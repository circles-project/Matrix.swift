//
//  Matrix+Room.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation
//import Collections // Maybe one day we will get a SortedSet implementation for Swift...


extension Matrix {
    public class Room: ObservableObject {
        public typealias HistoryVisibility = RoomHistoryVisibilityContent.HistoryVisibility

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
        
        @Published public var timeline: [ClientEventWithoutRoomId]
        @Published public var localEchoEvent: Event?
        //@Published var earliestMessage: MatrixMessage?
        //@Published var latestMessage: MatrixMessage?
        public var state: [String: [String: ClientEventWithoutRoomId]]  // Tuples are not Hashable so we can't do [(EventType,String): ClientEventWithoutRoomId]
        
        @Published public var highlightCount: Int = 0
        @Published public var notificationCount: Int = 0
        
        @Published public var joinedMembers: Set<UserId> = []
        @Published public var invitedMembers: Set<UserId> = []
        @Published public var leftMembers: Set<UserId> = []
        @Published public var bannedMembers: Set<UserId> = []
        @Published public var knockingMembers: Set<UserId> = []

        @Published public var encryptionParams: RoomEncryptionContent?
        
        private var backwardToken: String?
        private var forwardToken: String?
        
        public init(roomId: RoomId, session: Session, initialState: [ClientEventWithoutRoomId], initialTimeline: [ClientEventWithoutRoomId] = []) throws {
            self.roomId = roomId
            self.session = session
            self.timeline = initialTimeline
            
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
            
            guard let creationEvent = state[M_ROOM_CREATE]?[""],
                  let creationContent = creationEvent.content as? RoomCreateContent
            else {
                throw Matrix.Error("No m.room.create event")
            }
            self.type = creationContent.type
            self.version = creationContent.roomVersion ?? "1"
            self.predecessorRoomId = creationContent.predecessor?.roomId
            
            if let tombstoneEvent = state[M_ROOM_TOMBSTONE]?[""],
               let tombstoneContent = tombstoneEvent.content as? RoomTombstoneContent
            {
                self.tombstoneEventId = tombstoneEvent.eventId
                self.successorRoomId = tombstoneContent.replacementRoom
            } else {
                self.tombstoneEventId = nil
                self.successorRoomId = nil
            }
            
            if let nameEvent = state[M_ROOM_NAME]?[""],
               let nameContent = nameEvent.content as? RoomNameContent
            {
                self.name = nameContent.name
            }
            
            if let avatarEvent = state[M_ROOM_AVATAR]?[""],
               let avatarContent = avatarEvent.content as? RoomAvatarContent
            {
                self.avatarUrl = avatarContent.mxc
            }
            
            if let topicEvent = state[M_ROOM_TOPIC]?[""],
               let topicContent = topicEvent.content as? RoomTopicContent
            {
                self.topic = topicContent.topic
            }
            
            for (memberKey, memberEvent) in state[M_ROOM_MEMBER] ?? [:] {
                guard memberKey == memberEvent.stateKey,                           // Sanity check
                      let memberContent = memberEvent.content as? RoomMemberContent,
                      let memberUserId = UserId(memberKey)
                else {
                    // continue
                    throw Matrix.Error("Error processing \(M_ROOM_MEMBER) event for user \(memberKey)")
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
            
            for (powerLevelsKey, powerLevelsEvent) in state[M_ROOM_POWER_LEVELS] ?? [:]  {
                guard powerLevelsEvent.content is RoomPowerLevelsContent
                else {
                    throw Matrix.Error("Couldn't parse \(M_ROOM_POWER_LEVELS) event for key \(powerLevelsKey)")
                }
                // Do we need to *do* anything with the powerlevels for now?
                // No?
            }

            if let encryptionEvent = state[M_ROOM_ENCRYPTION]?[""],
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
                    updateState(from: event)
                }
            }
            // And regardless, add the events to our timeline
            await MainActor.run {
                self.timeline.append(contentsOf: events)
            }
        }
        
        public func updateState(from events: [ClientEventWithoutRoomId]) async {
            await MainActor.run {
                for event in events {
                    updateState(from: event)
                }
            }
        }
        
        public func updateState(from event: ClientEventWithoutRoomId) {
            guard let stateKey = event.stateKey
            else {
                let msg = "No state key for \"state\" event of type \(event.type)"
                print("updateState:\t\(msg)")
                //throw Matrix.Error(msg)
                //continue
                return
            }

            switch event.type {
            
            case M_ROOM_AVATAR:
                guard let content = event.content as? RoomAvatarContent
                else {
                    print("Room:\tFailed to parse \(M_ROOM_AVATAR) event \(event.eventId)")
                    return
                }
                //print("Room:\tSetting room avatar")
                if self.avatarUrl != content.mxc {
                    self.avatarUrl = content.mxc
                    // FIXME: Also fetch the new avatar image
                }
                    
                case M_ROOM_NAME:
                    guard let content = event.content as? RoomNameContent
                    else {
                        print("Room:\tFailed to parse \(M_ROOM_NAME) event \(event.eventId)")
                        return
                    }
                    //print("Room:\tSetting room name")
                    self.name = content.name
                    
                case M_ROOM_TOPIC:
                    guard let content = event.content as? RoomTopicContent
                    else {
                        print("\tRoom:\tFailed to parse \(M_ROOM_TOPIC) event \(event.eventId)")
                        return
                    }
                    //print("Room:\tSetting topic")
                    self.topic = content.topic
                    
                case M_ROOM_MEMBER:
                    guard let content = event.content as? RoomMemberContent,
                          let stateKey = event.stateKey,
                          let userId = UserId(stateKey)
                    else {
                        print("Room:\tFailed to parse \(M_ROOM_MEMBER) event \(event.eventId)")
                        return
                    }
                    print("Room:\tUpdating membership for user \(stateKey)")
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
                
            case M_ROOM_ENCRYPTION:
                guard let content = event.content as? RoomEncryptionContent
                else {
                    return
                }
                self.encryptionParams = content
                
            default:
                let msg = "Room:\tNot handling event of type \(event.type)"
                //print("\(msg)")
                
            } // end switch event.type
            
            // Finally, update our local copy of the state to include this event
            var d = self.state[event.type] ?? [:]
            d[stateKey] = event
            self.state[event.type] = d
        } // end func updateState()
        
        
        public func paginate(limit: UInt?=nil) async throws {
            let response = try await self.session.getMessages(roomId: roomId, forward: false, from: self.backwardToken, limit: limit)
            // The timeline messages are in the "chunk" piece of the response
            await MainActor.run {
                self.timeline = response.chunk + self.timeline
                self.backwardToken = response.end ?? self.backwardToken
            }
        }
        
        public func getState(type: String, stateKey: String) async throws -> Codable? {
            if let event = self.state[type]?[stateKey] {
                return event.content
            }
            return try await session.getRoomState(roomId: roomId, eventType: type, with: stateKey)
        }
        
        // The minimal list of state events required to reconstitute the room into a useful state
        // e.g. for displaying the user's room list
        public var minimalState: [ClientEventWithoutRoomId] {
            return [
                state[M_ROOM_CREATE]![""]!,                             // Room creation
                state[M_ROOM_ENCRYPTION]?[""],                          // Encryption settings
                //state[.mRoomHistoryVisibility]?[""],                  // History visibility
                state[M_ROOM_MEMBER]?["\(session.creds.userId)"],       // My membership in the room
                state[M_ROOM_POWER_LEVELS]?["\(session.creds.userId)"], // My power level in the room
                state[M_ROOM_NAME]?[""],
                state[M_ROOM_AVATAR]?[""],
                state[M_ROOM_TOPIC]?[""],
                state[M_ROOM_TOMBSTONE]?[""],
            ]
            .compactMap{ $0 }
        }
        
        public var creator: UserId {
            state[M_ROOM_CREATE]![""]!.sender
        }
        
        public func getHistoryVisibility() async throws -> HistoryVisibility? {
            let content = try await getState(type: M_ROOM_HISTORY_VISIBILITY, stateKey: "") as? RoomHistoryVisibilityContent
            return content?.historyVisibility
        }
        
        public func getJoinedMembers() async throws -> [UserId] {
            try await self.session.getJoinedMembers(roomId: roomId)
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
        
        public var timestamp: UInt64 {
            self.lastMessage?.originServerTS ?? self.state[M_ROOM_CREATE]![""]!.originServerTS
        }
        
        public func setName(newName: String) async throws {
            try await self.session.setRoomName(roomId: self.roomId, name: newName)
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
                let content = mTextContent(msgtype: .text, body: text)
                return try await self.session.sendMessageEvent(to: self.roomId, type: M_ROOM_MESSAGE, content: content)
        }
        
        public func sendImage(image: NativeImage) async throws -> EventId {
            guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
                throw Matrix.Error("Couldn't create JPEG for image")
            }
            let info = mImageInfo(h: Int(image.size.height),
                                  w: Int(image.size.width),
                                  mimetype: "image/jpeg",
                                  size: jpegData.count)
            if !self.isEncrypted {
                let mxc = try await self.session.uploadData(data: jpegData, contentType: "image/jpeg")
                let content = mImageContent(msgtype: .image, body: "\(mxc.mediaId).jpeg", url: mxc, info: info)
                return try await self.session.sendMessageEvent(to: self.roomId, type: M_ROOM_MESSAGE, content: content)
            }
            else {
                let encryptedFile = try await self.session.encryptAndUploadData(plaintext: jpegData, contentType: "image/jpeg")
                let content = mImageContent(msgtype: .image, body: "\(encryptedFile.url.mediaId).jpeg", file: encryptedFile, info: info)
                return try await self.session.sendMessageEvent(to: self.roomId, type: M_ROOM_MESSAGE, content: content)
            }
        }


        
        public func sendVideo(fileUrl: URL, thumbnail: NativeImage?) async throws -> EventId {
            throw Matrix.Error("Not implemented")
        }
        
        public func sendReply(to eventId: EventId, text: String) async throws -> EventId {
            if !self.isEncrypted {
                let content = mTextContent(msgtype: .text,
                                           body: text,
                                           relates_to: mRelatesTo(inReplyTo: .init(eventId: eventId)))
                return try await self.session.sendMessageEvent(to: self.roomId, type: M_ROOM_MESSAGE, content: content)
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
        
        public func addReaction(_ reaction: String, to eventId: EventId) async throws -> EventId {
            // FIXME: What about encryption?
            try await self.session.addReaction(reaction: reaction, to: eventId, in: self.roomId)
        }
    }
}

extension Matrix.Room: Identifiable {
    public var id: String {
        "\(self.roomId)"
    }
}

extension Matrix.Room: Equatable {
    public static func == (lhs: Matrix.Room, rhs: Matrix.Room) -> Bool {
        lhs.roomId == rhs.roomId
    }
}

extension Matrix.Room: Hashable {
    public func hash(into hasher: inout Hasher) {
        self.roomId.hash(into: &hasher)
    }
}
