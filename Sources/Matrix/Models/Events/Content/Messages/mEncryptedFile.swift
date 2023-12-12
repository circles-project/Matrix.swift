//
//  mEncryptedFile.swift
//
//
//  Created by Charles Wright on 12/12/23.
//

import Foundation

extension Matrix {
    // https://matrix.org/docs/spec/client_server/r0.6.0#extensions-to-m-message-msgtypes
    public struct mEncryptedFile: Codable {
        public var url: MXC
        public var key: JWK
        public var iv: String
        public var hashes: [String: String]
        public var v: String
        
        public enum CodingKeys: String, CodingKey {
            case url
            case key
            case iv
            case hashes
            case v
        }
        
        public init(url: MXC, key: JWK, iv: String, hashes: [String : String], v: String) {
            self.url = url
            self.key = key
            self.iv = iv
            self.hashes = hashes
            self.v = v
        }
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<Matrix.mEncryptedFile.CodingKeys> = try decoder.container(keyedBy: Matrix.mEncryptedFile.CodingKeys.self)
            
            self.url = try container.decode(MXC.self, forKey: Matrix.mEncryptedFile.CodingKeys.url)
            
            self.key = try container.decode(Matrix.JWK.self, forKey: Matrix.mEncryptedFile.CodingKeys.key)
            
            let unpaddedIV = try container.decode(String.self, forKey: Matrix.mEncryptedFile.CodingKeys.iv)
            self.iv = Base64.ensurePadding(unpaddedIV)!
            
            let unpaddedHashes = try container.decode([String : String].self, forKey: Matrix.mEncryptedFile.CodingKeys.hashes)
            self.hashes = unpaddedHashes.compactMapValues {
                Base64.ensurePadding($0)
            }
            
            self.v = try container.decode(String.self, forKey: Matrix.mEncryptedFile.CodingKeys.v)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(url, forKey: .url)
            try container.encode(key, forKey: .key)
            
            guard let unpaddedIV = Base64.removePadding(iv)
            else {
                Matrix.logger.error("Couldn't remove base64 padding")
                throw Matrix.Error("Couldn't remove base64 padding")
            }
            try container.encode(unpaddedIV, forKey: .iv)
            
            let unpaddedHashes = hashes.compactMapValues {
                Base64.removePadding($0)
            }
            try container.encode(unpaddedHashes, forKey: .hashes)
            
            try container.encode(v, forKey: .v)
        }
    }

}
