//
//  KeyBackupRoomData.swift
//  
//
//  Created by Charles Wright on 6/30/23.
//

import Foundation

extension Matrix {

    public struct KeyBackupRoomData: Codable {
        struct SessionInfo: Codable {
            
            struct SessionData: Codable {
                var ciphertext: String
                var ephemeral: String
                var mac: String
            }
            
            var firstMessageIndex: Int
            var forwardedCount: Int
            var isVerified: Bool
            var sessionData: SessionData
            
            enum CodingKeys: String, CodingKey {
                case firstMessageIndex = "first_message_index"
                case forwardedCount = "forwarded_count"
                case isVerified = "is_verified"
                case sessionData = "session_data"
            }
        }
        
        var sessions: [String: SessionInfo]
    }
    
}
