//
//  Matrix+User.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation

extension Matrix {
    public class User: ObservableObject, Identifiable {
        public let id: UserId // For Identifiable
        public var session: Session
        @Published public var displayName: String?
        @Published public var avatarUrl: String?
        @Published public var avatar: NativeImage?
        @Published public var statusMessage: String?
                
        public init(userId: UserId, session: Session) {
            self.id = userId
            self.session = session
            
            _ = Task {
                try await self.refreshProfile()
            }
        }
        
        public func refreshProfile() async throws {
            (self.displayName, self.avatarUrl) = try await self.session.getProfileInfo(userId: self.id)
        }
    }
}
