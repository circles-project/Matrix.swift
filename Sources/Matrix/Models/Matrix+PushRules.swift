//
//  Matrix+PushRules.swift
//
//
//  Created by Charles Wright on 3/21/24.
//

import Foundation
import os

extension Matrix {
    public enum PushRules {
        
        private(set) public static var logger: os.Logger?
        
        public static func setLogger(_ logger: os.Logger?) {
            self.logger = logger
        }
        
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
                PushRules.logger?.debug("Decoding push rule action")
                                
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
                public var value: Value?

                public enum Value: Codable {
                    case boolean(Bool)
                    case integer(Int)
                    case string(String)

                    public init(from decoder: Decoder) throws {
                        PushRules.logger?.debug("Decoding PushCondition.Value")
                        if let bool = try? Bool(from: decoder) {
                            self = .boolean(bool)
                            return
                        } else if let int = try? Int(from: decoder) {
                            self = .integer(int)
                            return
                        } else if let string = try? String(from: decoder) {
                            self = .string(string)
                            return
                        } else {
                            Matrix.logger.error("Failed to decode PushRule PushCondition value")
                            throw Matrix.Error("Failed to decode PushRule PushCondition value")
                        }
                    }

                    public enum CodingKeys: CodingKey {
                        case boolean
                        case integer
                        case string
                    }

                    public func encode(to encoder: Encoder) throws {
                        switch self {
                        case .boolean(let bool):
                            try bool.encode(to: encoder)
                        case .integer(let int):
                            try int.encode(to: encoder)
                        case .string(let string):
                            try string.encode(to: encoder)
                        }
                    }
                }
                
                public enum CodingKeys: String, CodingKey {
                    case isA = "is"
                    case key
                    case kind
                    case pattern
                    case value
                }
                
                public init(from decoder: Decoder) throws {
                    PushRules.logger?.debug("Decoding PushRule")
                    let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

                    PushRules.logger?.debug("Decoding PushRule.isA")
                    self.isA = try container.decodeIfPresent(String.self, forKey: .isA)

                    PushRules.logger?.debug("Decoding PushRule.key")
                    self.key = try container.decodeIfPresent(String.self, forKey: .key)

                    PushRules.logger?.debug("Decoding PushRule.kind")
                    self.kind = try container.decode(Matrix.PushRules.Kind.self, forKey: .kind)

                    PushRules.logger?.debug("Decoding PushRule.pattern")
                    self.pattern = try container.decodeIfPresent(String.self, forKey: .pattern)

                    PushRules.logger?.debug("Decoding PushRule.value")
                    self.value = try container.decodeIfPresent(Matrix.PushRules.PushRule.PushCondition.Value.self, forKey: .value)
                    
                    PushRules.logger?.debug("Done decoding PushRule")
                }
            }
        }
        
        // https://spec.matrix.org/v1.10/client-server-api/#conditions-1
        public enum Kind: String, Codable, Equatable {
            case eventMatch = "event_match"
            case eventPropertyIs = "event_property_is"
            case eventPropertyContains = "event_property_contains"
            case containsDisplayName = "contains_display_name"
            case roomMemberCount = "room_member_count"
            case senderNotificationPermission = "sender_notification_permission"
        }
    }
}
