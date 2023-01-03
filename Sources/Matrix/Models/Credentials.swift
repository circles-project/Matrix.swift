//
//  MatrixCredentials.swift
//  Circles
//
//  Created by Charles Wright on 4/25/22.
//

import Foundation

extension Matrix {

    struct Credentials: Codable {
        var accessToken: String
        var deviceId: String
        var userId: UserId
        var wellKnown: Matrix.WellKnown?
        //var homeServer: String? // Warning: Deprecated; Do not use
        
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case deviceId = "device_id"
            case userId = "user_id"
            case wellKnown = "well_known"
        }
    }
}
