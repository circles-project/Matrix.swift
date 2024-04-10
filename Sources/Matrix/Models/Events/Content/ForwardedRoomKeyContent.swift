//
//  ForwardedRoomKeyContent.swift
//  
//
//  Created by Charles Wright on 3/3/23.
//

import Foundation

public struct ForwardedRoomKeyContent: Codable {
    public var algorithm: String
    public var forwardingCurve25519KeyChain: [String]
    public var roomId: RoomId
    public var senderClaimedEd25519Key: String
    public var senderKey: String
    public var sessionId: String
    public var sessionKey: String
    public var withheld: Withheld
    
    public struct Withheld: Codable {
        var reason: String
        var code: RoomKeyWithheldContent.Code
    }
    
    
    public enum CodingKeys: String, CodingKey {
        case algorithm
        case forwardingCurve25519KeyChain = "forwarding_curve25519_key_chain"
        case roomId = "room_id"
        case senderClaimedEd25519Key = "sender_claimed_ed25519_key"
        case senderKey = "sender_key"
        case sessionId = "session_id"
        case sessionKey = "session_key"
        case withheld
    }
}
