//
//  File.swift
//  
//
//  Created by Charles Wright on 5/3/23.
//

import Foundation
import MatrixSDKCrypto
import os

import CryptoKit
import IDZSwiftCommonCrypto

extension Matrix {
    // https://spec.matrix.org/v1.6/client-server-api/#storage
    public class SecretStore {
        
        // https://spec.matrix.org/v1.6/client-server-api/#secret-storage
        public struct EncryptedData: Codable {
            public var iv: String
            public var ciphertext: String
            public var mac: String
        }

        public struct Secret: Codable {
            public var encrypted: [String: EncryptedData]
        }
        
        private var session: Session
        private var logger: os.Logger
        var keys: [String: Data]
    
        public init(session: Session, keys: [String: Data]) {
            self.session = session
            self.logger = Matrix.logger
            self.keys = keys
        }
        
        func encrypt(name: String,
                     data: Data,
                     key: Data
        ) throws -> EncryptedData {
            // Keygen - Use HKDF to derive encryption key and MAC key from master key
            let salt = Array<UInt8>(repeating: 0, count: 32)
                        
            let hac: HashedAuthenticationCode = HKDF<CryptoKit.SHA256>.extract(inputKeyMaterial: SymmetricKey(data: key), salt: salt)
            let keyMaterial = HKDF<CryptoKit.SHA256>.expand(pseudoRandomKey: hac, info: name.data(using: .utf8), outputByteCount: 64)
            
            let (encryptionKey, macKey) = keyMaterial.withUnsafeBytes { bytes in
                let kE = Array(bytes[0..<32])
                let kM = Array(bytes[33..<64])
                return (kE, kM)
            }
            
            // Generate random IV
            let iv = try Random.generateBytes(byteCount: 16)
            
            // Encrypt data with encryption key and IV to create ciphertext
            let cryptor = Cryptor(operation: .encrypt,
                                  algorithm: .aes,
                                  mode: .CTR,
                                  padding: .NoPadding,
                                  key: encryptionKey,
                                  iv: iv
            )
            
            guard let ciphertext = cryptor.update(data)?.final()
            else {
                logger.error("Failed to encrypt")
                throw Matrix.Error("Failed to encrypt")
            }
            
            // MAC ciphertext with MAC key
            guard let mac = HMAC(algorithm: .sha256, key: macKey).update(ciphertext)?.final()
            else {
                logger.error("Couldn't compute HMAC")
                throw Matrix.Error("Couldn't compute HMAC")
            }
            
            return EncryptedData(iv: Data(iv).base64EncodedString(),
                                 ciphertext: Data(ciphertext).base64EncodedString(),
                                 mac: Data(mac).base64EncodedString()
            )
        }
        
        func decrypt(name: String,
                     encrypted: EncryptedData,
                     key: Data
        ) throws -> Data {
            
            guard let iv = Data(base64Encoded: encrypted.iv),
                  let ciphertext = Data(base64Encoded: encrypted.ciphertext),
                  let mac = Data(base64Encoded: encrypted.mac)
            else {
                throw Matrix.Error("Couldn't parse encrypted data")
            }
            
            // Keygen
            let salt = Array<UInt8>(repeating: 0, count: 32)
                        
            let hac: HashedAuthenticationCode = HKDF<CryptoKit.SHA256>.extract(inputKeyMaterial: SymmetricKey(data: key), salt: salt)
            let keyMaterial = HKDF<CryptoKit.SHA256>.expand(pseudoRandomKey: hac, info: name.data(using: .utf8), outputByteCount: 64)
            
            
            let (encryptionKey, macKey) = keyMaterial.withUnsafeBytes { bytes in
                let kE = Array(bytes[0..<32])
                let kM = Array(bytes[33..<64])
                return (kE, kM)
            }
            
            // Cryptographic Doom Principle: Always check the MAC first!
            let storedMAC = [UInt8](mac)  // convert from Data
            guard let computedMAC = HMAC(algorithm: .sha256, key: macKey).update(ciphertext)?.final()
            else {
                logger.error("Couldn't compute HMAC")
                throw Matrix.Error("Couldn't compute HMAC")
            }
            
            guard storedMAC.count == computedMAC.count
            else {
                logger.error("MAC doesn't match (\(storedMAC.count) bytes vs \(computedMAC.count) bytes)")
                throw Matrix.Error("MAC doesn't match")
            }
            
            var macIsValid = true
            // Compare the MACs -- Constant time comparison
            for i in storedMAC.indices {
                if storedMAC[i] != computedMAC[i] {
                    macIsValid = false
                }
            }
            
            guard macIsValid
            else {
                let stored = Data(storedMAC).base64EncodedString()
                let computed = Data(computedMAC).base64EncodedString()
                logger.error("MAC doesn't match (\(stored) vs \(computed)")
                throw Matrix.Error("MAC doesn't match")
            }
            
            // Whew now we finally know it's safe to decrypt
            
            let cryptor = Cryptor(operation: .decrypt,
                                  algorithm: .aes,
                                  mode: .CTR,
                                  padding: .NoPadding,
                                  key: encryptionKey,
                                  iv: [UInt8](iv)
            )
            
            guard let decryptedBytes = cryptor.update(ciphertext)?.final()
            else {
                logger.error("Failed to decrypt ciphertext")
                throw Matrix.Error("Failed to decrypt ciphertext")
            }
            
            return Data(decryptedBytes)
        }
            
        public func getSecret(type: String) async throws -> Codable? {
            
            logger.debug("Attempting to get secret for type [\(type)]")
            guard let secret = try await session.getAccountData(for: type, of: Secret.self)
            else {
                // Couldn't download the account data ==> Don't have this secret
                logger.debug("Could not download account data for type [\(type)]")
                return nil
            }

            // Make sure that we know how to decode this one, before we get into all the mess of wrangling keys etc
            guard let Type = Matrix.accountDataTypes[type]
            else {
                logger.error("Don't know how to parse Account Data type \(type)")
                throw Matrix.Error("Don't know how to parse Account Data of type \(type)")
            }

            // Now we have the encrypted secret downloaded
            // Look at all of the encryptions, and see if there's one where we know the key -- or where we can get the key
            for (keyId, encryptedData) in secret.encrypted {
                guard let key = self.keys[keyId]
                else {
                    logger.warning("Couldn't get key for id \(keyId)")
                    continue
                }
                logger.debug("Got key and description for key id [\(keyId)]")
                
                let data = try decrypt(name: type, encrypted: encryptedData, key: key)
                logger.debug("Successfully decrypted data for secret [\(type)]")
                
                let decoder = JSONDecoder()
                if let object = try? decoder.decode(Type.self, from: data) {
                    logger.debug("Successfully decoded object of type [\(type)]")
                    return object
                }
            }
            logger.warning("Couldn't find a key to decrypt secret [\(type)]")
            return nil
        }
        
        public func saveSecret(_ secret: Codable, type: String) async throws {
            throw Matrix.Error("Not implemented")
        }
        
        public func getKeyDescription(keyId: String) async throws -> KeyDescriptionContent? {
            try await session.getAccountData(for: "m.secret_storage.key.\(keyId)", of: KeyDescriptionContent.self)
        }

        
    }
}
