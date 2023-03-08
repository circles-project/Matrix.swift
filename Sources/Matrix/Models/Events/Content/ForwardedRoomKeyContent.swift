//
//  ForwardedRoomKeyContent.swift
//  
//
//  Created by Charles Wright on 3/3/23.
//

import Foundation

public struct ForwardedRoomKeyContent: Codable {
    var algorithm: String
    var forwardingCurve25519KeyChain: [String]
    var roomId: RoomId
    var senderClaimedEd25519Key: String
    var senderKey: String
    var sessionId: String
    var sessionKey: String
    var withheld: Withheld
    
    struct Withheld: Codable {
        var reason: String
        var code: RoomKeyWithheldContent.Code
    }
    
    
    enum CodingKeys: String, CodingKey {
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
