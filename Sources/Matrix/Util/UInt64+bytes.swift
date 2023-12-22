//
//  UInt64+bytes.swift
//
//
//  Created by Charles Wright on 12/21/23.
//

import Foundation

extension UInt64 {
    var bytes: [UInt8] {
        return [
            UInt8( self            >> 56),
            UInt8((self % (1<<56)) >> 48),
            UInt8((self % (1<<48)) >> 40),
            UInt8((self % (1<<40)) >> 32),
            UInt8((self % (1<<32)) >> 24),
            UInt8((self % (1<<24)) >> 16),
            UInt8((self % (1<<16)) >>  8),
            UInt8( self % (1<<8)        ),
        ]
    }
}
