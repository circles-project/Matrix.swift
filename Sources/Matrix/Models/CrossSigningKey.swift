//
//  CrossSigningKey.swift
//  
//
//  Created by Charles Wright on 3/9/23.
//

import Foundation

// For https://spec.matrix.org/v1.6/client-server-api/#post_matrixclientv3keysdevice_signingupload
public struct CrossSigningKey: Codable {
    var keys: [String:String]
    var signatures: [UserId: [String:String]]?
    var usage: [String]
    var userId: UserId
    
    enum CodingKeys: String, CodingKey {
        case keys
        case signatures
        case usage
        case userId = "user_id"
    }
}
