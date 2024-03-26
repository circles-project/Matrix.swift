//
//  KeyDescriptionContent.swift
//  
//
//  Created by Charles Wright on 5/3/23.
//

import Foundation
import CryptoKit
import IDZSwiftCommonCrypto

extension Matrix {
    // https://spec.matrix.org/v1.6/client-server-api/#key-storage
    public struct KeyDescriptionContent: Codable {
        public var name: String?
        public var algorithm: String
        public var passphrase: Passphrase?
        public var iv: String?
        public var mac: String?
        
        public struct Passphrase: Codable {
            public var algorithm: String
            public var salt: String?    // Required for m.pbkdf2
            public var iterations: Int? // Required for m.pbkdf2
            public var bits: Int?
            
            public init(algorithm: String, salt: String?=nil, iterations: Int?=nil, bits: Int?=nil) {
                self.algorithm = algorithm
                self.salt = salt
                self.iterations = iterations
                self.bits = bits
            }
        }
        
        public init(name: String? = nil, algorithm: String, passphrase: Passphrase? = nil, iv: String? = nil, mac: String? = nil) {
            self.name = name
            self.algorithm = algorithm
            self.passphrase = passphrase
            self.iv = iv
            self.mac = mac
        }
        
        public func validate(key: Data) throws -> Bool {
            guard let oldIVString = self.iv,
                  let oldMacString = self.mac,
                  let oldMacData = Base64.data(oldMacString),
                  let iv = Base64.data(oldIVString)
            else {
                logger.error("Key description is invalid")
                throw Matrix.Error("Key description is invalid")
            }
            
            logger.debug("Validating SSSS key with IV=\(oldIVString) MAC=\(oldMacString)")
            
            // Keygen - Use HKDF to derive encryption key and MAC key from master key
            let salt = Array<UInt8>(repeating: 0, count: 32)
                        
            let hac: HashedAuthenticationCode = HKDF<CryptoKit.SHA256>.extract(inputKeyMaterial: SymmetricKey(data: key), salt: salt)
            let keyMaterial = HKDF<CryptoKit.SHA256>.expand(pseudoRandomKey: hac, info: "".data(using: .utf8), outputByteCount: 64)
            
            let (encryptionKey, macKey) = keyMaterial.withUnsafeBytes { bytes in
                let kE = Array(bytes[0..<32])
                let kM = Array(bytes[32..<64])
                return (kE, kM)
            }
            
            let zeroes = [UInt8](repeating: 0, count: 32)
         
            // Encrypt data with encryption key and IV to create ciphertext
            let cryptor = Cryptor(operation: .encrypt,
                                  algorithm: .aes,
                                  mode: .CTR,
                                  padding: .NoPadding,
                                  key: encryptionKey,
                                  iv: [UInt8](iv)
            )
            
            guard let ciphertext = cryptor.update(zeroes)?.final()
            else {
                logger.error("Failed to encrypt")
                throw Matrix.Error("Failed to encrypt")
            }
            logger.debug("Got ciphertext [0x\(Data(ciphertext).hexString)]")
            
            // MAC ciphertext with MAC key
            guard let mac = HMAC(algorithm: .sha256, key: macKey).update(ciphertext)?.final()
            else {
                logger.error("Couldn't compute HMAC")
                throw Matrix.Error("Couldn't compute HMAC")
            }
            logger.debug("Got mac [0x\(Data(mac).hexString)]")
            
            // Now validate the new MAC vs the old MAC
            let oldMac = [UInt8](oldMacData)
            // First quick check - Are they the same length?
            guard mac.count == oldMac.count
            else {
                logger.warning("MAC lengths are not the same")
                return false
            }
            
            // Compare the MACs -- Constant time comparison
            var macIsValid = true
            for i in oldMac.indices {
                if mac[i] != oldMac[i] {
                    macIsValid = false
                }
            }
            
            guard macIsValid
            else {
                let old = Data(oldMac).hexString
                let new = Data(mac).hexString
                logger.warning("MAC doesn't match - 0x\(old) vs 0x\(new))")
                return false
            }
            
            // If we're still here, then everything must have matched.  We're good!
            return true
        }
    }
}
