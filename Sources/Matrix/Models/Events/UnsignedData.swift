//
//  UnsignedData.swift
//
//
//  Created by Michael Hollister on 1/23/23.
//

import Foundation

public struct UnsignedData: Codable {
    public let age: Int?
    // public let prevContent: Codable // Ugh how are we supposed to decode this???

    public let redactedBecause: ClientEvent?
    public let transactionId: String?
    
    public var description: String {
        return """
               UnsignedData: {age: \(age), \
               redactedBecause: \(String(describing: redactedBecause)), \
               transactionId: \(String(describing: transactionId))}
               """
    }
    
    public enum CodingKeys: String, CodingKey {
        case age
        case redactedBecause = "redacted_because"
        case transactionId = "transaction_id"
    }
    
    public init(age: Int? = nil, redactedBecause: ClientEvent? = nil, transactionId: String? = nil) {
        self.age = age
        self.redactedBecause = redactedBecause
        self.transactionId = transactionId
    }
}
