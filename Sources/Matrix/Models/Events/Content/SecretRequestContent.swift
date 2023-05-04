//
//  SecretRequestContent.swift
//  
//
//  Created by Charles Wright on 5/3/23.
//

import Foundation

public struct SecretRequestContent: Codable {
    public enum Action: String, Codable {
        case request
        case requestCancellation = "request_cancellation"
    }
    
    public var action: Action
    public var name: String?
    public var requestId: String
    public var requestingDeviceId: String
    
    public enum CodingKeys: String, CodingKey {
        case action
        case name
        case requestId = "request_id"
        case requestingDeviceId = "requesting_device_id"
    }
}
