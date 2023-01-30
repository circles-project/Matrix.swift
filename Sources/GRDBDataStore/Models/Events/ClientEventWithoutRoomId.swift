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
    // Uses ClientEvent table with storing null room id
    public static let databaseTableName = "clientEvents"
}
