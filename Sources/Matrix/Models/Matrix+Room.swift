//
//  Matrix+Room.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation
//import Collections // Maybe one day we will get a SortedSet implementation for Swift...
import OrderedCollections

#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension Matrix {
    open class Room: ObservableObject {
        public typealias HistoryVisibility = RoomHistoryVisibilityContent.HistoryVisibility
        public typealias Membership = RoomMemberContent.Membership
        public typealias PowerLevels = RoomPowerLevelsContent

        public let roomId: RoomId
        public let session: Session
        private var dataStore: DataStore?
        
        @Published public var avatar: NativeImage?
        private var currentAvatarUrl: MXC?          // Remember where we got our current avatar image, so we can know when to fetch a new one (or not)
        
        private(set) public var timeline: OrderedDictionary<EventId,Message> //[ClientEventWithoutRoomId]
        //@Published public var localEchoEvent: Event?
        @Published private(set) public var localEchoMessage: Message?
        private(set) public var reactions: [EventId: Message]

        @Published private(set) public var state: [String: [String: ClientEventWithoutRoomId]]  // Tuples are not Hashable so we can't do [(EventType,String): ClientEventWithoutRoomId]
        
        @Published public var highlightCount: Int = 0
        @Published public var notificationCount: Int = 0
        
        private var backwardToken: String?
        private var forwardToken: String?
        
        private var fetchAvatarImageTask: Task<Void,Swift.Error>?
        
        // MARK: init
        
        public required init(roomId: RoomId, session: Session, initialState: [ClientEventWithoutRoomId], initialTimeline: [ClientEventWithoutRoomId] = []) throws {
            self.roomId = roomId
            self.session = session
            self.timeline = [:] // Set this to empty for starters, because we need `self` to create instances of Matrix.Message
            self.reactions = [:]
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
            
            self.timeline = [:]
            for event in initialTimeline {
                self.timeline[event.eventId] = Matrix.Message(event: event, room: self)
            }
            
            // Use our thumbhash or blurhash as our avatar until the application decides it's worth fetching the actual image
            Task {
                await self.useBlurryPlaceholder()
            }
            
            /*
            // FIXME: CRAZY DEBUGGING
            // For some reason, SwiftUI isn't updating views in Circles when we change our (published) avatar image
            // Let's test this to see what's going on
            Task(priority: .background) {
                while true {
                    let sec = Int.random(in: 10...30)
                    try await Task.sleep(for: .seconds(sec))
                    let imageName = ["diamond.fill", "circle.fill", "square.fill", "seal.fill", "shield.fill"].randomElement()!
                    #if os(macOS)
                    let newImage = NSImage(systemSymbolName: imageName, accessibilityDescription: nil)
                    #else
                    let newImage = UIImage(systemName: imageName)
                    #endif
                    await MainActor.run {
                        print("Setting avatar for room \(self.roomId)")
                        self.avatar = newImage
                    }
                }
            }
            */
        }
        
        func updateUnreadCounts(notifications: Int, highlights: Int) async {
            // Gotta run this on the main Actor because the vars are @Published, and will trigger an objectWillChange
            await MainActor.run {
                self.notificationCount = notifications
                self.highlightCount = highlights
            }
        }
        
        // MARK: Timeline
        
        open func updateTimeline(from events: [ClientEventWithoutRoomId]) async throws {
            logger.debug("Updating timeline: \(self.timeline.count) existing events vs \(events.count) new events")

            guard !events.isEmpty
            else {
                // No new events.  All done!
                logger.debug("No new events; Done!")
                return
            }
            
            // It's possible that we can get some state events in our timeline, especially when the room is new
            let stateEvents = events.filter({$0.stateKey != nil})
            await self.updateState(from: stateEvents)
            
            /*
            let messages = events.map {
                Matrix.Message(event: $0, room: self)
            }
            
            let newKeysAndValues = messages.map {
                ($0.eventId, $0)
            }
            */
            
            guard !self.timeline.isEmpty
            else {
                logger.debug("No existing events.  Starting from scratch with the new events")
                // No old events.  Start from scratch with the new stuff.
                var tmpTimeline: OrderedDictionary<EventId,Matrix.Message> = [:]
                for event in events {
                    tmpTimeline[event.eventId] = Matrix.Message(event: event, room: self)
                }
                let newTimeline = tmpTimeline
                await MainActor.run {
                    self.timeline = newTimeline
                }
                return
            }
            
            logger.debug("Merging old and new events")
            /*
            var tmpTimeline = self.timeline.merging(newKeysAndValues, uniquingKeysWith: { m1,m2 -> Matrix.Message in
                m1
            })
            tmpTimeline.sort()
            let newTimeline = tmpTimeline
            */
            var tmpTimeline = self.timeline
            for event in events {
                tmpTimeline[event.eventId] = Matrix.Message(event: event, room: self)
                
                // When we receive the "real" version of a message, we can remove the local echo
                if event.eventId == self.localEchoMessage?.eventId {
                    await MainActor.run {
                        self.localEchoMessage = nil
                    }
                }
            }
            let newTimeline = tmpTimeline
            
            await MainActor.run {
                self.timeline = newTimeline
            }
        }
        
        // MARK: State
        
        open func updateState(from events: [ClientEventWithoutRoomId]) async {
            // Compute the new state from the old state and the new events
            var tmpState = self.state
            for event in events {
                guard let stateKey = event.stateKey
                else {
                    logger.debug("No state key for \"state\" even of type \(event.type)")
                    continue
                }
                
                var d = tmpState[event.type] ?? [:]
                d[stateKey] = event
                tmpState[event.type] = d
            }
            let newState = tmpState
            await MainActor.run {
                self.state = newState
            }
            
            // Also update our actual image, if necessary
            self.updateAvatarImage()
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
        
        public var messages: [Matrix.Message] {
            Array(
                timeline
                    .values
                    .filter {
                        $0.stateKey == nil
                    }
            )
        }
        
        public var latestMessage: Matrix.Message? {
            messages.last
        }
        
        public var earliestMessage: Matrix.Message? {
            messages.first
        }
        
        // MARK: Room "profile"
        
        public func setName(newName: String) async throws {
            try await self.session.setRoomName(roomId: self.roomId, name: newName)
        }
        
        public func setAvatarImage(image: NativeImage) async throws {
            let (scaledImage, mxc) = try await self.session.setAvatarImage(roomId: self.roomId, image: image)
            // When the server is lagging, the client can get really janky if we wait on the m.room.avatar to come down the /sync pipeline
            // So instead we'll automatically update the in-memory data right now, since we know that the event was accepted by the server in the call above
            await MainActor.run {
                self.avatar = scaledImage
                self.currentAvatarUrl = mxc
            }
        }
        
        public func setTopic(newTopic: String) async throws {
            try await self.session.setTopic(roomId: self.roomId, topic: newTopic)
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
                guard mxc != self.currentAvatarUrl
                else {
                    logger.debug("Room \(self.roomId) already has the latest avatar.  Done.")
                    return
                }
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
                        self.currentAvatarUrl = mxc
                    }
                    
                    self.fetchAvatarImageTask = nil
                    logger.debug("Room \(self.roomId) done fetching avatar image")
                })
                
            } else {
                logger.debug("Can't fetch avatar for room \(self.roomId) because we have no avatar_url")
            }
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

        private(set) public var canPaginate: Bool = true
                
        public func paginate(limit: UInt?=nil) async throws {
            let response = try await self.session.getMessages(roomId: roomId, forward: false, from: self.backwardToken, limit: limit)
            // The timeline messages are in the "chunk" piece of the response
            try await self.updateTimeline(from: response.chunk)
            self.backwardToken = response.end ?? self.backwardToken
            self.canPaginate = response.end != nil
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
            let eventId = try await self.session.sendMessageEvent(to: self.roomId, type: M_ROOM_MESSAGE, content: content)
            let localEchoEvent = try ClientEventWithoutRoomId(content: content,
                                                              eventId: eventId,
                                                              originServerTS: UInt64(1000*Date().timeIntervalSince1970),
                                                              sender: session.creds.userId,
                                                              type: M_ROOM_MESSAGE)
            await MainActor.run {
                self.localEchoMessage = Matrix.Message(event: localEchoEvent, room: self)
            }
            return eventId
        }
        
        public func sendImage(image: NativeImage,
                              thumbnailSize: (Int,Int)?=(800,600),
                              withBlurhash: Bool=true,
                              withThumbhash: Bool=true
        ) async throws -> EventId {
            let jpegStart = Date()
            guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
                throw Matrix.Error("Couldn't create JPEG for image")
            }
            let jpegEnd = Date()
            let jpegTime = jpegEnd.timeIntervalSince(jpegStart)
            logger.debug("\(jpegTime) sec to compress \(image.size.width)x\(image.size.height) JPEG")
            
            var info = mImageInfo(h: Int(image.size.height),
                                  w: Int(image.size.width),
                                  mimetype: "image/jpeg",
                                  size: jpegData.count)
            
            let thumbnail: NativeImage?
            if let (thumbWidth, thumbHeight) = thumbnailSize {
                let thumbnailStart = Date()
                thumbnail = image.downscale(to: CGSize(width: thumbWidth, height: thumbHeight))
                let thumbnailEnd = Date()
                let thumbnailTime = thumbnailEnd.timeIntervalSince(thumbnailStart)
                logger.debug("\(thumbnailTime) sec to resize \(thumbnail!.size.width)x\(thumbnail!.size.height) thumbnail")
            } else {
                thumbnail = nil
            }
            
            let thumbnailData: Data?
            if let thumbnail = thumbnail {
                let thumbJpegStart = Date()
                thumbnailData = thumbnail.jpegData(compressionQuality: 0.8)
                let thumbJpegEnd = Date()
                let thumbJpegTime = thumbJpegEnd.timeIntervalSince(thumbJpegStart)
                logger.debug("\(thumbJpegTime) sec to compress thumbnail JPEG")
                guard thumbnailData != nil else {
                    throw Matrix.Error("Failed to create JPEG for thumbnail")
                }
            } else {
                thumbnailData = nil
            }
            
            if withBlurhash || withThumbhash {
                let tinyStart = Date()
                guard let image100x100 = image.downscale(to: CGSize(width: 100, height: 100))
                else {
                    logger.error("Failed to create tiny 100x100 image for blurhash/thumbhash")
                    throw Matrix.Error("Failed to create tiny 100x100 image for blurhash/thumbhash")
                }
                let tinyEnd = Date()
                let tinyTime = tinyEnd.timeIntervalSince(tinyStart)
                logger.debug("\(tinyTime) sec to create tiny 100x100 image for blurhash/thumbhash")

                
                if withBlurhash {
                    let blurhashStart = Date()
                    info.blurhash = image100x100.blurHash(numberOfComponents: image100x100.size.width > image100x100.size.height ? (6,4) : (4,6))
                    let blurhashEnd = Date()
                    let blurhashTime = blurhashEnd.timeIntervalSince(blurhashStart)
                    logger.debug("\(blurhashTime) sec to create blurhash")
                }
                
                if withThumbhash
                {
                    let thumbhashStart = Date()
                    info.thumbhash = imageToThumbHash(image: image100x100).base64EncodedString()
                    let thumbhashEnd = Date()
                    let thumbhashTime = thumbhashEnd.timeIntervalSince(thumbhashStart)
                    logger.debug("\(thumbhashTime) sec to create thumbhash")
                }
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
                let eventId =  try await self.session.sendMessageEvent(to: self.roomId, type: M_ROOM_MESSAGE, content: content)
                let localEchoEvent = try ClientEventWithoutRoomId(content: content,
                                                                  eventId: eventId,
                                                                  originServerTS: UInt64(1000*Date().timeIntervalSince1970),
                                                                  sender: session.creds.userId,
                                                                  type: M_ROOM_MESSAGE)
                await MainActor.run {
                    self.localEchoMessage = Matrix.Message(event: localEchoEvent, room: self)
                }
                return eventId
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
                let eventId = try await self.session.sendMessageEvent(to: self.roomId, type: M_ROOM_MESSAGE, content: content)
                let localEchoEvent = try ClientEventWithoutRoomId(content: content,
                                                                  eventId: eventId,
                                                                  originServerTS: UInt64(1000*Date().timeIntervalSince1970),
                                                                  sender: session.creds.userId,
                                                                  type: M_ROOM_MESSAGE)
                await MainActor.run {
                    self.localEchoMessage = Matrix.Message(event: localEchoEvent, room: self)
                }
                return eventId
            }
        }


        
        public func sendVideo(fileUrl: URL, thumbnail: NativeImage?) async throws -> EventId {
            throw Matrix.Error("Not implemented")
        }
        
        public func sendReply(to event: ClientEventWithoutRoomId, text: String, threaded: Bool = true) async throws -> EventId {
            let relatesTo: mRelatesTo
            // Is this a threaded reply?  If so, extract the thread id from the parent event, or use its id as the new thread id.
            // Otherwise, just send the m.in_reply_to relation
            if threaded {
                if let relatedContent = event.content as? RelatedEventContent,
                   relatedContent.relationshipType == M_THREAD,
                   let threadId = relatedContent.relatedEventId
                {
                    relatesTo = mRelatesTo(relType: M_THREAD, eventId: threadId, inReplyTo: event.eventId)

                } else {
                    relatesTo = mRelatesTo(relType: M_THREAD, eventId: event.eventId, inReplyTo: event.eventId)
                }
            
            } else {
                relatesTo = mRelatesTo(inReplyTo: event.eventId)
            }
            
            let content = mTextContent(msgtype: .text,
                                       body: text,
                                       relatesTo: relatesTo)
            
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
