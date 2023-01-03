//
//  CreateContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

/// m.room.create: https://spec.matrix.org/v1.5/client-server-api/#mroomcreate
struct CreateContent: Codable {
    let creator: String
    /// Whether users on other servers can join this room. Defaults to true if key does not exist.
    let federate: Bool?
    
    struct PreviousRoom: Codable {
        let eventId: String
        let roomId: RoomId
    }
    let predecessor: PreviousRoom?
    
    /// The version of the room. Defaults to "1" if the key does not exist.
    let roomVersion: String?
    let type: String?
}
