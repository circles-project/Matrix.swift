//
//  Matrix+StrippedStateRoom.swift
//  
//
//  Created by Charles Wright on 3/23/23.
//

import Foundation

extension Matrix {
    public class StrippedStateRoom: ObservableObject {
        public var session: Session
        public let roomId: RoomId
        public let state: [String: [String:StrippedStateEvent]]  // From /sync
        public let creator: UserId
        @Published public var avatar: NativeImage?
                        
        public init(session: Session, roomId: RoomId, stateEvents: [StrippedStateEvent]) throws {
            
            self.session = session
            self.roomId = roomId

            var state: [String: [String:StrippedStateEvent]] = [:]
            
            for event in stateEvents {
                var dict = state[event.type] ?? [:]
                dict[event.stateKey] = event
                state[event.type] = dict
            }
            self.state = state
            
            guard let event = state[M_ROOM_CREATE]?[""],
                  let content = event.content as? RoomCreateContent
            else {
                throw Matrix.Error("No creation event for room \(roomId)")
            }
            self.creator = event.sender
            
            self.avatar = nil
        }
        
        // MARK: Computed properties
        
        public var type: String? {
            guard let event = state[M_ROOM_CREATE]?[""],
                  let content = event.content as? RoomCreateContent
            else {
                return nil
            }
            return content.type
        }
        
        public var version: String {
            guard let event = state[M_ROOM_CREATE]?[""],
                  let content = event.content as? RoomCreateContent
            else {
                return "1"
            }
            return content.roomVersion ?? "1"
        }
        
        public var predecessorRoomId: RoomId? {
            guard let event = state[M_ROOM_CREATE]?[""],
                  let content = event.content as? RoomCreateContent
            else {
                return nil
            }
            return content.predecessor?.roomId
        }
        
        public var encrypted: Bool {
            guard let event = state[M_ROOM_ENCRYPTION]?[""],
                  let content = event.content as? RoomEncryptionContent
            else {
                return false
            }
            return true
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
        
        public var members: [UserId] {
            guard let events = state[M_ROOM_MEMBER]?.values.filter( { event in
                guard let content = event.content as? RoomMemberContent
                else { return false }
                return content.membership == .join
            })
            else {
                return []
            }
            
            return events.compactMap { event -> UserId? in
                guard let userId = UserId(event.stateKey)
                else { return nil }
                return userId
            }
        }

        // MARK: Join
        
        public func join(reason: String? = nil) async throws {
            try await session.join(roomId: roomId, reason: reason)
        }

        // MARK: Get avatar image
        
        public func getAvatarImage() async throws {
            guard let mxc = self.avatarUrl else {
                return
            }
            
            let data = try await session.downloadData(mxc: mxc)
            let image = NativeImage(data: data)
            
            await MainActor.run {
                self.avatar = image
            }
        }
    }

}

extension Matrix.StrippedStateRoom: Identifiable {
    public var id: String {
        "\(self.roomId)"
    }
}
