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
        case content
        case eventId = "event_id"
        case originServerTS = "origin_server_ts"
        case roomId = "room_id"
        case sender
        case stateKey = "state_key"
        case type
        case unsigned
    }

    static public var databaseTableName: String = "timeline"

}

extension ClientEvent: PersistableRecord {
    
}
