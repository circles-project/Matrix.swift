//
//  EventFilter.swift
//
//
//  Created by Charles Wright on 1/10/24.
//

import Foundation

extension Matrix {
    // https://spec.matrix.org/v1.9/client-server-api/#post_matrixclientv3useruseridfilter
    struct EventFilter: Codable {
        var limit: UInt?
        var notSenders: [UserId]?
        var notTypes: [String]?
        var senders: [UserId]?
        var types: [String]?
        
        enum CodingKeys: String, CodingKey {
            case limit
            case notSenders = "not_senders"
            case notTypes = "not_types"
            case senders
            case types
        }
    }
}
