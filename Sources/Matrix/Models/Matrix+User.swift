//
//  Matrix+User.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation
import GRDB

extension Matrix {
    public class User: ObservableObject, Identifiable {
        public let id: UserId // For Identifiable
        public var session: Session
        @Published public var displayName: String?
        @Published public var avatarUrl: String?
        @Published public var avatar: NativeImage?
        @Published public var statusMessage: String?
        
        public enum CodingKeys: String, CodingKey {
            case id
            case session
            case displayName
            case avatarUrl
            case avatar
            case statusMessage
        }
        
        public init(userId: UserId, session: Session) {
            self.id = userId
            self.session = session
            
            _ = Task {
                try await self.refreshProfile()
            }
        }
        
        public required init(row: Row) throws {
            guard let session = Matrix.User.decodingSession else {
                throw Matrix.Error("Error initializing session field")
            }
            
            self.id = row[CodingKeys.id.stringValue]
            self.session = session
            self.displayName = row[CodingKeys.displayName.stringValue]
            self.avatarUrl = row[CodingKeys.avatarUrl.stringValue]
            self.avatar = nil // Avatar will be fetched from URLSession cache
            self.statusMessage = row[CodingKeys.statusMessage.stringValue]
            
            _ = Task {
                try await self.refreshProfile()
            }
        }

        public func encode(to container: inout PersistenceContainer) throws {
            container[CodingKeys.id.stringValue] = id
            // session not being encoded
            container[CodingKeys.displayName.stringValue] = displayName
            container[CodingKeys.avatarUrl.stringValue] = avatarUrl
            // avatar not being encoded
            container[CodingKeys.statusMessage.stringValue] = statusMessage
        }
                
        public func refreshProfile() async throws {
            (self.displayName, self.avatarUrl) = try await self.session.getProfileInfo(userId: self.id)
        }
    }
}

extension Matrix.User: StorableDecodingContext, FetchableRecord, PersistableRecord {
    public static func createTable(_ store: GRDBDataStore) async throws {
        try await store.dbQueue.write { db in
            try db.create(table: databaseTableName) { t in
                t.primaryKey {
                    t.column(Matrix.User.CodingKeys.id.stringValue, .text).notNull()
                }

                t.column(Matrix.User.CodingKeys.displayName.stringValue, .text)
                t.column(Matrix.User.CodingKeys.avatarUrl.stringValue, .text)
                t.column(Matrix.User.CodingKeys.statusMessage.stringValue, .text)
            }
        }
    }

    public static let databaseTableName = "users"
    public static var decodingDataStore: GRDBDataStore?
    public static var decodingDatabase: Database?
    public static var decodingSession: Matrix.Session?
}
