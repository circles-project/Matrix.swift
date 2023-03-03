//
//  RoomKeyContent.swift
//  
//
//  Created by Charles Wright on 3/3/23.
//

import Foundation

public struct RoomKeyContent: Codable {
    enum Algorithm: String, Codable {
        case megolmV1AesSha2 = "m.megolm.v1.aes-sha2"
    }
    var algorithm: Algorithm
    var roomId: RoomId
    var sessionId: String
    var sessionKey: String
    
    enum CodingKeys: String, CodingKey {
        case algorithm
        case roomId = "room_id"
        case sessionId = "session_id"
        case sessionKey = "session_key"
    }
}
