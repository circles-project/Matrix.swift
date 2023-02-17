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
    let type: String?
    let version: String
    let creator: UserId
    
    let isEncrypted: Bool
    
    let predecessorRoomId: RoomId?
    let successorRoomId: RoomId?
    
    let name: String?
    let avatarUrl: MXC?
    let topic: String?
    
    let notificationCount: Int
    let highlightCount: Int
    
    let minimalState: Data
    let latestMessages: Data
    let timestamp: UInt64
    
}

extension RoomRecord: FetchableRecord, TableRecord {
    static var databaseTableName = "rooms"
    
    enum Columns: String, ColumnExpression {
        case roomId
        case type
        case version
        case creator
        case isEncrypted
        case name
        case topic
        case avatarUrl
        case predecessorRoomId
        case successorRoomId
        case highlightCount
        case notificationCount
        case timestamp
        case minimalState
        case latestMessages
    }
        
    public init(row: Row) {

        self.roomId = row[Columns.roomId] as RoomId
        self.type = row[Columns.type] as String?
        self.version = row[Columns.version] as String
        self.creator = row[Columns.creator] as UserId
        
        self.isEncrypted = row[Columns.isEncrypted] as Bool
        
        self.name = row[Columns.name] as String?
        self.topic = row[Columns.topic] as String?
        self.avatarUrl = row[Columns.avatarUrl] as MXC?
        
        self.predecessorRoomId = row[Columns.predecessorRoomId] as RoomId?
        self.successorRoomId = row[Columns.successorRoomId] as RoomId?
        
        self.highlightCount = row[Columns.highlightCount] as Int
        self.notificationCount = row[Columns.notificationCount] as Int
        
        self.timestamp = row[Columns.timestamp] as UInt64
        self.minimalState = row[Columns.minimalState] as Data
        self.latestMessages = row[Columns.latestMessages] as Data
    }
}

extension RoomRecord: PersistableRecord { }
