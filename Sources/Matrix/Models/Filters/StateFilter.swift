//
//  StateFilter.swift
//
//
//  Created by Charles Wright on 1/10/24.
//

import Foundation

extension Matrix {
    struct StateFilter: Codable {
        var containsUrl: Bool?
        var includeRedundantMembers: Bool?
        var lazyLoadMembers: Bool?
        var limit: UInt?
        var notRooms: [RoomId]?
        var notSenders: [UserId]?
        var notTypes: [String]?
        var rooms: [RoomId]?
        var senders: [UserId]?
        var types: [String]?
        var unreadThreadNotifications: Bool?
        
        enum CodingKeys: String, CodingKey {
            case containsUrl = "contains_url"
            case includeRedundantMembers = "include_redundant_members"
            case lazyLoadMembers = "lazy_load_members"
            case limit
            case notRooms = "not_rooms"
            case notSenders = "not_senders"
            case notTypes = "not_types"
            case rooms
            case senders
            case types
            case unreadThreadNotifications = "unread_thread_notifications"
        }
    }
}
