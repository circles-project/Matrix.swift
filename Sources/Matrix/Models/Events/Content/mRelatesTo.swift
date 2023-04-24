//
//  mRelatesTo.swift
//  
//
//  Created by Charles Wright on 4/21/23.
//

import Foundation

public struct mRelatesTo: Codable {

    public struct mInReplyTo: Codable {
        var eventId: EventId
        public enum CodingKeys: String, CodingKey {
            case eventId = "event_id"
        }
        public init(eventId: EventId) {
            self.eventId = eventId
        }
    }
    public let relType: String?
    public let eventId: EventId?
    public let key: String?
    public let inReplyTo: mInReplyTo?
    
    public init(relType: String?, eventId: EventId?, key: String? = nil, inReplyTo: EventId? = nil) {
        self.relType = relType
        self.eventId = eventId
        self.key = key
        if let parentEventId = inReplyTo {
            self.inReplyTo = mInReplyTo(eventId: parentEventId)
        } else {
            self.inReplyTo = nil
        }
    }
    
    public init(inReplyTo: EventId) {
        self.relType = nil
        self.eventId = nil
        self.key = nil
        self.inReplyTo = mInReplyTo(eventId: inReplyTo)
    }
    
    public enum CodingKeys: String, CodingKey {
        case relType = "rel_type"
        case eventId = "event_id"
        case key
        case inReplyTo = "m.in_reply_to"
    }
}


