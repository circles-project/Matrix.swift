//
//  File.swift
//  
//
//  Created by Charles Wright on 4/24/23.
//

import Foundation
import GRDB

class ClientEventRecord: ClientEvent, FetchableRecord, TableRecord, PersistableRecord {
    
    enum CodingKeys: String, CodingKey {
        case relationshipType = "rel_type"
        case relatedEventId = "related_eventid"
    }
    
    enum Columns: String, ColumnExpression {
        case content
        case eventId = "event_id"
        case originServerTS = "origin_server_ts"
        case roomId = "room_id"
        case sender
        case stateKey = "state_key"
        case type
        case unsigned
        case relationshipType = "rel_type"
        case relatedEventId = "related_eventid"
    }

    static public var databaseTableName: String = "timeline"
    
    
    var relationshipType: String? {
        if let relatedContent = self.content as? RelatedEventContent {
            return relatedContent.relationType
        } else {
            return nil
        }
    }
    var relatedEventId: EventId? {
        if let relatedContent = self.content as? RelatedEventContent {
            return relatedContent.relatedEventId
        } else {
            return nil
        }
    }
    
    public override var description: String {
        return """
               ClientEventRecord: {eventId: \(eventId), roomId: \(roomId), \
               originServerTS:\(originServerTS), sender: \(sender), \
               stateKey: \(String(describing: stateKey)), type: \(type), \
               content: \(content), unsigned: \(String(describing: unsigned)), \
               relationshipType: \(String(describing: relationshipType)), \
               relatedEventId: \(String(describing: relatedEventId))}
               """
    }
    
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
    
    init(event: ClientEvent) throws {
        try super.init(content: event.content, eventId: event.eventId, originServerTS: event.originServerTS, roomId: event.roomId, sender: event.sender, stateKey: event.stateKey, type: event.type, unsigned: event.unsigned)
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(relationshipType, forKey: .relationshipType)
        try container.encodeIfPresent(relatedEventId, forKey: .relatedEventId)
    }
}


