//
//  RoomMessagesResponseBody.swift
//  
//
//  Created by Charles Wright on 3/14/23.
//

import Foundation

public struct RoomMessagesResponseBody: Codable {
    var chunk: [ClientEventWithoutRoomId]
    var end: String?
    var start: String
    var state: [ClientEventWithoutRoomId]?
}
