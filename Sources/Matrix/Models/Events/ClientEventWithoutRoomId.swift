//
//  ClientEventWithoutRoomId.swift
//
//
//  Created by Charles Wright on 5/19/22.
//

import Foundation
import AnyCodable

public class ClientEventWithoutRoomId: ClientEventWithoutEventIdOrRoomId {
    public let eventId: String
    
    public override var description: String {
        return """
               ClientEventWithoutRoomId: {eventId: \(eventId), originServerTS:\(originServerTS), \
               sender: \(sender), stateKey: \(String(describing: stateKey)), type: \(type), \
               content: \(content), unsigned: \(String(describing: unsigned))}
               """
    }
    
    public enum CodingKeys: String, CodingKey {
        case content
        case eventId = "event_id"
        case originServerTS = "origin_server_ts"
        //case roomId = "room_id"
        case sender
        case stateKey = "state_key"
        case type
        case unsigned
    }
    
    public convenience init(_ event: ClientEventWithoutEventIdOrRoomId, eventId: EventId) throws {
        try self.init(content: event.content, eventId: eventId, originServerTS: event.originServerTS, sender: event.sender, stateKey: event.stateKey, type: event.type, unsigned: event.unsigned)
    }
    
    public init(content: Codable, eventId: String, originServerTS: UInt64, sender: UserId,
                stateKey: String? = nil, type: String,
                unsigned: UnsignedData? = nil) throws {
        self.eventId = eventId
        try super.init(content: content, originServerTS: originServerTS, sender: sender, stateKey: stateKey, type: type, unsigned: unsigned)
    }
    
    required public init(from decoder: Decoder) throws {
        Matrix.logger.debug("Decoding ClientEventWithoutRoomId")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let eventId = try container.decode(String.self, forKey: .eventId)
        Matrix.logger.debug("  eventId = \(eventId)")
        self.eventId = eventId
        
        try super.init(from: decoder)

        Matrix.logger.debug("  done with event \(eventId)")
    }
    
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventId, forKey: .eventId)
        try super.encode(to: encoder)
    }
}

extension ClientEventWithoutRoomId: Equatable {
    public static func == (lhs: ClientEventWithoutRoomId, rhs: ClientEventWithoutRoomId) -> Bool {
        lhs.eventId == rhs.eventId
    }
}

extension ClientEventWithoutRoomId: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(eventId)
    }
}

extension ClientEventWithoutRoomId: Comparable {
    public static func < (lhs: ClientEventWithoutRoomId, rhs: ClientEventWithoutRoomId) -> Bool {
        lhs.originServerTS < rhs.originServerTS
    }
}
