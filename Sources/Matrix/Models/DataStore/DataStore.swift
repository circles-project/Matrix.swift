//
//  DataStore.swift
//  
//
//  Created by Michael Hollister on 1/11/23.
//

import Foundation

/// docs TBD
public protocol DataStore {
    var url: URL { get }
    associatedtype StorableKey
    
    init(userId: UserId, deviceId: String) async throws
    init(path: URL) async throws
    func clearStore() async throws
    
    func save<T>(_ object: T) async throws where T: Storable
    func saveAll<T>(_ objectList: [T]) async throws where T: Storable
    func load<T>(_ type: T.Type, _ key: StorableKey) async throws -> T? where T: Storable
    func loadAll<T>(_ type: T.Type) async throws -> [T] where T: Storable
    func remove<T>(_ object: T) async throws where T: Storable
    func removeAll<T>(_ objectList: [T]) async throws where T: Storable
}

// Specialized implementation left to the underlying DataStore module used by the API
extension DataStore {
    @available(*, deprecated, message: "DataStore function 'save' not implemented for object. Will throw runtime error if function is not implemented.")
    public func save<T>(_ object: T) async throws where T: Storable {
        throw Matrix.Error("DataStore function 'save' not implemented for object: \(self)")
    }
    @available(*, deprecated, message: "DataStore function 'saveAll' not implemented for object. Will throw runtime error if function is not implemented.")
    public func saveAll<T>(_ objectList: [T]) async throws where T: Storable {
        throw Matrix.Error("DataStore function 'saveAll' not implemented for object: \(self)")
    }

    @available(*, deprecated, message: "DataStore function 'load' not implemented for object. Will throw runtime error if function is not implemented.")
    public func load<T>(_ type: T.Type, _ key: StorableKey) async throws -> T? where T: Storable {
        throw Matrix.Error("DataStore function 'load' not implemented for object: \(self)")
    }
    @available(*, deprecated, message: "DataStore function 'loadAll' not implemented for object. Will throw runtime error if function is not implemented.")
    public func loadAll<T>(_ type: T.Type) async throws -> [T] where T: Storable {
        throw Matrix.Error("DataStore function 'loadAll' not implemented for object: \(self)")
    }

    @available(*, deprecated, message: "DataStore function 'remove' not implemented for object. Will throw runtime error if function is not implemented.")
    public func remove<T>(_ object: T) async throws where T: Storable {
        throw Matrix.Error("DataStore function 'remove' not implemented for object: \(self)")
    }
    @available(*, deprecated, message: "DataStore function 'removeAll' not implemented for object. Will throw runtime error if function is not implemented.")
    public func removeAll<T>(_ objectList: [T]) async throws where T: Storable {
        throw Matrix.Error("DataStore function 'removeAll' not implemented for object: \(self)")
    }
}
