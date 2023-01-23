//
//  Room.swift
//  
//
//  Created by Michael Hollister on 1/17/23.
//

import Foundation
import Matrix
import GRDB

extension Matrix.Room: FetchableRecord, PersistableRecord {
    internal static func createTable(_ store: GRDBDataStore) async throws {
        try await store.dbQueue.write { db in
            try db.create(table: databaseTableName) { t in
                t.primaryKey {
                    t.column(Matrix.Room.CodingKeys.roomId.stringValue, .text).notNull()
                }

                t.column(Matrix.Room.CodingKeys.type.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.version.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.name.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.topic.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.avatarUrl.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.avatar.stringValue, .blob)
                t.column(Matrix.Room.CodingKeys.predecessorRoomId.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.successorRoomId.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.tombstoneEventId.stringValue, .text)
                
                // FIXME: Change to list of foreign keys to clientEvents with added room ids (self)
                t.column(Matrix.Room.CodingKeys.messages.stringValue, .blob)
                t.column(Matrix.Room.CodingKeys.localEchoEvent.stringValue, .blob)
                t.column(Matrix.Room.CodingKeys.highlightCount.stringValue, .integer)
                t.column(Matrix.Room.CodingKeys.notificationCount.stringValue, .integer)
                t.column(Matrix.Room.CodingKeys.joinedMembers.stringValue, .blob)
                t.column(Matrix.Room.CodingKeys.invitedMembers.stringValue, .blob)
                t.column(Matrix.Room.CodingKeys.leftMembers.stringValue, .blob)
                t.column(Matrix.Room.CodingKeys.bannedMembers.stringValue, .blob)
                t.column(Matrix.Room.CodingKeys.knockingMembers.stringValue, .blob)
                t.column(Matrix.Room.CodingKeys.encryptionParams.stringValue, .blob)
            }
        }
    }
    
    public static let databaseTableName = "rooms"
        
    public func save(_ store: GRDBDataStore) async throws {
        try await store.save(self)
    }
    
    public func load(_ store: GRDBDataStore) async throws -> Matrix.Room? {
        return try await store.load(Matrix.Room.self, self.roomId)
    }
    
    public static func load(_ store: GRDBDataStore, key: StorableKey) async throws -> Matrix.Room? {
        return try await store.load(Matrix.Room.self, key)
    }
    
    public func remove(_ store: GRDBDataStore) async throws {
        try await store.remove(self)
    }
}
