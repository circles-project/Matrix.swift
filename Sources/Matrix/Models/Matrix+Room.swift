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
    open class Room: ObservableObject {
        public typealias HistoryVisibility = RoomHistoryVisibilityContent.HistoryVisibility
        public typealias Membership = RoomMemberContent.Membership
        public typealias PowerLevels = RoomPowerLevelsContent

        public let roomId: RoomId
        public let session: Session
        private var dataStore: DataStore?
        
        @Published public var avatar: NativeImage?
        
        @Published private(set) public var timeline: OrderedDictionary<EventId,Matrix.Message> //[ClientEventWithoutRoomId]
        //@Published public var localEchoEvent: Event?
        @Published private(set) public var localEchoMessage: Message? // FIXME: Set this when we send a message

        @Published private(set) public var state: [String: [String: ClientEventWithoutRoomId]]  // Tuples are not Hashable so we can't do [(EventType,String): ClientEventWithoutRoomId]
        
        @Published public var highlightCount: Int = 0
        @Published public var notificationCount: Int = 0
        
        private var backwardToken: String?
        private var forwardToken: String?
        
        // MARK: init
        
        public required init(roomId: RoomId, session: Session, initialState: [ClientEventWithoutRoomId], initialTimeline: [ClientEventWithoutRoomId] = []) throws {
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
        
        // MARK: Timeline
        
        open func updateTimeline(from events: [ClientEventWithoutRoomId]) async throws {

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
        
        // MARK: State
        
        open func updateState(from events: [ClientEventWithoutRoomId]) async {
            for event in events {
                await updateState(from: event)
            }
        }
        
        open func updateState(from event: ClientEventWithoutRoomId) async {
            guard let stateKey = event.stateKey
            else {
                let msg = "No state key for \"state\" event of type \(event.type)"
                print("updateState:\t\(msg)")
                //throw Matrix.Error(msg)
                //continue
                return
            }
            
            // Update our local copy of the state to include this event
            await MainActor.run {
                var d = self.state[event.type] ?? [:]
                d[stateKey] = event
                self.state[event.type] = d
            }
            
            if event.type == M_ROOM_AVATAR {
                // FIXME: Fetch the latest image
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
        
        // MARK: Computed properties
        
        public var version: String {
            guard let event = state[M_ROOM_CREATE]![""],
                  let content = event.content as? RoomCreateContent
            else {
                return "1"
            }
            return content.roomVersion ?? "1"
        }
        
        public var creator: UserId {
            state[M_ROOM_CREATE]![""]!.sender
        }
        
        public var type: String? {
            guard let event = state[M_ROOM_CREATE]![""],
                  let content = event.content as? RoomCreateContent
            else {
                return nil
            }
            return content.type
        }
        
        public var historyVisibility: HistoryVisibility? {
            guard let event = state[M_ROOM_HISTORY_VISIBILITY]?[""],
                  let content = event.content as? RoomHistoryVisibilityContent
            else {
                return nil
            }
            return content.historyVisibility
        }
        
        public func getHistoryVisibility() async throws -> HistoryVisibility? {
            let content = try await getState(type: M_ROOM_HISTORY_VISIBILITY, stateKey: "") as? RoomHistoryVisibilityContent
            return content?.historyVisibility
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
            return content.mxc
        }
        
        public var predecessorRoomId: RoomId? {
            guard let event = state[M_ROOM_CREATE]?[""],
                  let content = event.content as? RoomCreateContent
            else {
                return nil
            }
            return content.predecessor?.roomId
        }
        
        public var successorRoomId: RoomId? {
            guard let event = state[M_ROOM_TOMBSTONE]?[""],
                  let content = event.content as? RoomTombstoneContent
            else {
                return nil
            }
            return content.replacementRoom
        }
        
        public var tombstoneEventId: EventId? {
            guard let event = state[M_ROOM_TOMBSTONE]?[""]
            else {
                return nil
            }
            return event.eventId
        }
        
        private func getKnownMembers(status: Membership) -> [UserId] {
            guard let dict = state[M_ROOM_MEMBER]
            else {
                return []
            }
            return dict.values.compactMap { event in
                guard let user = event.stateKey,
                      let content = event.content as? RoomMemberContent,
                      content.membership == status
                else {
                    return nil
                }
                return UserId(user)
            }
        }
        
        public var joinedMembers: [UserId] {
            self.getKnownMembers(status: .join)
        }
        
        public var invitedMembers: [UserId] {
            self.getKnownMembers(status: .invite)
        }
        
        public var leftMembers: [UserId] {
            self.getKnownMembers(status: .leave)
        }
        
        public var bannedMembers: [UserId] {
            self.getKnownMembers(status: .ban)
        }
        
        public var knockingMembers: [UserId] {
            self.getKnownMembers(status: .knock)
        }
                
        public func getJoinedMembers() async throws -> [UserId] {
            try await self.session.getJoinedMembers(roomId: roomId)
        }
        
        public var latestMessage: Matrix.Message? {
            timeline
                .values
                .filter {
                    $0.stateKey == nil
                }
                .last
        }
        
        public var earliestMessage: Matrix.Message? {
            timeline
                .values
                .filter {
                    $0.stateKey == nil
                }
                .first
        }
        
        // MARK: Room "profile"
        
        public func setName(newName: String) async throws {
            try await self.session.setRoomName(roomId: self.roomId, name: newName)
        }
        
        public func setAvatarImage(image: NativeImage) async throws {
            try await self.session.setAvatarImage(roomId: self.roomId, image: image)
        }
        
        public func setTopic(newTopic: String) async throws {
            try await self.session.setTopic(roomId: self.roomId, topic: newTopic)
        }
        
        // MARK: Power levels
        
        public func setPowerLevel(userId: UserId, power: Int) async throws {
            guard var content = try await session.getRoomState(roomId: roomId, eventType: M_ROOM_POWER_LEVELS) as? PowerLevels
            else {
                throw Matrix.Error("Couldn't get current power levels")
            }

            var dict = content.users ?? [:]
            dict[userId] = power
            content.users = dict
            let eventId = try await self.session.sendStateEvent(to: self.roomId, type: M_ROOM_POWER_LEVELS, content: content)
        }
        
        public func getPowerLevel(userId: UserId) -> Int {
            guard let event = state[M_ROOM_POWER_LEVELS]?[""],
                  let content = event.content as? RoomPowerLevelsContent
            else {
                return 0
            }
            return content.users?[userId] ?? content.usersDefault ?? 0
        }
        
        public var myPowerLevel: Int {
            let me = session.creds.userId
            return powerLevels?.users?[me] ?? powerLevels?.usersDefault ?? 0
        }
        
        public var powerLevels: PowerLevels? {
            guard let event = self.state[M_ROOM_POWER_LEVELS]?[""],
                  let content = event.content as? PowerLevels
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
        
        // MARK: Membership operations
        
        public func invite(userId: UserId, reason: String? = nil) async throws {
            try await self.session.inviteUser(roomId: self.roomId, userId: userId, reason: reason)
        }
        
        public func kick(userId: UserId, reason: String? = nil) async throws {
            try await self.session.kickUser(roomId: self.roomId, userId: userId, reason: reason)
        }
        
        public func ban(userId: UserId, reason: String? = nil) async throws {
            try await self.session.banUser(roomId: self.roomId, userId: userId, reason: reason)
        }
        
        public func mute(userId: UserId) async throws {
            try await self.setPowerLevel(userId: userId, power: -10)
        }
        
        public func leave(reason: String? = nil) async throws {
            try await self.session.leave(roomId: self.roomId, reason: reason)
        }
        
        // MARK: Pagination
        
        public func canPaginate() -> Bool {
            // FIXME: TODO:
            return false
        }
                
        public func paginate(limit: UInt?=nil) async throws {
            let response = try await self.session.getMessages(roomId: roomId, forward: false, from: self.backwardToken, limit: limit)
            // The timeline messages are in the "chunk" piece of the response
            try await self.updateTimeline(from: response.chunk)
            self.backwardToken = response.end ?? self.backwardToken
        }
        
        // MARK: Encryption
        
        public var encryptionParams: RoomEncryptionContent? {
            guard let event = state[M_ROOM_ENCRYPTION]?[""],
                  let content = event.content as? RoomEncryptionContent
            else {
                return nil
            }
            return content
        }
        
        public var isEncrypted: Bool {
            self.encryptionParams != nil
        }
        
        // MARK: Sending messages
        
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

// MARK: Protocol Extensions

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
