//
//  Matrix+Room.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation
//import Collections // Maybe one day we will get a SortedSet implementation for Swift...
import OrderedCollections
import os

import AVFoundation

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
        //private(set) public var reactions: [EventId: Message]
        private(set) public var relations: [String: [EventId: Set<Message>]]
        private(set) public var replies: [EventId: Set<Message>]

        @Published private(set) public var state: [String: [String: ClientEventWithoutRoomId]]  // Tuples are not Hashable so we can't do [(EventType,String): ClientEventWithoutRoomId]
                
        @Published public var highlightCount: Int = 0
        @Published public var notificationCount: Int = 0
        
        @Published private(set) public var accountData: [String: Codable]
        
        private var backwardToken: String?
        private var forwardToken: String?
        
        private var fetchAvatarImageTask: Task<Void,Swift.Error>?
        
        private var logger: os.Logger
        
        // MARK: init
        
        public required init(roomId: RoomId, session: Session,
                             initialState: [ClientEventWithoutRoomId],
                             initialTimeline: [ClientEventWithoutRoomId] = [],
                             initialAccountData: [AccountDataEvent] = []
        ) throws {
            self.roomId = roomId
            self.session = session
            self.timeline = [:] // Set this to empty for starters, because we need `self` to create instances of Matrix.Message
            //self.reactions = [:]
            self.relations = [
                M_REACTION: [:],
                M_THREAD: [:],
                M_ANNOTATION: [:],
                M_REFERENCE: [:],
            ]
            self.replies = [:]
            self.state = [:]
            self.accountData = [:]
            
            self.logger = os.Logger(subsystem: "matrix", category: "room \(roomId)")
            
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
            
            for event in initialAccountData {
                self.accountData[event.type] = event.content
            }
            
            // Now run all the async stuff that we can't run in a sync context
            Task {
                // Update replies, reactions, and other relations for our messages
                await self.updateRelations(events: initialTimeline)
                
                // Use our thumbhash or blurhash as our avatar until the application decides it's worth fetching the actual image
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
            
            // Also update our reactions, replies, and other relations
            await self.updateRelations(events: events)
        }
        
        // MARK: Relations
        func updateRelations(events: [ClientEventWithoutRoomId]) async {
            for event in events {
                if let content = event.content as? RelatedEventContent {
                    logger.debug("Updating relations with event \(event.eventId) (\(event.type))")
                    
                    let message = self.timeline[event.eventId] ?? Message(event: event, room: self)
                    
                    // Check relType
                    if let relType = content.relationType,
                       let relatedEventId = content.relatedEventId
                    {
                        logger.debug("relType = \(relType) relatedEventId = \(relatedEventId)")
                        // Update our state here in the Room
                        if let set = self.relations[relType]?[relatedEventId] {
                            self.relations[relType]![relatedEventId] = set.union([message])
                        } else {
                            self.relations[relType] = self.relations[relType] ?? [:]
                            self.relations[relType]![relatedEventId] = [message]
                        }
                        
                        // Also update the Message if we have it in memory
                        if let relatedMessage = self.timeline[relatedEventId]
                        {
                            if relType == M_ANNOTATION && event.type == M_REACTION /*,
                               let reactionContent = event.content as? ReactionContent,
                               let key = reactionContent.relatesTo.key */
                            {
                                logger.debug("Adding event \(event.eventId) as a reaction to message \(relatedEventId)")
                                await relatedMessage.addReaction(event: event)
                            }
                            else if relType == M_THREAD && event.type == M_ROOM_MESSAGE {
                                logger.debug("THREAD Adding event \(event.eventId) as a reply to \(relatedEventId)")
                                await relatedMessage.addReply(message: message)
                            }
                            else {
                                logger.debug("Event \(event.eventId) doesn't look like a relation that we understand")
                            }
                            
                        } else {
                            logger.debug("Couldn't find relation parent message \(relatedEventId)")
                        }
                    } else {
                        logger.debug("Event \(event.eventId) doesn't look like a standard relation")
                    }
                    
                    // Check for inReplyTo, which is distinct from relType
                    if let parentEventId = content.replyToEventId {
                        self.replies[parentEventId] = self.replies[parentEventId] ?? []
                        self.replies[parentEventId]?.insert(message)
                        if let parentMessage = self.timeline[parentEventId] {
                            logger.debug("Adding reply to message \(parentEventId)")
                            await parentMessage.addReply(message: message)
                        }
                    } else {
                        logger.debug("Event \(event.eventId) doesn't look like a rich reply")
                    }
                }
            }
        }
        
        public func loadReactions(for eventId: EventId) async throws -> [ClientEventWithoutRoomId] {
            let reactionEvents = try await self.session.loadRelatedEvents(for: eventId, in: self.roomId, relType: M_ANNOTATION, type: M_REACTION)
            try await self.updateTimeline(from: reactionEvents)
            return reactionEvents
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
        
        // MARK: Account Data

        public func updateAccountData(events: [AccountDataEvent]) async {
            await MainActor.run {
                for event in events {
                    self.accountData[event.type] = event.content
                }
            }
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
                        $0.stateKey == nil && ($0.type == M_ROOM_MESSAGE || $0.type == M_ROOM_ENCRYPTED)
                    }
            )
        }
        
        public var latestMessage: Matrix.Message? {
            messages.last
        }
        
        public var earliestMessage: Matrix.Message? {
            messages.first
        }
        
        public var threads: [EventId: Set<Message>] {
            relations[M_THREAD] ?? [:]
        }
        
        public var tags: [String] {
            guard let content = self.accountData[M_TAG] as? TagContent
            else {
                return []
            }
            // Values here are simply the "order" from the JSON structure
            // Keys are the String tags
            // Return the tags sorted by "order"
            return content.tags.sorted(by: { $0.value < $1.value }).compactMap { $0.key }
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
        
        // MARK: Fetching messages
        
        public func getMessages(forward: Bool = false,
                                from startToken: String? = nil,
                                to endToken: String? = nil,
                                limit: UInt? = 25
        ) async throws -> RoomMessagesResponseBody {
            let response = try await session.getMessages(roomId: self.roomId, forward: forward, from: startToken, to: endToken, limit: limit)
            
            let events = response.chunk
            
            try await self.updateTimeline(from: events)
            await self.updateRelations(events: events)
            
            return response
        }
        
        public func getRelatedMessages(eventId: EventId,
                                       relType: String,
                                       from startToken: String? = nil,
                                       to endToken: String? = nil,
                                       limit: UInt? = 25
        ) async throws -> RelatedMessagesResponseBody {
            let response = try await session.getRelatedMessages(roomId: self.roomId, eventId: eventId, relType: relType, from: startToken, to: endToken, limit: limit)
            
            let events = response.chunk
            
            try await self.updateTimeline(from: events)
            await self.updateRelations(events: events)
            
            return response
        }
        
        public func getThreadRoots(from startToken: String? = nil,
                                   include: String? = nil,
                                   limit: UInt? = 25
        ) async throws -> RelatedMessagesResponseBody {
            let response = try await session.getThreadRoots(roomId: self.roomId, from: startToken, include: include, limit: limit)
            
            let events = response.chunk
            
            try await self.updateTimeline(from: events)
            await self.updateRelations(events: events)
            
            return response
        }
        
        public func getThreadedMessages(threadId: EventId,
                                        from startToken: String? = nil,
                                        to endToken: String? = nil,
                                        limit: UInt? = 25
        ) async throws -> RelatedMessagesResponseBody {
            return try await getRelatedMessages(eventId: threadId, relType: M_THREAD, from: startToken, to: endToken, limit: limit)
        }
        
        // MARK: Sending messages
        
        public func sendText(text: String) async throws -> EventId {
            let content = mTextContent(msgtype: M_TEXT, body: text)
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
                              caption: String?=nil,
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
                if let t = thumbnail {
                    logger.debug("\(thumbnailTime) sec to resize \(t.size.width)x\(t.size.height) thumbnail")
                }
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
                if let image100x100 = image.downscale(to: CGSize(width: 100, height: 100)) {
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
                else {
                    logger.error("Failed to create tiny 100x100 image for blurhash/thumbhash")
                    //throw Matrix.Error("Failed to create tiny 100x100 image for blurhash/thumbhash")
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
                let content = mImageContent(msgtype: M_IMAGE,
                                            body: "\(mxc.mediaId).jpeg",
                                            url: mxc,
                                            info: info,
                                            caption: caption)
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
                
                let content = mImageContent(msgtype: M_IMAGE,
                                            body: "\(encryptedFile.url.mediaId).jpeg",
                                            file: encryptedFile,
                                            info: info,
                                            caption: caption)
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


        
        public func sendVideo(url: URL, thumbnail: NativeImage, caption: String? = nil) async throws -> EventId {
            guard url.isFileURL
            else {
                logger.error("URL must be a local file URL")
                throw Matrix.Error("URL must be a local file URL")
            }
            let video = AVAsset(url: url)
            
            // Get the basic info about the video
            // Duration
            let cmDuration: CMTime = try await video.load(.duration)
            let duration = UInt(cmDuration.seconds)
            // Resolution
            guard let track = try await video.loadTracks(withMediaType: .video).first
            else {
                logger.error("No video tracks in the video")
                throw Matrix.Error("No video tracks in the video")
            }
            let resolution = try await track.load(.naturalSize)
            let height = UInt(abs(resolution.height))
            let width = UInt(abs(resolution.width))

            // https://developer.apple.com/documentation/avfoundation/media_reading_and_writing/exporting_video_to_alternative_formats
            let preset: String = AVAssetExportPresetMediumQuality
            let fileType: AVFileType = .mp4
            
            // Check the compatibility of the preset to export the video to the output file type.
            guard await AVAssetExportSession.compatibility(ofExportPreset: preset,
                                                           with: video,
                                                           outputFileType: fileType)
            else {
                logger.error("The preset can't export the video to the output file type.")
                throw Matrix.Error("The preset can't export the video to the output file type.")
            }
            
            // Generate a random file in the temporary directory
            let random = UInt64.random(in: 0...UInt64.max)
            let filename = "video-\(random).\(fileType.rawValue)"
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            
            // Create and configure the export session.
            guard let exportSession = AVAssetExportSession(asset: video,
                                                           presetName: preset)
            else {
                logger.error("Failed to create export session.")
                throw Matrix.Error("Failed to create export session.")
            }
            exportSession.outputFileType = fileType
            exportSession.outputURL = outputURL
            
            // Convert the video to the output file type and export it to the output URL.
            await exportSession.export()
            
            // Load the data from the file and upload it
            guard let data = try? Data(contentsOf: outputURL)
            else {
                logger.error("Failed to load transcoded video data")
                throw Matrix.Error("Failed to laod transcoded video data")
            }
            
            guard let thumbData = thumbnail.jpegData(compressionQuality: 0.8)
            else {
                logger.error("Failed to compress thumbnail")
                throw Matrix.Error("Failed to compress thumbnail")
            }
            let thumbnailInfo = mThumbnailInfo(h: Int(thumbnail.size.height),
                                               w: Int(thumbnail.size.width),
                                               mimetype: "image/jpeg",
                                               size: thumbData.count)
            
            if !self.isEncrypted {
                let mxc = try await session.uploadData(data: data, contentType: "video/mp4")
                let thumbMXC = try await session.uploadData(data: thumbData, contentType: "image/jpeg")

                let info = mVideoInfo(duration: duration,
                                      h: height,
                                      w: width,
                                      mimetype: "video/mp4",
                                      size: UInt(data.count),
                                      thumbnail_info: thumbnailInfo)
                let content = mVideoContent(msgtype: M_VIDEO, body: filename, info: info, url: mxc, caption: caption)
                
                return try await session.sendMessageEvent(to: self.roomId, type: M_ROOM_MESSAGE, content: content)
            } else {
                let file = try await session.encryptAndUploadData(plaintext: data, contentType: "video/mp4")
                let thumbFile = try await session.encryptAndUploadData(plaintext: thumbData, contentType: "image/jpeg")
                let info = mVideoInfo(duration: duration,
                                      h: height,
                                      w: width, mimetype: "video/mp4",
                                      size: UInt(data.count),
                                      thumbnail_file: thumbFile,
                                      thumbnail_info: thumbnailInfo)
                let content = mVideoContent(msgtype: M_VIDEO, body: filename, info: info, file: file, caption: caption)
                
                return try await session.sendMessageEvent(to: self.roomId, type: M_ROOM_MESSAGE, content: content)
            }
        }
        
        public func sendReply(to event: ClientEventWithoutRoomId, text: String, threaded: Bool = true) async throws -> EventId {
            let relatesTo: mRelatesTo
            // Is this a threaded reply?  If so, extract the thread id from the parent event, or use its id as the new thread id.
            // Otherwise, just send the m.in_reply_to relation
            if threaded {
                if let relatedContent = event.content as? RelatedEventContent,
                   relatedContent.relationType == M_THREAD,
                   let threadId = relatedContent.relatedEventId
                {
                    relatesTo = mRelatesTo(relType: M_THREAD, eventId: threadId)

                } else {
                    relatesTo = mRelatesTo(relType: M_THREAD, eventId: event.eventId)
                }
            
            } else {
                relatesTo = mRelatesTo(inReplyTo: event.eventId)
            }
            
            let content = mTextContent(msgtype: M_TEXT,
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
