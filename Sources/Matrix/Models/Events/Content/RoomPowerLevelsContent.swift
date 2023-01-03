//
//  RoomPowerLevelsContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

/// m.room.power_levels: https://spec.matrix.org/v1.5/client-server-api/#mroompower_levels
struct RoomPowerLevelsContent: Codable {
    var invite: Int
    var kick: Int
    var ban: Int
    
    var events: [String: Int]
    var eventsDefault: Int

    var notifications: [String: Int]?
    
    var redact: Int
    
    var stateDefault: Int

    var users: [String: Int]
    var usersDefault: Int
    
    enum CodingKeys: String, CodingKey {
        case invite
        case kick
        case ban
        case events
        case eventsDefault = "events_default"
        case notifications
        case redact
        case stateDefault = "state_default"
        case users
        case usersDefault = "users_default"
    }
}
