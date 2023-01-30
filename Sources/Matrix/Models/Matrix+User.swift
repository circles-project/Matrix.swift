//
//  Matrix+User.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation

extension Matrix {
    public class User: ObservableObject, Identifiable, Codable, Storable {
        public typealias StorableKey = UserId
        
        public let id: UserId // For Identifiable
        public var session: Session
        @Published public var displayName: String?
        @Published public var avatarUrl: String?
        @Published public var avatar: NativeImage?
        @Published public var statusMessage: String?
        
        public enum CodingKeys: String, CodingKey {
            case id
            case session
            case displayName
            case avatarUrl
            case avatar
            case statusMessage
        }
        
        public init(userId: UserId, session: Session) {
            self.id = userId
            self.session = session
            
            _ = Task {
                try await self.refreshProfile()
            }
        }
        
        // Successfuly decoding of the object requires that a session instance is stored
        // in the decoder's `userInfo` dictionary
        public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            if let sessionKey = CodingUserInfoKey(rawValue: CodingKeys.session.stringValue),
               let unwrappedSession = decoder.userInfo[sessionKey] as? Session {
                self.session = unwrappedSession
            }
            else {
                throw Matrix.Error("Error initializing session field")
            }

            self.id = try container.decode(UserId.self, forKey: .id)
            self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            self.avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
            self.avatar = try container.decodeIfPresent(NativeImage.self, forKey: .avatar)
            self.statusMessage = try container.decodeIfPresent(String.self, forKey: .statusMessage)
            
            _ = Task {
                try await self.refreshProfile()
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(id, forKey: .id)
            // session not being encoded
            try container.encode(displayName, forKey: .displayName)
            try container.encode(avatarUrl, forKey: .avatarUrl)
            try container.encode(avatar, forKey: .avatar)
            try container.encode(statusMessage, forKey: .statusMessage)
        }
        
        public func refreshProfile() async throws {
            (self.displayName, self.avatarUrl) = try await self.session.getProfileInfo(userId: self.id)
        }
    }
}
