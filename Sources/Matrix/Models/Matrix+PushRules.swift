//
//  Matrix+PushRules.swift
//
//
//  Created by Charles Wright on 3/21/24.
//

import Foundation

extension Matrix {
    public enum PushRules {
        
        public enum Action: Codable, Equatable {
            case notify
            case dontNotify
            case coalesce
            case setSoundTweak(sound: String)
            case setHighlightTweak(highlight: Bool)
            case setGenericTweak(tweak:String, value:String)
            
            enum TweakCodingKeys: String, CodingKey {
                case setTweak = "set_tweak"
                case value
            }
            
            public init(from decoder: Decoder) throws {
                //Matrix.logger.debug("Decoding push rule action")
                                
                struct ActionDecodingError: Swift.Error {
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
                        Matrix.logger.error("Invalid string: [\(string)]")
                        throw ActionDecodingError(msg: "Invalid string")
                    }
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

                Matrix.logger.error("Invalid action: Doesn't match either type (string or set_tweak)")
                throw ActionDecodingError(msg: "Doesn't match either type of action (string or set_tweak)")
            }
            
            public func encode(to encoder: Encoder) throws {
                switch self {
                case .notify:
                    try "notify".encode(to: encoder)
                case .dontNotify:
                    try "dont_notify".encode(to: encoder)
                case .coalesce:
                    try "coalesce".encode(to: encoder)
                case .setSoundTweak(let sound):
                    var container = encoder.container(keyedBy: TweakCodingKeys.self)
                    try container.encode("sound", forKey: .setTweak)
                    try container.encode(sound, forKey: .value)
                case .setHighlightTweak(let highlight):
                    var container = encoder.container(keyedBy: TweakCodingKeys.self)
                    try container.encode("highlight", forKey: .setTweak)
                    try container.encode(highlight, forKey: .value)
                case .setGenericTweak(let tweak, let value):
                    var container = encoder.container(keyedBy: TweakCodingKeys.self)
                    try container.encode(tweak, forKey: .setTweak)
                    try container.encode(value, forKey: .value)
                }
            }
        }
        

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
                public var kind: Kind
                public var pattern: String?
                
                public enum CodingKeys: String, CodingKey {
                    case isA = "is"
                    case key
                    case kind
                    case pattern
                }
            }
        }
        
        public enum Kind: String, Codable, Equatable {
            case override
            case underride
            case sender
            case room
            case content
        }
    }
}
