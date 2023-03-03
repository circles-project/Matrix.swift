//
//  EncryptedEventContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation
import AnyCodable

public protocol MatrixCiphertext: Codable {}

public struct MegolmPlaintext: Codable {
    public let type: String
    public let content: Codable
    public let roomId: RoomId
    
    public enum CodingKeys: String, CodingKey {
        case type
        case content
        case roomId = "room_id"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.content = try Matrix.decodeEventContent(of: self.type, from: decoder)
        self.roomId = try container.decode(RoomId.self, forKey: .roomId)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.type, forKey: .type)
        try container.encode(AnyCodable(self.content), forKey: .content)
        try container.encode(self.roomId, forKey: .roomId)
    }
}

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

public struct OlmPlaintext: Codable {
    public let type: String
    public let content: String // Codable ???
    public let sender: UserId
    public let recipient: UserId
    public let recipientKeys: [String: String]
    public let keys: [String: String]
    
    public enum CodingKeys: String, CodingKey {
        case type
        case content
        case sender
        case recipient
        case recipientKeys = "recipient_keys"
        case keys
    }
}

public struct OlmCiphertext: MatrixCiphertext {
    public struct EncryptedPayload: Codable {
        public enum MessageType: Int, Codable {
            case preKey = 0
            case ordinary = 1
        }
        public let type: MessageType
        public let body: String
        
        public init(type: MessageType, body: String) {
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
    public let algorithm: EncryptionAlgorithm
    public let ciphertext: MatrixCiphertext
    public let deviceId: String?
    public let senderKey: String?
    public let sessionId: String?
    
    public enum CodingKeys: String, CodingKey {
        case algorithm
        case ciphertext
        case deviceId = "device_id"
        case senderKey = "sender_key"
        case sessionId = "session_id"
    }
    
    public init(algorithm: EncryptionAlgorithm,
                ciphertext: MatrixCiphertext,
                deviceId: String?,
                senderKey: String?,
                sessionId: String?
    ) {
        self.algorithm = algorithm
        self.senderKey = senderKey
        self.deviceId = deviceId
        self.sessionId = sessionId
        self.ciphertext = ciphertext
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.algorithm = try container.decode(EncryptionAlgorithm.self, forKey: .algorithm)
        switch self.algorithm {
        case .olmV1:
            self.ciphertext = try container.decode(OlmCiphertext.self, forKey: .ciphertext)
        case .megolmV1:
            self.ciphertext = try container.decode(MegolmCiphertext.self, forKey: .ciphertext)
        }
        
        self.deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
        self.senderKey = try container.decodeIfPresent(String.self, forKey: .senderKey)
        self.sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(algorithm, forKey: .algorithm)
        try container.encode(ciphertext, forKey: .ciphertext)
        
        try container.encodeIfPresent(deviceId, forKey: .deviceId)
        try container.encodeIfPresent(senderKey, forKey: .senderKey)
        try container.encodeIfPresent(sessionId, forKey: .sessionId)
    }
}
