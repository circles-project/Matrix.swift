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
    class Session: Matrix.Client, ObservableObject {
        @Published var displayName: String?
        @Published var avatarUrl: URL?
        @Published var avatar: Matrix.NativeImage?
        @Published var statusMessage: String?
        
        // cvw: Leaving these as comments for now, as they require us to define even more types
        //@Published var device: MatrixDevice
        
        @Published var rooms: [RoomId: Matrix.Room]
        @Published var invitations: [RoomId: Matrix.InvitedRoom]

        // Need some private stuff that outside callers can't see
        private var syncRequestTask: Task<String?,Swift.Error>? // FIXME Use a TaskGroup to make this subordinate to the backgroundSyncTask
        private var syncToken: String? = nil
        private var syncRequestTimeout: Int = 30_000
        private var keepSyncing: Bool
        private var syncDelayNs: UInt64 = 30_000_000_000
        private var backgroundSyncTask: Task<UInt,Swift.Error>? // FIXME use a TaskGroup
        
        private var ignoreUserIds: Set<UserId>

        // We need to use the Matrix 'recovery' feature to back up crypto keys etc
        // This saves us from struggling with UISI errors and unverified devices
        private var recoverySecretKey: Data?
        private var recoveryTimestamp: Date?
        
        // Matrix Rust crypto
        private var crypto: MatrixSDKCrypto.OlmMachine
        
        init(creds: Credentials, startSyncing: Bool = true) throws {
            self.rooms = [:]
            self.invitations = [:]
            
            self.ignoreUserIds = []
            
            self.keepSyncing = startSyncing
            // Initialize the sync tasks to nil so we can run super.init()
            self.syncRequestTask = nil
            self.backgroundSyncTask = nil
            
            let documentsPath = NSSearchPathForDirectoriesInDomains(
                .documentDirectory, .userDomainMask, true
            ).first!
            let cryptoStorePath = "\(documentsPath)/\(creds.userId)/\(creds.deviceId)/crypto"
            self.crypto = try OlmMachine(userId: "\(creds.userId)", deviceId: creds.deviceId, path: cryptoStorePath, passphrase: nil)
            
            try super.init(creds: creds)
            
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
        func sync() async throws -> String? {
            
            // FIXME: Use a TaskGroup
            syncRequestTask = syncRequestTask ?? .init(priority: .background) {
                var url = "/_matrix/client/v3/sync?timeout=\(self.syncRequestTimeout)"
                if let token = syncToken {
                    url += "&since=\(token)"
                }
                let (data, response) = try await self.call(method: "GET", path: url)
                
                let rawDataString = String(data: data, encoding: .utf8)
                print("\n\n\(rawDataString!)\n\n")
                
                guard response.statusCode == 200 else {
                    print("ERROR: /sync got HTTP \(response.statusCode) \(response.description)")
                    if response.statusCode == 429 {
                        // Slow down!
                        // FIXME: Decode the response data to find out how much we should slow down
                        try await Task.sleep(nanoseconds: 30_000_000_000)
                    }
                    return self.syncToken
                }
                
                let decoder = JSONDecoder()
                //decoder.keyDecodingStrategy = .convertFromSnakeCase
                guard let responseBody = try? decoder.decode(SyncResponseBody.self, from: data)
                else {
                    self.syncRequestTask = nil
                    throw Matrix.Error("Could not decode /sync response")
                }
                
                // Process the sync response, updating local state
                
                // Send updates to the Rust crypto module
                try self.updateCryptoAfterSync(responseBody: responseBody)
                
                // Handle invites
                print("/sync:\tHandling invites")
                if let invitedRoomsDict = responseBody.rooms?.invite {
                    for (roomId, info) in invitedRoomsDict {
                        print("/sync:\tFound invited room \(roomId)")
                        guard let events = info.inviteState?.events
                        else {
                            continue
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
                    for (roomId, info) in joinedRoomsDict {
                        print("/sync:\tFound joined room \(roomId)")
                        
                        let stateEvents = info.state?.events ?? []
                        
                        // Update the crypto module about any new users
                        let newUsers = stateEvents.filter {
                            // Find all of the room member events that represent a joined member of the room
                            guard $0.type == .mRoomMember,
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
                        print("\tUpdating crypto state with \(newUsers.count) potentially-new users")
                        crypto.updateTrackedUsers(users: newUsers)
                        
                        let messages: [ClientEventWithoutRoomId] = info.timeline?.events.compactMap { event in
                            switch event.type {
                            case .mEncrypted:
                                // Try to decrypt any encrypted events in the timeline
                                let maybeDecrypted = try? self.decryptMessageEvent(event: event, in: roomId)
                                // But if we failed to decrypt, keep the encrypted event around
                                // Maybe we didn't get the key the first time around
                                // We can always ask for it later
                                return maybeDecrypted ?? event
                            default:
                                // Keep everything else as-is for now
                                return event
                            }
                        } ?? []
                        
                        if let room = self.rooms[roomId] {
                            print("\tWe know this room already")
                            print("\t\(stateEvents.count) new state events")
                            print("\t\(messages.count) new messages")

                            // Update the room with the latest data from `info`
                            room.updateState(from: stateEvents)
                            room.messages.formUnion(messages)
                            
                            if let unread = info.unreadNotifications {
                                print("\t\(unread.notificationCount) notifications")
                                print("\t\(unread.highlightCount) highlights")
                                room.notificationCount = unread.notificationCount
                                room.highlightCount = unread.highlightCount
                            }
                            
                        } else {
                            print("\tThis is a new room")
                            
                            // Create the new Room object.  Also, remove the room id from the invites.
                            invitations.removeValue(forKey: roomId)
                            
                            guard stateEvents.count > 0
                            else {
                                print("Can't create a new room with no initial state (room id = \(roomId))")
                                continue
                            }
                            print("\t\(stateEvents.count) initial state events")
                            print("\t\(messages.count) initial messages")
                            
                            guard let room = try? Room(roomId: roomId, session: self, initialState: stateEvents, initialMessages: messages)
                            else {
                                print("Failed to create room \(roomId)")
                                continue
                            }
                            self.rooms[roomId] = room
                            
                            if let unread = info.unreadNotifications {
                                print("\t\(unread.notificationCount) notifications")
                                print("\t\(unread.highlightCount) highlights")
                                room.notificationCount = unread.notificationCount
                                room.highlightCount = unread.highlightCount
                            }
                        }
                    }
                } else {
                    print("/sync:\tNo joined rooms")
                }
                
                // Handle rooms that we've left
                if let leftRoomsDict = responseBody.rooms?.leave {
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

                self.syncToken = responseBody.nextBatch
                self.syncRequestTask = nil
                return responseBody.nextBatch
            
            } // end sync Task block
            
            guard let task = syncRequestTask else {
                print("Error: /sync Failed to launch sync request task")
                return nil
            }
            return try await task.value
        }
        
        private func updateCryptoAfterSync(responseBody: SyncResponseBody) throws {
            var eventsString = "[]"
            if let toDevice = responseBody.toDevice {
                let events = toDevice.events
                let encoder = JSONEncoder()
                let eventsData = try encoder.encode(events)
                eventsString = String(data: eventsData, encoding: .utf8)!
            }
            var deviceLists = MatrixSDKCrypto.DeviceLists(changed: [],left: [])
            // Ugh we have to translate back to raw String's
            if let changed = responseBody.deviceLists?.changed {
                deviceLists.changed = changed.map {
                    $0.description
                }
            }
            if let left = responseBody.deviceLists?.left {
                deviceLists.left = left.map {
                    $0.description
                }
            }
            let result = try self.crypto.receiveSyncChanges(events: eventsString,
                                                            deviceChanges: deviceLists,
                                                            keyCounts: responseBody.deviceOneTimeKeysCount ?? [:],
                                                            unusedFallbackKeys: responseBody.deviceUnusedFallbackKeyTypes)
        }

        // MARK: Session state management
        
        func pause() async throws {
            // pause() doesn't actually make any API calls
            // It just tells our own local sync task to take a break
            throw Matrix.Error("Not implemented yet")
        }
        
        func close() async throws {
            // close() is like pause; it doesn't make any API calls
            // It just tells our local sync task to shut down
            throw Matrix.Error("Not implemented yet")
        }
        
        func createRecovery(privateKey: Data) async throws {
            throw Matrix.Error("Not implemented yet")
        }
        
        func deleteRecovery() async throws {
            throw Matrix.Error("Not implemented yet")
        }
        
        func whoAmI() async throws -> UserId {
            return self.creds.userId
        }
        
        // MARK: Sending messages
        
        override func sendMessageEvent(to roomId: RoomId,
                                       type: Matrix.EventType,
                                       content: Codable
        ) async throws -> EventId {
            // First, do we know about this room at all?
            guard let room = self.rooms[roomId]
            else {
                throw Matrix.Error("Unkown room [\(roomId)]")
            }
            
            guard let params = room.encryptionParams
            else {
                return try await super.sendMessageEvent(to: roomId,
                                                        type: type,
                                                        content: content)
            }
            
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
            
            // I am now dumber for having written this
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
                                              historyVisibility: translate(room.historyVisibility),
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
                                                          eventType: type.rawValue,
                                                          content: stringContent)
            let encryptedData = encryptedString.data(using: .utf8)!
            return try await super.sendMessageEvent(to: roomId,
                                                    type: .mEncrypted,
                                                    content: encryptedData)
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
        
        // MARK: Decrypting Messsages
        
        private func decryptMessageEvent(event: ClientEventWithoutRoomId, in roomId: RoomId) throws -> ClientEventWithoutRoomId {
            let encoder = JSONEncoder()
            let eventData = try encoder.encode(event)
            let eventString = String(data: eventData, encoding: .utf8)!
            let decryptedStruct = try crypto.decryptRoomEvent(event: eventString,
                                                              roomId: roomId.description)
            let decryptedString = decryptedStruct.clearEvent
            
            let decoder = JSONDecoder()
            let decryptedClientEvent = try decoder.decode(ClientEventWithoutRoomId.self,
                                                          from: decryptedString.data(using: .utf8)!)
            return decryptedClientEvent
        }
        
        // MARK: Crypto Requests
        
        func sendCryptoRequest(request: Request) async throws {
            switch request {
                
            case .toDevice(requestId: let requestId, eventType: let eventType, body: let body):
                let (data, response) = try await self.call(method: "PUT",
                                                           path: "/_/matrix/client/\(version)/sendToDevice/\(eventType)/\(requestId)",
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
                                                           path: "/_matrix/client/\(version)/keys/upload",
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
                                                           path: "/_matix/client/\(version)/keys/query",
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
                                                           path: "/_matrix/client/\(version)/keys/claim",
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
                let urlPath = "/_matrix/client/\(version)/room_keys/keys?version=\(backupVersion)"
                let requestBodyString = "{\"rooms\": \(rooms)}"
                let requestBody = requestBodyString.data(using: .utf8)!
                let (data, response) = try await self.call(method: "PUT",
                                                           path: urlPath,
                                                           body: requestBody)
                guard let responseBodyString = String(data: data, encoding: .utf8)
                else {
                    throw Matrix.Error("Couldn't process /room_keys/keys response")
                }
                try self.crypto.markRequestAsSent(requestId: requestId,
                                                  requestType: .keysBackup,
                                                  response: responseBodyString)
                
            case .roomMessage(requestId: let requestId, roomId: let roomId, eventType: let eventType, content: let content):
                let requestBody = content.data(using: .utf8)!
                let urlPath = "/_matrix/client/\(version)/rooms/\(roomId)/send/\(eventType)/\(requestId)"
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
                                                           path: "/_matrix/client/\(version)/keys/signatures/upload",
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
    
    } // end class Session
}
