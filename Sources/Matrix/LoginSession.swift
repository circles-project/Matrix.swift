//
//  LoginSession.swift
//  
//
//  Created by Charles Wright on 12/9/22.
//

import Foundation
import AnyCodable

public class LoginSession: UIAuthSession<Matrix.Credentials> {
    public let userId: UserId
    
    public struct LoginRequestBody: Codable {
        public struct Identifier: Codable {
            public let type: String
            public let user: String
        }
        public var identifier: Identifier
        public var type: String?
        public var password: String?
        public var token: String?
        public var deviceId: String?
        public var initialDeviceDisplayName: String?
        public var refreshToken: Bool?
        
        public enum CodingKeys: String, CodingKey {
            case identifier
            case type
            case password
            case token
            case deviceId = "device_id"
            case initialDeviceDisplayName = "initial_device_display_name"
            case refreshToken = "refresh_token"
        }
    }
    
    public convenience init(userId: String,
                            password: String? = nil,
                            deviceId: String? = nil,
                            initialDeviceDisplayName: String? = nil
    ) async throws {
        guard let domain = UserId(userId)?.domain
        else {
            throw Matrix.Error("Couldn't parse Matrix user id \(userId)")
        }
        let wellknown = try await Matrix.fetchWellKnown(for: domain)
        
        guard let homeserver = URL(string: wellknown.homeserver.baseUrl)
        else {
            throw Matrix.Error("Couldn't look up well-known homeserver for user id \(userId)")
        }
        
        try await self.init(homeserver: homeserver,
                            userId: userId,
                            password: password,
                            deviceId: deviceId,
                            initialDeviceDisplayName: initialDeviceDisplayName)
    }
    
    public init(homeserver: URL,
                userId: String,
                password: String? = nil,
                deviceId: String? = nil,
                initialDeviceDisplayName: String? = nil
    ) async throws {
        let version = "v3"
        let urlPath = "/_matrix/client/\(version)/login"
        self.userId = UserId(userId)!
        let wellknown = try await Matrix.fetchWellKnown(for: self.userId.domain)
        
        guard let url = URL(string: wellknown.homeserver.baseUrl + urlPath) else {
            throw Matrix.Error("Couldn't construct /login URL")
        }

        let args: [String: Codable] = [
            "identifier": LoginRequestBody.Identifier(type: "m.id.user", user: userId),
            "password": password,                                // For legacy non-UIA login
            "type": password != nil ? "m.login.password" : nil,  // For legacy non-UIA login
            "device_id": deviceId,
            "initial_device_display_name": initialDeviceDisplayName,
        ]
        
        super.init(method: "POST", url: url, requestDict: args)
    }
    
    public convenience init(username: String, domain: String, deviceId: String? = nil, initialDeviceDisplayName: String? = nil) async throws {
        try await self.init(userId: "@\(username):\(domain)", deviceId: deviceId, initialDeviceDisplayName: initialDeviceDisplayName)
    }
}
