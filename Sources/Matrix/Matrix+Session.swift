//
//  Matrix+Session.swift
//
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation
import os

#if !os(macOS)
import UIKit
#else
import AppKit
#endif

import IDZSwiftCommonCrypto
import MatrixSDKCrypto

extension Matrix {
    public class Session: Matrix.Client, ObservableObject {
        
        public struct Config {
            var storageType: StorageType
            var s4key: Data
            var s4KeyId: String
        }
        
        public var me: User {
            self.getUser(userId: self.creds.userId)
        }
        
        // cvw: Leaving these as comments for now, as they require us to define even more types
        //@Published public var device: MatrixDevice
        
        @Published public var rooms: [RoomId: Matrix.Room]
        @Published public var invitations: [RoomId: Matrix.InvitedRoom]
        @Published public var spaceChildRooms: [RoomId: Matrix.SpaceChildRoom]
        
        public private(set) var users: ConcurrentDictionary<UserId,Matrix.User> //[UserId: Matrix.User]
        
        // cvw: Stuff that we need to add, but haven't got to yet
        public typealias AccountDataFilter = (String) -> Bool
        public typealias AccountDataHandler = ([AccountDataEvent]) async throws -> Void
        @Published public private(set) var accountData: [String: Codable]
        private var accountDataHandlers: [(AccountDataFilter,AccountDataHandler)] = []
        
        // Our current active UIA session, if any
        @Published public private(set) var uiaSession: UIAuthSession?

        // Need some private stuff that outside callers can't see
        private var dataStore: DataStore?
        private var syncRequestTask: Task<String?,Swift.Error>? // FIXME Use a TaskGroup to make this subordinate to the backgroundSyncTask
        private var dehydrateRequestTask: Task<String?, Swift.Error>?
        private var initialSyncFilter: SyncFilter?
        
        #if DEBUG
        @Published public private(set) var syncToken: String? = nil
        public private(set) var syncSuccessCount: UInt = 0
        public private(set) var syncFailureCount: UInt = 0
        #else
        private var syncToken: String? = nil
        private var syncSuccessCount: UInt = 0
        private var syncFailureCount: UInt = 0
        #endif
        private var syncFilterId: String? = nil
        private var syncRequestTimeout: Int = 30_000
        private var keepSyncing: Bool
        private var syncDelayNS: UInt64 = 30_000_000_000
        private var backgroundSyncTask: Task<UInt,Swift.Error>? // FIXME use a TaskGroup
        private var backgroundSyncDelayMS: UInt64?
                
        private(set) public var syncLogger: os.Logger?
        
        public func enableSyncLogging() {
            self.syncLogger = os.Logger(subsystem: "Session", category: "sync \(creds.userId)")
        }
        
        public func disableSyncLogging() {
            self.syncLogger = nil
        }
        
        private var propagateProfileUpdates = false
        
        public var ignoredUserIds: [UserId] {
            guard let content = self.accountData[M_IGNORED_USER_LIST] as? IgnoredUserListContent
            else {
                return []
            }
            return content.ignoredUsers
        }

        // Secret Storage
        public private(set) var secretStore: SecretStore?
        public var secretStorageOnline: Bool {
            guard case let .online(defaultKeyId) = self.secretStore?.state
            else {
                return false
            }
            logger.debug("Secret storage is online with keyId \(defaultKeyId)")
            return true
        }
        
        // Matrix Rust crypto
        internal var crypto: MatrixSDKCrypto.OlmMachine
        internal var cryptoQueue: TicketTaskQueue<Void>
        var cryptoLogger: os.Logger
        
        // Key Backup
        var backupRecoveryKey: MatrixSDKCrypto.BackupRecoveryKey?
        
        // Encrypted Media
        private var downloadAndDecryptTasks: [MXC: Task<URL,Swift.Error>]
        
        // When did we last query for users' devices / keys ?
        private var userDeviceKeysTimestamps: [UserId: Date]
        
        // MARK: init
        
        public init(creds: Credentials,
                    defaults: UserDefaults = UserDefaults.standard,
                    syncToken: String? = nil, startSyncing: Bool = true, initialSyncFilter: SyncFilter? = nil,
                    displayname: String? = nil, avatarUrl: MXC? = nil, statusMessage: String? = nil,
                    recoverySecretKey: Data? = nil, recoveryTimestamp: Data? = nil,
                    storageType: StorageType = .persistent(preserve: true),
                    useCrossSigning: Bool = true,
                    secretStorageKey: SecretStorageKey? = nil,
                    enableKeyBackup: Bool = true
        ) async throws {
            
            //self.syncLogger = os.Logger(subsystem: "matrix", category: "sync \(creds.userId)")
            self.cryptoLogger = os.Logger(subsystem: "matrix", category: "crypto \(creds.userId)")
            
            self.rooms = [:]
            self.invitations = [:]
            self.spaceChildRooms = [:]
            self.users = .init(n: 16)
            self.accountData = [:]
            
            self.syncToken = syncToken
            self.keepSyncing = startSyncing
            self.initialSyncFilter = initialSyncFilter
            // Initialize the sync tasks to nil so we can run super.init()
            self.syncRequestTask = nil
            self.dehydrateRequestTask = nil
            self.backgroundSyncTask = nil
            //self.backgroundSyncDelayMS = 1_000
            
            self.userDeviceKeysTimestamps = [:]
            
            self.uiaSession = nil
            
            self.dataStore = try await GRDBDataStore(userId: creds.userId, type: storageType)
            
            // Rust Crypto SDK
            let appSupportUrl = try FileManager.default.url(for: .applicationSupportDirectory,
                                                            in: .userDomainMask,
                                                            appropriateFor: nil,
                                                            create: true)
            let applicationName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "matrix.swift"
            let cryptoStoreDir = appSupportUrl.appendingPathComponent(applicationName)
                                              .appendingPathComponent(creds.userId.stringValue)
                                              .appendingPathComponent(creds.deviceId)
                                              .appendingPathComponent("crypto")
            try FileManager.default.createDirectory(at: cryptoStoreDir, withIntermediateDirectories: true)
            self.crypto = try OlmMachine(userId: "\(creds.userId)",
                                         deviceId: "\(creds.deviceId)",
                                         path: cryptoStoreDir.path,
                                         passphrase: nil)
            MatrixSDKCrypto.setLogger(logger: Matrix.CryptoLogger())
            self.cryptoQueue = TicketTaskQueue<Void>()
            
            self.downloadAndDecryptTasks = [:]
            
            try await super.init(creds: creds, defaults: defaults)
            
            // --------------------------------------------------------------------------------------------------------
            // Phase 1 init is done -- Now we can reference `self`
            // Ok now we're initialized as a valid Matrix.Client (super class)
            
            // Populate our own User in the users dictionary
            // This is to mitigate a race condition later when we start up the session and multiple pieces of the app call getUser() at (nearly) the same time
            let _ = self.getUser(userId: creds.userId)
            
            // Set up crypto stuff
            // Secret storage
            cryptoLogger.debug("Setting up secret storage")
            if let sskey = secretStorageKey {
                cryptoLogger.debug("Setting up secret storage with keyId \(sskey.keyId)")
                self.secretStore = try await .init(session: self, ssk: sskey)
            } else {
                cryptoLogger.debug("Setting up secret storage -- no new keys")
                self.secretStore = try await .init(session: self, keys: [:])
            }
            // If we were able to find the keys that we need to bring SecretStorage online,
            // ie it's not just sitting there waiting to be provided some keys,
            // then we can also go ahead and enable cross-signing and key backup.
            if secretStorageOnline {
                try await cryptoQueue.run {
                    
                    self.cryptoLogger.debug("Checking for outgoing requests")
                    let cryptoRequests = try self.crypto.outgoingRequests()
                    logger.debug("Session:\tSending initial crypto requests (\(cryptoRequests.count, privacy: .public))")
                    for request in cryptoRequests {
                        try await self.sendCryptoRequest(request: request)
                    }
                    
                    if useCrossSigning {
                        // Hopefully uia is nil -- Meaning we don't have to re-authenticate so soon.
                        // But it's possible that we might get stuck doing UIA right off the bat.
                        // No big deal.  Handle it like any other UIA.
                        if let uia = try await self.setupCrossSigning() {
                            logger.debug("Need to UIA to enable cross-signing")
                        } else {
                            logger.debug("Setup cross-signing without UIA")
                        }
                    }
                    if enableKeyBackup {
                        try await self.setupKeyBackup()
                    }
                }
            }
            
            
            // Load our list of existing invited rooms
            if let store = self.dataStore {
                logger.debug("Looking for previously-saved invited rooms")
                let invitedRoomIds = try await store.getInvitedRoomIds(for: creds.userId)
                logger.debug("Found \(invitedRoomIds.count) invited room id's")
                
                // Note: We can get stuck invitations if we somehow miss the join event for a room
                //       So here we query our entire list of joined rooms to make sure we're not incorrectly loading an old invitation
                let joinedRoomIds = try await getJoinedRoomIds()
                
                for roomId in invitedRoomIds {
                    if joinedRoomIds.contains(roomId) {
                        // Looks like this is a "stuck" invitation.
                        // Purge it from the database so we don't stumble over this again
                        try await deleteInvitedRoom(roomId: roomId)
                    } else {
                        logger.debug("Attempting to load stripped state for invited room \(roomId)")
                        let strippedStateEvents = try await store.loadStrippedState(for: roomId)
                        if let room = try? InvitedRoom(session: self, roomId: roomId, stateEvents: strippedStateEvents) {
                            await MainActor.run {
                                self.invitations[roomId] = room
                            }
                        }
                    }
                }
            }
            
            // Load our account data
            if let store = self.dataStore {
                let events = try await store.loadAccountDataEvents(roomId: nil, limit: 1000, offset: nil)
                for event in events {
                    self.accountData[event.type] = event
                }
            }
            
            // Are we supposed to start syncing?
            if startSyncing {
                try await startBackgroundSync()
            }

        }
        
        public func loadJoinedRooms() async throws {
            let joinedRoomIds = try await self.getJoinedRoomIds()
            
            let missingRoomIds = joinedRoomIds.filter { self.rooms[$0] == nil }
            
            for roomId in missingRoomIds {
                if let storedRoom = try? await self.loadRoomFromStorage(roomId: roomId)
                {
                    await MainActor.run {
                        if rooms[roomId] == nil {
                            rooms[roomId] = storedRoom
                        }
                    }
                }
                else if let stateEvents = try? await self.getRoomStateEvents(roomId: roomId),
                        let newRoom = await self.roomFromEvents(roomId: roomId, stateEvents: stateEvents, timelineEvents: [], accountDataEvents: [])
                {
                    await MainActor.run {
                        if rooms[roomId] == nil {
                            rooms[roomId] = newRoom
                        }
                    }
                }
                else {
                    logger.warning("Failed to load joined room \(roomId)")
                }
            }
        }
        
        private func loadRoomFromStorage(roomId: RoomId) async throws -> Matrix.Room? {
            if let store = self.dataStore {
                do {
                    let stateEvents = try await store.loadEssentialState(for: roomId)
                    let timelineEvents = try await store.loadTimeline(for: roomId, limit: 25, offset: 0)
                    let accountDataEvents = try await store.loadAccountDataEvents(roomId: roomId, limit: 0, offset: 0)
                    let room = await self.roomFromEvents(roomId: roomId, stateEvents: stateEvents, timelineEvents: timelineEvents, accountDataEvents: accountDataEvents)
                    return room
                }
                catch {
                    logger.error("Failed to load room \(roomId) from storage")
                    throw Matrix.Error("Failed to load room from storage")
                }
            }
            else {
                return nil
            }
        }
                        
        private func roomFromEvents(roomId: RoomId,
                                    stateEvents: [ClientEventWithoutRoomId],
                                    timelineEvents: [ClientEventWithoutRoomId],
                                    accountDataEvents: [AccountDataEvent]
        ) async -> Matrix.Room? {
            let T: Matrix.Room.Type
            
            if let creationEvent = stateEvents.first(where: {$0.type == M_ROOM_CREATE}),
               let creationContent = creationEvent.content as? RoomCreateContent,
               let roomTypeString = creationContent.type,
               let type = Matrix.roomTypes[roomTypeString]
            {
                T = type
            } else {
                T = Matrix.defaultRoomType
            }
            
            if let room = try? T.init(roomId: roomId,
                                      session: self,
                                      initialState: stateEvents,
                                      initialTimeline: timelineEvents,
                                      initialAccountData: accountDataEvents)
            {
                return room
            }
            
            return nil
        }
        
        // MARK: Profile management
        
        public func inhibitProfilePropagation() {
            self.propagateProfileUpdates = false
        }
        
        public func enableProfilePropagation() {
            self.propagateProfileUpdates = true
        }
        
        override public func setMyDisplayName(_ name: String, propagate: Bool? = nil) async throws {
            let propagate = propagate ?? self.propagateProfileUpdates
            try await super.setMyDisplayName(name, propagate: propagate)
            
            // FIXME: Until we can make Synapse conform to the spec and send m.presence events, we're just going to fake them ourselves
            await self.me.update(PresenceContent(displayname: name))
        }
        
        override public func setMyAvatarUrl(_ mxc: MXC, propagate: Bool? = nil) async throws {
            let propagate = propagate ?? self.propagateProfileUpdates

            try await super.setMyAvatarUrl(mxc, propagate: propagate)
            
            // FIXME: Until we can make Synapse conform to the spec and send m.presence events, we're just going to fake them ourselves
            await self.me.update(PresenceContent(avatarUrl: mxc))
        }
        
        @discardableResult
        override public func setMyAvatarImage(_ image: Matrix.NativeImage, propagate: Bool? = nil) async throws -> MXC {
            let propagate = propagate ?? self.propagateProfileUpdates

            let mxc = try await super.setMyAvatarImage(image, propagate: propagate)
            
            // FIXME: Until we can make Synapse conform to the spec and send m.presence events, we're just going to fake them ourselves
            await self.me.update(PresenceContent(avatarUrl: mxc))
            
            return mxc
        }
        
        override public func setMyStatus(message: String) async throws {
            try await super.setMyStatus(message: message)

            // FIXME: Until we can make Synapse conform to the spec and send m.presence events, we're just going to fake them ourselves
            await self.me.update(PresenceContent(statusMessage: message))
        }

        
        // MARK: Threepids
        
        @discardableResult
        public func deleteThreepid(medium: String,
                                   address: String,
                                   completion handler: UiaCompletionHandler? = nil
        ) async throws -> UIASession? {

            return try await uiaCall(method: "POST",
                                     path: "/_matrix/client/v3/account/3pid/delete",
                                     requestDict: [
                                        "medium": medium,
                                        "address": address
                                     ],
                                     completion: handler)

        }

        
        // MARK: Sync
        
        public func startBackgroundSync() async throws {
            self.keepSyncing = true
            if let t = self.backgroundSyncTask,
               t.isCancelled == false
            {
                logger.warning("Session:\tCan't start background sync when it's already running!")
                return
            }
            self.backgroundSyncTask = self.backgroundSyncTask ?? .init(priority: .background) {
                syncLogger?.debug("Starting background sync")
                var count: UInt = 0
                while self.keepSyncing {
                    syncLogger?.debug("Keeping on syncing...")
                    guard let token = try? await sync()
                    else {
                        self.syncFailureCount += 1
                        syncLogger?.warning("Sync failed with token \(self.syncToken ?? "(none)") -- \(self.syncFailureCount) failures")
                        /* // Update: Never stop never stopping :)
                           //         Lots of bad stuff happens if we stop syncing.  So keep going!
                        if failureCount > 3 {
                            self.keepSyncing = false
                        }
                        */
                        try await Task.sleep(for: .seconds(30))
                        continue
                    }
                    
                    count += 1
                    self.syncFailureCount = 0
                    self.syncSuccessCount += 1
                
                    syncLogger?.debug("Got new sync token \(token)")
                    /*
                    if let delay = self.backgroundSyncDelayMS {
                        syncLogger.debug("Sleeping for \(delay) ms before next sync")
                        let nano = delay * 1000
                        try await Task.sleep(nanoseconds: nano)
                    }
                    */
                    
                    // Weekly device rehydration check
                    let lastDeviceDehydration = self.defaults.object(forKey: "last_device_dehydration[\(self.creds.userId)]") as? Date
                    
                    if let interval = lastDeviceDehydration?.timeIntervalSinceNow,
                       abs(interval) < Double(RoomEncryptionContent.defaultRotationPeriodMs) {
                        // Dehydrated device timestamp is not old enough to refresh, no op
                    }
                    else {
                        // Either we have not uploaded a dehydrated device or time has expired
                        syncLogger?.debug("Last dehydration time is expired")
                        
                        try await self.dehydrateDevice()
                        self.defaults.set(Date(), forKey: "last_device_dehydration[\(self.creds.userId)]")
                    }
                }
                self.backgroundSyncTask = nil
                return count
            }
        }
        
        public func sync() async throws -> String? {
            //print("/sync:\t\(creds.userId) Starting sync()  -- token is \(syncToken ?? "(none)")")
            // FIXME: Use a TaskGroup
            if let task = syncRequestTask {
                syncLogger?.debug("Already syncing..  awaiting on the result")
                return try await task.value
            } else {
                do {
                    syncRequestTask = .init(priority: .background, operation: syncRequestTaskOperation)
                    return try await syncRequestTask?.value
                } catch {
                    self.syncRequestTask = nil
                    return nil
                }
            }
        }
        
        // MARK: Sync request task
        
        // https://spec.matrix.org/v1.2/client-server-api/#get_matrixclientv3sync
        // The Swift compiler couldn't figure this out when it was given in-line in the call below.
        // So here we are defining its type explicitly.
        @Sendable
        private func syncRequestTaskOperation() async throws -> String? {
            
            let logger = self.syncLogger
            
            logger?.debug("Doing a sync")
            
            // Following the Rust Crypto SDK example https://github.com/matrix-org/matrix-rust-sdk/blob/8ac7f88d22e2fa0ca96eba7239ba7ec08658552c/crates/matrix-sdk-crypto/src/lib.rs#L540
            // We first send any outbound messages from the crypto module before we actually call /sync
            logger?.debug("Sending outbound crypto requests")
            try await sendOutgoingCryptoRequests()
            
            let url = "/_matrix/client/v3/sync"
            var params = [
                "timeout": "\(syncRequestTimeout)",
            ]
            if let token = syncToken {
                logger?.debug("User \(self.creds.userId) syncing with token \(token)")

                params["since"] = token
                if let filterId = self.syncFilterId {
                    params["filter"] = filterId
                }
            } else {
                logger?.debug("User \(self.creds.userId) doing initial sync")
                
                if let filter = self.initialSyncFilter {
                    logger?.debug("Setting initial sync filter before we can sync")
                    let filterId = try await self.uploadFilter(filter)
                    params["filter"] = filterId
                } else {
                    logger?.debug("No initial sync filter")
                }
            }
            let (data, response) = try await self.call(method: "GET", path: url, params: params)
            logger?.debug("User \(self.creds.userId) got sync response with status \(response.statusCode, privacy: .public)")
            
            //let rawDataString = String(data: data, encoding: .utf8)
            //print("\n\n\(rawDataString!)\n\n")

            guard response.statusCode == 200 else {
                logger?.error("\(self.creds.userId) Error: got HTTP \(response.statusCode, privacy: .public) \(response.description, privacy: .public)")
                self.syncRequestTask = nil
                //return self.syncToken
                return nil
            }
            
            let decoder = JSONDecoder()
            //decoder.keyDecodingStrategy = .convertFromSnakeCase
            guard let responseBody = try? decoder.decode(SyncResponseBody.self, from: data)
            else {
                self.syncRequestTask = nil
                logger?.error("Failed to decode /sync response")
                throw Matrix.Error("Failed to decode /sync response")
            }
            
            // Process the sync response, updating local state if necessary
            
            // First thing to check: Did our sync token actually change?
            // Because if not, then we've already seen everything in this update
            if responseBody.nextBatch == self.syncToken {
                logger?.debug("Token didn't change; Therefore no updates; Doing nothing")
                self.syncRequestTask = nil
                return syncToken
            } else {
                logger?.debug("Got new sync token \(responseBody.nextBatch)")
            }
            
            // Track whether this sync was successful.  If not, we shouldn't advance the token.
            var success = true
            
            try await cryptoQueue.run {
                // Send updates to the Rust crypto module
                logger?.debug("Updating Rust crypto module")
                guard let decryptedToDeviceEventsString = try? self.updateCryptoAfterSync(responseBody: responseBody)
                else {
                    success = false
                    logger?.error("Crypto update failed")
                    return
                }
                // NOTE: If we want to track the Olm or Megolm sessions ourselves for debugging purposes,
                //       then this is the place to do it.  The Rust Crypto SDK just provided us with the
                //       plaintext of all the to-device events.
            }

            // Send any requests from the crypto module
            try await self.sendOutgoingCryptoRequests()
            
            // Save any new keys to our current backup (if any)
            try await self.saveKeysToBackup()
            
            // Handle invites
            if let invitedRoomsDict = responseBody.rooms?.invite {
                logger?.debug("Found \(invitedRoomsDict.count, privacy: .public) invited rooms")
                for (roomId, info) in invitedRoomsDict {
                    logger?.debug("Found invited room \(roomId)")
                    guard let events = info.inviteState?.events
                    else {
                        continue
                    }
                    
                    if let store = self.dataStore {
                        try await store.saveStrippedState(events: events, roomId: roomId)
                    }
                    
                    //if self.invitations[roomId] == nil {
                    let room = try InvitedRoom(session: self, roomId: roomId, stateEvents: events)
                    await MainActor.run {
                        self.invitations[roomId] = room
                    }
                    //}
                }
            } else {
                logger?.debug("No invited rooms")
            }
            
            // Handle rooms where we're already joined
            if let joinedRoomsDict = responseBody.rooms?.join {
                logger?.debug("Found \(joinedRoomsDict.count, privacy: .public) joined rooms")
                for (roomId, info) in joinedRoomsDict {
                    logger?.debug("Found joined room \(roomId)")
                    let stateEvents = info.state?.events ?? []
                    let timelineEvents = info.timeline?.events ?? []
                    let timelineStateEvents = timelineEvents.filter {
                        $0.stateKey != nil
                    }
                    let allStateEvents = stateEvents + timelineStateEvents
                    
                    let roomTimestamp = timelineEvents.map { $0.originServerTS }.max()
                    
                    if let store = self.dataStore {
                        // First save the state events from before this timeline
                        // Then save the state events that came in during the timeline
                        // We do both in a single call so it all happens in one transaction in the database
                        if !allStateEvents.isEmpty {
                            //logger.debug("Saving state for room \(roomId)")
                            try await store.saveState(events: allStateEvents, in: roomId)
                        }
                        if !timelineEvents.isEmpty {
                            // Save the whole timeline so it can be displayed later
                            //logger.debug("Saving timeline for room \(roomId)")
                            try await store.saveTimeline(events: timelineEvents, in: roomId)
                        }
                        
                        // Also process any redactions that need to hit the database
                        let redactionEvents = timelineEvents.filter { $0.type == M_ROOM_REDACTION }
                                                            .compactMap { try? ClientEvent(from: $0, roomId: roomId) }
                        try await store.processRedactions(redactionEvents)
                        
                        // Save the room summary with the latest timestamp
                        if let timestamp = roomTimestamp {
                            //logger.debug("Saving timestamp for room \(roomId)")
                            try await store.saveRoomTimestamp(roomId: roomId, state: .join, timestamp: timestamp)
                        } else {
                            //logger.debug("No update to timestamp for room \(roomId)")
                        }
                    }
                    
                    // Did we have any users leave, or get kicked or banned?
                    // If so, we need to create a new Megolm session with a new chain of keys before we can send anything else
                    // The first step towards that is to invalidate the current session
                    let leftUsers = allStateEvents.filter {
                        guard $0.type == M_ROOM_MEMBER,
                              let content = $0.content as? RoomMemberContent,
                              content.membership == .leave || content.membership == .ban
                        else {
                            return false
                        }
                        return true
                    }.compactMap {
                        $0.stateKey
                    }
                    if !leftUsers.isEmpty {
                        //logger.debug("CRYPTO: Discarding/invalidating old Megolm session for room \(roomId) because \(leftUsers.count) users have left")
                        try await cryptoQueue.run {
                            try self.crypto.discardRoomKey(roomId: "\(roomId)")
                        }
                    }
                    
                    // Update the crypto module about any new users
                    let newUsers = allStateEvents.filter {
                        // Find all of the room member events that represent a joined member of the room
                        guard $0.type == M_ROOM_MEMBER,
                              let content = $0.content as? RoomMemberContent,
                              content.membership == .join
                        else {
                            return false
                        }
                        return true
                    }.compactMap {
                        // The member event's state key is the id of the given user
                        $0.stateKey
                    }
                    if !newUsers.isEmpty {
                        //logger.debug("Updating crypto state with \(newUsers.count) potentially-new users")
                        try await cryptoQueue.run {
                            try self.crypto.updateTrackedUsers(users: newUsers)
                        }
                    }

                    let accountDataEvents = info.accountData?.events

                    if let room = self.rooms[roomId] {
                        //logger.debug("\tWe know this room already: \(stateEvents.count) new state events, \(timelineEvents.count) new timeline events")

                        // Update the room with the latest data from `info`
                        await room.updateState(from: stateEvents)
                        try await room.updateTimeline(from: timelineEvents)
                        
                        if let unread = info.unreadNotifications {
                            //logger.debug("\t\(unread.notificationCount) notifications, \(unread.highlightCount) highlights")
                            //room.notificationCount = unread.notificationCount
                            //room.highlightCount = unread.highlightCount
                            await room.updateUnreadCounts(notifications: unread.notificationCount, highlights: unread.highlightCount)
                        }
                        
                        if let roomAccountDataEvents = accountDataEvents {
                            await room.updateAccountData(events: roomAccountDataEvents)
                        }
                        
                        if let ephemeralEvents = info.ephemeral?.events {
                            await room.updateEphemeral(events: ephemeralEvents)
                        }

                    } else {
                        
                        let T: Matrix.Room.Type
                        
                        if let creationEvent = stateEvents.first(where: {$0.type == M_ROOM_CREATE}),
                           let creationContent = creationEvent.content as? RoomCreateContent,
                           let roomTypeString = creationContent.type,
                           let type = Matrix.roomTypes[roomTypeString]
                        {
                            T = type
                        } else {
                            T = Matrix.defaultRoomType
                        }
                        
                        if let room = try? T.init(roomId: roomId,
                                                  session: self,
                                                  initialState: allStateEvents,
                                                  initialTimeline: timelineEvents,
                                                  initialAccountData: accountDataEvents ?? [])
                        {
                            await MainActor.run {
                                self.rooms[roomId] = room
                            }
                        }
                    }
                    
                    if invitations[roomId] != nil {
                        // Clearly the room is no longer in the 'invited' state
                        await MainActor.run {
                            invitations.removeValue(forKey: roomId)
                        }
                        // Also purge any stripped state that we had been storing for this room
                        try await deleteInvitedRoom(roomId: roomId)
                    }
                }
            } else {
                logger?.debug("No joined rooms")
            }
            
            // Handle rooms that we've left
            if let leftRoomsDict = responseBody.rooms?.leave {
                logger?.debug("Found \(leftRoomsDict.count, privacy: .public) left rooms")
                for (roomId, info) in leftRoomsDict {
                    logger?.debug("Found left room \(roomId)")
                    
                    let stateEvents = info.state?.events ?? []
                    let timelineEvents = info.timeline?.events ?? []
                    let timelineStateEvents = timelineEvents.filter { $0.stateKey != nil }
                    let allStateEvents = stateEvents + timelineStateEvents
                    
                    // Save state events into the data store - In particular this will save our m.room.member event in the "left" state
                    if let store = self.dataStore {
                        if !allStateEvents.isEmpty {
                            try await store.saveState(events: allStateEvents, in: roomId)
                        }
                        if !timelineEvents.isEmpty {
                            try await store.saveTimeline(events: timelineEvents, in: roomId)
                        }
                    }
                    
                    if let room = self.rooms[roomId] {
                        await room.updateState(from: stateEvents)
                        try await room.updateTimeline(from: timelineEvents)
                        
                        if let callback = room.onLeave {
                            try await callback()
                        }
                    }
                    
                    // TODO: What should we do here?
                    // For now, just make sure these rooms are taken out of the other lists
                    await MainActor.run {
                        invitations.removeValue(forKey: roomId)
                        rooms.removeValue(forKey: roomId)
                    }
                }
            } else {
                logger?.debug("No left rooms")
            }
            
            if let newAccountDataEvents = responseBody.accountData?.events {
                logger?.debug("Found \(newAccountDataEvents.count, privacy: .public) account data events")
                
                // Call any registered account data handler callbacks
                for (filter,handler) in self.accountDataHandlers {
                    let matchingEvents = newAccountDataEvents.filter({ filter($0.type) })
                    if !matchingEvents.isEmpty
                    {
                        try await handler(matchingEvents)
                    }
                }
                
                // Update our own local copy
                var updates = [String: Codable]()
                for event in newAccountDataEvents {
                    logger?.debug("Got account data with type = \(event.type, privacy: .public)")
                    updates[event.type] = event.content
                }
                
                if let store = self.dataStore {
                    logger?.debug("Saving account data")
                    try await store.saveAccountData(events: newAccountDataEvents, in: nil)
                    logger?.debug("Done saving account data")
                }
                
                // Do the merge before we move to the main thread
                let updatedAccountData = self.accountData.merging(updates, uniquingKeysWith: { (current,new) in new } )
                // On the main thread, update account data in one swoop
                await MainActor.run {
                    self.accountData = updatedAccountData
                }
            } else {
                logger?.debug("No account data")
            }
            
            // Presence
            if let presenceEvents = responseBody.presence?.events {
                logger?.debug("Updating presence - \(presenceEvents.count) events")
                for event in presenceEvents {
                    if let userId = event.sender,
                       let presence = event.content as? PresenceContent
                    {
                        logger?.debug("Updating presence for user \(userId.stringValue)")
                        await self.users[userId]?.update(presence)
                    } else {
                        logger?.error("Could not parse presence event")
                    }
                }
            }
            
            // FIXME: Handle to-device messages
            logger?.debug("Skipping to-device messages for now")


            if success {
                logger?.debug("Updating sync token...  awaiting MainActor")
                await MainActor.run {
                    //print("/sync:\tMainActor updating sync token to \(responseBody.nextBatch)")
                    self.syncToken = responseBody.nextBatch
                }
                UserDefaults.standard.set(self.syncToken, forKey: "sync_token[\(creds.userId)::\(creds.deviceId)]")
                
                //print("/sync:\t\(creds.userId) Done!")
                logger?.debug("sync successful!")
                self.syncRequestTask = nil
                return responseBody.nextBatch
            } else {
                logger?.error("sync failed")
                return self.syncToken
            }
        }
        
        public func setSyncFilter(_ filter: SyncFilter) async throws {
            let filterId = try await uploadFilter(filter)
            await MainActor.run {
                self.syncFilterId = filterId
            }
        }
        
        
        // MARK: Crypto
        
        private func updateCryptoAfterSync(responseBody: SyncResponseBody) throws -> SyncChangesResult {
            var logger = self.syncLogger
            var eventsListString = "[]"
            if let toDevice = responseBody.toDevice {
                let events = toDevice.events
                let encoder = JSONEncoder()
                let eventsData = try encoder.encode(events)
                eventsListString = String(data: eventsData, encoding: .utf8)!
                logger?.debug("Sending \(events.count, privacy: .public) to-device event to Rust crypto module:   \(eventsListString)")
            }
            let eventsString = "{\"events\": \(eventsListString)}"
            // Ugh we have to translate the device lists back to raw String's
            var deviceLists = MatrixSDKCrypto.DeviceLists(
                changed: responseBody.deviceLists?.changed?.map { $0.description } ?? [],
                left: responseBody.deviceLists?.left?.map { $0.description } ?? []
            )
            logger?.debug("\(deviceLists.changed.count, privacy: .public) Changed devices")
            logger?.debug("\(deviceLists.left.count, privacy: .public) Left devices")
            logger?.debug("\(responseBody.deviceOneTimeKeysCount?.keys.count ?? 0, privacy: .public) device one-time keys")
            if let dotkc = responseBody.deviceOneTimeKeysCount {
                logger?.debug("\(dotkc)")
            }
            logger?.debug("\(responseBody.deviceUnusedFallbackKeyTypes?.count ?? 0, privacy: .public) unused fallback keys")

            guard let result = try? self.crypto.receiveSyncChanges(events: eventsString,
                                                                   deviceChanges: deviceLists,
                                                                   keyCounts: responseBody.deviceOneTimeKeysCount ?? [:],
                                                                   unusedFallbackKeys: responseBody.deviceUnusedFallbackKeyTypes ?? [],
                                                                   nextBatchToken: responseBody.nextBatch)
            else {
                logger?.error("Crypto update failed")
                throw Matrix.Error("Crypto update failed")
            }
            logger?.debug("Got response from Rust crypto: \(result.toDeviceEvents.count) to-device events, \(result.roomKeyInfos.count) room key info's")
            return result
        }

        // Send any and all pending requests from the crypto crate
        func sendOutgoingCryptoRequests() async throws {
            try await cryptoQueue.run {
                if let requests = try? self.crypto.outgoingRequests() {
                    for request in requests {
                        try await self.sendCryptoRequest(request: request)
                    }
                }
            }
        }
        
        // Send one request from the crypto crate
        func sendCryptoRequest(request: Request) async throws {
            let logger = self.cryptoLogger
            switch request {
                
            case .toDevice(requestId: let requestId, eventType: let eventType, body: let messagesString):
                logger.debug("Handling to-device request")
                let bodyString = "{\"messages\": \(messagesString)}"         // Redneck JSON encoding 🤘
                let txnId = "\(UInt16.random(in: UInt16.min...UInt16.max))"
                let (data, response) = try await self.call(method: "PUT",
                                                           //path: "/_/matrix/client/v3/sendToDevice/\(eventType)/\(txnId)",
                                                           path: "/_matrix/client/v3/sendToDevice/\(eventType)/\(txnId)",
                                                           body: bodyString)
                guard let responseBodyString = String(data: data, encoding: .utf8)
                else {
                    logger.error("Couldn't process /sendToDevice response")
                    throw Matrix.Error("Couldn't process /sendToDevice response")
                }
                logger.debug("Marking to-device request as sent")
                try self.crypto.markRequestAsSent(requestId: requestId,
                                                  requestType: .toDevice,
                                                  responseBody: responseBodyString)
                
            case .keysUpload(requestId: let requestId, body: let bodyString):
                logger.debug("Handling keys upload request")
                let (data, response) = try await self.call(method: "POST",
                                                           path: "/_matrix/client/v3/keys/upload",
                                                           body: bodyString)
                guard let responseBodyString = String(data: data, encoding: .utf8)
                else {
                    logger.error("Couldn't process /keys/upload response")
                    throw Matrix.Error("Couldn't process /keys/upload response")
                }
                logger.debug("Marking keys upload request as sent")
                try self.crypto.markRequestAsSent(requestId: requestId,
                                                  requestType: .keysUpload,
                                                  responseBody: responseBodyString)
            
            case .keysQuery(requestId: let requestId, users: let users):
                logger.debug("Handling keys query request")
                // poljar says the Rust code intentionally ignores the timeout and device id's here
                // weird but ok whatever
                var deviceKeys: [String: [String]] = .init()
                for user in users {
                    logger.debug("Including user \(user) in keys query")
                    deviceKeys[user] = []
                }
                struct KeysQueryRequestBody: Codable {
                    var deviceKeys: [String: [String]]
                    var timeout: UInt64
                    
                    enum CodingKeys: String, CodingKey {
                        case deviceKeys = "device_keys"
                        case timeout
                    }
                }
                let requestBody = KeysQueryRequestBody(deviceKeys: deviceKeys, timeout: 10_000)
                let (data, response) = try await self.call(method: "POST",
                                                           path: "/_matrix/client/v3/keys/query",
                                                           body: requestBody)
                guard let responseBodyString = String(data: data, encoding: .utf8)
                else {
                    logger.error("Couldn't process /keys/query response body")
                    throw Matrix.Error("Couldn't process /keys/query response body")
                }
                logger.debug("Marking /keys/query response as sent")
                try self.crypto.markRequestAsSent(requestId: requestId,
                                                  requestType: .keysQuery,
                                                  responseBody: responseBodyString)
                // ------ Now all the important work is done -----------
                // From here on out, we're only working to update our local timestamps
                struct KeysQueryResponseBody: Decodable {
                    var deviceKeys: [UserId: [String:DeviceKeysInfo]]
                    struct DeviceKeysInfo: Decodable {
                        // We're ignoring everything in here :shrug:
                    }
                    
                    enum CodingKeys: String, CodingKey {
                        case deviceKeys = "device_keys"
                    }
                }
                let decoder = JSONDecoder()
                guard let responseBody = try? decoder.decode(KeysQueryResponseBody.self, from: data)
                else {
                    logger.error("Failed to decode /keys/query response body.  Unable to update device keys timestamps.")
                    // Don't throw an error!
                    // We've already done all the important bits, now just move on with life.
                    // The only thing we're missing out on here is updating our timestamps for the queried users.
                    return
                }
                // Now update our local timestamps
                let updatedUserIds = Array(responseBody.deviceKeys.keys)
                let timestamp = Date()
                for userId in updatedUserIds {
                    self.userDeviceKeysTimestamps[userId] = timestamp
                }
                
                
            case .keysClaim(requestId: let requestId, oneTimeKeys: let oneTimeKeys):
                logger.debug("Handling keys claim request")
                let (data, response) = try await self.call(method: "POST",
                                                           path: "/_matrix/client/v3/keys/claim",
                                                           body: [
                                                            "one_time_keys": oneTimeKeys
                                                           ])
                guard let responseBodyString = String(data: data, encoding: .utf8)
                else {
                    logger.error("Couldn't process /keys/claim response")
                    throw Matrix.Error("Couldn't process /keys/claim response")
                }
                logger.debug("Marking /keys/claim response as sent")
                try self.crypto.markRequestAsSent(requestId: requestId,
                                                  requestType: .keysClaim,
                                                  responseBody: responseBodyString)
                
            case .keysBackup(requestId: let requestId, version: let backupVersion, rooms: let rooms):
                logger.debug("Handling keys backup request")
                let path = "/_matrix/client/v3/room_keys/keys"
                let params = [
                    "version": "\(backupVersion)"
                ]
                let requestBodyString = "{\"rooms\": \(rooms)}"
                let requestBody = requestBodyString.data(using: .utf8)!
                let (data, response) = try await self.call(method: "PUT",
                                                           path: path,
                                                           params: params,
                                                           bodyData: requestBody)
                guard let responseBodyString = String(data: data, encoding: .utf8)
                else {
                    logger.error("Couldn't process /room_keys/keys response")
                    throw Matrix.Error("Couldn't process /room_keys/keys response")
                }
                logger.debug("Marking keys backup request as sent")
                try self.crypto.markRequestAsSent(requestId: requestId,
                                                  requestType: .keysBackup,
                                                  responseBody: responseBodyString)
                
            case .roomMessage(requestId: let requestId, roomId: let roomId, eventType: let eventType, content: let content):
                logger.debug("Sending room message for the crypto SDK: type = \(eventType)")
                // oof, looks like we need to decode the raw request string that the crypto sdk provided
                // it's kind of a stupid round-trip through our decoders, but oh well...
                let rawRequestData = content.data(using: .utf8)!
                let requestBody = try Matrix.decodeEventContent(of: eventType, from: rawRequestData)
                let urlPath = "/_matrix/client/v3/rooms/\(roomId)/send/\(eventType)/\(requestId)"
                let (data, response) = try await self.call(method: "PUT",
                                                           path: urlPath,
                                                           body: requestBody)
                guard let responseBodyString = String(data: data, encoding: .utf8)
                else {
                    logger.error("Couldn't process /send/\(eventType) response")
                    throw Matrix.Error("Couldn't process /send/\(eventType) response")
                }
                logger.debug("Marking room message request as sent")
                try self.crypto.markRequestAsSent(requestId: requestId,
                                                  requestType: .roomMessage,
                                                  responseBody: responseBodyString)
                
            case .signatureUpload(requestId: let requestId, body: let requestBody):
                logger.debug("Handling signature upload request")
                let (data, response) = try await self.call(method: "POST",
                                                           path: "/_matrix/client/v3/keys/signatures/upload",
                                                           body: requestBody)
                guard let responseBodyString = String(data: data, encoding: .utf8)
                else {
                    logger.error("Couldn't process /keys/signatures/upload response")
                    throw Matrix.Error("Couldn't process /keys/signatures/upload response")
                }
                logger.debug("Got signature upload response: Status \(response.statusCode) Body = \(responseBodyString)")
                logger.debug("Marking signature upload request as sent")
                try self.crypto.markRequestAsSent(requestId: requestId,
                                                  requestType: .signatureUpload,
                                                  responseBody: responseBodyString)
            } // end case request
        } // end sendCryptoRequests()
        
        // Query the server for the latest devices and keys for the given users
        public func queryKeys(for userIds: [UserId]) async throws {
            let now = Date()
            let threshold: TimeInterval = .minutes(30)
            // Which users have we not updated lately?
            let users = userIds
                .filter {
                    if let ts = self.userDeviceKeysTimestamps[$0] {
                        return now.timeIntervalSince(ts) > threshold
                    } else {
                        return true
                    }
                }
                .map { $0.stringValue }
            let requestId = UInt16.random(in: 0...UInt16.max)
            let keysQueryRequest = MatrixSDKCrypto.Request.keysQuery(requestId: "kq\(requestId)", users: users)

            try await self.sendCryptoRequest(request: keysQueryRequest)
        }

        public func requestRoomKey(for message: Message) async throws {
            logger.debug("Requesting room key for \(message.eventId) in room \(message.roomId.stringValue)")
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(message.event),
                  let string = String(data: data, encoding: .utf8)
            else {
                logger.error("Failed to encode event \(message.eventId)")
                throw Matrix.Error("Failed to encode event")
            }
            
            let requestPair = try self.crypto.requestRoomKey(event: string, roomId: message.room.roomId.stringValue)
            
            try await self.cryptoQueue.run {
                try await self.sendCryptoRequest(request: requestPair.keyRequest)
            }
        }
        
        // https://github.com/matrix-org/matrix-spec-proposals/pull/3814
        @Sendable
        public func dehydrateDeviceTaskOperation() async throws -> String? {
            cryptoLogger.debug("Dehydrating device \(self.creds.deviceId)")
            
            struct DehydratedDeviceResponseBody: Codable {
                var deviceId: String
                var deviceData: [String: String]?
                
                enum CodingKeys: String, CodingKey {
                    case deviceId = "device_id"
                    case deviceData = "device_data"
                }
            }
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
                        
            // Before dehydrating, we need to check if a device already exists.
            // If so, we'll want to rehydrate first since its possible the dehydrated
            // device contains room keys we've not received.
            var (data, response) = try await self.call(method: "GET",
                                                       path: "/_matrix/client/unstable/org.matrix.msc3814.v1/dehydrated_device",
                                                       body: nil,
                                                       expectedStatuses: [200,404])
            
            if response.statusCode != 404,
               let ssKey = try await self.secretStore?.getSecretData(type: M_DEHYDRATED_DEVICE) {
                cryptoLogger.debug("Rehydrating device \(self.creds.deviceId)")
                
                // Sigh... device ids may contain '/' characters which are also allowed in url paths
                var deviceIdCharacterSet = CharacterSet.urlPathAllowed
                deviceIdCharacterSet.remove("/")
                
                guard let responseBody = try? decoder.decode(DehydratedDeviceResponseBody.self, from: data),
                      var deviceIdUrlEncoded = responseBody.deviceId.addingPercentEncoding(withAllowedCharacters: deviceIdCharacterSet),
                      let deviceDataJson = try? encoder.encode(responseBody.deviceData),
                      let deviceDataString = String(data: deviceDataJson, encoding: .utf8)
                else {
                    self.dehydrateRequestTask = nil
                    cryptoLogger.error("Failed to process /unstable/org.matrix.msc3814.v1/dehydrated_device response")
                    throw Matrix.Error("Failed to process /unstable/org.matrix.msc3814.v1/dehydrated_device response")
                }
                
                let deviceId = responseBody.deviceId
                do {
                    let rehydrator = try crypto.dehydratedDevices().rehydrate(pickleKey: ssKey, deviceId: deviceId, deviceData: deviceDataString)
                    var next_batch = ""
                    
                    struct DehydratedDeviceEventsResponseBody: Codable {
                        var events: [ToDeviceEvent]
                        var nextBatch: String
                        
                        enum CodingKeys: String, CodingKey {
                            case events = "events"
                            case nextBatch = "next_batch"
                        }
                    }
                    
                    while true {
                        (data, response) = try await self.call(method: "POST",
                                                               path: "/_matrix/client/unstable/org.matrix.msc3814.v1/dehydrated_device/\(deviceIdUrlEncoded)/events",
                                                               body: "{\"next_batch\": \"\(next_batch)\"}",
                                                               disableUrlEncoding: true)
                        
                        guard let responseBody = try? decoder.decode(DehydratedDeviceEventsResponseBody.self, from: data),
                              let eventsJson = try? encoder.encode(responseBody.events),
                              let eventsString = String(data: eventsJson, encoding: .utf8)
                        else {
                            self.dehydrateRequestTask = nil
                            cryptoLogger.error("Failed to process /unstable/org.matrix.msc3814.v1/dehydrated_device/\(deviceIdUrlEncoded)/events response")
                            throw Matrix.Error("Failed to process /unstable/org.matrix.msc3814.v1/dehydrated_device/\(deviceIdUrlEncoded)/events response")
                        }
                        
                        if responseBody.events.count == 0 {
                            break
                        }
                        
                        next_batch = responseBody.nextBatch
                        cryptoLogger.debug("Device rehydration \(deviceId): Received event batch \(eventsString) for batch \(next_batch)")
                        try rehydrator.receiveEvents(events: eventsString)
                    }
                }
                catch {
                    cryptoLogger.error("Failed to rehydrate device, discarding and creating new one...")
                }
            }
            
            // Device dehydration
            let bytes = try Random.generateBytes(byteCount: 32)
            let ssKey = Data(bytes)
            try await self.secretStore?.saveSecretData(ssKey, type: M_DEHYDRATED_DEVICE)
            
            let dehydrator = try crypto.dehydratedDevices().create()
            let keysUploadRequest = try dehydrator.keysForUpload(deviceDisplayName: "\(self.creds.deviceId) (dehydrated)", pickleKey: ssKey)
            
            (data, response) = try await self.call(method: "PUT",
                                                   path: "/_matrix/client/unstable/org.matrix.msc3814.v1/dehydrated_device",
                                                   body: keysUploadRequest.body)
            
            guard let responseBody = try? decoder.decode(DehydratedDeviceResponseBody.self, from: data)
            else {
                self.dehydrateRequestTask = nil
                cryptoLogger.error("Failed to read device_id from device dehydration request")
                throw Matrix.Error("Failed to read device_id from device dehydration request")
            }
            
            cryptoLogger.debug("Successfully dehydrated device \(responseBody.deviceId)")
            self.dehydrateRequestTask = nil
            return nil
        }
        
        public func dehydrateDevice() async throws {
            // FIXME: Use a TaskGroup
            if let task = dehydrateRequestTask {
                syncLogger?.debug("Already dehydrating...  awaiting on the result")
                try await task.value
            } else {
                do {
                    dehydrateRequestTask = .init(priority: .background, operation: dehydrateDeviceTaskOperation)
                    try await dehydrateRequestTask?.value
                } catch {
                    self.dehydrateRequestTask = nil
                }
            }
        }
        
        // MARK: Session state management
        
        public func pause() async throws {
            // pause() doesn't actually make any API calls
            // It just tells our own local sync task to take a break
            syncLogger?.debug("Pausing session")
            self.keepSyncing = false
        }
        
        public func close() async throws {
            // close() is like pause; it doesn't make any API calls
            // It just tells our local sync task to shut down
            
            syncLogger?.debug("Closing session")
            self.keepSyncing = false
            if let task = syncRequestTask {
                syncLogger?.debug("Canceling sync task")
                task.cancel()
            }
            if let dehydrateDeviceTask = dehydrateRequestTask {
                syncLogger?.debug("Canceling device dehydration task")
                dehydrateDeviceTask.cancel()
            }
            
            syncLogger?.debug("Session closed")
        }
        
        // MARK: UIA
        
        public typealias UiaCompletionHandler = (UIAuthSession, Data) async throws -> Void
        
        public func uiaCall(method: String,
                            path: String,
                            requestDict: [String: Codable],
                            filter: ((UIAA.Flow) -> Bool)? = nil,
                            completion handler: UiaCompletionHandler? = nil
        ) async throws -> UIAuthSession? {
            let url = URL(string: path, relativeTo: self.baseUrl)!
            
            let uia = UIAuthSession(method: method, url: url,
                                    credentials: self.creds,
                                    requestDict: requestDict,
                                    completion: { (uias, data) in
                                                    logger.debug("UIA is complete.  Setting uiaSession back to nil")
                                                    await MainActor.run {
                                                        self.uiaSession = nil
                                                    }
                                                    if let handler = handler {
                                                        try await handler(uias, data)
                                                    }
                                                })
            logger.debug("Waiting for UIA to connect")
            try await uia.connect()
            switch uia.state {
            case .finished:
                // Yay, got it in one!  The server did not require us to authenticate again.
                logger.debug("UIA was not required for \(path, privacy: .public)")
                return nil
                
            case .connected(let uiaState):
                logger.debug("UIA is connected.  Must be completed to execute the API endpoint \(path, privacy: .public)")
                
                // At this point, there could potentially be many UIA flows available to us
                
                for flow in uiaState.flows {
                    logger.debug("Found UIA flow \(flow.stages, privacy: .public)")
                }

                // If the caller provided a filter to select from the flows,
                // we filter the flows with it and take the first one that passes
                
                if let flowFilter = filter {
                    logger.debug("Filtering \(uiaState.flows.count, privacy: .public) flows")
                    guard let flow = uiaState.flows.filter(flowFilter).first
                    else {
                        throw Matrix.Error("No compatible authentication flows")
                    }
                    
                    logger.debug("Selecting flow \(flow.stages, privacy: .public)")
                    await uia.selectFlow(flow: flow)
                } else {
                    logger.debug("No flow filter; \(uiaState.flows.count, privacy: .public) available flows")
                }
                
            case .inProgress(let uiaState, _):
                logger.debug("UIA is now in progress.  Must be completed to execute the API endpoint \(path)")
                for flow in uiaState.flows {
                    logger.debug("Found UIA flow \(flow.stages, privacy: .public)")
                }
            default:
                // The caller will have to complete UIA before the request can go through
                logger.debug("UIA is in some other state.  Client needs to complete UIA to execute API endpoint \(path, privacy: .public)")
            }
            
            await MainActor.run {
                self.uiaSession = uia
            }
            return uia
        }
        
        public func cancelUIA() async throws {
            await MainActor.run {
                self.uiaSession = nil
            }
        }
        
        // MARK: UIA endpoints
        
        /*
         This is the legacy Matrix API endpoint to update m.login.password
         */
        public func changePassword(newPassword: String) async throws {
            logger.debug("Changing password for user \(self.creds.userId.stringValue)")
            let path =  "/_matrix/client/v3/account/password"
            let _ = try await uiaCall(method: "POST", path: path,
                                      requestDict: ["new_password": newPassword],
                                      completion:  { (_,_) in
                                        logger.debug("Successfully changed password")
                                      })
        }
        
        /*
         This is the fancy new UIA-all-the-things version from my MSC
         */
        public func updateAuth(filter: @escaping (UIAA.Flow) -> Bool,
                               completion handler: UiaCompletionHandler? = nil
        ) async throws {
            logger.debug("Updating authentication for user \(self.creds.userId.stringValue)")
            let path =  "/_matrix/client/v3/account/auth"
            let uia = try await uiaCall(method: "POST", path: path,
                                        requestDict: [:],
                                        filter: filter,
                                        completion: { (us,data) in
                                            logger.debug("Successfully updated auth")
                                            if let handler = handler {
                                                try await handler(us,data)
                                            }
                                        })
        }
        
        public func setBsSpekePassword(_ handler: UiaCompletionHandler? = nil) async throws {
            try await updateAuth(filter: { (flow) -> Bool in
                                            flow.stages.contains(AUTH_TYPE_ENROLL_BSSPEKE_SAVE)
                                         },
                                 completion: handler)
            
        }
        
        public func deleteDevice(deviceId: String,
                                 completion handler: UiaCompletionHandler? = nil
        ) async throws {
            logger.debug("Deleting device for user \(self.creds.userId.stringValue)")
            let path =  "/_matrix/client/v3/devices/\(deviceId)"
            let uia = try await uiaCall(method: "DELETE",
                                        path: path,
                                        requestDict: [:],
                                        filter: { _ in true },
                                        completion: { (us,data) in
                                            logger.debug("Successfully deleted device")
                                            if let handler = handler {
                                                try await handler(us,data)
                                            }
                                        })
        }
        
        public func deactivateAccount(erase: Bool = false, completion handler: UiaCompletionHandler? = nil) async throws {
            logger.debug("Deactivating account for user \(self.creds.userId.stringValue)")
                        
            let path = "/_matrix/client/v3/account/deactivate"
            let uia = try await uiaCall(method: "POST",
                                        path: path,
                                        requestDict: [
                                            "erase": erase
                                        ],
                                        filter: { _ in true },
                                        completion: { (us,data) in
                                            logger.debug("Successfully deactivated account")
                                            if let handler = handler {
                                                try await handler(us,data)
                                            }
                                        })
        }
        
        // MARK: who Am I
        
        public func whoAmI() async throws -> UserId {
            return self.creds.userId
        }
        
        // MARK: Account Data
        
        public override func putAccountData(_ content: Codable, for eventType: String) async throws {
            try await super.putAccountData(content, for: eventType)
            await MainActor.run {
                self.accountData[eventType] = content
            }
        }
        
        public func addAccountDataHandler(filter: @escaping AccountDataFilter, handler: @escaping AccountDataHandler) {
            self.accountDataHandlers.append(contentsOf: [(filter,handler)])
        }
        
        // MARK: Rooms
        
        public override func getRoomStateEvents(roomId: RoomId) async throws -> [ClientEventWithoutRoomId] {
            logger.debug("getRoomStateEvents Getting room state events for room \(roomId)")
            let events = try await super.getRoomStateEvents(roomId: roomId)
            logger.debug("getRoomStateEvents Got \(events.count, privacy: .public) state events for \(roomId)")
            if let store = self.dataStore {
                logger.debug("getRoomStateEvents Saving events to data store")
                try await store.saveState(events: events, in: roomId)
            } else {
                logger.debug("getRoomStateEvents No data store - Not saving events")
            }
            if let room = self.rooms[roomId] {
                logger.debug("getRoomStateEvents Updating room object for \(roomId) with new events")
                await room.updateState(from: events)
            } else {
                logger.debug("getRoomStateEvents No current room object for \(roomId)")
            }
            logger.debug("getRoomStateEvents Returning \(events.count, privacy: .public) events for room \(roomId)")
            return events
        }
        
        @discardableResult
        public func getRoom<T: Matrix.Room>(roomId: RoomId,
                                            as type: T.Type = Matrix.Room.self,
                                            onLeave: (() async throws ->Void)? = nil
        ) async throws -> T? {
            logger.debug("getRoom Starting")
            if let existingRoom = self.rooms[roomId] as? T {
                logger.debug("getRoom \(roomId) Found room in the cache.  Done.")
                return existingRoom
            }
            
            // Apparently we don't already have a Room object for this one
            // Let's see if we can find the necessary data to construct it
            
            // Do we have this room in our data store?
            if let store = self.dataStore {
                logger.debug("getRoom \(roomId) Loading room from data store")
                let stateEvents = try await store.loadEssentialState(for: roomId)
                logger.debug("getRoom \(roomId) Loaded \(stateEvents.count, privacy: .public) state events")
                
                if stateEvents.count > 0 {
                
                    let timelineEvents = try await store.loadTimeline(for: roomId, limit: 25, offset: 0)
                    logger.debug("getRoom \(roomId) Loaded \(stateEvents.count, privacy: .public) timeline events")
                    //let timelineEvents = [ClientEventWithoutRoomId]()
                    
                    let accountDataEvents = try await store.loadAccountDataEvents(roomId: roomId, limit: 1000, offset: nil)
                    
                    let readReceipt = try await store.loadReadReceipt(roomId: roomId, threadId: "main")
                 
                
                    logger.debug("getRoom \(roomId) Constructing the room")
                    if let room = try? T(roomId: roomId,
                                         session: self,
                                         initialState: stateEvents,
                                         initialTimeline: timelineEvents,
                                         initialAccountData: accountDataEvents,
                                         initialReadReceipt: readReceipt,
                                         onLeave: onLeave
                    ) {
                        logger.debug("getRoom \(roomId) Adding new room to the cache")
                        await MainActor.run {
                            self.rooms[roomId] = room
                        }
                        return room
                    }
                }
            }
            
            // Ok we didn't have the room state cached locally
            logger.debug("getRoom \(roomId) Failed to load room from data store")
            // Maybe the server knows about this room?
            logger.debug("getRoom \(roomId) Asking the server for room state")
            guard let events = try? await getRoomStateEvents(roomId: roomId)
            else {
                logger.error("getRoom \(roomId) Failed to get room state events")
                return nil
            }
            logger.debug("getRoom \(roomId) Got \(events.count, privacy: .public) events from the server")
            
            if let room = try? T(roomId: roomId,
                                 session: self,
                                 initialState: events,
                                 initialTimeline: [],
                                 onLeave: onLeave
            ) {
                logger.debug("getRoom \(roomId) Created room.  Adding to cache.")
                await MainActor.run {
                    self.rooms[roomId] = room
                }
                return room
            } else {
                logger.error("getRoom \(roomId) Failed to create room from the server's state events")
                // Looks like we got nothing
                return nil
            }
            

        }
        
        public var systemNoticesRoom: Matrix.Room? {
            // FIXME: Make this do something
            nil
        }
        
        public func getSpaceRoom(roomId: RoomId) async throws -> Matrix.SpaceRoom? {
            if let existingSpace = self.rooms[roomId] as? Matrix.SpaceRoom {
                return existingSpace
            }
            
            // Apparently we don't already have a Space object for this one
            // Let's see if we can find the necessary data to construct it
            
            // Do we have this room in our data store?
            if let store = self.dataStore {
                let events = try await store.loadEssentialState(for: roomId)
                if events.count > 0 {
                    if let space = try? Matrix.SpaceRoom(roomId: roomId, session: self, initialState: events)
                    {
                        await MainActor.run {
                            self.rooms[roomId] = space
                        }
                        return space
                    }
                }
            }
            
            // Ok we didn't have the room state cached locally
            // Maybe the server knows about this room?
            let events = try await getRoomStateEvents(roomId: roomId)
            if let space = try? Matrix.SpaceRoom(roomId: roomId, session: self, initialState: events) {
                await MainActor.run {
                    self.rooms[roomId] = space
                }
                return space
            }
            
            // Looks like we got nothing
            return nil
        }
        
        public func getInvitedRoom(roomId: RoomId) async throws -> Matrix.InvitedRoom? {
            if let room = self.invitations[roomId] {
                return room
            }
            
            if let store = self.dataStore {
                let events = try await store.loadStrippedState(for: roomId)
                if let room = try? Matrix.InvitedRoom(session: self, roomId: roomId, stateEvents: events) {
                    await MainActor.run {
                        self.invitations[roomId] = room
                    }
                    return room
                }
            }
            
            // Whoops, looks like we couldn't find what we needed
            return nil
        }
        
        public func deleteInvitedRoom(roomId: RoomId) async throws {
            await MainActor.run {
                self.invitations.removeValue(forKey: roomId)
            }
            if let store = self.dataStore {
                let count = try await store.deleteStrippedState(for: roomId)
                logger.debug("Purged \(count) stripped state events for invited room \(roomId)")
            }
        }
        
        public func getSpaceChildRoom(roomId: RoomId) async throws -> Matrix.SpaceChildRoom? {
            if let room = self.spaceChildRooms[roomId] {
                return room
            }
            
            if let store = self.dataStore,
               let events = try? await store.loadStrippedState(for: roomId),
               let room = try? Matrix.SpaceChildRoom(session: self, roomId: roomId, stateEvents: events)
            {
                await MainActor.run {
                    self.spaceChildRooms[roomId] = room
                }
                return room
            }
            
            // Whoops, looks like we couldn't find what we needed
            return nil
        }
        
        // MARK: Users
        
        public func getUser(userId: UserId) -> Matrix.User {
            if let existingUser = self.users[userId] {
                return existingUser
            }
            
            let user = Matrix.User(userId: userId, session: self)
            self.users[userId] = user
            return user
        }
        
        public func ignoreUser(userId: UserId) async throws {
            let existingIgnoreList = try await self.getAccountData(for: M_IGNORED_USER_LIST, of: IgnoredUserListContent.self)?.ignoredUsers ?? []
            if !existingIgnoreList.contains(userId) {
                logger.debug("Adding user \(userId.stringValue) to the ignore list")
                let newContent = IgnoredUserListContent(ignoring: existingIgnoreList + [userId])
                try await self.putAccountData(newContent, for: M_IGNORED_USER_LIST)
                logger.debug("Ignore list is now \(newContent.ignoredUsers)")
            } else {
                logger.debug("Already ignoring user \(userId.stringValue) - No further action is necessary")
            }
        }
        
        public func unignoreUser(userId: UserId) async throws {
            let existingIgnoreList = try await self.getAccountData(for: M_IGNORED_USER_LIST, of: IgnoredUserListContent.self)?.ignoredUsers ?? []
            if existingIgnoreList.contains(userId) {
                logger.debug("Removing user \(userId) from the ignore list")
                let newContent = IgnoredUserListContent(ignoring: existingIgnoreList.filter { $0 != userId })
                try await self.putAccountData(newContent, for: M_IGNORED_USER_LIST)
                logger.debug("Ignore list is now \(newContent.ignoredUsers)")
            } else {
                logger.debug("Already not ignoring user \(userId.stringValue) - No further action is necessary")
            }
        }
        
        
        // MARK: Sending messages
                
        override public func sendMessageEvent(to roomId: RoomId,
                                              type: String,
                                              content: Codable
        ) async throws -> EventId {
            // First, do we know about this room at all?
            guard let room = try await getRoom(roomId: roomId)
            else {
                throw Matrix.Error("Unkown room [\(roomId)]")
            }
            
            // Is the room encrypted?
            guard let params = room.encryptionParams
            else {
                // If not, easy peasy -- just send the message
                return try await super.sendMessageEvent(to: roomId,
                                                        type: type,
                                                        content: content)
            }
            
            // Reactions are also not encrypted, even if the room itself is encrypted
            if type == M_REACTION {
                return try await super.sendMessageEvent(to: roomId,
                                                        type: type,
                                                        content: content)
            }
            
            // -------------------------------------------------------------------------------------------------------
            // If we're still here, then we need to encrypt the message before we can send it
            
            return try await self.sendEncryptedMessageEvent(room: room, type: type, content: content)
        }
        
        // Internal elper function for sending encrypted messages
        func sendEncryptedMessageEvent(room: Room, type: String, content: Codable) async throws -> EventId {
            
            // cvw: I found a nice comment on the encrypt() function in the Matrix Rust SDK
            // https://github.com/matrix-org/matrix-rust-sdk/blob/main/bindings/matrix-sdk-crypto-ffi/src/machine.rs
            /// **Note**: A room key needs to be shared with the group of users that are
            /// members in the given room. If this is not done this method will panic.
            ///
            /// The usual flow to encrypt an event using this state machine is as
            /// follows:
            ///
            /// 1. Get the one-time key claim request to establish 1:1 Olm sessions for
            ///    the room members of the room we wish to participate in. This is done
            ///    using the [`get_missing_sessions()`](#method.get_missing_sessions)
            ///    method. This method call should be locked per call.
            ///
            /// 2. Share a room key with all the room members using the
            ///    [`share_room_key()`](#method.share_room_key). This method
            ///    call should be locked per room.
            ///
            /// 3. Encrypt the event using this method.
            ///
            /// 4. Send the encrypted event to the server.
            ///
            /// After the room key is shared steps 1 and 2 will become noops, unless
            /// there's some changes in the room membership or in the list of devices a
            /// member has.

            let logger = self.cryptoLogger
            let roomId = room.roomId
            
            guard let params = room.encryptionParams
            else {
                logger.error("Can't send an encrypted message to unencrypted room \(roomId, privacy: .public)")
                throw Matrix.Error("Can't send encrypted message to an unencrypted room")
            }
            
            guard let roomHistoryVisibility = try await room.getHistoryVisibility()
            else {
                logger.error("Cannot encrypt because we cannot determine history visibility for room \(roomId, privacy: .public)")
                throw Matrix.Error("Cannot encrypt because we cannot determine history visibility for room \(roomId)")
            }

            // NOTE: Depending on the room's history visibility we should include either:
            //       * joined members only (for history visiblity == .joined)
            //       * joined AND invited members (for any other history visibility)
            let members = try await getRoomMembers(roomId: roomId)
            let joined: Set<UserId> = members[.join] ?? []
            let invited: Set<UserId> = members[.invite] ?? []
            let userIds: [UserId]
            if roomHistoryVisibility == .joined {
                userIds = Array(joined)
            } else {
                userIds = Array(joined.union(invited))
            }
            let users = userIds.map { $0.stringValue } // Convert back to String because the Rust SDK doesn't know about our types
            logger.debug("Found \(users.count) users in the room: \(users)")
            
            try await cryptoQueue.run {
                try await self.queryKeys(for: userIds)
                
                if let missingSessionsRequest = try self.crypto.getMissingSessions(users: users) {
                    // Send the missing sessions request
                    logger.debug("Sending missing sessions request")
                    try await self.sendCryptoRequest(request: missingSessionsRequest)
                }
            }
            
            // FIXME: WhereTF do we get the "only allow trusted devices" setting?
            let onlyTrusted = false
            
            // I am now dumber for having written this
            // Unfortunately our version of the enum needs to be derived from String, while theirs seems to be a number
            func translate(_ ours: Matrix.Room.HistoryVisibility) -> MatrixSDKCrypto.HistoryVisibility {
                switch ours {
                case .shared:
                    return .shared
                case .invited:
                    return .invited
                case .joined:
                    return .joined
                case .worldReadable:
                    return .worldReadable
                }
            }
            
            let settings = EncryptionSettings(algorithm: .megolmV1AesSha2,
                                              rotationPeriod: params.rotationPeriodMs ?? RoomEncryptionContent.defaultRotationPeriodMs,
                                              rotationPeriodMsgs: params.rotationPeriodMsgs ?? RoomEncryptionContent.defaultRotationPeriodMsgs,
                                              historyVisibility: translate(roomHistoryVisibility),
                                              onlyAllowTrustedDevices: onlyTrusted)
                      
            try await cryptoQueue.run {
                logger.debug("Computing room key sharing")
                let shareRoomKeyRequests = try self.crypto.shareRoomKey(roomId: roomId.description,
                                                                        users: users,
                                                                        settings: settings)
                logger.debug("Sending \(shareRoomKeyRequests.count) share room key requests")
                for request in shareRoomKeyRequests {
                    try await self.sendCryptoRequest(request: request)
                }
            }
            
            let encoder = JSONEncoder()
            let binaryContent = try encoder.encode(content)
            let stringContent = String(data: binaryContent, encoding: .utf8)!
            logger.debug("Encrypting plaintext message content = [\(stringContent)]")
            let encryptedString = try self.crypto.encrypt(roomId: roomId.description,
                                                          eventType: type,
                                                          content: stringContent)
            //logger.debug("Got encrypted string = [\(encryptedString)]")
            let encryptedData = encryptedString.data(using: .utf8)!
            let encryptedContent = try Matrix.decodeEventContent(of: M_ROOM_ENCRYPTED, from: encryptedData)
            logger.debug("Sending encrypted message")
            let eventId = try await super.sendMessageEvent(to: roomId,
                                                           type: M_ROOM_ENCRYPTED,
                                                           content: encryptedContent)
            logger.debug("Got event id \(eventId)")

            logger.debug("Sending crypto requests post-message")
            try? await sendOutgoingCryptoRequests()
            logger.debug("Saving key backup")
            try? await saveKeysToBackup()

            logger.debug("Returning event id \(eventId)")
            return eventId
        }
        
        // MARK: Read Receipts
        override public func sendReadReceipt(roomId: RoomId,
                                             threadId: EventId? = nil,
                                             eventId: EventId
        ) async throws {
            if let store = self.dataStore {
                try await store.saveReadReceipt(roomId: roomId,
                                                threadId: threadId ?? "main",
                                                eventId: eventId)
            }
            
            try await super.sendReadReceipt(roomId: roomId,
                                            threadId: threadId,
                                            eventId: eventId)
        }

        // MARK: Encrypted Media
        
        public func encryptAndUploadData(plaintext: Data, contentType: String) async throws -> mEncryptedFile {
            let key = try Random.generateBytes(byteCount: 32)
            let iv = try Random.generateBytes(byteCount: 8) + Array<UInt8>(repeating: 0, count: 8)
            var cryptor = Cryptor(operation: .encrypt,
                                  algorithm: Cryptor.Algorithm.aes,
                                  mode: Cryptor.Mode.CTR,
                                  padding: .NoPadding,
                                  key: key,
                                  iv: iv)
            guard let encryptedBytes = cryptor.update(plaintext)?.final(),
                  let sha256sum = Digest(algorithm: .sha256).update(byteArray: encryptedBytes)?.final()
            else {
                throw Matrix.Error("Failed to encrypt and hash")
            }
            let ciphertext = Data(encryptedBytes)
            guard let mxc = try? await self.uploadData(data: ciphertext, contentType: contentType)
            else {
                logger.error("Failed to upload encrypted data")
                throw Matrix.Error("Failed to upload encrypted data")
            }
            
            guard let unpaddedSHA256 = Base64.unpadded(sha256sum),
                  let unpaddedIV = Base64.unpadded(iv),
                  let jwk = Matrix.JWK(key)
            else {
                logger.error("Failed to remove base64 padding")
                throw Matrix.Error("Failed to remove base64 padding")
            }
            
            return mEncryptedFile(url: mxc,
                                  key: jwk,
                                  iv: unpaddedIV,
                                  hashes: ["sha256": unpaddedSHA256],
                                  v: "v2")
        }
        
        public func encryptAndUploadFile(url: URL, contentType: String) async throws -> mEncryptedFile {
            guard url.isFileURL
            else {
                logger.error("URL must be a local file URL")
                throw Matrix.Error("URL must be a local file URL")
            }
            let data = try Data(contentsOf: url)
            return try await encryptAndUploadData(plaintext: data, contentType: contentType)
        }
        
        public func downloadAndDecryptData(_ info: mEncryptedFile) async throws -> Data {
            logger.debug("Downloading and decrypting encrypted data from \(info.url, privacy: .public)")
            guard let ciphertext = try? await self.downloadData(mxc: info.url)
            else {
                logger.error("Failed to download encrypted data from \(info.url, privacy: .public)")
                throw Matrix.Error("Failed to download media data")
            }
            
            logger.debug("Checking SHA256 hash for \(info.url, privacy: .public)")
            // Cryptographic doom principle: Verify that the ciphertext is what we expected,
            // before we do anything crazy like trying to decrypt
            guard let gotSHA256 = Digest(algorithm: .sha256).update(ciphertext)?.final(),
                  let wantedSHA256base64unpadded = info.hashes["sha256"],
                  let wantedSHA256base64 = Base64.ensurePadding(wantedSHA256base64unpadded),
                  let wantedSHA256data = Data(base64Encoded: wantedSHA256base64),
                  gotSHA256.count == wantedSHA256data.count
            else {
                logger.error("Failed to get sha256 hashes")
                throw Matrix.Error("Failed to get sha256 hashes")
            }
            let wantedSHA256 = [UInt8](wantedSHA256data)
            // WTF, CommonCrypto doesn't have a Digest.verify() ???!?!?!
            // Verify manually that the two hashes match... grumble grumble grumble
            var match = true
            for i in gotSHA256.indices {
                if gotSHA256[i] != wantedSHA256[i] {
                    match = false
                }
            }
            guard match == true else {
                logger.error("SHA256 hash does not match!")
                throw Matrix.Error("SHA256 hash does not match!")
            }
            
            // OK now it's finally safe to (try to) decrypt this thing
            
            logger.debug("Got key \(info.key.k) and iv \(info.iv) for \(info.url, privacy: .public)")
            
            guard let key = Base64.data(info.key.k, urlSafe: true),
                  let iv = Base64.data(info.iv)
            else {
                logger.error("Couldn't parse key and IV")
                throw Matrix.Error("Couldn't parse key and IV")
            }
            
            var cryptor = Cryptor(operation: .decrypt,
                                  algorithm: .aes,
                                  mode: .CTR,
                                  padding: .NoPadding,
                                  key: [UInt8](key),
                                  iv: [UInt8](iv)
            )
            
            guard let decryptedBytes = cryptor.update(ciphertext)?.final()
            else {
                logger.error("Failed to decrypt ciphertext")
                throw Matrix.Error("Failed to decrypt ciphertext")
            }
            
            logger.debug("Decryption success for \(info.url, privacy: .public)")
            return Data(decryptedBytes)
        }
        
        /*
        public func downloadAndDecryptFile(_ info: mEncryptedFile,
                                           allowRedirect: Bool = true,
                                           delegate: URLSessionDownloadDelegate? = nil
        ) async throws -> URL {
            logger.debug("Downloading and decrypting encrypted file from \(info.url, privacy: .public)")
            
            // FIXME: Figure out what our decrypted cache dir should be
            /* // Argh why does none of this crap work?  It doesn't actually create the directories...
            let topLevel = URL.applicationSupportDirectory
            let applicationName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "matrix.swift"
            let decryptedDir = topLevel.appendingPathComponent(applicationName, isDirectory: true)
                                       .appendingPathComponent(creds.userId.stringValue, isDirectory: true)
                                       .appendingPathComponent("decrypted", isDirectory: true)
            try FileManager.default.createDirectory(at: decryptedDir, withIntermediateDirectories: true)
            let domainDecryptedDir = decryptedDir.appendingPathComponent(info.url.serverName, isDirectory: true)
                                                 .standardizedFileURL
            try FileManager.default.createDirectory(at: domainDecryptedDir, withIntermediateDirectories: true)
            let decryptedUrl = domainDecryptedDir.appendingPathComponent(info.url.mediaId)
                                                 .standardizedFileURL
            */
            let decryptedUrl = URL.temporaryDirectory.appendingPathComponent("\(info.url.serverName):\(info.url.mediaId)")
            // First check: Are we already working on this one?
            if let task = self.downloadAndDecryptTasks[info.url] {
                logger.debug("Already working on downloading \(info.url, privacy: .public)")
                return try await task.value
            }
            
            if FileManager.default.isReadableFile(atPath: decryptedUrl.path()) {
                logger.debug("Found downloaded file for \(info.url, privacy: .public)")
                return decryptedUrl
            }
            
            let task = Task {
                logger.debug("Starting download task for \(info.url, privacy: .public)")
                guard let ciphertextUrl = try? await self.downloadFile(mxc: info.url, allowRedirect: allowRedirect, delegate: delegate)
                else {
                    logger.error("Failed to download encrypted file from \(info.url, privacy: .public)")
                    throw Matrix.Error("Failed to download media file")
                }
                
                logger.debug("Checking SHA256 hash for \(info.url, privacy: .public)")
                var sha256 = Digest(algorithm: .sha256)
                guard let sha256file = try? FileHandle(forReadingFrom: ciphertextUrl)
                else {
                    logger.error("Failed to open downloaded file for \(info.url)")
                    throw Matrix.Error("Failed to open downloaded file")
                }
                
                while let data = try sha256file.read(upToCount: 1<<20) {
                    sha256.update(data: data)
                }
                let gotSHA256 = sha256.final()
                try sha256file.close()
                
                guard let wantedSHA256base64unpadded = info.hashes["sha256"],
                      let wantedSHA256base64 = Base64.ensurePadding(wantedSHA256base64unpadded),
                      let wantedSHA256data = Data(base64Encoded: wantedSHA256base64)
                else {
                    logger.error("Couldn't parse stored SHA256 hash for \(info.url)")
                    throw Matrix.Error("Couldn't parse stored SHA256 hash")
                }
                let wantedSHA256 = [UInt8](wantedSHA256data)
                
                guard gotSHA256.count == 32,
                      wantedSHA256.count == 32
                else {
                    logger.error("Hash lengths are not correct for \(info.url)")
                    throw Matrix.Error("Hash lengths are not correct")
                }
                // WTF, CommonCrypto doesn't have a Digest.verify() ???!?!?!
                // Verify manually that the two hashes match... grumble grumble grumble
                var match = true
                for i in gotSHA256.indices {
                    if gotSHA256[i] != wantedSHA256[i] {
                        match = false
                    }
                }
                guard match == true else {
                    logger.error("SHA256 hash does not match for \(info.url)")
                    throw Matrix.Error("SHA256 hash does not match!")
                }
                logger.debug("SHA256 hash checks out OK for \(info.url)")
                
                // OK now it's finally safe to (try to) decrypt this thing
                
                logger.debug("Got key \(info.key.k) and iv \(info.iv) for \(info.url, privacy: .public)")
                
                guard let key = Base64.data(info.key.k, urlSafe: true),
                      let iv = Base64.data(info.iv)
                else {
                    logger.error("Couldn't parse key and IV for \(info.url)")
                    throw Matrix.Error("Couldn't parse key and IV")
                }
                
                var cryptor = StreamCryptor(operation: .decrypt,
                                            algorithm: .aes,
                                            mode: .CTR,
                                            padding: .NoPadding,
                                            key: [UInt8](key),
                                            iv: [UInt8](iv)
                )
                
                logger.debug("Trying to open input file for \(ciphertextUrl)")
                guard let encrypted = try? FileHandle(forReadingFrom: ciphertextUrl)
                else {
                    logger.error("Couldn't open encrypted file for \(info.url)")
                    throw Matrix.Error("Couldn't open encrypted file")
                }

                var outputFile: FileHandle?
                await MainActor.run {
                    outputFile = try? FileHandle(forWritingTo: decryptedUrl)
                }
                logger.debug("Trying to open output file for \(decryptedUrl)")
                guard let decrypted = outputFile
                else {
                    logger.error("Couldn't open file for decrypted data for \(info.url)")
                    //let parentExists = FileManager.default.fileExists(atPath: domainDecryptedDir.absoluteString)
                    //logger.debug("Parent directory exists? \(parentExists) for \(info.url)")
                    throw Matrix.Error("Couldn't open file for decrypted data")
                }
                
                while let data = try encrypted.read(upToCount: 1<<20) {
                    
                    var buffer = Array<UInt8>(repeating: 0, count: cryptor.getOutputLength(inputByteCount: data.count))
                    let (count, status) = cryptor.update(dataIn: data, byteArrayOut: &buffer)
                    if status == Status.success {
                        try decrypted.write(contentsOf: buffer)
                    } else {
                        logger.error("Failed to decrypt file for \(info.url)")
                        throw Matrix.Error("Failed to decrypt")
                    }
                }
                // Shouldn't need to do anything else for CTR mode
                
                logger.debug("Closing file handles for \(info.url)")
                // Close the file handles
                try encrypted.close()
                try decrypted.close()
                
                logger.debug("Successfully decrypted \(info.url)")
                // Return the URL of the decrypted file
                return decryptedUrl
            }
            self.downloadAndDecryptTasks[info.url] = task
            let result = try await task.value
            logger.debug("Finished downloadAndDecryptFile for \(info.url)")
            return result
        }
        */

        // MARK: Fetching Messages
        
        override public func getMessages(roomId: RoomId,
                                         forward: Bool = false,
                                         from startToken: String? = nil,
                                         to endToken: String? = nil,
                                         limit: UInt? = 25
        ) async throws -> RoomMessagesResponseBody {
            var responseBody = try await super.getMessages(roomId: roomId, forward: forward, from: startToken, to: endToken, limit: limit)
            
            if let store = dataStore {
                // Don't save state here, because it could be way out of date
                // But do save the timeline events for offline use
                try await store.saveTimeline(events: responseBody.chunk, in: roomId)
            }

            return responseBody
        }
        
        public func loadRelatedEvents(for eventId: EventId, in roomId: RoomId, relType: String, type: String?) async throws -> [ClientEventWithoutRoomId] {
            if let store = self.dataStore {
                let reactionEvents = try await store.loadRelatedEvents(for: eventId, in: roomId, relType: M_ANNOTATION, type: type)
                return reactionEvents
            } else {
                return []
            }
        }
        
        public override func getRelatedMessages(roomId: RoomId,
                                                eventId: EventId,
                                                relType: String,
                                                from startToken: String? = nil,
                                                to endToken: String? = nil,
                                                limit: UInt? = 25
        ) async throws -> RelatedMessagesResponseBody {
            let response = try await super.getRelatedMessages(roomId: roomId, eventId: eventId, relType: relType, from: startToken, to: endToken, limit: limit)
            
            let events = response.chunk
            
            if let store = dataStore {
                try await store.saveTimeline(events: events, in: roomId)
            }
            
            return response
        }
        
        public override func getThreadedMessages(roomId: RoomId,
                                                 threadId: EventId,
                                                 from startToken: String? = nil,
                                                 to endToken: String? = nil,
                                                 limit: UInt? = 25
        ) async throws -> RelatedMessagesResponseBody {
            return try await self.getRelatedMessages(roomId: roomId, eventId: threadId, relType: M_THREAD, from: startToken, to: endToken, limit: limit)
        }
        
        // MARK: Decrypting Messsages
        
        public func decryptMessageEvent(_ encryptedEvent: ClientEventWithoutRoomId,
                                         in roomId: RoomId
        ) throws -> ClientEventWithoutRoomId {
            logger.debug("\(self.creds.userId) Trying to decrypt event \(encryptedEvent.eventId)")
            let encoder = JSONEncoder()
            let encryptedData = try encoder.encode(encryptedEvent)
            let encryptedString = String(data: encryptedData, encoding: .utf8)!
            //let contentData = try encoder.encode(event.content)
            //let contentString = String(data: contentData, encoding: .utf8)!
            //logger.debug("Encoded event string = \(encryptedString)")
            //logger.debug("Encoded event content = \(contentString)")
            //logger.debug("Trying to decrypt...")
            guard let decryptedStruct = try? crypto.decryptRoomEvent(event: encryptedString,
                                                                     roomId: "\(roomId)",
                                                                     handleVerificationEvents: true,
                                                                     strictShields: false)
            else {
                logger.error("\(self.creds.userId) Failed to decrypt event \(encryptedEvent.eventId)")
                throw Matrix.Error("Failed to decrypt")
            }
            let decryptedString = decryptedStruct.clearEvent
            logger.debug("Decrypted event:\t[\(decryptedString)]")
            
            let decoder = JSONDecoder()
            guard let decryptedMinimalEvent = try? decoder.decode(MinimalEvent.self, from: decryptedString.data(using: .utf8)!)
            else {
                logger.error("\(self.creds.userId) Failed to decode decrypted event")
                throw Matrix.Error("Failed to decode decrypted event")
            }
            return try ClientEventWithoutRoomId(content: decryptedMinimalEvent.content,
                                                eventId: encryptedEvent.eventId,
                                                originServerTS: encryptedEvent.originServerTS,
                                                sender: encryptedEvent.sender,
                                                // stateKey should be nil, since we decrypted something; must not be a state event.
                                                type: decryptedMinimalEvent.type,
                                                unsigned: encryptedEvent.unsigned)
        }
        
        // MARK: Deleting events
        
        public func deleteEvent(_ eventId: EventId, in roomId: RoomId) async throws {
            if let store = self.dataStore {
                try await store.deleteEvent(eventId, in: roomId)
            }
        }
        
        // MARK: Devices
        
        public func getCryptoDevices(userId: UserId) -> [CryptoDevice] {
            guard let devices = try? self.crypto.getUserDevices(userId: "\(userId)", timeout: 0)
            else {
                return []
            }
            return devices
        }
        
        public var devices: [CryptoDevice] {
            self.getCryptoDevices(userId: self.creds.userId)
        }
        
        public var device: CryptoDevice? {
            try? self.crypto.getDevice(userId: self.creds.userId.description, deviceId: self.creds.deviceId.description, timeout: 0)
        }
        
        // MARK: Secret Storage
        public func enableSecretStorage(defaultKey: SecretStorageKey) async throws {
            
            if self.secretStore == nil {
                self.secretStore = try await SecretStore(session: self, ssk: defaultKey)
            }
            
            guard let store = self.secretStore
            else {
                logger.error("Failed to enable secret storage")
                throw Matrix.Error("Failed to enable secret storage")
            }
            
            switch store.state {
            case .online(let existingDefaultKeyId):
                logger.debug("Secret storage is already online with keyId \(existingDefaultKeyId, privacy: .public)")
                return
            default:
                logger.debug("Attempting to bring secret storage online with keyId \(defaultKey.keyId, privacy: .public)")
                try await store.addNewDefaultKey(defaultKey)
            }
        }
        
        // MARK: Cross Signing
        
        @discardableResult
        public func setupCrossSigning() async throws -> UIAuthSession? {
            let logger: os.Logger = Logger(subsystem: "matrix", category: "XSIGN")
            logger.debug("Setting up")
            
            func ensureMyDeviceIsVerified() async throws {
                logger.debug("Looking for crypto device \(self.creds.deviceId)")
                if let device = try? self.crypto.getDevice(userId: self.creds.userId.stringValue, deviceId: self.creds.deviceId, timeout: 0),
                   device.crossSigningTrusted
                {
                    logger.debug("Device \(self.creds.deviceId, privacy: .public) is already cross-signed")
                    return
                } else {
                    logger.debug("Generating signature upload request for device \(self.creds.deviceId)")
                    let signatureUploadRequest: SignatureUploadRequest = try self.crypto.verifyDevice(userId: self.creds.userId.stringValue, deviceId: self.creds.deviceId)
                    // Why is this type different from the normal crypto Request?
                    // Turns out that this one doesn't need to be marked as sent after we're done, and that's why it's not a normal .signatureUpload request with a request id
                    // But poljar says it's OK if we just make up a request id and mark it as sent like anything else
                    // So that is what we are going to do
                    let request: MatrixSDKCrypto.Request = .signatureUpload(requestId: "xsign-\(self.creds.deviceId)", body: signatureUploadRequest.body)
                    logger.debug("Sending signature upload request for device \(self.creds.deviceId)")
                    try await sendCryptoRequest(request: request)
                    logger.debug("Successfully uploaded signature for device \(self.creds.deviceId)")
                }
            }
            
            // First thing to check: Do we already have all of our cross-signing keys?
            let status = self.crypto.crossSigningStatus()
            if status.hasMaster && status.hasSelfSigning && status.hasUserSigning {
                // Also ensure that our current device key is signed
                try await ensureMyDeviceIsVerified()

                // Nothing more to be done here
                logger.debug("Already all set up.  Done.")
                return nil
            }
            
            // If we don't have our keys, maybe they are on the server
            // (Maybe we created them on another device and uploaded them)
            guard secretStorageOnline,
                  let store = self.secretStore
            else {
                logger.error("No secret store")
                throw Matrix.Error("No secret store")
            }
            
            logger.debug("Looking for keys on the server")
            // Look in the secret store for our cross-signing keys
            if let privateMSK = try await store.getSecretString(type: M_CROSS_SIGNING_MASTER),
               let privateSSK = try await store.getSecretString(type: M_CROSS_SIGNING_SELF_SIGNING),
               let privateUSK = try await store.getSecretString(type: M_CROSS_SIGNING_USER_SIGNING)
            {
                logger.debug("Found keys on the server")
                let export = CrossSigningKeyExport(masterKey: privateMSK, selfSigningKey: privateSSK, userSigningKey: privateUSK)
                try self.crypto.importCrossSigningKeys(export: export)
                
                // Also ensure that our current device key is signed
                try await ensureMyDeviceIsVerified()
                
                // Success!  And no need to do UIA!
                return nil
            }
            
            // If we're still here, then we need to bootstrap our cross signing, ie generate a new set of keys
            logger.debug("Need to bootstrap")
            let result = try self.crypto.bootstrapCrossSigning()
            
            logger.debug("Exporting keys")
            guard let export = try self.crypto.exportCrossSigningKeys(),
                  let privateMSK = export.masterKey,
                  let privateSSK = export.selfSigningKey,
                  let privateUSK = export.userSigningKey
            else {
                logger.error("Failed to export new cross-signing keys")
                throw Matrix.Error("Failed to export new cross-signing keys")
            }
            
            // Upload the signing keys
            logger.debug("Master key:       \(result.uploadSigningKeysRequest.masterKey)")
            logger.debug("Self-signing key: \(result.uploadSigningKeysRequest.selfSigningKey)")
            logger.debug("User-signing key: \(result.uploadSigningKeysRequest.userSigningKey)")
            let decoder = JSONDecoder()
            let masterKey = try decoder.decode(CrossSigningKey.self, from: result.uploadSigningKeysRequest.masterKey.data(using: .utf8)!)
            let selfSigningKey = try decoder.decode(CrossSigningKey.self, from: result.uploadSigningKeysRequest.selfSigningKey.data(using: .utf8)!)
            let userSigningKey = try decoder.decode(CrossSigningKey.self, from: result.uploadSigningKeysRequest.userSigningKey.data(using: .utf8)!)

            let path = "/_matrix/client/v3/keys/device_signing/upload"
            let url = URL(string: path, relativeTo: self.baseUrl)!
            
            // WARNING: This endpoint uses the user-interactive auth, so unless we call it *immediately* after login, we should expect to receive a new UIA session that must be completed before the request can take effect
            logger.debug("Sending keys in a POST request to the server")
            let uia = UIAuthSession(method: "POST", url: url,
                                    credentials: self.creds,
                                    requestDict: [
                                        "master_key": masterKey,
                                        "self_signing_key": selfSigningKey,
                                        "user_signing_key": userSigningKey,
                                    ]
            ) { (_,_) in
                // Completion handler that runs after the UIA completes successfully
                logger.debug("UIA completed successfully")
                
                // Ensure that all device keys have been uploaded before uploading signatures
                if let keyUploadRequest = result.uploadKeysRequest {
                    try await self.sendCryptoRequest(request: keyUploadRequest)
                }
                
                // Upload the new cross-signing keys to secret storage, so we can use them on other devices
                logger.debug("Saving keys to secret storage")
                try await store.saveSecretString(privateMSK, type: M_CROSS_SIGNING_MASTER)
                try await store.saveSecretString(privateSSK, type: M_CROSS_SIGNING_SELF_SIGNING)
                try await store.saveSecretString(privateUSK, type: M_CROSS_SIGNING_USER_SIGNING)
                
                // Also upload the signature request in `result.signatureRequest`
                logger.debug("Uploading signatures")
                // WTF man, why do we have Request.signatureUpload AND SignatureUploadRequest ???
                let requestId = UInt16.random(in: 0...UInt16.max)
                let request: Request = .signatureUpload(requestId: "\(requestId)", body: result.uploadSignatureRequest.body)
                try await self.sendCryptoRequest(request: request)
            }
            logger.debug("Waiting for UIA to connect")
            try await uia.connect()
            switch uia.state {
            case .finished:
                // Yay, got it in one!  The server did not require us to authenticate again.
                logger.debug("UIA was not required to upload keys")
                return nil
            case .connected(let uiaState):
                logger.debug("UIA is connected.  Must be completed to upload keys.")
                for flow in uiaState.flows {
                    logger.debug("Found UIA flow \(flow.stages)")
                }
            case .inProgress(let uiaState, _):
                logger.debug("UIA is now in progress.  Must be completed to upload keys.")
                for flow in uiaState.flows {
                    logger.debug("Found UIA flow \(flow.stages)")
                }
            default:
                // The caller will have to complete UIA before the request can go through
                logger.debug("Client needs to complete UIA to upload keys")
            }
            
            // Update our state to reflect the need to do UIA
            await MainActor.run {
                self.uiaSession = uia
            }
            // And return the session object in case the caller needs it
            return uia
        }
        
        // MARK: Key backup
        
        public func setupKeyBackup() async throws {
            logger.debug("Setting up key backup")
            
            // Step 1 - Maybe we're already good to go?
            if self.crypto.backupEnabled() {
                logger.debug("Key backup is already enabled.  Done.")
                return
            }
            
            // Step 2 - Maybe we already set up key backup on another device?
            // Step 2.1 - Do we have an existing backup on the server?
            logger.debug("Looking for current key backup")
            if let info = try? await getCurrentKeyBackupVersionInfo() {
                logger.debug("Found key backup with version \(info.version)")
                // Step 2.2 - Can we get the recovery key from secret storage?  And if so, does it match our current backup's public key?
                if let store = self.secretStore {
                    logger.debug("Looking for recovery key in the secret store")
                    
                    if let recoveryPrivateKey = try await store.getSecretString(type: M_MEGOLM_BACKUP_V1) {
                        // Cool, this is the key that we should use.
                        logger.debug("Found recovery key in secret storage")
                        
                        let recoveryKey = try MatrixSDKCrypto.BackupRecoveryKey.fromBase64(key: recoveryPrivateKey)
                        let backupPublicKey = recoveryKey.megolmV1PublicKey()
                        
                        guard backupPublicKey.publicKey == info.authData.publicKey
                        else {
                            logger.error("Recovery key doesn't match current backup: \(backupPublicKey.publicKey) vs \(info.authData.publicKey)")
                            throw Matrix.Error("Recovery key doesn't match current backup")
                        }
                        
                        // Tell the crypto module about this backup
                        // I think this is to enable saving new keys to it, since we're only providing the public half of the key
                        logger.debug("Enabling backup in the crypto module")
                        try self.crypto.enableBackupV1(key: backupPublicKey, version: info.version)
                        
                        // I think this is the part where we provide the crypto module with the private half of the key
                        logger.debug("Saving recovery key in the crypto module")
                        try self.crypto.saveRecoveryKey(key: recoveryKey, version: info.version)
                        
                        // Also, hang onto this key so that we can decrypt keys from the backup in the future
                        // FIXME: Maybe this isn't necessary anymore, since we provided the crypto module with the private key
                        // * We should be able to retrieve it via self.crypto.getBackupKeys()
                        self.backupRecoveryKey = recoveryKey
                        
                        
                        // Finally - Do we need to load keys from this existing backup?
                        let etag = loadKeyBackupEtag(version: info.version)
                        if etag != nil {
                            logger.debug("Found existing etag \(etag!) for key backup")
                        } else {
                            logger.debug("No existing etag for key backup")
                        }
                        
                        if etag != info.etag {
                            // Either we had no previous etag, or it has changed
                            // In either case, we should load new keys from the server
                            logger.debug("Loading keys from the backup that we found")
                            try await self.loadKeysFromBackup()
                            // And save the etag
                            try self.saveKeyBackupEtag(etag: info.etag, version: info.version)
                        } else {
                            logger.debug("Key backup etag is unchanged.  We are up-to-date.")
                        }
                        
                        return
                    } else {
                        logger.warning("Couldn't get a recovery key from secret storage")
                    }
                } else {
                    // FIXME: This is where we should at least try to validate the signatures on the key backup version info
                    // We don't strictly *require* the private key in order to save our new keys into an existing backup

                    logger.debug("No secret store - Can't get recovery private key")
                }
                
                
                logger.error("Couldn't load recovery key for backup version \(info.version)")
                throw Matrix.Error("Couldn't load recovery key for backup version \(info.version)")
            } else {
                logger.debug("Failed to get current backup version")
            }
                        
            // Step 3 - There is no existing backup.  Create one from scratch.
            logger.debug("No existing key backup.  Creating a new one.")
            
            guard self.secretStorageOnline == true,
                  let store = self.secretStore
            else {
                logger.error("Can't create a new key backup without active secret storage")
                throw Matrix.Error("Can't create a new key backup without active secret storage")
            }
            
            // Step 3.1 - Generate a random recovery key
            let recoveryKey = MatrixSDKCrypto.BackupRecoveryKey()
            let recoveryPrivateKey = recoveryKey.toBase64()
            let backupPublicKey = recoveryKey.megolmV1PublicKey()
            logger.debug("Public key for our recovery key is \(backupPublicKey.publicKey)")
            
            // Step 3.2 - Create the backup on the server
            
            // Create signatures for our public key
            // * First serialize the JSON that we want to sign
            struct AuthData: Codable {
                var public_key: String
            }
            let encoder = JSONEncoder()
            guard let jsonData = try? encoder.encode(AuthData(public_key: backupPublicKey.publicKey)),
                  let jsonString = String(data: jsonData, encoding: .utf8)
            else {
                logger.error("Failed to sign JSON for new recovery public key")
                throw Matrix.Error("Failed to sign JSON for new recovery public key")
            }
            // * Then use self.crypto.sign(message: json) -- This produces the [String: [String:String]] structure that we require.
            let signatures = try self.crypto.sign(message: jsonString)
            
            guard let newVersion = try? await createNewKeyBackupVersion(publicKey: backupPublicKey.publicKey, signatures: signatures)
            else {
                logger.error("Failed to create new key backup version")
                throw Matrix.Error("Failed to create new key backup version")
            }
            
            // Step 3.3 - Enable backups in the crypto module with this version
            // Give the crypto module the public half of the key, to enable writing new keys
            try self.crypto.enableBackupV1(key: backupPublicKey, version: newVersion)
            // Give the crypto module the private half of the key, to enable reading old keys
            try self.crypto.saveRecoveryKey(key: recoveryKey, version: newVersion)
            
            // Also, hang onto this key so that we can decrypt keys from the backup in the future
            // FIXME: Also should be able to get it from the crypto module at any time via self.crypto.getBackupKeys()
            self.backupRecoveryKey = recoveryKey

            // Step 3.4 - Save the recovery key to secret storage
            logger.debug("Saving new recovery key to secret storage")
            try await store.saveSecretString(recoveryPrivateKey, type: M_MEGOLM_BACKUP_V1)
        }
        
        func loadKeyBackupEtag(version: String) -> String? {
            struct EtagInfo: Codable {
                var deviceId: String
                var version: String
                var etag: String
            }
            // Read our most recent version of the etag, if any
            let etagDefaultsKey = "key_backup_etag[\(self.creds.userId)]"
            guard let data = UserDefaults.standard.data(forKey: etagDefaultsKey)
            else {
                logger.debug("No key backup etag")
                return nil
            }
            let decoder = JSONDecoder()
            guard let etagInfo = try? decoder.decode(EtagInfo.self, from: data)
            else {
                logger.debug("Couldn't decode etag info")
                return nil
            }

            guard etagInfo.deviceId == self.creds.deviceId,
                  etagInfo.version == version
            else {
                logger.debug("Etag doesn't match current device and backup version")
                return nil
            }
            
            return etagInfo.etag
        }
        
        func saveKeyBackupEtag(etag: String, version: String) throws {
            logger.debug("Saving key backup etag \(etag) for version \(version)")
            struct EtagInfo: Codable {
                var deviceId: String
                var version: String
                var etag: String
            }
            let info = EtagInfo(deviceId: self.creds.deviceId, version: version, etag: etag)
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(info)
            else {
                logger.debug("Failed to encode etag info")
                throw Matrix.Error("Failed to encode etag info")
            }
            let etagDefaultsKey = "key_backup_etag[\(self.creds.userId)]"
            UserDefaults.standard.set(data, forKey: etagDefaultsKey)
        }
        
        public func getCurrentKeyBackupVersionInfo() async throws -> KeyBackup.VersionInfo {
            logger.debug("Getting current key backup version info")
            
            let path = "/_matrix/client/v3/room_keys/version"
            let (data, response) = try await call(method: "GET", path: path)
            
            if let rawResponseData = String(data: data, encoding: .utf8) {
                logger.debug("Got raw response: \(rawResponseData)")
            }
                       
            let decoder = JSONDecoder()
            guard let info = try? decoder.decode(KeyBackup.VersionInfo.self, from: data)
            else {
                logger.error("Failed to decode key backup version info")
                throw Matrix.Error("Failed to decode key backup version info")
            }
            return info
        }
        
        public func createNewKeyBackupVersion(publicKey: String,
                                              signatures: [String: [String:String]]? = nil
        ) async throws -> String {
            logger.debug("Creating new key backup version with public key \(publicKey)")

            struct RequestBody: Codable {
                struct AuthData: Codable {
                    var publicKey: String
                    var signatures: [String: [String:String]]?
                    enum CodingKeys: String, CodingKey {
                        case publicKey = "public_key"
                        case signatures
                    }
                }
                
                var algorithm: String
                var authData: AuthData
                
                enum CodingKeys: String, CodingKey {
                    case algorithm
                    case authData = "auth_data"
                }
                
                init(publicKey: String, signatures: [String: [String:String]]? = nil) {
                    self.algorithm = M_MEGOLM_BACKUP_V1_CURVE25519_AES_SHA2
                    self.authData = AuthData(publicKey: publicKey, signatures: signatures)
                }
            }
            
            let requestBody = RequestBody(publicKey: publicKey, signatures: signatures)
            let encoder = JSONEncoder()
            let requestBodyData = try encoder.encode(requestBody)
            let path = "/_matrix/client/v3/room_keys/version"
            let (data, response) = try await call(method: "POST", path: path, bodyData: requestBodyData)
            
            struct ResponseBody: Codable {
                var version: String
            }
            
            let decoder = JSONDecoder()
            let responseBody = try decoder.decode(ResponseBody.self, from: data)

            logger.debug("Created new key backup with version \(responseBody.version)")
            return responseBody.version
        }
        
        public func saveKeysToBackup() async throws {
            if self.crypto.backupEnabled() {
                try await cryptoQueue.run {
                    logger.debug("Checking for any new key backup requests to send")
                    if let request = try? self.crypto.backupRoomKeys() {
                        logger.debug("Sending crypto request to backup room keys")
                        try await self.sendCryptoRequest(request: request)
                    }
                }
            } else {
                logger.debug("Key backup is not enabled; No requests to send.")
            }
        }
        
        public func loadKeysFromBackup() async throws {
            
            guard let backupKeys = try? self.crypto.getBackupKeys()
            else {
                logger.error("No backup recovery key -- Not fetching backup because we wouldn't be able to decrypt it")
                return
            }
            let version = backupKeys.backupVersion()
            let key = backupKeys.recoveryKey()
            
            logger.debug("Fetching keys from backup version \(version)")
            
            let path = "/_matrix/client/v3/room_keys/keys"
            let params = [
                "version": version
            ]
            let (data, response) = try await call(method: "GET", path: path, params: params)
            
            struct ResponseBody: Codable {
                var rooms: [RoomId: KeyBackup.RoomData]
            }
            
            let decoder = JSONDecoder()
            let responseBody = try decoder.decode(ResponseBody.self, from: data)

            logger.debug("Got key backup with keys for \(responseBody.rooms.count) rooms")
            for (roomId, roomData) in responseBody.rooms {
                logger.debug("Processing key backup for room \(roomId) with \(roomData.sessions.count) sessions")
                for (sessionId, sessionInfo) in roomData.sessions {
                    logger.debug("Processing key backup for room \(roomId) session \(sessionId)")
                    let ciphertext = sessionInfo.sessionData.ciphertext
                    let ephemeral = sessionInfo.sessionData.ephemeral
                    let mac = sessionInfo.sessionData.mac
                    guard let decryptedKeysString = try? key.decryptV1(ephemeralKey: ephemeral, mac: mac, ciphertext: ciphertext),
                          let decryptedKeysData = decryptedKeysString.data(using: .utf8)
                    else {
                        logger.debug("Failed to decrypt keys for room \(roomId) session \(sessionId)")
                        continue
                    }
                    logger.debug("Decrypted key backup for room \(roomId) session \(sessionId)")
                    logger.error("Decrypted keys = \(decryptedKeysString)")

                    let decoder = JSONDecoder()
                    guard let decryptedSessionData = try? decoder.decode(KeyBackup.DecryptedSessionData.self, from: decryptedKeysData)
                    else {
                        logger.error("Failed to decode decrypted session data")
                        throw Matrix.Error("Failed to decode decrypted session data")
                    }
                    logger.debug("Decoded decrypted session data")
                    
                    // Add roomId and sessionId so the crypto module can import the session data
                    let importableSessionData = KeyBackup.SessionData(decrypted: decryptedSessionData, roomId: roomId, sessionId: sessionId)
                    // Convert to a String that we can pass to the rust module
                    let encoder = JSONEncoder()
                    guard let importableData = try? encoder.encode(importableSessionData),
                          let importableString = String(data: importableData, encoding: .utf8)
                    else {
                        logger.error("Failed to encode session data")
                        throw Matrix.Error("Failed to encode session data")
                    }

                    let listener = ConsoleLoggingProgressListener(logger: self.cryptoLogger, message: "Room \(roomId) session \(sessionId)")
                    
                    guard let result = try? self.crypto.importDecryptedRoomKeys(keys: "[\(importableString)]", progressListener: listener)
                    else {
                        logger.error("Failed to import decrypted keys for room \(roomId) session \(sessionId)")
                        continue
                    }
                    logger.debug("Imported \(result.imported) / \(result.total) decrypted keys for room \(roomId) session \(sessionId)")
                }
            }


        }
        
        // MARK: logout
        
        public override func logout() async throws {
            await MainActor.run {
                self.syncRequestTask?.cancel()
                self.dehydrateRequestTask?.cancel()
                self.backgroundSyncTask?.cancel()
                self.users = .init(n: 16)
                self.rooms = [:]
                self.invitations = [:]
                self.spaceChildRooms = [:]
                self.accountData = [:]
            }
            try await super.logout()
            try await dataStore?.close()
        }
        
    }
}
