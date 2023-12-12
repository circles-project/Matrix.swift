//
//  DynamicCodingKeys.swift
//
//
//  Created by Michael Hollister on 11/30/23.
//

import Foundation

/// Helper struct that can create coding keys at runtime
public struct DynamicCodingKeys: CodingKey {
    public var stringValue: String
    public var intValue: Int?

    public init(stringValue: String) {
        self.stringValue = stringValue
    }

    public init(intValue: Int) {
        self.stringValue = "\(intValue)";
        self.intValue = intValue
    }
}
