//
//  RoomEventFilter.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

extension Matrix {
    // https://spec.matrix.org/v1.2/client-server-api/#post_matrixclientv3useruseridfilter
    public struct RoomEventFilter: Codable {
        public var containsUrl: Bool?
        public var includeRedundantMembers: Bool?
        public var lazyLoadMembers: Bool?
        public var limit: Int?
        public var notRooms: [RoomId]?
        public var notSenders: [UserId]?
        public var notTypes: [String]?
        public var rooms: [RoomId]?
        public var senders: [UserId]?
        public var types: [String]?
        
        public enum CodingKeys: String, CodingKey {
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
        }
    }
}
