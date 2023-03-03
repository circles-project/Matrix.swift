//
//  RoomKeyWithheldContent.swift
//  
//
//  Created by Charles Wright on 3/3/23.
//

import Foundation

public struct RoomKeyWithheldContent: Codable {
    enum Algorithm: String, Codable {
        case megolmV1AesSha2 = "m.megolm.v1.aes-sha2"
    }
    enum Code: String, Codable {
        case blacklisted = "m.blacklisted"
        case unverified = "m.unverified"
        case unauthorized = "m.unauthorized"
        case unavailable = "m.unavailable"
        case noOlm = "m.no_olm"
    }
    
    var algorithm: Algorithm
    var code: Code
    var reason: String?
    var roomId: RoomId?
    var senderKey: String
    var sessionId: String?
    
    enum CodingKeys: String, CodingKey {
        case algorithm
        case code
        case reason
        case roomId = "room_id"
        case senderKey = "sender_key"
        case sessionId = "session_id"
    }
    
}
