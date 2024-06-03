//
//  PushRulesContent.swift
//  
//
//  Created by Charles Wright on 12/8/22.
//

import Foundation
import AnyCodable

// https://spec.matrix.org/v1.10/client-server-api/#push-rules
// This is some of the messiest crap in the entire Matrix spec.
// And that is saying something.
public struct PushRulesContent: Codable {

    public typealias PushRule = Matrix.PushRules.PushRule
    
    public struct RuleSet: Codable {
        public var content: [PushRule]?
        public var override: [PushRule]?
        public var room: [PushRule]?
        public var sender: [PushRule]?
        public var underride: [PushRule]?
    }
    public var global: RuleSet?
}
