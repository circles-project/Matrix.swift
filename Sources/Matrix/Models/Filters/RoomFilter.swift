//
//  RoomFilter.swift
//
//
//  Created by Charles Wright on 1/10/24.
//

import Foundation

extension Matrix {
    struct RoomFilter: Codable {
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
    }
}
