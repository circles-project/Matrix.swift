//
//  ClientEventWithoutRoomId+Record.swift
//  
//
//  Created by Charles Wright on 2/16/23.
//

import Foundation
import GRDB

extension ClientEventWithoutRoomId: FetchableRecord, TableRecord {
    
    enum Columns: String, ColumnExpression {
        case content
        case eventId = "event_id"
        case originServerTS = "origin_server_ts"
        case sender
        case stateKey = "state_key"
        case type
        case unsigned
    }
    
    static public var databaseTableName: String = "timeline"
    
}

// Note: ClientEventWithoutRoomId does NOT conform to PersistableRecord
//       because we can't persist it by itself.  We *need* to know which
//       room an event belongs in, in order to save it.
//       The proper approach is to first convert to ClientEvent, then
//       persist the ClientEvent in the database.
