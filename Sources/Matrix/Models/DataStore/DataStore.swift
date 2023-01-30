//
//  DataStore.swift
//  
//
//  Created by Michael Hollister on 1/11/23.
//

import Foundation

/// DataStore protocol for defining interface on presisting Matrix objects to storage
/// with async or non-async invocation.
///
/// Note that methods are provided to load objects from store with passing in a
/// Matrix Session, as certain types of objects require an existing session be
/// provided before the object can be instantiated.
public protocol DataStore {
    /// Path to the DataStore
    var url: URL { get }
    
    init(userId: UserId, deviceId: String) async throws
    init(path: URL) async throws
    func clearStore() async throws
    
    func save<T>(_ object: T) throws
    func saveAll<T>(_ objects: [T]) throws
    func load<T,K>(_ type: T.Type, key: K) throws -> T?
    func loadAll<T>(_ type: T.Type) throws -> [T]?
    func load<T,K>(_ type: T.Type, key: K, session: Matrix.Session) throws -> T?
    func loadAll<T>(_ type: T.Type, session: Matrix.Session) throws -> [T]?
    func remove<T>(_ object: T) throws
    func remove<T,K>(_ type: T.Type, key: K) throws
    func removeAll<T>(_ objects: [T]) throws

    func save<T>(_ object: T) async throws
    func saveAll<T>(_ objects: [T]) async throws
    func load<T,K>(_ type: T.Type, key: K) async throws -> T?
    func loadAll<T>(_ type: T.Type) async throws -> [T]?
    func load<T,K>(_ type: T.Type, key: K, session: Matrix.Session) async throws -> T?
    func loadAll<T>(_ type: T.Type, session: Matrix.Session) async throws -> [T]?
    func remove<T>(_ object: T) async throws
    func remove<T,K>(_ type: T.Type, key: K) async throws
    func removeAll<T>(_ objects: [T]) async throws
}
