//
//  ReactionContent.swift
//  
//
//  Created by Charles Wright on 12/12/22.
//

import Foundation

struct ReactionContent: Codable {
    struct RelatesTo: Codable {
        enum RelType: String, Codable {
            case annotation = "m.annotation"
        }
        var relType: RelType
        var eventId: EventId
        var key: String
        
        enum CodingKeys: String, CodingKey {
            case relType = "rel_type"
            case eventId = "event_id"
            case key
        }
    }
    var relatesTo: RelatesTo
    
    enum CodingKeys: String, CodingKey {
        case relatesTo = "m.relates_to"
    }
    
    init(eventId: EventId, reaction: String) {
        self.relatesTo = RelatesTo(relType: .annotation, eventId: eventId, key: reaction)
    }
}
