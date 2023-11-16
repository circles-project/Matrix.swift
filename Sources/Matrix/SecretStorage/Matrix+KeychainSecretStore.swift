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

public protocol KeyStoreProtocol {
    init(userId: UserId)
    func loadKey(keyId: String, reason: String) async throws -> Data?
    func saveKey(key: Data, keyId: String) async throws
    func deleteKey(keyId: String, reason: String) async throws
}

extension Matrix {
    
    public typealias LocalKeyStore = KeychainAccessKeyStore
    
    public class InsecureKeyStore: KeyStoreProtocol {
        let userId: UserId
        private var logger: os.Logger

        public required init(userId: UserId) {
            self.userId = userId
            self.logger = .init(subsystem: "matrix", category: "insecure-keychain")
        }
        
        public func loadKey(keyId: String, reason: String) async throws -> Data? {
            logger.warning("WARNING TOTALLY INSECURE FAKE KEYCHAIN - FIXME")
            return UserDefaults.standard.data(forKey: "org.futo.ssss.key.\(keyId)")
        }
        
        public func saveKey(key: Data, keyId: String) async throws {
            logger.warning("WARNING TOTALLY INSECURE FAKE KEYCHAIN - FIXME")
            UserDefaults.standard.set(key, forKey: "org.futo.ssss.key.\(keyId)")
        }
        
        public func deleteKey(keyId: String, reason: String) async throws {
            UserDefaults.standard.removeObject(forKey: "org.futo.ssss.key.\(keyId)")
        }
    }
    
    public class KeychainAccessKeyStore: KeyStoreProtocol {
        let userId: UserId
        private var keychain: Keychain
        private var logger: os.Logger

        public required init(userId: UserId) {
            self.userId = userId
            self.keychain = Keychain(service: userId.stringValue)
            self.logger = .init(subsystem: "matrix", category: "keychainaccess")
        }
        
        public func loadKey(keyId: String, reason: String) async throws -> Data? {
            // https://github.com/kishikawakatsumi/KeychainAccess#closed_lock_with_key-obtaining-a-touch-id-face-id-protected-item
            // Ensure this runs on a background thread - Otherwise if we try to authenticate to the keychain from the main thread, the app will lock up
            let t = Task(priority: .background) {
                var context = LAContext()
                context.touchIDAuthenticationAllowableReuseDuration = 60.0
                guard let data = try? keychain
                    .accessibility(.whenUnlockedThisDeviceOnly, authenticationPolicy: .userPresence)
                    //.accessibility(.whenPasscodeSetThisDeviceOnly, authenticationPolicy: [.biometryAny])
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
            if let result = try? await t.value {
                return result
            }
            
            // Backwards compatibility - If previous versions of the app have stored keys in UserDefaults, try to move them into the real Keychain
            let insecure = InsecureKeyStore(userId: userId)
            if let key = try? await insecure.loadKey(keyId: keyId, reason: reason) {
                try await saveKey(key: key, keyId: keyId)
                try await insecure.deleteKey(keyId: keyId, reason: "Moved to KeychainAccess key store")
                return key
            }
            
            // Apparently we just don't have this one
            return nil
        }
        
        public func saveKey(key: Data, keyId: String) async throws {
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
        
        public func deleteKey(keyId: String, reason: String) async throws {
            do {
                try keychain.remove(keyId)
            } catch let error {
                logger.error("Failed to delete key \(keyId): \(error, privacy: .public)")
            }
        }
    }
    
}
