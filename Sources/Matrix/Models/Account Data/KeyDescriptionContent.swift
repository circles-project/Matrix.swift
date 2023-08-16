//
//  KeyDescriptionContent.swift
//  
//
//  Created by Charles Wright on 5/3/23.
//

import Foundation

// https://spec.matrix.org/v1.6/client-server-api/#key-storage
public struct KeyDescriptionContent: Codable {
    public var name: String?
    public var algorithm: String
    public var passphrase: Passphrase?
    public var iv: String?
    public var mac: String?
    
    public struct Passphrase: Codable {
        public var algorithm: String
        public var salt: String
        public var iterations: Int
        public var bits: Int?
    }
    
    public init(name: String? = nil, algorithm: String, passphrase: Passphrase? = nil, iv: String? = nil, mac: String? = nil) {
        self.name = name
        self.algorithm = algorithm
        self.passphrase = passphrase
        self.iv = iv
        self.mac = mac
    }

}

