//
//  DataStore.swift
//  
//
//  Created by Charles Wright on 2/14/23.
//

import Foundation

public enum StorageType: String {
    case inMemory
    case persistent
}

public protocol DataStore {
    var session: Matrix.Session { get }
    
    init(session: Matrix.Session, type: StorageType) async throws
    
    //init(userId: UserId, deviceId: String) async throws
    
    func save(events: [ClientEvent]) async throws
    func save(events: [ClientEventWithoutRoomId], in roomId: RoomId) async throws
    
    func saveState(events: [ClientEvent]) async throws
    func saveState(events: [ClientEventWithoutRoomId], in roomId: RoomId) async throws
    
    func loadEvents(for roomId: RoomId, limit: Int, offset: Int?) async throws -> [ClientEvent]
    
    func loadState(for roomId: RoomId, limit: Int, offset: Int?) async throws -> [ClientEventWithoutRoomId]
    
    // FIXME: Add all the other function prototypes that got built out in the GRDBDataStore
    
    func loadRooms(limit: Int, offset: Int?) async throws -> [Matrix.Room]
    
    //func loadRooms(of type: String?, limit: Int, offset: Int?) async throws -> [Matrix.Room]
    
    func loadRoom(_ roomId: RoomId) async throws -> Matrix.Room?
    
    func saveRoomTimestamp(roomId: RoomId, state: RoomMemberContent.Membership, timestamp: UInt64) async throws
}
