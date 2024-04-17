//
//  ClientEventWithoutRoomId.swift
//
//
//  Created by Charles Wright on 5/19/22.
//

import Foundation
import os
import AnyCodable

public class ClientEventWithoutRoomId: Matrix.Event, Codable {
    public let eventId: String
    public let originServerTS: UInt64
    //public let roomId: String
    public let sender: UserId
    public let stateKey: String?
    public let type: String
    public let content: Codable
    public let unsigned: UnsignedData?
    
    private(set) public static var logger: os.Logger?
    
    public static func setLogger(_ logger: os.Logger?) {
        Self.logger = logger
    }
    
    public static func enableLogging() {
        Self.logger = os.Logger(subsystem: "Matrix", category: "ClientEventWithoutRoomId")
    }
    
    public static func disableLogging() {
        Self.logger = nil
    }
    
    public var description: String {
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
    
    public init(content: Codable, eventId: String, originServerTS: UInt64, sender: UserId,
                stateKey: String? = nil, type: String,
                unsigned: UnsignedData? = nil) throws {
        self.content = content
        self.eventId = eventId
        self.originServerTS = originServerTS
        self.sender = sender
        self.stateKey = stateKey
        self.type = type
        self.unsigned = unsigned
    }
    
    required public init(from decoder: Decoder) throws {
        Self.logger?.debug("Decoding ClientEventWithoutRoomId")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let eventId = try container.decode(String.self, forKey: .eventId)
        Self.logger?.debug("  eventId = \(eventId)")
        self.eventId = eventId
        
        self.originServerTS = try container.decode(UInt64.self, forKey: .originServerTS)
        //self.roomId = try container.decode(String.self, forKey: .roomId)
        self.sender = try container.decode(UserId.self, forKey: .sender)
        self.stateKey = try container.decodeIfPresent(String.self, forKey: .stateKey)
        
        let type = try container.decode(String.self, forKey: .type)
        Self.logger?.debug("  type = \(type)")
        self.type = type
        
        self.unsigned = try container.decodeIfPresent(UnsignedData.self, forKey: .unsigned)
         
        self.content = try Matrix.decodeEventContent(of: self.type, from: decoder)
        Self.logger?.debug("  done with event \(eventId)")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventId, forKey: .eventId)
        try container.encode(originServerTS, forKey: .originServerTS)
        try container.encode(sender, forKey: .sender)
        try container.encodeIfPresent(stateKey, forKey: .stateKey)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(unsigned, forKey: .unsigned)
        try container.encode(AnyCodable(content), forKey: .content)
    }
    
    public lazy var timestamp: Date = {
        let seconds: TimeInterval = Double(self.originServerTS) / 1000.0
        return Date(timeIntervalSince1970: seconds)
    }()
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
