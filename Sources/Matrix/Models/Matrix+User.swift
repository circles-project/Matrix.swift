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
        @Published private(set) public var displayName: String?
        private(set) public var avatarUrl: MXC?
        @Published private(set) public var avatar: NativeImage?
        private var currentAvatarUrl: MXC?
        @Published public var statusMessage: String?
        private var refreshProfileTask: Task<Void,Swift.Error>?
        private var fetchAvatarImageTask: Task<Void,Swift.Error>?
                
        public init(userId: UserId, session: Session) {
            self.userId = userId
            self.session = session
            
            self.refreshProfile()
        }
        
        public func refreshProfile() {
            self.refreshProfileTask = self.refreshProfileTask ?? .init(priority: .background, operation: {
                let newDisplayName: String?
                let newAvatarUrl: MXC?
                
                (newDisplayName, newAvatarUrl) = try await self.session.getProfileInfo(userId: userId)
                
                let needToFetchAvatar = newAvatarUrl != self.avatarUrl

                await MainActor.run {
                    self.displayName = newDisplayName
                    self.avatarUrl = newAvatarUrl
                }
                
                if needToFetchAvatar {
                    self.fetchAvatarImage()
                }
                
                // Dirty hack 😈 - Hold the "lock" to keep the application from constantly / repeatedly
                // trying to fetch a displayname or avatar_url that doesn't exist
                try await Task.sleep(for: .seconds(30))
                
                self.refreshProfileTask = nil
            })
        }
        
        public func fetchAvatarImage() {
            if let mxc = self.avatarUrl {
                
                if mxc == self.currentAvatarUrl && self.avatar != nil {
                    logger.debug("User \(self.userId) already has the latest avatar")
                    return
                }
                
                self.fetchAvatarImageTask = self.fetchAvatarImageTask ?? .init(priority: .background, operation: {
                    logger.debug("Fetching avatar for user \(self.userId) from \(mxc)")
                    let startTime = Date()
                    guard let data = try? await self.session.downloadData(mxc: mxc)
                    else {
                        logger.error("User \(self.userId) failed to download avatar from \(mxc)")
                        self.fetchAvatarImageTask = nil
                        return
                    }
                    let endTime = Date()
                    let latencyMS = endTime.timeIntervalSince(startTime) * 1000
                    logger.debug("User \(self.userId) fetched \(data.count) bytes of avatar data from \(mxc) in \(latencyMS) ms")
                    let newAvatar = Matrix.NativeImage(data: data)
                    await MainActor.run {
                        self.avatar = newAvatar
                        self.currentAvatarUrl = mxc
                    }
                    
                    self.fetchAvatarImageTask = nil
                })
    
            } else {
                logger.debug("Can't fetch avatar for user \(self.userId) because we have no avatar_url")
            }
        }
        
        public var isVerified: Bool {
            // FIXME: Query the crypto module and/or the server to find out whether we've verified this user
            false
        }
        
        public var devices: [CryptoDevice] {
            self.session.getCryptoDevices(userId: self.userId)
        }
    }
}

extension Matrix.User: Identifiable {
    public var id: String {
        "\(self.userId)"
    }
}

extension Matrix.User: Equatable {
    public static func == (lhs: Matrix.User, rhs: Matrix.User) -> Bool {
        lhs.userId == rhs.userId
    }
}

extension Matrix.User: Hashable {
    public func hash(into hasher: inout Hasher) {
        self.userId.hash(into: &hasher)
    }
}
