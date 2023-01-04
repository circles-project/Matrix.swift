//
//  Matrix+Room.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation

extension Matrix {
    class Room: ObservableObject {
        let roomId: RoomId
        let session: Session
        
        let type: String?
        let version: String
        
        @Published var name: String?
        @Published var topic: String?
        @Published var avatarUrl: MXC?
        @Published var avatar: NativeImage?
        
        let predecessorRoomId: RoomId?
        let successorRoomId: RoomId?
        let tombstoneEventId: EventId?
        
        @Published var messages: Set<ClientEventWithoutRoomId>
        @Published var localEchoEvent: Event?
        //@Published var earliestMessage: MatrixMessage?
        //@Published var latestMessage: MatrixMessage?
        private var stateEventsCache: [EventType: [ClientEventWithoutRoomId]]
        
        @Published var highlightCount: Int = 0
        @Published var notificationCount: Int = 0
        
        @Published var joinedMembers: Set<UserId> = []
        @Published var invitedMembers: Set<UserId> = []
        @Published var leftMembers: Set<UserId> = []
        @Published var bannedMembers: Set<UserId> = []
        @Published var knockingMembers: Set<UserId> = []

        @Published var encryptionParams: RoomEncryptionContent?
        
        init(roomId: RoomId, session: Session, initialState: [ClientEventWithoutRoomId], initialMessages: [ClientEventWithoutRoomId] = []) throws {
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
        
        func updateState(from events: [ClientEventWithoutRoomId]) {
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
        
        func setDisplayName(newName: String) async throws {
            try await self.session.setDisplayName(roomId: self.roomId, name: newName)
        }
        
        func setAvatarImage(image: NativeImage) async throws {
            try await self.session.setAvatarImage(roomId: self.roomId, image: image)
        }
        
        func setTopic(newTopic: String) async throws {
            try await self.session.setTopic(roomId: self.roomId, topic: newTopic)
        }
        
        func invite(userId: UserId, reason: String? = nil) async throws {
            try await self.session.inviteUser(roomId: self.roomId, userId: userId, reason: reason)
        }
        
        func kick(userId: UserId, reason: String? = nil) async throws {
            try await self.session.kickUser(roomId: self.roomId, userId: userId, reason: reason)
        }
        
        func ban(userId: UserId, reason: String? = nil) async throws {
            try await self.session.banUser(roomId: self.roomId, userId: userId, reason: reason)
        }
        
        func leave(reason: String? = nil) async throws {
            try await self.session.leave(roomId: self.roomId, reason: reason)
        }
        
        func canPaginate() -> Bool {
            // FIXME: TODO:
            return false
        }
        
        func paginate(count: UInt = 25) async throws {
            throw Matrix.Error("Not implemented")
        }
        
        var isEncrypted: Bool {
            self.encryptionParams != nil
        }
        
        func sendText(text: String) async throws -> EventId {
            if !self.isEncrypted {
                let content = mTextContent(msgtype: .text, body: text)
                return try await self.session.sendMessageEvent(to: self.roomId, type: .mRoomMessage, content: content)
            }
            else {
                throw Matrix.Error("Not implemented")
            }
        }
        
        func sendImage(image: NativeImage) async throws -> EventId {
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
        
        func sendVideo(fileUrl: URL, thumbnail: NativeImage?) async throws -> EventId {
            throw Matrix.Error("Not implemented")
        }
        
        func sendReply(to eventId: EventId, text: String) async throws -> EventId {
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
        
        func redact(eventId: EventId, reason: String?) async throws -> EventId {
            try await self.session.sendRedactionEvent(to: self.roomId, for: eventId, reason: reason)
        }
        
        func report(eventId: EventId, score: Int, reason: String?) async throws {
            try await self.session.sendReport(for: eventId, in: self.roomId, score: score, reason: reason)
        }
        
        func sendReaction(_ reaction: String, to eventId: EventId) async throws -> EventId {
            // FIXME: What about encryption?
            let content = ReactionContent(eventId: eventId, reaction: reaction)
            return try await self.session.sendMessageEvent(to: self.roomId, type: .mReaction, content: content)
        }
    }
}
