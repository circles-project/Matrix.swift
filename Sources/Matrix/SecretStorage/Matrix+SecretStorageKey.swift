//
//  Matrix+SecretStorageKey.swift
//  
//
//  Created by Charles Wright on 8/15/23.
//

import Foundation

import IDZSwiftCommonCrypto
import Base58Swift

extension Matrix {
    public struct SecretStorageKey {
        public var key: Data
        public var keyId: String
        public var description: KeyDescriptionContent
        
        public init(key: Data, keyId: String, description: KeyDescriptionContent) {
            self.key = key
            self.keyId = keyId
            self.description = description
        }
        
        // https://spec.matrix.org/v1.8/client-server-api/#deriving-keys-from-passphrases
        public init(passphrase: String, keyId: String, description: KeyDescriptionContent) throws {
            guard description.passphrase?.algorithm == M_PBKDF2
            else {
                Matrix.logger.error("Passphrase algorithm must be m.pbkdf2")
                throw Matrix.Error("Passphrase algorithm must be m.pbkdf2")
            }
            
            guard let salt = description.passphrase?.salt,
                  let iterations = description.passphrase?.iterations,
                  let bits = description.passphrase?.bits
            else {
                Matrix.logger.error("Missing information for generating m.pbkdf2 passphrase")
                throw Matrix.Error("Missing information for generating m.pbkdf2 passphrase")
            }
            let byteLen = UInt(bits) / 8
            
            let keyBytes = PBKDF.deriveKey(password: passphrase,
                                           salt: salt,
                                           prf: .sha512,
                                           rounds: UInt32(iterations),
                                           derivedKeyLength: byteLen)
            
            self.key = Data(keyBytes)
            self.keyId = keyId
            self.description = description
        }
        
        // https://spec.matrix.org/v1.8/client-server-api/#key-representation
        public init(raw: String, keyId: String, description: KeyDescriptionContent) throws {
            let base58 = raw.replacingOccurrences(of: " ", with: "")
            
            guard let bytes = Base58.base58Decode(base58)
            else {
                Matrix.logger.error("Failed to decode base58 key \(keyId)")
                throw Matrix.Error("Invalid base58 key")
            }
            
            // This should be zero, because it includes the final parity byte
            // That last byte should cancel out any bits that were set by the previous bytes
            let parity = bytes.reduce(0) { (curr,next) in
                curr ^ next
            }
            
            guard bytes.count - 3 == 32,  // We need a 256-bit key, plus 2 "header" bytes and one trailing parity byte
                  bytes[0] == 0x8b,       // First header byte
                  bytes[1] == 0x01,       // Second header byte
                  parity == 0             // Computed parity, including the final "parity" byte to cancel everything out to zero
            else {
                Matrix.logger.error("Invalid raw string for secret storage key \(keyId)")
                throw Matrix.Error("Invalid raw string for secret storage key \(keyId)")
            }
            
            let keyBytes = bytes[2...34]
            let key = Data(keyBytes)
            
            if description.iv != nil && description.mac != nil {
                guard try description.validate(key: key)
                else {
                    Matrix.logger.error("Failed to validate raw SSSS key \(keyId, privacy: .public)")
                    throw Matrix.Error("Failed to validate raw SSSS key")
                }
            }
            
            self.key = key
            self.keyId = keyId
            self.description = description
        }
        
        // https://spec.matrix.org/v1.8/client-server-api/#key-representation
        public var base58String: String {
            let keyBytes = Array<UInt8>(self.key)
            let parity: UInt8 = keyBytes.reduce(0x8b^0x01) { (curr,next) in
                curr ^ next
            }
            let bytes = [0x8b, 0x01] + keyBytes + [parity]
            
            // This should be easier but Swift makes String kind of a pain
            let base58String = Base58.base58Encode(bytes)
            let base58Data = base58String.data(using: .utf8)!
            let base58Bytes = [UInt8](base58Data)

            let chunks = base58Bytes.chunked(into: 4)
            let strings: [String] = chunks.compactMap { String(bytes: $0, encoding: .utf8) }
            return strings.joined(separator: " ")
        }
    }
}
