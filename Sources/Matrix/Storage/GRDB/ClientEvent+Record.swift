//
//  ClientEvent+Record.swift
//  
//
//  Created by Charles Wright on 2/14/23.
//

import Foundation
import GRDB

extension ClientEvent: FetchableRecord, TableRecord {
    
    enum Columns: String, ColumnExpression {
        case content, eventId, originServerTS, roomId, sender, stateKey, type
    }
    
    static public var databaseTableName = "events"
}

extension ClientEvent: PersistableRecord {
    
}
