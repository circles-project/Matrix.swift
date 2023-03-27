//  Copyright 2020, 2021 Kombucha Digital Privacy Systems LLC
//  Copyright 2022 FUTO Holdings, Inc.
//
//  UIAA.swift
//  Matrix.swift
//
//  Created by Charles Wright on 4/26/21.
//

import Foundation
import AnyCodable

public enum UIAA {
    
    public struct Flow: Codable {
        public var stages: [String]
        
        public func isSatisfiedBy(completed: [String]) -> Bool {
            completed.starts(with: stages)
        }

        public mutating func pop(stage: String) {
            if stages.starts(with: [stage]) {
                stages = Array(stages.dropFirst())
            }
        }
    }
    
    
    public struct SessionState: Decodable {
        public var errcode: String?
        public var error: String?
        public var flows: [Flow]
        public var params: [StageId: UiaStageParams]?
        public var completed: [String]?
        public var session: String
        
        enum CodingKeys: String, CodingKey {
            case errcode
            case error
            case flows
            case params
            case completed
            case session
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.errcode = try container.decodeIfPresent(String.self, forKey: .errcode)
            self.error = try container.decodeIfPresent(String.self, forKey: .error)
            self.flows = try container.decode([Flow].self, forKey: .flows)
            self.params = try container.decode([StageId:UiaStageParams].self, forKey: .params) // This relies on our extension to KeyedDecodingContainer, below.
            self.completed = try container.decodeIfPresent([String].self, forKey: .completed)
            self.session = try container.decode(String.self, forKey: .session)
        }
        
        /*
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(errcode, forKey: .errcode)
            try container.encodeIfPresent(error, forKey: .error)
            try container.encode(flows, forKey: .flows)
            try container.encodeIfPresent(params, forKey: .params)
            try container.encodeIfPresent(completed, forKey: .completed)
            try container.encode(session, forKey: .session)
        }
        */

        public func hasCompleted(stage: String) -> Bool {
            guard let completed = completed else {
                return false
            }
            return completed.contains(stage)
        }
    }
    
    // This is an ugly hack to facilitate decoding UIA parameters from the HTTP response.
    // By defining our own type here, we can write our own custom implementation that tells
    // Swift's KeyedDecodingContainer how to handle dictionaries from UIA stages to the
    // parameters for those stages.
    public struct StageId: LosslessStringConvertible, Hashable, CodingKey, Codable {
        var string: String
        
        public init?(_ description: String) {
            self.string = description
        }
        
        public var stringValue: String {
            string
        }
        
        public init?(stringValue: String) {
            self.string = stringValue
        }
        
        public var intValue: Int? {
            nil
        }
        
        public init?(intValue: Int) {
            return nil
        }
        
        public init(from decoder: Decoder) throws {
            self.string = try .init(from: decoder)
        }
        
        public enum CodingKeys: CodingKey {
            case string
        }
        
        public func encode(to encoder: Encoder) throws {
            try self.string.encode(to: encoder)
        }
    }
    
    private(set) public static var parameterTypes: [String: UiaStageParams.Type] = [
        AUTH_TYPE_TERMS : TermsParams.self,
        AUTH_TYPE_APPLE_SUBSCRIPTION : AppleSubscriptionParams.self,
        AUTH_TYPE_ENROLL_PASSWORD : PasswordEnrollParams.self,
        AUTH_TYPE_LOGIN_EMAIL_REQUEST_TOKEN : EmailLoginParams.self,
        AUTH_TYPE_ENROLL_BSSPEKE_OPRF : BSSpekeOprfParams.self,
        AUTH_TYPE_LOGIN_BSSPEKE_OPRF : BSSpekeOprfParams.self,
        AUTH_TYPE_ENROLL_BSSPEKE_SAVE : BSSpekeEnrollParams.self,
        AUTH_TYPE_LOGIN_BSSPEKE_VERIFY : BSSpekeVerifyParams.self,
    ]
    
    public static func registerParameterType(type: UiaStageParams.Type, for name: String) {
        parameterTypes[name] = type
    }
}

extension UIAA.Flow: Identifiable {
    public var id: String {
        stages.joined(separator: " ")
    }
}

extension UIAA.Flow: Equatable {
    public static func != (lhs: UIAA.Flow, rhs: UIAA.Flow) -> Bool {
        if lhs.stages.count != rhs.stages.count {
            return true
        }
        for (l,r) in zip(lhs.stages, rhs.stages) {
            if l != r {
                return true
            }
        }
        return false
    }
}

extension UIAA.Flow: Hashable {
    public func hash(into hasher: inout Hasher) {
        for stage in stages {
            hasher.combine(stage)
        }
    }
}

public protocol UiaStageParams: Codable { }

public struct TermsParams: UiaStageParams {
    public struct Policy: Codable {
        public struct LocalizedPolicy: Codable {
            public var name: String
            public var url: URL
        }
        
        public var name: String
        public var version: String
        // FIXME this is the awfulest f**king kludge I think I've ever written
        // But the Matrix JSON struct here is pretty insane
        // Rather than make a proper dictionary, they throw the version in the
        // same object with the other keys of what should be a natural dict.
        // Parsing this properly is going to be something of a shitshow.
        // But for now, we do it the quick & dirty way...
        public var en: LocalizedPolicy?
        // UPDATE (2022-04-22)
        // - The trick to making this work is to realize: There is no spoon.  m.login.terms is not in the Matrix spec. :)
        // - Therefore we don't need to slavishly stick to this messy design.
        // - We can really do whatever we want here.
        // - Really the basic structure from Matrix is pretty good.  It just needs a little tweak.
        //var localizations: [String: LocalizedPolicy]
    }
    
    public var policies: [Policy]
}


public struct AppleSubscriptionParams: UiaStageParams {
    public var productIds: [String]
}

public struct PasswordEnrollParams: UiaStageParams {
    public var minimumLength: Int
}

public struct EmailLoginParams: UiaStageParams {
    public var addresses: [String]
}

public struct BSSpekeOprfParams: UiaStageParams {
    public var curve: String
    public var hashFunction: String

    public struct PHFParams: Codable {
        public var name: String
        public var iterations: UInt
        public var blocks: UInt
    }
    public var phfParams: PHFParams

    public enum CodingKeys: String, CodingKey {
        case curve
        case hashFunction = "hash_function"
        case phfParams = "phf_params"
    }
}

public struct BSSpekeEnrollParams: UiaStageParams {

    public var blindSalt: String
    
    public enum CodingKeys: String, CodingKey {
        case blindSalt = "blind_salt"
    }
}

public struct BSSpekeVerifyParams: UiaStageParams {
    public var B: String  // Server's ephemeral public key
    public var blindSalt: String
    
    public enum CodingKeys: String, CodingKey {
        case B
        case blindSalt = "blind_salt"
    }
}


extension KeyedDecodingContainer {
    func decode(_ type: Dictionary<UIAA.StageId,UiaStageParams>.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> Dictionary<UIAA.StageId,UiaStageParams> {
        let subContainer: KeyedDecodingContainer<UIAA.StageId> = try self.nestedContainer(keyedBy: UIAA.StageId.self, forKey: key)
        var decodedDict = [UIAA.StageId:UiaStageParams]()
        for k in subContainer.allKeys {
            guard let T = UIAA.parameterTypes[k.stringValue] else { continue }
            decodedDict[k] = try subContainer.decode(T.self, forKey: k)
        }
        return decodedDict
    }
    
    func decodeIfPresent(_ type: Dictionary<UIAA.StageId,UiaStageParams>.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> Dictionary<UIAA.StageId,UiaStageParams>? {
        if self.contains(key) {
            return try self.decode([UIAA.StageId: UiaStageParams].self, forKey: key)
        } else {
            return nil
        }
    }
}

/*
extension KeyedEncodingContainer {
    
    func encode(_ value: Dictionary<UIAA.StageId,UiaStageParams>, forKey key: KeyedEncodingContainer<K>.Key) throws {
        var subContainer: KeyedEncodingContainer<UIAA.StageId> = try self.nestedContainer(keyedBy: UIAA.StageId.self, forKey: key)
        for (stageId, params) in value {
            try subContainer.encode(params, forKey: stageId)
        }
    }
    
    func encodeIfPresent(_ value: Dictionary<UIAA.StageId,UiaStageParams>?, forKey key: KeyedDecodingContainer<K>.Key) throws {
        if let value = value {
            try encode(value, forKey: key)
        }
    }
}
*/
