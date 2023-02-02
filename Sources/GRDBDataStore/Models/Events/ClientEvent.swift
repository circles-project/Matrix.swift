//
//  Messages.swift
//  
//
//  Created by Michael Hollister on 1/19/23.
//

import Foundation
import Matrix
import GRDB

extension ClientEvent: FetchableRecord, PersistableRecord {
    internal static func createTable(_ store: GRDBDataStore) async throws {
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
    
    internal static func save(_ store: GRDBDataStore, object: ClientEventWithoutRoomId,
                              database: Database? = nil, roomId: RoomId? = nil) throws {
        if let unwrappedRoomId = roomId {
            let event = try ClientEvent(from: object, roomId: unwrappedRoomId)
            try store.save(event, database: database)
        }
        else {
            try store.save(object, database: database)
        }
    }
    
    internal static func saveAll(_ store: GRDBDataStore, objects: [ClientEventWithoutRoomId],
                                 database: Database? = nil, roomId: RoomId? = nil) throws {
        for event in objects {
            try self.save(store, object: event, database: database, roomId: roomId)
        }
    }
    
    internal static func save(_ store: GRDBDataStore, object: ClientEventWithoutRoomId,
                              database: Database? = nil, roomId: RoomId? = nil) async throws {
        if let unwrappedRoomId = roomId {
            let event = try ClientEvent(from: object, roomId: unwrappedRoomId)
            try await store.save(event, database: database)
        }
        else {
            try await store.save(object, database: database)
        }
    }
    
    internal static func saveAll(_ store: GRDBDataStore, objects: [ClientEventWithoutRoomId],
                                 database: Database? = nil, roomId: RoomId? = nil) async throws {
        for event in objects {
            try await self.save(store, object: event, database: database, roomId: roomId)
        }
    }
}
