//
//  Storable.swift
//  
//
//  Created by Michael Hollister on 1/13/23.
//

import Foundation

/// docs TBD
public protocol Storable {
    associatedtype StorableObject
    associatedtype StorableKey
    
    func save(_ store: any DataStore) async throws
    func load(_ store: any DataStore) async throws -> StorableObject?
    static func load(_ store: any DataStore, key: StorableKey) async throws -> StorableObject?
    func remove(_ store: any DataStore) async throws
}

// Implementation left to the underlying DataStore module used by the API
extension Storable {
    @available(*, deprecated, message: "Storable function 'save' not implemented for object. Will throw runtime error if function is not implemented.")
    public func save(_ store: any DataStore) async throws {
        throw Matrix.Error("Storable function 'save' not implemented for object: \(self)")
    }

    @available(*, deprecated, message: "Storable function 'load' not implemented for object. Will throw runtime error if function is not implemented.")
    public func load(_ store: any DataStore) async throws -> StorableObject? {
        throw Matrix.Error("Storable function 'load' not implemented for object: \(self)")
    }
    
    @available(*, deprecated, message: "Storable function 'load' not implemented for object. Will throw runtime error if function is not implemented.")
    public static func load(_ store: any DataStore, key: StorableKey) async throws -> StorableObject? {
        throw Matrix.Error("Storable function 'load' not implemented for object: \(self)")
    }

    @available(*, deprecated, message: "Storable function 'remove' not implemented for object. Will throw runtime error if function is not implemented.")
    public func remove(_ store: any DataStore) async throws {
        throw Matrix.Error("Storable function 'remove' not implemented for object: \(self)")
    }
}
