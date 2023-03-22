//
//  RoomPowerLevelsContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

/// m.room.power_levels: https://spec.matrix.org/v1.5/client-server-api/#mroompower_levels
public struct RoomPowerLevelsContent: Codable {
    public var invite: Int?
    public var kick: Int?
    public var ban: Int?
    public var redact: Int?
    
    public var events: [String: Int]?
    public var eventsDefault: Int?

    public var notifications: [String: Int]?
    
    public var stateDefault: Int?

    public var users: [UserId: Int]?
    public var usersDefault: Int?
    
    public init(invite: Int? = nil,
                kick: Int? = nil,
                ban: Int? = nil,
                redact: Int? = nil,
                events: [String : Int]? = nil,
                eventsDefault: Int? = nil,
                notifications: [String : Int]? = nil,
                stateDefault: Int? = nil,
                users: [UserId : Int]? = nil,
                usersDefault: Int? = nil) {
        self.invite = invite
        self.kick = kick
        self.ban = ban
        self.events = events
        self.eventsDefault = eventsDefault
        self.notifications = notifications
        self.redact = redact
        self.stateDefault = stateDefault
        self.users = users
        self.usersDefault = usersDefault
    }
    
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
