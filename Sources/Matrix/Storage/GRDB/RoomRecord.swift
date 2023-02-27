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
    
}

extension RoomRecord: FetchableRecord, TableRecord {
    static var databaseTableName = "rooms"
    
    enum Columns: String, ColumnExpression {
        case roomId
        case joinState
        //case highlightCount
        //case notificationCount
        case timestamp

    }

}

extension RoomRecord: PersistableRecord { }
