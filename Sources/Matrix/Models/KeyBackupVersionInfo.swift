//
//  KeyBackupVersionInfo.swift
//  
//
//  Created by Charles Wright on 6/29/23.
//

import Foundation

extension Matrix {
    
    
    /* Example:
     {
        "version": "3",
        "algorithm": "m.megolm_backup.v1.curve25519-aes-sha2",
        "auth_data": {
            "public_key": "Mrxfu+9SZktqomZ4MDryY63Q7wHhsXf4HinP47Pg6xg",
            "signatures": {
                "@test062909:us.circles-dev.net": {
                    "ed25519:ihS/b7e2vZB0uouVi4NW6acbRpiES3iVHX0pajJsldg":"WQ7fYZB6HOtLqr6ujwNOihujj3QGDyo/hLIPmSdkDhG+cHf4ukMgBELFy9XQ/5iZtYHNj/WsBtKnYkWp3RthDw",
                    "ed25519:ENLVRXXYFB":"GN/UnV7LkUTfauEaalgNQm7VXm8evr3LppNZiFFe5i9oNif+peuBPdRTpO0ZRxsBt+1W56+QYFoi0cMXHRmXAA"
                }
            }
        },
        "etag": "0",
        "count": 0
     }
     */
    
    public struct KeyBackupVersionInfo: Codable {
        
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
