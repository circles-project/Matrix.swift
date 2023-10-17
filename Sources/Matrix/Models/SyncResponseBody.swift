//
//  SyncResponseBody.swift
//  
//
//  Created by Charles Wright on 12/8/22.
//

import Foundation

extension Matrix {
    
    public struct SyncResponseBody: Decodable {
        public struct MinimalEventsContainer: Decodable {
            public var events: [MinimalEvent]?
            
            public enum CodingKeys: CodingKey {
                case events
            }
            
            public init(from decoder: Decoder) throws {
                let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
                if let lossy = try container.decodeIfPresent(LossyCodableList<MinimalEvent>.self, forKey: .events) {
                    self.events = lossy.elements
                } else {
                    self.events = nil
                }
            }
        }
        
        public struct AccountData: Codable {
            // Here we can't use the MinimalEvent type that we already defined
            // Because Matrix is batshit and puts crazy stuff into these `type`s
            public var events: [AccountDataEvent]?
            
            public enum CodingKeys: CodingKey {
                case events
            }
            
            public init(from decoder: Decoder) throws {
                let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
                if let lossy = try container.decodeIfPresent(LossyCodableList<AccountDataEvent>.self, forKey: .events) {
                    self.events = lossy.elements
                } else {
                    self.events = nil
                }
            }
        }
        
        public typealias Presence =  MinimalEventsContainer
        public typealias Ephemeral = MinimalEventsContainer
        
        public struct Rooms: Decodable {
            public var invite: [RoomId: InvitedRoomSyncInfo]?
            public var join: [RoomId: JoinedRoomSyncInfo]?
            public var knock: [RoomId: KnockedRoomSyncInfo]?
            public var leave: [RoomId: LeftRoomSyncInfo]?
            
            public enum CodingKeys: CodingKey {
                case invite
                case join
                case knock
                case leave
            }
            
            public init(from decoder: Decoder) throws {
                logger.debug("Decoding Rooms")
                let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
                logger.debug("invite")
                self.invite = try container.decodeIfPresent([RoomId : InvitedRoomSyncInfo].self, forKey: .invite)
                logger.debug("join")
                self.join = try container.decodeIfPresent([RoomId : JoinedRoomSyncInfo].self, forKey: .join)
                logger.debug("knock")
                self.knock = try container.decodeIfPresent([RoomId : KnockedRoomSyncInfo].self, forKey: .knock)
                logger.debug("leave")
                self.leave = try container.decodeIfPresent([RoomId : LeftRoomSyncInfo].self, forKey: .leave)
            }
        }
        
        public struct InvitedRoomSyncInfo: Decodable {
            public typealias InviteState = StrippedStateEventsContainer
            public var inviteState: InviteState?
            
            public enum CodingKeys: String, CodingKey {
                case inviteState = "invite_state"
            }
        }
        
        public struct StateEventsContainer: Decodable {
            public var events: [ClientEventWithoutRoomId]?
            
            public enum CodingKeys: CodingKey {
                case events
            }
            
            public init(from decoder: Decoder) throws {
                let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
                if let lossy = try container.decodeIfPresent(LossyCodableList<ClientEventWithoutRoomId>.self, forKey: .events) {
                    self.events = lossy.elements
                } else {
                    self.events = nil
                }
            }
        }
        
        public struct StrippedStateEventsContainer: Decodable {
            public var events: [StrippedStateEvent]?
            
            public enum CodingKeys: CodingKey {
                case events
            }
            
            public init(from decoder: Decoder) throws {
                let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
                let lossy = try container.decode(LossyCodableList<StrippedStateEvent>.self, forKey: .events)
                self.events = lossy.elements
            }
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
            
            public init(from decoder: Decoder) throws {
                let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
                let lossy = try container.decode(LossyCodableList<ClientEventWithoutRoomId>.self, forKey: .events)
                self.events = lossy.elements
                self.limited = try container.decodeIfPresent(Bool.self, forKey: .limited)
                self.prevBatch = try container.decodeIfPresent(String.self, forKey: .prevBatch)
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
            
            public init(from decoder: Decoder) throws {
                logger.debug("Decoding JoinedRoomSyncInfo")
                let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

                logger.debug("Account Data")
                self.accountData = try container.decodeIfPresent(Matrix.SyncResponseBody.AccountData.self, forKey: .accountData)

                logger.debug("Ephemeral")
                self.ephemeral = try container.decodeIfPresent(Matrix.SyncResponseBody.Ephemeral.self, forKey: .ephemeral)

                logger.debug("State")
                self.state = try container.decodeIfPresent(Matrix.SyncResponseBody.StateEventsContainer.self, forKey: .state)

                logger.debug("Summary")
                self.summary = try container.decodeIfPresent(Matrix.SyncResponseBody.JoinedRoomSyncInfo.RoomSummary.self, forKey: .summary)

                logger.debug("Timeline")
                self.timeline = try container.decodeIfPresent(Matrix.SyncResponseBody.Timeline.self, forKey: .timeline)

                logger.debug("Unread Notifications")
                self.unreadNotifications = try container.decodeIfPresent(Matrix.SyncResponseBody.JoinedRoomSyncInfo.UnreadNotificationCounts.self, forKey: .unreadNotifications)

                logger.debug("Unread Thread Notifications")
                self.unreadThreadNotifications = try container.decodeIfPresent([EventId : Matrix.SyncResponseBody.JoinedRoomSyncInfo.UnreadNotificationCounts].self, forKey: .unreadThreadNotifications)
            }
        }
        
        public struct KnockedRoomSyncInfo: Decodable {
            public typealias KnockState = StrippedStateEventsContainer
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
            
            public enum CodingKeys: CodingKey {
                case events
            }
            
            public init(from decoder: Decoder) throws {
                let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
                let lossy = try container.decode(LossyCodableList<ToDeviceEvent>.self, forKey: .events)
                self.events = lossy.elements
            }
        }
        
        public struct DeviceLists: Decodable {
            public var changed: [UserId]?
            public var left: [UserId]?
        }
        
        public typealias OneTimeKeysCount = [String : Int32]
        
        public var accountData: AccountData?
        public var deviceLists: DeviceLists?
        public var deviceOneTimeKeysCount: OneTimeKeysCount?
        public var deviceUnusedFallbackKeyTypes: [String]?
        public var nextBatch: String
        public var presence: Presence?
        public var rooms: Rooms?
        public var toDevice: ToDevice?
        
        public enum CodingKeys: String, CodingKey {
            case accountData = "account_data"
            case deviceLists = "device_lists"
            case deviceOneTimeKeysCount = "device_one_time_keys_count"
            case deviceUnusedFallbackKeyTypes = "device_unused_fallback_key_types"
            case nextBatch = "next_batch"
            case presence
            case rooms
            case toDevice = "to_device"
        }
        
        public init(from decoder: Decoder) throws {
            logger.debug("Decoding /sync response")
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            logger.debug("\tAccount data")
            self.accountData = try container.decodeIfPresent(AccountData.self, forKey: .accountData)
            
            logger.debug("\tDevice lists")
            self.deviceLists = try container.decodeIfPresent(DeviceLists.self, forKey: .deviceLists)
            
            logger.debug("\tDevice one-time keys count")
            self.deviceOneTimeKeysCount = try container.decodeIfPresent(OneTimeKeysCount.self, forKey: .deviceOneTimeKeysCount)
            
            logger.debug("\tDevice unused fallback key types")
            self.deviceUnusedFallbackKeyTypes = try container.decodeIfPresent([String].self, forKey: .deviceUnusedFallbackKeyTypes)
            
            logger.debug("\tNext batch")
            self.nextBatch = try container.decode(String.self, forKey: .nextBatch)
            
            logger.debug("\tPresence")
            self.presence = try container.decodeIfPresent(Presence.self, forKey: .presence)
            
            logger.debug("\tRooms")
            self.rooms = try container.decodeIfPresent(Rooms.self, forKey: .rooms)
            
            logger.debug("\tTo-Device")
            self.toDevice = try container.decodeIfPresent(ToDevice.self, forKey: .toDevice)
        }
    }
}
