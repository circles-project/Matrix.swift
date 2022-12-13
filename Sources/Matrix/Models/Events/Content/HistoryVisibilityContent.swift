//
//  HistoryVisibilityContent.swift
//  
//
//  Created by Charles Wright on 12/13/22.
//

import Foundation

// https://spec.matrix.org/v1.5/client-server-api/#room-history-visibility
struct HistoryVisibilityContent: Codable {
    enum HistoryVisibility: String, Codable {
        case worldReadable = "world_readable"
        case shared
        case invited
        case joined
    }
    var historyVisibility: HistoryVisibility
    
    enum CodingKeys: String, CodingKey {
        case historyVisibility = "history_visibility"
    }
}
