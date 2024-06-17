//
//  Matrix+Threepid.swift
//  
//
//  Created by Charles Wright on 6/17/24.
//

import Foundation

extension Matrix {
    public struct Threepid: Codable {
        var addedAt: UInt
        var address: String
        var medium: String
        var validatedAt: UInt
    }
}
