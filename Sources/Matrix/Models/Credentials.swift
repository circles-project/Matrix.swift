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
    }

}
