//
//  EncryptedEventContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

public protocol MatrixCiphertext: Codable {}

public struct MegolmCiphertext: MatrixCiphertext {
    public let base64: String
    
    public init(base64: String) {
        self.base64 = base64
    }
    
    public init(from decoder: Decoder) throws {
        self.base64 = try .init(from: decoder)
    }
    
    public func encode(to encoder: Encoder) throws {
        try self.base64.encode(to: encoder)
    }
}

public struct OlmCiphertext: MatrixCiphertext {
    public struct EncryptedPayload: Codable {
        public let type: Int
        public let body: String
        
        public init(type: Int, body: String) {
            self.type = type
            self.body = body
        }
    }
    public let ciphertext: [String: EncryptedPayload]
    
    public init(ciphertext: [String : EncryptedPayload]) {
        self.ciphertext = ciphertext
    }
    
    public init(from decoder: Decoder) throws {
        self.ciphertext = try .init(from: decoder)
    }
    
    public func encode(to encoder: Encoder) throws {
        try self.ciphertext.encode(to: encoder)
    }
}

public struct EncryptedEventContent: Codable {
    public enum Algorithm: String, Codable {
        case olmV1 = "m.olm.v1.curve25519-aes-sha2"
        case megolmV1 = "m.megolm.v1.aes-sha2"
    }
    
    public let algorithm: Algorithm
    public let senderKey: String
    public let deviceId: String
    public let sessionId: String
    public let ciphertext: MatrixCiphertext
    
    public enum CodingKeys: String, CodingKey {
        case algorithm
        case senderKey = "sender_key"
        case deviceId = "device_id"
        case sessionId = "session_id"
        case ciphertext
    }
    
    public init(algorithm: Algorithm, senderKey: String, deviceId: String, sessionId: String,
                ciphertext: MatrixCiphertext) {
        self.algorithm = algorithm
        self.senderKey = senderKey
        self.deviceId = deviceId
        self.sessionId = sessionId
        self.ciphertext = ciphertext
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.algorithm = try container.decode(Algorithm.self, forKey: .algorithm)
        self.senderKey = try container.decode(String.self, forKey: .senderKey)
        self.deviceId = try container.decode(String.self, forKey: .deviceId)
        self.sessionId = try container.decode(String.self, forKey: .sessionId)
        
        switch self.algorithm {
        case .olmV1:
            self.ciphertext = try container.decode(OlmCiphertext.self, forKey: .ciphertext)
        case .megolmV1:
            self.ciphertext = try container.decode(MegolmCiphertext.self, forKey: .ciphertext)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(algorithm, forKey: .algorithm)
        try container.encode(senderKey, forKey: .senderKey)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(ciphertext, forKey: .ciphertext)
    }
}

/*
public struct EventPlaintextPayload: Codable {
    public let type: String
    public let content: MatrixMessageContent
    public let roomId: String
    
    public init(from decoder: Decoder) throws {
        // FIXME: Need to borrow code from MatrixClientEvent to decode this thing
    }
    
    // As with MatrixClientEvent, support for .encode() and Encodable should be automatic, since the only ambiguity is on the input side.
    // Once we have a Codable MatrixMessageContent, whatever it is, it knows how to encode itself.
}
*/
