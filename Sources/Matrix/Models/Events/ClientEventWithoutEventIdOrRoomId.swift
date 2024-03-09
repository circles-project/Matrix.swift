//
//  File.swift
//  
//
//  Created by Charles Wright on 3/8/24.
//

import Foundation
import AnyCodable

// cvw: This is nonsense.  Why can't /rooms/{roomId}/event/{eventId} just return a normal damn event?? FFS!
//      Oh well I guess it is what it is...

public class ClientEventWithoutEventIdOrRoomId: Matrix.Event, Codable {
    public let originServerTS: UInt64
    //public let roomId: String
    public let sender: UserId
    public let stateKey: String?
    public let type: String
    public let content: Codable
    public let unsigned: UnsignedData?
    
    public var description: String {
        return """
               ClientEventWithoutEventIdOrRoomId: {originServerTS:\(originServerTS), \
               sender: \(sender), stateKey: \(String(describing: stateKey)), type: \(type), \
               content: \(content), unsigned: \(String(describing: unsigned))}
               """
    }
    
    public enum CodingKeys: String, CodingKey {
        case content
        case originServerTS = "origin_server_ts"
        //case roomId = "room_id"
        case sender
        case stateKey = "state_key"
        case type
        case unsigned
    }
    
    public init(content: Codable, originServerTS: UInt64, sender: UserId,
                stateKey: String? = nil, type: String,
                unsigned: UnsignedData? = nil) throws {
        self.content = content
        self.originServerTS = originServerTS
        self.sender = sender
        self.stateKey = stateKey
        self.type = type
        self.unsigned = unsigned
    }
    
    required public init(from decoder: Decoder) throws {
        Matrix.logger.debug("Decoding ClientEventWithoutEventIdOrRoomId")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.originServerTS = try container.decode(UInt64.self, forKey: .originServerTS)
        //self.roomId = try container.decode(String.self, forKey: .roomId)
        self.sender = try container.decode(UserId.self, forKey: .sender)
        self.stateKey = try container.decodeIfPresent(String.self, forKey: .stateKey)
        
        let type = try container.decode(String.self, forKey: .type)
        Matrix.logger.debug("  type = \(type)")
        self.type = type
        
        self.unsigned = try container.decodeIfPresent(UnsignedData.self, forKey: .unsigned)
         
        self.content = try Matrix.decodeEventContent(of: self.type, from: decoder)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
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
