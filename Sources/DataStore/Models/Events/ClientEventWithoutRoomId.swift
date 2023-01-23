//
//  ClientEventWithoutRoomId.swift
//  
//
//  Created by Michael Hollister on 1/23/23.
//

import Foundation
import Matrix
import GRDB

extension ClientEventWithoutRoomId: FetchableRecord, PersistableRecord {
    // docs tbd: uses ClientEvents table with null room id, or can specify room id via function interface
    public static let databaseTableName = "clientEvents"

    public func save(_ store: GRDBDataStore) async throws {
        try await store.save(self)
    }

    public func save(_ store: GRDBDataStore, roomId: RoomId) async throws {
        let event = try ClientEvent(content: self.content, eventId: self.eventId, originServerTS: self.originServerTS,
                                                 roomId: roomId, sender: self.sender, stateKey: self.stateKey, type: self.type, unsigned: self.unsigned)
        try await store.save(event)
    }
    
    public func load(_ store: GRDBDataStore) async throws -> ClientEventWithoutRoomId? {
        return try await store.load(ClientEventWithoutRoomId.self, self.eventId)
    }

    public static func load(_ store: GRDBDataStore, key: StorableKey) async throws -> ClientEventWithoutRoomId? {
        return try await store.load(ClientEventWithoutRoomId.self, key)
    }
    
    public func remove(_ store: GRDBDataStore) async throws {
        try await store.remove(self)
    }
}
