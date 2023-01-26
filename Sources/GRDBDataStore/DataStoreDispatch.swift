//
//  DataStoreDispatch.swift
//  
//
//  Created by Michael Hollister on 1/26/23.
//

import Foundation
import Matrix
import GRDB

/// docs tbd: converts generic types to specialzed or default method calls
extension GRDBDataStore: DataStore {
    public func save<T>(_ object: T) throws {
        switch T.self {
        default:
            if let obj = object as? PersistableRecord {
                try self.save(obj)
            }
            break
        }
    }
    
    public func saveAll<T>(_ objects: [T]) throws {
        switch T.self {
        default:
            if let objs = objects as? [PersistableRecord] {
                try self.saveAll(objs)
            }
            break
        }
    }
    
    public func load<T,K>(_ type: T.Type, key: K) throws -> T? {
        switch T.self {
        case is Matrix.Credentials.Type:
            if let keyValue = key as? Matrix.Credentials.StorableKey {
                return try Matrix.Credentials.load(self, key: keyValue) as? T
            }
            return nil
            
        case is Matrix.Session.Type:
            if let keyValue = key as? Matrix.Session.StorableKey {
                return try Matrix.Session.load(self, key: keyValue) as? T
            }
            return nil
            
        default:
            if let typeObj = type as? (FetchableRecord & TableRecord).Type,
                let keyValue = key as? DatabaseValueConvertible {
                return try self.load(typeObj, key: keyValue) as? T
            }
            return nil
        }
    }
    
    public func loadAll<T>(_ type: T.Type) throws -> [T]? {
        switch T.self {
        default:
            if let typeObj = type as? (FetchableRecord & TableRecord).Type {
                return try self.loadAll(typeObj) as? [T]
            }
            return nil
        }
    }
    
    public func load<T,K>(_ type: T.Type, key: K, session: Matrix.Session) throws -> T? {
        switch T.self {
        case is Matrix.InvitedRoom.Type:
            if let keyValue = key as? Matrix.InvitedRoom.StorableKey {
                return try Matrix.InvitedRoom.load(self, key: keyValue, session: session) as? T
            }
            return nil
            
        case is Matrix.Room.Type:
            if let keyValue = key as? Matrix.Room.StorableKey {
                return try Matrix.Room.load(self, key: keyValue, session: session) as? T
            }
            return nil
            
        case is Matrix.User.Type:
            if let keyValue = key as? Matrix.User.StorableKey {
                return try Matrix.User.load(self, key: keyValue, session: session) as? T
            }
            return nil
            
        default:
            return try self.load(type, key: key)
        }
    }
    
    public func loadAll<T>(_ type: T.Type, session: Matrix.Session) throws -> [T]? {
        switch T.self {
        default:
            return try self.loadAll(type)
        }
    }
    
    public func remove<T>(_ object: T) throws {
        switch T.self {
        default:
            if let obj = object as? PersistableRecord {
                try self.remove(obj)
            }
            break
        }
    }
    
    public func remove<T,K>(_ type: T.Type, key: K) throws {
        switch T.self {
        default:
            if let typeObj = type as? PersistableRecord.Type,
                let keyValue = key as? DatabaseValueConvertible {
                try self.remove(typeObj, key: keyValue)
            }
            break
        }
    }
    
    public func removeAll<T>(_ objects: [T]) throws {
        switch T.self {
        default:
            if let objs = objects as? [PersistableRecord] {
                try self.removeAll(objs)
            }
            break
        }
    }

    // MARK: Async methods
    public func save<T>(_ object: T) async throws {
        switch T.self {
        default:
            if let obj = object as? PersistableRecord {
                try await self.save(obj)
            }
            break
        }
    }
    
    public func saveAll<T>(_ objects: [T]) async throws {
        switch T.self {
        default:
            if let objs = objects as? [PersistableRecord] {
                try await self.saveAll(objs)
            }
            break
        }
    }
    
    public func load<T,K>(_ type: T.Type, key: K) async throws -> T? {
        switch T.self {
        case is Matrix.Credentials.Type:
            if let keyValue = key as? Matrix.Credentials.StorableKey {
                return try await Matrix.Credentials.load(self, key: keyValue) as? T
            }
            return nil
            
        case is Matrix.Session.Type:
            if let keyValue = key as? Matrix.Session.StorableKey {
                return try await Matrix.Session.load(self, key: keyValue) as? T
            }
            return nil
            
        default:
            if let typeObj = type as? (FetchableRecord & TableRecord).Type,
                let keyValue = key as? DatabaseValueConvertible {
                return try await self.load(typeObj, key: keyValue) as? T
            }
            return nil
        }
    }
    
    public func loadAll<T>(_ type: T.Type) async throws -> [T]? {
        switch T.self {
        default:
            if let typeObj = type as? (FetchableRecord & TableRecord).Type {
                return try await self.loadAll(typeObj) as? [T]
            }
            return nil
        }
    }
    
    public func load<T,K>(_ type: T.Type, key: K, session: Matrix.Session) async throws -> T? {
        switch T.self {
        case is Matrix.InvitedRoom.Type:
            if let keyValue = key as? Matrix.InvitedRoom.StorableKey {
                return try await Matrix.InvitedRoom.load(self, key: keyValue, session: session) as? T
            }
            return nil
            
        case is Matrix.Room.Type:
            if let keyValue = key as? Matrix.Room.StorableKey {
                return try await Matrix.Room.load(self, key: keyValue, session: session) as? T
            }
            return nil
            
        case is Matrix.User.Type:
            if let keyValue = key as? Matrix.User.StorableKey {
                return try await Matrix.User.load(self, key: keyValue, session: session) as? T
            }
            return nil
            
        default:
            return try await self.load(type, key: key)
        }
    }
    
    public func loadAll<T>(_ type: T.Type, session: Matrix.Session) async throws -> [T]? {
        switch T.self {
        default:
            return try await self.loadAll(type)
        }
    }
    
    public func remove<T>(_ object: T) async throws {
        switch T.self {
        default:
            if let obj = object as? PersistableRecord {
                try await self.remove(obj)
            }
            break
        }
    }
    
    public func remove<T,K>(_ type: T.Type, key: K) async throws {
        switch T.self {
        default:
            if let typeObj = type as? PersistableRecord.Type,
                let keyValue = key as? DatabaseValueConvertible {
                try await self.remove(typeObj, key: keyValue)
            }
            break
        }
    }
    
    public func removeAll<T>(_ objects: [T]) async throws {
        switch T.self {
        default:
            if let objs = objects as? [PersistableRecord] {
                try await self.removeAll(objs)
            }
            break
        }
    }
}
