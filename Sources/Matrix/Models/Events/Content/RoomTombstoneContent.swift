//
//  RoomTombstoneContent.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation

struct RoomTombstoneContent: Codable {
    var body: String
    var replacementRoom: RoomId
    
    enum CodingKeys: String, CodingKey {
        case body
        case replacementRoom = "replacement_room"
    }
}
