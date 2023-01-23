//
//  UnsignedData.swift
//  
//
//  Created by Michael Hollister on 1/23/23.
//

import Foundation

public struct UnsignedData: Codable {
    public let age: Int
    // public let prevContent: Codable // Ugh how are we supposed to decode this???
    // public let redactedBecause: ClientEvent? // Ugh wtf Matrix?  We can't have a recursive structure here...
    public struct FakeClientEvent: Codable {
        public var eventId: String
    }
    public let redactedBecause: FakeClientEvent?
    public let transactionId: String?
}
