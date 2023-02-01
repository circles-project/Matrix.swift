//
//  Session.swift
//  
//
//  Created by Michael Hollister on 1/22/23.
//

import Foundation
import Matrix
import GRDB

extension Matrix.Session: FetchableRecord, PersistableRecord {
    internal static func createTable(_ store: GRDBDataStore) async throws {
        try await store.dbQueue.write { db in
            try db.create(table: databaseTableName) { t in
                t.primaryKey {
                    t.column(Matrix.Session.CodingKeys.credentialsUserId.stringValue, .text).notNull()
                        //.references(Matrix.Credentials.databaseTableName, column: Matrix.Credentials.CodingKeys.userId.stringValue)
                    t.column(Matrix.Session.CodingKeys.credentialsDeviceId.stringValue, .text).notNull()
                        //.references(Matrix.Credentials.databaseTableName, column: Matrix.Credentials.CodingKeys.deviceId.stringValue)
                }

                t.column(Matrix.Session.CodingKeys.displayName.stringValue, .text)
                t.column(Matrix.Session.CodingKeys.avatarUrl.stringValue, .text)
                t.column(Matrix.Session.CodingKeys.statusMessage.stringValue, .text)
                
                // List of foreign keys to rooms in 'rooms'
                t.column(Matrix.Session.CodingKeys.rooms.stringValue, .blob).notNull()
                
                t.column(Matrix.Session.CodingKeys.invitations.stringValue, .blob).notNull()
                t.column(Matrix.Session.CodingKeys.syncToken.stringValue, .text)
                t.column(Matrix.Session.CodingKeys.syncRequestTimeout.stringValue, .integer).notNull()
                t.column(Matrix.Session.CodingKeys.keepSyncing.stringValue, .boolean).notNull()
                t.column(Matrix.Session.CodingKeys.syncDelayNs.stringValue, .integer).notNull()
                t.column(Matrix.Session.CodingKeys.ignoreUserIds.stringValue, .blob).notNull()
                t.column(Matrix.Session.CodingKeys.recoverySecretKey.stringValue, .blob)
                t.column(Matrix.Session.CodingKeys.recoveryTimestamp.stringValue, .date)
            }
        }
    }
    
    public static let databaseTableName = "sessions"
    public static var databaseDecodingUserInfo: [CodingUserInfoKey : Any] = [:]
    private static let userInfoDataStoreKey = CodingUserInfoKey(rawValue: Matrix.Session.CodingKeys.dataStore.stringValue)!
    private static let userInfoCredentialsKey = CodingUserInfoKey(rawValue: Matrix.Session.CodingKeys.credentials.stringValue)!
    private static let userInfoRoomsKey = CodingUserInfoKey(rawValue: Matrix.Session.CodingKeys.rooms.stringValue)!
    private static let userInfoSessionKey = CodingUserInfoKey(rawValue: "session")!
    
    // We cannot transact with the DB with re-entrant read/write operations in a safe maner for async code,
    // so we must manually persist any sub-objects (e.g. messages) using the same database context. Results
    // from decoding will be stored in the userInfo dictionary, and accessed when the root-type is being decoded.
    
    private static func decodeRooms(_ store: GRDBDataStore, _ db: Database, _ key: StorableKey) throws {
        // For some reason SQL interpolation only works for the WHERE condition value...
        let sqlRequest: SQLRequest<EventId> = "SELECT rooms FROM sessions WHERE user_id = \(key.0) AND device_id = \(key.1)"

        if let roomIdsJSON = try String.fetchOne(db, sqlRequest),
           let roomIdsJSONData = roomIdsJSON.data(using: .utf8) {
            let decoder = JSONDecoder()
            var rooms: [RoomId: Matrix.Room] = [:]

            let roomIds = try decoder.decode([RoomId].self, from: roomIdsJSONData)
            for roomId in roomIds {
                // Unfortunately Session is more complex in that we have not initialized this session object at this point in time,
                // but its fields require that a session object be provided (at least since the session field is not a nullable type at
                // this moment). To work around this issue we createa dummy session object that will be used to temporarily initialize the
                // rooms until the root-level decoder is invoked and can re-assign the the session fields to itself
                if let creds: Matrix.Credentials = Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoCredentialsKey] as? Matrix.Credentials {
                    let dummySesssion = try Matrix.Session(creds: creds, startSyncing: false)
                    if let room = try Matrix.Room.load(store, key: roomId, session: dummySesssion, database: db) {
                        rooms[roomId] = room
                    }
                }
            }

            Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoRoomsKey] = rooms
        }
    }
    
    private static func loadAll(_ store: GRDBDataStore, _ db: Database) throws -> [Matrix.Session] {
        // For some reason SQL interpolation only works for the WHERE condition value...
        let sqlRequest: SQLRequest<Matrix.Session.StorableKey> = "SELECT user_id, device_id FROM sessions"
        
        let rows = try Row.fetchAll(db, sqlRequest)
        var sessions: [Matrix.Session] = []
        for row in rows {
            if let userIdStr = row[Matrix.Session.CodingKeys.credentialsUserId.stringValue] as? String,
               let deviceId = row[Matrix.Session.CodingKeys.credentialsDeviceId.stringValue] as? DeviceId,
               let userId = UserId(userIdStr),
               let session = try Matrix.Session.load(store, key: (userId, deviceId), database: db) {
                sessions.append(session)
            }
        }
        
        return sessions
    }
    
    internal static func save(_ store: GRDBDataStore, object: Matrix.Session, database: Database? = nil) throws {
        if let db = database {
            try store.save(object.creds, database: db)
            try store.saveAll(Array(object.rooms.values), database: db)
            try store.save(object, database: db)
        }
        else {
            try store.dbQueue.write { db in
                try store.save(object.creds, database: db)
                try store.saveAll(Array(object.rooms.values), database: db)
                try store.save(object, database: db)
            }
        }
        

    }
    
    internal static func saveAll(_ store: GRDBDataStore, objects: [Matrix.Session]) throws {
        try store.dbQueue.write { db in
            for session in objects {
                try self.save(store, object: session, database: db)
            }
        }
    }
    
    internal static func load(_ store: GRDBDataStore, key: StorableKey, database: Database? = nil) throws -> Matrix.Session? {
        Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoDataStoreKey] = store
        Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoRoomsKey] = [:]
        let compositeKey = Matrix.Credentials.getDatabaseValueConvertibleKey(key)
        
        // See note in decodeRooms regarding circular initialization dependency and Session decoder
        // for mutating the userInfo dict...
        Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoSessionKey] = NSMutableArray()
        
        if let db = database {
            Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoCredentialsKey] = try store.load(Matrix.Credentials.self, key: compositeKey, database: db)
            try decodeRooms(store, db, key)
            return try store.load(Matrix.Session.self, key: compositeKey, database: db)
        }
        else {
            return try store.dbQueue.read { db in
                Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoCredentialsKey] = try store.load(Matrix.Credentials.self, key: compositeKey, database: db)
                try decodeRooms(store, db, key)
                return try store.load(Matrix.Session.self, key: compositeKey, database: db)
            }
        }
    }
    
    internal static func loadAll(_ store: GRDBDataStore) throws -> [Matrix.Session]? {
        return try store.dbQueue.read { db in
            try loadAll(store, db)
        }
    }
    
    internal static func remove(_ store: GRDBDataStore, key: StorableKey) throws {
        let compositeKey = Matrix.Credentials.getDatabaseValueConvertibleKey(key)
        try store.remove(Matrix.Session.self, key: compositeKey)
    }
    
    internal static func save(_ store: GRDBDataStore, object: Matrix.Session, database: Database? = nil) async throws {
        if let db = database {
            let _ = {
                try store.save(object.creds, database: db)
                try store.saveAll(Array(object.rooms.values), database: db)
                try store.save(object, database: db)
            }
        }
        else {
            try await store.dbQueue.write { db in
                try store.save(object.creds, database: db)
                try store.saveAll(Array(object.rooms.values), database: db)
                try store.save(object, database: db)
            }
        }
    }
    
    internal static func saveAll(_ store: GRDBDataStore, objects: [Matrix.Session]) async throws {
        try await store.dbQueue.write { db in
            for session in objects {
                try self.save(store, object: session, database: db)
            }
        }
    }
    
    internal static func load(_ store: GRDBDataStore, key: StorableKey) async throws -> Matrix.Session? {
        Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoDataStoreKey] = store
        Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoRoomsKey] = [:]
        let compositeKey = Matrix.Credentials.getDatabaseValueConvertibleKey(key)
        
        // See note in decodeRooms regarding circular initialization dependency and Session decoder
        // for mutating the userInfo dict...
        Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoSessionKey] = NSMutableArray()
        
        return try await store.dbQueue.read { db in
            Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoCredentialsKey] = try store.load(Matrix.Credentials.self, key: compositeKey, database: db)
            try decodeRooms(store, db, key)
            return try store.load(Matrix.Session.self, key: compositeKey, database: db)
        }
    }
    
    internal static func loadAll(_ store: GRDBDataStore) async throws -> [Matrix.Session]? {
        return try await store.dbQueue.read { db in
            try loadAll(store, db)
        }
    }
    
    internal static func remove(_ store: GRDBDataStore, key: StorableKey) async throws {
        let compositeKey = Matrix.Credentials.getDatabaseValueConvertibleKey(key)
        try await store.remove(Matrix.Session.self, key: compositeKey)
    }
}
