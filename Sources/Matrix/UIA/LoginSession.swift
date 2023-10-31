//
//  LoginSession.swift
//  
//
//  Created by Charles Wright on 12/9/22.
//

import Foundation
import AnyCodable

public class LoginSession: UIAuthSession {
    
    public convenience init(userId: UserId,
                            password: String? = nil,
                            deviceId: String? = nil,
                            initialDeviceDisplayName: String? = nil,
                            completion: ((UIAuthSession,Data) async throws -> Void)? = nil,
                            cancellation: (() async -> Void)? = nil
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
                            completion: completion,
                            cancellation: cancellation)
    }
    
    public init(homeserver: URL,
                userId: UserId,
                password: String? = nil,
                deviceId: String? = nil,
                initialDeviceDisplayName: String? = nil,
                completion: ((UIAuthSession,Data) async throws -> Void)? = nil,
                cancellation: (() async -> Void)? = nil
    ) async throws {
        let version = "v3"
        let urlPath = "/_matrix/client/\(version)/login"
        
        guard let url = URL(string: urlPath, relativeTo: homeserver) else {
            throw Matrix.Error("Couldn't construct /login URL")
        }

        var args: [String: Codable] = [
            "identifier": Matrix.LoginRequestBody.Identifier(type: "m.id.user", user: "\(userId)"),
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
        
        super.init(method: "POST", url: url, requestDict: args, completion: completion, cancellation: cancellation)
        
        self.storage["userId"] = userId
    }
    
    public convenience init(username: String,
                            domain: String,
                            deviceId: String? = nil,
                            initialDeviceDisplayName: String? = nil,
                            completion: ((UIAuthSession,Data) async throws -> Void)? = nil,
                            cancellation: (() async -> Void)? = nil
    ) async throws {
        guard let userId = UserId("@\(username):\(domain)")
        else {
            throw Matrix.Error("Invalid user id")
        }
        try await self.init(userId: userId,
                            deviceId: deviceId,
                            initialDeviceDisplayName: initialDeviceDisplayName,
                            completion: completion,
                            cancellation: cancellation)
    }
}
