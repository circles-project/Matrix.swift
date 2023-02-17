//
//  GRDBDataStore.swift
//  
//
//  Created by Charles Wright on 2/14/23.
//

import Foundation

import GRDB

struct GRDBDataStore: DataStore {
    var session: Matrix.Session
    //let db: Database
    let dbQueue: DatabaseQueue
    var migrator: DatabaseMigrator
    
    // MARK: Migrations
    
    private mutating func runMigrations() throws {
        // First Migration -- Create the basic tables
        migrator.registerMigration("Create Tables") { db in
            
            try db.create(table: "events") { t in
                t.column("eventId", .text).unique().notNull()
                t.column("roomId", .text).notNull()
                t.column("sender", .text).notNull()
                t.column("type", .text).notNull()
                t.column("stateKey", .text)
                t.column("originServerTS", .integer).notNull()
                t.column("content", .blob).notNull()
                t.primaryKey(["eventId"])
            }
            
            try db.create(table: "rooms") { t in
                t.column("roomId", .text).unique().notNull()
                t.column("type", .text)
                t.column("version", .text).notNull()
                t.column("creator", .text).notNull()
                
                t.column("isEncrypted", .boolean).notNull()
                
                t.column("predecessorRoomId", .text)
                t.column("successorRoomId", .text)
                
                t.column("name", .text)
                t.column("avatarUrl", .text)
                t.column("topic", .text)
                
                t.column("notificationCount", .integer).notNull()
                t.column("highlightCount", .integer).notNull()
                
                t.column("minimalState", .blob).notNull()
                t.column("latestMessages", .blob).notNull()
                t.column("timestamp", .datetime).notNull()
                
                t.primaryKey(["roomId"])
            }
            
            // User profiles are explicitly key-value stores in order to
            // support more flexible profiles in the future.
            try db.create(table: "userProfiles") { t in
                t.column("userId", .text).notNull()
                t.column("key", .text).notNull()
                t.column("value", .text).notNull()
                t.primaryKey(["userId", "key"])
            }
            
            // We're cheating a little bit here, using the same table for
            // both room-level account data and global account data.
            // Use a roomId of "" for global account data that is not
            // specific to any given room.
            // In the Swift code, we would use `nil`, but SQL doesn't
            // like to have NULLs in primary keys.
            try db.create(table: "accountData") { t in
                t.column("userId", .text).notNull()
                t.column("roomId", .text).notNull()
                t.column("type", .text).notNull()
                t.column("content", .blob)
                t.primaryKey(["userId", "roomId", "type"])
            }
        }
        
        try migrator.migrate(dbQueue)
    }
    
    // MARK: init()
    
    init(queue: DatabaseQueue, session: Matrix.Session) async throws {
        //dbQueue = try DatabaseQueue(path: path)
        self.dbQueue = queue
        self.session = session
        self.migrator = DatabaseMigrator()
        
        try runMigrations()
        
    }
    
    // MARK: Events
    
    func save(events: [ClientEvent]) async throws {
        try await dbQueue.write { db in
            for event in events {
                try event.save(db)
            }
        }
    }
    
    func save(events: [ClientEventWithoutRoomId], in roomId: RoomId) async throws {
        let clientEvents = try events.map {
            try ClientEvent(from: $0, roomId: roomId)
        }
        try await dbQueue.write { db in
            for clientEvent in clientEvents {
                try clientEvent.save(db)
            }
        }
    }
    
    func loadEvents(for roomId: RoomId,
                    limit: Int = 25, offset: Int? = nil
    ) async throws -> [ClientEvent] {
        let roomIdColumn = ClientEvent.Columns.roomId
        let timestampColumn = ClientEvent.Columns.originServerTS
        let events = try await dbQueue.read { db -> [ClientEvent] in
            try ClientEvent
                .filter(roomIdColumn == "\(roomId)")
                .order(timestampColumn.desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
        return events
    }
    
    func loadEvents(for roomId: RoomId, of types: [Matrix.EventType],
                    limit: Int = 25, offset: Int? = nil
    ) async throws -> [ClientEvent] {
        let roomIdColumn = ClientEvent.Columns.roomId
        let typeColumn = ClientEvent.Columns.type
        let timestampColumn = ClientEvent.Columns.originServerTS
        
        let typeStrings = types.map { "\($0)" }
        
        let events = try await dbQueue.read { db -> [ClientEvent] in
            try ClientEvent
                .filter(roomIdColumn == "\(roomId)")
                .filter(typeStrings.contains(typeColumn))
                .order(timestampColumn.desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
        return events
    }
    
    func loadStateEvents(for roomId: RoomId,
                         limit: Int = 25, offset: Int? = nil
    ) async throws -> [ClientEvent] {
        let roomIdColumn = ClientEvent.Columns.roomId
        let stateKeyColumn = ClientEvent.Columns.stateKey
        let timestampColumn = ClientEvent.Columns.originServerTS
        let events = try await dbQueue.read { db -> [ClientEvent] in
            try ClientEvent
                .filter(roomIdColumn == "\(roomId)")
                .filter(stateKeyColumn != nil)
                .order(timestampColumn.desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
        return events
    }
    
    // MARK: Rooms
    
    func loadRooms(limit: Int=100, offset: Int? = nil) async throws -> [Matrix.Room] {
        let timestampColumn = RoomRecord.Columns.timestamp
        let records = try await dbQueue.read { db -> [RoomRecord] in
            try RoomRecord
                .order(timestampColumn.desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
        let rooms = try records.compactMap { rec in
            let decoder = JSONDecoder()
            let stateEvents = try decoder.decode([ClientEventWithoutRoomId].self, from: rec.minimalState)
            let messageEvents = try decoder.decode([ClientEventWithoutRoomId].self, from: rec.latestMessages)
            return try? Matrix.Room(roomId: rec.roomId, session: self.session, initialState: stateEvents, initialMessages: messageEvents)
        }
        return rooms
    }
    
    func loadRooms(of type: String?, limit: Int=100, offset: Int?=nil) async throws -> [Matrix.Room] {
        let timestampColumn = RoomRecord.Columns.timestamp
        let typeColumn = RoomRecord.Columns.type
        let records = try await dbQueue.read { db -> [RoomRecord] in
            try RoomRecord
                .filter(typeColumn == type)
                .order(timestampColumn.desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
        let rooms = try records.compactMap { rec in
            let decoder = JSONDecoder()
            let stateEvents = try decoder.decode([ClientEventWithoutRoomId].self, from: rec.minimalState)
            let messageEvents = try decoder.decode([ClientEventWithoutRoomId].self, from: rec.latestMessages)
            return try? Matrix.Room(roomId: rec.roomId, session: self.session, initialState: stateEvents, initialMessages: messageEvents)
        }
        return rooms
    }
    
    func saveRooms(_ rooms: [Matrix.Room]) async throws {
        let records = try rooms.map { room in
            let encoder = JSONEncoder()
            let stateData = try encoder.encode(room.minimalState)
            let lastMessage = room.lastMessage
            let messageData = try encoder.encode([lastMessage].compactMap({$0}))
            
            return RoomRecord(roomId: room.roomId,
                       type: room.type,
                       version: room.version,
                       creator: room.creator,
                       isEncrypted: room.isEncrypted,
                       predecessorRoomId: room.predecessorRoomId,
                       successorRoomId: room.successorRoomId,
                       name: room.name,
                       avatarUrl: room.avatarUrl,
                       topic: room.topic,
                       notificationCount: room.notificationCount,
                       highlightCount: room.highlightCount,
                       minimalState: stateData,
                       latestMessages: messageData,
                       timestamp: lastMessage?.originServerTS ?? 0)
        }
        try await dbQueue.write { db in
            for record in records {
                try record.save(db)
            }
        }
    }
    
    // MARK: User profiles
    
    func loadProfileItem(_ item: String, for userId: UserId) async throws -> String? {
        let userIdColumn = UserProfileRecord.Columns.userId
        let keyColumn = UserProfileRecord.Columns.key
        let record = try await dbQueue.read { db -> UserProfileRecord? in
            try UserProfileRecord
                .filter(userIdColumn == "\(userId)")
                .filter(keyColumn == item)
                .fetchOne(db)
        }
        return record?.value
    }
    
    func loadDisplayname(for userId: UserId) async throws -> String? {
        try await loadProfileItem("displayname", for: userId)
    }
    
    func loadAvatarUrl(for userId: UserId) async throws -> MXC? {
        guard let string = try await loadProfileItem("avatar_url", for: userId)
        else {
            return nil
        }
        return MXC(string)
    }
    
    func loadStatusMessage(for userId: UserId) async throws -> String? {
        try await loadProfileItem("status", for: userId)
    }
    
    func saveProfileItem(_ item: String, _ value: String, for userId: UserId) async throws {
        let record = UserProfileRecord(userId: userId, key: item, value: value)
        try await dbQueue.write { db in
            try record.save(db)
        }
    }
    
    func saveDisplayname(_ name: String, for userId: UserId) async throws {
        try await saveProfileItem("displayname", name, for: userId)
    }
    
    func saveAvatarUrl(_ url: MXC, for userId: UserId) async throws {
        try await saveProfileItem("avatar_url", url.description, for: userId)
    }
    
    func saveStatusMessage(_ msg: String, for userId: UserId) async throws {
        try await saveProfileItem("status", msg, for: userId)
    }
    
    // MARK: Account data
    
    func loadAccountData(for userId: UserId, of type: String, in roomId: RoomId? = nil) async throws -> Codable {
        throw Matrix.Error("Not Implemented")
    }
}
