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
        @Published private(set) public var reactions: [String:Set<UserId>]?
        @Published private(set) public var replies: [Message]?
        
        public var isEncrypted: Bool
        
        private var fetchThumbnailTask: Task<Void,Swift.Error>?
        private var loadReactionsTask: Task<Int,Swift.Error>?
        
        private var logger: os.Logger
        
        public init(event: ClientEventWithoutRoomId, room: Room) {
            self.event = event
            self.room = room
            self.sender = room.session.getUser(userId: event.sender)
            self.reactions = nil
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
                }
            } else {
                self.isEncrypted = false
                self.encryptedEvent = nil
            }
            
            // Swift Phase 1 init is complete ///////////////////////////////////////////////
            
            // Initialize reactions
            if let allReactions = room.relations[M_REACTION]?[event.eventId] {
                self.reactions = [:]
                for reaction in allReactions {
                    if let content = reaction.content as? ReactionContent,
                       content.relationType == M_REACTION,
                       content.relatedEventId == event.eventId,
                       let key = content.relatesTo.key
                    {
                        // Ok, this is one we can use
                        if self.reactions?[key] == nil {
                            self.reactions?[key] = [reaction.sender.userId]
                        } else {
                            self.reactions?[key]!.insert(reaction.sender.userId)
                        }
                    }
                }
            }
        }
        
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
        
        public lazy var timestamp: Date = Date(timeIntervalSince1970: TimeInterval(event.originServerTS)/1000.0)
        
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
                if self.reactions == nil {
                    self.reactions = [:]
                }
                if reactions![key] == nil {
                    reactions![key] = [event.sender]
                } else {
                    reactions![key]!.insert(event.sender)
                }
            }
            logger.debug("Now we have \(self.reactions?.keys.count ?? 0) distinct reactions")
        }
        
        public func addReaction(message: Message) async {
            await self.addReaction(event: message.event)
        }
        
        public func addReply(message: Message) async {
            logger.debug("Adding reply message \(message.eventId)")
            if message.replyToEventId == self.eventId {
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
        
        public func loadReactions() {
            logger.debug("Loading reactions")
            
            if self.reactions != nil {
                logger.debug("We already have reactions; Not loading after all.")
                return
            }
            
            if let task = self.loadReactionsTask {
                logger.debug("Load reactions task is already running.  Not starting a new one.")
                return
            }
            
            self.loadReactionsTask = Task {
                logger.debug("Load reactions task starting...")
                let reactionEvents = try await self.room.loadReactions(for: self.eventId)
                logger.debug("Loaded \(reactionEvents.count) reactions")
                
                // If we didn't find anything, and we didn't have anything before,
                // set our local var to non-nil in order to signal that we've already tried loading
                if reactionEvents.isEmpty && self.reactions == nil {
                    logger.debug("Setting our local stored reactions to non-nil")
                    await MainActor.run {
                        self.reactions = [:]
                    }
                }
                
                logger.debug("Load reactions task is done")
                self.loadReactionsTask = nil
                return reactionEvents.count
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
                else if self.thumbnail == nil,
                   content.msgtype == .image,
                   let imageContent = content as? mImageContent
                {
                    logger.debug("Message \(self.eventId) does not have a thumbnail, but it is an m.image")

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
                }
                
                else {
                    logger.warning("Message \(self.eventId) doesn't seem to have any usable thumbnail")
                }
                
                self.fetchThumbnailTask = nil
                return
            }
        }
        
        public func sendReaction(_ reaction: String) async throws -> EventId {
            try await self.room.addReaction(reaction, to: eventId)
        }
    }
}

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
