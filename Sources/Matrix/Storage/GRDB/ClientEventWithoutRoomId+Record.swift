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
        case content, eventId, originServerTS, sender, stateKey, type
    }
    
    static public var databaseTableName = "events"
}

// Note: ClientEventWithoutRoomId does NOT conform to PersistableRecord
//       because we can't persist it by itself.  We *need* to know which
//       room an event belongs in, in order to save it.
//       The proper approach is to first convert to ClientEvent, then
//       persist the ClientEvent in the database.
