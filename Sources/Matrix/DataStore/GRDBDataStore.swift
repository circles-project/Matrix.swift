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
    public let session: Matrix.Session
    
    // Publicly exposing the DB in case the user application requires advanced SQL functionality
    public let dbQueue: DatabaseQueue

    public required convenience init(appName: String, userId: UserId, session: Matrix.Session) async throws {
        // User IDs contain invalid path characters
        var dbDirectory = URL(string: NSHomeDirectory())
        dbDirectory?.appendPathComponent(".matrix")
        dbDirectory?.appendPathComponent(appName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? appName)
        dbDirectory?.appendPathComponent(userId.description.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId.description)
        
        guard var dbUrl = dbDirectory else {
            throw Matrix.Error("Error creating path for user data store: \(dbDirectory?.path ?? "nil")")
        }
        
        if !FileManager.default.fileExists(atPath: dbUrl.path) {
            try FileManager.default.createDirectory(atPath: dbUrl.path, withIntermediateDirectories: true)
        }
        
        dbUrl.appendPathComponent("matrix.sqlite3")
        try await self.init(path: dbUrl, session: session)
    }
    
    public required init(path: URL, session: Matrix.Session) async throws {
        self.url = path
        self.session = session
        
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

    public func save<T>(_ object: T, database: Database? = nil) throws
    where T: PersistableRecord & StorableDecodingContext {
        if let db = database {
            T.decodingDataStore = self
            T.decodingSession = self.session
            T.decodingDatabase = db
            
            try object.upsert(db)
        }
        else {
            try dbQueue.write { db in
                T.decodingDataStore = self
                T.decodingSession = self.session
                T.decodingDatabase = db
                
                try object.upsert(db)
            }
        }
    }

    public func saveAll<T>(_ objects: [T], database: Database? = nil) throws
    where T: PersistableRecord & StorableDecodingContext {
        if let db = database {
            T.decodingDataStore = self
            T.decodingSession = self.session
            T.decodingDatabase = db
            
            for obj in objects {
                try obj.upsert(db)
            }
        }
        else {
            try dbQueue.write { db in
                T.decodingDataStore = self
                T.decodingSession = self.session
                T.decodingDatabase = db
                
                for obj in objects {
                    try obj.upsert(db)
                }
            }
        }
    }

    public func load<T>(_ type: T.Type, key: DatabaseValueConvertible, database: Database? = nil) throws -> T?
    where T: FetchableRecord & TableRecord & StorableDecodingContext {
        if let db = database {
            T.decodingDataStore = self
            T.decodingSession = self.session
            T.decodingDatabase = db
            
            if let obj = try T.fetchOne(db, key: key) {
                return obj
            }
            return nil
        }
        else {
            return try dbQueue.read { db in
                T.decodingDataStore = self
                T.decodingSession = self.session
                T.decodingDatabase = db
                
                if let obj = try T.fetchOne(db, key: key) {
                    return obj
                }
                return nil
            }
        }
    }

    public func loadAll<T>(_ type: T.Type, database: Database? = nil) throws -> [T]?
    where T: FetchableRecord & TableRecord & StorableDecodingContext {
        if let db = database {
            T.decodingDataStore = self
            T.decodingSession = self.session
            T.decodingDatabase = db
            
            return try T.fetchAll(db)
        }
        else {
            return try dbQueue.read { db in
                T.decodingDataStore = self
                T.decodingSession = self.session
                T.decodingDatabase = db
                
                return try T.fetchAll(db)
            }
        }
    }

    public func remove(_ object: PersistableRecord, database: Database? = nil) throws {
        if let db = database {
            try object.delete(db)
        }
        else {
            let _ = try dbQueue.write { db in
                try object.delete(db)
            }
        }
    }

    public func remove(_ type: PersistableRecord.Type, key: DatabaseValueConvertible, database: Database? = nil) throws {
        if let db = database {
            try type.deleteOne(db, key: key)
        }
        else {
            let _ = try dbQueue.write { db in
                try type.deleteOne(db, key: key)
            }
        }
    }

    public func removeAll(_ objects: [PersistableRecord], database: Database? = nil) throws {
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
    
    public func save<T>(_ object: T, database: Database? = nil) async throws
    where T: PersistableRecord & StorableDecodingContext {
        if let db = database {
            T.decodingDataStore = self
            T.decodingSession = self.session
            T.decodingDatabase = db
            
            try object.upsert(db)
        }
        else {
            try await dbQueue.write { db in
                T.decodingDataStore = self
                T.decodingSession = self.session
                T.decodingDatabase = db
                
                try object.upsert(db)
            }
        }
    }
    
    public func saveAll<T>(_ objects: [T], database: Database? = nil) async throws
    where T: PersistableRecord & StorableDecodingContext {
        if let db = database {
            T.decodingDataStore = self
            T.decodingSession = self.session
            T.decodingDatabase = db
            
            for obj in objects {
                try obj.upsert(db)
            }
        }
        else {
            try await dbQueue.write { db in
                T.decodingDataStore = self
                T.decodingSession = self.session
                T.decodingDatabase = db
                
                for obj in objects {
                    try obj.upsert(db)
                }
            }
        }
    }
    
    public func load<T>(_ type: T.Type, key: DatabaseValueConvertible, database: Database? = nil) async throws -> T?
    where T: FetchableRecord & TableRecord & StorableDecodingContext {
        if let db = database {
            T.decodingDataStore = self
            T.decodingSession = self.session
            T.decodingDatabase = db
            
            if let obj = try T.fetchOne(db, key: key) {
                return obj
            }
            return nil
        }
        else {
            return try await dbQueue.read { db in
                T.decodingDataStore = self
                T.decodingSession = self.session
                T.decodingDatabase = db
                
                if let obj = try T.fetchOne(db, key: key) {
                    return obj
                }
                return nil
            }
        }
    }
    
    public func loadAll<T>(_ type: T.Type, database: Database? = nil) async throws -> [T]?
    where T: FetchableRecord & TableRecord & StorableDecodingContext {
        if let db = database {
            T.decodingDataStore = self
            T.decodingSession = self.session
            T.decodingDatabase = db
            
            return try T.fetchAll(db)
        }
        else {
            return try await dbQueue.read { db in
                T.decodingDataStore = self
                T.decodingSession = self.session
                T.decodingDatabase = db
                
                return try T.fetchAll(db)
            }
        }
    }
        
    public func remove(_ object: PersistableRecord, database: Database? = nil) async throws {
        if let db = database {
            try object.delete(db)
        }
        else {
            let _ = try await dbQueue.write { db in
                try object.delete(db)
            }
        }
    }
    
    public func remove(_ type: PersistableRecord.Type, key: DatabaseValueConvertible, database: Database? = nil) async throws {
        if let db = database {
            try type.deleteOne(db, key: key)
        }
        else {
            let _ = try await dbQueue.write { db in
                try type.deleteOne(db, key: key)
            }
        }
    }
    
    public func removeAll(_ objects: [PersistableRecord], database: Database? = nil) async throws {
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
