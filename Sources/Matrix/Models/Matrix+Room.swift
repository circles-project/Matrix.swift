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
        @Published var avatarUrl: String?
        @Published var avatar: NativeImage?
        
        let predecessorRoomId: RoomId?
        let successorRoomId: RoomId?
        let tombstoneEventId: EventId?
        
        @Published var messages: Set<ClientEvent>
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

        init(roomId: RoomId, session: Session, initialState: [ClientEventWithoutRoomId], initialMessages: [ClientEvent] = []) throws {
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
                self.avatarUrl = avatarContent.url
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
            
        }
    }
}
