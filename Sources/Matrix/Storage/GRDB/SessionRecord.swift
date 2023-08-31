//
//  SessionRecord.swift
//  
//
//  Created by Charles Wright on 2/18/23.
//

import Foundation
import GRDB

struct SessionRecord: Codable {
    // Credentials
    let userId: UserId
    let deviceId: String
    let accessToken: String
    let homeserver: URL
    
    // User profile info
    let displayname: String?
    let avatarUrl: MXC?
    let statusMessage: String?
    
    // Sync info
    let syncToken: String?
    let syncing: Bool?
    let syncRequestTimeout: Int
    let syncDelayNS: UInt64
    
    // Encrypted backup / recovery info
    let recoverySecretKey: Data?
    let recoveryTimestamp: Date?
    
    public var description: String {
        return """
               SessionRecord: {userId: \(userId), deviceId: \(deviceId), accessToken:\(accessToken), \
               homeserver: \(homeserver), displayname: \(String(describing: displayname)), \
               avatarUrl: \(String(describing: avatarUrl)), statusMessage: \(String(describing: statusMessage)), \
               syncToken: \(String(describing: syncToken)), syncing: \(String(describing: syncing)), \
               syncRequestTimeout: \(syncRequestTimeout), syncDelayNS: \(syncDelayNS), \
               recoverySecretKey: \(String(describing: recoverySecretKey)), \
               recoveryTimestamp: \(String(describing: recoveryTimestamp))}
               """
    }
}

extension SessionRecord: FetchableRecord, TableRecord {
    static var databaseTableName = "sessions"
}

extension SessionRecord: PersistableRecord { }
