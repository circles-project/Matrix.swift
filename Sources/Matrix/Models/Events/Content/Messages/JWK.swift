//
//  JWK.swift
//
//
//  Created by Charles Wright on 12/12/23.
//

import Foundation

extension Matrix {
    // https://matrix.org/docs/spec/client_server/r0.6.0#extensions-to-m-message-msgtypes
    public struct JWK: Codable {
        public enum KeyType: String, Codable {
            case oct
        }
        public enum KeyOperation: String, Codable {
            case encrypt
            case decrypt
        }
        public enum Algorithm: String, Codable {
            case A256CTR
        }

        public var kty: KeyType
        public var key_ops: [KeyOperation]
        public var alg: Algorithm
        public var k: String
        public var ext: Bool

        public init?(_ key: [UInt8]) {
            self.kty = .oct
            self.key_ops = [.decrypt, .encrypt]
            self.alg = .A256CTR
            guard let b64key = Base64.unpadded(key, urlSafe: true)
            else {
                Matrix.logger.error("Failed to convert JWK key to urlsafe base64")
                return nil
            }
            self.k = b64key
            self.ext = true
        }
        
        public init?(kty: KeyType, key_ops: [KeyOperation], alg: Algorithm, k: String, ext: Bool) {
            self.kty = kty
            self.key_ops = key_ops
            self.alg = alg
            guard let b64key = Base64.removePadding(k)?
                                     .replacingOccurrences(of: "/", with: "_")
                                     .replacingOccurrences(of: "+", with: "-")
            else {
                Matrix.logger.error("Failed to convert JWK key to urlsafe base64")
                return nil
            }
            self.k = b64key
            self.ext = ext
        }
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
            self.kty = try container.decode(KeyType.self, forKey: .kty)
            self.key_ops = try container.decode([KeyOperation].self, forKey: .key_ops)
            self.alg = try container.decode(Matrix.JWK.Algorithm.self, forKey: .alg)
            let unpaddedKey = try container.decode(String.self, forKey: .k)
            guard let paddedKey = Base64.ensurePadding(unpaddedKey)
            else {
                throw Matrix.Error("Failed to ensure padding on JWK key")
            }
            self.k = paddedKey
            self.ext = try container.decode(Bool.self, forKey: Matrix.JWK.CodingKeys.ext)
        }
        
        public enum CodingKeys: CodingKey {
            case kty
            case key_ops
            case alg
            case k
            case ext
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Matrix.JWK.CodingKeys.self)
            try container.encode(self.kty, forKey: Matrix.JWK.CodingKeys.kty)
            try container.encode(self.key_ops, forKey: Matrix.JWK.CodingKeys.key_ops)
            try container.encode(self.alg, forKey: Matrix.JWK.CodingKeys.alg)
            let unpaddedK = Base64.removePadding(self.k)!
            try container.encode(unpaddedK, forKey: Matrix.JWK.CodingKeys.k)
            try container.encode(self.ext, forKey: Matrix.JWK.CodingKeys.ext)
        }
    }

}
