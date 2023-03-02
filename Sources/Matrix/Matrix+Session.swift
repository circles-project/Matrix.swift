//
//  Matrix+Session.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation

#if !os(macOS)
import UIKit
#else
import AppKit
#endif

import IDZSwiftCommonCrypto
import MatrixSDKCrypto


extension Matrix {
    public class Session: Matrix.Client, ObservableObject {
        @Published public var displayName: String?
        @Published public var avatarUrl: URL?
        @Published public var avatar: Matrix.NativeImage?
        @Published public var statusMessage: String?
        
        // cvw: Leaving these as comments for now, as they require us to define even more types
        //@Published public var device: MatrixDevice
        
        @Published public var rooms: [RoomId: Matrix.Room]
        @Published public var invitations: [RoomId: Matrix.InvitedRoom]
        
        // cvw: Stuff that we need to add, but haven't got to yet
        public var accountData: [Matrix.AccountDataType: Codable]

        // Need some private stuff that outside callers can't see
        private var dataStore: DataStore?
        private var syncRequestTask: Task<String?,Swift.Error>? // FIXME Use a TaskGroup to make this subordinate to the backgroundSyncTask
        private var syncToken: String? = nil
        private var syncRequestTimeout: Int = 30_000
        private var keepSyncing: Bool
        private var syncDelayNS: UInt64 = 30_000_000_000
        private var backgroundSyncTask: Task<UInt,Swift.Error>? // FIXME use a TaskGroup
        
        // FIXME: Derive this from our account data???
        // The type is `m.ignored_user_list` https://spec.matrix.org/v1.5/client-server-api/#mignored_user_list
        private var ignoreUserIds: [UserId] {
            guard let content = self.accountData[.mIgnoredUserList] as? IgnoredUserListContent
            else {
                return []
            }
            return content.ignoredUsers
        }

        // We need to use the Matrix 'recovery' feature to back up crypto keys etc
        // This saves us from struggling with UISI errors and unverified devices
        private var recoverySecretKey: Data?
        private var recoveryTimestamp: Date?
        
        // Matrix Rust crypto
        private var crypto: MatrixSDKCrypto.OlmMachine
        
        public init(creds: Credentials,
                    syncToken: String? = nil, startSyncing: Bool = true,
                    displayname: String? = nil, avatarUrl: MXC? = nil, statusMessage: String? = nil,
                    recoverySecretKey: Data? = nil, recoveryTimestamp: Data? = nil,
                    storageType: StorageType = .persistent(preserve: true)
        ) async throws {
            self.rooms = [:]
            self.invitations = [:]
            self.accountData = [:]
                        
            self.keepSyncing = startSyncing
            // Initialize the sync tasks to nil so we can run super.init()
            self.syncRequestTask = nil
            self.backgroundSyncTask = nil
            
            self.dataStore = try await GRDBDataStore(userId: creds.userId, type: storageType)
            
            let cryptoStorePath = [
                NSHomeDirectory(),
                ".matrix",
                Bundle.main.infoDictionary?["CFBundleName"] as? String ?? Bundle.main.className,
                "\(creds.userId)",
                "\(creds.deviceId)",
                "crypto"
            ].joined(separator: "/")
            self.crypto = try OlmMachine(userId: "\(creds.userId)",
                                         deviceId: "\(creds.deviceId)",
                                         path: cryptoStorePath,
                                         passphrase: nil)
            
            try super.init(creds: creds)

            // --------------------------------------------------------------------------------------------------------
            // Phase 1 init is done -- Now we can reference `self`
            
            // Ok now we're initialized as a valid Matrix.Client (super class)
            // Are we supposed to start syncing?
            if startSyncing {
                backgroundSyncTask = .init(priority: .background) {
                    var count: UInt = 0
                    while keepSyncing {
                        let token = try await sync()
                        count += 1
                    }
                    return count
                }
            }
        }
        
        // MARK: Sync
        // https://spec.matrix.org/v1.2/client-server-api/#get_matrixclientv3sync
        @Sendable
        private func syncRequestTaskOperation() async throws -> String? {
            var url = "/_matrix/client/v3/sync"
            var params = [
                "timeout": "\(syncRequestTimeout)",
            ]
            if let token = syncToken {
                params["since"] = token
            }
            print("/sync:\tCalling \(url)")
            let (data, response) = try await self.call(method: "GET", path: url, params: params)
            
            //let rawDataString = String(data: data, encoding: .utf8)
            //print("\n\n\(rawDataString!)\n\n")
            
            guard response.statusCode == 200 else {
                print("ERROR: /sync got HTTP \(response.statusCode) \(response.description)")
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
                logger.debug("/sync:\tToken didn't change; Therefore no updates; Doing nothing")
                self.syncRequestTask = nil
                return syncToken
            }
            
            // Send updates to the Rust crypto module
            try self.updateCryptoAfterSync(responseBody: responseBody)
            
            // Handle invites
            if let invitedRoomsDict = responseBody.rooms?.invite {
                print("/sync:\t\(invitedRoomsDict.count) invited rooms")
                for (roomId, info) in invitedRoomsDict {
                    print("/sync:\tFound invited room \(roomId)")
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
                print("/sync:\tNo invited rooms")
            }
            
            // Handle rooms where we're already joined
            if let joinedRoomsDict = responseBody.rooms?.join {
                print("/sync:\t\(joinedRoomsDict.count) joined rooms")
                for (roomId, info) in joinedRoomsDict {
                    print("/sync:\tFound joined room \(roomId)")
                    let stateEvents = info.state?.events ?? []
                    let timelineEvents = info.timeline?.events ?? []
                    let timelineStateEvents = timelineEvents.filter {
                        $0.stateKey != nil
                    }
                    
                    let roomTimestamp = timelineEvents.map { $0.originServerTS }.max()
                    
                    if let store = self.dataStore {
                        // First save the state events from before this timeline
                        // Then save the state events that came in during the timeline
                        // We do both in a single call so it all happens in one transaction in the database
                        let allStateEvents = stateEvents + timelineStateEvents
                        if !allStateEvents.isEmpty {
                            print("/sync:\tSaving state for room \(roomId)")
                            try await store.saveState(events: allStateEvents, in: roomId)
                        }
                        if !timelineEvents.isEmpty {
                            // Save the whole timeline so it can be displayed later
                            print("/sync:\tSaving timeline for room \(roomId)")
                            try await store.saveTimeline(events: timelineEvents, in: roomId)
                        }
                        
                        // Save the room summary with the latest timestamp
                        if let timestamp = roomTimestamp {
                            print("/sync:\tSaving timestamp for room \(roomId)")
                            try await store.saveRoomTimestamp(roomId: roomId, state: .join, timestamp: timestamp)
                        } else {
                            print("/sync:\tNo update to timestamp for room \(roomId)")
                        }
                    }

                    if let room = self.rooms[roomId] {
                        print("\tWe know this room already")
                        print("\t\(stateEvents.count) new state events")
                        print("\t\(timelineEvents.count) new timeline events")

                        // Update the room with the latest data from `info`
                        try await room.updateState(from: stateEvents)
                        if room.isEncrypted {
                            let decryptedEvents = tryToDecryptEvents(events: timelineEvents, in: roomId)
                            try await room.updateTimeline(from: decryptedEvents)
                        } else {
                            try await room.updateTimeline(from: timelineEvents)
                        }
                        
                        if let unread = info.unreadNotifications {
                            print("\t\(unread.notificationCount) notifications")
                            print("\t\(unread.highlightCount) highlights")
                            room.notificationCount = unread.notificationCount
                            room.highlightCount = unread.highlightCount
                        }
                        
                    } else {
                        // Clearly the room is no longer in the 'invited' state
                        invitations.removeValue(forKey: roomId)
                        // FIXME Also purge any stripped state that we had been storing for this room
                        
                        if let room = try? Matrix.Room(roomId: roomId, session: self, initialState: stateEvents+timelineStateEvents, initialTimeline: timelineEvents) {
                            print("/sync:\tInitialized new Room object for \(roomId)")
                            await MainActor.run {
                                self.rooms[roomId] = room
                            }
                        } else {
                            print("/sync:\tError: Failed to initialize Room object for \(roomId)")
                        }
                    }
                    

                }
            } else {
                print("/sync:\tNo joined rooms")
            }
            
            // Handle rooms that we've left
            if let leftRoomsDict = responseBody.rooms?.leave {
                print("/sync:\t\(leftRoomsDict.count) left rooms")
                for (roomId, info) in leftRoomsDict {
                    print("/sync:\tFound left room \(roomId)")
                    // TODO: What should we do here?
                    // For now, just make sure these rooms are taken out of the other lists
                    invitations.removeValue(forKey: roomId)
                    rooms.removeValue(forKey: roomId)
                }
            } else {
                print("/sync:\tNo left rooms")
            }
            
            // FIXME: Do something with AccountData
            
            // FIXME: Handle to-device messages

            print("/sync:\tUpdating sync token...  awaiting MainActor")
            await MainActor.run {
                print("/sync:\tMainActor updating sync token to \(responseBody.nextBatch)")
                self.syncToken = responseBody.nextBatch
            }

            print("/sync:\tDone!")
            self.syncRequestTask = nil
            return responseBody.nextBatch
        
        }
        
        public func sync() async throws -> String? {
            print("/sync:\tStarting sync()")
            
            /*
            // FIXME: Use a TaskGroup
            syncRequestTask = syncRequestTask ?? .init(priority: .background, operation: syncRequestTaskOperation)
            
            guard let task = syncRequestTask else {
                print("Error: /sync Failed to launch sync request task")
                return nil
            }
            print("/sync:\tAwaiting result of sync task")
            return try await task.value
            */
            
            if let task = syncRequestTask {
                return try await task.value
            } else {
                syncRequestTask = .init(priority: .background, operation: syncRequestTaskOperation)
                return try await syncRequestTask?.value
            }
        }
        
        // MARK: Crypto
        
        private func updateCryptoAfterSync(responseBody: SyncResponseBody) throws {
            var eventsString = "[]"
            if let toDevice = responseBody.toDevice {
                let events = toDevice.events
                let encoder = JSONEncoder()
                let eventsData = try encoder.encode(events)
                eventsString = String(data: eventsData, encoding: .utf8)!
            }
            // Ugh we have to translate the device lists back to raw String's
            var deviceLists = MatrixSDKCrypto.DeviceLists(
                changed: responseBody.deviceLists?.changed?.map { $0.description } ?? [],
                left: responseBody.deviceLists?.left?.map { $0.description } ?? []
            )

            let result = try self.crypto.receiveSyncChanges(events: eventsString,
                                                            deviceChanges: deviceLists,
                                                            keyCounts: responseBody.deviceOneTimeKeysCount ?? [:],
                                                            unusedFallbackKeys: responseBody.deviceUnusedFallbackKeyTypes ?? [])
        }

        func sendCryptoRequest(request: Request) async throws {
            switch request {
                
            case .toDevice(requestId: let requestId, eventType: let eventType, body: let body):
                let (data, response) = try await self.call(method: "PUT",
                                                           path: "/_/matrix/client/v3/sendToDevice/\(eventType)/\(requestId)",
                                                           body: body.data(using: .utf8)!)
                guard let responseBodyString = String(data: data, encoding: .utf8)
                else {
                    throw Matrix.Error("Couldn't process /sendToDevice response")
                }
                try self.crypto.markRequestAsSent(requestId: requestId,
                                                  requestType: .toDevice,
                                                  response: responseBodyString)
                
            case .keysUpload(requestId: let requestId, body: let body):
                let (data, response) = try await self.call(method: "PUT",
                                                           path: "/_matrix/client/v3/keys/upload",
                                                           body: body.data(using: .utf8)!)
                guard let responseBodyString = String(data: data, encoding: .utf8)
                else {
                    throw Matrix.Error("Couldn't process /keys/upload response")
                }
                try self.crypto.markRequestAsSent(requestId: requestId,
                                                  requestType: .keysUpload,
                                                  response: responseBodyString)
            
            case .keysQuery(requestId: let requestId, users: let users):
                // poljar says the Rust code intentionally ignores the timeout and device id's here
                // weird but ok whatever
                var deviceKeys: [String: [String]] = .init()
                for user in users {
                    deviceKeys[user] = []
                }
                let (data, response) = try await self.call(method: "POST",
                                                           path: "/_matix/client/v3/keys/query",
                                                           body: [
                                                            "device_keys": deviceKeys
                                                           ])
                guard let responseBodyString = String(data: data, encoding: .utf8)
                else {
                    throw Matrix.Error("Couldn't process /keys/query response body")
                }
                try self.crypto.markRequestAsSent(requestId: requestId,
                                                  requestType: .keysQuery,
                                                  response: responseBodyString)
                
            case .keysClaim(requestId: let requestId, oneTimeKeys: let oneTimeKeys):
                let (data, response) = try await self.call(method: "POST",
                                                           path: "/_matrix/client/v3/keys/claim",
                                                           body: [
                                                            "one_time_keys": oneTimeKeys
                                                           ])
                guard let responseBodyString = String(data: data, encoding: .utf8)
                else {
                    throw Matrix.Error("Couldn't process /keys/claim response")
                }
                try self.crypto.markRequestAsSent(requestId: requestId,
                                                  requestType: .keysClaim,
                                                  response: responseBodyString)
                
            case .keysBackup(requestId: let requestId, version: let backupVersion, rooms: let rooms):
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
                    throw Matrix.Error("Couldn't process /room_keys/keys response")
                }
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
                    throw Matrix.Error("Couldn't process /send/\(eventType) response")
                }
                try self.crypto.markRequestAsSent(requestId: requestId,
                                                  requestType: .roomMessage,
                                                  response: responseBodyString)
                
            case .signatureUpload(requestId: let requestId, body: let body):
                let requestBody = body.data(using: .utf8)!
                let (data, response) = try await self.call(method: "POST",
                                                           path: "/_matrix/client/v3/keys/signatures/upload",
                                                           body: requestBody)
                guard let responseBodyString = String(data: data, encoding: .utf8)
                else {
                    throw Matrix.Error("Couldn't process /keys/signatures/upload response")
                }
                try self.crypto.markRequestAsSent(requestId: requestId,
                                                  requestType: .signatureUpload,
                                                  response: responseBodyString)
            } // end case request
        } // end sendCryptoRequests()

        
        public func pause() async throws {
            // pause() doesn't actually make any API calls
            // It just tells our own local sync task to take a break
            throw Matrix.Error("Not implemented yet")
        }
        
        public func close() async throws {
            // close() is like pause; it doesn't make any API calls
            // It just tells our local sync task to shut down
            throw Matrix.Error("Not implemented yet")
        }
        
        public func createRecovery(privateKey: Data) async throws {
            throw Matrix.Error("Not implemented yet")
        }
        
        public func deleteRecovery() async throws {
            throw Matrix.Error("Not implemented yet")
        }
        
        public func whoAmI() async throws -> UserId {
            return self.creds.userId
        }
        
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
        
        public func getRoom(roomId: RoomId) async throws -> Matrix.Room? {
            if let existingRoom = self.rooms[roomId] {
                return existingRoom
            }
            
            // Apparently we don't already have a Room object for this one
            // Let's see if we can find the necessary data to construct it
            
            // Do we have this room in our data store?
            if let store = self.dataStore {
                let events = try await store.loadEssentialState(for: roomId)
                if events.count > 0 {
                    if let room = try? Matrix.Room(roomId: roomId, session: self, initialState: events) {
                        await MainActor.run {
                            self.rooms[roomId] = room
                        }
                        return room
                    }
                }
            }
            
            // Ok we didn't have the room state cached locally
            // Maybe the server knows about this room?
            let events = try await getRoomStateEvents(roomId: roomId)
            if let room = try? Matrix.Room(roomId: roomId, session: self, initialState: events, initialTimeline: []) {
                await MainActor.run {
                    self.rooms[roomId] = room
                }
                return room
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
            
            let users: [String] = room.joinedMembers.map {
                $0.description
            }
            if let missingSessionsRequest = try self.crypto.getMissingSessions(users: users) {
                // Send the missing sessions request
                try await self.sendCryptoRequest(request: missingSessionsRequest)
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
                    
            let shareRoomKeyRequests = try self.crypto.shareRoomKey(roomId: roomId.description,
                                                                    users: users,
                                                                    settings: settings)
            for request in shareRoomKeyRequests {
                try await self.sendCryptoRequest(request: request)
            }
            
            let encoder = JSONEncoder()
            let binaryContent = try encoder.encode(content)
            let stringContent = String(data: binaryContent, encoding: .utf8)!
            let encryptedString = try self.crypto.encrypt(roomId: roomId.description,
                                                          eventType: type,
                                                          content: stringContent)
            print("Got encrypted string = [\(encryptedString)]")
            let encryptedData = encryptedString.data(using: .utf8)!
            let encryptedContent = try Matrix.decodeEventContent(of: M_ROOM_ENCRYPTED, from: encryptedData)
            return try await super.sendMessageEvent(to: roomId,
                                                    type: M_ROOM_ENCRYPTED,
                                                    content: encryptedContent)
        }

        // MARK: Encrypted Media
        
        func encryptAndUploadData(plaintext: Data, contentType: String) async throws -> mEncryptedFile {
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
        
        func downloadAndDecryptData(_ info: mEncryptedFile) async throws -> Data {
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
                                         limit: Int? = 25
        ) async throws -> [ClientEventWithoutRoomId] {
            let events = try await super.getMessages(roomId: roomId, forward: forward, from: startToken, to: endToken, limit: limit)
            return self.tryToDecryptEvents(events: events, in: roomId)
        }
        
        // MARK: Decrypting Messsages
        
        private func tryToDecryptEvents(events: [ClientEventWithoutRoomId],
                                        in roomId: RoomId
        ) -> [ClientEventWithoutRoomId] {
            events.compactMap { event in
                switch event.type {
                case M_ROOM_ENCRYPTED:
                    // Try to decrypt any encrypted events in the timeline
                    let maybeDecrypted = try? self.decryptMessageEvent(event, in: roomId)
                    // But if we failed to decrypt, keep the encrypted event around
                    // Maybe we didn't get the key the first time around
                    // We can always ask for it later
                    return maybeDecrypted ?? event
                default:
                    // Keep everything else as-is for now
                    return event
                }
            }
        }
        
        private func decryptMessageEvent(_ encryptedEvent: ClientEventWithoutRoomId,
                                         in roomId: RoomId
        ) throws -> ClientEventWithoutRoomId {
            logger.debug("Trying to decrypt event \(encryptedEvent.eventId)")
            let encoder = JSONEncoder()
            let encryptedData = try encoder.encode(encryptedEvent)
            let encryptedString = String(data: encryptedData, encoding: .utf8)!
            //let contentData = try encoder.encode(event.content)
            //let contentString = String(data: contentData, encoding: .utf8)!
            logger.debug("Encoded event string = \(encryptedString)")
            //logger.debug("Encoded event content = \(contentString)")
            logger.debug("Trying to decrypt...")
            guard let decryptedStruct = try? crypto.decryptRoomEvent(event: encryptedString, roomId: "\(roomId)", handleVerificatonEvents: true)
            else {
                logger.error("Failed to decrypt event \(encryptedEvent.eventId)")
                throw Matrix.Error("Failed to decrypt")
            }
            let decryptedString = decryptedStruct.clearEvent
            logger.debug("Decrypted event:\t\(decryptedString)")
            
            let decoder = JSONDecoder()
            guard let decryptedMinimalEvent = try? decoder.decode(MinimalEvent.self, from: decryptedString.data(using: .utf8)!)
            else {
                logger.error("Failed to decode decrypted event")
                throw Matrix.Error("Failed to decode decrypted event")
            }
            return try ClientEventWithoutRoomId(content: decryptedMinimalEvent.content,
                                            eventId: encryptedEvent.eventId,
                                            originServerTS: encryptedEvent.originServerTS,
                                            sender: encryptedEvent.sender,
                                            // stateKey should be nil, since we decrypted something; must not be a state event.
                                            type: decryptedMinimalEvent.type)
        }
        

        
    }
}
