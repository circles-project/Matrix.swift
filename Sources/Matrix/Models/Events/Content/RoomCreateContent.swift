//
//  RoomCreateContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

/// m.room.create: https://spec.matrix.org/v1.5/client-server-api/#mroomcreate
struct RoomCreateContent: Codable {
    let creator: UserId
    /// Whether users on other servers can join this room. Defaults to true if key does not exist.
    let federate: Bool?
    
    struct PreviousRoom: Codable {
        let eventId: EventId
        let roomId: RoomId
        
        enum CodingKeys: String, CodingKey {
            case eventId = "event_id"
            case roomId = "room_id"
        }
    }
    let predecessor: PreviousRoom?
    
    /// The version of the room. Defaults to "1" if the key does not exist.
    let roomVersion: String?
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case creator
        case federate = "m.federate"
        case predecessor
        case roomVersion = "room_version"
        case type
    }
}
