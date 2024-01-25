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

import LocalAuthentication

extension Matrix {

    // https://spec.matrix.org/v1.6/client-server-api/#storage
    public class SecretStore {
        
        public enum State {
            case uninitialized
            case needKey(String, KeyDescriptionContent)
            case online(String)
            case error(String)
        }
        
        // https://spec.matrix.org/v1.6/client-server-api/#secret-storage
        public struct EncryptedData: Codable {
            public var iv: String
            public var ciphertext: String
            public var mac: String
            
            public enum CodingKeys: CodingKey {
                case iv
                case ciphertext
                case mac
            }
            
            public init(iv: String, ciphertext: String, mac: String) {
                self.iv = iv
                self.ciphertext = ciphertext
                self.mac = mac
            }
            
            public init(from decoder: Decoder) throws {
                let container: KeyedDecodingContainer<Matrix.SecretStore.EncryptedData.CodingKeys> = try decoder.container(keyedBy: Matrix.SecretStore.EncryptedData.CodingKeys.self)
                
                let unpaddedIV = try container.decode(String.self, forKey: Matrix.SecretStore.EncryptedData.CodingKeys.iv)
                let unpaddedCiphertext = try container.decode(String.self, forKey: Matrix.SecretStore.EncryptedData.CodingKeys.ciphertext)
                let unpaddedMac = try container.decode(String.self, forKey: Matrix.SecretStore.EncryptedData.CodingKeys.mac)
                
                self.iv = Base64.ensurePadding(unpaddedIV)!
                self.ciphertext = Base64.ensurePadding(unpaddedCiphertext)!
                self.mac = Base64.ensurePadding(unpaddedMac)!
            }

            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: Matrix.SecretStore.EncryptedData.CodingKeys.self)
                
                guard let unpaddedIV = Base64.removePadding(self.iv),
                      let unpaddedCiphertext = Base64.removePadding(self.ciphertext),
                      let unpaddedMac = Base64.removePadding(self.mac)
                else {
                    Matrix.logger.error("Failed to remove base64 padding for encoding")
                    throw Matrix.Error("Failed to remove base64 padding for encoding")
                }
                
                try container.encode(unpaddedIV, forKey: Matrix.SecretStore.EncryptedData.CodingKeys.iv)
                try container.encode(unpaddedCiphertext, forKey: Matrix.SecretStore.EncryptedData.CodingKeys.ciphertext)
                try container.encode(unpaddedMac, forKey: Matrix.SecretStore.EncryptedData.CodingKeys.mac)
            }
        }

        public struct Secret: Codable {
            public var encrypted: [String: EncryptedData]
        }
        
        public var state: State
        private var session: Session
        private var logger: os.Logger
        private var keystore: KeyStoreProtocol
        var keys: [String: Data]
        
        // MARK: init
    
        public init(session: Session, ssk: SecretStorageKey) async throws {
            self.session = session
            self.logger = .init(subsystem: "matrix", category: "SSSS")
            self.keys = [ssk.keyId : ssk.key]
            self.keystore = Matrix.LocalKeyStore(userId: session.creds.userId)
            self.state = .uninitialized
            
            logger.debug("Initializing with default key")
            
            try await registerKey(key: ssk)
            
            // Make sure that our default key is registered with the server-side secret storage
            if let oldDefaultKeyId = try await getDefaultKeyId() {
                logger.debug("Found existing default keyId [\(oldDefaultKeyId)]")
                if oldDefaultKeyId != ssk.keyId {
                    
                    // Do we have this old key in our device keychain?
                    if let oldDefaultKey = try await keystore.loadKey(keyId: oldDefaultKeyId, reason: "Initializing secret storage") {
                        self.keys[oldDefaultKeyId] = oldDefaultKey
                        self.state = .online(oldDefaultKeyId)
                        // Save our new key under the old key
                        try await saveKey(key: ssk.key, keyId: ssk.keyId, under: [oldDefaultKeyId])
                        // Save the old key under our new key, in anticipation of switching sometime in the near future
                        try await saveKey(key: oldDefaultKey, keyId: oldDefaultKeyId, under: [ssk.keyId])
                        return
                    }
                    
                    // Do we have this old key in our secret storage, encrypted under our known key?
                    if let oldDefaultKey = try await getKey(keyId: oldDefaultKeyId) {
                        self.keys[oldDefaultKeyId] = oldDefaultKey
                        self.state = .online(oldDefaultKeyId)
                        // Save our new key under the old key
                        try await saveKey(key: ssk.key, keyId: ssk.keyId, under: [oldDefaultKeyId])
                        // Save the old key under our new key, in anticipation of switching sometime in the near future
                        try await saveKey(key: oldDefaultKey, keyId: oldDefaultKeyId, under: [ssk.keyId])
                        return
                    }
                    
                    guard let description = try await getKeyDescription(keyId: oldDefaultKeyId)
                    else {
                        logger.error("Couldn't get key description for old key id \(oldDefaultKeyId, privacy: .public)")
                        throw Matrix.Error("Couldn't get key descripiton for default key")
                    }
                    
                    // Check to see if our key is actually this one in disguise
                    let oldAndNewKeysMatch = try validateKeyVsDescription(key: ssk.key, keyId: ssk.keyId, description: description)
                    if oldAndNewKeysMatch {
                        logger.debug("Old and new keys match despite having different keyId's")
                        self.keys[oldDefaultKeyId] = ssk.key
                        self.state = .online(oldDefaultKeyId)
                        return
                    }
                    
                    // If we're still here, then we don't know where to get this key
                    // Maybe the user can help us?
                    logger.debug("We need a key to bring secret storage online: keyId \(oldDefaultKeyId, privacy: .public) algorithm \(description.algorithm, privacy: .public)")
                    self.state = .needKey(oldDefaultKeyId, description)
                    return
                     
                } else {
                    logger.debug("Existing default keyId matches what we have [\(ssk.keyId)]")
                    self.state = .online(ssk.keyId)
                }
            } else {
                logger.debug("No existing keyId; Setting our new one to be the default")
                
                try await setDefaultKeyId(keyId: ssk.keyId)
                self.state = .online(ssk.keyId)
            }
            
            self.registerAccountDataHandler()
            
            logger.debug("Done with init")
        }
        
        // MARK: init
        
        public init(session: Session, keys: [String: Data]) async throws {
            self.session = session
            self.logger = .init(subsystem: "matrix", category: "SSSS")
            self.keys = keys
            self.keystore = Matrix.LocalKeyStore(userId: session.creds.userId)
            self.state = .uninitialized
            
            logger.debug("Initializing with a set of \(keys.count) initial keys")
            
            // OK now let's see what we got
            // 1. Do we have the default key?
            //    a. Is it in the `keys` that we were init'ed with?
            //    b. Is it in our Keychain?
            //    c. Do we need to prompt the user for the passphrase?
            
            // First we need to connect to the server's account data and get the default key info
            // (If there is no default key, then we must remain in state `.uninitialized` and we are done here.)
            guard let serverDefaultKeyId = try await getDefaultKeyId()
            else {
                logger.warning("No default keyId for SSSS")
                self.registerAccountDataHandler()
                return
            }
            
            // Next, once we know the id of the default key, we look to see if we already have it in our `keys` dictionary
            // - If we have the default key, then we are in state `.online(keyId)` where `keyId` is the id of our default key
            if let key = keys[serverDefaultKeyId] {
                logger.debug("SSSS is online with existing key [\(serverDefaultKeyId)]")
                self.state = .online(serverDefaultKeyId)
            }
            else {
                logger.debug("Can't find the actual key for keyId [\(serverDefaultKeyId)]")
                
                logger.debug("Looking in Keychain for key with keyId \(serverDefaultKeyId)")
                // If the key isn't already loaded in memory, then maybe we have previously saved it in the Keychain
                // - If we have the default key, then we are in state `.online(keyId)` where `keyId` is the id of our default key
                if let key = try await keystore.loadKey(keyId: serverDefaultKeyId, reason: "The app needs to load cryptographic keys for your account") {
                    logger.debug("Found key \(serverDefaultKeyId) in the Keychain")
                    self.keys[serverDefaultKeyId] = key
                    self.state = .online(serverDefaultKeyId)
                } else {
                    logger.debug("Failed to load key \(serverDefaultKeyId) from the Keychain ")
                    
                    // If we don't have the default key, then there's not much that we can do.
                    logger.debug("Failed to load default SSSS key with keyId \(serverDefaultKeyId)")
                    // Set `state` to `.needKey` with the default key's description, so that the application can prompt the user
                    // to provide a passphrase.
                    logger.debug("Fetching key description")
                    if let description = try await getKeyDescription(keyId: serverDefaultKeyId) {
                        logger.debug("Setting state to .needKey")
                        self.state = .needKey(serverDefaultKeyId, description)
                    }
                }
            }
            
            self.registerAccountDataHandler()
            
            logger.debug("Done with init")
        }
        
        // MARK: Derived properties
        
        public var defaultKeyId: String? {
            switch self.state {
            case .online(let keyId):
                return keyId
            default:
                return nil
            }
        }
        
        // MARK: Account Data
        
        private func registerAccountDataHandler() {
            
            func filter(type: String) -> Bool {
                [M_SECRET_STORAGE_DEFAULT_KEY].contains(type) || type.starts(with: M_SECRET_STORAGE_KEY_PREFIX)
            }
            
            self.session.addAccountDataHandler(filter: filter,
                                               handler: self.handleAccountDataEvents)
        }
        
        public func handleAccountDataEvents(_ events: [AccountDataEvent]) async throws {
            
            // We need to be a bit smart about how we handle the events here
            // The events may arrive in any order.  But for us, order is very important.
            // We need to process all new keys before we try to set the new default key,
            // in case the new key is one that we're seeing for the first time in this batch.
            
            let newKeyEvents = events.filter { $0.type.starts(with: ORG_FUTO_SSSS_KEY_PREFIX) }
            let newDefaultkeyEvents = events.filter { $0.type == M_SECRET_STORAGE_DEFAULT_KEY }
            let otherEvents = events.filter { event in
                !event.type.starts(with: ORG_FUTO_SSSS_KEY_PREFIX) && !(event.type == M_SECRET_STORAGE_DEFAULT_KEY)
            }
            
            for event in newKeyEvents {
                try await handleAccountDataEvent(event)
            }
            
            for event in newDefaultkeyEvents {
                try await handleAccountDataEvent(event)

            }
            
            for event in otherEvents {
                try await handleAccountDataEvent(event)
            }
            
        }
        
        public func handleAccountDataEvent(_ event: AccountDataEvent) async throws {

            if event.type == M_SECRET_STORAGE_DEFAULT_KEY {
                
                // New default key
                guard let defaultKeyContent = event.content as? DefaultKeyContent
                else {
                    logger.error("Failed to parse default key content of type [\(event.type)]")
                    return
                }
                
                let newDefaultKeyId = defaultKeyContent.key
                // Ok now we know the id of the new default key
                // But unfortunately we probably don't have the key itself -- This came in over /sync.

                if case let .online(currentDefaultKeyId) = self.state,
                   currentDefaultKeyId == newDefaultKeyId
                {
                    logger.debug("Already using keyId \(newDefaultKeyId) as the default.  Doing nothing.")
                }
                else if let key = self.keys[newDefaultKeyId] {
                    logger.debug("Switching default key to \(newDefaultKeyId)")
                    self.state = .online(newDefaultKeyId)
                } else {
                    // Not sure what to do here...
                    // I guess we save the new default key id as "pending" and wait for the key itself to come in???
                    // FIXME: Not implemented
                    logger.error("FIXME: Not really handling new default key event yet")
                }
                
            } else if event.type.starts(with: M_SECRET_STORAGE_KEY_PREFIX) {
                
                // New key description, which might tell us how to reconstruct a key from a passphrase
                guard let keyDescriptionContent = event.content as? KeyDescriptionContent
                else {
                    logger.error("Failed to parse key descripiton content for [\(event.type)]")
                    return
                }
                // FIXME: Not implemented
                logger.error("FIXME: Not really handling new key description events yet")
                
            } else if event.type.starts(with: ORG_FUTO_SSSS_KEY_PREFIX) {
                // New encrypted secret storage key
                // Hopefully this one will be more useful than the key description
                guard let secret = event.content as? Secret
                else {
                    logger.error("Failed to parse encrypted secret for account data event type [\(event.type)]")
                    return
                }
                
                guard let decrypted = try? await decryptSecret(secret: secret, type: event.type)
                else {
                    logger.error("Failed to decrypt secret storage key \(event.type)")
                    return
                }
                
                // The key was base64 encoded before encryption
                let decoder = JSONDecoder()
                guard let base64key = try? decoder.decode(String.self, from: decrypted)
                else {
                    logger.error("Failed to extract base64-encoded key from decrypted event [\(event.type)]")
                    return
                }
                
                guard let key = Base64.data(base64key)
                else {
                    logger.error("Failed to base64 decode the key")
                    return
                }
                
                // Whew now we finally have the raw bytes of our new key
                // Construct its official Matrix key id
                let keyId = M_SECRET_STORAGE_KEY_PREFIX + "." + event.type.dropFirst(ORG_FUTO_SSSS_KEY_PREFIX.count + 1)
                // And add it to our collection of keys
                self.keys[keyId] = key
            }
        }
        
        // MARK: Encrypt
        
        static func encrypt(name: String,
                     data: Data,
                     key: Data
        ) throws -> EncryptedData {
            let logger = os.Logger(subsystem: "ssss", category: "encrypt")
            
            logger.debug("Encrypting \(name)")
            // Keygen - Use HKDF to derive encryption key and MAC key from master key
            let salt = Array<UInt8>(repeating: 0, count: 32)
                        
            let hac: HashedAuthenticationCode = HKDF<CryptoKit.SHA256>.extract(inputKeyMaterial: SymmetricKey(data: key), salt: salt)
            let keyMaterial = HKDF<CryptoKit.SHA256>.expand(pseudoRandomKey: hac, info: name.data(using: .utf8), outputByteCount: 64)
            
            let (encryptionKey, macKey) = keyMaterial.withUnsafeBytes { bytes in
                let kE = Array(bytes[0..<32])
                let kM = Array(bytes[32..<64])
                return (kE, kM)
            }
            //logger.debug("Encryption key = \(Data(encryptionKey).base64EncodedString())")
            //logger.debug("MAC key        = \(Data(macKey).base64EncodedString())")
            
            // Generate random IV
            // https://spec.matrix.org/v1.7/client-server-api/#msecret_storagev1aes-hmac-sha2
            // > Generate 16 random bytes, set bit 63 to 0 (in order to work around
            // > differences in AES-CTR implementations), and use this as the AES
            // > initialization vector. This becomes the iv property, encoded using base64.
            
            let iv = try [UInt8.random(in: UInt8(0)..<UInt8(128))] + Random.generateBytes(byteCount: 15)
            
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
            
            guard let b64iv = Base64.unpadded(iv),
                  let b64ciphertext = Base64.unpadded(ciphertext),
                  let b64mac = Base64.unpadded(mac)
            else {
                logger.error("Failed to convert to unpadded base64")
                throw Matrix.Error("Failed to convert to unpadded base64")
            }
            
            let encrypted = EncryptedData(iv: b64iv,
                                          ciphertext: b64ciphertext,
                                          mac: b64mac)
            
            /*
            // TEST: Can we decrypt what we just encrypted???
            if let decrypted = try? decrypt(name: name, encrypted: encrypted, key: key) {
                logger.debug("Test decryption succeeded")
                if decrypted == data {
                    logger.debug("Data decrypted successfully!")
                } else {
                    logger.error("Failed to decrypt correctly!")
                }
            } else {
                logger.error("Test decryption failed!")
            }
            */
            
            return encrypted
        }
        
        // MARK: Decrypt
        
        static func decrypt(name: String,
                     encrypted: EncryptedData,
                     key: Data
        ) throws -> Data {
            let logger = os.Logger(subsystem: "ssss", category: "decrypt")
            
            logger.debug("Decrypting \(name, privacy: .public)")
            
            guard let iv = Base64.data(encrypted.iv),
                  let ciphertext = Base64.data(encrypted.ciphertext),
                  let mac = Base64.data(encrypted.mac)
            else {
                logger.error("Couldn't parse encrypted data")
                throw Matrix.Error("Couldn't parse encrypted data")
            }
            
            // Keygen
            let salt = Array<UInt8>(repeating: 0, count: 32)
                        
            let hac: HashedAuthenticationCode = HKDF<CryptoKit.SHA256>.extract(inputKeyMaterial: SymmetricKey(data: key), salt: salt)
            let keyMaterial = HKDF<CryptoKit.SHA256>.expand(pseudoRandomKey: hac, info: name.data(using: .utf8), outputByteCount: 64)
            
            let (encryptionKey, macKey) = keyMaterial.withUnsafeBytes { bytes in
                let kE = Array(bytes[0..<32])
                let kM = Array(bytes[32..<64])
                return (kE, kM)
            }
            //logger.debug("Encryption key = \(Data(encryptionKey).base64EncodedString())")
            //logger.debug("MAC key        = \(Data(macKey).base64EncodedString())")
            
            // Cryptographic Doom Principle: Always check the MAC first!
            let storedMAC = [UInt8](mac)  // convert from Data
            guard let computedMAC = HMAC(algorithm: .sha256, key: macKey).update(ciphertext)?.final()
            else {
                logger.error("Couldn't compute HMAC")
                throw Matrix.Error("Couldn't compute HMAC")
            }
            
            guard storedMAC.count == computedMAC.count
            else {
                logger.error("MAC lengths don't match (\(storedMAC.count, privacy: .public) bytes vs \(computedMAC.count, privacy: .public) bytes)")
                throw Matrix.Error("MAC lengths don't match")
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
        
        // MARK: Decrypt secret
        
        private func decryptSecret(secret: Secret, type: String) async throws -> Data? {
            // Look at all of the encryptions, and see if there's one where we know the key -- or where we can get the key
            for (keyId, encryptedData) in secret.encrypted {
                logger.debug("Trying to decrypt secret \(type) with key \(keyId)")
                guard let key = try await self.getKey(keyId: keyId)
                else {
                    logger.warning("Couldn't get key for id \(keyId)")
                    continue
                }
                logger.debug("Got key and description for key id [\(keyId)]")
                
                let decryptedData = try SecretStore.decrypt(name: type, encrypted: encryptedData, key: key)
                logger.debug("Successfully decrypted data for secret [\(type)]")
                return decryptedData
            }
            logger.warning("Couldn't find a key to decrypt secret [\(type)]")
            return nil
        }
        

        
        // MARK: Get secret
        
        public func getSecretData(type: String) async throws -> Data? {
            logger.debug("Attempting to get secret data for type [\(type)]")
            
            guard let secret = try await session.getAccountData(for: type, of: Secret.self)
            else {
                // Couldn't download the account data ==> Don't have this secret
                logger.debug("Could not download account data for type [\(type)]")
                return nil
            }
            logger.debug("Downloaded enrypted secret \(type)")

            // Now we have the encrypted secret downloaded

            guard let data = try await decryptSecret(secret: secret, type: type)
            else {
                logger.error("Decryption failed for secret [\(type)]")
                throw Matrix.Error("Decryption failed for secret [\(type)]")
            }
            logger.debug("Decrypted secret \(type)")
            
            return data
        }
        
        public func getSecretString(type: String) async throws -> String? {
            let maybeData = try await getSecretData(type: type)
            
            guard let data = maybeData
            else {
                logger.error("No stored secret for type \(type)")
                return nil
            }
            
            // Ok this is messy and a bit complicated
            // We want to support any kind of String that has been stored in SSSS
            // * Maybe this is a String that we JSON encoded with double quotes, e.g. in an earlier version of Matrix.swift
            // * Maybe this is a String that we encoded as raw UTF-8, e.g. in Circles Android
            
            let decoder = JSONDecoder()
            if let jsonString = try? decoder.decode(String.self, from: data) {
                return jsonString
            }
            else {
                let rawString = String(data: data, encoding: .utf8)
                return rawString
            }
        }
            
        public func getSecretObject<T: Codable>(type: String) async throws -> T? {
            
            let maybeData = try await getSecretData(type: type)

            guard let data = maybeData
            else {
                logger.error("No stored secret for type \(type)")
                return nil
            }
            
            func hex(_ data: Data) -> String {
                let bytes = [UInt8](data)
                let string = bytes.map {
                    String($0, radix: 16)
                }.joined(separator: "")
                return string
            }
            
            logger.debug("Raw data = \(hex(data))")
                
            let decoder = JSONDecoder()
            guard let object = try? decoder.decode(T.self, from: data)
            else {
                logger.error("Failed to decode decrypted secret [\(type)]")
                throw Matrix.Error("Failed to decode decrypted secret [\(type)]")
            }
                    
            logger.debug("Successfully decoded object of type [\(T.self)]")
            return object
        }
        
        // MARK: Save secret
        
        public func saveSecretData(_ data: Data,
                                   type: String,
                                   under keyIds: [String]? = nil

        ) async throws {
            let encryptionKeyIds = keyIds ?? [defaultKeyId].compactMap { $0 }
            guard !encryptionKeyIds.isEmpty
            else {
                logger.error("Can't save secret without any encryption keys")
                throw Matrix.Error("Can't save secret without any encryption keys")
            }
            
            // Do we already have encrypted version(s) of this secret?
            // FIXME: Whooooooaaaaaa - Hold on a minute
            // We have NO WAY to know whether the old value is the same as the new one!
            // What should we do here?!?
            // ANSWER: For now we're assuming that secrets are never-changing,
            // so it's OK to keep the old encryptions around as long as they're for other keys
            // Any old encryptions under this current key will be overwritten.
            let existingSecret = try await session.getAccountData(for: type, of: Secret.self)
            var secret = existingSecret ?? Secret(encrypted: [:])

            for encryptionKeyId in encryptionKeyIds {
                guard let key = self.keys[encryptionKeyId]
                else {
                    logger.error("No key for keyId \(encryptionKeyId) -- Not encrypting to this key")
                    continue
                }
                // Encrypt the secret under this key
                let encryptedData = try SecretStore.encrypt(name: type, data: data, key: key)
                // Add our encryption to whatever was there before, overwriting any previous encryption to this key
                secret.encrypted[encryptionKeyId] = encryptedData
            }

            // Upload the updated secret to our Account Data
            try await session.putAccountData(secret, for: type)
        }
        
        public func saveSecretString(_ string: String,
                                     type: String,
                                     under keyIds: [String]? = nil
        ) async throws {
            logger.debug("Saving secret string of type [\(type)]")
            
            guard let data = string.data(using: .utf8)
            else {
                logger.error("Failed to convert string to UTF-8 data")
                throw Matrix.Error("Failed to conver string to UTF-8 data")
            }
            
            try await saveSecretData(data, type: type, under: keyIds)
        }
        
        public func saveSecretObject<T: Codable>(_ content: T,
                                                 type: String,
                                                 under keyIds: [String]? = nil
        ) async throws {
            logger.debug("Saving secret object of type [\(type)]")
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(content)
            
            try await saveSecretData(data, type: type, under: keyIds)
        }
        
        // MARK: Save key
        public func saveKey(key: Data,
                            keyId: String,
                            under keyIds: [String]? = nil
        ) async throws {
            guard let base64Key = Base64.unpadded(key)
            else {
                logger.error("Failed to convert key to base64")
                throw Matrix.Error("Failed to convert key to base64")
            }
            
            try await saveSecretString(base64Key, type: "\(ORG_FUTO_SSSS_KEY_PREFIX).\(keyId)", under: keyIds)
        }
        
        // MARK: Get key
        public func getKey(keyId: String) async throws -> Data? {
            logger.debug("Getting key for keyId \(keyId)")
            
            if let key = self.keys[keyId] {
                logger.debug("Key \(keyId) was already in our cache")
                return key
            }
            
            logger.debug("Looking for encrypted key \(keyId) in secret storage")
            if let base64Key: String = try await getSecretString(type: "\(ORG_FUTO_SSSS_KEY_PREFIX).\(keyId)") {
                let key = Base64.data(base64Key)
                return key
            }
            
            logger.error("Couldn't get key for keyId \(keyId)")
            return nil
        }
        
        // MARK: Generate key description
        public static func generateKeyDescription(key: Data,
                                                  keyId: String,
                                                  name: String? = nil,
                                                  algorithm: String = M_SECRET_STORAGE_V1_AES_HMAC_SHA2,
                                                  passphrase: KeyDescriptionContent.Passphrase?
        ) throws -> KeyDescriptionContent {
            let zeroes = [UInt8](repeating: 0, count: 32)
            let encrypted = try encrypt(name: "", data: Data(zeroes), key: key)
            let iv = encrypted.iv
            let mac = encrypted.mac
            
            return KeyDescriptionContent(name: name, algorithm: algorithm, passphrase: passphrase, iv: iv, mac: mac)
        }
        
        // MARK: Save key description
        public func saveKeyDescription(_ description: KeyDescriptionContent,
                                       for keyId: String
        ) async throws {
            try await session.putAccountData(description, for: keyId)
        }
        
        // MARK: Get key description
        
        public func getKeyDescription(keyId: String) async throws -> KeyDescriptionContent? {
            logger.debug("Fetching key description for keyId [\(keyId)]")
            return try await session.getAccountData(for: "\(M_SECRET_STORAGE_KEY_PREFIX).\(keyId)", of: KeyDescriptionContent.self)
        }

        // MARK: Add new key
        
        public func addNewDefaultKey(_ ssk: SecretStorageKey) async throws {
            logger.debug("Adding new default key with key id \(ssk.keyId)")
            try await addNewSecretStorageKey(ssk, makeDefault: true)
        }
        
        public func addNewSecretStorageKey(_ ssk: SecretStorageKey, makeDefault: Bool = false, sync: Bool = true) async throws {
            logger.debug("Adding new key with key id \(ssk.keyId)")
            // Super basic level: Add the new key to our keys
            self.keys[ssk.keyId] = ssk.key
            
            // Save it in our keychain so it will be there next time we launch the app
            try await self.keystore.saveKey(key: ssk.key, keyId: ssk.keyId, sync: sync)
            
            // Now we need to be sure to keep all our bookkeeping stuff in order
            switch state {
            case .online(let oldDefaultKeyId):
                guard let base64Key = Base64.unpadded(ssk.key)
                else {
                    logger.error("Failed to convert new key to base64")
                    throw Matrix.Error("Failed to convert new key to base64")
                }
                
                guard let oldDefaultKey = self.keys[oldDefaultKeyId]
                else {
                    logger.error("Failed to get old default key for key id \(oldDefaultKeyId)")
                    throw Matrix.Error("Failed to get old default key for key id \(oldDefaultKeyId)")
                }
                
                guard let oldBase64Key = Base64.unpadded(oldDefaultKey)
                else {
                    logger.error("Failed to convert old key to base64")
                    throw Matrix.Error("Failed to convert old key to base64")
                }
                
                // Save our new key, encrypted under the old key, so other clients can access it
                try await self.saveSecretString(base64Key, type: "\(ORG_FUTO_SSSS_KEY_PREFIX).\(ssk.keyId)")

                // Create the key description that allows us (and other clients) to verify that we have the correct bytes for the key
                try await self.registerKey(key: ssk)
                
                if makeDefault {
                    // Switch to the new key as our default
                    self.state = .online(ssk.keyId)
                    // Save the old key, encrypted under our new key, so we can recover old secrets in the future
                    try await self.saveSecretString(oldBase64Key, type: "\(ORG_FUTO_SSSS_KEY_PREFIX).\(oldDefaultKeyId)")
                    try await self.setDefaultKeyId(keyId: ssk.keyId)
                }
                
            case .needKey(let neededKeyId, let neededDescription):
                if ssk.keyId == neededKeyId {
                    // Yay this is what we've been waiting for
                    logger.debug("Got the key that we were waiting for?  Validating...")
                    guard try validateKeyVsDescription(key: ssk.key, keyId: ssk.keyId, description: neededDescription)
                    else {
                        logger.error("Failed to validate new key.  Still waiting.")
                        return
                    }
                    logger.debug("Successfully validated keyId \(ssk.keyId, privacy: .public)")
                    self.state = .online(ssk.keyId)
                }
                
            default:
                // If we were in some other state, good news!  Now we can be fully online.
                if makeDefault {
                    // Switch to the new key as our default
                    self.state = .online(ssk.keyId)
                    // Create the key description that allows us (and other clients) to verify that we have the correct bytes for the key
                    try await self.registerKey(key: ssk)
                    // Mark the new key as the default
                    try await self.setDefaultKeyId(keyId: ssk.keyId)
                }
            }
        }
        
        // MARK: Register key
        
        public func registerKey(key: SecretStorageKey) async throws {
            logger.debug("Registering new key with keyId [\(key.keyId)]")
                        
            let type = "\(M_SECRET_STORAGE_KEY_PREFIX).\(key.keyId)"
            
            try await session.putAccountData(key.description, for: type)
        }
        
        // MARK: Validate key
        
        public func validateKey(key: Data,
                                keyId: String
        ) async throws -> Bool {
            logger.debug("Validating key with keyId [\(keyId)]")
            
            guard let description = try await getKeyDescription(keyId: keyId)
            else {
                logger.error("Failed to get key description for keyId \(keyId, privacy: .public)")
                throw Matrix.Error("Failed to get key description")
            }
            
            return try validateKeyVsDescription(key: key, keyId: keyId, description: description)
        }
        
        public func validateKeyVsDescription(key: Data,
                                             keyId: String,
                                             description: KeyDescriptionContent
        ) throws -> Bool {
            guard let oldIVString = description.iv,
                  let oldMacString = description.mac,
                  let oldMacData = Base64.data(oldMacString),
                  let iv = Base64.data(oldIVString)
            else {
                logger.error("Failed to parse key description for keyId \(keyId, privacy: .public)")
                throw Matrix.Error("Failed to parse key description")
            }
            
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
            
            // MAC ciphertext with MAC key
            guard let mac = HMAC(algorithm: .sha256, key: macKey).update(ciphertext)?.final()
            else {
                logger.error("Couldn't compute HMAC")
                throw Matrix.Error("Couldn't compute HMAC")
            }
            
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
                let old = Data(oldMac).base64EncodedString()
                let new = Data(mac).base64EncodedString()
                logger.warning("MAC doesn't match - \(old) vs \(new)")
                return false
            }
            
            // If we're still here, then everything must have matched.  We're good!
            return true
        }

        
        // MARK: Set default keyId
        
        public func setDefaultKeyId(keyId: String) async throws {
            logger.debug("Setting keyId [\(keyId)] to be the default SSSS key")
            let content = DefaultKeyContent(key: keyId)
            let type = M_SECRET_STORAGE_DEFAULT_KEY
            
            try await session.putAccountData(content, for: type)
        }
        
        // MARK: Get default keyId
        
        public func getDefaultKeyId() async throws -> String? {
            logger.debug("Getting default keyId")
            guard let content = try await session.getAccountData(for: M_SECRET_STORAGE_DEFAULT_KEY, of: DefaultKeyContent.self)
            else {
                logger.error("Couldn't find a default keyId")
                return nil
            }

            logger.debug("Found default keyId \(content.key)`")
            return content.key
        }
        
        // MARK: Generate key
        
        public func generateKey(keyId: String, password: String, description: KeyDescriptionContent) throws -> SecretStorageKey? {
            guard let algorithm = description.passphrase?.algorithm,
                  let salt = description.passphrase?.salt
            else {
                logger.error("Can't generate secret storage key without algorithm and salt")
                return nil
            }
            
            let iterations = description.passphrase?.iterations ?? 100_000
            let bitLength = description.passphrase?.bits ?? 256

            
            switch algorithm {
            case M_PBKDF2:
                let rounds = UInt32(iterations)
                let byteLength: UInt = UInt(bitLength) / 8
                logger.debug("Generating PBKDF2 key  (rounds = \(rounds), length = \(byteLength)")

                let keyBytes = PBKDF.deriveKey(password: password, salt: salt, prf: .sha512, rounds: rounds, derivedKeyLength: byteLength)
                let keyData = Data(keyBytes)
                logger.debug("Generated key data = \(Base64.padded(keyData))")
                
                guard keyData.count == byteLength,
                      try validateKeyVsDescription(key: keyData, keyId: keyId, description: description)
                else {
                    logger.error("Password-generated key does not match description")
                    return nil
                }
                let key = SecretStorageKey(key: keyData, keyId: keyId, description: description)
                return key
                
            default:
                logger.error("Unknown key generation algorithm")
                return nil
            }
        }
    }
}
