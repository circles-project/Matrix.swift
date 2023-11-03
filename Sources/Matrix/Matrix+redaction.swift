//
//  Matrix+redaction.swift
//  
//
//  Created by Charles Wright on 9/6/23.
//

import Foundation

extension Matrix {
    
    private static func redactEventContent(_ badContent: Codable, type: String) throws -> Codable {
        switch type {
            
        case M_ROOM_MEMBER:
            guard let content = badContent as? RoomMemberContent
            else {
                Matrix.logger.error("Couldn't parse \(M_ROOM_MEMBER) content")
                throw Matrix.Error("Couldn't parse \(M_ROOM_MEMBER) content")
            }
            let memberContent = RoomMemberContent(membership: content.membership)
            return memberContent
            
        case M_ROOM_CREATE:
            let content = badContent
            return content
            
        case M_ROOM_JOIN_RULES:
            guard let content = badContent as? RoomJoinRuleContent
            else {
                Matrix.logger.error("Couldn't parse \(M_ROOM_JOIN_RULES) content")
                throw Matrix.Error("Couldn't parse \(M_ROOM_JOIN_RULES) content")
            }
            let joinRulesContent = RoomJoinRuleContent(allow: content.allow, joinRule: content.joinRule)
            return joinRulesContent
            
        case M_ROOM_POWER_LEVELS:
            guard let content = badContent as? RoomPowerLevelsContent
            else {
                Matrix.logger.error("Couldn't parse \(M_ROOM_POWER_LEVELS) content")
                throw Matrix.Error("Couldn't parse \(M_ROOM_POWER_LEVELS) content")
            }
            let powerLevelsContent = RoomPowerLevelsContent(invite: content.invite,
                                                            kick: content.kick,
                                                            ban: content.ban,
                                                            redact: content.redact,
                                                            events: content.events,
                                                            eventsDefault: content.eventsDefault,
                                                            notifications: content.notifications,
                                                            stateDefault: content.stateDefault,
                                                            users: content.users,
                                                            usersDefault: content.usersDefault)
            return powerLevelsContent
                    
        case M_ROOM_HISTORY_VISIBILITY:
            guard let content = badContent as? RoomHistoryVisibilityContent
            else {
                Matrix.logger.error("Couldn't parse \(M_ROOM_HISTORY_VISIBILITY) content")
                throw Matrix.Error("Couldn't parse \(M_ROOM_HISTORY_VISIBILITY) content")
            }
            let historyVisibilityContent = RoomHistoryVisibilityContent(historyVisibility: content.historyVisibility)
            return historyVisibilityContent
            
        case M_ROOM_REDACTION:
            guard let content = badContent as? RedactionContent
            else {
                Matrix.logger.error("Couldn't parse \(M_ROOM_REDACTION) content")
                throw Matrix.Error("Couldn't parse \(M_ROOM_REDACTION) content")
            }
            let redactionContent = RedactionContent(redacts: content.redacts)
            return redactionContent
            
        default:
            return badContent
        }
    }
    
    // https://spec.matrix.org/v1.8/rooms/v11/#redactions
    public static func redactEvent(_ event: ClientEvent, because redaction: ClientEvent) throws -> ClientEvent {
        
        guard event.roomId == redaction.roomId
        else {
            Matrix.logger.error("Can't redact an event from a different room")
            throw Matrix.Error("Can't redact an event from a different room")
        }
        
        guard redaction.type == M_ROOM_REDACTION
        else {
            Matrix.logger.error("Can't redact with a non-\(M_ROOM_REDACTION) event")
            throw Matrix.Error("Can't redact with a non-\(M_ROOM_REDACTION) event")
        }
        
        guard let redactionContent = redaction.content as? RedactionContent,
              redactionContent.redacts == event.eventId
        else {
            Matrix.logger.error("Invalid redaction content")
            throw Matrix.Error("Invalid redaction content")
        }

        let redactedContent = try redactEventContent(event.content, type: event.type)
        let unsigned = UnsignedData(redactedBecause: redaction)
        
        return try ClientEvent(content: redactedContent,
                               eventId: event.eventId,
                               originServerTS: event.originServerTS,
                               roomId: event.roomId,
                               sender: event.sender,
                               stateKey: event.stateKey,
                               type: event.type,
                               unsigned: unsigned)
    }
    
}
