//
//  User.swift
//  
//
//  Created by Michael Hollister on 1/22/23.
//

import Foundation
import Matrix
import GRDB

extension Matrix.User: FetchableRecord, PersistableRecord {
    internal static func createTable(_ store: GRDBDataStore) async throws {
        try await store.dbQueue.write { db in
            try db.create(table: databaseTableName) { t in
                t.primaryKey {
                    t.column(Matrix.User.CodingKeys.id.stringValue, .text).notNull()
                }

                t.column(Matrix.User.CodingKeys.displayName.stringValue, .text)
                t.column(Matrix.User.CodingKeys.avatarUrl.stringValue, .text)
                t.column(Matrix.User.CodingKeys.avatar.stringValue, .blob)
                t.column(Matrix.User.CodingKeys.statusMessage.stringValue, .text)
            }
        }
    }

    public static let databaseTableName = "users"

    public func save(_ store: GRDBDataStore) async throws {
        try await store.save(self)
    }

    public func load(_ store: GRDBDataStore) async throws -> Matrix.User? {
        return try await store.load(Matrix.User.self, self.id)
    }

    public static func load(_ store: GRDBDataStore, key: StorableKey) async throws -> Matrix.User? {
        return try await store.load(Matrix.User.self, key)
    }

    public func remove(_ store: GRDBDataStore) async throws {
        try await store.remove(self)
    }
}
