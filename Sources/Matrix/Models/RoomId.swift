//
//  RoomId.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

public struct RoomId: LosslessStringConvertible, Codable, Identifiable, Equatable, Hashable, CodingKey {
    public let opaqueId: String
    public let domain: String
    public let port: UInt16?
    
    private static func validate(_ roomId: String) -> Bool {
        let toks = roomId.split(separator: ":")
        // First validate the room id part
        guard roomId.starts(with: "!"),
              toks.count == 2 || toks.count == 3,
              let first = toks.first,
              first.count > 1
        else {
            return false
        }
        // FIXME We could do much more specific validation to the spec https://spec.matrix.org/v1.5/appendices/#server-name
        if toks.count == 3 {
            guard let port = toks.last,
                  port.count < 6,
                  port.allSatisfy({ c in
                      c.isNumber
                  })
            else {
                return false
            }
        }
        let host = toks[1]
        guard !host.isEmpty
        else {
            return false
        }
        return true
    }
    
    public init?(_ stringValue: String) {
        self.init(stringValue: stringValue)
    }
    
    public init?(stringValue: String)  {
        guard RoomId.validate(stringValue) else {
            return nil
        }
        let toks = stringValue.split(separator: ":")

        self.opaqueId = String(toks[0].dropFirst(1))
        self.domain = String(toks[1])
        if toks.count > 2 {
            self.port = UInt16(toks[2])
        } else {
            self.port = nil
        }
    }
    
    public init(from decoder: Decoder) throws {
        let roomId = try String(from: decoder)
        guard let me: RoomId = .init(roomId)
        else {
            let msg = "Invalid room id"
            throw Matrix.Error(msg)
        }
        self = me
    }
    
    public func encode(to encoder: Encoder) throws {
        try self.description.encode(to: encoder)
    }
    
    public var description: String {
        if let p = self.port {
            return "!\(opaqueId):\(domain):\(p)"
        } else {
            return "!\(opaqueId):\(domain)"
        }
    }
    
    public var id: String {
        description
    }

    public static func == (lhs: RoomId, rhs: RoomId) -> Bool {
        lhs.opaqueId == rhs.opaqueId && lhs.domain == rhs.domain && lhs.port == rhs.port
    }
    
    public var stringValue: String {
        description
    }
    
    public var intValue: Int? {
        nil
    }
    
    public init?(intValue: Int) {
        nil
    }
}

extension KeyedDecodingContainer {
        
    func decodeIfPresent<T:Decodable>(_ type: Dictionary<RoomId,T>.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> Dictionary<RoomId,T>? {
        if self.contains(key) {
            return try self.decode([RoomId: T].self, forKey: key)
        } else {
            return nil
        }
    }
    
    func decode<T:Decodable>(_ type: Dictionary<RoomId,T>.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> Dictionary<RoomId,T> {
        let subContainer: KeyedDecodingContainer<RoomId> = try self.nestedContainer(keyedBy: RoomId.self, forKey: key)
        var decodedDict = [RoomId:T]()
        for k in subContainer.allKeys {
            decodedDict[k] = try subContainer.decode(T.self, forKey: k)
        }
        return decodedDict
    }
}

extension KeyedEncodingContainer {
    mutating func encode<T:Encodable>(_ dict: Dictionary<RoomId,T>, forKey key: KeyedEncodingContainer<K>.Key) throws {
        var subContainer: KeyedEncodingContainer<RoomId> = self.nestedContainer(keyedBy: RoomId.self, forKey: key)
        for (k,v) in dict {
            try subContainer.encode(v, forKey: k)
        }
    }
    
    mutating func encodeIfPresent<T:Encodable>(_ dict: Dictionary<RoomId,T>?, forKey key: KeyedEncodingContainer<K>.Key) throws {
        if let d = dict {
            try self.encode(d, forKey: key)
        }
    }
}
