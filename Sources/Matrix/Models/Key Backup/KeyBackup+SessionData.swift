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
        
        init(from decoder: Decoder) throws {
            var logger = os.Logger(subsystem: "matrix", category: "DecryptedSessionData")
            logger.debug("Starting init()")

            let container: KeyedDecodingContainer<Matrix.KeyBackup.DecryptedSessionData.CodingKeys> = try decoder.container(keyedBy: Matrix.KeyBackup.DecryptedSessionData.CodingKeys.self)
            logger.debug("algorithm")
            self.algorithm = try container.decode(String.self, forKey: Matrix.KeyBackup.DecryptedSessionData.CodingKeys.algorithm)
            logger.debug("sender key")
            self.senderKey = try container.decode(String.self, forKey: Matrix.KeyBackup.DecryptedSessionData.CodingKeys.senderKey)
            logger.debug("session key")
            self.sessionKey = try container.decode(String.self, forKey: Matrix.KeyBackup.DecryptedSessionData.CodingKeys.sessionKey)
            logger.debug("sender claimed keys")
            self.senderClaimedKeys = try container.decode([String : String].self, forKey: Matrix.KeyBackup.DecryptedSessionData.CodingKeys.senderClaimedKeys)
            logger.debug("forwarding Curve25519 key chain")
            self.forwardingCurve25519KeyChain = try container.decode([String].self, forKey: Matrix.KeyBackup.DecryptedSessionData.CodingKeys.forwardingCurve25519KeyChain)

            logger.debug("Done with init()")
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
