//
//  SyncFilter.swift
//
//
//  Created by Charles Wright on 1/10/24.
//

import Foundation

extension Matrix {
    struct SyncFilter: Codable {
        var accountData: EventFilter?
        var eventFields: [String]?
        var eventFormat: EventFormat?
        enum EventFormat: String, Codable {
            case client
            case federation
        }
        var presence: EventFilter?
        var room: RoomFilter?
        
        enum CodingKeys: String, CodingKey {
            case accountData = "account_data"
            case eventFields = "event_fields"
            case eventFormat = "event_format"
            case presence
            case room
        }
    }
}
