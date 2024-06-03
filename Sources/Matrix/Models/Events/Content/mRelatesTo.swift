//
//  mRelatesTo.swift
//
//
//  Created by Charles Wright on 4/21/23.
//

import Foundation
import os

public struct mRelatesTo: Codable {
    
    private(set) public static var logger: os.Logger?
    
    public static func setLogger(_ logger: os.Logger?) {
        Self.logger = logger
    }

    public struct mInReplyTo: Codable {
        var eventId: EventId
        public enum CodingKeys: String, CodingKey {
            case eventId = "event_id"
        }
        public init(eventId: EventId) {
            self.eventId = eventId
        }
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: mRelatesTo.mInReplyTo.CodingKeys.self)
            self.eventId = try container.decode(EventId.self, forKey: mRelatesTo.mInReplyTo.CodingKeys.eventId)
        }
    }
    public let relType: String?
    public let eventId: EventId?
    public let key: String?
    public let inReplyTo: mInReplyTo?
    public let isFallingBack: Bool?
    
    public init(relType: String?, eventId: EventId?, key: String? = nil,
                inReplyTo: EventId? = nil, isFallingBack: Bool? = false) {
        self.relType = relType
        self.eventId = eventId
        self.key = key
        if let parentEventId = inReplyTo {
            self.inReplyTo = mInReplyTo(eventId: parentEventId)
        } else {
            self.inReplyTo = nil
        }
        self.isFallingBack = isFallingBack
    }
    
    public init(inReplyTo: EventId) {
        self.relType = nil
        self.eventId = nil
        self.key = nil
        self.inReplyTo = mInReplyTo(eventId: inReplyTo)
        self.isFallingBack = nil
    }
    
    public static func richReply(to parent: EventId) -> mRelatesTo {
        return .init(inReplyTo: parent)
    }
    
    public static func threadedReply(to parent: EventId) -> mRelatesTo {
        return .init(relType: M_THREAD, eventId: parent, inReplyTo: .init(parent), isFallingBack: true)
    }
    
    public static func replacing(_ old: EventId) -> mRelatesTo {
        return .init(relType: M_REPLACE, eventId: old)
    }
    
    public enum CodingKeys: String, CodingKey {
        case relType = "rel_type"
        case eventId = "event_id"
        case key
        case inReplyTo = "m.in_reply_to"
        case isFallingBack = "is_falling_back"
    }
    
    public init(from decoder: Decoder) throws {
        Self.logger?.debug("Decoding mRelatesTo")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        Self.logger?.debug("Decoding mRelatesTo.relType")
        self.relType = try container.decodeIfPresent(String.self, forKey: .relType)

        Self.logger?.debug("Decoding mRelatesTo.eventId")
        self.eventId = try container.decodeIfPresent(EventId.self, forKey: .eventId)

        Self.logger?.debug("Decoding mRelatesTo.key")
        self.key = try container.decodeIfPresent(String.self, forKey: .key)

        Self.logger?.debug("Decoding mRelatesTo.inReplyTo")
        self.inReplyTo = try container.decodeIfPresent(mRelatesTo.mInReplyTo.self, forKey: .inReplyTo)

        Self.logger?.debug("Decoding mRelatesTo.isFallingBack")
        self.isFallingBack = try container.decodeIfPresent(Bool.self, forKey: .isFallingBack)
        
        Self.logger?.debug("Done decoding mRelatesTo")
    }
}


