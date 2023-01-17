//
//  TypingContent.swift
//  
//
//  Created by Michael Hollister on 12/29/22.
//

import Foundation

/// m.typing: https://spec.matrix.org/v1.5/client-server-api/#mtyping
public struct TypingContent: Codable {
    public let userIds: [UserId]
    
    public enum CodingKeys: String, CodingKey {
        case userIds = "user_ids"
    }
}
