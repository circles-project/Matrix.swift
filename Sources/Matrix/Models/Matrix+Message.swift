//
//  Matrix+Message.swift
//  
//
//  Created by Charles Wright on 3/20/23.
//

import Foundation

extension Matrix {
    public class Message: ObservableObject, Identifiable {
        @Published private(set) public var event: ClientEventWithoutRoomId
        private(set) public var encryptedEvent: ClientEventWithoutRoomId?
        public var room: Room
        public var sender: User
        
        @Published public var thumbnail: NativeImage?
        @Published public var reactions: [String:UInt]
        public var blur: NativeImage?
        
        public var isEncrypted: Bool
        
        private var fetchThumbnailTask: Task<Void,Swift.Error>?
        
        public init(event: ClientEventWithoutRoomId, room: Room) {
            self.event = event
            self.room = room
            self.sender = room.session.getUser(userId: event.sender)
            self.reactions = [:]
            
            // Initialize the blurhash
            if let messageContent = event.content as? Matrix.MessageContent,
               let blurhash = messageContent.blurhash,
               let thumbnailInfo = messageContent.thumbnail_info
            {
                self.blur = .init(blurHash: blurhash, size: CGSize(width: thumbnailInfo.w, height: thumbnailInfo.h))
            } else {
                self.blur = nil
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
        
        public var content: MessageContent? {
            event.content as? MessageContent
        }
        
        public var mimetype: String? {
            return content?.mimetype
        }
        
        public lazy var timestamp: Date = Date(timeIntervalSince1970: TimeInterval(event.originServerTS))
        
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
                
                // Now we also need to update our blurhash and thumbnail
                
                // Blurhash
                if let messageContent = event.content as? Matrix.MessageContent,
                   let blurhash = messageContent.blurhash,
                   let thumbnailInfo = messageContent.thumbnail_info
                {
                    self.blur = .init(blurHash: blurhash, size: CGSize(width: thumbnailInfo.w, height: thumbnailInfo.h))
                }
                
                // Thumbnail
                try await fetchThumbnail()
            }
        }
        
        public func fetchThumbnail() async throws {
            guard event.type == M_ROOM_MESSAGE,
                  let content = event.content as? MessageContent
            else {
                return
            }
            
            if let task = self.fetchThumbnailTask {
                try await task.value
                return
            }
            
            
            self.fetchThumbnailTask = Task {
                guard let info = content.thumbnail_info
                else {
                    self.fetchThumbnailTask = nil
                    return
                }
                
                if let encryptedFile = content.thumbnail_file {
                    guard let data = try? await room.session.downloadAndDecryptData(encryptedFile)
                    else {
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
                    guard let data = try? await room.session.downloadData(mxc: mxc)
                    else {
                        self.fetchThumbnailTask = nil
                        return
                    }
                    let image = NativeImage(data: data)
                    await MainActor.run {
                        self.thumbnail = image
                    }
                }
                self.fetchThumbnailTask = nil
            }
        }
        
        public func addReaction(_ reaction: String) async throws -> EventId {
            try await self.room.addReaction(reaction, to: eventId)
        }
    }
}
