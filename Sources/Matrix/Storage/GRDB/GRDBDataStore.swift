//
//  GRDBDataStore.swift
//  
//
//  Created by Charles Wright on 2/14/23.
//

import Foundation

import GRDB

public struct GRDBDataStore: DataStore {
    //let db: Database
    //let dbQueue: DatabaseQueue
    let database: DatabaseWriter & DatabaseReader // This might be a DatabaseQueue or a DatabasePool, depending on if we're in-memory or persistent
    var migrator: DatabaseMigrator
        
    // MARK: Migrations
    
    private mutating func runMigrations() throws {
        // First Migration -- Create the basic tables
        migrator.registerMigration("Create Tables") { db in
            
            // Events database
            try db.create(table: "timeline") { t in
                t.column("event_id", .text).unique().notNull()
                t.column("room_id", .text).notNull()
                t.column("sender", .text).notNull()
                t.column("type", .text).notNull()
                t.column("state_key", .text)
                t.column("origin_server_ts", .integer).notNull()
                t.column("content", .blob).notNull()
                t.column("unsigned", .blob)
                t.column("rel_type", .text)
                t.column("related_eventid", .text)
                t.primaryKey(["event_id"])
            }
            
            // Room state events
            // This is almost the same schema as `timeline`, except:
            // * stateKey is NOT NULL
            // * primary key is (roomId, type, stateKey) instead of eventId
            try db.create(table: "state") { t in
                t.column("event_id", .text).notNull()
                t.column("room_id", .text).notNull()
                t.column("sender", .text).notNull()
                t.column("type", .text).notNull()
                t.column("state_key", .text).notNull()
                t.column("origin_server_ts", .integer).notNull()
                t.column("content", .blob).notNull()
                t.column("unsigned", .blob)
                t.primaryKey(["room_id", "type", "state_key"])
            }
            
            try db.create(table: "stripped_state") { t in
                t.column("room_id", .text).notNull()
                t.column("sender", .text).notNull()
                t.column("state_key", .text).notNull()
                t.column("type", .text).notNull()
                t.column("content", .blob).notNull()
                t.primaryKey(["room_id", "type", "state_key"])
            }
            
            try db.create(table: "rooms") { t in
                t.column("room_id", .text).unique().notNull()
                
                t.column("join_state", .text).notNull()
                
                //t.column("notification_count", .integer).notNull()
                //t.column("highlight_count", .integer).notNull()

                t.column("timestamp", .datetime).notNull()
                
                t.primaryKey(["room_id"])
            }
            
            // User profiles are explicitly key-value stores in order to
            // support more flexible profiles in the future.
            try db.create(table: "user_profiles") { t in
                t.column("user_id", .text).notNull()
                t.column("key", .text).notNull()
                t.column("value", .text).notNull()
                t.primaryKey(["user_id", "key"])
            }
            
            // We're cheating a little bit here, using the same table for
            // both room-level account data and global account data.
            // Use a roomId of "" for global account data that is not
            // specific to any given room.
            // In the Swift code, we would use `nil`, but SQL doesn't
            // like to have NULLs in primary keys.
            try db.create(table: "account_data") { t in
                t.column("room_id", .text).notNull()
                t.column("type", .text).notNull()
                t.column("content", .blob).notNull()
                t.primaryKey(["room_id", "type"])
            }
            
            // FIXME: Really this should move into a different type
            //        The existing data store is for all the stuff *inside* a session
            //        It has no notion of multiple sessions at all
            /*
            try db.create(table: "sessions") { t in
                t.column("userId", .text).notNull()
                t.column("deviceId", .text).notNull()
                t.column("accessToken", .text).notNull()
                t.column("homeserver", .text).notNull()
                
                t.column("displayname", .text)
                t.column("avatarUrl", .text)
                t.column("statusMessage", .text)
                
                t.column("syncToken", .text)
                t.column("syncing", .boolean)
                t.column("syncRequestTimeout", .integer).notNull()
                t.column("syncDelayNS", .integer).notNull()
                
                t.column("recoverySecretKey", .blob)
                t.column("recoveryTimestamp", .datetime)
                
                t.primaryKey(["userId"])
            }
            */
        }
        
        migrator.registerMigration("Create read receipts") { db in
            try db.create(table: "read_receipts") { t in
                t.column("room_id", .text).notNull()
                t.column("thread_id", .text).notNull()
                t.column("event_id", .text).notNull()
                t.primaryKey(["room_id"])
            }
        }
        
        try migrator.migrate(database)
    }
    
    // MARK: init()
    
    public init(userId: UserId, type: StorageType) async throws {
        switch type {
        case .inMemory:
            self.database = DatabaseQueue()
        case .persistent(let preserve):
            
            let appSupportUrl = try FileManager.default.url(for: .applicationSupportDirectory,
                                                            in: .userDomainMask,
                                                            appropriateFor: nil,
                                                            create: true)
            let applicationName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "matrix.swift"

            let dirUrl = appSupportUrl.appendingPathComponent(applicationName)
                                      .appendingPathComponent(userId.stringValue)
            let databaseUrl = dirUrl.appendingPathComponent("matrix.sqlite3")
            
            if !preserve {
                try? FileManager.default.removeItem(at: databaseUrl)
            }
            
            Matrix.logger.debug("Ensuring that database directory exists")
            try FileManager.default.createDirectory(at: dirUrl, withIntermediateDirectories: true)

            Matrix.logger.debug("Trying to open database at [\(databaseUrl)]")
            self.database = try DatabasePool(path: databaseUrl.path)
            Matrix.logger.debug("Success opening database")
        }
        
        Matrix.logger.debug("Running migrations")
        self.migrator = DatabaseMigrator()
        try runMigrations()
     
        Matrix.logger.debug("Initialized GRDB database for \(userId.stringValue)")
    }
    
    public func close() async throws {
        try database.close()
    }
    
    // MARK: Timeline
    
    public func saveTimeline(events: [ClientEvent]) async throws {
        let records = events.compactMap { try? ClientEventRecord(event: $0) }
        try await database.write { db in
            for record in records {
                try record.save(db)
            }
        }
    }
    
    public func saveTimeline(events: [ClientEventWithoutRoomId], in roomId: RoomId) async throws {
        let clientEvents = try events.map {
            try ClientEvent(from: $0, roomId: roomId)
        }
        // This is stupid but it works
        let records = clientEvents.compactMap {
            try? ClientEventRecord(event: $0)
        }
        try await database.write { db in
            for record in records {
                try record.save(db)
            }
        }
    }
    
    public func loadTimeline(for roomId: RoomId,
                             limit: Int = 25, offset: Int? = nil
    ) async throws -> [ClientEventWithoutRoomId] {
        let roomIdColumn = ClientEventRecord.Columns.roomId
        let timestampColumn = ClientEventRecord.Columns.originServerTS
        let records = try await database.read { db -> [ClientEventRecord] in
            try ClientEventRecord
                .filter(roomIdColumn == "\(roomId)")
                .order(timestampColumn.desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
        let events = records.map { $0 as ClientEventWithoutRoomId }
        return events
    }
    
    // MARK: Events
    
    public func loadEvents(for roomId: RoomId, of types: [String],
                           limit: Int = 25, offset: Int? = nil
    ) async throws -> [ClientEvent] {
        let roomIdColumn = StateEventRecord.Columns.roomId
        let typeColumn = StateEventRecord.Columns.type
        let timestampColumn = StateEventRecord.Columns.originServerTS
        
        let typeStrings = types.map { "\($0)" }
        
        let records = try await database.read { db -> [StateEventRecord] in
            try StateEventRecord
                .filter(roomIdColumn == "\(roomId)")
                .filter(typeStrings.contains(typeColumn))
                .order(timestampColumn.desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
        let events = records.compactMap {
            try? ClientEvent(content: $0.content,
                             eventId: $0.eventId,
                             originServerTS: $0.originServerTS,
                             roomId: $0.roomId,
                             sender: $0.sender,
                             stateKey: $0.stateKey,
                             type: $0.type)
        }
        return events
    }
    
    public func loadRelatedEvents(for eventId: EventId, in roomId: RoomId, relType: String, type: String? = nil) async throws -> [ClientEventWithoutRoomId] {
        let roomIdColumn = ClientEventRecord.Columns.roomId
        let relTypeColumn = ClientEventRecord.Columns.relationshipType
        let relatedEventColumn = ClientEventRecord.Columns.relatedEventId
        let typeColumn = ClientEventRecord.Columns.type
        
        let records = try await database.read { db -> [ClientEventRecord] in
            var query = ClientEventRecord
                .filter(roomIdColumn == "\(roomId)")
                .filter(relTypeColumn == relType)
                .filter(relatedEventColumn == eventId)
            if let eventType = type {
                query = query.filter(typeColumn == eventType)
            }
            return try query.fetchAll(db)
        }
        let events = records.map { $0 as ClientEventWithoutRoomId }
        return events
    }
    
    public func deleteEvent(_ eventId: EventId, in roomId: RoomId) async throws {
        let eventIdColumn = ClientEventRecord.Columns.eventId
        let roomIdColumn = ClientEventRecord.Columns.roomId
        
        try await database.write { db in
            try ClientEventRecord
                    .filter(eventIdColumn == eventId)
                    .filter(roomIdColumn == roomId)
                    .deleteAll(db)
        }
    }

    // MARK: State
    
    public func loadState(for roomId: RoomId,
                          limit: Int = 0,
                          offset: Int? = nil
    ) async throws -> [ClientEventWithoutRoomId] {
        let roomIdColumn = StateEventRecord.Columns.roomId
        // let stateKeyColumn = ClientEvent.Columns.stateKey
        let timestampColumn = StateEventRecord.Columns.originServerTS
        let baseRequest = StateEventRecord.filter(roomIdColumn == "\(roomId)")
                                        .order(timestampColumn.desc)
        let request = limit > 0 ? baseRequest.limit(limit, offset: offset) : baseRequest
        let records = try await database.read { db -> [StateEventRecord] in
            try request.fetchAll(db)
        }
        let events = records.compactMap {
            try? ClientEventWithoutRoomId(content: $0.content,
                                          eventId: $0.eventId,
                                          originServerTS: $0.originServerTS,
                                          sender: $0.sender,
                                          stateKey: $0.stateKey,
                                          type: $0.type)
        }
        return events
    }
    
    public func loadEssentialState(for roomId: RoomId) async throws -> [ClientEventWithoutRoomId] {
        let roomIdColumn = StateEventRecord.Columns.roomId
        let eventTypes = [
            M_ROOM_CREATE,
            M_ROOM_TOMBSTONE,
            M_ROOM_ENCRYPTION,
            M_ROOM_POWER_LEVELS,
            M_ROOM_NAME,
            M_ROOM_AVATAR,
            M_ROOM_TOPIC,
            M_SPACE_CHILD,
            M_SPACE_PARENT,
        ]
        //let query = "room_id='\(roomId)' AND type IN (\(eventTypes.map({"'\($0)'"}).joined(separator: ",")))"
        /*
        let query = "room_id='\(roomId)'"
        let request = table.filter(sql: query)
        */
        let request = StateEventRecord.filter(roomIdColumn == roomId)
        let records = try await database.read { db in
            try request.fetchAll(db)
        }
        return records.compactMap {
            try? ClientEventWithoutRoomId(content: $0.content,
                                          eventId: $0.eventId,
                                          originServerTS: $0.originServerTS,
                                          sender: $0.sender,
                                          stateKey: $0.stateKey,
                                          type: $0.type)
        }
    }
    
    public func loadState(for roomId: RoomId, type: String) async throws -> [ClientEventWithoutRoomId] {
        let roomIdColumn = StateEventRecord.Columns.roomId
        let typeColumn = StateEventRecord.Columns.type
        
        let request = StateEventRecord.filter(roomIdColumn == roomId)
                                      .filter(typeColumn == type)
        let records = try await database.read { db in
            try request.fetchAll(db)
        }
        return records.compactMap {
            try? ClientEventWithoutRoomId(content: $0.content,
                                          eventId: $0.eventId,
                                          originServerTS: $0.originServerTS,
                                          sender: $0.sender,
                                          stateKey: $0.stateKey,
                                          type: $0.type)
        }
    }
    
    public func loadState(for roomId: RoomId, type: String, stateKey: String) async throws -> ClientEventWithoutRoomId? {
        let roomIdColumn = StateEventRecord.Columns.roomId
        let typeColumn = StateEventRecord.Columns.type
        let stateKeyColumn = StateEventRecord.Columns.stateKey
        
        let request = StateEventRecord.filter(roomIdColumn == roomId)
                                      .filter(typeColumn == type)
                                      .filter(stateKeyColumn == stateKey)
        guard let record = try await database.read( { db in
            try request.fetchOne(db)
        })
        else {
            return nil
        }
        
        return try? ClientEventWithoutRoomId(content: record.content,
                                             eventId: record.eventId,
                                             originServerTS: record.originServerTS,
                                             sender: record.sender,
                                             stateKey: record.stateKey,
                                             type: record.type)
    }
    
    
    public func saveState(events: [ClientEventWithoutRoomId], in roomId: RoomId) async throws {
        let stateEvents = events.compactMap { event in
            try? StateEventRecord(from: event, in: roomId)
        }
        try await database.write { db in
            for stateEvent in stateEvents {
                try stateEvent.save(db)
            }
        }
    }
    
    public func saveState(events: [ClientEvent]) async throws {
        let stateEvents = events.compactMap { event in
            try? StateEventRecord(from: event)
        }
        try await database.write { db in
            for stateEvent in stateEvents {
                try stateEvent.save(db)
            }
        }
    }
    
    // MARK: Read Receipts
    public func loadReadReceipt(roomId: RoomId,
                                threadId: EventId = "main"
    ) async throws -> EventId? {
        let roomIdColumn = ReadReceiptRecord.Columns.roomId
        let threadIdColumn = ReadReceiptRecord.Columns.threadId
        
        let request = ReadReceiptRecord
                        .filter(roomIdColumn == roomId)
                        .filter(threadIdColumn == threadId)
        let record = try await database.read { db in
            try request.fetchOne(db)
        }
        return record?.eventId
    }
    
    public func loadAllReadReceipts(roomId: RoomId) async throws -> [EventId : EventId] {
        let roomIdColumn = ReadReceiptRecord.Columns.roomId

        let request = ReadReceiptRecord
                        .filter(roomIdColumn == roomId)
        let records = try await database.read { db in
            try request.fetchAll(db)
        }
        let tuples = records.compactMap {
            ($0.threadId ?? "main", $0.eventId)
        }
        let receipts: [EventId: EventId] = .init(uniqueKeysWithValues: tuples)
        return receipts
    }
    
    public func saveReadReceipt(roomId: RoomId,
                                threadId: EventId = "main",
                                eventId: EventId
    ) async throws {
        let record = ReadReceiptRecord(roomId: roomId, threadId: threadId, eventId: eventId)
        
        try await database.write { db in
            try record.save(db)
        }
    }
    
    // MARK: Redactions
    
    public func processRedactions(_ redactions: [ClientEvent]) async throws {
        let roomIdColumn = ClientEventRecord.Columns.roomId
        let eventIdColumn = ClientEventRecord.Columns.eventId

        for redaction in redactions {
            guard redaction.type == M_ROOM_REDACTION,
                  let content = redaction.content as? RedactionContent,
                  let redactedEventId = content.redacts
            else {
                continue
            }
                        
            try await database.write { db in
                
                if let badEvent = try ClientEventRecord
                                        .filter(roomIdColumn == "\(redaction.roomId)")
                                        .filter(eventIdColumn == redactedEventId)
                                        .fetchOne(db)
                {
                    if badEvent.stateKey != nil {
                        // It's a state event, so we can't just delete it completely.
                        // Try to redact it, and save the redacted version.
                        let redacted = try Matrix.redactEvent(badEvent, because: redaction)
                        try ClientEventRecord(event: redacted).save(db)
                    } else {
                        // Not a state event.  Nuke it from orbit.
                        try ClientEventRecord
                            .filter(roomIdColumn == "\(redaction.roomId)")
                            .filter(eventIdColumn == redactedEventId)
                            .deleteAll(db)
                    }
                }
            }
        }
    }
    
    // MARK: Stripped State
    
    public func saveStrippedState(events: [StrippedStateEvent], roomId: RoomId) async throws {
        try await database.write { db in
            for event in events {
                let record = StrippedStateEventRecord(from: event, in: roomId)
                try record.save(db)
            }
        }
    }
    
    public func loadStrippedState(for roomId: RoomId) async throws -> [StrippedStateEvent] {
        let roomIdColumn = StrippedStateEventRecord.Columns.roomId
        let records = try await database.read { db in
            try StrippedStateEventRecord
                    .filter(roomIdColumn == "\(roomId)")
                    .fetchAll(db)
        }
        let events = records.map {
            StrippedStateEvent(sender: $0.sender,
                               stateKey: $0.stateKey,
                               type: $0.type,
                               content: $0.content)
        }
        return events
    }
    
    public func deleteStrippedState(for roomId: RoomId) async throws -> Int {
        let roomIdColumn = StrippedStateEventRecord.Columns.roomId
        let count = try await database.write { db in
            try StrippedStateEventRecord
                .filter(roomIdColumn == "\(roomId)")
                .deleteAll(db)
        }
        return count
    }

    
    // MARK: Rooms
    
    public func getRecentRoomIds(limit: Int=20, offset: Int? = nil) async throws -> [RoomId] {
        let timestampColumn = RoomRecord.Columns.timestamp
        let records = try await database.read { db -> [RoomRecord] in
            try RoomRecord
                .order(timestampColumn.desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
        return records.map { $0.roomId }
    }
    
    public func getRoomIds(of roomType: String, limit: Int=20, offset: Int?=nil) async throws -> [RoomId] {
        let eventTypeColumn = StateEventRecord.Columns.type
        let stateKeyColumn = StateEventRecord.Columns.stateKey
        let records = try await database.read { db in
            let baseQuery = StateEventRecord
                .filter(eventTypeColumn == M_ROOM_CREATE)
                .filter(stateKeyColumn == roomType)
            let query = limit > 0 ? baseQuery.limit(limit, offset: offset) : baseQuery
            return try query.fetchAll(db)
        }
        let roomIds = records.map { $0.roomId }
        return roomIds
    }
    
    public func getJoinedRoomIds(for userId: UserId, limit: Int=20, offset: Int?=nil) async throws -> [RoomId] {
        let eventTypeColumn = StateEventRecord.Columns.type
        let stateKeyColumn = StateEventRecord.Columns.stateKey
        let records = try await database.read { db in
            let baseQuery = StateEventRecord
                .filter(eventTypeColumn == M_ROOM_MEMBER)
                .filter(stateKeyColumn == "\(userId)")
            let query = limit > 0 ? baseQuery.limit(limit, offset: offset) : baseQuery
            return try query.fetchAll(db)
        }
        let roomIds = records.compactMap { record -> RoomId? in
            // Is the membership state 'join' ???
            guard let content = record.content as? RoomMemberContent,
                  content.membership == .join
            else {
                return nil
            }
            return record.roomId
        }
        return roomIds
    }
    
    public func getInvitedRoomIds(for userId: UserId) async throws -> [RoomId] {
        //let roomIdColumn = StrippedStateEventRecord.Columns.roomId
        let typeColumn = StrippedStateEventRecord.Columns.type
        let stateKeyColumn = StrippedStateEventRecord.Columns.stateKey
        let records = try await database.read { db in
            try StrippedStateEventRecord
                .filter(typeColumn == M_ROOM_MEMBER)
                .filter(stateKeyColumn == "\(userId)")
                .fetchAll(db)
        }
        let roomIds = records.compactMap { record -> RoomId? in
            guard let content = record.content as? RoomMemberContent,
                  content.membership == .invite
            else {
                return nil
            }
            return record.roomId
        }
        return roomIds
    }
    
    /* // Moving this up into the Session layer
    public func loadRoom(_ roomId: RoomId) async throws -> Matrix.Room? {
        let stateEvents = try await loadState(for: roomId)
        return try? Matrix.Room(roomId: roomId, session: self.session, initialState: stateEvents)
    }
    */
    
    public func saveRoomTimestamp(roomId: RoomId,
                                  state: RoomMemberContent.Membership,
                                  timestamp: UInt64
    ) async throws {
        try await database.write { db in
            let rec = RoomRecord(roomId: roomId, joinState: state, timestamp: timestamp)
            try rec.save(db)
        }
    }
    
    public func deleteRoom(_ roomId: RoomId) async throws {
        try await database.write { db in
            try RoomRecord
                .filter(RoomRecord.Columns.roomId == "\(roomId)")
                .deleteAll(db)
            
            try StateEventRecord
                .filter(StateEventRecord.Columns.roomId == "\(roomId)")
                .deleteAll(db)
            
            try ClientEventRecord
                .filter(ClientEventRecord.Columns.roomId == "\(roomId)")
                .deleteAll(db)
            
            try StrippedStateEventRecord
                .filter(StrippedStateEventRecord.Columns.roomId == "\(roomId)")
                .deleteAll(db)
        }
    }
    
    // MARK: User profiles
    
    public func loadProfileItem(_ item: String, for userId: UserId) async throws -> String? {
        let userIdColumn = UserProfileRecord.Columns.userId
        let keyColumn = UserProfileRecord.Columns.key
        let record = try await database.read { db -> UserProfileRecord? in
            try UserProfileRecord
                .filter(userIdColumn == "\(userId)")
                .filter(keyColumn == item)
                .fetchOne(db)
        }
        return record?.value
    }
    
    public func loadDisplayname(for userId: UserId) async throws -> String? {
        try await loadProfileItem("displayname", for: userId)
    }
    
    public func loadAvatarUrl(for userId: UserId) async throws -> MXC? {
        guard let string = try await loadProfileItem("avatar_url", for: userId)
        else {
            return nil
        }
        return MXC(string)
    }
    
    public func loadStatusMessage(for userId: UserId) async throws -> String? {
        try await loadProfileItem("status", for: userId)
    }
    
    public func saveProfileItem(_ item: String, _ value: String, for userId: UserId) async throws {
        let record = UserProfileRecord(userId: userId, key: item, value: value)
        try await database.write { db in
            try record.save(db)
        }
    }
    
    public func saveDisplayname(_ name: String, for userId: UserId) async throws {
        try await saveProfileItem("displayname", name, for: userId)
    }
    
    public func saveAvatarUrl(_ url: MXC, for userId: UserId) async throws {
        try await saveProfileItem("avatar_url", url.description, for: userId)
    }
    
    public func saveStatusMessage(_ msg: String, for userId: UserId) async throws {
        try await saveProfileItem("status", msg, for: userId)
    }
    
    // MARK: Account data
    
    public func loadAccountData(of type: String, in roomId: RoomId? = nil) async throws -> Codable? {
        let roomIdColumn = AccountDataRecord.Columns.roomId
        let typeColumn = AccountDataRecord.Columns.type
        let record = try await database.read { db -> AccountDataRecord? in
            try AccountDataRecord
                .filter(roomIdColumn == roomId?.stringValue ?? "")
                .filter(typeColumn == type)
                .fetchOne(db)
        }
        return record?.content
    }
    
    public func loadAccountDataEvents(roomId: RoomId? = nil,
                                      limit: Int = 1000, offset: Int? = nil
    ) async throws -> [Matrix.AccountDataEvent] {
        let roomIdColumn = AccountDataRecord.Columns.roomId
        let records = try await database.read { db in
            try AccountDataRecord
                .filter(roomIdColumn == roomId?.stringValue ?? "")
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
        let events = records.compactMap {
            Matrix.AccountDataEvent(type: $0.type, content: $0.content)
        }
        return events
    }
    
    public func saveAccountData(events: [Matrix.AccountDataEvent], in roomId: RoomId? = nil) async throws {
        let records = events.compactMap {
            AccountDataRecord(from: $0, in: roomId)
        }
        try await database.write { db in
            for record in records {
                try record.save(db)
            }
        }
    }
}
