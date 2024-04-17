//
//  AccountDataEvent.swift
//
//
//  Created by Charles Wright on 7/11/23.
//

import Foundation
import os

extension Matrix {
    public struct AccountDataEvent: Codable {
        
        private(set) public static var logger: os.Logger?
        
        public static func setLogger(_ logger: os.Logger?) {
            Self.logger = logger
        }
        
        public static func enableLogging() {
            Self.logger = os.Logger(subsystem: "Matrix", category: "AccountDataEvent")
        }
        
        public static func disableLogging() {
            Self.logger = nil
        }
        
        public var type: String
        public var content: Codable
        
        public var description: String {
            return "AccountDataEvent: {type: \(type), content:\(content)}"
        }
        
        public enum CodingKeys: String, CodingKey {
            case type
            case content
        }
        
        public init(type: String, content: Codable) {
            self.type = type
            self.content = content
        }
        
        public init(from decoder: Decoder) throws {
            Self.logger?.debug("Decoding account data event")
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let type = try container.decode(String.self, forKey: .type)
            self.type = type
            Self.logger?.debug("\tAccount data event type = \(type)")
            self.content = try Matrix.decodeAccountData(of: self.type, from: decoder)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(content, forKey: .content)
        }
    }
}
