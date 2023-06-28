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
        
        @Published public var displayName: String?
        @Published public var avatarUrl: URL?
        @Published public var avatar: Matrix.NativeImage?
        @Published public var statusMessage: String?
        
        // cvw: Leaving these as comments for now, as they require us to define even more types
        //@Published public var device: MatrixDevice
        
        @Published public var rooms: [RoomId: Matrix.Room]
        @Published public var invitations: [RoomId: Matrix.InvitedRoom]
        @Published public var spaceChildRooms: [RoomId: Matrix.SpaceChildRoom]
        
        public private(set) var users: [UserId: Matrix.User]
        
        // cvw: Stuff that we need to add, but haven't got to yet
        @Published public var accountData: [String: Codable]
        
        // Our current active UIA session, if any
        @Published public private(set) var uiaSession: UIAuthSession?

        // Need some private stuff that outside callers can't see
        private var dataStore: DataStore?
        private var syncRequestTask: Task<String?,Swift.Error>? // FIXME Use a TaskGroup to make this subordinate to the backgroundSyncTask
        private var syncToken: String? = nil
        private var syncRequestTimeout: Int = 30_000
        private var keepSyncing: Bool
        private var syncDelayNS: UInt64 = 30_000_000_000
        private var backgroundSyncTask: Task<UInt,Swift.Error>? // FIXME use a TaskGroup
        private var backgroundSyncDelayMS: UInt64?
        
        private let mediaCachePath: String
        
        var syncLogger: os.Logger
        
        private var ignoreUserIds: [UserId] {
            guard let content = self.accountData[M_IGNORED_USER_LIST] as? IgnoredUserListContent
            else {
                return []
            }
            return content.ignoredUsers
        }

        // Secret Storage
        private var secretStore: SecretStore?
        // We need to use the Matrix 'recovery' feature to back up crypto keys etc
        // This saves us from struggling with UISI errors and unverified devices
        private var recoverySecretKey: Data?
        private var recoveryTimestamp: Date?
        
        // Matrix Rust crypto
        private var crypto: MatrixSDKCrypto.OlmMachine
        private var cryptoQueue: TicketTaskQueue<Void>
        var cryptoLogger: os.Logger
        
        // MARK: init
        
        public init(creds: Credentials,
                    syncToken: String? = nil, startSyncing: Bool = true,
                    displayname: String? = nil, avatarUrl: MXC? = nil, statusMessage: String? = nil,
                    recoverySecretKey: Data? = nil, recoveryTimestamp: Data? = nil,
                    storageType: StorageType = .persistent(preserve: true),
                    useCrossSigning: Bool = true,
                    secretStorageKeyInfo: (String,Data)? = nil
        ) async throws {
            
            self.syncLogger = os.Logger(subsystem: "matrix", category: "sync \(creds.userId)")
            self.cryptoLogger = os.Logger(subsystem: "matrix", category: "crypto \(creds.userId)")
            
            self.rooms = [:]
            self.invitations = [:]
            self.spaceChildRooms = [:]
            self.users = [:]
            self.accountData = [:]
            
            self.syncToken = syncToken
            self.keepSyncing = startSyncing
            // Initialize the sync tasks to nil so we can run super.init()
            self.syncRequestTask = nil
            self.backgroundSyncTask = nil
            //self.backgroundSyncDelayMS = 1_000
            
            self.uiaSession = nil
            
            // FIXME: Pick a better / more appropriate location for this cache
            //        See https://www.swiftbysundell.com/articles/working-with-files-and-folders-in-swift/
            let mediaCachePath = [
                NSHomeDirectory(),
                ".matrix",
                Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "matrix.swift",
                "\(creds.userId)",
                "\(creds.deviceId)",
                "media",
                "cache",
            ].joined(separator: "/")
            self.mediaCachePath = mediaCachePath
            if !FileManager.default.fileExists(atPath: mediaCachePath) {
                try FileManager.default.createDirectory(at: URL(filePath: mediaCachePath), withIntermediateDirectories: true)
            }
            
            
            self.dataStore = try await GRDBDataStore(userId: creds.userId, type: storageType)
            
            let cryptoStorePath = [
                NSHomeDirectory(),
                ".matrix",
                Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "matrix.swift",
                "\(creds.userId)",
                "\(creds.deviceId)",
                "crypto"
            ].joined(separator: "/")
            self.crypto = try OlmMachine(userId: "\(creds.userId)",
                                         deviceId: "\(creds.deviceId)",
                                         path: cryptoStorePath,
                                         passphrase: nil)
            self.cryptoQueue = TicketTaskQueue<Void>()
            
            try await super.init(creds: creds)
            
            // --------------------------------------------------------------------------------------------------------
            // Phase 1 init is done -- Now we can reference `self`
            // Ok now we're initialized as a valid Matrix.Client (super class)

            
            // Set up crypto stuff
            // Secret storage
            if let (s4keyId,s4key) = secretStorageKeyInfo {
                cryptoLogger.debug("Setting up secret storage with keyId \(s4keyId)")
                self.secretStore = try await .init(session: self, defaultKey: s4key, defaultKeyId: s4keyId)
            } else {
                cryptoLogger.debug("Setting up secret storage -- no keys")
                self.secretStore = try await .init(session: self, keys: [:])
            }
            // Initial requests
            try await cryptoQueue.run {
                let cryptoRequests = try self.crypto.outgoingRequests()
                print("Session:\tSending initial crypto requests (\(cryptoRequests.count))")
                for request in cryptoRequests {
                    try await self.sendCryptoRequest(request: request)
                }
                if useCrossSigning {
                    // Hopefully uia is nil -- Meaning we don't have to re-authenticate so soon.
                    // But it's possible that we might get stuck doing UIA right off the bat.
                    // No big deal.  Handle it like any ohter UIA.
                    if let uia = try await self.setupCrossSigning() {
                        await MainActor.run {
                            self.uiaSession = uia
                        }
                    }
                }
            }
            
            
            // Load our list of existing invited rooms
            if let store = self.dataStore {
                logger.debug("Looking for previously-saved invited rooms")
                let invitedRoomIds = try await store.getInvitedRoomIds(for: creds.userId)
                logger.debug("Found \(invitedRoomIds.count) invited room id's")
                for roomId in invitedRoomIds {
                    logger.debug("Attempting to load stripped state for invited room \(roomId)")
                    let strippedStateEvents = try await store.loadStrippedState(for: roomId)
                    if let room = try? InvitedRoom(session: self, roomId: roomId, stateEvents: strippedStateEvents) {
                        self.invitations[roomId] = room
                    }
                }
            }
            
            // Are we supposed to start syncing?
            if startSyncing {
                try await startBackgroundSync()
            }
        }
        
        // MARK: Sync
        
        public func startBackgroundSync() async throws {
            self.keepSyncing = true
            if self.backgroundSyncTask != nil {
                logger.warning("Session:\tCan't start background sync when it's already running!")
                return
            }
            self.backgroundSyncTask = self.backgroundSyncTask ?? .init(priority: .background) {
                syncLogger.debug("Starting background sync")
                var count: UInt = 0
                var failureCount: UInt = 0
                while self.keepSyncing {
                    syncLogger.debug("Keeping on syncing...")
                    guard let token = try? await sync()
                    else {
                        syncLogger.warning("Sync failed with token \(self.syncToken ?? "(none)")")
                        failureCount += 1
                        if failureCount > 3 {
                            self.keepSyncing = false
                        }
                        try await Task.sleep(for: .seconds(1))
                        continue
                    }
                    failureCount = 0
                    syncLogger.debug("Got new sync token \(token)")
                    count += 1
                    if let delay = self.backgroundSyncDelayMS {
                        syncLogger.debug("Sleeping for \(delay) ms before next sync")
                        let nano = delay * 1000
                        try await Task.sleep(nanoseconds: nano)
                    }
                }
                self.backgroundSyncTask = nil
                return count
            }
        }
        
        // https://spec.matrix.org/v1.2/client-server-api/#get_matrixclientv3sync
        // The Swift compiler couldn't figure this out when it was given in-line in the call below.
        // So here we are defining its type explicitly.
        @Sendable
        private func syncRequestTaskOperation() async throws -> String? {
            
            var logger = self.syncLogger
            
            // Following the Rust Crypto SDK example https://github.com/matrix-org/matrix-rust-sdk/blob/8ac7f88d22e2fa0ca96eba7239ba7ec08658552c/crates/matrix-sdk-crypto/src/lib.rs#L540
            // We first send any outbound messages from the crypto module before we actually call /sync
            try await cryptoQueue.run {
                let requests = try self.crypto.outgoingRequests()
                for request in requests {
                    try await self.sendCryptoRequest(request: request)
                }
            }
            
            logger.debug("User \(self.creds.userId) syncing with token \(self.syncToken ?? "(none)")")
            let url = "/_matrix/client/v3/sync"
            var params = [
                "timeout": "\(syncRequestTimeout)",
            ]
            if let token = syncToken {
                params["since"] = token
            }
            let (data, response) = try await self.call(method: "GET", path: url, params: params)
            //logger.debug("User \(self.creds.userId) got sync response")
            
            //let rawDataString = String(data: data, encoding: .utf8)
            //print("\n\n\(rawDataString!)\n\n")
            
            guard response.statusCode == 200 else {
                logger.error("\(self.creds.userId) Error: got HTTP \(response.statusCode) \(response.description)")
                self.syncRequestTask = nil
                //return self.syncToken
                return nil
            }
            
            let decoder = JSONDecoder()
            //decoder.keyDecodingStrategy = .convertFromSnakeCase
            guard let responseBody = try? decoder.decode(SyncResponseBody.self, from: data)
            else {
                self.syncRequestTask = nil
                let msg = "Could not decode /sync response"
                logger.error("\(msg)")
                throw Matrix.Error(msg)
            }
            
            // Process the sync response, updating local state if necessary
            
            // First thing to check: Did our sync token actually change?
            // Because if not, then we've already seen everything in this update
            if responseBody.nextBatch == self.syncToken {
                logger.debug("Token didn't change; Therefore no updates; Doing nothing")
                self.syncRequestTask = nil
                return syncToken
            } else {
                logger.debug("Got new sync token \(responseBody.nextBatch)")
            }
            
            // Track whether this sync was successful.  If not, we shouldn't advance the token.
            var success = true
            
            try await cryptoQueue.run {
                // Send updates to the Rust crypto module
                logger.debug("Updating Rust crypto module")
                guard let decryptedToDeviceEventsString = try? self.updateCryptoAfterSync(responseBody: responseBody)
                else {
                    success = false
                    logger.error("Crypto update failed")
                    return
                }
                // NOTE: If we want to track the Olm or Megolm sessions ourselves for debugging purposes,
                //       then this is the place to do it.  The Rust Crypto SDK just provided us with the
                //       plaintext of all the to-device events.
                
                // Send any requests from the crypto module
                logger.debug("Querying crypto module for any new requests")
                guard let cryptoRequests = try? self.crypto.outgoingRequests()
                else {
                    // Don't set success to false here -- With the outgoing requests, we can always try again later
                    logger.error("Failed to get outgoing crypto requests")
                    return
                }
                logger.debug("Sending \(cryptoRequests.count) crypto requests")
                for request in cryptoRequests {
                    try await self.sendCryptoRequest(request: request)
                }
            }
            
            // Handle invites
            if let invitedRoomsDict = responseBody.rooms?.invite {
                logger.debug("Found \(invitedRoomsDict.count) invited rooms")
                for (roomId, info) in invitedRoomsDict {
                    logger.debug("Found invited room \(roomId)")
                    guard let events = info.inviteState?.events
                    else {
                        continue
                    }
                    
                    if let store = self.dataStore {
                        try await store.saveStrippedState(events: events, roomId: roomId)
                    }
                    
                    //if self.invitations[roomId] == nil {
                        let room = try InvitedRoom(session: self, roomId: roomId, stateEvents: events)
                        self.invitations[roomId] = room
                    //}
                }
            } else {
                logger.debug("No invited rooms")
            }
            
            // Handle rooms where we're already joined
            if let joinedRoomsDict = responseBody.rooms?.join {
                logger.debug("Found \(joinedRoomsDict.count) joined rooms")
                for (roomId, info) in joinedRoomsDict {
                    logger.debug("Found joined room \(roomId)")
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
                        
                    } else {
                        // Clearly the room is no longer in the 'invited' state
                        invitations.removeValue(forKey: roomId)
                        // Also purge any stripped state that we had been storing for this room
                        try await deleteInvitedRoom(roomId: roomId)
                    }
                }
            } else {
                logger.debug("No joined rooms")
            }
            
            // Handle rooms that we've left
            if let leftRoomsDict = responseBody.rooms?.leave {
                logger.debug("Found \(leftRoomsDict.count) left rooms")
                for (roomId, info) in leftRoomsDict {
                    logger.debug("Found left room \(roomId)")
                    // TODO: What should we do here?
                    // For now, just make sure these rooms are taken out of the other lists
                    invitations.removeValue(forKey: roomId)
                    rooms.removeValue(forKey: roomId)
                }
            } else {
                logger.debug("No left rooms")
            }
            
            // FIXME: Do something with AccountData
            logger.debug("Skipping account data for now")
            
            // FIXME: Handle to-device messages
            logger.debug("Skipping to-device messages for now")


            if success {
                logger.debug("Updating sync token...  awaiting MainActor")
                await MainActor.run {
                    //print("/sync:\tMainActor updating sync token to \(responseBody.nextBatch)")
                    self.syncToken = responseBody.nextBatch
                }
                UserDefaults.standard.set(self.syncToken, forKey: "sync_token[\(creds.userId)::\(creds.deviceId)]")
                
                //print("/sync:\t\(creds.userId) Done!")
                self.syncRequestTask = nil
                return responseBody.nextBatch
            } else {
                return self.syncToken
            }
        }
        
        public func sync() async throws -> String? {
            //print("/sync:\t\(creds.userId) Starting sync()  -- token is \(syncToken ?? "(none)")")
            // FIXME: Use a TaskGroup
            if let task = syncRequestTask {
                syncLogger.debug("Already syncing..  awaiting on the result")
                return try await task.value
            } else {
                syncRequestTask = .init(priority: .background, operation: syncRequestTaskOperation)
                return try await syncRequestTask?.value
            }
        }
        
        // MARK: Crypto
        
        private func updateCryptoAfterSync(responseBody: SyncResponseBody) throws -> String {
            var logger = self.syncLogger
            var eventsListString = "[]"
            if let toDevice = responseBody.toDevice {
                let events = toDevice.events
                let encoder = JSONEncoder()
                let eventsData = try encoder.encode(events)
                eventsListString = String(data: eventsData, encoding: .utf8)!
                logger.debug("Sending \(events.count) to-device event to Rust crypto module:   \(eventsListString)")
            }
            let eventsString = "{\"events\": \(eventsListString)}"
            // Ugh we have to translate the device lists back to raw String's
            var deviceLists = MatrixSDKCrypto.DeviceLists(
                changed: responseBody.deviceLists?.changed?.map { $0.description } ?? [],
                left: responseBody.deviceLists?.left?.map { $0.description } ?? []
            )
            logger.debug("\(deviceLists.changed.count) Changed devices")
            logger.debug("\(deviceLists.left.count) Left devices")
            logger.debug("\(responseBody.deviceOneTimeKeysCount?.keys.count ?? 0) device one-time keys")
            if let dotkc = responseBody.deviceOneTimeKeysCount {
                logger.debug("\(dotkc)")
            }
            logger.debug("\(responseBody.deviceUnusedFallbackKeyTypes?.count ?? 0) unused fallback keys")

            guard let result = try? self.crypto.receiveSyncChanges(events: eventsString,
                                                                   deviceChanges: deviceLists,
                                                                   keyCounts: responseBody.deviceOneTimeKeysCount ?? [:],
                                                                   unusedFallbackKeys: responseBody.deviceUnusedFallbackKeyTypes ?? [])
            else {
                logger.error("Crypto update failed")
                throw Matrix.Error("Crypto update failed")
            }
            logger.debug("Got response from Rust crypto: \(result)")
            return result
        }

        func sendCryptoRequest(request: Request) async throws {
            var logger = self.cryptoLogger
            switch request {
                
            case .toDevice(requestId: let requestId, eventType: let eventType, body: let messagesString):
                logger.debug("Handling to-device request")
                let bodyString = "{\"messages\": \(messagesString)}"         // Redneck JSON encoding 🤘
                let txnId = "\(UInt16.random(in: UInt16.min...UInt16.max))"
                //let txnId = "\(UInt8.random(in: UInt8.min...UInt8.max))"
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
                                                  response: responseBodyString)
                
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
                                                  response: responseBodyString)
            
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
                                                  response: responseBodyString)
                
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
                                                  response: responseBodyString)
                
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
                                                           body: requestBody)
                guard let responseBodyString = String(data: data, encoding: .utf8)
                else {
                    logger.error("Couldn't process /room_keys/keys response")
                    throw Matrix.Error("Couldn't process /room_keys/keys response")
                }
                logger.debug("Marking keys backup request as sent")
                try self.crypto.markRequestAsSent(requestId: requestId,
                                                  requestType: .keysBackup,
                                                  response: responseBodyString)
                
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
                                                  response: responseBodyString)
                
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
                logger.debug("Marking signature upload request as sent")
                try self.crypto.markRequestAsSent(requestId: requestId,
                                                  requestType: .signatureUpload,
                                                  response: responseBodyString)
            } // end case request
        } // end sendCryptoRequests()

        // MARK: Session state management
        
        public func pause() async throws {
            // pause() doesn't actually make any API calls
            // It just tells our own local sync task to take a break
            self.keepSyncing = false
        }
        
        public func close() async throws {
            // close() is like pause; it doesn't make any API calls
            // It just tells our local sync task to shut down
            throw Matrix.Error("Not implemented yet")
        }
        
        // MARK: UIA
        public func cancelUIA() async throws {
            await MainActor.run {
                self.uiaSession = nil
            }
        }
        
        // MARK: Recovery
        
        public func createRecovery(privateKey: Data) async throws {
            throw Matrix.Error("Not implemented yet")
        }
        
        public func deleteRecovery() async throws {
            throw Matrix.Error("Not implemented yet")
        }
        
        public func whoAmI() async throws -> UserId {
            return self.creds.userId
        }
        
        // MARK: Rooms
        
        public override func getRoomStateEvents(roomId: RoomId) async throws -> [ClientEventWithoutRoomId] {
            let events = try await super.getRoomStateEvents(roomId: roomId)
            if let store = self.dataStore {
                try await store.saveState(events: events, in: roomId)
            }
            if let room = self.rooms[roomId] {
                try await room.updateState(from: events)
            }
            return events
        }
        
        
        public func getRoom<T: Matrix.Room>(roomId: RoomId,
                                            as type: T.Type = Matrix.Room.self
        ) async throws -> T? {
            let tag = "getRoom(\(roomId))"
            logger.debug("\(tag)\tStarting")
            if let existingRoom = self.rooms[roomId] as? T {
                logger.debug("\(tag)\tFound room in the cache.  Done.")
                return existingRoom
            }
            
            // Apparently we don't already have a Room object for this one
            // Let's see if we can find the necessary data to construct it
            
            // Do we have this room in our data store?
            if let store = self.dataStore {
                logger.debug("\(tag)\tLoading room from data store")
                let stateEvents = try await store.loadEssentialState(for: roomId)
                logger.debug("\(tag)\tLoaded \(stateEvents.count) state events")
                /*
                let timelineEvents = try await store.loadTimeline(for: roomId, limit: 25, offset: 0)
                logger.debug("\(tag)\tLoaded \(stateEvents.count) timeline events")
                */
                let timelineEvents = [ClientEventWithoutRoomId]()
                 
                if stateEvents.count > 0 {
                    logger.debug("\(tag)\tConstructing the room")
                    if let room = try? T(roomId: roomId, session: self, initialState: stateEvents, initialTimeline: timelineEvents) {
                        logger.debug("\(tag)\tAdding new room to the cache")
                        await MainActor.run {
                            self.rooms[roomId] = room
                        }
                        return room
                    }
                }
            }
            
            // Ok we didn't have the room state cached locally
            logger.debug("\(tag)\tFailed to load from data store")
            // Maybe the server knows about this room?
            logger.debug("\(tag)\tAsking the server")
            let events = try await getRoomStateEvents(roomId: roomId)
            logger.debug("\(tag)\tGot \(events.count) events from the server")
            if let room = try? T(roomId: roomId, session: self, initialState: events, initialTimeline: []) {
                logger.debug("\(tag)\tCreated room.  Adding to cache.")
                await MainActor.run {
                    self.rooms[roomId] = room
                }
                return room
            } else {
                logger.error("\(tag)\tFailed to create room from the server's state events")
            }
            
            // Looks like we got nothing
            return nil
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
            throw Matrix.Error("Not implemented")
            /*
            var content = try await self.getAccountData(for: M_IGNORED_USER_LIST, of: IgnoredUserListContent.self)
            if !content.ignoredUsers.contains(userId) {
                content.ignoredUsers.append(userId)
                try await self.putAccountData(content, for: M_IGNORED_USER_LIST)
            }
            */
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

            let users: [String] = try await room.getJoinedMembers().map { $0.description }
            logger.debug("Found \(users.count) users in the room: \(users)")
            try await cryptoQueue.run {
                if let missingSessionsRequest = try self.crypto.getMissingSessions(users: users) {
                    // Send the missing sessions request
                    logger.debug("Sending missing sessions request")
                    try await self.sendCryptoRequest(request: missingSessionsRequest)
                }
            }
            
            // FIXME: WhereTF do we get the "only allow trusted devices" setting?
            let onlyTrusted = false
            
            guard let roomHistoryVisibility = try await room.getHistoryVisibility()
            else {
                throw Matrix.Error("Cannot encrypt because we cannot determine history visibility for room \(roomId)")
            }
            
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
                                              rotationPeriod: params.rotationPeriodMs,
                                              rotationPeriodMsgs: params.rotationPeriodMsgs,
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
            return try await super.sendMessageEvent(to: roomId,
                                                    type: M_ROOM_ENCRYPTED,
                                                    content: encryptedContent)
        }
        
        // MARK: Media
        
        public override func downloadData(mxc: MXC) async throws -> Data {
            // FIXME: First check to see if we already have the item in our cache
            
            let data = try await super.downloadData(mxc: mxc)
            
            // FIXME: Save the data in our cache
            
            return data
        }

        // MARK: Encrypted Media
        
        public func encryptAndUploadData(plaintext: Data, contentType: String) async throws -> mEncryptedFile {
            let key = try Random.generateBytes(byteCount: 32)
            let iv = try Random.generateBytes(byteCount: 16)
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
            let mxc = try await self.uploadData(data: ciphertext, contentType: contentType)

            return mEncryptedFile(url: mxc,
                                  key: Matrix.JWK(key),
                                  iv: Data(iv).base64EncodedString(),
                                  hashes: ["sha256": Data(sha256sum).base64EncodedString()],
                                  v: "v2")
        }
        
        public func downloadAndDecryptData(_ info: mEncryptedFile) async throws -> Data {
            let ciphertext = try await self.downloadData(mxc: info.url)
            
            // Cryptographic doom principle: Verify that the ciphertext is what we expected,
            // before we do anything crazy like trying to decrypt
            guard let gotSHA256 = Digest(algorithm: .sha256).update(ciphertext)?.final(),
                  let wantedSHA256base64 = info.hashes["sha256"],
                  let wantedSHA256data = Data(base64Encoded: wantedSHA256base64),
                  gotSHA256.count == wantedSHA256data.count
            else {
                throw Matrix.Error("Couldn't get SHA256 digest(s)")
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
                throw Matrix.Error("SHA256 hash does not match!")
            }
            
            // OK now it's finally safe to (try to) decrypt this thing
            
            guard let key = Data(base64Encoded: info.key.k),
                  let iv = Data(base64Encoded: info.iv)
            else {
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
                throw Matrix.Error("Failed to decrypt ciphertext")
            }
            
            return Data(decryptedBytes)
        }

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
        
        public override func getRelatedEvents(roomId: RoomId, eventId: EventId, relType: String) async throws -> [ClientEventWithoutRoomId] {
            let events = try await super.getRelatedEvents(roomId: roomId, eventId: eventId, relType: relType)
            
            if let store = dataStore {
                try await store.saveTimeline(events: events, in: roomId)
            }
            
            return events
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
            guard let decryptedStruct = try? crypto.decryptRoomEvent(event: encryptedString, roomId: "\(roomId)", handleVerificatonEvents: true)
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
        
        // MARK: Cross Signing
        
        public func setupCrossSigning() async throws -> UIAuthSession? {
            let logger: os.Logger = Logger(subsystem: "matrix", category: "XSIGN")
            logger.debug("Setting up")
            
            // First thing to check: Do we already have all of our cross-signing keys?
            let status = self.crypto.crossSigningStatus()
            if status.hasMaster && status.hasSelfSigning && status.hasUserSigning {
                // Nothing more to be done here
                logger.debug("Already all set up.  Done.")
                return nil
            }
            
            // If we don't have our keys, maybe they are on the server
            // (Maybe we created them on another device and uploaded them)
            if let store = self.secretStore {
                logger.debug("Looking for keys on the server")
                // Look in the secret store for our cross-signing keys
                if let privateMSK = try await store.getSecret(type: M_CROSS_SIGNING_MASTER) as? String,
                   let privateSSK = try await store.getSecret(type: M_CROSS_SIGNING_SELF_SIGNING) as? String,
                   let privateUSK = try await store.getSecret(type: M_CROSS_SIGNING_USER_SIGNING) as? String
                {
                    logger.debug("Found keys on the server")
                    let export = CrossSigningKeyExport(masterKey: privateMSK, selfSigningKey: privateSSK, userSigningKey: privateUSK)
                    try self.crypto.importCrossSigningKeys(export: export)
                    // Success!  And no need to do UIA!
                    return nil
                }
            } else {
                logger.warning("No secret store")
            }
            
            // If we're still here, then we need to bootstrap our cross signing, ie generate a new set of keys
            logger.debug("Need to bootstrap")
            let result = try self.crypto.bootstrapCrossSigning()
            
            logger.debug("Exporting keys")
            guard let export = self.crypto.exportCrossSigningKeys(),
                  let privateMSK = export.masterKey,
                  let privateSSK = export.selfSigningKey,
                  let privateUSK = export.userSigningKey
            else {
                logger.error("Failed to export new cross-signing keys")
                throw Matrix.Error("Failed to export new cross-signing keys")
            }
            
            // Upload the signing keys
            let decoder = JSONDecoder()
            let masterKey = try decoder.decode(CrossSigningKey.self, from: result.uploadSigningKeysRequest.userSigningKey.data(using: .utf8)!)
            let selfSigningKey = try decoder.decode(CrossSigningKey.self, from: result.uploadSigningKeysRequest.selfSigningKey.data(using: .utf8)!)
            let userSigningKey = try decoder.decode(CrossSigningKey.self, from: result.uploadSigningKeysRequest.userSigningKey.data(using: .utf8)!)

            let path = "/_matrix/client/v3/keys/device_signing/upload"
            let url = URL(string: path, relativeTo: self.baseUrl)!
            
            // WARNING: This endpoint uses the user-interactive auth, so unless we call it *immediately* after login, we should expect to receive a new UIA session that must be completed before the request can take effect
            logger.debug("Sending keys in a POST request to the server")
            let uia = UIAuthSession(method: "POST", url: url, requestDict: [
                "master_key": masterKey,
                "self_signing_key": selfSigningKey,
                "user_signing_key": userSigningKey,
            ]) { (_,_) in
                // Completion handler that runs after the UIA completes successfully
                logger.debug("UIA completed successfully")
                
                if let store = self.secretStore {
                    // Upload the new cross-signing keys to secret storage, so we can use them on other devices
                    logger.debug("Saving keys to secret storage")
                    try await store.saveSecret(privateMSK, type: M_CROSS_SIGNING_MASTER)
                    try await store.saveSecret(privateSSK, type: M_CROSS_SIGNING_SELF_SIGNING)
                    try await store.saveSecret(privateUSK, type: M_CROSS_SIGNING_USER_SIGNING)
                }
                
                // Also upload the signature request in `result.signatureRequest`
                logger.debug("Uploading signatures")
                // WTF man, why do we have Request.signatureUpload AND SignatureUploadRequest ???
                let requestId = UInt16.random(in: 0...UInt16.max)
                let request: Request = .signatureUpload(requestId: "\(requestId)", body: result.signatureRequest.body)
                try await self.sendCryptoRequest(request: request)
            }
            logger.debug("Waiting for UIA to connect")
            try await uia.connect()
            switch uia.state {
            case .finished:
                // Yay, got it in one!  The server did not require us to authenticate again.
                logger.debug("UIA was not required to upload keys")
                return nil
            case .inProgress(let uiaState, _):
                logger.debug("UIA is now in progress.  Must be completed to upload keys.")
                for flow in uiaState.flows {
                    logger.debug("Found UIA flow \(flow.stages)")
                }
            default:
                // The caller will have to complete UIA before the request can go through
                logger.debug("Client needs to complete UIA to upload keys")
            }
            return uia
        }
        
        // MARK: logout
        
        public override func logout() async throws {
            self.syncRequestTask?.cancel()
            self.backgroundSyncTask?.cancel()
            self.users = [:]
            self.rooms = [:]
            self.invitations = [:]
            self.spaceChildRooms = [:]
            self.accountData = [:]
            try await super.logout()
            try await dataStore?.close()
        }
    }
}
