//
//  UserProfileRecord.swift
//  
//
//  Created by Charles Wright on 2/16/23.
//

import Foundation
import GRDB

struct UserProfileRecord: Codable {
    let userId: UserId
    let key: String
    let value: String
}

extension UserProfileRecord: FetchableRecord, TableRecord {
    static var databaseTableName = "userProfiles"
    
    enum Columns: String, ColumnExpression {
        case userId, key, value
    }
}

extension UserProfileRecord: PersistableRecord {
}
