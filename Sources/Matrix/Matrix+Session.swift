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
        
        init(creds: Credentials, startSyncing: Bool = true) throws {
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
        
        // MARK: Sync
        // https://spec.matrix.org/v1.2/client-server-api/#get_matrixclientv3sync
        func sync() async throws -> String? {
            
            struct SyncResponseBody: Decodable {
                struct MinimalEventsContainer: Decodable {
                    var events: [MinimalEvent]?
                }
                struct AccountData: Decodable {
                    // Here we can't use the MinimalEvent type that we already defined
                    // Because Matrix is batshit and puts crazy stuff into these `type`s
                    struct Event: Decodable {
                        var type: AccountDataType
                        var content: Decodable
                        
                        enum CodingKeys: String, CodingKey {
                            case type
                            case content
                        }
                        
                        init(from decoder: Decoder) throws {
                            let container = try decoder.container(keyedBy: CodingKeys.self)
                            
                            self.type = try container.decode(AccountDataType.self, forKey: .type)
                            self.content = try Matrix.decodeAccountData(of: self.type, from: decoder)
                        }
                    }
                    var events: [Event]?
                }
                typealias Presence =  MinimalEventsContainer
                typealias Ephemeral = MinimalEventsContainer
                
                struct Rooms: Decodable {
                    var invite: [RoomId: InvitedRoomSyncInfo]?
                    var join: [RoomId: JoinedRoomSyncInfo]?
                    var knock: [RoomId: KnockedRoomSyncInfo]?
                    var leave: [RoomId: LeftRoomSyncInfo]?
                }
                struct InvitedRoomSyncInfo: Decodable {
                    struct InviteState: Decodable {
                        var events: [StrippedStateEvent]?
                    }
                    var inviteState: InviteState?
                }
                struct StateEventsContainer: Decodable {
                    var events: [ClientEventWithoutRoomId]?
                }
                struct Timeline: Decodable {
                    var events: [ClientEventWithoutRoomId]
                    var limited: Bool?
                    var prevBatch: String?
                }
                struct JoinedRoomSyncInfo: Decodable {
                    struct RoomSummary: Decodable {
                        var heroes: [UserId]?
                        var invitedMemberCount: Int?
                        var joinedMemberCount: Int?
                        
                        enum CodingKeys: String, CodingKey {
                            case heroes = "m.heroes"
                            case invitedMemberCount = "m.invited_member_count"
                            case joinedMemberCount = "m.joined_member_count"
                        }
                    }
                    struct UnreadNotificationCounts: Decodable {
                        // FIXME: The spec gives the type for these as "Highlighted notification count" and "Total notification count" -- Hopefully it's a typo, and those should have been in the description column instead
                        var highlightCount: Int
                        var notificationCount: Int
                    }
                    var accountData: AccountData?
                    var ephemeral: Ephemeral?
                    var state: StateEventsContainer?
                    var summary: RoomSummary?
                    var timeline: Timeline?
                    var unreadNotifications: UnreadNotificationCounts?
                }
                struct KnockedRoomSyncInfo: Decodable {
                    struct KnockState: Decodable {
                        var events: [StrippedStateEvent]
                    }
                    var knockState: KnockState?
                }
                struct LeftRoomSyncInfo: Decodable {
                    var accountData: AccountData?
                    var state: StateEventsContainer?
                    var timeline: Timeline?
                }
                struct ToDevice: Decodable {
                    var events: [ToDeviceEvent]
                }
                struct DeviceLists: Decodable {
                    var changed: [UserId]?
                    var left: [UserId]?
                }
                typealias OneTimeKeysCount = [String : Int]
                
                var accountData: AccountData?
                var deviceLists: DeviceLists?
                var deviceOneTimeKeysCount: OneTimeKeysCount?
                var nextBatch: String
                var presence: Presence?
                var rooms: Rooms?
                var toDevice: ToDevice?
            }
            
            // FIXME: Use a TaskGroup
            syncRequestTask = syncRequestTask ?? .init(priority: .background) {
                var url = "/_matrix/client/v3/sync?timeout=\(self.syncRequestTimeout)"
                if let token = syncToken {
                    url += "&since=\(token)"
                }
                let (data, response) = try await self.call(method: "GET", path: url)
                
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
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                guard let responseBody = try? decoder.decode(SyncResponseBody.self, from: data)
                else {
                    self.syncRequestTask = nil
                    throw Matrix.Error("Could not decode /sync response")
                }
                
                // Process the sync response, updating local state
                
                // Handle invites
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
    }
}
