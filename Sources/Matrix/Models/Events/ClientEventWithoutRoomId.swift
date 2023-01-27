//
//  ClientEventWithoutRoomId.swift
//
//
//  Created by Charles Wright on 5/19/22.
//

import Foundation

// Used for the /sync API
// Normally this would be defined in-line in the only place where it's used,
// but since it's much bigger than most random data-transfer object types,
// this one gets its own file.
public struct ClientEventWithoutRoomId: Matrix.Event {
    public let eventId: String
    public let originServerTS: UInt64
    //public let roomId: String
    public let sender: UserId
    public let stateKey: String?
    public let type: Matrix.EventType
    public let content: Codable

    public struct UnsignedData: Codable {
        public let age: Int
        //public let prevContent: Codable
        public struct FakeClientEvent: Codable {
            public var eventId: String
        }
        public let redactedBecause: FakeClientEvent?
        public let transactionId: String?
    }
    public let unsigned: UnsignedData?
    
    public enum CodingKeys: String, CodingKey {
        case content
        case eventId = "event_id"
        case originServerTS = "origin_server_ts"
        //case roomId = "room_id"
        case sender
        case stateKey = "state_key"
        case type
        case unsigned
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.eventId = try container.decode(String.self, forKey: .eventId)
        self.originServerTS = try container.decode(UInt64.self, forKey: .originServerTS)
        //self.roomId = try container.decode(String.self, forKey: .roomId)
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
        try container.encode(sender, forKey: .sender)
        try container.encode(stateKey, forKey: .stateKey)
        try container.encode(type, forKey: .type)
        try container.encode(unsigned, forKey: .unsigned)
        try Matrix.encodeEventContent(content: content, of: type, to: encoder)
    }
}

extension ClientEventWithoutRoomId: Hashable {
    public static func == (lhs: ClientEventWithoutRoomId, rhs: ClientEventWithoutRoomId) -> Bool {
        lhs.eventId == rhs.eventId
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(eventId)
    }    
}
