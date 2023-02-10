//
//  RoomPowerLevelsContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

/// m.room.power_levels: https://spec.matrix.org/v1.5/client-server-api/#mroompower_levels
public struct RoomPowerLevelsContent: Codable {
    public let invite: Int?
    public let kick: Int?
    public let ban: Int?
    public let redact: Int?
    
    public let events: [Matrix.EventType: Int]?
    public let eventsDefault: Int?

    public let notifications: [String: Int]?
    
    public let stateDefault: Int?

    public let users: [UserId: Int]?
    public let usersDefault: Int?
    
    public init(invite: Int? = nil,
                kick: Int? = nil,
                ban: Int? = nil,
                redact: Int? = nil,
                events: [Matrix.EventType : Int]? = nil,
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
