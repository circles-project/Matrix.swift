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
    
    private static func loadMessages(_ room: Matrix.Room?, database: Database) throws {
        let events = try ClientEvent
            .filter(Column(ClientEvent.CodingKeys.roomId.stringValue) == room?.roomId.description)
            .filter(Column(ClientEvent.CodingKeys.type.stringValue) == Matrix.EventType.mRoomMessage.rawValue)
            .fetchAll(database)
        let messages = Set(try events.map { try ClientEventWithoutRoomId(from: $0) })
        
        room?.messages = messages
    }
    
    internal static func save(_ store: GRDBDataStore, object: Matrix.Room, database: Database? = nil) throws {
        if let db = database {
            try ClientEvent.saveAll(store, objects: Array(object.messages), database: db, roomId: object.roomId)
            try store.save(object, database: db)
        }
        else {
            try store.dbQueue.write { db in
                try ClientEvent.saveAll(store, objects: Array(object.messages), database: db, roomId: object.roomId)
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
    
    internal static func load(_ store: GRDBDataStore, key: StorableKey, session: Matrix.Session,
                              database: Database? = nil) throws -> Matrix.Room? {
        Matrix.Room.databaseDecodingUserInfo[Matrix.Room.userInfoSessionKey] = session
        
        if let db = database {
            let room = try store.load(Matrix.Room.self, key: key, database: db)
            try loadMessages(room, database: db)
            return room
        }
        else {
            return try store.dbQueue.read { db in
                let room = try store.load(Matrix.Room.self, key: key, database: db)
                try loadMessages(room, database: db)
                return room
            }
        }
    }
    
    internal static func loadAll(_ store: GRDBDataStore, session: Matrix.Session,
                                 database: Database? = nil) throws -> [Matrix.Room]? {
        return try store.dbQueue.read { db in
            if let unwrappedRoomIds = try Matrix.Room.fetchAll(db, sql: "SELECT roomId FROM rooms") as? [RoomId] {
                var rooms: [Matrix.Room] = []
                for roomId in unwrappedRoomIds {
                    if let room = try Matrix.Room.load(store, key: roomId, session: session, database: db) {
                        rooms.append(room)
                    }
                }
                return rooms
            }
            return nil
        }
    }
    
    internal static func save(_ store: GRDBDataStore, object: Matrix.Room, database: Database? = nil) async throws {
        if let db = database {
            let _ = {
                try ClientEvent.saveAll(store, objects: Array(object.messages), database: db, roomId: object.roomId)
                try store.save(object, database: db)
            }
        }
        else {
            try await store.dbQueue.write { db in
                try ClientEvent.saveAll(store, objects: Array(object.messages), database: db, roomId: object.roomId)
                try store.save(object, database: db)
            }
        }
    }
    
    internal static func saveAll(_ store: GRDBDataStore, objects: [Matrix.Room]) async throws {
        try await store.dbQueue.write { db in
            try Matrix.Room.saveAll(store, objects: objects)
        }
    }
    
    internal static func load(_ store: GRDBDataStore, key: StorableKey, session: Matrix.Session,
                              database: Database? = nil) async throws -> Matrix.Room? {
        Matrix.Room.databaseDecodingUserInfo[Matrix.Room.userInfoSessionKey] = session

        if let db = database {
            let room = try await store.load(Matrix.Room.self, key: key, database: db)
            try loadMessages(room, database: db)
            return room
        }
        else {
            return try await store.dbQueue.read { db in
                let room = try store.load(Matrix.Room.self, key: key, database: db)
                try loadMessages(room, database: db)
                return room
            }
        }
    }
    
    internal static func loadAll(_ store: GRDBDataStore, session: Matrix.Session) async throws -> [Matrix.Room]? {
        return try await store.dbQueue.read { db in
            return try Matrix.Room.loadAll(store, session: session, database: db)
        }
    }
}
