//
//  Matrix+Room.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation

extension Matrix {
    class Room: ObservableObject {
        let roomId: RoomId
        let session: Session
        
        let type: String?
        let version: String
        
        @Published var name: String?
        @Published var topic: String?
        @Published var avatarUrl: MXC?
        @Published var avatar: NativeImage?
        
        let predecessorRoomId: RoomId?
        let successorRoomId: RoomId?
        let tombstoneEventId: EventId?
        
        @Published var messages: Set<ClientEventWithoutRoomId>
        @Published var localEchoEvent: Event?
        //@Published var earliestMessage: MatrixMessage?
        //@Published var latestMessage: MatrixMessage?
        private var stateEventsCache: [EventType: [ClientEventWithoutRoomId]]
        
        @Published var highlightCount: Int = 0
        @Published var notificationCount: Int = 0
        
        @Published var joinedMembers: Set<UserId> = []
        @Published var invitedMembers: Set<UserId> = []
        @Published var leftMembers: Set<UserId> = []
        @Published var bannedMembers: Set<UserId> = []
        @Published var knockingMembers: Set<UserId> = []

        @Published var encryptionParams: RoomEncryptionContent?
        
        init(roomId: RoomId, session: Session, initialState: [ClientEventWithoutRoomId], initialMessages: [ClientEventWithoutRoomId] = []) throws {
            self.roomId = roomId
            self.session = session
            self.messages = Set(initialMessages)
            
            self.stateEventsCache = [:]
            for event in initialState {
                var cache = stateEventsCache[event.type] ?? []
                cache.append(event)
                stateEventsCache[event.type] = cache
            }
            
            guard let creationEvent = stateEventsCache[.mRoomCreate]?.first,
                  let creationContent = creationEvent.content as? CreateContent
            else {
                throw Matrix.Error("No m.room.create event")
            }
            self.type = creationContent.type
            self.version = creationContent.roomVersion
            self.predecessorRoomId = creationContent.predecessor.roomId
            
            if let tombstoneEvent = stateEventsCache[.mRoomTombstone]?.last,
               let tombstoneContent = tombstoneEvent.content as? RoomTombstoneContent
            {
                self.tombstoneEventId = tombstoneEvent.eventId
                self.successorRoomId = tombstoneContent.replacementRoom
            } else {
                self.tombstoneEventId = nil
                self.successorRoomId = nil
            }
            
            if let nameEvent = stateEventsCache[.mRoomName]?.last,
               let nameContent = nameEvent.content as? RoomNameContent
            {
                self.name = nameContent.name
            }
            
            if let avatarEvent = stateEventsCache[.mRoomAvatar]?.last,
               let avatarContent = avatarEvent.content as? RoomAvatarContent
            {
                self.avatarUrl = avatarContent.mxc
            }
            
            if let topicEvent = stateEventsCache[.mRoomTopic]?.last,
               let topicContent = topicEvent.content as? RoomTopicContent
            {
                self.topic = topicContent.topic
            }
            
            for memberEvent in stateEventsCache[.mRoomMember] ?? [] {
                if let memberContent = memberEvent.content as? RoomMemberContent,
                   let stateKey = memberEvent.stateKey,
                   let memberUserId = UserId(stateKey)
                {
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
            }
            
            let powerLevelsEvents = stateEventsCache[.mRoomPowerLevels] ?? []
            for powerLevelsEvent in powerLevelsEvents {
                guard powerLevelsEvent.content is RoomPowerLevelsContent
                else {
                    throw Matrix.Error("Couldn't parse room power levels")
                }
            }
            // Do we need to *do* anything with the powerlevels for now?
            // No?
            
            if let encryptionEvent = stateEventsCache[.mRoomEncryption]?.last,
               let encryptionContent = encryptionEvent.content as? RoomEncryptionContent
            {
                self.encryptionParams = encryptionContent
            } else {
                self.encryptionParams = nil
            }
            
        }
        
        func updateState(from events: [ClientEventWithoutRoomId]) {
            for event in events {
                
                switch event.type {
                
                case .mRoomAvatar:
                    guard let content = event.content as? RoomAvatarContent
                    else {
                        continue
                    }
                    if self.avatarUrl != content.mxc {
                        self.avatarUrl = content.mxc
                        // FIXME: Also fetch the new avatar image
                    }
                    
                case .mRoomName:
                    guard let content = event.content as? RoomNameContent
                    else {
                        continue
                    }
                    self.name = content.name
                    
                case .mRoomTopic:
                    guard let content = event.content as? RoomTopicContent
                    else {
                        continue
                    }
                    self.topic = content.topic
                    
                case .mRoomMember:
                    guard let content = event.content as? RoomMemberContent,
                          let stateKey = event.stateKey,
                          let userId = UserId(stateKey)
                    else {
                        continue
                    }
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
                    
                case .mRoomEncryption:
                    guard let content = event.content as? RoomEncryptionContent
                    else {
                        continue
                    }
                    self.encryptionParams = content
                    
                default:
                    print("Not handling event of type \(event.type)")
                    
                } // end switch event.type
                
            } // end func updateState()
        }
        
        func setDisplayName(newName: String) async throws {
            try await self.session.setDisplayName(roomId: self.roomId, name: newName)
        }
        
        func setAvatarImage(image: NativeImage) async throws {
            try await self.session.setAvatarImage(roomId: self.roomId, image: image)
        }
    }
}
