//
//  RoomCreateContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

/// m.room.create: https://spec.matrix.org/v1.5/client-server-api/#mroomcreate
public struct RoomCreateContent: Codable {
    public let creator: UserId?
    /// Whether users on other servers can join this room. Defaults to true if key does not exist.
    public let federate: Bool?
    
    public struct PreviousRoom: Codable {
        public let eventId: EventId
        public let roomId: RoomId
        
        public init(eventId: EventId, roomId: RoomId) {
            self.eventId = eventId
            self.roomId = roomId
        }
        
        public enum CodingKeys: String, CodingKey {
            case eventId = "event_id"
            case roomId = "room_id"
        }
    }
    public let predecessor: PreviousRoom?
    
    /// The version of the room. Defaults to "1" if the key does not exist.
    public let roomVersion: String?
    public let type: String?
    
    public init(creator: UserId?, federate: Bool?, predecessor: PreviousRoom?,
                roomVersion: String?, type: String?) {
        self.creator = creator
        self.federate = federate
        self.predecessor = predecessor
        self.roomVersion = roomVersion
        self.type = type
    }
    
    public enum CodingKeys: String, CodingKey {
        case creator
        case federate = "m.federate"
        case predecessor
        case roomVersion = "room_version"
        case type
    }
}
