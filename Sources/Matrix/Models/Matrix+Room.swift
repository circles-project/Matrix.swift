//
//  Matrix+Room.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation
import GRDB

extension Matrix {
    public class Room: ObservableObject {
        public let roomId: RoomId
        public var session: Session
        
        public var type: String?
        public var version: String
        
        @Published public var name: String?
        @Published public var topic: String?
        @Published public var avatarUrl: MXC?
        @Published public var avatar: NativeImage?
        
        public let predecessorRoomId: RoomId?
        public let successorRoomId: RoomId?
        public let tombstoneEventId: EventId?
        
        @Published public var messages: Set<ClientEventWithoutRoomId>
        @Published public var localEchoEvent: Event?
        //@Published var earliestMessage: MatrixMessage?
        //@Published var latestMessage: MatrixMessage?
        private var stateEventsCache: [EventType: [ClientEventWithoutRoomId]]
        
        @Published public var highlightCount: Int = 0
        @Published public var notificationCount: Int = 0
        
        @Published public var joinedMembers: Set<UserId> = []
        @Published public var invitedMembers: Set<UserId> = []
        @Published public var leftMembers: Set<UserId> = []
        @Published public var bannedMembers: Set<UserId> = []
        @Published public var knockingMembers: Set<UserId> = []

        @Published public var encryptionParams: RoomEncryptionContent?
        
        public enum CodingKeys: String, CodingKey {
            case roomId
            case session
            case type
            case version
            case name
            case topic
            case avatarUrl
            case avatar
            case predecessorRoomId
            case successorRoomId
            case tombstoneEventId
            case messages
            case localEchoEvent
            case stateEventsCache
            case highlightCount
            case notificationCount
            case joinedMembers
            case invitedMembers
            case leftMembers
            case bannedMembers
            case knockingMembers
            case encryptionParams
        }
        
        public init(roomId: RoomId, session: Session, initialState: [ClientEventWithoutRoomId], initialMessages: [ClientEventWithoutRoomId] = []) throws {
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
                  let creationContent = creationEvent.content as? RoomCreateContent
            else {
                throw Matrix.Error("No m.room.create event")
            }
            self.type = creationContent.type
            self.version = creationContent.roomVersion ?? "1"
            self.predecessorRoomId = creationContent.predecessor?.roomId
            
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
        
        public required init(row: Row) throws {
            let decoder = JSONDecoder()
            guard let database = Matrix.Room.decodingDatabase,
                  let session = Matrix.Room.decodingSession else {
                throw Matrix.Error("Error decoding room object")
            }
            
            self.session = session
            self.stateEventsCache = [:]
            
            self.roomId = row[CodingKeys.roomId.stringValue]
            self.type = row[CodingKeys.type.stringValue]
            self.version = row[CodingKeys.version.stringValue]
            self.name = row[CodingKeys.name.stringValue]
            self.topic = row[CodingKeys.topic.stringValue]
            self.avatarUrl = row[CodingKeys.avatarUrl.stringValue]
            self.avatar = nil // Avatar will be fetched from URLSession cache
            self.predecessorRoomId = row[CodingKeys.predecessorRoomId.stringValue]
            self.successorRoomId = row[CodingKeys.successorRoomId.stringValue]
            self.tombstoneEventId = row[CodingKeys.tombstoneEventId.stringValue]
            self.messages = try Matrix.Room.loadMessages(roomId: self.roomId, database: database)

            if row[CodingKeys.localEchoEvent.stringValue] == nil {
                self.localEchoEvent = nil
            }
            else if let unwrapedEvent = try? decoder.decode(ClientEvent.self, from: row[CodingKeys.localEchoEvent.stringValue]) {
                self.localEchoEvent = unwrapedEvent
            }
            else if let unwrapedEvent = try? decoder.decode(ClientEventWithoutRoomId.self,
                                                                     from: row[CodingKeys.localEchoEvent.stringValue]) {
                self.localEchoEvent = unwrapedEvent
            }
            else if let unwrapedEvent = try? decoder.decode(MinimalEvent.self, from: row[CodingKeys.localEchoEvent.stringValue]) {
                self.localEchoEvent = unwrapedEvent
            }
            else if let unwrapedEvent = try? decoder.decode(StrippedStateEvent.self, from: row[CodingKeys.localEchoEvent.stringValue]) {
                self.localEchoEvent = unwrapedEvent
            }
            else if let unwrapedEvent = try? decoder.decode(ToDeviceEvent.self, from: row[CodingKeys.localEchoEvent.stringValue]) {
                self.localEchoEvent = unwrapedEvent
            }
            
            self.highlightCount = row[CodingKeys.highlightCount.stringValue]
            self.notificationCount = row[CodingKeys.notificationCount.stringValue]
            self.joinedMembers = try decoder.decode(Set<UserId>.self, from: row[CodingKeys.joinedMembers.stringValue])
            self.invitedMembers = try decoder.decode(Set<UserId>.self, from: row[CodingKeys.invitedMembers.stringValue])
            self.leftMembers = try decoder.decode(Set<UserId>.self, from: row[CodingKeys.leftMembers.stringValue])
            self.bannedMembers = try decoder.decode(Set<UserId>.self, from: row[CodingKeys.bannedMembers.stringValue])
            self.knockingMembers = try decoder.decode(Set<UserId>.self, from: row[CodingKeys.knockingMembers.stringValue])
            self.encryptionParams = try decoder.decode(RoomEncryptionContent.self, from: row[CodingKeys.encryptionParams.stringValue])
        }

        public func encode(to container: inout PersistenceContainer) throws {
            let encoder = JSONEncoder()
            guard let dataStore = Matrix.Room.decodingDataStore,
                  let database = Matrix.Room.decodingDatabase else {
                throw Matrix.Error("Error encoding room object")
            }
            
            container[CodingKeys.roomId.stringValue] = roomId
            // session not being encoded
            container[CodingKeys.type.stringValue] = type
            container[CodingKeys.version.stringValue] = version
            container[CodingKeys.name.stringValue] = name
            container[CodingKeys.topic.stringValue] = topic
            container[CodingKeys.avatarUrl.stringValue] = avatarUrl
            // avatar not being encoded
            container[CodingKeys.predecessorRoomId.stringValue] = predecessorRoomId
            container[CodingKeys.successorRoomId.stringValue] = successorRoomId
            container[CodingKeys.tombstoneEventId.stringValue] = tombstoneEventId
            try ClientEvent.saveAll(dataStore, objects: Array(self.messages), database: database, roomId: self.roomId)
            
            if let unwrapedEvent = localEchoEvent as? ClientEvent {
                container[CodingKeys.localEchoEvent.stringValue] = try encoder.encode(unwrapedEvent)
            }
            else if let unwrapedEvent = localEchoEvent as? ClientEventWithoutRoomId {
                container[CodingKeys.localEchoEvent.stringValue] = try encoder.encode(unwrapedEvent)
            }
            else if let unwrapedEvent = localEchoEvent as? MinimalEvent {
                container[CodingKeys.localEchoEvent.stringValue] = try encoder.encode(unwrapedEvent)
            }
            else if let unwrapedEvent = localEchoEvent as? StrippedStateEvent {
                container[CodingKeys.localEchoEvent.stringValue] = try encoder.encode(unwrapedEvent)
            }
            else if let unwrapedEvent = localEchoEvent as? ToDeviceEvent {
                container[CodingKeys.localEchoEvent.stringValue] = try encoder.encode(unwrapedEvent)
            }
            else {
                container[CodingKeys.localEchoEvent.stringValue] = nil
            }
            
            // stateEventsCache not being encoded
            container[CodingKeys.highlightCount.stringValue] = highlightCount
            container[CodingKeys.notificationCount.stringValue] = notificationCount
            container[CodingKeys.joinedMembers.stringValue] = try encoder.encode(joinedMembers)
            container[CodingKeys.invitedMembers.stringValue] = try encoder.encode(invitedMembers)
            container[CodingKeys.leftMembers.stringValue] = try encoder.encode(leftMembers)
            container[CodingKeys.bannedMembers.stringValue] = try encoder.encode(bannedMembers)
            container[CodingKeys.knockingMembers.stringValue] = try encoder.encode(knockingMembers)
            container[CodingKeys.encryptionParams.stringValue] = try encoder.encode(encryptionParams)
        }
                
        public func updateState(from events: [ClientEventWithoutRoomId]) {
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
        
        public func setDisplayName(newName: String) async throws {
            try await self.session.setDisplayName(roomId: self.roomId, name: newName)
        }
        
        public func setAvatarImage(image: NativeImage) async throws {
            try await self.session.setAvatarImage(roomId: self.roomId, image: image)
        }
        
        public func setTopic(newTopic: String) async throws {
            try await self.session.setTopic(roomId: self.roomId, topic: newTopic)
        }
        
        public func invite(userId: UserId, reason: String? = nil) async throws {
            try await self.session.inviteUser(roomId: self.roomId, userId: userId, reason: reason)
        }
        
        public func kick(userId: UserId, reason: String? = nil) async throws {
            try await self.session.kickUser(roomId: self.roomId, userId: userId, reason: reason)
        }
        
        public func ban(userId: UserId, reason: String? = nil) async throws {
            try await self.session.banUser(roomId: self.roomId, userId: userId, reason: reason)
        }
        
        public func leave(reason: String? = nil) async throws {
            try await self.session.leave(roomId: self.roomId, reason: reason)
        }
        
        public func canPaginate() -> Bool {
            // FIXME: TODO:
            return false
        }
        
        public func paginate(count: UInt = 25) async throws {
            throw Matrix.Error("Not implemented")
        }
        
        public var isEncrypted: Bool {
            self.encryptionParams != nil
        }
        
        public func sendText(text: String) async throws -> EventId {
            if !self.isEncrypted {
                let content = mTextContent(msgtype: .text, body: text)
                return try await self.session.sendMessageEvent(to: self.roomId, type: .mRoomMessage, content: content)
            }
            else {
                throw Matrix.Error("Not implemented")
            }
        }
        
        public func sendImage(image: NativeImage) async throws -> EventId {
            if !self.isEncrypted {
                guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
                    throw Matrix.Error("Couldn't create JPEG for image")
                }
                let mxc = try await self.session.uploadData(data: jpegData, contentType: "image/jpeg")
                let info = mImageInfo(h: Int(image.size.height),
                                      w: Int(image.size.width),
                                      mimetype: "image/jpeg",
                                      size: jpegData.count)
                let content = mImageContent(msgtype: .image, body: "\(mxc.mediaId).jpeg", info: info)
                return try await self.session.sendMessageEvent(to: self.roomId, type: .mRoomMessage, content: content)
            }
            else {
                throw Matrix.Error("Not implemented")
            }
        }
        
        public func sendVideo(fileUrl: URL, thumbnail: NativeImage?) async throws -> EventId {
            throw Matrix.Error("Not implemented")
        }
        
        public func sendReply(to eventId: EventId, text: String) async throws -> EventId {
            if !self.isEncrypted {
                let content = mTextContent(msgtype: .text,
                                           body: text,
                                           relates_to: mRelatesTo(in_reply_to: .init(event_id: eventId)))
                return try await self.session.sendMessageEvent(to: self.roomId, type: .mRoomMessage, content: content)
            }
            else {
                throw Matrix.Error("Not implemented")
            }
        }
        
        public func redact(eventId: EventId, reason: String?) async throws -> EventId {
            try await self.session.sendRedactionEvent(to: self.roomId, for: eventId, reason: reason)
        }
        
        public func report(eventId: EventId, score: Int, reason: String?) async throws {
            try await self.session.sendReport(for: eventId, in: self.roomId, score: score, reason: reason)
        }
        
        public func sendReaction(_ reaction: String, to eventId: EventId) async throws -> EventId {
            // FIXME: What about encryption?
            let content = ReactionContent(eventId: eventId, reaction: reaction)
            return try await self.session.sendMessageEvent(to: self.roomId, type: .mReaction, content: content)
        }
    }
}

extension RoomId: DatabaseValueConvertible {}

extension Matrix.Room: StorableDecodingContext, FetchableRecord, PersistableRecord {
    public static func createTable(_ store: GRDBDataStore) async throws {
        try await store.dbQueue.write { db in
            try db.create(table: databaseTableName) { t in
                t.primaryKey {
                    t.column(Matrix.Room.CodingKeys.roomId.stringValue, .text).notNull()
                }

                t.column(Matrix.Room.CodingKeys.type.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.version.stringValue, .text).notNull()
                t.column(Matrix.Room.CodingKeys.name.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.topic.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.avatarUrl.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.predecessorRoomId.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.successorRoomId.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.tombstoneEventId.stringValue, .text)
                t.column(Matrix.Room.CodingKeys.localEchoEvent.stringValue, .blob)
                t.column(Matrix.Room.CodingKeys.highlightCount.stringValue, .integer).notNull()
                t.column(Matrix.Room.CodingKeys.notificationCount.stringValue, .integer).notNull()
                t.column(Matrix.Room.CodingKeys.joinedMembers.stringValue, .blob).notNull()
                t.column(Matrix.Room.CodingKeys.invitedMembers.stringValue, .blob).notNull()
                t.column(Matrix.Room.CodingKeys.leftMembers.stringValue, .blob).notNull()
                t.column(Matrix.Room.CodingKeys.bannedMembers.stringValue, .blob).notNull()
                t.column(Matrix.Room.CodingKeys.knockingMembers.stringValue, .blob).notNull()
                t.column(Matrix.Room.CodingKeys.encryptionParams.stringValue, .blob)
            }
        }
    }
    
    public static let databaseTableName = "rooms"
    public static var decodingDataStore: GRDBDataStore?
    public static var decodingDatabase: Database?
    public static var decodingSession: Matrix.Session?
    
    public static func loadMessages(roomId: RoomId, database: Database) throws -> Set<ClientEventWithoutRoomId> {
        let events = try ClientEvent
            .filter(Column(ClientEvent.CodingKeys.roomId.stringValue) == roomId)
            .filter(Column(ClientEvent.CodingKeys.type.stringValue) == Matrix.EventType.mRoomMessage.rawValue)
            .fetchAll(database)
        let messages = Set(try events.map { try ClientEventWithoutRoomId(from: $0) })
        
        return messages
    }
}
