//
//  HistoryVisibilityContent.swift
//  
//
//  Created by Charles Wright on 12/13/22.
//

import Foundation

import MatrixSDKCrypto

// https://spec.matrix.org/v1.5/client-server-api/#room-history-visibility
struct HistoryVisibilityContent: Codable {

    var historyVisibility: Matrix.Room.HistoryVisibility
    
    enum CodingKeys: String, CodingKey {
        case historyVisibility = "history_visibility"
    }
}
