//
//  RoomTombstoneContent.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation

/// m.room.tombstone: https://spec.matrix.org/v1.5/client-server-api/#mroomtombstone
public struct RoomTombstoneContent: Codable {
    public let body: String
    public let replacementRoom: RoomId
    
    public init(body: String, replacementRoom: RoomId) {
        self.body = body
        self.replacementRoom = replacementRoom
    }
    
    public enum CodingKeys: String, CodingKey {
        case body
        case replacementRoom = "replacement_room"
    }
}
