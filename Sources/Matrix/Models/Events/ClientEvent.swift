//
//  MatrixClientEvent.swift
//
//
//  Created by Charles Wright on 5/17/22.
//

import Foundation
import GRDB

public struct ClientEvent: Matrix.Event, Codable {    
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
    
    public init(content: Codable, eventId: String, originServerTS: UInt64, roomId: RoomId,
                sender: UserId, stateKey: String? = nil, type: Matrix.EventType,
                unsigned: UnsignedData? = nil) throws {
        self.content = content
        self.eventId = eventId
        self.originServerTS = originServerTS
        self.roomId = roomId
        self.sender = sender
        self.stateKey = stateKey
        self.type = type
        self.unsigned = unsigned
    }
    
    public init(from: ClientEventWithoutRoomId, roomId: RoomId) throws {
        try self.init(content: from.content, eventId: from.eventId,
                      originServerTS: from.originServerTS, roomId: roomId,
                      sender: from.sender, type: from.type)
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

extension ClientEvent: StorableDecodingContext, FetchableRecord, PersistableRecord {
    public static func createTable(_ store: GRDBDataStore) async throws {
        try await store.dbQueue.write { db in
            try db.create(table: databaseTableName) { t in
                t.primaryKey {
                    t.column(ClientEvent.CodingKeys.eventId.stringValue, .text).notNull()
                }

                t.column(ClientEvent.CodingKeys.content.stringValue, .blob).notNull()
                t.column(ClientEvent.CodingKeys.originServerTS.stringValue, .integer).notNull()
                t.column(ClientEvent.CodingKeys.roomId.stringValue, .text)
                t.column(ClientEvent.CodingKeys.sender.stringValue, .text).notNull()
                t.column(ClientEvent.CodingKeys.stateKey.stringValue, .text)
                t.column(ClientEvent.CodingKeys.type.stringValue, .text).notNull()
                t.column(ClientEvent.CodingKeys.unsigned.stringValue, .blob)
            }
        }
    }
    
    public static let databaseTableName = "clientEvents"
    public static var decodingDataStore: GRDBDataStore?
    public static var decodingDatabase: Database?
    public static var decodingSession: Matrix.Session?
        
    public static func save(_ store: GRDBDataStore, object: ClientEventWithoutRoomId,
                                  database: Database? = nil, roomId: RoomId? = nil) throws {
        if let unwrappedRoomId = roomId {
            let event = try ClientEvent(from: object, roomId: unwrappedRoomId)
            try store.save(event, database: database)
        }
        else {
            try store.save(object, database: database)
        }
    }
    
    public static func saveAll(_ store: GRDBDataStore, objects: [ClientEventWithoutRoomId],
                                 database: Database? = nil, roomId: RoomId? = nil) throws {
        try objects.forEach { try self.save(store, object: $0, database: database, roomId: roomId) }
    }
    
    public static func save(_ store: GRDBDataStore, object: ClientEventWithoutRoomId,
                              database: Database? = nil, roomId: RoomId? = nil) async throws {
        if let unwrappedRoomId = roomId {
            let event = try ClientEvent(from: object, roomId: unwrappedRoomId)
            try await store.save(event, database: database)
        }
        else {
            try await store.save(object, database: database)
        }
    }
    
    public static func saveAll(_ store: GRDBDataStore, objects: [ClientEventWithoutRoomId],
                                 database: Database? = nil, roomId: RoomId? = nil) async throws {
        try objects.forEach { try self.save(store, object: $0, database: database, roomId: roomId) }
    }
}

