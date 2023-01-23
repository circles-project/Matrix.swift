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

extension Matrix {
    public class Session: Matrix.Client, ObservableObject, Codable, Storable {
        public typealias StorableObject = Session
        public typealias StorableKey = Credentials.StorableKey
        
        @Published public var displayName: String?
        @Published public var avatarUrl: URL?
        @Published public var avatar: Matrix.NativeImage?
        @Published public var statusMessage: String?
        
        // cvw: Leaving these as comments for now, as they require us to define even more types
        //@Published public var device: MatrixDevice
        
        @Published public var rooms: [RoomId: Matrix.Room]
        @Published public var invitations: [RoomId: Matrix.InvitedRoom]

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
        
        public enum CodingKeys: String, CodingKey {
            case credentials
            case displayName
            case avatarUrl
            case avatar
            case statusMessage
            // rooms not being encoded in session object
            // invitations not being encoded in session object
            // syncRequestTask not being encoded
            case syncToken
            case syncRequestTimeout
            case keepSyncing
            case syncDelayNs
            // backgroundSyncTask not being encoded
            case ignoreUserIds
            case recoverySecretKey
            case recoveryTimestamp
        }
        
        public init(creds: Credentials, startSyncing: Bool = true) throws {
            self.rooms = [:]
            self.invitations = [:]
            
            self.ignoreUserIds = []
            
            self.keepSyncing = startSyncing
            // Initialize the sync tasks to nil so we can run super.init()
            self.syncRequestTask = nil
            self.backgroundSyncTask = nil
            
            
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
            
        public required convenience init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let creds = try container.decode(Credentials.self, forKey: .credentials)
            let startSyncing = try container.decode(Bool.self, forKey: .keepSyncing)
            // FIXME: do proper class initalization and decoding
            try self.init(creds: creds, startSyncing: startSyncing)
            
            self.displayName = try container.decode(String.self, forKey: .displayName)
            self.avatarUrl = try container.decode(URL.self, forKey: .avatarUrl)
            self.avatar = try container.decode(NativeImage.self, forKey: .avatar)
            self.statusMessage = try container.decode(String.self, forKey: .statusMessage)
            self.syncToken = try container.decode(String.self, forKey: .syncToken)
            self.syncRequestTimeout = try container.decode(Int.self, forKey: .syncRequestTimeout)
            self.ignoreUserIds = try container.decode(Set<UserId>.self, forKey: .ignoreUserIds)
            self.recoverySecretKey = try container.decode(Data.self, forKey: .recoverySecretKey)
            self.recoveryTimestamp = try container.decode(Date.self, forKey: .recoveryTimestamp)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.creds, forKey: .credentials)
            try container.encode(displayName, forKey: .displayName)
            try container.encode(avatarUrl, forKey: .avatarUrl)
            try container.encode(avatar, forKey: .avatar)
            try container.encode(statusMessage, forKey: .statusMessage)
            try container.encode(syncToken, forKey: .syncToken)
            try container.encode(syncRequestTimeout, forKey: .syncRequestTimeout)
            try container.encode(keepSyncing, forKey: .keepSyncing)
            try container.encode(syncDelayNs, forKey: .syncDelayNs)
            try container.encode(recoverySecretKey, forKey: .recoverySecretKey)
            try container.encode(recoveryTimestamp, forKey: .recoveryTimestamp)
        }
        
        // MARK: Sync
        // https://spec.matrix.org/v1.2/client-server-api/#get_matrixclientv3sync
        public func sync() async throws -> String? {
            
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
                    //return self.syncToken
                    return nil
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
                if let invitedRoomsDict = responseBody.rooms?.invite {
                    print("/sync:\t\(invitedRoomsDict.count) invited rooms")
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
                    print("/sync:\t\(joinedRoomsDict.count) joined rooms")
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
                    print("/sync:\tMainActor updating sync token")
                    self.syncToken = responseBody.nextBatch
                    self.syncRequestTask = nil
                }

                print("/sync:\tDone!")
                return responseBody.nextBatch
            
            }
            
            guard let task = syncRequestTask else {
                print("Error: /sync Failed to launch sync request task")
                return nil
            }
            return try await task.value
        }

        
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
    }
}
