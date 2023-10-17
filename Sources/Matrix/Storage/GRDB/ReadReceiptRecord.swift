//
//  ReadMarkerRecord.swift
//
//
//  Created by Charles Wright on 10/17/23.
//

import Foundation
import GRDB

struct ReadReceiptRecord: Codable {
    var roomId: RoomId
    var threadId: EventId?
    var eventId: EventId
    
    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case threadId = "thread_id"
        case eventId = "event_id"
    }
    
    init(roomId: RoomId,
         threadId: EventId? = nil,
         eventId: EventId
    ) {
        self.roomId = roomId
        self.threadId = threadId
        self.eventId = eventId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let stringRoomId = try container.decode(String.self, forKey: .roomId)
        self.roomId = RoomId(stringRoomId)!
        
        self.threadId = try container.decodeIfPresent(EventId.self, forKey: .threadId)
        
        self.eventId = try container.decode(EventId.self, forKey: .eventId)
    }
}

extension ReadReceiptRecord: FetchableRecord, TableRecord {
    static public var databaseTableName: String = "read_receipts"
    
    public enum Columns: String, ColumnExpression {
        case roomId = "room_id"
        case threadId = "thread_id"
        case eventId = "event_id"
    }
}

extension ReadReceiptRecord: PersistableRecord { }
