//
//  RoomRecord.swift
//  
//
//  Created by Charles Wright on 2/16/23.
//

import Foundation
import GRDB

struct RoomRecord: Codable {
    let roomId: RoomId

    let joinState: RoomMemberContent.Membership
    
    //let notificationCount: Int
    //let highlightCount: Int

    let timestamp: UInt64
    
    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case joinState = "join_state"
        case timestamp
    }
    
}

extension RoomRecord: FetchableRecord, TableRecord {
    static var databaseTableName = "rooms"
    
    enum Columns: String, ColumnExpression {
        case roomId = "room_id"
        case joinState = "join_state"
        //case highlightCount = "highlight_count"
        //case notificationCount = "notification_count"
        case timestamp

    }

}

extension RoomRecord: PersistableRecord { }
