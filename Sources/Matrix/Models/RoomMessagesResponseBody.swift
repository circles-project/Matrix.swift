//
//  RoomMessagesResponseBody.swift
//  
//
//  Created by Charles Wright on 3/14/23.
//

import Foundation

public struct RoomMessagesResponseBody: Codable {
    public var chunk: [ClientEventWithoutRoomId]
    public var end: String?
    public var start: String
    public var state: [ClientEventWithoutRoomId]?
}
