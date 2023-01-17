//
//  ReactionContent.swift
//  
//
//  Created by Charles Wright on 12/12/22.
//

import Foundation

/// m.reaction: https://github.com/uhoreg/matrix-doc/blob/aggregations-reactions/proposals/2677-reactions.md
struct ReactionContent: Codable {
    struct RelatesTo: Codable {
        enum RelType: String, Codable {
            case annotation = "m.annotation"
        }
        let relType: RelType
        let eventId: EventId
        let key: String
        
        enum CodingKeys: String, CodingKey {
            case relType = "rel_type"
            case eventId = "event_id"
            case key
        }
    }
    let relatesTo: RelatesTo
    
    enum CodingKeys: String, CodingKey {
        case relatesTo = "m.relates_to"
    }
    
    init(eventId: EventId, reaction: String) {
        self.relatesTo = RelatesTo(relType: .annotation, eventId: eventId, key: reaction)
    }
}
