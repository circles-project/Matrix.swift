//
//  StateEvent.swift
//  
//
//  Created by Charles Wright on 2/24/23.
//

import Foundation
import AnyCodable
import GRDB

// FIXME This winds up just being a copy of ClientEvent with non-nil stateKey and a different table name
// If the Event types were classes instead of structs, we could just inherit...
struct StateEventRecord: Codable {
    public let content: Codable
    public let eventId: String
    public let originServerTS: UInt64
    public let roomId: RoomId
    public let sender: UserId
    public let stateKey: String
    public let type: String
    public let unsigned: UnsignedData?
    
    public enum Columns: String, ColumnExpression {
        case content
        case eventId = "event_id"
        case originServerTS = "origin_server_ts"
        case roomId = "room_id"
        case sender
        case stateKey = "state_key"
        case type
        case unsigned
    }
    
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
    init(from event: ClientEventWithoutRoomId, in roomId: RoomId) throws {
        self.roomId = roomId
        self.type = event.type
        self.stateKey = event.stateKey!
        self.content = event.content
        self.sender = event.sender
        self.eventId = event.eventId
        self.originServerTS = event.originServerTS
        self.unsigned = event.unsigned
    }
    
    init(from event: ClientEvent) throws {
        self.roomId = event.roomId
        self.type = event.type
        self.stateKey = event.stateKey!
        self.content = event.content
        self.sender = event.sender
        self.eventId = event.eventId
        self.originServerTS = event.originServerTS
        self.unsigned = event.unsigned
    }
    
    init(from decoder: Decoder) throws {
        Matrix.logger.debug("Decoding a StateEventRecord")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let roomId = try container.decode(RoomId.self, forKey: .roomId)
        Matrix.logger.debug("roomId = \(roomId)")
        self.roomId = roomId
        
        let type = try container.decode(String.self, forKey: .type)
        Matrix.logger.debug("type = \(type)")
        self.type = type
        
        self.stateKey = try container.decode(String.self, forKey: .stateKey)
        self.content = try Matrix.decodeEventContent(of: self.type, from: decoder)
        self.sender = try container.decode(UserId.self, forKey: .sender)
        self.eventId = try container.decode(String.self, forKey: .eventId)
        self.originServerTS = try container.decode(UInt64.self, forKey: .originServerTS)
        self.unsigned = try container.decodeIfPresent(UnsignedData.self, forKey: .unsigned)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.roomId, forKey: .roomId)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.stateKey, forKey: .stateKey)
        try container.encode(AnyCodable(self.content), forKey: .content)
        try container.encode(self.sender, forKey: .sender)
        try container.encode(self.eventId, forKey: .eventId)
        try container.encode(self.originServerTS, forKey: .originServerTS)
        try container.encodeIfPresent(self.unsigned, forKey: .unsigned)
    }
}

extension StateEventRecord: FetchableRecord, TableRecord {
    public static var databaseTableName: String = "state"
}

extension StateEventRecord: PersistableRecord {
    
}
