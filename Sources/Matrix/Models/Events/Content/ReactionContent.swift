//
//  ReactionContent.swift
//  
//
//  Created by Charles Wright on 12/12/22.
//

import Foundation

/// m.reaction: https://github.com/uhoreg/matrix-doc/blob/aggregations-reactions/proposals/2677-reactions.md
public struct ReactionContent: RelatedEventContent {

    public var relatesTo: mRelatesTo
    
    public enum CodingKeys: String, CodingKey {
        case relatesTo = "m.relates_to"
    }
    
    public init(eventId: EventId, reaction: String) {
        self.relatesTo = mRelatesTo(relType: M_ANNOTATION, eventId: eventId, key: reaction)
    }
    
    public init(relatesTo: mRelatesTo) {
        self.relatesTo = relatesTo
    }
    
    public var relationType: String? {
        self.relatesTo.relType
    }
    
    public var relatedEventId: EventId? {
        self.relatesTo.eventId
    }
    
    public var replyToEventId: EventId? {
        nil
    }
    
    public var replacesEventId: EventId? {
        nil
    }
    
    public func mentions(userId: UserId) -> Bool {
        false
    }
}
