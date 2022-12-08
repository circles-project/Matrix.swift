//
//  PushRulesContent.swift
//  
//
//  Created by Charles Wright on 12/8/22.
//

import Foundation
import AnyCodable

// https://spec.matrix.org/v1.5/client-server-api/#push-rules
struct PushRulesContent: Codable {
    struct PushRule: Codable {
        var actions: [Action]
        var conditions: [PushCondition]?
        var isDefault: Bool
        var isEnabled: Bool
        var pattern: String?
        var ruleId: String
        
        enum CodingKeys: String, CodingKey {
            case actions
            case conditions
            case isDefault = "default"
            case isEnabled = "enabled"
            case pattern
            case ruleId = "rule_id"
        }
        
        struct PushCondition: Codable {
            var isA: String?
            var key: String?
            var kind: String
            var pattern: String?
            
            enum CodingKeys: String, CodingKey {
                case isA = "is"
                case key
                case kind
                case pattern
            }
        }
        
        enum Action: Codable {
            case notify
            case dontNotify
            case coalesce
            case setTweak(key:String, value:String)
        }
    }
    struct RuleSet: Codable {
        var content: [PushRule]?
        var override: [PushRule]?
        var room: [PushRule]?
        var sender: [PushRule]?
        var underride: [PushRule]?
    }
    var global: RuleSet
}
