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
    func saveStrippedState(events: [StrippedStateEvent], roomId: RoomId) async throws

    func loadTimeline(for roomId: RoomId, limit: Int, offset: Int?) async throws -> [ClientEvent]
    
    func loadState(for roomId: RoomId, limit: Int, offset: Int?) async throws -> [ClientEventWithoutRoomId]
    func loadEssentialState(for roomId: RoomId) async throws -> [ClientEventWithoutRoomId]
    
    func getRecentRoomIds(limit: Int, offset: Int?) async throws -> [RoomId]
    func getRoomIds(of roomType: String, limit: Int, offset: Int?) async throws -> [RoomId]
    func getJoinedRoomIds(for userId: UserId, limit: Int, offset: Int?) async throws -> [RoomId]
    
    //func loadRooms(of type: String?, limit: Int, offset: Int?) async throws -> [Matrix.Room]
    //func loadRoom(_ roomId: RoomId) async throws -> Matrix.Room?
    
    func saveRoomTimestamp(roomId: RoomId, state: RoomMemberContent.Membership, timestamp: UInt64) async throws
}
