//
//  DataStoreDispatch.swift
//  
//
//  Created by Michael Hollister on 1/26/23.
//

import Foundation
import Matrix
import GRDB

// Internal dispatcher that converts the generic types to call specialized
// implementations if required
extension GRDBDataStore: DataStore {
    // MARK: Non-async methods
    
    @_disfavoredOverload
    public func save<T>(_ object: T) throws {
        switch object {
        case let obj as Matrix.Room :
            try Matrix.Room.save(self, object: obj)
            break

        case let obj as Matrix.Session :
            try Matrix.Session.save(self, object: obj)
            break
            
        default:
            if let obj = object as? PersistableRecord {
                try self.save(obj)
            }
            break
        }
    }
    
    @_disfavoredOverload
    public func saveAll<T>(_ objects: [T]) throws {
        switch T.self {
        case is Matrix.Session.Type:
            throw Matrix.Error("Method not supported for Session object")
            
        case is Matrix.Room.Type:
            if let objs = objects as? [Matrix.Room] {
                try Matrix.Room.saveAll(self, objects: objs)
            }
            break
            
        default:
            if let objs = objects as? [PersistableRecord] {
                try self.saveAll(objs)
            }
            break
        }
    }
    
    @_disfavoredOverload
    public func load<T,K>(_ type: T.Type, key: K) throws -> T? {
        switch (type, key) {
        case let (_, keyValue) as (Matrix.Session.Type, Matrix.Session.StorableKey):
            return try Matrix.Session.load(self, key: keyValue) as? T
            
        default:
            if let typeObj = type as? (FetchableRecord & TableRecord).Type,
                let keyValue = key as? DatabaseValueConvertible {
                return try self.load(typeObj, key: keyValue) as? T
            }
            return nil
        }
    }
    
    @_disfavoredOverload
    public func loadAll<T>(_ type: T.Type) throws -> [T]? {
        switch T.self {
        case is Matrix.Session.Type:
            throw Matrix.Error("Method not supported for Session object")
            
        default:
            if let typeObj = type as? (FetchableRecord & TableRecord).Type {
                return try self.loadAll(typeObj) as? [T]
            }
            return nil
        }
    }
    
    public func load<T,K>(_ type: T.Type, key: K, session: Matrix.Session) throws -> T? {
        switch (type, key) {
        case let (_, keyValue) as (Matrix.Room.Type, Matrix.Room.StorableKey):
            return try Matrix.Room.load(self, key: keyValue, session: session) as? T
            
        case let (_, keyValue) as (Matrix.User.Type, Matrix.User.StorableKey):
            return try Matrix.User.load(self, key: keyValue, session: session) as? T
            
        default:
            return try self.load(type, key: key)
        }
    }
    
    public func loadAll<T>(_ type: T.Type, session: Matrix.Session) throws -> [T]? {
        switch T.self {
        case is Matrix.Session.Type:
            throw Matrix.Error("Method not supported for Session object")
            
        case is Matrix.Room.Type:
            return try Matrix.Room.loadAll(self, session: session) as? [T]
            
        case is Matrix.User.Type:
            return try Matrix.User.loadAll(self, session: session) as? [T]
            
        default:
            return try self.loadAll(type)
        }
    }
    
    @_disfavoredOverload
    public func remove<T>(_ object: T) throws {
        switch T.self {
        default:
            if let obj = object as? PersistableRecord {
                try self.remove(obj)
            }
            break
        }
    }
    
    @_disfavoredOverload
    public func remove<T,K>(_ type: T.Type, key: K) throws {
        switch (type, key) {
        default:
            if let typeObj = type as? PersistableRecord.Type,
                let keyValue = key as? DatabaseValueConvertible {
                try self.remove(typeObj, key: keyValue)
            }
            break
        }
    }
    
    @_disfavoredOverload
    public func removeAll<T>(_ objects: [T]) throws {
        switch T.self {
        case is Matrix.Session.Type:
            throw Matrix.Error("Method not supported for Session object")
            
        default:
            if let objs = objects as? [PersistableRecord] {
                try self.removeAll(objs)
            }
            break
        }
    }

    // MARK: Async methods
    @_disfavoredOverload
    public func save<T>(_ object: T) async throws {
        switch object {
        case let obj as Matrix.Room :
            try await Matrix.Room.save(self, object: obj)
            break

        case let obj as Matrix.Session :
            try await Matrix.Session.save(self, object: obj)
            break
            
        default:
            if let obj = object as? PersistableRecord {
                try await self.save(obj)
            }
            break
        }
    }
    
    @_disfavoredOverload
    public func saveAll<T>(_ objects: [T]) async throws {
        switch T.self {
        case is Matrix.Session.Type:
            throw Matrix.Error("Method not supported for Session object")
            
        case is Matrix.Room.Type:
            if let objs = objects as? [Matrix.Room] {
                try await Matrix.Room.saveAll(self, objects: objs)
            }
            break
            
        default:
            if let objs = objects as? [PersistableRecord] {
                try await self.saveAll(objs)
            }
            break
        }
    }
    
    @_disfavoredOverload
    public func load<T,K>(_ type: T.Type, key: K) async throws -> T? {
        switch (type, key) {
        case let (_, keyValue) as (Matrix.Session.Type, Matrix.Session.StorableKey):
            return try await Matrix.Session.load(self, key: keyValue) as? T
            
        default:
            if let typeObj = type as? (FetchableRecord & TableRecord).Type,
                let keyValue = key as? DatabaseValueConvertible {
                return try await self.load(typeObj, key: keyValue) as? T
            }
            return nil
        }
    }
    
    @_disfavoredOverload
    public func loadAll<T>(_ type: T.Type) async throws -> [T]? {
        switch T.self {
        case is Matrix.Session.Type:
            throw Matrix.Error("Method not supported for Session object")
            
        default:
            if let typeObj = type as? (FetchableRecord & TableRecord).Type {
                return try await self.loadAll(typeObj) as? [T]
            }
            return nil
        }
    }
    
    public func load<T,K>(_ type: T.Type, key: K, session: Matrix.Session) async throws -> T? {
        switch (type, key) {
        case let (_, keyValue) as (Matrix.Room.Type, Matrix.Room.StorableKey):
            return try await Matrix.Room.load(self, key: keyValue, session: session) as? T
            
        case let (_, keyValue) as (Matrix.User.Type, Matrix.User.StorableKey):
            return try await Matrix.User.load(self, key: keyValue, session: session) as? T
                        
        default:
            return try await self.load(type, key: key)
        }
    }
    
    public func loadAll<T>(_ type: T.Type, session: Matrix.Session) async throws -> [T]? {
        switch T.self {
        case is Matrix.Session.Type:
            throw Matrix.Error("Method not supported for Session object")
            
        case is Matrix.Room.Type:
            return try await Matrix.Room.loadAll(self, session: session) as? [T]
            
        case is Matrix.User.Type:
            return try await Matrix.User.loadAll(self, session: session) as? [T]
            
        default:
            return try await self.loadAll(type)
        }
    }
    
    @_disfavoredOverload
    public func remove<T>(_ object: T) async throws {
        switch T.self {
        default:
            if let obj = object as? PersistableRecord {
                try await self.remove(obj)
            }
            break
        }
    }
    
    @_disfavoredOverload
    public func remove<T,K>(_ type: T.Type, key: K) async throws {
        switch (type, key) {
        default:
            if let typeObj = type as? PersistableRecord.Type,
                let keyValue = key as? DatabaseValueConvertible {
                try await self.remove(typeObj, key: keyValue)
            }
            break
        }
    }
    
    @_disfavoredOverload
    public func removeAll<T>(_ objects: [T]) async throws {
        switch T.self {
        case is Matrix.Session.Type:
            throw Matrix.Error("Method not supported for Session object")
            
        default:
            if let objs = objects as? [PersistableRecord] {
                try await self.removeAll(objs)
            }
            break
        }
    }
}
