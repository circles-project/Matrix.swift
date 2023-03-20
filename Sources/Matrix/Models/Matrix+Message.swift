//
//  Matrix+Message.swift
//  
//
//  Created by Charles Wright on 3/20/23.
//

import Foundation

extension Matrix {
    public class Message: ObservableObject {
        private(set) public var event: ClientEventWithoutRoomId
        public var room: Room
        public var sender: User
        
        @Published public var thumbnail: NativeImage?
        @Published public var reactions: [String:UInt]
        public var blurhash: NativeImage?
        
        private var fetchThumbnailTask: Task<Void,Swift.Error>?
        
        public init(event: ClientEventWithoutRoomId, room: Room) {
            self.event = event
            self.room = room
            self.sender = room.session.getUser(userId: event.sender)
            self.reactions = [:]
            
            // FIXME: Initialize the blurhash
        }
        
        public var eventId: EventId {
            event.eventId
        }
        
        public var roomId: RoomId {
            room.roomId
        }
        
        public var type: String {
            event.type
        }
        
        public var content: Codable {
            event.content
        }
        
        public var mimetype: String? {
            guard let content = event.content as? MessageContent
            else {
                return nil
            }
            return content.mimetype
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
    }
}
