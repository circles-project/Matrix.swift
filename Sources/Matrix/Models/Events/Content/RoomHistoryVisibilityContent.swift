//
//  RoomHistoryVisibilityContent.swift
//  
//
//  Created by Michael Hollister on 1/3/23.
//

import Foundation

/// m.room.history_visibility: https://spec.matrix.org/v1.5/client-server-api/#mroomhistory_visibility
public struct RoomHistoryVisibilityContent: Codable {
    public enum HistoryVisibility: String, Codable {
        case invited
        case joined
        case shared
        case worldReadable = "world_readable"
    }
    
    public let historyVisibility: HistoryVisibility
    
    public enum CodingKeys: String, CodingKey {
        case historyVisibility = "history_visibility"
    }
}
