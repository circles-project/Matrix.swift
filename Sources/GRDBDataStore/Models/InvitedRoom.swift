//
//  InvitedRoom.swift
//  
//
//  Created by Michael Hollister on 1/22/23.
//

import Foundation
import Matrix
import GRDB

extension Matrix.InvitedRoom: FetchableRecord, PersistableRecord {
    internal static func createTable(_ store: GRDBDataStore) async throws {
        try await store.dbQueue.write { db in
            try db.create(table: databaseTableName) { t in
                t.primaryKey {
                    t.column(Matrix.InvitedRoom.CodingKeys.roomId.stringValue, .text).notNull()
                }

                t.column(Matrix.InvitedRoom.CodingKeys.type.stringValue, .text)
                t.column(Matrix.InvitedRoom.CodingKeys.version.stringValue, .text)
                t.column(Matrix.InvitedRoom.CodingKeys.predecessorRoomId.stringValue, .text)
                t.column(Matrix.InvitedRoom.CodingKeys.encrypted.stringValue, .boolean)
                t.column(Matrix.InvitedRoom.CodingKeys.creator.stringValue, .text)
                t.column(Matrix.InvitedRoom.CodingKeys.sender.stringValue, .text)
                t.column(Matrix.InvitedRoom.CodingKeys.name.stringValue, .text)
                t.column(Matrix.InvitedRoom.CodingKeys.topic.stringValue, .text)
                t.column(Matrix.InvitedRoom.CodingKeys.avatarUrl.stringValue, .text)
                t.column(Matrix.InvitedRoom.CodingKeys.avatar.stringValue, .blob)
                t.column(Matrix.InvitedRoom.CodingKeys.members.stringValue, .blob)
            }
        }
    }
    
    public static let databaseTableName = "invitedRooms"
    public static var databaseDecodingUserInfo: [CodingUserInfoKey : Any] = [:]
    private static let userInfoSessionKey = CodingUserInfoKey(rawValue: Matrix.InvitedRoom.CodingKeys.session.stringValue)!
        
    internal static func load(_ store: GRDBDataStore, key: StorableKey, session: Matrix.Session) throws -> Matrix.InvitedRoom? {
        Matrix.InvitedRoom.databaseDecodingUserInfo = [Matrix.InvitedRoom.userInfoSessionKey: session]
        return try store.load(Matrix.InvitedRoom.self, key: key)
    }
    
    internal static func load(_ store: GRDBDataStore, key: StorableKey, session: Matrix.Session) async throws -> Matrix.InvitedRoom? {
        Matrix.InvitedRoom.databaseDecodingUserInfo = [Matrix.InvitedRoom.userInfoSessionKey: session]
        return try await store.load(Matrix.InvitedRoom.self, key: key)
    }
}
