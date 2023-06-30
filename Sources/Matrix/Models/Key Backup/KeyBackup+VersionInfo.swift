//
//  KeyBackupVersionInfo.swift
//  
//
//  Created by Charles Wright on 6/29/23.
//

import Foundation

extension Matrix.KeyBackup {
    
    public struct VersionInfo: Codable {
        
        // NOTE: This is only for Megolm backup v1
        // https://spec.matrix.org/v1.6/client-server-api/#backup-algorithm-mmegolm_backupv1curve25519-aes-sha2
        // FIXME if there is ever another version
        struct AuthData: Codable {
            var publicKey: String
            var signatures: [String: [String:String]]?
            
            enum CodingKeys: String, CodingKey {
                case publicKey = "public_key"
                case signatures
            }
        }
        
        var algorithm: String
        var authData: AuthData
        var count: Int
        var etag: String
        var version: String
        
        enum CodingKeys: String, CodingKey {
            case algorithm
            case authData = "auth_data"
            case count
            case etag
            case version
        }
    }
    
}
