//
//  MatrixClientEvent.swift
//
//
//  Created by Charles Wright on 5/17/22.
//

import Foundation

public struct ClientEvent: Matrix.Event, Codable, Storable {
    public typealias StorableObject = ClientEvent
    public typealias StorableKey = EventId
    
    public let content: Codable
    public let eventId: String
    public let originServerTS: UInt64
    public let roomId: RoomId
    public let sender: UserId
    public let stateKey: String?
    public let type: Matrix.EventType
    public let unsigned: UnsignedData?
    
    public enum CodingKeys: String, CodingKey {
        case content
        case eventId = "event_id"
        case originServerTS = "origin_server_ts"
        case roomId = "room_id"
        case sender
        case stateKey = "state_key"
        case type
        case unsigned
    }
    
    public init(content: Codable, eventId: String, originServerTS: UInt64, roomId: RoomId, sender: UserId, stateKey: String? = nil, type: Matrix.EventType, unsigned: UnsignedData? = nil) throws {
        self.content = content
        self.eventId = eventId
        self.originServerTS = originServerTS
        self.roomId = roomId
        self.sender = sender
        self.stateKey = stateKey
        self.type = type
        self.unsigned = unsigned
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.eventId = try container.decode(String.self, forKey: .eventId)
        self.originServerTS = try container.decode(UInt64.self, forKey: .originServerTS)
        self.roomId = try container.decode(RoomId.self, forKey: .roomId)
        self.sender = try container.decode(UserId.self, forKey: .sender)
        self.stateKey = try? container.decode(String.self, forKey: .stateKey)
        self.type = try container.decode(Matrix.EventType.self, forKey: .type)
        self.unsigned = try? container.decode(UnsignedData.self, forKey: .unsigned)
        
        self.content = try Matrix.decodeEventContent(of: self.type, from: decoder)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventId, forKey: .eventId)
        try container.encode(originServerTS, forKey: .originServerTS)
        try container.encode(roomId, forKey: .roomId)
        try container.encode(sender, forKey: .sender)
        try container.encode(stateKey, forKey: .stateKey)
        try container.encode(type, forKey: .type)
        try container.encode(unsigned, forKey: .unsigned)
        try Matrix.encodeEventContent(content: content, of: type, to: encoder)
    }
}

extension ClientEvent: Hashable {
    public static func == (lhs: ClientEvent, rhs: ClientEvent) -> Bool {
        lhs.eventId == rhs.eventId
    }

    public func hash(into hasher: inout Hasher) {
        //hasher.combine(roomId)
        hasher.combine(eventId)
    }
}
