//
//  RoomCanonicalAliasContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

/// m.room.canonical_alias: https://spec.matrix.org/v1.5/client-server-api/#mroomcanonical_alias
public struct RoomCanonicalAliasContent: Codable {
    public let alias: String
    public let altAliases: [String]
    
    public enum CodingKeys: String, CodingKey {
        case alias
        case altAliases = "alt_aliases"
    }
}
