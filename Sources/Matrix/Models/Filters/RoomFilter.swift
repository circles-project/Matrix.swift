//
//  RoomFilter.swift
//
//
//  Created by Charles Wright on 1/10/24.
//

import Foundation

extension Matrix {
    public struct RoomFilter: Codable {
        var accountData: RoomEventFilter?
        var ephemeral: RoomEventFilter?
        var includeLeave: Bool?
        var notRooms: [RoomId]?
        var rooms: [RoomId]?
        var state: StateFilter?
        var timeline: RoomEventFilter?
        
        enum CodingKeys: String, CodingKey {
            case accountData = "account_data"
            case ephemeral
            case includeLeave = "include_leave"
            case notRooms = "not_rooms"
            case rooms
            case state
            case timeline
        }
        
        public init(accountData: RoomEventFilter? = nil, ephemeral: RoomEventFilter? = nil, includeLeave: Bool? = nil, notRooms: [RoomId]? = nil, rooms: [RoomId]? = nil, state: StateFilter? = nil, timeline: RoomEventFilter? = nil) {
            self.accountData = accountData
            self.ephemeral = ephemeral
            self.includeLeave = includeLeave
            self.notRooms = notRooms
            self.rooms = rooms
            self.state = state
            self.timeline = timeline
        }
    }
}
