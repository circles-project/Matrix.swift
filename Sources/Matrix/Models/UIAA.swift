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
    
    public struct Params: CustomStringConvertible {
        private var items: [String: Any]
        
        public subscript(index: String) -> Any? {
            get {
                return items[index]
            }
            set(newValue) {
                items[index] = newValue
            }
        }
        
        public var description: String {
            items.description
        }
    }
    
    public struct SessionState: Codable {
        public var errcode: String?
        public var error: String?
        public var flows: [Flow]
        public var params: Params?
        public var completed: [String]?
        public var session: String

        public func hasCompleted(stage: String) -> Bool {
            guard let completed = completed else {
                return false
            }
            return completed.contains(stage)
        }
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

public struct TermsParams: Codable {
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


public struct AppleSubscriptionParams: Codable {
    public var productIds: [String]
}

public struct PasswordEnrollParams: Codable {
    public var minimumLength: Int
}

public struct EmailLoginParams: Codable {
    public var addresses: [String]
}

public struct BSSpekeOprfParams: Codable {
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

public struct BSSpekeEnrollParams: Codable {

    public var blindSalt: String
    
    public enum CodingKeys: String, CodingKey {
        case blindSalt = "blind_salt"
    }
}

public struct BSSpekeVerifyParams: Codable {
    public var B: String  // Server's ephemeral public key
    public var blindSalt: String
    
    public enum CodingKeys: String, CodingKey {
        case B
        case blindSalt = "blind_salt"
    }
}


extension UIAA.Params: Codable {
    
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case mLoginTerms = "m.login.terms"
        case mLoginPassword = "m.login.password"
        case mLoginDummy = "m.login.dummy"
        case mEnrollPassword = "m.enroll.password"
        case mEnrollEmailRequestToken = "m.enroll.email.request_token"
        case mEnrollEmailSubmitToken = "m.enroll.email.submit_token"
        case mLoginEmailRequestToken = "m.login.email.request_token"
        case mLoginEmailSubmitToken = "m.login.email.submit_token"
        case mEnrollBSSpekeOprf = "m.enroll.bsspeke-ecc.oprf"
        case mEnrollBSSpekeSave = "m.enroll.bsspeke-ecc.save"
        case mLoginBSSpekeOprf = "m.login.bsspeke-ecc.oprf"
        case mLoginBSSpekeVerify = "m.login.bsspeke-ecc.verify"
        case mLoginSubscriptionApple = "org.futo.subscription.apple"
    }

    
    public init(from decoder: Decoder) throws {
        print("Trying to decode some UIA params...")
        
        self.items = .init()
        
        // Approach:
        // - Define a whole bunch of coding keys, based on the known auth types
        // - Get a container from the decoder
        // - Attempt to decode each element in the container, using its coding key to determine its type
        // - After we decode each thing, stick it in the internal dictionary keyed by its coding key (ie its auth type)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        for key in CodingKeys.allCases {
            if container.contains(key) {
                print("\t\(key.stringValue)\tYes")
            } else {
                print("\t\(key.stringValue)\tNo")
            }
        }
        
        // This is painful but it works.
        // Why can't our CodingKeys be CaseIterable when they have associated values?  This could be so much cleaner...
        
        print("Trying to decode Apple params")
        if let appleParams = try container.decodeIfPresent(AppleSubscriptionParams.self, forKey: .mLoginSubscriptionApple) {
            print("Decoded params for Apple subscriptions")
            self.items[CodingKeys.mLoginSubscriptionApple.rawValue] = appleParams
        }
        
        print("Trying to decode terms params")
        if let termsParams = try container.decodeIfPresent(TermsParams.self, forKey: .mLoginTerms) {
            print("Decoded params for terms")
            self.items[CodingKeys.mLoginTerms.rawValue] = termsParams
        }
        
        print("Trying to decode password params")
        if let passwordParams = try container.decodeIfPresent(PasswordEnrollParams.self, forKey: .mEnrollPassword) {
            print("Decoded params for password")
            self.items[CodingKeys.mEnrollPassword.rawValue] = passwordParams
        }
        
        print("Trying to decode email params")
        if let emailParams = try? container.decode(EmailLoginParams.self, forKey: .mLoginEmailRequestToken) {
            print("Decoded params for email request token")
            self.items[CodingKeys.mLoginEmailRequestToken.rawValue] = emailParams
        }
        
        print("Trying to decode bsspeke enroll oprf params")
        if let bsspekeParams = try container.decodeIfPresent(BSSpekeOprfParams.self, forKey: .mEnrollBSSpekeOprf) {
            print("Decoded params for bsspeke enroll oprf")
            self.items[CodingKeys.mEnrollBSSpekeOprf.rawValue] = bsspekeParams
        }
        
        print("Trying to decode bsspeke login oprf params")
        if let bsspekeParams = try container.decodeIfPresent(BSSpekeOprfParams.self, forKey: .mLoginBSSpekeOprf) {
            print("Decoded params for bsspeke login oprf")
            self.items[CodingKeys.mLoginBSSpekeOprf.rawValue] = bsspekeParams
        }
        
        print("Trying to decode bsspeke enroll save params")
        if let bsspekeParams = try container.decodeIfPresent(BSSpekeEnrollParams.self, forKey: .mEnrollBSSpekeSave) {
            print("Decoded params for bsspeke save")
            self.items[CodingKeys.mEnrollBSSpekeSave.rawValue] = bsspekeParams
        }
        
        print("Trying to decode bsspeke login verify params")
        if let bsspekeParams = try container.decodeIfPresent(BSSpekeVerifyParams.self, forKey: .mLoginBSSpekeVerify) {
            print("Decoded params for bsspeke verify")
            self.items[CodingKeys.mLoginBSSpekeVerify.rawValue] = bsspekeParams
        }
        
        print("That's all folks")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Now we need to look at what all we've got
        // * Try to pull each possible thing out of the dictionary, and if we find it, cast it to its real type
        // * Encode it into the container
        // This function is going to wind up essentially mirroring the `decode()` function above
        // - For each `if let foo` up there, we'll have the exact same `if let foo` down here
        
        if let appleParams = items[CodingKeys.mLoginSubscriptionApple.rawValue] as? AppleSubscriptionParams {
            try container.encode(appleParams, forKey: .mLoginSubscriptionApple)
        }
        
        if let termsParams = items[CodingKeys.mLoginTerms.rawValue] as? TermsParams {
            try container.encode(termsParams, forKey: .mLoginTerms)
        }
        
        if let passwordParams = items[CodingKeys.mEnrollPassword.rawValue] as? PasswordEnrollParams {
            try container.encode(passwordParams, forKey: .mEnrollPassword)
        }
        
        if let emailParams = items[CodingKeys.mLoginEmailRequestToken.rawValue] as? EmailLoginParams {
            try container.encode(emailParams, forKey: .mLoginEmailRequestToken)
        }
        
        if let bsspekeParams = items[CodingKeys.mEnrollBSSpekeOprf.rawValue] as? BSSpekeOprfParams {
            try container.encode(bsspekeParams, forKey: .mEnrollBSSpekeOprf)
        }
        
        if let bsspekeParams = items[CodingKeys.mLoginBSSpekeOprf.rawValue] as? BSSpekeOprfParams {
            try container.encode(bsspekeParams, forKey: .mLoginBSSpekeOprf)
        }
        
        if let bsspekeParams = items[CodingKeys.mEnrollBSSpekeSave.rawValue] as? BSSpekeEnrollParams {
            try container.encode(bsspekeParams, forKey: .mEnrollBSSpekeSave)
        }
        
        if let bsspekeParams = items[CodingKeys.mLoginBSSpekeVerify.rawValue] as? BSSpekeVerifyParams {
            try container.encode(bsspekeParams, forKey: .mLoginBSSpekeVerify)
        }
    }
}
