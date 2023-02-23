//
//  SyncResponseBody.swift
//  
//
//  Created by Charles Wright on 12/8/22.
//

import Foundation

extension Matrix {
    
    public struct AccountDataEvent: Decodable {
        public var type: String
        public var content: Decodable
        
        public enum CodingKeys: String, CodingKey {
            case type
            case content
        }
        
        public init(from decoder: Decoder) throws {
            print("Decoding account data event")
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.type = try container.decode(String.self, forKey: .type)
            print("\tGot type = \(self.type)")
            self.content = try Matrix.decodeAccountData(of: self.type, from: decoder)
        }
    }
    
    public struct SyncResponseBody: Decodable {
        public struct MinimalEventsContainer: Decodable {
            public var events: [MinimalEvent]?
        }
        
        public struct AccountData: Decodable {
            // Here we can't use the MinimalEvent type that we already defined
            // Because Matrix is batshit and puts crazy stuff into these `type`s
            public var events: [AccountDataEvent]?
        }
        
        public typealias Presence =  MinimalEventsContainer
        public typealias Ephemeral = MinimalEventsContainer
        
        public struct Rooms: Decodable {
            public var invite: [RoomId: InvitedRoomSyncInfo]?
            public var join: [RoomId: JoinedRoomSyncInfo]?
            public var knock: [RoomId: KnockedRoomSyncInfo]?
            public var leave: [RoomId: LeftRoomSyncInfo]?
        }
        
        public struct InvitedRoomSyncInfo: Decodable {
            public struct InviteState: Decodable {
                public var events: [StrippedStateEvent]?
            }
            public var inviteState: InviteState?
            
            public enum CodingKeys: String, CodingKey {
                case inviteState = "invite_state"
            }
        }
        
        public struct StateEventsContainer: Decodable {
            public var events: [ClientEventWithoutRoomId]?
        }
        
        public struct Timeline: Decodable {
            public var events: [ClientEventWithoutRoomId]
            public var limited: Bool?
            public var prevBatch: String?
            
            public enum CodingKeys: String, CodingKey {
                case events
                case limited
                case prevBatch = "prev_batch"
            }
        }
        
        public struct JoinedRoomSyncInfo: Decodable {
            public struct RoomSummary: Decodable {
                public var heroes: [UserId]?
                public var invitedMemberCount: Int?
                public var joinedMemberCount: Int?
                
                public enum CodingKeys: String, CodingKey {
                    case heroes = "m.heroes"
                    case invitedMemberCount = "m.invited_member_count"
                    case joinedMemberCount = "m.joined_member_count"
                }
            }
            public struct UnreadNotificationCounts: Decodable {
                // FIXME: The spec gives the type for these as "Highlighted notification count" and "Total notification count" -- Hopefully it's a typo, and those should have been in the description column instead
                public var highlightCount: Int
                public var notificationCount: Int
                
                public enum CodingKeys: String, CodingKey {
                    case highlightCount = "highlight_count"
                    case notificationCount = "notification_count"
                }
            }
            public var accountData: AccountData?
            public var ephemeral: Ephemeral?
            public var state: StateEventsContainer?
            public var summary: RoomSummary?
            public var timeline: Timeline?
            public var unreadNotifications: UnreadNotificationCounts?
            public var unreadThreadNotifications: [EventId: UnreadNotificationCounts]?
            
            public enum CodingKeys: String, CodingKey {
                case accountData = "account_data"
                case ephemeral
                case state
                case summary
                case timeline
                case unreadNotifications = "unread_notifications"
                case unreadThreadNotifications = "unread_thread_notifications"
            }
        }
        
        public struct KnockedRoomSyncInfo: Decodable {
            public struct KnockState: Decodable {
                public var events: [StrippedStateEvent]
            }
            public var knockState: KnockState?
            
            public enum CodingKeys: String, CodingKey {
                case knockState = "knock_state"
            }
        }
        
        public struct LeftRoomSyncInfo: Decodable {
            public var accountData: AccountData?
            public var state: StateEventsContainer?
            public var timeline: Timeline?
            
            public enum CodingKeys: String, CodingKey {
                case accountData = "account_data"
                case state
                case timeline
            }
        }
        
        public struct ToDevice: Decodable {
            public var events: [ToDeviceEvent]
        }
        
        public struct DeviceLists: Decodable {
            public var changed: [UserId]?
            public var left: [UserId]?
        }
        
        public typealias OneTimeKeysCount = [String : Int]
        
        public var accountData: AccountData?
        public var deviceLists: DeviceLists?
        public var deviceOneTimeKeysCount: OneTimeKeysCount?
        public var nextBatch: String
        public var presence: Presence?
        public var rooms: Rooms?
        public var toDevice: ToDevice?
        
        public enum CodingKeys: String, CodingKey {
            case accountData = "account_data"
            case deviceLists = "device_lists"
            case deviceOneTimeKeysCount = "device_one_time_keys_count"
            case nextBatch = "next_batch"
            case presence
            case rooms
            case toDevice = "to_device"
        }
        
        public init(from decoder: Decoder) throws {
            print("Decoding /sync response")
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            print("\tAccount data")
            self.accountData = try container.decodeIfPresent(AccountData.self, forKey: .accountData)
            
            print("\tDevice lists")
            self.deviceLists = try container.decodeIfPresent(DeviceLists.self, forKey: .deviceLists)
            
            print("\tDevice one-time keys count")
            self.deviceOneTimeKeysCount = try container.decodeIfPresent(OneTimeKeysCount.self, forKey: .deviceOneTimeKeysCount)
            
            print("\tNext batch")
            self.nextBatch = try container.decode(String.self, forKey: .nextBatch)
            
            print("\tPresence")
            self.presence = try container.decodeIfPresent(Presence.self, forKey: .presence)
            
            print("\tRooms")
            self.rooms = try container.decodeIfPresent(Rooms.self, forKey: .rooms)
            
            print("\tTo-Device")
            self.toDevice = try container.decodeIfPresent(ToDevice.self, forKey: .toDevice)
        }
    }
}
