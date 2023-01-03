//
//  RoomHistoryVisibilityContent.swift
//  
//
//  Created by Michael Hollister on 1/3/23.
//

import Foundation

/// m.room.history_visibility: https://spec.matrix.org/v1.5/client-server-api/#mroomhistory_visibility
struct RoomHistoryVisibilityContent: Codable {
    enum HistoryVisibility: String, Codable {
        case invited
        case joined
        case shared
        case world_readable
    }
    
    var historyVisibility: HistoryVisibility
    
    enum CodingKeys: String, CodingKey {
        case historyVisibility = "history_visibility"
    }
}
