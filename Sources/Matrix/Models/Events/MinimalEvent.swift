//
//  MinimalEvent.swift
//
//
//  Created by Charles Wright on 5/19/22.
//

import Foundation

// The bare minimum implementation of the MatrixEvent protocol
// Used for decoding other event types
// Also used in the /sync response for AccountData, Presence, etc.
public struct MinimalEvent: Matrix.Event {
    public let type: Matrix.EventType
    public let sender: UserId?
    public let content: Codable
    
    public enum CodingKeys: String, CodingKey {
        case type
        case content
        case sender
    }
    
    public init(type: Matrix.EventType, sender: UserId?, content: Codable) {
        self.type = type
        self.sender = sender
        self.content = content
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(Matrix.EventType.self, forKey: .type)
        self.sender = try container.decodeIfPresent(UserId.self, forKey: .sender)
        self.content = try Matrix.decodeEventContent(of: self.type, from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        if let senderUserId = sender {
            try container.encode(senderUserId, forKey: .sender)
        }
        try container.encode(type, forKey: .type)
        try Matrix.encodeEventContent(content: content, of: type, to: encoder)
    }
}

