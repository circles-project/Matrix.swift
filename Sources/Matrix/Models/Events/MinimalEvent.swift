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
struct MinimalEvent: Matrix.Event {
    let type: Matrix.EventType
    let sender: UserId?
    let content: Codable
    
    enum CodingKeys: String, CodingKey {
        case type
        case content
        case sender
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(Matrix.EventType.self, forKey: .type)
        self.sender = try? container.decode(UserId.self, forKey: .sender)
        self.content = try Matrix.decodeEventContent(of: self.type, from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(type, forKey: .sender)
        try container.encode(type, forKey: .type)
        try Matrix.encodeEventContent(content: content, of: type, to: encoder)
    }

    
}

