//
//  EncryptionAlgorithm.swift
//  
//
//  Created by Charles Wright on 3/3/23.
//

import Foundation

public enum EncryptionAlgorithm: String, Codable {
    case olmV1 = "m.olm.v1.curve25519-aes-sha2"
    case megolmV1 = "m.megolm.v1.aes-sha2"
}
