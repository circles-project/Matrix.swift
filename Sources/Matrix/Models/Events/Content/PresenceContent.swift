//
//  PresenceContent.swift
//  
//
//  Created by Michael Hollister on 12/28/22.
//

import Foundation

/// m.presence: https://spec.matrix.org/v1.5/client-server-api/#mpresence
struct PresenceContent: Codable {
    let avatarUrl: String?
    let currentlyActive: Bool?
    let displayname: String?
    let lastActiveAgo: Int?

    enum Presence: String, Codable {
        case online
        case offline
        case unavailable
    }
    
    let presence: Presence
    let statusMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case avatarUrl = "avatar_url"
        case currentlyActive = "currently_active"
        case displayname
        case lastActiveAgo = "last_active_ago"
        case presence
        case statusMessage = "status_msg"
    }
}
