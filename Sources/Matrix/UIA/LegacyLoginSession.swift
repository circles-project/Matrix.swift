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
    
    var completion: ((Matrix.Credentials) async throws -> Void)?
    
    public enum Status {
        case new
        case failure(String)
        case success(Matrix.Credentials)
    }
    @Published private(set) public var status: Status
    
    public init(userId: UserId,
                deviceId: String? = nil,
                initialDeviceDisplayName: String? = nil,
                completion: ((Matrix.Credentials) async throws -> Void)? = nil
    ) {
        self.userId = userId
        self.deviceId = deviceId
        self.initialDeviceDisplayName = initialDeviceDisplayName
        self.completion = completion
        self.status = .new
    }
    
    public func login(password: String) async throws {
        
        if let creds: Matrix.Credentials = try? await Matrix.login(userId: userId, password: password, deviceId: deviceId, initialDeviceDisplayName: initialDeviceDisplayName) {
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
