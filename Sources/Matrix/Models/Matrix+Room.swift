//
//  Matrix+Room.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation
//import Collections // Maybe one day we will get a SortedSet implementation for Swift...
import OrderedCollections

extension Matrix {
    public class Room: ObservableObject {
        public typealias HistoryVisibility = RoomHistoryVisibilityContent.HistoryVisibility

        public let roomId: RoomId
        public let session: Session
        private var dataStore: DataStore?
        
        public let type: String?
        public let version: String
        
        // FIXME: Change all of these to be computed properties.  Make `state` be @Published so SwiftUI will update all Views whenever it changes.
        @Published public var name: String?
        @Published public var topic: String?
        @Published public var avatarUrl: MXC?
        @Published public var avatar: NativeImage?
        
        // FIXME: Change all of these to be computed properties.  Make `state` be @Published so SwiftUI will update all Views whenever it changes.
        public let predecessorRoomId: RoomId?
        public let successorRoomId: RoomId?
        public let tombstoneEventId: EventId?
        
        @Published public var timeline: OrderedDictionary<EventId,Matrix.Message> //[ClientEventWithoutRoomId]
        @Published public var localEchoEvent: Event?
        //@Published var earliestMessage: MatrixMessage?
        //@Published var latestMessage: MatrixMessage?
        public var state: [String: [String: ClientEventWithoutRoomId]]  // Tuples are not Hashable so we can't do [(EventType,String): ClientEventWithoutRoomId]
        
        @Published public var highlightCount: Int = 0
        @Published public var notificationCount: Int = 0
        
        // FIXME: Change all of these to be computed properties.  Make `state` be @Published so SwiftUI will update all Views whenever it changes.
        @Published public var joinedMembers: Set<UserId> = []
        @Published public var invitedMembers: Set<UserId> = []
        @Published public var leftMembers: Set<UserId> = []
        @Published public var bannedMembers: Set<UserId> = []
        @Published public var knockingMembers: Set<UserId> = []

        // FIXME: Change all of these to be computed properties.  Make `state` be @Published so SwiftUI will update all Views whenever it changes.
        @Published public var encryptionParams: RoomEncryptionContent?
        
        private var backwardToken: String?
        private var forwardToken: String?
        
        public init(roomId: RoomId, session: Session, initialState: [ClientEventWithoutRoomId], initialTimeline: [ClientEventWithoutRoomId] = []) throws {
            self.roomId = roomId
            self.session = session
            self.timeline = [:] // Set this to empty for starters, because we need `self` to create instances of Matrix.Message
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
            
            let initialMessages = initialTimeline.map {
                Matrix.Message(event: $0, room: self)
            }
            self.timeline = .init(uniqueKeysWithValues: initialMessages
                .map {
                    ($0.eventId, $0)
                }
            )
        }
        
        public func updateTimeline(from events: [ClientEventWithoutRoomId]) async throws {

            guard !events.isEmpty
            else {
                // No new events.  All done!
                return
            }
            
            let messages = events.map {
                Matrix.Message(event: $0, room: self)
            }
            
            let newKeysAndValues = messages.map {
                ($0.eventId, $0)
            }
            
            guard !self.timeline.isEmpty
            else {
                // No old events.  Start from scratch with the new stuff.
                await MainActor.run {
                    self.timeline = .init(uniqueKeysWithValues: newKeysAndValues)
                }
                return
            }
            
            var tmpTimeline = self.timeline.merging(newKeysAndValues, uniquingKeysWith: { m1,m2 -> Matrix.Message in
                m1
            })
            tmpTimeline.sort()
            let newTimeline = tmpTimeline
            
            await MainActor.run {
                self.timeline = newTimeline
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
            try await self.updateTimeline(from: response.chunk)
            self.backwardToken = response.end ?? self.backwardToken
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
                state[M_ROOM_HISTORY_VISIBILITY]?[""],                  // History visibility
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
        
        public var lastMessage: Matrix.Message? {
            timeline
                .values
                .filter {
                    $0.stateKey == nil
                }
                .last
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
        
        public func setPowerLevel(userId: UserId, power: Int) async throws {
            guard var content = try await session.getRoomState(roomId: roomId, eventType: M_ROOM_POWER_LEVELS) as? RoomPowerLevelsContent
            else {
                throw Matrix.Error("Couldn't get current power levels")
            }

            var dict = content.users ?? [:]
            dict[userId] = power
            content.users = dict
            let eventId = try await self.session.sendStateEvent(to: self.roomId, type: M_ROOM_POWER_LEVELS, content: content)
        }
        
        public var myPowerLevel: Int {
            let me = session.creds.userId
            return powerLevels?.users?[me] ?? powerLevels?.usersDefault ?? 0
        }
        
        public var powerLevels: RoomPowerLevelsContent? {
            guard let event = self.state[M_ROOM_POWER_LEVELS]?[""],
                  let content = event.content as? RoomPowerLevelsContent
            else {
                return nil
            }
            return content
        }
        
        public var iCanInvite: Bool {
            guard let levels = powerLevels
            else {
                return false
            }
            
            let inviteLevel = levels.invite ?? levels.stateDefault ?? 50
            return myPowerLevel >= inviteLevel
        }
        
        public var iCanKick: Bool {
            guard let levels = powerLevels
            else {
                return false
            }
            
            let kickLevel = levels.kick ?? levels.stateDefault ?? 50
            return myPowerLevel >= kickLevel
        }
        
        public var iCanBan: Bool {
            guard let levels = powerLevels
            else {
                return false
            }
            
            let banLevel = levels.ban ?? levels.stateDefault ?? 50
            return myPowerLevel >= banLevel
        }
        
        public var iCanRedact: Bool {
            guard let levels = powerLevels
            else {
                return false
            }
            
            let redactLevel = levels.redact ?? levels.stateDefault ?? 50
            return myPowerLevel >= redactLevel
        }
        
        public func iCanSendEvent(type: String) -> Bool {
            guard let levels = powerLevels
            else {
                return false
            }
            
            let sendLevel = levels.events?[type] ?? levels.eventsDefault ?? 0
            return myPowerLevel >= sendLevel
        }
        
        public func iCanChangeState(type: String) -> Bool {
            guard let levels = powerLevels
            else {
                return false
            }
            
            let stateLevel = levels.stateDefault ?? 50
            return myPowerLevel >= stateLevel
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
        
        public func sendImage(image: NativeImage,
                              thumbnailSize: (Int,Int)?=(800,600),
                              withBlurhash: Bool=true
        ) async throws -> EventId {
            guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
                throw Matrix.Error("Couldn't create JPEG for image")
            }
            
            var info = mImageInfo(h: Int(image.size.height),
                                  w: Int(image.size.width),
                                  mimetype: "image/jpeg",
                                  size: jpegData.count)
            
            let thumbnail: NativeImage?
            if let (thumbWidth, thumbHeight) = thumbnailSize {
                thumbnail = image.downscale(to: CGSize(width: thumbWidth, height: thumbHeight))
            } else {
                thumbnail = nil
            }
            
            let thumbnailData: Data?
            if let thumbnail = thumbnail {
                thumbnailData = thumbnail.jpegData(compressionQuality: 0.9)
                guard thumbnailData != nil else {
                    throw Matrix.Error("Failed to create JPEG for thumbnail")
                }
            } else {
                thumbnailData = nil
            }
            
            if withBlurhash {
                info.blurhash = image.blurHash(numberOfComponents: image.size.width > image.size.height ? (6,4) : (4,6))
            }
            
            if !self.isEncrypted {
                let mxc = try await self.session.uploadData(data: jpegData, contentType: "image/jpeg")
                if let thumbnail = thumbnail,
                   let thumbnailData = thumbnailData
                {
                    let thumbnailMXC = try await self.session.uploadData(data: thumbnailData, contentType: "image/jpeg")
                    info.thumbnail_info = mThumbnailInfo(h: Int(thumbnail.size.height),
                                                         w: Int(thumbnail.size.width),
                                                         mimetype: "image/jpeg",
                                                         size: thumbnailData.count)
                    info.thumbnail_url = thumbnailMXC
                }
                let content = mImageContent(msgtype: .image, body: "\(mxc.mediaId).jpeg", url: mxc, info: info)
                return try await self.session.sendMessageEvent(to: self.roomId, type: M_ROOM_MESSAGE, content: content)
            }
            else {
                let encryptedFile = try await self.session.encryptAndUploadData(plaintext: jpegData, contentType: "image/jpeg")
                
                if let thumbnail = thumbnail,
                   let thumbnailData = thumbnailData
                {
                    let thumbnailFile = try await self.session.encryptAndUploadData(plaintext: thumbnailData, contentType: "image/jpeg")
                    info.thumbnail_info = mThumbnailInfo(h: Int(thumbnail.size.height),
                                                         w: Int(thumbnail.size.width),
                                                         mimetype: "image/jpeg",
                                                         size: thumbnailData.count)
                    info.thumbnail_file = thumbnailFile
                }
                
                let content = mImageContent(msgtype: .image, body: "\(encryptedFile.url.mediaId).jpeg", file: encryptedFile, info: info)
                return try await self.session.sendMessageEvent(to: self.roomId, type: M_ROOM_MESSAGE, content: content)
            }
        }


        
        public func sendVideo(fileUrl: URL, thumbnail: NativeImage?) async throws -> EventId {
            throw Matrix.Error("Not implemented")
        }
        
        public func sendReply(to eventId: EventId, text: String) async throws -> EventId {
            let content = mTextContent(msgtype: .text,
                                       body: text,
                                       relates_to: mRelatesTo(inReplyTo: .init(eventId: eventId)))
            return try await self.session.sendMessageEvent(to: self.roomId, type: M_ROOM_MESSAGE, content: content)
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
