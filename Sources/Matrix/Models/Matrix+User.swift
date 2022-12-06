//
//  Matrix+User.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation

extension Matrix {
    class User: ObservableObject, Identifiable {
        let id: UserId // For Identifiable
        var session: Session
        @Published var displayName: String?
        @Published var avatarUrl: String?
        @Published var avatar: NativeImage?
        @Published var statusMessage: String?
                
        init(userId: UserId, session: Session) {
            self.id = userId
            self.session = session
            
            _ = Task {
                try await self.refreshProfile()
            }
        }
        
        func refreshProfile() async throws {
            (self.displayName, self.avatarUrl) = try await self.session.getProfileInfo(userId: self.id)
        }
    }
}
