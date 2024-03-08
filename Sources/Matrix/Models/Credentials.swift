//
//  MatrixCredentials.swift
//  Circles
//
//  Created by Charles Wright on 4/25/22.
//

import Foundation

extension Matrix {
    public struct Credentials: Codable {
        public var accessToken: String
        public var deviceId: String
        public var expiration: Date?
        public var refreshToken: String?
        public var userId: UserId
        public var wellKnown: Matrix.WellKnown?
        

        public enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case deviceId = "device_id"
            
            // OK this is a bit weird because the Matrix C-S API decided to do something weird (again)
            // They send the expiration as a relative time instead of an absolute time
            // But that's crazy, so we convert it to an absolute time for internal storage and/or for saving locally on the client
            // NOTE: If we ever re-use this code on the server, we'll have to flip this around backwards
            //       and have init(from decoder:) use the absolute time
            //       and make encode() send the relative time
            // This is why you shouldn't do silly ambiguous stuff like this
            case expiration
            case expiresInMs = "expires_in_ms"
            
            case refreshToken = "refresh_token"
            case userId = "user_id"
            case wellKnown = "well_known"
        }
        
        public init(userId: UserId,
                    accessToken: String,
                    deviceId: String,
                    expiration: Date? = nil,
                    refreshToken: String? = nil,
                    wellKnown: Matrix.WellKnown? = nil
        ) {
            self.userId = userId
            self.accessToken = accessToken
            self.deviceId = deviceId
            self.expiration = expiration
            self.refreshToken = refreshToken
            self.wellKnown = wellKnown
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.accessToken = try container.decode(String.self, forKey: .accessToken)
            self.deviceId = try container.decode(String.self, forKey: .deviceId)
            if let lifetime = try container.decodeIfPresent(UInt.self, forKey: .expiresInMs) {
                self.expiration = Date() + TimeInterval(lifetime/1000)
            } else {
                self.expiration = try container.decodeIfPresent(Date.self, forKey: .expiration)
            }
            self.refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
            self.userId = try container.decode(UserId.self, forKey: .userId)
            self.wellKnown = try container.decodeIfPresent(Matrix.WellKnown.self, forKey: .wellKnown)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.accessToken, forKey: .accessToken)
            try container.encode(self.deviceId, forKey: .deviceId)
            try container.encodeIfPresent(self.expiration, forKey: .expiration)
            try container.encodeIfPresent(self.refreshToken, forKey: .refreshToken)
            try container.encode(self.userId, forKey: .userId)
            try container.encodeIfPresent(self.wellKnown, forKey: .wellKnown)
        }
        
        public func save(suiteName: String? = nil) throws {
            let defaults: UserDefaults
            
            if let suite = suiteName {
                guard let d = UserDefaults(suiteName: suite)
                else {
                    Matrix.logger.error("Failed to initialize UserDefaults for suite \(suite)")
                    throw Matrix.Error("Failed to initialize UserDefaults")
                }
                defaults = d
            } else {
                defaults = UserDefaults.standard
            }

            let encoder = JSONEncoder()
            let data = try encoder.encode(self)
            // Save the creds data in a single blob
            defaults.set(data, forKey: "credentials[\(userId)]")
        }
        
        public static func load(for userId: UserId, suiteName: String? = nil) throws -> Credentials? {
            let defaults: UserDefaults
            
            if let suite = suiteName {
                guard let d = UserDefaults(suiteName: suite)
                else {
                    Matrix.logger.error("Failed to initialize UserDefaults for suite \(suite)")
                    throw Matrix.Error("Failed to initialize UserDefaults")
                }
                defaults = d
            } else {
                defaults = UserDefaults.standard
            }
            // First check to see if we have saved our creds in the new format
            let decoder = JSONDecoder()
            if let data = defaults.data(forKey: "credentials[\(userId)]"),
               let creds = try? decoder.decode(Matrix.Credentials.self, from: data),
               creds.userId == userId
            {
                return creds
            }
            
            // Fall back to the older approach of loading each item individually
            guard let deviceId = defaults.string(forKey: "device_id[\(userId)]"),
                  let accessToken = defaults.string(forKey: "access_token[\(userId)]")
            else {
                return nil
            }
            let expiration = defaults.object(forKey: "expiration[\(userId)]") as? Date
            let refreshToken = defaults.string(forKey: "refresh_token[\(userId)]")
            
            return .init(userId: userId,
                         accessToken: accessToken,
                         deviceId: deviceId,
                         expiration: expiration,
                         refreshToken: refreshToken)
        }
    }
}
