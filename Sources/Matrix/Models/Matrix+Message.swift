//
//  Matrix+Message.swift
//  
//
//  Created by Charles Wright on 3/20/23.
//

import Foundation

extension Matrix {
    public class Message: ObservableObject, Identifiable {
        private(set) public var event: ClientEventWithoutRoomId
        public var room: Room
        public var sender: User
        
        @Published public var thumbnail: NativeImage?
        @Published public var reactions: [String:UInt]
        public var blurhash: NativeImage?
        
        public var isEncrypted: Bool
        
        private var fetchThumbnailTask: Task<Void,Swift.Error>?
        
        public init(event: ClientEventWithoutRoomId, room: Room) {
            self.event = event
            self.room = room
            self.sender = room.session.getUser(userId: event.sender)
            self.reactions = [:]
            
            // FIXME: Initialize the blurhash
            
            self.isEncrypted = event.type == M_ROOM_ENCRYPTED
            // FIXME: Now try to decrypt???
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
        
        public var content: MessageContent {
            event.content as! MessageContent
        }
        
        public var mimetype: String? {
            return content.mimetype
        }
        
        public lazy var timestamp: Date = Date(timeIntervalSince1970: TimeInterval(event.originServerTS))
        
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
