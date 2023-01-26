//
//  ClientEventWithoutRoomId.swift
//  
//
//  Created by Michael Hollister on 1/23/23.
//

import Foundation
import Matrix
import GRDB

extension ClientEventWithoutRoomId: FetchableRecord, PersistableRecord {
    // docs tbd: uses ClientEvents table with null room id, or can specify room id via function interface
    public static let databaseTableName = "clientEvents"
}
