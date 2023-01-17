//
//  RoomTopicContent.swift
//
//
//  Created by Charles Wright on 5/19/22.
//

import Foundation

/// m.room.topic: https://spec.matrix.org/v1.5/client-server-api/#mroomtopic
struct RoomTopicContent: Codable {
    let topic: String
}
