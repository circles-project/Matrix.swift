//
//  ReactionContent.swift
//  
//
//  Created by Charles Wright on 12/12/22.
//

import Foundation

/// m.reaction: https://github.com/uhoreg/matrix-doc/blob/aggregations-reactions/proposals/2677-reactions.md
public struct ReactionContent: Codable {
    public struct RelatesTo: Codable {
        public enum RelType: String, Codable {
            case annotation = "m.annotation"
        }
        public let relType: RelType
        public let eventId: EventId
        public let key: String
        
        public enum CodingKeys: String, CodingKey {
            case relType = "rel_type"
            case eventId = "event_id"
            case key
        }
    }
    public let relatesTo: RelatesTo
    
    public enum CodingKeys: String, CodingKey {
        case relatesTo = "m.relates_to"
    }
    
    public init(eventId: EventId, reaction: String) {
        self.relatesTo = RelatesTo(relType: .annotation, eventId: eventId, key: reaction)
    }
}
