//
//  FullyReadContent.swift
//
//
//  Created by Charles Wright on 10/16/23.
//

import Foundation

public struct FullyReadContent: Codable {
    var eventId: EventId
    
    public enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
    }
}
