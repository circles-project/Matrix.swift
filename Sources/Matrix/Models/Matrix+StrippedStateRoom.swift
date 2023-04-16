//
//  Matrix+StrippedStateRoom.swift
//  
//
//  Created by Charles Wright on 3/23/23.
//

import Foundation

extension Matrix {
    public class StrippedStateRoom: ObservableObject {
        public var session: Session
        public let roomId: RoomId
        public let state: [String: [String:StrippedStateEvent]]  // From /sync
        public let creator: UserId
        @Published public var avatar: NativeImage?
        private var fetchAvatarImageTask: Task<Void,Swift.Error>?
                        
        public init(session: Session, roomId: RoomId, stateEvents: [StrippedStateEvent]) throws {
            
            self.session = session
            self.roomId = roomId

            var state: [String: [String:StrippedStateEvent]] = [:]
            
            for event in stateEvents {
                var dict = state[event.type] ?? [:]
                dict[event.stateKey] = event
                state[event.type] = dict
            }
            self.state = state
            
            guard let event = state[M_ROOM_CREATE]?[""],
                  let content = event.content as? RoomCreateContent
            else {
                throw Matrix.Error("No creation event for room \(roomId)")
            }
            self.creator = event.sender
            
            self.avatar = nil
        }
        
        // MARK: Computed properties
        
        public var type: String? {
            guard let event = state[M_ROOM_CREATE]?[""],
                  let content = event.content as? RoomCreateContent
            else {
                return nil
            }
            return content.type
        }
        
        public var version: String {
            guard let event = state[M_ROOM_CREATE]?[""],
                  let content = event.content as? RoomCreateContent
            else {
                return "1"
            }
            return content.roomVersion ?? "1"
        }
        
        public var predecessorRoomId: RoomId? {
            guard let event = state[M_ROOM_CREATE]?[""],
                  let content = event.content as? RoomCreateContent
            else {
                return nil
            }
            return content.predecessor?.roomId
        }
        
        public var encrypted: Bool {
            guard let event = state[M_ROOM_ENCRYPTION]?[""],
                  let content = event.content as? RoomEncryptionContent
            else {
                return false
            }
            return true
        }

        public var name: String? {
            guard let event = state[M_ROOM_NAME]?[""],
                  let content = event.content as? RoomNameContent
            else {
                return nil
            }
            return content.name
        }
        
        public var topic: String? {
            guard let event = state[M_ROOM_TOPIC]?[""],
                  let content = event.content as? RoomTopicContent
            else {
                return nil
            }
            return content.topic
        }
        
        public var avatarUrl: MXC? {
            guard let event = state[M_ROOM_AVATAR]?[""],
                  let content = event.content as? RoomAvatarContent
            else {
                return nil
            }
            return content.url
        }
        
        public var blurhash: String? {
            guard let event = state[M_ROOM_AVATAR]?[""],
                  let content = event.content as? RoomAvatarContent
            else {
                return nil
            }
            return content.info.blurhash
        }
        
        public var thumbhash: String? {
            guard let event = state[M_ROOM_AVATAR]?[""],
                  let content = event.content as? RoomAvatarContent
            else {
                return nil
            }
            return content.info.thumbhash
        }
        
        public var members: [UserId] {
            guard let events = state[M_ROOM_MEMBER]?.values.filter( { event in
                guard let content = event.content as? RoomMemberContent
                else { return false }
                return content.membership == .join
            })
            else {
                return []
            }
            
            return events.compactMap { event -> UserId? in
                guard let userId = UserId(event.stateKey)
                else { return nil }
                return userId
            }
        }

        // MARK: Join
        
        public func join(reason: String? = nil) async throws {
            try await session.join(roomId: roomId, reason: reason)
        }

        // MARK: Get avatar image
        
        public func getAvatarImage() async throws {
            guard let mxc = self.avatarUrl else {
                return
            }
            
            let data = try await session.downloadData(mxc: mxc)
            let image = NativeImage(data: data)
            
            await MainActor.run {
                self.avatar = image
            }
        }
        
        // Set our avatar image from the thumbhash or blurhash, depending on what we have available.
        // For use while loading the real image from the server.
        func useBlurryPlaceholder() async {
            if let thumbhash = self.thumbhash,
               let thumbhashData = Data(base64Encoded: thumbhash)
            {
                let image = thumbHashToImage(hash: thumbhashData)
                await MainActor.run {
                    logger.debug("Room \(self.roomId) using thumbhash while loading")
                    self.avatar = image
                }
            } else if let blurhash = self.blurhash {
                
                if let event = self.state[M_ROOM_AVATAR]?[""],
                   let content = event.content as? RoomAvatarContent,
                   let image = NativeImage(blurHash: blurhash,
                                           size: CGSize(width: content.info.w,
                                                        height: content.info.h))
                {
                    await MainActor.run {
                        logger.debug("Room \(self.roomId) using blurhash while loading")
                        self.avatar = image
                    }
                }

            }
        }
        
        public func updateAvatarImage() {
            if let mxc = self.avatarUrl
            {
                logger.debug("Room \(self.roomId) fetching avatar for from \(mxc)")

                self.fetchAvatarImageTask = self.fetchAvatarImageTask ?? .init(priority: .background, operation: {
                    logger.debug("Room \(self.roomId) starting a new fetch task")
                    
                    // First, while we're loading the new image, set a place holder if we have one
                    await self.useBlurryPlaceholder()
                    
                    // Now that we have things looking OK locally for now, we can actually load the real image
                    let startTime = Date()
                    guard let data = try? await self.session.downloadData(mxc: mxc)
                    else {
                        logger.error("Room \(self.roomId) failed to download avatar from \(mxc)")
                        self.fetchAvatarImageTask = nil
                        return
                    }
                    let endTime = Date()
                    let latencyMS = endTime.timeIntervalSince(startTime) * 1000
                    let sizeKB = Double(data.count) / 1024.0
                    logger.debug("Room \(self.roomId.opaqueId) fetched \(sizeKB) KB of avatar image data from \(mxc.mediaId) in \(latencyMS) ms")
                    let newAvatar = Matrix.NativeImage(data: data)
                    logger.debug("Room \(self.roomId) setting new avatar from \(mxc)")
                    await MainActor.run {
                        print("Room \(self.roomId) updating avatar NOW")
                        self.avatar = newAvatar
                    }
                    
                    self.fetchAvatarImageTask = nil
                    logger.debug("Room \(self.roomId) done fetching avatar image")
                })
                
            } else {
                logger.debug("Can't fetch avatar for room \(self.roomId) because we have no avatar_url")
            }
        }
    }

}

extension Matrix.StrippedStateRoom: Identifiable {
    public var id: String {
        "\(self.roomId)"
    }
}
