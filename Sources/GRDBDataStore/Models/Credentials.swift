//
//  Credentials.swift
//  
//
//  Created by Michael Hollister on 1/13/23.
//

import Foundation
import Matrix
import GRDB

extension Matrix.Credentials: FetchableRecord, PersistableRecord {
    internal static func createTable(_ store: GRDBDataStore) async throws {
        try await store.dbQueue.write { db in
            try db.create(table: databaseTableName) { t in
                t.primaryKey {
                    t.column(Matrix.Credentials.CodingKeys.userId.stringValue, .text).notNull()
                    t.column(Matrix.Credentials.CodingKeys.deviceId.stringValue, .text).notNull()
                }

                t.column(Matrix.Credentials.CodingKeys.accessToken.stringValue, .text).notNull()
                t.column(Matrix.Credentials.CodingKeys.expiresInMs.stringValue, .integer)
                t.column(Matrix.Credentials.CodingKeys.homeServer.stringValue, .text)
                t.column(Matrix.Credentials.CodingKeys.refreshToken.stringValue, .text)
                t.column(Matrix.Credentials.CodingKeys.wellKnown.stringValue, .blob)
            }
        }
    }
    public static let databaseTableName = "credentials"
    
    internal static func getDatabaseValueConvertibleKey(_ key: StorableKey) -> [String: DatabaseValueConvertible] {
        let compositeKey: [String: DatabaseValueConvertible] = [Matrix.Credentials.CodingKeys.userId.stringValue: key.0,
                                                                Matrix.Credentials.CodingKeys.deviceId.stringValue: key.1]
        return compositeKey
    }
}
