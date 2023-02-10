//
//  MatrixCredentials.swift
//  Circles
//
//  Created by Charles Wright on 4/25/22.
//

import Foundation
import GRDB

/// Login 200 response: https://spec.matrix.org/v1.5/client-server-api/#post_matrixclientv3login
extension Matrix {
    public struct Credentials: Codable, Equatable {        
        public let userId: UserId
        public let deviceId: DeviceId
        
        public var accessToken: String
        public var expiresInMs: Int? = nil
        
        @available(*, deprecated, message: "Clients should extract the homeServer from userId.")
        public var homeServer: String? = nil
        public var refreshToken: String? = nil
        public var wellKnown: Matrix.WellKnown? = nil
        
        public init(userId: UserId, deviceId: DeviceId, accessToken: String,
                    expiresInMs: Int? = nil, homeServer: String? = nil,
                    refreshToken: String? = nil, wellKnown: Matrix.WellKnown? = nil) {
            self.userId = userId
            self.deviceId = deviceId
            self.accessToken = accessToken
            self.expiresInMs = expiresInMs
            self.homeServer = homeServer
            self.refreshToken = refreshToken
            self.wellKnown = wellKnown
        }
        
        public static func == (lhs: Matrix.Credentials, rhs: Matrix.Credentials) -> Bool {
            return lhs.userId == rhs.userId &&
            lhs.deviceId == rhs.deviceId &&
            lhs.accessToken == rhs.accessToken &&
            lhs.expiresInMs == rhs.expiresInMs &&
            lhs.homeServer == rhs.homeServer &&
            lhs.refreshToken == rhs.refreshToken &&
            lhs.wellKnown == rhs.wellKnown
        }
        
        public enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case deviceId = "device_id"
            case expiresInMs = "expires_in_ms"
            case homeServer = "home_server"
            case refreshToken = "refresh_token"
            case userId = "user_id"
            case wellKnown = "well_known"
        }
    }
}

extension Matrix.Credentials: StorableDecodingContext, FetchableRecord, PersistableRecord {
    public static func createTable(_ store: GRDBDataStore) async throws {
        try await store.dbQueue.write { db in
            try db.create(table: databaseTableName) { t in
                t.primaryKey {
                    t.column(Matrix.Credentials.CodingKeys.userId.stringValue, .text).notNull()
                }

                t.column(Matrix.Credentials.CodingKeys.deviceId.stringValue, .text).notNull()
                t.column(Matrix.Credentials.CodingKeys.accessToken.stringValue, .text).notNull()
                t.column(Matrix.Credentials.CodingKeys.expiresInMs.stringValue, .integer)
                t.column(Matrix.Credentials.CodingKeys.homeServer.stringValue, .text)
                t.column(Matrix.Credentials.CodingKeys.refreshToken.stringValue, .text)
                t.column(Matrix.Credentials.CodingKeys.wellKnown.stringValue, .blob)
            }
        }
    }
    public static let databaseTableName = "credentials"
    public static var decodingDataStore: GRDBDataStore?
    public static var decodingDatabase: Database?
    public static var decodingSession: Matrix.Session?
}

