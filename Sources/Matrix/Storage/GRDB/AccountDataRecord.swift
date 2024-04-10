//
//  AccountDataRecord.swift
//  
//
//  Created by Charles Wright on 7/25/23.
//

import Foundation
import GRDB

struct AccountDataRecord: Codable {
        
    public let roomId: RoomId?
    public let type: String
    public let content: Codable
    
    public enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case type
        case content
    }
    
    public var description: String {
        return """
               AccountDataRecord: {roomId: \(String(describing: roomId)),
               type: \(type), content:\(content)}
               """
    }
    
    init(from event: Matrix.AccountDataEvent, in roomId: RoomId? = nil) {
        self.roomId = roomId
        self.type = event.type
        self.content = event.content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let stringRoomId = try container.decodeIfPresent(String.self, forKey: .roomId),
           !stringRoomId.isEmpty {
            self.roomId = RoomId(stringRoomId)
        } else {
            self.roomId = nil
        }

        let type = try container.decode(String.self, forKey: .type)
        self.type = type
        self.content = try Matrix.decodeAccountData(of: type, from: decoder)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        let stringRoomId = roomId?.stringValue ?? ""
        try container.encodeIfPresent(stringRoomId, forKey: .roomId)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.content, forKey: .content)
    }
}

extension AccountDataRecord: FetchableRecord, TableRecord {
    static public var databaseTableName: String = "account_data"

    public enum Columns: String, ColumnExpression {
        case roomId = "room_id"
        case type
        case content
    }
}

extension AccountDataRecord: PersistableRecord {
}
