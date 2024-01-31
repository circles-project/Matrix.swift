//
//  KeyDescriptionContent.swift
//  
//
//  Created by Charles Wright on 5/3/23.
//

import Foundation

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
        
    }
}
