//
//  KeyId.swift
//  
//
//  Created by Charles Wright on 5/3/23.
//

import Foundation

// https://spec.matrix.org/v1.6/client-server-api/#key-storage
// > Each key has an ID, and the description of the key is stored in the user’s
// > account data using the event type m.secret_storage.key.[key ID].

public struct KeyId: Codable, LosslessStringConvertible, Identifiable, Hashable {
    
    public var id: String
    
    public var description: String {
        "m.secret_storage.key.\(id)"
    }
    
    public init(_ id: String) {
        self.id = id
    }
    
    public init(from decoder: Decoder) throws {
        let string = try String(from: decoder)
        
        guard string.starts(with: "m.secret_storage.key.")
        else {
            throw Matrix.Error("Invalid secret storage key")
        }
        
        self.id = String(string.dropFirst("m.secret_storage.key.".count))
    }
    
    public enum CodingKeys: CodingKey {
        case id
    }
    
    public func encode(to encoder: Encoder) throws {
        try self.description.encode(to: encoder)
    }
    
}

extension KeyId: CodingKey {
    public var stringValue: String {
        description
    }
    
    public var intValue: Int? {
        nil
    }
    
    public init?(stringValue: String) {
        guard stringValue.starts(with: "m.secret_storage.key.")
        else { return nil }
        self.id = String(stringValue.dropFirst("m.secret_storage.key.".count))
    }
    
    public init?(intValue: Int) {
        nil
    }
}

extension KeyedDecodingContainer {
        
    func decodeIfPresent<T:Decodable>(_ type: Dictionary<KeyId,T>.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> Dictionary<KeyId,T>? {
        if self.contains(key) {
            return try self.decode([KeyId: T].self, forKey: key)
        } else {
            return nil
        }
    }
    
    func decode<T:Decodable>(_ type: Dictionary<KeyId,T>.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> Dictionary<KeyId,T> {
        let subContainer: KeyedDecodingContainer<KeyId> = try self.nestedContainer(keyedBy: KeyId.self, forKey: key)
        var decodedDict = [KeyId:T]()
        for k in subContainer.allKeys {
            decodedDict[k] = try subContainer.decode(T.self, forKey: k)
        }
        return decodedDict
    }
}

extension KeyedEncodingContainer {
    mutating func encode<T:Encodable>(_ dict: Dictionary<KeyId,T>, forKey key: KeyedEncodingContainer<K>.Key) throws {
        var subContainer: KeyedEncodingContainer<KeyId> = self.nestedContainer(keyedBy: KeyId.self, forKey: key)
        for (k,v) in dict {
            try subContainer.encode(v, forKey: k)
        }
    }
    
    mutating func encodeIfPresent<T:Encodable>(_ dict: Dictionary<KeyId,T>?, forKey key: KeyedEncodingContainer<K>.Key) throws {
        if let d = dict {
            try self.encode(d, forKey: key)
        }
    }
}
