//
//  Matrix+Message.swift
//
//
//  Created by Charles Wright on 3/20/23.
//

import Foundation
import os

extension Matrix {
    public class Message: ObservableObject, Identifiable {
        @Published private(set) public var event: ClientEventWithoutRoomId
        private(set) public var encryptedEvent: ClientEventWithoutRoomId?
        public var room: Room
        public var sender: User
        
        @Published public var thumbnail: NativeImage?
        @Published private(set) public var reactions: [String:Set<UserId>]
        @Published private(set) public var replies: [Message]?
        @Published private(set) public var replacement: Message?
        
        public var isEncrypted: Bool
        
        private var fetchThumbnailTask: Task<Void,Swift.Error>?
        private var loadReactionsTask: Task<Int,Swift.Error>?
        
        private var logger: os.Logger
        
        public init(event: ClientEventWithoutRoomId, room: Room) {
            self.event = event
            self.room = room
            self.sender = room.session.getUser(userId: event.sender)
            self.reactions = [:]
            self.replies = nil
            
            self.logger = os.Logger(subsystem: "matrix", category: "message \(event.eventId)")
            
            // Initialize the thumbnail
            if let messageContent = event.content as? Matrix.MessageContent {
                
                // Try thumbhash first
                if let thumbhashString = messageContent.thumbhash,
                   let thumbhashData = Data(base64Encoded: thumbhashString)
                {
                    self.thumbnail = thumbHashToImage(hash: thumbhashData)
                } else if let blurhash = messageContent.blurhash,
                          let thumbnailInfo = messageContent.thumbnail_info
                {
                    // Initialize from the blurhash
                    self.thumbnail = .init(blurHash: blurhash, size: CGSize(width: thumbnailInfo.w, height: thumbnailInfo.h))
                } else {
                    // No thumbhash, no blurhash, so we have nothing until we can fetch the real image
                    self.thumbnail = nil
                }
            }
            
            if event.type == M_ROOM_ENCRYPTED {
                self.isEncrypted = true
                self.encryptedEvent = event
                
                // Now try to decrypt
                let _ = Task {
                    try await decrypt()
                    
                    // Once we're decrypted, we may need to try again to update our relations to other events
                    // For example, event replacements are only allowed for messages of the same type, so we can't process those until we've decrypted
                    await self.room.updateRelations(events: [self.event])
                }
            } else {
                self.isEncrypted = false
                self.encryptedEvent = nil
            }
            
            // Swift Phase 1 init is complete ///////////////////////////////////////////////
            
            // Initialize reactions
            if let allReactions = room.relations[M_REACTION]?[event.eventId] {
                for reaction in allReactions {
                    if let content = reaction.content as? ReactionContent,
                       content.relationType == M_REACTION,
                       content.relatedEventId == event.eventId,
                       let key = content.relatesTo.key
                    {
                        // Ok, this is one we can use
                        if self.reactions[key] == nil {
                            self.reactions[key] = [reaction.sender.userId]
                        } else {
                            self.reactions[key]!.insert(reaction.sender.userId)
                        }
                    }
                }
            }
        }
        
        // MARK: Computed Properties
        
        public var eventId: EventId {
            event.eventId
        }
        
        public var id: String {
            "\(eventId)"
        }
        
        public var roomId: RoomId {
            room.roomId
        }
        
        public var type: String {
            event.type
        }
        
        public var stateKey: String? {
            event.stateKey
        }
        
        public var content: Codable? {
            event.content
        }
        
        public var mimetype: String? {
            if let content = self.content as? MessageContent {
                return content.mimetype
            } else {
                return nil
            }
        }
        
        public var timestamp: Date {
            event.timestamp
        }
        
        public var relatedEventId: EventId? {
            if let content = event.content as? RelatedEventContent {
                return content.relatedEventId
            }
            return nil
        }
        
        public var relationType: String? {
            if let content = event.content as? RelatedEventContent {
                return content.relationType
            }
            return nil
        }
        
        public var replyToEventId: EventId? {
            if let content = event.content as? RelatedEventContent {
                return content.replyToEventId
            }
            return nil
        }
        
        public var threadId: EventId? {
            if self.relationType == M_THREAD {
                return self.relatedEventId
            }
            return nil
        }
        
        public var thread: Set<Message>? {
            self.room.threads[self.eventId]
        }
        
        public var iCanRedact: Bool {
            self.sender.userId == self.room.session.creds.userId || self.room.iCanRedact
        }
        
        public var mentionsMe: Bool {
            if let content = self.content as? Matrix.MessageContent {
                return content.mentions(userId: self.room.session.creds.userId)
            } else {
                return false
            }
        }
        
        // MARK: Reactions
        
        // https://github.com/uhoreg/matrix-doc/blob/aggregations-reactions/proposals/2677-reactions.md
        public func addReaction(event: ClientEventWithoutRoomId) async {
            logger.debug("Adding reaction message \(event.eventId)")
            guard let content = event.content as? ReactionContent,
                  content.relatesTo.eventId == self.eventId,
                  let key = content.relatesTo.key
            else {
                logger.error("Not adding reaction: Couldn't parse reaction message content")
                return
            }
            await MainActor.run {
                if reactions[key] == nil {
                    reactions[key] = [event.sender]
                } else {
                    reactions[key]!.insert(event.sender)
                }
            }
            logger.debug("Now we have \(self.reactions.keys.count) distinct reactions")
        }
        
        public func addReaction(message: Message) async {
            await self.addReaction(event: message.event)
        }
        
        public func removeReaction(event: ClientEventWithoutRoomId) async {
            guard let content = event.content as? ReactionContent,
                  let key = content.relatesTo.key
            else {
                logger.error("Can't remove reaction: Event \(event.eventId) is not a reaction")
                return
            }
            
            await MainActor.run {
                reactions[key]?.remove(event.sender)
            }
        }
                
        public func removeReaction(message: Message) async {
            await self.removeReaction(event: message.event)
        }
        
        public func sendRemoveReaction(_ emoji: String) async throws {
            let userId = room.session.creds.userId
            guard reactions[emoji]?.contains(userId) ?? false
            else {
                logger.error("Can't remove reaction \(emoji) because there isn't one from us")
                return
            }
            
            // Now we have to go digging in the room's data to find the original event
            guard let messages = room.relations[M_ANNOTATION]?[eventId]?.filter({$0.type == M_REACTION})
            else {
                logger.error("Can't find any reaction events")
                return
            }
            logger.debug("Found \(messages.count) reactions")
            
            guard let myMessage = messages.first(where: { message in
                      guard message.sender.userId == userId,
                            let content = message.content as? ReactionContent,
                            content.relatesTo.key == emoji
                      else {
                          return false
                      }
                      return true
                  })
            else {
                logger.error("Can't find my reaction message for \(emoji)")
                return
            }
            
            // Redact the original event to remove the reaction
            try await self.room.redact(eventId: myMessage.eventId)
            
        }
        
        public func loadReactions() {
            logger.debug("Loading reactions")
            
            if let task = self.loadReactionsTask {
                logger.debug("Load reactions task is already running.  Not starting a new one.")
                return
            }
            
            self.loadReactionsTask = Task {
                logger.debug("Load reactions task starting...")
                let reactionEvents = try await self.room.loadReactions(for: self.eventId)
                logger.debug("Loaded \(reactionEvents.count) reactions")
                
                for event in reactionEvents {
                    await addReaction(event: event)
                }
                
                logger.debug("Load reactions task is done")
                self.loadReactionsTask = nil
                return reactionEvents.count
            }
        }
        
        public func sendReaction(_ reaction: String) async throws -> EventId {
            try await self.room.addReaction(reaction, to: eventId)
        }
        
        // MARK: Replies
        
        public func addReply(message: Message) async {
            logger.debug("Adding reply message \(message.eventId)")
            if message.replyToEventId == self.eventId || message.relatedEventId == self.eventId {
                if let replies = self.replies,
                   replies.contains(message)
                {
                    logger.debug("We already have this one; Not adding \(message.eventId) as a reply")
                    return
                }
                await MainActor.run {
                    if self.replies == nil {
                        self.replies = []
                    }
                    self.replies!.append(message)
                }
            }
            logger.debug("Now we have \(self.replies?.count ?? 0) replies")
        }
        
        public func removeReply(message: Message) async {
            logger.debug("Removing reply message \(message.eventId)")
            await MainActor.run {
                self.replies?.removeAll(where: { $0.eventId == message.eventId })
            }
        }
        
        // MARK: Replacements
        
        // https://spec.matrix.org/v1.8/client-server-api/#event-replacements
        public func addReplacement(message: Message) async throws {
            logger.debug("Adding replacement message \(message.eventId)")
            guard message.roomId == self.roomId
            else {
                logger.error("Message \(message.eventId) cannot replace \(self.eventId) -- roomId doesn't match")
                throw Matrix.Error("Invalid replacement: RoomId mismatch")
            }
            guard message.type == self.type
            else {
                logger.error("Message \(message.eventId) cannot replace \(self.eventId) -- message type doesn't match (\(message.type) vs \(self.type)")
                throw Matrix.Error("Invalid replacement: Type mismatch")
            }
            guard message.sender == self.sender
            else {
                logger.error("Message \(message.eventId) cannot replace \(self.eventId) -- message sender doesn't match (\(message.sender.userId) vs \(self.sender.userId)")
                throw Matrix.Error("Invalid replacement: Sender mismatch")

            }
            guard message.stateKey == nil,
                  self.stateKey == nil
            else {
                logger.error("Message \(message.eventId) cannot replace \(self.eventId) -- Can't replace state events")
                throw Matrix.Error("Invalid replacement: State event(s)")
            }
            guard self.relationType != M_REPLACE
            else {
                logger.error("Message \(message.eventId) cannot replace \(self.eventId) -- Can't replace a replacement")
                throw Matrix.Error("Invalid replacement: Existing message is itself a replacement")
            }
            
            // Do we already have a replacement for this event?
            // And if so, should we keep it in favor of the new one?
            if let oldReplacement = self.replacement {
                if oldReplacement.timestamp > message.timestamp
                {
                    logger.debug("Not replacing with \(message.eventId) -- Current replacement \(oldReplacement.eventId) is more recent")
                    return
                }
                
                if oldReplacement.timestamp == message.timestamp,
                   oldReplacement.eventId > message.eventId
                {
                    logger.debug("Not replacing with \(message.eventId) -- Current replacement \(oldReplacement.eventId) has higher eventId")
                    return
                }
            }
            
            await MainActor.run {
                self.replacement = message
            }
        }
        
        // MARK: decrypt
        
        public func decrypt() async throws {
            guard self.event.type == M_ROOM_ENCRYPTED
            else {
                // Already decrypted!
                return
            }
            
            if let decryptedEvent = try? self.room.session.decryptMessageEvent(self.event, in: self.room.roomId) {
                await MainActor.run {
                    self.event = decryptedEvent
                }
                
                // Now we also need to update our thumbnail
                // Look for a placeholder
                if let messageContent = event.content as? Matrix.MessageContent {
                    if let thumbhashString = messageContent.thumbhash,
                       let thumbhashData = Data(base64Encoded: thumbhashString)
                    {
                        // Use the thumbhash if it's available
                        await MainActor.run {
                            self.thumbnail = thumbHashToImage(hash: thumbhashData)
                        }
                    } else if let blurhash = messageContent.blurhash,
                              let thumbnailInfo = messageContent.thumbnail_info
                    {
                        // Fall back to blurhash
                        await MainActor.run {
                            self.thumbnail = .init(blurHash: blurhash, size: CGSize(width: thumbnailInfo.w, height: thumbnailInfo.h))
                        }
                    } else {
                        await MainActor.run {
                            self.thumbnail = nil
                        }
                    }

                }
                
                // Thumbnail
                try await fetchThumbnail()
            }
        }
        
        // MARK: fetch thumbnail
        
        public func fetchThumbnail() async throws {
            logger.debug("Fetching thumbnail for message \(self.eventId)")
            guard event.type == M_ROOM_MESSAGE,
                  let content = event.content as? MessageContent
            else {
                logger.debug("Event \(self.eventId) is not an m.room.message -- Not fetching thumbnail")
                return
            }
            
            if let task = self.fetchThumbnailTask {
                logger.debug("Message \(self.eventId) is already fetching its thumbnail.  Waiting on that task.")
                try await task.value
                return
            }
            
            
            self.fetchThumbnailTask = Task {
                logger.debug("Starting fetch thumbnail task for message \(self.eventId)")
                if let info = content.thumbnail_info {
                    logger.debug("Message \(self.eventId) has a thumbnail")
                    
                    if let encryptedFile = content.thumbnail_file {
                        logger.debug("Message \(self.eventId) has an encrypted thumbnail")

                        guard let data = try? await room.session.downloadAndDecryptData(encryptedFile)
                        else {
                            logger.error("Failed to download encrypted thumbnail for \(self.eventId)")
                            self.fetchThumbnailTask = nil
                            return
                        }
                        let image = NativeImage(data: data)
                        await MainActor.run {
                            self.thumbnail = image
                        }
                        self.fetchThumbnailTask = nil
                        return
                    }
                    
                    if let mxc = content.thumbnail_url {
                        logger.debug("Message \(self.eventId) has a plaintext thumbnail")

                        guard let data = try? await room.session.downloadData(mxc: mxc)
                        else {
                            logger.error("Failed to download plaintext thumbnail for \(self.eventId)")
                            self.fetchThumbnailTask = nil
                            return
                        }
                        let image = NativeImage(data: data)
                        await MainActor.run {
                            self.thumbnail = image
                        }
                        self.fetchThumbnailTask = nil
                        return
                    }
                }
                
                // m.image is a special case - If it doesn't have a thumbnail, we can just use the full-resolution image
                else if content.msgtype == M_IMAGE
                {
                    logger.debug("Message \(self.eventId) does not have a thumbnail, but it is an m.image")

                    guard let imageContent = event.content as? mImageContent
                    else {
                        logger.error("Failed to parse event \(self.eventId) content as an m.image")
                        self.fetchThumbnailTask = nil
                        return
                    }

                    if let encryptedFile = imageContent.file {
                        logger.debug("Message \(self.eventId) has an encrypted image")

                        guard let data = try? await room.session.downloadAndDecryptData(encryptedFile)
                        else {
                            logger.error("Failed to download encrypted image for \(self.eventId)")
                            self.fetchThumbnailTask = nil
                            return
                        }
                        let image = NativeImage(data: data)
                        await MainActor.run {
                            self.thumbnail = image
                        }
                        self.fetchThumbnailTask = nil
                        return
                    }
                    
                    if let mxc = imageContent.url {
                        logger.debug("Message \(self.eventId) has a plaintext image")

                        guard let data = try? await room.session.downloadData(mxc: mxc)
                        else {
                            logger.error("Failed to download plaintext image for \(self.eventId)")
                            self.fetchThumbnailTask = nil
                            return
                        }
                        let image = NativeImage(data: data)
                        await MainActor.run {
                            self.thumbnail = image
                        }
                        self.fetchThumbnailTask = nil
                        return
                    }
                    
                    logger.error("Message \(self.eventId) appears to be an m.image without any actual image")
                    self.fetchThumbnailTask = nil
                    return
                }
                
                else {
                    logger.warning("Message \(self.eventId) doesn't seem to have any usable thumbnail")
                    self.fetchThumbnailTask = nil
                    return
                }
                
            } // end Task
        } // end public func fetchThumbnail
        
    } // end public class Message
} // end extension Matrix

extension Matrix.Message: Equatable {
    public static func == (lhs: Matrix.Message, rhs: Matrix.Message) -> Bool {
        lhs.eventId == rhs.eventId && lhs.type == rhs.type
    }
}

extension Matrix.Message: Hashable {
    public func hash(into hasher: inout Hasher) {
        self.event.hash(into: &hasher)
    }
}
