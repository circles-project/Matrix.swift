//
//  Matrix+User.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation

extension Matrix {
    public class User: ObservableObject {
        public let userId: UserId
        public var session: Session
        @Published public var displayName: String?
        @Published public var avatarUrl: MXC?
        @Published public var avatar: NativeImage?
        @Published public var statusMessage: String?
                
        public init(userId: UserId, session: Session) {
            self.userId = userId
            self.session = session
            
            _ = Task {
                try await self.refreshProfile()
            }
        }
        
        public func refreshProfile() async throws {
            let newDisplayName: String?
            let newAvatarUrl: MXC?
            
            (newDisplayName, newAvatarUrl) = try await self.session.getProfileInfo(userId: userId)
            await MainActor.run {
                self.displayName = newDisplayName
                self.avatarUrl = newAvatarUrl
            }
        }
    }
}

extension Matrix.User: Identifiable {
    public var id: String {
        "\(self.userId)"
    }
}
