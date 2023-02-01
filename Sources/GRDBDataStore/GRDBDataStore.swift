//
//  GRDBDataStore.swift
//  
//
//  Created by Charles Wright on 5/24/22.
//

import Foundation
import Matrix
import GRDB

public class GRDBDataStore {
    public var url: URL
    
    // Publicly exposing the DB in case the user application requires advanced SQL functionality
    public let dbQueue: DatabaseQueue
    
    public required convenience init(userId: UserId, deviceId: String) async throws {
        // User IDs contain invalid path characters
        var dbDirectory = URL(string: NSHomeDirectory())
        dbDirectory?.appendPathComponent(".matrix")
        dbDirectory?.appendPathComponent(userId.description.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId.description)
        dbDirectory?.appendPathComponent(deviceId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? deviceId)
        
        guard var dbUrl = dbDirectory else {
            throw Matrix.Error("Error creating path for user data store: \(dbDirectory?.path ?? "nil")")
        }
        
        if !FileManager.default.fileExists(atPath: dbUrl.path) {
            try FileManager.default.createDirectory(atPath: dbUrl.path, withIntermediateDirectories: true)
        }
        
        dbUrl.appendPathComponent("matrix.sqlite3")
        try await self.init(path: dbUrl)
    }
    
    public required init(path: URL) async throws {
        self.url = path
        
        // Using single connection over application lifetime: https://swiftpackageindex.com/groue/grdb.swift/v6.6.1/documentation/grdb/concurrency
        if !FileManager.default.fileExists(atPath: url.path) {
            dbQueue = try DatabaseQueue(path: url.path)
            
            try await Matrix.Credentials.createTable(self)
            try await ClientEvent.createTable(self)
            try await Matrix.User.createTable(self)
            try await Matrix.Room.createTable(self)
            try await Matrix.Session.createTable(self)
        }
        else {
            dbQueue = try DatabaseQueue(path: url.path)
        }
    }
    
    public func clearStore() async throws {
        try await dbQueue.write { db in
            try Matrix.Credentials.deleteAll(db)
            try Matrix.Room.deleteAll(db)
            try ClientEvent.deleteAll(db)
            try Matrix.Session.deleteAll(db)
            try Matrix.User.deleteAll(db)
        }
    }
    
    // MARK: Non-async methods
    
    internal func save(_ object: PersistableRecord, database: Database? = nil) throws {
        if let db = database {
            try object.upsert(db)
        }
        else {
            try dbQueue.write { db in
                try object.upsert(db)
            }
        }
    }
    
    internal func saveAll(_ objects: [PersistableRecord], database: Database? = nil) throws {
        if let db = database {
            for obj in objects {
                try obj.upsert(db)
            }
        }
        else {
            try dbQueue.write { db in
                for obj in objects {
                    try obj.upsert(db)
                }
            }
        }
    }
    
    internal func load<T>(_ type: T.Type, key: DatabaseValueConvertible, database: Database? = nil) throws -> T?
    where T: FetchableRecord & TableRecord {
        if let db = database {
            if let obj = try T.fetchOne(db, key: key) {
                return obj
            }
            return nil
        }
        else {
            return try dbQueue.read { db in
                if let obj = try T.fetchOne(db, key: key) {
                    return obj
                }
                return nil
            }
        }
    }
    
    internal func load<T>(_ type: T.Type, key: [String: DatabaseValueConvertible], database: Database? = nil) throws -> T?
    where T: FetchableRecord & TableRecord {
        if let db = database {
            if let obj = try T.fetchOne(db, key: key) {
                return obj
            }
            return nil
        }
        else {
            return try dbQueue.read { db in
                if let obj = try T.fetchOne(db, key: key) {
                    return obj
                }
                return nil
            }
        }
    }
    
    internal func loadAll<T>(_ type: T.Type, database: Database? = nil) throws -> [T]?
    where T: FetchableRecord & TableRecord {
        if let db = database {
            return try T.fetchAll(db)
        }
        else {
            return try dbQueue.read { db in
                return try T.fetchAll(db)
            }
        }
    }
        
    internal func remove(_ object: PersistableRecord, database: Database? = nil) throws {
        if let db = database {
            try object.delete(db)
        }
        else {
            let _ = try dbQueue.write { db in
                try object.delete(db)
            }
        }
    }
    
    internal func remove(_ type: PersistableRecord.Type, key: DatabaseValueConvertible, database: Database? = nil) throws {
        if let db = database {
            try type.deleteOne(db, key: key)
        }
        else {
            let _ = try dbQueue.write { db in
                try type.deleteOne(db, key: key)
            }
        }
    }
    
    internal func remove(_ type: PersistableRecord.Type, key: [String: DatabaseValueConvertible], database: Database? = nil) throws {
        if let db = database {
            try type.deleteOne(db, key: key)
        }
        else {
            let _ = try dbQueue.write { db in
                try type.deleteOne(db, key: key)
            }
        }
    }
    
    internal func removeAll(_ objects: [PersistableRecord], database: Database? = nil) throws {
        if let db = database {
            for obj in objects {
                try obj.delete(db)
            }
        }
        else {
            try dbQueue.write { db in
                for obj in objects {
                    try obj.delete(db)
                }
            }
        }
    }
    
    // MARK: Async methods
    
    internal func save(_ object: PersistableRecord, database: Database? = nil) async throws {
        if let db = database {
            try object.upsert(db)
        }
        else {
            try await dbQueue.write { db in
                try object.upsert(db)
            }
        }
    }
    
    internal func saveAll(_ objects: [PersistableRecord], database: Database? = nil) async throws {
        if let db = database {
            for obj in objects {
                try obj.upsert(db)
            }
        }
        else {
            try await dbQueue.write { db in
                for obj in objects {
                    try obj.upsert(db)
                }
            }
        }
    }
    
    internal func load<T>(_ type: T.Type, key: DatabaseValueConvertible, database: Database? = nil) async throws -> T?
    where T: FetchableRecord & TableRecord {
        if let db = database {
            if let obj = try T.fetchOne(db, key: key) {
                return obj
            }
            return nil
        }
        else {
            return try await dbQueue.read { db in
                if let obj = try T.fetchOne(db, key: key) {
                    return obj
                }
                return nil
            }
        }
    }
    
    internal func load<T>(_ type: T.Type, key: [String: DatabaseValueConvertible], database: Database? = nil) async throws -> T?
    where T: FetchableRecord & TableRecord {
        if let db = database {
            if let obj = try T.fetchOne(db, key: key) {
                return obj
            }
            return nil
        }
        else {
            return try await dbQueue.read { db in
                if let obj = try T.fetchOne(db, key: key) {
                    return obj
                }
                return nil
            }
        }
    }
    
    internal func loadAll<T>(_ type: T.Type, database: Database? = nil) async throws -> [T]?
    where T: FetchableRecord & TableRecord {
        if let db = database {
            return try T.fetchAll(db)
        }
        else {
            return try await dbQueue.read { db in
                return try T.fetchAll(db)
            }
        }
    }
        
    internal func remove(_ object: PersistableRecord, database: Database? = nil) async throws {
        if let db = database {
            try object.delete(db)
        }
        else {
            let _ = try await dbQueue.write { db in
                try object.delete(db)
            }
        }
    }
    
    internal func remove(_ type: PersistableRecord.Type, key: DatabaseValueConvertible, database: Database? = nil) async throws {
        if let db = database {
            try type.deleteOne(db, key: key)
        }
        else {
            let _ = try await dbQueue.write { db in
                try type.deleteOne(db, key: key)
            }
        }
    }
    
    internal func remove(_ type: PersistableRecord.Type, key: [String: DatabaseValueConvertible], database: Database? = nil) async throws {
        if let db = database {
            try type.deleteOne(db, key: key)
        }
        else {
            let _ = try await dbQueue.write { db in
                try type.deleteOne(db, key: key)
            }
        }
    }
    
    internal func removeAll(_ objects: [PersistableRecord], database: Database? = nil) async throws {
        if let db = database {
            for obj in objects {
                try obj.delete(db)
            }
        }
        else {
            try await dbQueue.write { db in
                for obj in objects {
                    try obj.delete(db)
                }
            }
        }
    }
}
