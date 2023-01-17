//
//  PresenceContent.swift
//  
//
//  Created by Michael Hollister on 12/28/22.
//

import Foundation

/// m.presence: https://spec.matrix.org/v1.5/client-server-api/#mpresence
public struct PresenceContent: Codable {
    public let avatarUrl: String?
    public let currentlyActive: Bool?
    public let displayname: String?
    public let lastActiveAgo: Int?

    public enum Presence: String, Codable {
        case online
        case offline
        case unavailable
    }
    
    public let presence: Presence
    public let statusMessage: String?
    
    public enum CodingKeys: String, CodingKey {
        case avatarUrl = "avatar_url"
        case currentlyActive = "currently_active"
        case displayname
        case lastActiveAgo = "last_active_ago"
        case presence
        case statusMessage = "status_msg"
    }
}
