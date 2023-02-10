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
        public var userId: UserId
        public var wellKnown: Matrix.WellKnown?
        //public var homeServer: String? // Warning: Deprecated; Do not use
        
        public enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case deviceId = "device_id"
            case userId = "user_id"
            case wellKnown = "well_known"
        }
        
        public init(userId: UserId, accessToken: String, deviceId: String, wellKnown: Matrix.WellKnown? = nil) {
            self.userId = userId
            self.accessToken = accessToken
            self.deviceId = deviceId
            self.wellKnown = wellKnown
        }
    }
}
