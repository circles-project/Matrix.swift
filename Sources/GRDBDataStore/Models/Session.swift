//
//  Session.swift
//  
//
//  Created by Michael Hollister on 1/22/23.
//

import Foundation
import Matrix
import GRDB

// make note regarding singleton behavior? determine how sync data will be stored

extension Matrix.Session: FetchableRecord, PersistableRecord { //}, EncodableRecord {
    internal static func createTable(_ store: GRDBDataStore) async throws {
        try await store.dbQueue.write { db in
            try db.create(table: databaseTableName) { t in
                // FIXME: Change to foreign composite key (userid, deviceid) from 'credentials'
                t.primaryKey {
                    t.column(Matrix.Session.CodingKeys.credentials.stringValue, .blob).notNull()
                    //t.column(Matrix.Session.CodingKeys.credentials.stringValue, .blob).notNull().references(Matrix.Credentials.databaseTableName)
                }

                t.column(Matrix.Session.CodingKeys.displayName.stringValue, .text)
                t.column(Matrix.Session.CodingKeys.avatarUrl.stringValue, .text)
                t.column(Matrix.Session.CodingKeys.avatar.stringValue, .blob)
                t.column(Matrix.Session.CodingKeys.statusMessage.stringValue, .text)
                // FIXME: Encode rooms as list of foreign keys to room ids in rooms table
                // FIXME: Encode invitations as list of foreign keys to room ids in invitedRooms table
                t.column(Matrix.Session.CodingKeys.syncToken.stringValue, .text)
                t.column(Matrix.Session.CodingKeys.syncRequestTimeout.stringValue, .integer)
                t.column(Matrix.Session.CodingKeys.keepSyncing.stringValue, .boolean)
                t.column(Matrix.Session.CodingKeys.syncDelayNs.stringValue, .integer)
                t.column(Matrix.Session.CodingKeys.ignoreUserIds.stringValue, .blob)
                t.column(Matrix.Session.CodingKeys.recoverySecretKey.stringValue, .blob)
                t.column(Matrix.Session.CodingKeys.recoveryTimestamp.stringValue, .date)
            }
        }
    }
    
    public static let databaseTableName = "sessions"
    public static var databaseDecodingUserInfo: [CodingUserInfoKey : Any] = [:]
    private static let userInfoDataStoreKey = CodingUserInfoKey(rawValue: Matrix.Session.CodingKeys.dataStore.stringValue)!
    
//    public func encode(to container: inout PersistenceContainer) throws {
//        //container[Matrix.Session.CodingKeys.credentials.stringValue] =
//        container[Matrix.Session.CodingKeys.displayName.stringValue] = self.displayName
//        container[Matrix.Session.CodingKeys.avatarUrl.stringValue] = self.avatarUrl
//        container[Matrix.Session.CodingKeys.avatar.stringValue] = self.avatar
//        container[Matrix.Session.CodingKeys.statusMessage.stringValue] = self.statusMessage
//        container[Matrix.Session.CodingKeys.displayName.stringValue] = self.displayName
//        container[Matrix.Session.CodingKeys.displayName.stringValue] = self.displayName
//        container[Matrix.Session.CodingKeys.syncToken.stringValue] = self.syncToken
//        container[Matrix.Session.CodingKeys.syncRequestTimeout.stringValue] = self.syncRequestTimeout
//        container[Matrix.Session.CodingKeys.keepSyncing.stringValue] = self.keepSyncing
//        container[Matrix.Session.CodingKeys.syncDelayNs.stringValue] = self.syncDelayNs
//        container[Matrix.Session.CodingKeys.ignoreUserIds.stringValue] = self.ignoreUserIds
//        container[Matrix.Session.CodingKeys.recoverySecretKey.stringValue] = self.recoverySecretKey
//        container[Matrix.Session.CodingKeys.recoveryTimestamp.stringValue] = self.recoveryTimestamp
//    }


    internal static func load(_ store: GRDBDataStore, key: StorableKey) throws -> Matrix.Session? {
        let compositeKey: [String: DatabaseValueConvertible] = [Matrix.Credentials.CodingKeys.userId.stringValue: key.0,
                                                                Matrix.Credentials.CodingKeys.deviceId.stringValue: key.1]
        Matrix.Session.databaseDecodingUserInfo = [Matrix.Session.userInfoDataStoreKey: store]
        return try store.load(Matrix.Session.self, key: compositeKey)
    }

    internal static func load(_ store: GRDBDataStore, key: StorableKey) async throws -> Matrix.Session? {
        let compositeKey: [String: DatabaseValueConvertible] = [Matrix.Credentials.CodingKeys.userId.stringValue: key.0,
                                                                Matrix.Credentials.CodingKeys.deviceId.stringValue: key.1]
        Matrix.Session.databaseDecodingUserInfo = [Matrix.Session.userInfoDataStoreKey: store]
        return try await store.load(Matrix.Session.self, key: compositeKey)
    }
}
