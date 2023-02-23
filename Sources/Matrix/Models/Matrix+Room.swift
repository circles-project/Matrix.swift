//
//  Matrix+Room.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation

extension Matrix {
    public class Room: ObservableObject {
        public let roomId: RoomId
        public let session: Session
        private var dataStore: DataStore?
        
        public let type: String?
        public let version: String
        
        @Published public var name: String?
        @Published public var topic: String?
        @Published public var avatarUrl: MXC?
        @Published public var avatar: NativeImage?
        
        public let predecessorRoomId: RoomId?
        public let successorRoomId: RoomId?
        public let tombstoneEventId: EventId?
        
        @Published public var timeline: Set<ClientEventWithoutRoomId>
        @Published public var localEchoEvent: Event?
        //@Published var earliestMessage: MatrixMessage?
        //@Published var latestMessage: MatrixMessage?
        private var state: [EventType: [String: ClientEventWithoutRoomId]]  // Tuples are not Hashable so we can't do [(EventType,String): ClientEventWithoutRoomId]
        
        @Published public var highlightCount: Int = 0
        @Published public var notificationCount: Int = 0
        
        @Published public var joinedMembers: Set<UserId> = []
        @Published public var invitedMembers: Set<UserId> = []
        @Published public var leftMembers: Set<UserId> = []
        @Published public var bannedMembers: Set<UserId> = []
        @Published public var knockingMembers: Set<UserId> = []

        @Published public var encryptionParams: RoomEncryptionContent?
        
        public init(roomId: RoomId, session: Session, initialState: [ClientEventWithoutRoomId], initialTimeline: [ClientEventWithoutRoomId] = []) throws {
            self.roomId = roomId
            self.session = session
            self.timeline = Set(initialTimeline)
            
            self.state = [:]
            
            // Ugh, sometimes all of our state is actually in the timeline.
            // This can happen especially for an initial sync when there are new rooms and very few messages.
            // See https://spec.matrix.org/v1.5/client-server-api/#syncing
            // > In the case of an initial (since-less) sync, the state list represents the complete state
            // > of the room at the start of the returned timeline (so in the case of a recently-created
            // > room whose state fits entirely in the timeline, the state list will be empty).
            let allInitialStateEvents = initialState + initialTimeline.filter { $0.stateKey != nil }
            
            for event in allInitialStateEvents {
                guard let stateKey = event.stateKey
                else {
                    continue
                }
                var d = self.state[event.type] ?? [:]
                d[stateKey] = event
                self.state[event.type] = d
            }
            
            guard let creationEvent = state[.mRoomCreate]?[""],
                  let creationContent = creationEvent.content as? RoomCreateContent
            else {
                throw Matrix.Error("No m.room.create event")
            }
            self.type = creationContent.type
            self.version = creationContent.roomVersion ?? "1"
            self.predecessorRoomId = creationContent.predecessor?.roomId
            
            if let tombstoneEvent = state[.mRoomTombstone]?[""],
               let tombstoneContent = tombstoneEvent.content as? RoomTombstoneContent
            {
                self.tombstoneEventId = tombstoneEvent.eventId
                self.successorRoomId = tombstoneContent.replacementRoom
            } else {
                self.tombstoneEventId = nil
                self.successorRoomId = nil
            }
            
            if let nameEvent = state[.mRoomName]?[""],
               let nameContent = nameEvent.content as? RoomNameContent
            {
                self.name = nameContent.name
            }
            
            if let avatarEvent = state[.mRoomAvatar]?[""],
               let avatarContent = avatarEvent.content as? RoomAvatarContent
            {
                self.avatarUrl = avatarContent.mxc
            }
            
            if let topicEvent = state[.mRoomTopic]?[""],
               let topicContent = topicEvent.content as? RoomTopicContent
            {
                self.topic = topicContent.topic
            }
            
            for (memberKey, memberEvent) in state[.mRoomMember] ?? [:] {
                guard memberKey == memberEvent.stateKey,                           // Sanity check
                      let memberContent = memberEvent.content as? RoomMemberContent,
                      let memberUserId = UserId(memberKey)
                else {
                    // continue
                    throw Matrix.Error("Error processing \(EventType.mRoomMember) event for user \(memberKey)")
                }
                
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
            
            for (powerLevelsKey, powerLevelsEvent) in state[.mRoomPowerLevels] ?? [:]  {
                guard powerLevelsEvent.content is RoomPowerLevelsContent
                else {
                    throw Matrix.Error("Couldn't parse \(EventType.mRoomPowerLevels) event for key \(powerLevelsKey)")
                }
                // Do we need to *do* anything with the powerlevels for now?
                // No?
            }

            if let encryptionEvent = state[.mRoomEncryption]?[""],
               let encryptionContent = encryptionEvent.content as? RoomEncryptionContent
            {
                self.encryptionParams = encryptionContent
            } else {
                self.encryptionParams = nil
            }
            
            // Swift Phase 1 initialization complete
            // See https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/#Two-Phase-Initialization
            // Now we can call instance functions
        }
        
        public func updateTimeline(from events: [ClientEventWithoutRoomId]) async throws {
            for event in events {
                // Is this a state event?
                if event.stateKey != nil {
                    // If so, update our local state
                    try await updateState(from: event)
                }
                // And regardless, add the event to our timeline
                await MainActor.run {
                    self.timeline.insert(event)
                }
            }
        }
        
        public func updateState(from events: [ClientEventWithoutRoomId]) async throws {
            for event in events {
                try await updateState(from: event)
            }
        }
        
        public func updateState(from event: ClientEventWithoutRoomId) async throws {
            guard let stateKey = event.stateKey
            else {
                let msg = "No state key for \"state\" event of type \(event.type)"
                print("updateState:\t\(msg)")
                throw Matrix.Error(msg)
                //continue
            }
            
            var needToSave: Bool = false
            
            switch event.type {
            
            case .mRoomAvatar:
                guard let content = event.content as? RoomAvatarContent
                else {
                    return
                }
                if self.avatarUrl != content.mxc {
                    await MainActor.run {
                        self.avatarUrl = content.mxc
                    }
                    needToSave = true
                    // FIXME: Also fetch the new avatar image
                }
                
            case .mRoomName:
                guard let content = event.content as? RoomNameContent
                else {
                    return
                }
                needToSave = true
                await MainActor.run {
                    self.name = content.name
                }
                
            case .mRoomTopic:
                guard let content = event.content as? RoomTopicContent
                else {
                    return
                }
                needToSave = true
                await MainActor.run {
                    self.topic = content.topic
                }
                
            case .mRoomMember:
                guard let content = event.content as? RoomMemberContent,
                      let stateKey = event.stateKey,
                      let userId = UserId(stateKey)
                else {
                    return
                }
                await MainActor.run {
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
                }
                
            case .mRoomEncryption:
                guard let content = event.content as? RoomEncryptionContent
                else {
                    return
                }
                needToSave = true
                await MainActor.run {
                    self.encryptionParams = content
                }
                
            default:
                print("Not handling event of type \(event.type)")
                
            } // end switch event.type
            
            // Finally, update our local copy of the state to include this event
            var d = self.state[event.type] ?? [:]
            d[stateKey] = event
            self.state[event.type] = d
            
            // Do we need to save the room to local storage?
            if needToSave {
                // FIXME: TODO: Actually save the room to the DataStore
            }
            
        } // end func updateState()
        
        public func getState(type: Matrix.EventType, stateKey: String) async throws -> Codable? {
            if let event = self.state[type]?[stateKey] {
                return event.content
            }
            return try await session.getRoomState(roomId: roomId, for: type, with: stateKey)
        }
        
        // The minimal list of state events required to reconstitute the room into a useful state
        // e.g. for displaying the user's room list
        public var minimalState: [ClientEventWithoutRoomId] {
            return [
                state[.mRoomCreate]![""]!,                            // Room creation
                state[.mRoomEncryption]?[""],                         // Encryption settings
                //state[.mRoomHistoryVisibility]?[""],                  // History visibility
                state[.mRoomMember]?["\(session.creds.userId)"],      // My membership in the room
                state[.mRoomPowerLevels]?["\(session.creds.userId)"], // My power level in the room
                state[.mRoomName]?[""],
                state[.mRoomAvatar]?[""],
                state[.mRoomTopic]?[""],
                state[.mRoomTombstone]?[""],
            ]
            .compactMap{ $0 }
        }
        
        public var creator: UserId {
            state[.mRoomCreate]![""]!.sender
        }
        
        public var lastMessage: ClientEventWithoutRoomId? {
            timeline
                .filter {
                    $0.stateKey == nil
                }
                .sorted {
                    $0.originServerTS < $1.originServerTS
                }
                .last
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
