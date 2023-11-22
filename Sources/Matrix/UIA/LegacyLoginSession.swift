//
//  LegacyLoginSession.swift
//
//
//  Created by Charles Wright on 10/31/23.
//

import Foundation

public class LegacyLoginSession: ObservableObject {
    public var userId: UserId
    public var deviceId: String?
    public var initialDeviceDisplayName: String?
    public var refreshToken: Bool?
    
    var completion: ((Matrix.Credentials) async throws -> Void)?
    var cancellation: (() async -> Void)?
    
    public enum Status {
        case new
        case failure(String)
        case success(Matrix.Credentials)
    }
    @Published private(set) public var status: Status
    
    public init(userId: UserId,
                deviceId: String? = nil,
                initialDeviceDisplayName: String? = nil,
                refreshToken: Bool? = nil,
                completion: ((Matrix.Credentials) async throws -> Void)? = nil,
                cancellation: (() async -> Void)? = nil
    ) {
        self.userId = userId
        self.deviceId = deviceId
        self.initialDeviceDisplayName = initialDeviceDisplayName
        self.refreshToken = refreshToken
        self.completion = completion
        self.cancellation = cancellation
        self.status = .new
    }
    
    public func login(password: String) async throws {
        
        if let creds: Matrix.Credentials = try? await Matrix.login(userId: userId, password: password, deviceId: deviceId, initialDeviceDisplayName: initialDeviceDisplayName, refreshToken: refreshToken) {
            await MainActor.run {
                self.status = .success(creds)
            }
            if let callback = self.completion {
                try? await callback(creds)
            }
        } else {
            await MainActor.run {
                self.status = .failure("Login failed")
            }
        }
    }
}
