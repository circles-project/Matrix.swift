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
    public static var databaseDecodingUserInfo: [CodingUserInfoKey : Any] = [:]
    private static let userInfoSessionKey = CodingUserInfoKey(rawValue: Matrix.User.CodingKeys.session.stringValue)!
    
    internal static func load(_ store: GRDBDataStore, key: StorableKey, session: Matrix.Session) throws -> Matrix.User? {
        Matrix.User.databaseDecodingUserInfo = [Matrix.User.userInfoSessionKey: session]
        return try store.load(Matrix.User.self, key: key)
    }
    
    internal static func load(_ store: GRDBDataStore, key: StorableKey, session: Matrix.Session) async throws -> Matrix.User? {
        Matrix.User.databaseDecodingUserInfo = [Matrix.User.userInfoSessionKey: session]
        return try await store.load(Matrix.User.self, key: key)
    }
}
