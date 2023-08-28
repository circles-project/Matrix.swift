//
//  MatrixClientEvent.swift
//
//
//  Created by Charles Wright on 5/17/22.
//

import Foundation
import AnyCodable

public class ClientEvent: ClientEventWithoutRoomId {
    public let roomId: RoomId

    public override var description: String {
        return """
               ClientEvent: {eventId: \(eventId), roomId: \(roomId), \
               originServerTS:\(originServerTS), sender: \(sender), \
               stateKey: \(String(describing: stateKey)), type: \(type), \
               content: \(content), unsigned: \(String(describing: unsigned))}
               """
    }
    
    public enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
    }
    
    public init(content: Codable, eventId: String, originServerTS: UInt64, roomId: RoomId,
                sender: UserId, stateKey: String? = nil, type: String,
                unsigned: UnsignedData? = nil) throws {
        self.roomId = roomId
        try super.init(content: content, eventId: eventId, originServerTS: originServerTS, sender: sender, stateKey: stateKey, type: type, unsigned: unsigned)
    }
    
    public convenience init(from: ClientEventWithoutRoomId, roomId: RoomId) throws {
        try self.init(content: from.content, eventId: from.eventId,
                      originServerTS: from.originServerTS, roomId: roomId,
                      sender: from.sender, type: from.type,
                      unsigned: from.unsigned)
    }
    
    public required init(from decoder: Decoder) throws {
        //Matrix.logger.debug("Decoding ClientEvent")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.roomId = try container.decode(RoomId.self, forKey: .roomId)
        //Matrix.logger.debug("\troomid")
        try super.init(from: decoder)
    }
    
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(roomId, forKey: .roomId)
        try super.encode(to: encoder)
    }
}
