//
//  GRDBDataStore.swift
//  
//
//  Created by Charles Wright on 5/24/22.
//

import Foundation
import Matrix
import GRDB

public class GRDBDataStore: DataStore {
    public typealias StorableKey = DatabaseValueConvertible
    
    public var url: URL
    
    // docs tbd: exposing if user requires lower-level sql access instead of developing wrapper functions
    public let dbQueue: DatabaseQueue
    
    public required convenience init(userId: UserId, deviceId: String) async throws {
        // User IDs contain invalid path characters
        var dbDirectory = URL(string: NSHomeDirectory())
        dbDirectory?.appendPathComponent(".matrix")
        dbDirectory?.appendPathComponent(userId.description.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId.description)
        dbDirectory?.appendPathComponent(deviceId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? deviceId)
        
        if var dbUrl = dbDirectory {
            if !FileManager.default.fileExists(atPath: dbUrl.path) {
                try FileManager.default.createDirectory(atPath: dbUrl.path, withIntermediateDirectories: true)
            }
            
            dbUrl.appendPathComponent("matrix.sqlite3")
            try await self.init(path: dbUrl)
        }
        else {
            throw Matrix.Error("Error creating path for user data store: \(dbDirectory?.path ?? "nil")")
        }
    }
    
    public required init(path: URL) async throws {
        self.url = path
        
        // Using single connection over application lifetime: https://swiftpackageindex.com/groue/grdb.swift/v6.6.1/documentation/grdb/concurrency
        if !FileManager.default.fileExists(atPath: url.path) {
            dbQueue = try DatabaseQueue(path: url.path)
            
            try await Matrix.Credentials.createTable(self)
            try await Matrix.Room.createTable(self)
            try await Matrix.InvitedRoom.createTable(self)
            try await ClientEvent.createTable(self)
            try await Matrix.Session.createTable(self)
            try await Matrix.User.createTable(self)
        }
        else {
            dbQueue = try DatabaseQueue(path: url.path)
        }
    }
    
    public func clearStore() async throws {
        try await dbQueue.write { db in
            try Matrix.Credentials.deleteAll(db)
            try Matrix.Room.deleteAll(db)
            try Matrix.InvitedRoom.deleteAll(db)
            try ClientEvent.deleteAll(db)
            try Matrix.Session.deleteAll(db)
            try Matrix.User.deleteAll(db)
        }
    }
        
    public func save<T: Storable & PersistableRecord>(_ object: T) async throws {
        try await dbQueue.write { db in
            try object.upsert(db)
        }
    }
    
    public func saveAll<T: Storable & PersistableRecord>(_ objectList: [T]) async throws {
        try await dbQueue.write { db in
            for obj in objectList {
                try obj.upsert(db)
            }
        }
    }
    
    public func load<T: Storable & FetchableRecord & TableRecord>(_ type: T.Type, _ key: StorableKey) async throws -> T? {
        try await dbQueue.read { db in
            if let obj = try T.fetchOne(db, key: key) {
                return obj
            }
            return nil
        }
    }
    
    // docs TBD (composite primary key)
    internal func load<T: Storable & FetchableRecord & TableRecord>(_ type: T.Type, _ key: [String: StorableKey]) async throws -> T? {
        try await dbQueue.read { db in
            if let obj = try T.fetchOne(db, key: key) {
                return obj
            }
            return nil
        }
    }
    
    public func loadAll<T: Storable & FetchableRecord & TableRecord>(_ type: T.Type) async throws -> [T] {
        try await dbQueue.read { db in
            return try T.fetchAll(db)
        }
    }
    
//    public func loadAll<T: Storable & FetchableRecord & TableRecord>(_ type: T.Type, columns: [String], values: Int) async throws -> [T] {
//        try await dbQueue.read { db in
//            /// ```swift
//            /// let players = try dbQueue.read { db in
//            ///     let lastName = "O'Reilly"
//            ///     let sql = "SELECT * FROM player WHERE lastName = ?"
//            ///     return try Player.fetchAll(db, sql: sql, arguments: [lastName])
//            /// }
//            /// ```
//
//            //T.fetchAll(<#T##db: Database##Database#>, sql: <#T##String#>)
//            //return try T.fetchAll(db)
//            // complex sql statements/fetching tbd
//            //let sql = "SELECT * FROM \(T.databaseTableName) WHERE"
//            //T.find
//            //T.filter()
//            return try T.filter(Column("") == 2).fetchAll(db)
//            //return try T.fetchAll(db, sql: sql)
//        }
//    }
    
    public func remove<T: Storable & PersistableRecord>(_ object: T) async throws {
        try await dbQueue.write { db in
            try object.delete(db)
        }
    }
    
    public func removeAll<T: Storable & PersistableRecord>(_ objectList: [T]) async throws {
        try await dbQueue.write { db in
            for obj in objectList {
                try obj.delete(db)
            }
        }
    }
}
