//
//  RoomPowerLevelsContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

/// m.room.power_levels: https://spec.matrix.org/v1.5/client-server-api/#mroompower_levels
struct RoomPowerLevelsContent: Codable {
    let invite: Int
    let kick: Int
    let ban: Int
    
    let events: [String: Int]
    let eventsDefault: Int

    let notifications: [String: Int]?
    
    let redact: Int
    
    let stateDefault: Int

    let users: [String: Int]
    let usersDefault: Int
    
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
