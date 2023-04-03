//
//  LoginSession.swift
//  
//
//  Created by Charles Wright on 12/9/22.
//

import Foundation
import AnyCodable

public class LoginSession: UIAuthSession<Matrix.Credentials> {
    
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
    
    public convenience init(userId: UserId,
                            password: String? = nil,
                            deviceId: String? = nil,
                            initialDeviceDisplayName: String? = nil,
                            completion: ((Matrix.Credentials) async throws -> Void)? = nil
    ) async throws {

        let wellknown = try await Matrix.fetchWellKnown(for: userId.domain)
        
        guard let homeserver = URL(string: wellknown.homeserver.baseUrl)
        else {
            throw Matrix.Error("Couldn't look up well-known homeserver for user id \(userId)")
        }
        
        try await self.init(homeserver: homeserver,
                            userId: userId,
                            password: password,
                            deviceId: deviceId,
                            initialDeviceDisplayName: initialDeviceDisplayName,
                            completion: completion)
    }
    
    public init(homeserver: URL,
                userId: UserId,
                password: String? = nil,
                deviceId: String? = nil,
                initialDeviceDisplayName: String? = nil,
                completion: ((Matrix.Credentials) async throws -> Void)? = nil
    ) async throws {
        let version = "v3"
        let urlPath = "/_matrix/client/\(version)/login"
        let wellknown = try await Matrix.fetchWellKnown(for: self.userId.domain)
        
        guard let url = URL(string: wellknown.homeserver.baseUrl + urlPath) else {
            throw Matrix.Error("Couldn't construct /login URL")
        }

        var args: [String: Codable] = [
            "identifier": LoginRequestBody.Identifier(type: "m.id.user", user: "\(userId)"),
        ]
        
        // For legacy non-UIA login
        if let password = password {
            args["password"] = password
            args["type"] = "m.login.password"
        }
        
        if let deviceId = deviceId {
            args["device_id"] = deviceId
        }
        
        if let initialDeviceDisplayName = initialDeviceDisplayName {
            args["initial_device_display_name"] = initialDeviceDisplayName
        }
        
        super.init(method: "POST", url: url, requestDict: args, completion: completion)
        
        self.storage["userId"] = userId
    }
    
    public convenience init(username: String,
                            domain: String,
                            deviceId: String? = nil,
                            initialDeviceDisplayName: String? = nil,
                            completion: ((Matrix.Credentials) async throws -> Void)? = nil
    ) async throws {
        guard let userId = UserId("@\(username):\(domain)")
        else {
            throw Matrix.Error("Invalid user id")
        }
        try await self.init(userId: userId,
                            deviceId: deviceId,
                            initialDeviceDisplayName: initialDeviceDisplayName,
                            completion: completion)
    }
}
