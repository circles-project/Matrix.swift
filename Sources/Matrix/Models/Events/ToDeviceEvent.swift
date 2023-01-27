//
//  ToDeviceEvent.swift
//
//
//  Created by Charles Wright on 5/19/22.
//

import Foundation

    
// https://spec.matrix.org/v1.2/client-server-api/#extensions-to-sync
public struct ToDeviceEvent: Matrix.Event {
    public var content: Codable
    public var type: Matrix.EventType
    public var sender: UserId
    
    public enum CodingKeys: String, CodingKey {
        case content
        case type
        case sender
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sender = try container.decode(UserId.self, forKey: .sender)
        self.type = try container.decode(Matrix.EventType.self, forKey: .type)
        //let minimal = try MinimalEvent(from: decoder)
        //self.content = minimal.content
        self.content = try Matrix.decodeEventContent(of: self.type, from: decoder)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sender, forKey: .sender)
        try container.encode(type, forKey: .type)
        try Matrix.encodeEventContent(content: content, of: type, to: encoder)
    }
}

