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
                        let messages = info.timeline?.events.filter {
                            $0.type == .mRoomMessage // FIXME: Encryption
                        }
                        let stateEvents = info.state?.events

                        if let room = self.rooms[roomId] {
                            print("\tWe know this room already")
                            print("\t\(stateEvents?.count ?? 0) new state events")
                            print("\t\(messages?.count ?? 0) new messages")

                            // Update the room with the latest data from `info`
                            room.updateState(from: stateEvents ?? [])
                            room.messages.formUnion(messages ?? [])
                            
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
                            
                            guard let initialStateEvents = stateEvents
                            else {
                                print("Can't create a new room with no initial state (room id = \(roomId))")
                                continue
                            }
                            print("\t\(initialStateEvents.count) initial state events")
                            print("\t\(messages?.count ?? 0) initial messages")
                            
                            guard let room = try? Room(roomId: roomId, session: self, initialState: initialStateEvents, initialMessages: messages ?? [])
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
            
            }
            
            guard let task = syncRequestTask else {
                print("Error: /sync Failed to launch sync request task")
                return nil
            }
            return try await task.value
        }

        
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
    }
}
