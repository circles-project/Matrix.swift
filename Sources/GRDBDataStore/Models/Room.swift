//
//  Room.swift
//  
//
//  Created by Michael Hollister on 1/17/23.
//

import Foundation
import Matrix
import GRDB

extension RoomId: DatabaseValueConvertible {}

extension Matrix.Room: FetchableRecord, PersistableRecord {
    internal static func createTable(_ store: GRDBDataStore) async throws {
        try await store.dbQueue.write { db in
            try db.create(table: databaseTableName) { t in
                t.primaryKey {
                    t.column(Matrix.Room.CodingKeys.roomId.stringValue, .text).notNull()
                }

                t.column(Matrix.Room.CodingKeys.type.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.version.stringValue, .text).notNull()
                t.column(Matrix.Room.CodingKeys.name.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.topic.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.avatarUrl.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.predecessorRoomId.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.successorRoomId.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.tombstoneEventId.stringValue, .text)
                
                // List of foreign keys to events in 'clientEvents'
                t.column(Matrix.Room.CodingKeys.messages.stringValue, .blob).notNull()
                
                t.column(Matrix.Room.CodingKeys.localEchoEvent.stringValue, .blob)
                t.column(Matrix.Room.CodingKeys.highlightCount.stringValue, .integer).notNull()
                t.column(Matrix.Room.CodingKeys.notificationCount.stringValue, .integer).notNull()
                t.column(Matrix.Room.CodingKeys.joinedMembers.stringValue, .blob).notNull()
                t.column(Matrix.Room.CodingKeys.invitedMembers.stringValue, .blob).notNull()
                t.column(Matrix.Room.CodingKeys.leftMembers.stringValue, .blob).notNull()
                t.column(Matrix.Room.CodingKeys.bannedMembers.stringValue, .blob).notNull()
                t.column(Matrix.Room.CodingKeys.knockingMembers.stringValue, .blob).notNull()
                t.column(Matrix.Room.CodingKeys.encryptionParams.stringValue, .blob)
            }
        }
    }
    
    public static let databaseTableName = "rooms"
    public static var databaseDecodingUserInfo: [CodingUserInfoKey : Any] = [:]
    private static let userInfoSessionKey = CodingUserInfoKey(rawValue: Matrix.Room.CodingKeys.session.stringValue)!
    private static let userInfoMessagesKey = CodingUserInfoKey(rawValue: Matrix.Room.CodingKeys.messages.stringValue)!
    
    // We cannot transact with the DB with re-entrant read/write operations in a safe maner for async code,
    // so we must manually persist any sub-objects (e.g. messages) using the same database context. Results
    // from decoding will be stored in the userInfo dictionary, and accessed when the root-type is being decoded.
    
    private static func decodeMessages(_ db: Database, _ key: StorableKey) throws {
        // For some reason SQL interpolation only works for the WHERE condition value...
        let sqlRequest: SQLRequest<EventId> = "SELECT messages FROM rooms WHERE roomId = \(key)"
        
        if let eventIdsJSON = try String.fetchOne(db, sqlRequest),
           let eventIdsJSONData = eventIdsJSON.data(using: .utf8) {
            let decoder = JSONDecoder()
            var messages = Set<ClientEventWithoutRoomId>()
            
            let eventIds = try decoder.decode([EventId].self, from: eventIdsJSONData)
            for eventId in eventIds {
                if let event = try ClientEventWithoutRoomId.fetchOne(db, key: eventId) {
                    messages.insert(event)
                }
            }

            Matrix.Room.databaseDecodingUserInfo[Matrix.Room.userInfoMessagesKey] = messages
        }
    }
    
    internal static func save(_ store: GRDBDataStore, object: Matrix.Room, database: Database? = nil) throws {
        if let db = database {
            try store.saveAll(Array(object.messages), database: db)
            try store.save(object, database: db)
        }
        else {
            try store.dbQueue.write { db in
                try store.saveAll(Array(object.messages), database: db)
                try store.save(object, database: db)
            }
        }
    }
    
    internal static func saveAll(_ store: GRDBDataStore, objects: [Matrix.Room]) throws {
        try store.dbQueue.write { db in
            for room in objects {
                try self.save(store, object: room, database: db)
            }
        }
    }
    
    internal static func load(_ store: GRDBDataStore, key: StorableKey, session: Matrix.Session, database: Database? = nil) throws -> Matrix.Room? {
        Matrix.Room.databaseDecodingUserInfo[Matrix.Room.userInfoSessionKey] = session
        Matrix.Room.databaseDecodingUserInfo[Matrix.Room.userInfoMessagesKey] = Set<ClientEventWithoutRoomId>()
        
        if let db = database {
            try decodeMessages(db, key)
            return try store.load(Matrix.Room.self, key: key, database: db)
        }
        else {
            return try store.dbQueue.read { db in
                try decodeMessages(db, key)
                return try store.load(Matrix.Room.self, key: key, database: db)
            }
        }
    }
    
    internal static func loadAll(_ store: GRDBDataStore, session: Matrix.Session) throws -> [Matrix.Room]? {
        // For some reason SQL interpolation only works for the WHERE condition value...
        let sqlRequest: SQLRequest<RoomId> = "SELECT roomId FROM rooms"
        
        return try store.dbQueue.read { db in
            let roomIds = try RoomId.fetchAll(db, sqlRequest)
            var rooms: [Matrix.Room] = []
            for roomId in roomIds {
                if let room = try Matrix.Room.load(store, key: roomId, session: session, database: db) {
                    rooms.append(room)
                }
            }
            return rooms
        }
    }
    
    internal static func save(_ store: GRDBDataStore, object: Matrix.Room, database: Database? = nil) async throws {
        if let db = database {
            let _ = {
                try store.saveAll(Array(object.messages), database: db)
                try store.save(object, database: db)
            }
        }
        else {
            try await store.dbQueue.write { db in
                try store.saveAll(Array(object.messages), database: db)
                try store.save(object, database: db)
            }
        }
    }
    
    internal static func saveAll(_ store: GRDBDataStore, objects: [Matrix.Room]) async throws {
        try await store.dbQueue.write { db in
            for room in objects {
                try self.save(store, object: room, database: db)
            }
        }
    }
    
    internal static func load(_ store: GRDBDataStore, key: StorableKey, session: Matrix.Session, database: Database? = nil) async throws -> Matrix.Room? {
        Matrix.Room.databaseDecodingUserInfo[Matrix.Room.userInfoSessionKey] = session
        Matrix.Room.databaseDecodingUserInfo[Matrix.Room.userInfoMessagesKey] = Set<ClientEventWithoutRoomId>()
        
        if let db = database {
            try decodeMessages(db, key)
            return try await store.load(Matrix.Room.self, key: key, database: db)
        }
        else {
            return try await store.dbQueue.read { db in
                try decodeMessages(db, key)
                return try store.load(Matrix.Room.self, key: key, database: db)
            }
        }
    }
    
    internal static func loadAll(_ store: GRDBDataStore, session: Matrix.Session) async throws -> [Matrix.Room]? {
        // For some reason SQL interpolation only works for the WHERE condition value...
        let sqlRequest: SQLRequest<RoomId> = "SELECT roomId FROM rooms"
        
        return try await store.dbQueue.read { db in
            let roomIds = try RoomId.fetchAll(db, sqlRequest)
            var rooms: [Matrix.Room] = []
            for roomId in roomIds {
                if let room = try Matrix.Room.load(store, key: roomId, session: session, database: db) {
                    rooms.append(room)
                }
            }
            return rooms
        }
    }
}
