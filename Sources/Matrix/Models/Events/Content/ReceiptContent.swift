//
//  ReceiptContent.swift
//  
//
//  Created by Michael Hollister on 12/30/22.
//

import Foundation
import AnyCodable

// Unfortunately this event content is not well-defined, so this implementation is primarily based
// from the example JSON content

// cvw: You can say that again.  This might be one of the least-readable portions of the spec.
//      Attempting a simplified version of this based on spec v1.7:

public typealias ReceiptContent = [EventId: EventReceiptInfo]

public struct EventReceiptInfo: Codable {
    public struct Timestamp: Codable {
        var ts: UInt
        var threadId: EventId?
        public enum CodingKeys: String, CodingKey {
            case ts
            case threadId = "thread_id"
        }
    }
    public var read: [UserId: Timestamp]?
    public var readPrivate: [UserId: Timestamp]?
    public var fullyRead: [UserId: Timestamp]?
    
    public enum CodingKeys: String, CodingKey {
        case read = "m.read"
        case readPrivate = "m.read.private"
        case fullyRead = "m.fully_read"
    }
}
