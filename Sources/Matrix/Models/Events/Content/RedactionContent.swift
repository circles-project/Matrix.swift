//
//  RedactionContent.swift
//  
//
//  Created by Charles Wright on 9/6/23.
//

import Foundation

public struct RedactionContent: Codable {
    public let reason: String?
    public let redacts: EventId?
    
    public init(reason: String? = nil, redacts: EventId? = nil) {
        self.reason = reason
        self.redacts = redacts
    }
    
    public init(from decoder: Decoder) throws {
        Matrix.logger.debug("Decoding m.room.redaction")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let _reason = try container.decodeIfPresent(String.self, forKey: .reason)
        let _redacts = try container.decodeIfPresent(EventId.self, forKey: .redacts)
        Matrix.logger.debug("m.room.redaction { \"reason\" = \"\(_reason ?? "(none)")\", \"redacts\" = \"\(_redacts ?? "???")\"}")
        self.reason = _reason
        self.redacts = _redacts
    }
}
