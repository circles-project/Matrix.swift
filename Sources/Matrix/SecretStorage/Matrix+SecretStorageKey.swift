//
//  Matrix+SecretStorageKey.swift
//  
//
//  Created by Charles Wright on 8/15/23.
//

import Foundation

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
    }
}
