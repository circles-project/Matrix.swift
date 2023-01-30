//
//  Matrix+Room.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation

extension Matrix {
    public class Room: ObservableObject, Codable, Storable {
        public typealias StorableKey = RoomId
        
        public let roomId: RoomId
        public var session: Session
        
        public var type: String?
        public var version: String
        
        @Published public var name: String?
        @Published public var topic: String?
        @Published public var avatarUrl: MXC?
        @Published public var avatar: NativeImage?
        
        public let predecessorRoomId: RoomId?
        public let successorRoomId: RoomId?
        public let tombstoneEventId: EventId?
        
        @Published public var messages: Set<ClientEventWithoutRoomId>
        @Published public var localEchoEvent: Event?
        //@Published var earliestMessage: MatrixMessage?
        //@Published var latestMessage: MatrixMessage?
        private var stateEventsCache: [EventType: [ClientEventWithoutRoomId]]
        
        @Published public var highlightCount: Int = 0
        @Published public var notificationCount: Int = 0
        
        @Published public var joinedMembers: Set<UserId> = []
        @Published public var invitedMembers: Set<UserId> = []
        @Published public var leftMembers: Set<UserId> = []
        @Published public var bannedMembers: Set<UserId> = []
        @Published public var knockingMembers: Set<UserId> = []

        @Published public var encryptionParams: RoomEncryptionContent?
        
        public enum CodingKeys: String, CodingKey {
            case roomId
            case session
            case type
            case version
            case name
            case topic
            case avatarUrl
            case avatar
            case predecessorRoomId
            case successorRoomId
            case tombstoneEventId
            case messages
            case localEchoEvent
            case stateEventsCache
            case highlightCount
            case notificationCount
            case joinedMembers
            case invitedMembers
            case leftMembers
            case bannedMembers
            case knockingMembers
            case encryptionParams
        }
        
        public init(roomId: RoomId, session: Session, initialState: [ClientEventWithoutRoomId], initialMessages: [ClientEventWithoutRoomId] = []) throws {
            self.roomId = roomId
            self.session = session
            self.messages = Set(initialMessages)
            
            self.stateEventsCache = [:]
            for event in initialState {
                var cache = stateEventsCache[event.type] ?? []
                cache.append(event)
                stateEventsCache[event.type] = cache
            }
            
            guard let creationEvent = stateEventsCache[.mRoomCreate]?.first,
                  let creationContent = creationEvent.content as? RoomCreateContent
            else {
                throw Matrix.Error("No m.room.create event")
            }
            self.type = creationContent.type
            self.version = creationContent.roomVersion ?? "1"
            self.predecessorRoomId = creationContent.predecessor?.roomId
            
            if let tombstoneEvent = stateEventsCache[.mRoomTombstone]?.last,
               let tombstoneContent = tombstoneEvent.content as? RoomTombstoneContent
            {
                self.tombstoneEventId = tombstoneEvent.eventId
                self.successorRoomId = tombstoneContent.replacementRoom
            } else {
                self.tombstoneEventId = nil
                self.successorRoomId = nil
            }
            
            if let nameEvent = stateEventsCache[.mRoomName]?.last,
               let nameContent = nameEvent.content as? RoomNameContent
            {
                self.name = nameContent.name
            }
            
            if let avatarEvent = stateEventsCache[.mRoomAvatar]?.last,
               let avatarContent = avatarEvent.content as? RoomAvatarContent
            {
                self.avatarUrl = avatarContent.mxc
            }
            
            if let topicEvent = stateEventsCache[.mRoomTopic]?.last,
               let topicContent = topicEvent.content as? RoomTopicContent
            {
                self.topic = topicContent.topic
            }
            
            for memberEvent in stateEventsCache[.mRoomMember] ?? [] {
                if let memberContent = memberEvent.content as? RoomMemberContent,
                   let stateKey = memberEvent.stateKey,
                   let memberUserId = UserId(stateKey)
                {
                    switch memberContent.membership {
                    case .join:
                        joinedMembers.insert(memberUserId)
                    case .invite:
                        invitedMembers.insert(memberUserId)
                    case .ban:
                        bannedMembers.insert(memberUserId)
                    case .knock:
                        knockingMembers.insert(memberUserId)
                    case .leave:
                        leftMembers.insert(memberUserId)
                    }
                }
            }
            
            let powerLevelsEvents = stateEventsCache[.mRoomPowerLevels] ?? []
            for powerLevelsEvent in powerLevelsEvents {
                guard powerLevelsEvent.content is RoomPowerLevelsContent
                else {
                    throw Matrix.Error("Couldn't parse room power levels")
                }
            }
            // Do we need to *do* anything with the powerlevels for now?
            // No?
            
            if let encryptionEvent = stateEventsCache[.mRoomEncryption]?.last,
               let encryptionContent = encryptionEvent.content as? RoomEncryptionContent
            {
                self.encryptionParams = encryptionContent
            } else {
                self.encryptionParams = nil
            }
            
        }
        
        // Successfuly decoding of the object requires that a session instance and messages
        // are stored in the decoder's `userInfo` dictionary
        public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            if let sessionKey = CodingUserInfoKey(rawValue: CodingKeys.session.stringValue),
               let unwrappedSession = decoder.userInfo[sessionKey] as? Session {
                self.session = unwrappedSession
            }
            else {
                throw Matrix.Error("Error initializing session field")
            }
            self.stateEventsCache = [:]
            
            self.roomId = try container.decode(RoomId.self, forKey: .roomId)
            self.type = try container.decodeIfPresent(String.self, forKey: .type)
            self.version = try container.decode(String.self, forKey: .version)
            self.name = try container.decodeIfPresent(String.self, forKey: .name)
            self.topic = try container.decodeIfPresent(String.self, forKey: .topic)
            self.avatarUrl = try container.decodeIfPresent(MXC.self, forKey: .avatarUrl)
            self.avatar = try container.decodeIfPresent(NativeImage.self, forKey: .avatar)
            self.predecessorRoomId = try container.decodeIfPresent(RoomId.self, forKey: .predecessorRoomId)
            self.successorRoomId = try container.decodeIfPresent(RoomId.self, forKey: .successorRoomId)
            self.tombstoneEventId = try container.decodeIfPresent(EventId.self, forKey: .tombstoneEventId)
            
            // Messages are encoded as references to ClientEvent objects in a DataStore
            if let messagesKey = CodingUserInfoKey(rawValue: CodingKeys.messages.stringValue),
               let unwrappedMessages = decoder.userInfo[messagesKey] as? Set<ClientEventWithoutRoomId> {
                self.messages = unwrappedMessages
            }
            else {
                throw Matrix.Error("Error initializing messages field")
            }
            
            if let clientEvent = try container.decodeIfPresent(ClientEvent.self, forKey: .localEchoEvent) {
                self.localEchoEvent = clientEvent
            }
            else if let clientEventWithoutRoomId = try container.decodeIfPresent(ClientEventWithoutRoomId.self,
                                                                                 forKey: .localEchoEvent) {
                self.localEchoEvent = clientEventWithoutRoomId
            }
            else if let minimalEvent = try container.decodeIfPresent(MinimalEvent.self,
                                                                     forKey: .localEchoEvent) {
                self.localEchoEvent = minimalEvent
            }
            else if let strippedStateEvent = try container.decodeIfPresent(StrippedStateEvent.self,
                                                                           forKey: .localEchoEvent) {
                self.localEchoEvent = strippedStateEvent
            }
            else if let toDeviceEvent = try container.decodeIfPresent(ToDeviceEvent.self,
                                                                      forKey: .localEchoEvent) {
                self.localEchoEvent = toDeviceEvent
            }
            else {
                self.localEchoEvent = nil
            }
            
            self.highlightCount = try container.decode(Int.self, forKey: .highlightCount)
            self.notificationCount = try container.decode(Int.self, forKey: .notificationCount)
            self.joinedMembers = try container.decode(Set<UserId>.self, forKey: .joinedMembers)
            self.invitedMembers = try container.decode(Set<UserId>.self, forKey: .invitedMembers)
            self.leftMembers = try container.decode(Set<UserId>.self, forKey: .leftMembers)
            self.bannedMembers = try container.decode(Set<UserId>.self, forKey: .bannedMembers)
            self.knockingMembers = try container.decode(Set<UserId>.self, forKey: .knockingMembers)
            self.encryptionParams = try container.decodeIfPresent(RoomEncryptionContent.self,
                                                                  forKey: .encryptionParams)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(roomId, forKey: .roomId)
            // session not being encoded
            try container.encode(type, forKey: .type)
            try container.encode(version, forKey: .version)
            try container.encode(name, forKey: .name)
            try container.encode(topic, forKey: .topic)
            try container.encode(avatarUrl, forKey: .avatarUrl)
            try container.encode(avatar, forKey: .avatar)
            try container.encode(predecessorRoomId, forKey: .predecessorRoomId)
            try container.encode(successorRoomId, forKey: .successorRoomId)
            try container.encode(tombstoneEventId, forKey: .tombstoneEventId)
            
            // Messages are encoded as references to ClientEvent objects in a DataStore
            var eventIds: [EventId] = []
            for msg in self.messages {
                eventIds.append(msg.eventId)
            }
            try container.encode(eventIds, forKey: .messages)
            
            if let unwrapedLocalEchoEvent = localEchoEvent {
                try container.encode(unwrapedLocalEchoEvent, forKey: .localEchoEvent)
            }
            // stateEventsCache not being encoded
            try container.encode(highlightCount, forKey: .highlightCount)
            try container.encode(notificationCount, forKey: .notificationCount)
            try container.encode(joinedMembers, forKey: .joinedMembers)
            try container.encode(invitedMembers, forKey: .invitedMembers)
            try container.encode(leftMembers, forKey: .leftMembers)
            try container.encode(bannedMembers, forKey: .bannedMembers)
            try container.encode(knockingMembers, forKey: .knockingMembers)
            try container.encode(encryptionParams, forKey: .encryptionParams)
        }
                
        public func updateState(from events: [ClientEventWithoutRoomId]) {
            for event in events {
                
                switch event.type {
                
                case .mRoomAvatar:
                    guard let content = event.content as? RoomAvatarContent
                    else {
                        continue
                    }
                    if self.avatarUrl != content.mxc {
                        self.avatarUrl = content.mxc
                        // FIXME: Also fetch the new avatar image
                    }
                    
                case .mRoomName:
                    guard let content = event.content as? RoomNameContent
                    else {
                        continue
                    }
                    self.name = content.name
                    
                case .mRoomTopic:
                    guard let content = event.content as? RoomTopicContent
                    else {
                        continue
                    }
                    self.topic = content.topic
                    
                case .mRoomMember:
                    guard let content = event.content as? RoomMemberContent,
                          let stateKey = event.stateKey,
                          let userId = UserId(stateKey)
                    else {
                        continue
                    }
                    switch content.membership {
                    case .invite:
                        self.invitedMembers.insert(userId)
                        self.leftMembers.remove(userId)
                        self.bannedMembers.remove(userId)
                    case .join:
                        self.joinedMembers.insert(userId)
                        self.invitedMembers.remove(userId)
                        self.knockingMembers.remove(userId)
                        self.leftMembers.remove(userId)
                        self.bannedMembers.remove(userId)
                    case .knock:
                        self.knockingMembers.insert(userId)
                        self.leftMembers.remove(userId)
                        self.bannedMembers.remove(userId)
                    case .leave:
                        self.leftMembers.insert(userId)
                        self.invitedMembers.remove(userId)
                        self.knockingMembers.remove(userId)
                        self.joinedMembers.remove(userId)
                        self.bannedMembers.remove(userId)
                    case .ban:
                        self.bannedMembers.insert(userId)
                        self.invitedMembers.remove(userId)
                        self.knockingMembers.remove(userId)
                        self.joinedMembers.remove(userId)
                        self.leftMembers.remove(userId)
                    } // end switch content.membership
                    
                case .mRoomEncryption:
                    guard let content = event.content as? RoomEncryptionContent
                    else {
                        continue
                    }
                    self.encryptionParams = content
                    
                default:
                    print("Not handling event of type \(event.type)")
                    
                } // end switch event.type
                
            } // end func updateState()
        }
        
        public func setDisplayName(newName: String) async throws {
            try await self.session.setDisplayName(roomId: self.roomId, name: newName)
        }
        
        public func setAvatarImage(image: NativeImage) async throws {
            try await self.session.setAvatarImage(roomId: self.roomId, image: image)
        }
        
        public func setTopic(newTopic: String) async throws {
            try await self.session.setTopic(roomId: self.roomId, topic: newTopic)
        }
        
        public func invite(userId: UserId, reason: String? = nil) async throws {
            try await self.session.inviteUser(roomId: self.roomId, userId: userId, reason: reason)
        }
        
        public func kick(userId: UserId, reason: String? = nil) async throws {
            try await self.session.kickUser(roomId: self.roomId, userId: userId, reason: reason)
        }
        
        public func ban(userId: UserId, reason: String? = nil) async throws {
            try await self.session.banUser(roomId: self.roomId, userId: userId, reason: reason)
        }
        
        public func leave(reason: String? = nil) async throws {
            try await self.session.leave(roomId: self.roomId, reason: reason)
        }
        
        public func canPaginate() -> Bool {
            // FIXME: TODO:
            return false
        }
        
        public func paginate(count: UInt = 25) async throws {
            throw Matrix.Error("Not implemented")
        }
        
        public var isEncrypted: Bool {
            self.encryptionParams != nil
        }
        
        public func sendText(text: String) async throws -> EventId {
            if !self.isEncrypted {
                let content = mTextContent(msgtype: .text, body: text)
                return try await self.session.sendMessageEvent(to: self.roomId, type: .mRoomMessage, content: content)
            }
            else {
                throw Matrix.Error("Not implemented")
            }
        }
        
        public func sendImage(image: NativeImage) async throws -> EventId {
            if !self.isEncrypted {
                guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
                    throw Matrix.Error("Couldn't create JPEG for image")
                }
                let mxc = try await self.session.uploadData(data: jpegData, contentType: "image/jpeg")
                let info = mImageInfo(h: Int(image.size.height),
                                      w: Int(image.size.width),
                                      mimetype: "image/jpeg",
                                      size: jpegData.count)
                let content = mImageContent(msgtype: .image, body: "\(mxc.mediaId).jpeg", info: info)
                return try await self.session.sendMessageEvent(to: self.roomId, type: .mRoomMessage, content: content)
            }
            else {
                throw Matrix.Error("Not implemented")
            }
        }
        
        public func sendVideo(fileUrl: URL, thumbnail: NativeImage?) async throws -> EventId {
            throw Matrix.Error("Not implemented")
        }
        
        public func sendReply(to eventId: EventId, text: String) async throws -> EventId {
            if !self.isEncrypted {
                let content = mTextContent(msgtype: .text,
                                           body: text,
                                           relates_to: mRelatesTo(in_reply_to: .init(event_id: eventId)))
                return try await self.session.sendMessageEvent(to: self.roomId, type: .mRoomMessage, content: content)
            }
            else {
                throw Matrix.Error("Not implemented")
            }
        }
        
        public func redact(eventId: EventId, reason: String?) async throws -> EventId {
            try await self.session.sendRedactionEvent(to: self.roomId, for: eventId, reason: reason)
        }
        
        public func report(eventId: EventId, score: Int, reason: String?) async throws {
            try await self.session.sendReport(for: eventId, in: self.roomId, score: score, reason: reason)
        }
        
        public func sendReaction(_ reaction: String, to eventId: EventId) async throws -> EventId {
            // FIXME: What about encryption?
            let content = ReactionContent(eventId: eventId, reaction: reaction)
            return try await self.session.sendMessageEvent(to: self.roomId, type: .mReaction, content: content)
        }
    }
}
