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

/// m.receipt: https://spec.matrix.org/v1.5/client-server-api/#mreceipt
public struct ReceiptContent: Codable {
    public struct UserTimestamp: Codable, Equatable {
        public let ts: Int
    }
    
    public typealias ReceiptTypeContent = [String: [String: Int]]
        
    public enum ReceiptType: Codable, Equatable {
        case read([UserId: UserTimestamp]) // "m.read"
        case readPrivate([UserId: UserTimestamp]) // "m.read.private"
        case fullyRead([UserId: UserTimestamp]) // "m.fully_read"
        
        public static func == (lhs: ReceiptContent.ReceiptType, rhs: ReceiptContent.ReceiptType) -> Bool {
            switch (lhs, rhs) {
            case (.read(_), .read(_)):
                return true
            case (.readPrivate(_), .readPrivate(_)):
                return true
            case (.fullyRead(_), .fullyRead(_)):
                return true
            default:
                return false
            }
        }
        
        public static func === (lhs: ReceiptContent.ReceiptType, rhs: ReceiptContent.ReceiptType) -> Bool {
            switch (lhs, rhs) {
            case (let .read(lhsUsers), let .read(rhsUsers)):
                return lhsUsers == rhsUsers
            case (let .readPrivate(lhsUsers), let .readPrivate(rhsUsers)):
                return lhsUsers == rhsUsers
            case (let .fullyRead(lhsUsers), let .fullyRead(rhsUsers)):
                return lhsUsers == rhsUsers
            default:
                return false
            }
        }
        
        public init?(receiptType: String, receiptContent: ReceiptTypeContent) throws {
            var userDict: [UserId: UserTimestamp] = [:]
            for (k2, v2) in receiptContent {
                if let userId = UserId(k2), let timestamp = v2["ts"] {
                    userDict[userId] = UserTimestamp(ts: timestamp)
                }
            }
            
            switch receiptType {
            case "m.read":
                self = .read(userDict)
                return
            case "m.read.private":
                self = .readPrivate(userDict)
                return
            case "m.fully_read":
                self = .fullyRead(userDict)
                return
            default:
                let msg = "Failed to decode ReceiptType from string [\(receiptType)]"
                print(msg)
                throw Matrix.Error(msg)
            }
        }
    }
    
    public let events: [EventId: [ReceiptType]]
    
    public init(_ eventsDict: [EventId: [ReceiptType]]) {
        self.events = eventsDict
    }
}

extension KeyedDecodingContainer {
    public func decode(_ type: ReceiptContent.Type, forKey key: K) throws -> ReceiptContent? {
        guard self.contains(key) else {
            return nil
        }
        
        var receiptContentEvents: [EventId: [ReceiptContent.ReceiptType]] = [:]
        let receiptContentJSON = try self.decode([EventId: AnyCodable].self, forKey: key)
        
        for (k, v) in receiptContentJSON {
            if let receiptTypeArray = v.value as? [String: [String: [String: Int]]] {
                for (receiptTypeStr, usersDict) in receiptTypeArray {
                    if let receiptContent = try ReceiptContent.ReceiptType(receiptType: receiptTypeStr, receiptContent: usersDict) {
                        if receiptContentEvents[k] == nil {
                            receiptContentEvents[k] = [receiptContent]
                        }
                        else {
                            receiptContentEvents[k]?.append(receiptContent)
                        }
                    }
                }
            }
        }
        
        return ReceiptContent(receiptContentEvents)
    }
}
