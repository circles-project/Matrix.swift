//
//  RoomKeyRequestContent.swift
//  
//
//  Created by Charles Wright on 3/3/23.
//

import Foundation

public struct RoomKeyRequestContent: Codable {
    enum Action: String, Codable {
        case request
        case requestCancellation = "request_cancellation"
    }
    struct RequestedKeyInfo: Codable {
        var algorithm: String
        var roomId: RoomId
        var senderKey: String?
        var sessionId: String
        
        enum CodingKeys: String, CodingKey {
            case algorithm
            case roomId = "room_id"
            case senderKey = "sender_key"
            case sessionId = "session_id"
        }
    }
    
    var action: Action
    var body: RequestedKeyInfo?
    var requestId: String
    var requestingDeviceId: String
    
    enum CodingKeys: String, CodingKey {
        case action
        case body
        case requestId = "request_id"
        case requestingDeviceId = "requesting_device_id"
    }
}
