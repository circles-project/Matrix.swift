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
}
