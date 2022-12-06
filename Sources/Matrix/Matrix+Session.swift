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
        //@Published var invitations: [RoomId: Matrix.InvitedRoom]

        // Need some private stuff that outside callers can't see
        //private var syncTask: Task?
        private var userCache: [UserId: Matrix.User]
        //private var roomCache: [String: Matrix.Room]
        //private var deviceCache: [String: Matrix.Device]
        private var ignoreUserIds: Set<UserId>

        // We need to use the Matrix 'recovery' feature to back up crypto keys etc
        // This saves us from struggling with UISI errors and unverified devices
        private var recoverySecretKey: Data?
        private var recoveryTimestamp: Date?
        
        override init(creds: Credentials) throws {
            self.rooms = [:]
            //self.invitations = [:]
            
            self.userCache = [:]
            //self.roomCache = [:]
            self.ignoreUserIds = []
            
            try super.init(creds: creds)
        }
        
        // MARK: Sync
        /*
        // https://spec.matrix.org/v1.2/client-server-api/#get_matrixclientv3sync
        func sync() async throws {
            struct SyncRequestBody: Codable {
                var filter: String?
                var fullState: Bool?
                var setPresence: String?
                var since: String?
                var timeout: Int?
            }
            
            struct SyncResponseBody: Codable {
                struct MinimalEventsContainer: Codable {
                    var events: [MinimalEvent]?
                }
                struct AccountData: Codable {
                    // Here we can't use the MinimalEvent type that we already defined
                    // Because Matrix is batshit and puts crazy stuff into these `type`s
                    struct Event: Codable {
                        var type: String
                        var content: Codable
                    }
                    var events: [Event]?
                }
                typealias Presence =  MinimalEventsContainer
                typealias Ephemeral = MinimalEventsContainer
                
                struct Rooms: Codable {
                    var invite: [RoomId: InvitedRoomSyncInfo]?
                    var join: [RoomId: JoinedRoomSyncInfo]?
                    var knock: [RoomId: KnockedRoomSyncInfo]?
                    var leave: [RoomId: LeftRoomSyncInfo]?
                }
                struct InvitedRoomSyncInfo: Codable {
                    struct InviteState: Codable {
                        var events: [StrippedStateEvent]?
                    }
                    var inviteState: InviteState?
                }
                struct StateEventsContainer: Codable {
                    var events: [ClientEventWithoutRoomId]?
                }
                struct Timeline: Codable {
                    var events: [ClientEventWithoutRoomId]
                    var limited: Bool?
                    var prevBatch: String?
                }
                struct JoinedRoomSyncInfo: Codable {
                    struct RoomSummary: Codable {
                        var heroes: [UserId]?
                        var invitedMemberCount: Int?
                        var joinedMemberCount: Int?
                        
                        enum CodingKeys: String, CodingKey {
                            case heroes = "m.heroes"
                            case invitedMemberCount = "m.invited_member_count"
                            case joinedMemberCount = "m.joined_member_count"
                        }
                    }
                    struct UnreadNotificationCounts: Codable {
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
                struct KnockedRoomSyncInfo: Codable {
                    struct KnockState: Codable {
                        var events: [StrippedStateEvent]
                    }
                    var knockState: KnockState?
                }
                struct LeftRoomSyncInfo: Codable {
                    var accountData: AccountData?
                    var state: StateEventsContainer?
                    var timeline: Timeline?
                }
                struct ToDevice: Codable {
                    var events: [ToDeviceEvent]
                }
                struct DeviceLists: Codable {
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
            
            if let task = syncTask {
                return await task
            } else {
                syncTask = Task {
                    let requestBody = SyncRequestBody(timeout: 0)
                    let (data, response) = try await self.matrixApiCall(method: "GET", path: "/_matrix/client/v3/sync", body: requestBody)
                    
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    guard let responseBody = try? decoder.decode(SyncResponseBody.self, from: data)
                    else {
                        self.syncTask = nil
                        throw Error()
                    }
                    
                    // Process the sync response, updating local state
                    
                    // Handle invites
                    if let invitedRoomsDict = responseBody.rooms?.invite {
                        for (roomId, info) in invitedRoomsDict {
                            guard let events = info.inviteState.events
                            else {
                                continue
                            }
                            if self.invitations[roomId] == nil {
                                let room = InvitedRoom(matrix: self, roomId: RoomId, stateEvents: events)
                                self.invitations[roomId] = room
                            }
                        }
                    }
                    
                    // Handle rooms where we're already joined
                    if let joinedRoomsDict = responseBody.rooms?.join {
                        for (roomId, info) in joinedRoomsDict {
                            if let room = self.rooms[roomId] {
                                // Update the room with the latest data from `info`
                            } else {
                                // What the heck should we do here???
                                // Do we create the Room object, or not???
                            }
                        }
                    }
                    
                    
                    self.syncTask = nil
                }
            }
        }
        */
        
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
