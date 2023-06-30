//
//  KeyBackup+SessionData.swift
//  
//
//  Created by Charles Wright on 6/30/23.
//

import os
import Foundation

extension Matrix.KeyBackup {
    
    struct DecryptedSessionData: Codable {
        var algorithm: String
        var senderKey: String
        var sessionKey: String
        var senderClaimedKeys: [String: String]
        var forwardingCurve25519KeyChain: [String]
        
        enum CodingKeys: String, CodingKey {
            case algorithm
            case senderKey = "sender_key"
            case sessionKey = "session_key"
            case senderClaimedKeys = "sender_claimed_keys"
            case forwardingCurve25519KeyChain = "forwarding_curve25519_key_chain"
        }
    }
    
    struct SessionData: Codable {
        var algorithm: String
        var roomId: RoomId
        var senderKey: String
        var sessionId: String
        var sessionKey: String
        var senderClaimedKeys: [String: String]
        var forwardingCurve25519KeyChain: [String]
        
        enum CodingKeys: String, CodingKey {
            case algorithm
            case roomId = "room_id"
            case senderKey = "sender_key"
            case sessionId = "session_id"
            case sessionKey = "session_key"
            case senderClaimedKeys = "sender_claimed_keys"
            case forwardingCurve25519KeyChain = "forwarding_curve25519_key_chain"
        }
        
        init(decrypted: DecryptedSessionData, roomId: RoomId, sessionId: String) {
            self.roomId = roomId
            self.sessionId = sessionId
            self.algorithm = decrypted.algorithm
            self.senderKey = decrypted.senderKey
            self.sessionKey = decrypted.sessionKey
            self.senderClaimedKeys = decrypted.senderClaimedKeys
            self.forwardingCurve25519KeyChain = decrypted.forwardingCurve25519KeyChain
        }
    }

}
