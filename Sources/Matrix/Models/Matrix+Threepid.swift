//
//  Matrix+Threepid.swift
//  
//
//  Created by Charles Wright on 6/17/24.
//

import Foundation

extension Matrix {
    public struct Threepid: Codable {
        public var addedAt: UInt
        public var address: String
        public var medium: String
        public var validatedAt: UInt
    }
}
