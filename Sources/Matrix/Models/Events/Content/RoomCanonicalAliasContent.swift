//
//  RoomCanonicalAliasContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

/// m.room.canonical_alias: https://spec.matrix.org/v1.5/client-server-api/#mroomcanonical_alias
struct RoomCanonicalAliasContent: Codable {
    let alias: String
    let altAliases: [String]
    
    enum CodingKeys: String, CodingKey {
        case alias
        case altAliases = "alt_aliases"
    }
}
