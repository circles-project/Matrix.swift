//
//  RoomKeyWithheldContent.swift
//  
//
//  Created by Charles Wright on 3/3/23.
//

import Foundation

public struct RoomKeyWithheldContent: Codable {
    public enum Algorithm: String, Codable {
        case megolmV1AesSha2 = "m.megolm.v1.aes-sha2"
    }
    public enum Code: String, Codable {
        case blacklisted = "m.blacklisted"
        case unverified = "m.unverified"
        case unauthorized = "m.unauthorized"
        case unavailable = "m.unavailable"
        case noOlm = "m.no_olm"
    }
    
    public var algorithm: Algorithm
    public var code: Code
    public var reason: String?
    public var roomId: RoomId?
    public var senderKey: String
    public var sessionId: String?
    
    enum CodingKeys: String, CodingKey {
        case algorithm
        case code
        case reason
        case roomId = "room_id"
        case senderKey = "sender_key"
        case sessionId = "session_id"
    }
    
}
