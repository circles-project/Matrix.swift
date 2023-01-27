//
//  PushRulesContent.swift
//  
//
//  Created by Charles Wright on 12/8/22.
//

import Foundation
import AnyCodable

// https://spec.matrix.org/v1.5/client-server-api/#push-rules
// This is some of the messiest crap in the entire Matrix spec.
// And that is saying something.
public struct PushRulesContent: Codable {
    public struct PushRule: Codable {
        public var actions: [Action]
        public var conditions: [PushCondition]?
        public var isDefault: Bool
        public var isEnabled: Bool
        public var pattern: String?
        public var ruleId: String
        
        public enum CodingKeys: String, CodingKey {
            case actions
            case conditions
            case isDefault = "default"
            case isEnabled = "enabled"
            case pattern
            case ruleId = "rule_id"
        }
        
        public struct PushCondition: Codable {
            public var isA: String?
            public var key: String?
            public var kind: String
            public var pattern: String?
            
            public enum CodingKeys: String, CodingKey {
                case isA = "is"
                case key
                case kind
                case pattern
            }
        }
        
        public enum Action: Codable {
            case notify
            case dontNotify
            case coalesce
            case setSoundTweak(sound: String)
            case setHighlightTweak(highlight: Bool)
            case setGenericTweak(tweak:String, value:String)
            
            public init(from decoder: Decoder) throws {
                print("Decoding push rule action")
                                
                struct ActionDecodingError: Error {
                    var msg: String
                }

                if let string = try? String.init(from: decoder) {
                    switch string {
                    case "notify":
                        self = .notify
                        return
                    case "dont_notify":
                        self = .dontNotify
                        return
                    case "coalesce":
                        self = .coalesce
                        return
                    default:
                        print("Invalid string: [\(string)]")
                        throw ActionDecodingError(msg: "Invalid string")
                    }
                }

                enum TweakCodingKeys: String, CodingKey {
                    case setTweak = "set_tweak"
                    case value
                }
                
                let container = try decoder.container(keyedBy: TweakCodingKeys.self)

                let tweak = try container.decode(String.self, forKey: .setTweak)
                
                switch tweak {
                case "highlight":
                    let value = try container.decodeIfPresent(Bool.self, forKey: .value) ?? true
                    self = .setHighlightTweak(highlight: value)
                    return
                case "sound":
                    let value = try container.decode(String.self, forKey: .value)
                    self = .setSoundTweak(sound: value)
                    return
                default:
                    let value = try container.decode(String.self, forKey: .value)
                    self = .setGenericTweak(tweak: tweak, value: value)
                }

                
                print("Invalid action: Doesn't match either type (string or set_tweak)")
                throw ActionDecodingError(msg: "Doesn't match either type of action (string or set_tweak)")
            }
        }
    }
    public struct RuleSet: Codable {
        public var content: [PushRule]?
        public var override: [PushRule]?
        public var room: [PushRule]?
        public var sender: [PushRule]?
        public var underride: [PushRule]?
    }
    public var global: RuleSet?
}
