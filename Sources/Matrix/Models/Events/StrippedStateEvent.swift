//
//  StrippedStateEvent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

// https://spec.matrix.org/v1.2/client-server-api/#stripped-state

public struct StrippedStateEvent: Matrix.Event {
    public let sender: UserId
    public let stateKey: String
    public let type: Matrix.EventType
    public let content: Codable

    public enum CodingKeys: String, CodingKey {
        case sender
        case stateKey = "state_key"
        case type
        case content
    }

    public init(sender: UserId, stateKey: String, type: Matrix.EventType, content: Codable) {
        self.sender = sender
        self.stateKey = stateKey
        self.type = type
        self.content = content
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.sender = try container.decode(UserId.self, forKey: .sender)
        self.stateKey = try container.decode(String.self, forKey: .stateKey)
        self.type = try container.decode(Matrix.EventType.self, forKey: .type)
        
        self.content = try Matrix.decodeEventContent(of: self.type, from: decoder)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sender, forKey: .sender)
        try container.encode(stateKey, forKey: .stateKey)
        try container.encode(type, forKey: .type)
        try Matrix.encodeEventContent(content: content, of: type, to: encoder)
    }
}

