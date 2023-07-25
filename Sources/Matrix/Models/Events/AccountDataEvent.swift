//
//  AccountDataEvent.swift
//  
//
//  Created by Charles Wright on 7/11/23.
//

import Foundation

extension Matrix {
    public struct AccountDataEvent: Codable {
        public var type: String
        public var content: Codable
        
        public enum CodingKeys: String, CodingKey {
            case type
            case content
        }
        
        public init(type: String, content: Codable) {
            self.type = type
            self.content = content
        }
        
        public init(from decoder: Decoder) throws {
            logger.debug("Decoding account data event")
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let type = try container.decode(String.self, forKey: .type)
            self.type = type
            logger.debug("\tAccount data event type = \(type)")
            self.content = try Matrix.decodeAccountData(of: self.type, from: decoder)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(content, forKey: .content)
        }
    }
}
