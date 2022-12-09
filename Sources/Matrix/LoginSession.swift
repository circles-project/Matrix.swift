//
//  LoginSession.swift
//  
//
//  Created by Charles Wright on 12/9/22.
//

import Foundation
import AnyCodable

class LoginSession: UIAuthSession {
    let userId: UserId
    
    struct LoginRequestBody: Codable {
        struct Identifier: Codable {
            let type: String
            let user: String
        }
        var identifier: Identifier
        var type: String?
        var password: String?
        var token: String?
        var deviceId: String?
        var initialDeviceDisplayName: String?
        var refreshToken: Bool?
        
        enum CodingKeys: String, CodingKey {
            case identifier
            case type
            case password
            case token
            case deviceId = "device_id"
            case initialDeviceDisplayName = "initial_device_display_name"
            case refreshToken = "refresh_token"
        }
    }
    
    init(userId: String, deviceId: String? = nil, initialDeviceDisplayName: String? = nil) async throws {
        let version = "v3"
        let urlPath = "/_matrix/client/\(version)/login"
        self.userId = UserId(userId)!
        let wellknown = try await Matrix.fetchWellKnown(for: self.userId.domain)
        
        guard let url = URL(string: wellknown.homeserver.baseUrl + urlPath) else {
            throw Matrix.Error("Couldn't construct /login URL")
        }
        // Ugh we're doing this the Idiocracy way...  ok fine...
        let args: [String: AnyCodable] = [
            "identifier": AnyCodable(LoginRequestBody.Identifier(type: "m.id.user", user: userId)),
            "device_id": deviceId != nil ? AnyCodable(deviceId!) : nil,
            "initial_device_display_name": initialDeviceDisplayName != nil ? AnyCodable(initialDeviceDisplayName!) : nil,
        ]
        
        super.init(method: "POST", url: url, requestDict: args)
    }
    
    convenience init(username: String, domain: String, deviceId: String? = nil, initialDeviceDisplayName: String? = nil) async throws {
        try await self.init(userId: "@\(username):\(domain)", deviceId: deviceId, initialDeviceDisplayName: initialDeviceDisplayName)
    }
}
