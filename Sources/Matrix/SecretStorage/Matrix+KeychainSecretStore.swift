//
//  Matrix+KeychainSecretStore.swift
//  
//
//  Created by Charles Wright on 8/15/23.
//

import Foundation
import os
import LocalAuthentication
import KeychainAccess

extension Matrix {
    public class KeychainSecretStore {
        let userId: UserId
        private var keychain: Keychain
        private var logger: os.Logger
        
        public init(userId: UserId) {
            self.userId = userId
            self.keychain = Keychain(service: "matrix", accessGroup: userId.stringValue)
            self.logger = .init(subsystem: "matrix", category: "keychain")
        }
        
        private func loadKey_KeychainAccess(keyId: String, reason: String) async throws -> Data? {
            // https://github.com/kishikawakatsumi/KeychainAccess#closed_lock_with_key-obtaining-a-touch-id-face-id-protected-item
            // Ensure this runs on a background thread - Otherwise if we try to authenticate to the keychain from the main thread, the app will lock up
            let t = Task(priority: .background) {
                var context = LAContext()
                context.touchIDAuthenticationAllowableReuseDuration = 60.0
                guard let data = try? keychain
                    //.accessibility(.whenUnlockedThisDeviceOnly, authenticationPolicy: .userPresence)
                    .accessibility(.whenPasscodeSetThisDeviceOnly, authenticationPolicy: [.biometryAny])
                    .authenticationContext(context)
                    .authenticationPrompt(reason)
                    .getData(keyId)
                else {
                    self.logger.debug("Failed to get key data from keychain")
                    throw Matrix.Error("Failed to get key data from keychain")
                }
                self.logger.debug("Got \(data.count) bytes of data from the keychain")
                return data
            }
            return try await t.value
        }
        
        private func loadKey_FakeKeychain(keyId: String, reason: String) async throws -> Data? {
            logger.warning("WARNING TOTALLY INSECURE FAKE KEYCHAIN - FIXME")
            return UserDefaults.standard.data(forKey: "org.futo.ssss.key.\(keyId)")
        }
        
        // Use the Apple Keychain APIs directly, with no KeychainAccess
        private func loadKey_RawKeychain(keyId: String, reason: String) async throws -> Data? {
            // https://developer.apple.com/documentation/security/keychain_services/keychain_items/searching_for_keychain_items
            let tag = "org.futo.ssss.key.\(keyId)".data(using: .utf8)! // From the Apple article on saving keys to keychain
            let query: [String: Any] = [kSecClass as String: kSecClassKey,
                                        kSecAttrApplicationTag as String: tag,
                                        kSecAttrAccount as String: userId.stringValue,
                                        kSecMatchLimit as String: kSecMatchLimitOne,
                                        kSecReturnAttributes as String: true,
                                        kSecReturnData as String: true]
            
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            guard status != errSecItemNotFound else { throw Matrix.Error("Key \(keyId) not found for user \(userId)") }
            guard status == errSecSuccess else { throw Matrix.Error("Failed to load key \(keyId) for user \(userId): Status = \(status.description)") }
            
            guard let existingItem = item as? [String : Any],
                  let keyData = existingItem[kSecValueData as String] as? Data
                //let account = existingItem[kSecAttrAccount as String] as? String
            else {
                throw Matrix.Error("Failed to parse keychain data for key \(keyId) for user \(userId)")
            }
            logger.debug("Loaded \(keyData.count) bytes for key \(keyId) from keychain")
            return keyData
        }
        
        public func loadKey(keyId: String, reason: String) async throws -> Data? {
            // https://developer.apple.com/documentation/security/keychain_services/keychain_items/searching_for_keychain_items

            logger.debug("Attempting to load key with keyId \(keyId)")
            //return try await loadKey_KeychainAccess(keyId: keyId, reason: reason)
            //return try await loadKey_RawKeychain(keyId: keyId, reason: reason)
            return try await loadKey_FakeKeychain(keyId: keyId, reason: reason)
        }
        
        public func saveKey_KeychainAccess(key: Data, keyId: String) async throws {
            // https://github.com/kishikawakatsumi/KeychainAccess#closed_lock_with_key-updating-a-touch-id-face-id-protected-item
            // Ensure this runs on a background thread - Otherwise if we try to authenticate to the keychain from the main thread, the app will lock up
            let t = Task(priority: .background) {
                var context = LAContext()
                context.touchIDAuthenticationAllowableReuseDuration = 60.0
                self.logger.debug("Got context.  Attempting to save keyId \(keyId)")
                try keychain
                    .accessibility(.whenUnlockedThisDeviceOnly, authenticationPolicy: .userPresence)
                    .authenticationContext(context)
                    .set(key, key: keyId)
                self.logger.debug("Success saving keyId \(keyId)")
            }
            try await t.value
        }
        
        public func saveKey_FakeKeychain(key: Data, keyId: String) async throws {
            logger.warning("WARNING TOTALLY INSECURE FAKE KEYCHAIN - FIXME")
            UserDefaults.standard.set(key, forKey: "org.futo.ssss.key.\(keyId)")
        }
        
        public func saveKey_RawKeychain(key: Data, keyId: String) async throws {
            // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/storing_keys_in_the_keychain
            logger.debug("Saving key with the raw Keychain API")
            
            let tag = "org.futo.ssss.key.\(keyId)".data(using: .utf8)!
            let addquery: [String: Any] = [kSecClass as String: kSecClassKey,
                                           kSecAttrApplicationTag as String: tag,
                                           kSecAttrAccount as String: userId.stringValue, // From the Apple article on loading passwords from the keychain
                                           kSecValueRef as String: key]
            logger.debug("Created addQuery dictionary with \(addquery.count) entries")
            let status = SecItemAdd(addquery as CFDictionary, nil)
            logger.debug("Added key \(keyId) to the keychain")
            guard status == errSecSuccess
            else {
                logger.debug("Failed to save key \(keyId) to the keychain -- status = \(status.description)")
                throw Matrix.Error("Failed to save key \(keyId) for user \(userId)")
            }
            logger.debug("Saved key \(keyId) in the keychain")
        }
        
        public func saveKey(key: Data, keyId: String) async throws {
            logger.debug("Attempting to save key with keyId \(keyId)")

            //try await saveKey_KeychainAccess(key: key, keyId: keyId)
            //try await saveKey_RawKeychain(key: key, keyId: keyId)
            try await saveKey_FakeKeychain(key: key, keyId: keyId)
        }
    }
}
