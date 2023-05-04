//
//  File.swift
//  
//
//  Created by Charles Wright on 5/3/23.
//

import Foundation
import MatrixSDKCrypto

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
        
        var session: Session
        var keys: [String: String]
    
        public init(session: Session, key: String) {
            self.session = session
            self.keys = [
                "default" : key,
            ]
        }
            
        public func getSecret(type: String) async throws -> Codable? {
            throw Matrix.Error("Not implemented")
        }
        
        public func saveSecret(_ secret: Codable, type: String) async throws {
            
        }
        
        public func getKeyDescription(keyId: String) async throws -> KeyDescriptionContent {
            try await session.getAccountData(for: "m.secret_storage.key.\(keyId)", of: KeyDescriptionContent.self)
        }

        
    }
}
