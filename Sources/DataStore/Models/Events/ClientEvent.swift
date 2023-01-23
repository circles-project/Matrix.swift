//
//  Messages.swift
//  
//
//  Created by Michael Hollister on 1/19/23.
//

import Foundation
import Matrix
import GRDB

extension ClientEvent: FetchableRecord, PersistableRecord {
    internal static func createTable(_ store: GRDBDataStore) async throws {
        try await store.dbQueue.write { db in
            try db.create(table: databaseTableName) { t in
                t.primaryKey {
                    t.column(ClientEvent.CodingKeys.eventId.stringValue, .text).notNull()
                }

                t.column(ClientEvent.CodingKeys.content.stringValue, .blob)
                t.column(ClientEvent.CodingKeys.originServerTS.stringValue, .integer)
                t.column(ClientEvent.CodingKeys.roomId.stringValue, .text)
                t.column(ClientEvent.CodingKeys.sender.stringValue, .text)
                t.column(ClientEvent.CodingKeys.stateKey.stringValue, .text)
                t.column(ClientEvent.CodingKeys.type.stringValue, .text)
                t.column(ClientEvent.CodingKeys.unsigned.stringValue, .blob)
            }
        }
    }
    
    public static let databaseTableName = "clientEvents"

    public func save(_ store: GRDBDataStore) async throws {
        try await store.save(self)
    }

    public func load(_ store: GRDBDataStore) async throws -> ClientEvent? {
        return try await store.load(ClientEvent.self, self.eventId)
    }

    public static func load(_ store: GRDBDataStore, key: StorableKey) async throws -> ClientEvent? {
        return try await store.load(ClientEvent.self, key)
    }
    
    public func remove(_ store: GRDBDataStore) async throws {
        try await store.remove(self)
    }
}
