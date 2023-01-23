//
//  Matrix+InvitedRoom.swift
//  
//
//  Created by Charles Wright on 12/6/22.
//

import Foundation

extension Matrix {
    public class InvitedRoom: ObservableObject, Codable, Storable {
        public typealias StorableObject = InvitedRoom
        public typealias StorableKey = RoomId
        
        public var session: Session
        
        public let roomId: RoomId
        public let type: String?
        public let version: String
        public let predecessorRoomId: RoomId?
        
        public let encrypted: Bool
        
        public let creator: UserId
        public let sender: UserId
        
        public let name: String?
        public let topic: String?
        public let avatarUrl: MXC?
        @Published public var avatar: NativeImage?
        
        public var members: [UserId]
        
        private var stateEventsCache: [EventType: [StrippedStateEvent]]  // From /sync
        
        public enum CodingKeys: String, CodingKey {
            // session not being encoded
            case roomId
            case type
            case version
            case predecessorRoomId
            case encrypted
            case creator
            case sender
            case name
            case topic
            case avatarUrl
            case avatar
            case members
            // stateEventsCache not being encoded
        }
        
        public init(session: Session, roomId: RoomId, stateEvents: [StrippedStateEvent]) throws {
            
            self.session = session
            self.roomId = roomId
            
            self.stateEventsCache = [:]
            
            for event in stateEvents {
                var cache = stateEventsCache[event.type] ?? []
                cache.append(event)
                stateEventsCache[event.type] = cache
            }
            
            guard let createEvent = stateEventsCache[.mRoomCreate]?.first,
                  let createContent = createEvent.content as? RoomCreateContent
            else {
                throw Matrix.Error("No creation event for invited room")
            }
            self.type = createContent.type
            self.version = createContent.roomVersion ?? "1"
            self.creator = createEvent.sender
            self.predecessorRoomId = createContent.predecessor?.roomId
            
            // Need to parse the room member events to see who invited us
            guard let myInviteEvent = stateEventsCache[.mRoomMember]?
                .filter(
                    {
                        guard let content = $0.content as? RoomMemberContent else {
                            return false
                        }
                        if content.membership == .invite && $0.stateKey == "\(session.creds.userId)" {
                            return true
                        } else {
                            return false
                        }
                    }
                ).last
            else {
                throw Matrix.Error("No invite event in invited room")
            }
            self.sender = myInviteEvent.sender
            
            if let roomNameEvent = stateEventsCache[.mRoomName]?.last,
               let roomNameContent = roomNameEvent.content as? RoomNameContent
            {
                self.name = roomNameContent.name
            } else {
                self.name = nil
            }
            
            if let roomAvatarEvent = stateEventsCache[.mRoomAvatar]?.last,
               let roomAvatarContent = roomAvatarEvent.content as? RoomAvatarContent
            {
                self.avatarUrl = roomAvatarContent.mxc
            } else {
                self.avatarUrl = nil
            }
            
            if let roomTopicEvent = stateEventsCache[.mRoomTopic]?.last,
               let roomTopicContent = roomTopicEvent.content as? RoomTopicContent
            {
                self.topic = roomTopicContent.topic
            } else {
                self.topic = nil
            }
            
            if let roomMemberEvents = stateEventsCache[.mRoomMember]
            {
                // For each room member event,
                // - Check whether the member is in the 'join' state
                // - If so, return their UserId as part of the list
                self.members = roomMemberEvents.compactMap { event in
                    guard let content = event.content as? RoomMemberContent
                    else {
                        return nil
                    }
                    if content.membership == .join {
                        return UserId(event.stateKey)
                    } else {
                        return nil
                    }
                }
            } else {
                self.members = []
            }
            
            if let encryptionEvent = stateEventsCache[.mRoomEncryption]?.first,
               let encryptionContent = encryptionEvent.content as? RoomEncryptionContent
            {
                self.encrypted = true
            } else {
                self.encrypted = false
            }
            
        }
        
        public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.roomId = try container.decode(RoomId.self, forKey: .roomId)
            self.type = try container.decode(String.self, forKey: .type)
            self.version = try container.decode(String.self, forKey: .version)
            self.predecessorRoomId = try container.decode(RoomId.self, forKey: .predecessorRoomId)
            self.encrypted = try container.decode(Bool.self, forKey: .encrypted)
            self.creator = try container.decode(UserId.self, forKey: .creator)
            self.sender = try container.decode(UserId.self, forKey: .sender)
            self.name = try container.decode(String.self, forKey: .name)
            self.topic = try container.decode(String.self, forKey: .topic)
            self.avatarUrl = try container.decode(MXC.self, forKey: .avatarUrl)
            self.avatar = try container.decode(NativeImage.self, forKey: .avatar)
            self.members = try container.decode([UserId].self, forKey: .members)
            
            // FIXME: do proper class initalization and decoding
            self.session = try Matrix.Session(creds: Matrix.Credentials(userId: UserId("TODO")!, deviceId: "TODO", accessToken: "TODO"))
            self.stateEventsCache = [:]
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(roomId, forKey: .roomId)
            try container.encode(type, forKey: .type)
            try container.encode(version, forKey: .version)
            try container.encode(predecessorRoomId, forKey: .predecessorRoomId)
            try container.encode(encrypted, forKey: .encrypted)
            try container.encode(creator, forKey: .creator)
            try container.encode(sender, forKey: .sender)
            try container.encode(name, forKey: .name)
            try container.encode(topic, forKey: .topic)
            try container.encode(avatarUrl, forKey: .avatarUrl)
            try container.encode(avatar, forKey: .avatar)
            try container.encode(members, forKey: .members)
        }
        
        public func join(reason: String? = nil) async throws {
            try await session.join(roomId: roomId, reason: reason)
        }
        
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
    }

}
