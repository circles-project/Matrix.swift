//
//  RoomPowerLevelsContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

/// m.room.power_levels: https://spec.matrix.org/v1.5/client-server-api/#mroompower_levels
public struct RoomPowerLevelsContent: Codable {
    public let invite: Int
    public let kick: Int
    public let ban: Int
    
    public let events: [String: Int]
    public let eventsDefault: Int

    public let notifications: [String: Int]?
    
    public let redact: Int
    
    public let stateDefault: Int

    public let users: [String: Int]
    public let usersDefault: Int
    
    public enum CodingKeys: String, CodingKey {
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
