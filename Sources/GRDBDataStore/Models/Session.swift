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
    private static let userInfoSessionKey = CodingUserInfoKey(rawValue: "session")!
    
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
            try Matrix.Room.saveAll(store, objects: Array(object.rooms.values), database: db)
            try store.save(object, database: db)
        }
        else {
            try store.dbQueue.write { db in
                try store.save(object.creds, database: db)
                try Matrix.Room.saveAll(store, objects: Array(object.rooms.values), database: db)
                try store.save(object, database: db)
            }
        }
        

    }
    
    internal static func saveAll(_ store: GRDBDataStore, objects: [Matrix.Session]) throws {
        try store.dbQueue.write { db in
            try objects.forEach { try self.save(store, object: $0, database: db) }
        }
    }
    
    internal static func load(_ store: GRDBDataStore, key: StorableKey, database: Database? = nil) throws -> Matrix.Session? {
        Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoDataStoreKey] = store
        let compositeKey = Matrix.Credentials.getDatabaseValueConvertibleKey(key)
        
        // See note in decodeRooms regarding circular initialization dependency and Session decoder
        // for mutating the userInfo dict...
        Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoSessionKey] = NSMutableArray()
        
        if let db = database {
            Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoCredentialsKey] = try store.load(Matrix.Credentials.self, key: compositeKey, database: db)
            if let session = try store.load(Matrix.Session.self, key: compositeKey, database: db),
               let rooms = try Matrix.Room.loadAll(store, session: session, database: db) {
                rooms.forEach { session.rooms[$0.roomId] = $0 }
                return session
            }
            return nil
        }
        else {
            return try store.dbQueue.read { db in
                Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoCredentialsKey] = try store.load(Matrix.Credentials.self, key: compositeKey, database: db)
                if let session = try store.load(Matrix.Session.self, key: compositeKey, database: db),
                   let rooms = try Matrix.Room.loadAll(store, session: session, database: db) {
                    rooms.forEach { session.rooms[$0.roomId] = $0 }
                    return session
                }
                return nil
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
                try Matrix.Room.saveAll(store, objects: Array(object.rooms.values), database: db)
                try store.save(object, database: db)
            }
        }
        else {
            try await store.dbQueue.write { db in
                try store.save(object.creds, database: db)
                try Matrix.Room.saveAll(store, objects: Array(object.rooms.values), database: db)
                try store.save(object, database: db)
            }
        }
    }
    
    internal static func saveAll(_ store: GRDBDataStore, objects: [Matrix.Session]) async throws {
        try await store.dbQueue.write { db in
            try objects.forEach { try self.save(store, object: $0, database: db) }
        }
    }
    
    internal static func load(_ store: GRDBDataStore, key: StorableKey) async throws -> Matrix.Session? {
        Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoDataStoreKey] = store
        let compositeKey = Matrix.Credentials.getDatabaseValueConvertibleKey(key)
        
        // See note in decodeRooms regarding circular initialization dependency and Session decoder
        // for mutating the userInfo dict...
        Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoSessionKey] = NSMutableArray()
        
        return try await store.dbQueue.read { db in
            Matrix.Session.databaseDecodingUserInfo[Matrix.Session.userInfoCredentialsKey] = try store.load(Matrix.Credentials.self, key: compositeKey, database: db)
            if let session = try store.load(Matrix.Session.self, key: compositeKey, database: db),
               let rooms = try Matrix.Room.loadAll(store, session: session, database: db) {
                rooms.forEach { session.rooms[$0.roomId] = $0 }
                return session
            }
            return nil
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
