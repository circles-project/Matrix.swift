//
//  SecretSendContent.swift
//  
//
//  Created by Charles Wright on 5/3/23.
//

import Foundation

public struct SecretSendContent: Codable {
    public var requestId: String
    public var secret: String
    
    public enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case secret
    }
}
