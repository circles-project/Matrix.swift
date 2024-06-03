//
//  ReactionContent.swift
//  
//
//  Created by Charles Wright on 12/12/22.
//

import Foundation
import os

/// m.reaction: https://github.com/uhoreg/matrix-doc/blob/aggregations-reactions/proposals/2677-reactions.md
public struct ReactionContent: RelatedEventContent {
    
    private(set) public static var logger: os.Logger?

    public static func setLogger(_ logger: os.Logger?) {
        Self.logger = logger
    }

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
    
    public init(from decoder: Decoder) throws {
        Self.logger?.debug("Decoding ReactionContent")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        Self.logger?.debug("Decoding ReactionContent.relatesTo")
        self.relatesTo = try container.decode(mRelatesTo.self, forKey: .relatesTo)
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
