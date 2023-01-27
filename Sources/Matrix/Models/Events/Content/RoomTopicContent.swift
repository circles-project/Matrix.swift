//
//  RoomTopicContent.swift
//
//
//  Created by Charles Wright on 5/19/22.
//

import Foundation

/// m.room.topic: https://spec.matrix.org/v1.5/client-server-api/#mroomtopic
public struct RoomTopicContent: Codable {
    public let topic: String
    
    public init(topic: String) {
        self.topic = topic
    }
}
