//
//  UserId.swift
//
//
//  Created by Charles Wright on 5/19/22.
//

import Foundation
    
public struct UserId: LosslessStringConvertible, Codable, Identifiable, Equatable, Hashable, CodingKey {
    
    public let username: String
    public let domain: String
    public let port: UInt16?
    
    // https://spec.matrix.org/v1.8/appendices/#user-identifiers
    static let usernameRegex = try! Regex("^@[a-zA-Z0-9\\._=\\-/\\+]+$")  // Note the leading "@"
    // https://spec.matrix.org/v1.8/appendices/#server-name
    // FIXME: This is only a crude approxmation that doesn't actually check for valid IPv4 / IPv6 addresses
    static let domainRegex = try! Regex("^[a-zA-Z0-9\\-\\.]+$")
    
    public static func validate(_ userId: String) -> Bool {
        let toks = userId.split(separator: ":")
        // First we validate the user part
        guard let userPart = toks.first,
              let _ = try? usernameRegex.wholeMatch(in: userPart),
              userPart.count < 256
        else {
            return false
        }
        guard toks.count < 4,
              toks.count > 1
        else {
            return false
        }
        // Now we need to figure out if we have a port number in our homeserver
        // And if we do, it needs to be all-numeric
        if toks.count == 3 {
            guard let port = toks.last,
                  port.allSatisfy({ c in
                      c.isNumber
                  }),
                  let num = Int(port),
                  num < 65535
            else {
                return false
            }
        }
        // Does it look like we have a valid hostname?
        let hostPart = toks[1]
        guard let _ = try? domainRegex.wholeMatch(in: hostPart),
              hostPart.count < 256
        else {
            return false
        }
        return true
    }
    
    public static func autoCorrect(_ string: String, domain: String? = nil) -> UserId? {
        
        let lower = string.lowercased()
        
        // If we already have a valid UserId, let's just stick with that
        if let userId = UserId(lower) {
            return userId
        }

        // Case 1 - User just forgot the leading "@"
        //        - And it's clear that they did not enter an email address
        if !lower.contains("@") {
            
            if lower.contains(":") {
                // Looks like they tried their best to give us a localpart and a domainpart
                // Let's see if just prefixing the "@" will be sufficient
                return UserId("@\(lower)")
            } else {
                // Looks like they gave us one string with no ":" separator
                // The best that we can hope is that this is their username
                if let domain = domain {
                    // If we have a default domain, we'll try that one
                    return UserId("@\(lower):\(domain)")
                } else {
                    // Otherwise they're out of luck
                    return nil
                }
            }
            
        }
        // Case 2 - User transposed their Matrix UserId into an email address
        else if lower.contains("@") && !lower.starts(with: "@") {
            let toks = lower.split(separator: "@")
            guard toks.count == 2,
                  let userpart = toks.first,
                  let domainAndPort = toks.last,
                  !userpart.contains(":")
            else {
                return nil
            }
            return UserId("@\(userpart):\(domainAndPort)")
        }
        // Case 3 - User input their user part but without a domain
        else if lower.starts(with: "@") && !lower.contains(":") {
            if let domain = domain {
                return UserId("\(lower):\(domain)")
            } else {
                return nil
            }
        }
        else {
            // If we didn't match any of the cases above, then we don't know what to do with this one
            return nil
        }
    }
    
    public init?(username: String, domain: String, port: UInt16? = nil) {
        
        guard let _ = try? UserId.usernameRegex.wholeMatch(in: username)
        else {
            Matrix.logger.error("Bad username for UserId: \(username)")
            return nil
        }

        guard let _ = try? UserId.domainRegex.wholeMatch(in: domain)
        else {
            Matrix.logger.error("Bad domain for UserId: \(domain)")
            return nil
        }
        
        if username.starts(with: "@") {
            self.username = username.lowercased()
        } else {
            self.username = "@" + username.lowercased()
        }
        self.domain = domain.lowercased()
        self.port = port
    }
    
    // for LosslessStringConvertible
    public init?(_ stringValue: String) {
        self.init(stringValue: stringValue)
    }
    
    // for CodingKey
    public init?(stringValue: String) {
        guard UserId.validate(stringValue) else {
            //let msg = "Invalid user id"
            //throw Matrix.Error(msg)
            return nil
        }
        let toks = stringValue.split(separator: ":")

        self.username = String(toks[0]).lowercased()
        self.domain = String(toks[1]).lowercased()
        if toks.count > 2 {
            self.port = UInt16(toks[2])
        } else {
            self.port = nil
        }
    }
    
    public init(from decoder: Decoder) throws {
        //print("Decoding UserId")
        guard let stringUserId = try? String(from: decoder)
        else {
            let msg = "UserId: Failed to decode String version"
            print(msg)
            throw Matrix.Error(msg)
        }
        //print("\tGot string user id [\(stringUserId)]")
        guard let me: UserId = .init(stringUserId)
        else {
            let msg = "Invalid user id: \(stringUserId)"
            print("\tUserId: \(msg)")
            throw Matrix.Error(msg)
        }
        //print("UserId: Decoding success!")
        self = me
    }
    
    public func encode(to encoder: Encoder) throws {
        try self.description.encode(to: encoder)
    }

    public var description: String {
        if let port = self.port {
            return "\(username):\(domain):\(port)"
        } else {
            return "\(username):\(domain)"
        }
            
    }
    
    public var id: String {
        description
    }
    
    public static func == (lhs: UserId, rhs: UserId) -> Bool {
        lhs.username == rhs.username && lhs.domain == rhs.domain && lhs.port == rhs.port
    }

    public func hash(into hasher: inout Hasher) {
        self.description.hash(into: &hasher)
    }
    
    public var stringValue: String {
        description
    }
    
    public var intValue: Int? {
        nil
    }
    
    public init?(intValue: Int) {
        nil
    }
}

extension UserId: Comparable {
    public static func < (lhs: UserId, rhs: UserId) -> Bool {
        lhs.stringValue < rhs.stringValue
    }
}

extension KeyedDecodingContainer {
        
    func decodeIfPresent<T:Decodable>(_ type: Dictionary<UserId,T>.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> Dictionary<UserId,T>? {
        if self.contains(key) {
            return try self.decode([UserId: T].self, forKey: key)
        } else {
            return nil
        }
    }
    
    func decode<T:Decodable>(_ type: Dictionary<UserId,T>.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> Dictionary<UserId,T> {
        let subContainer: KeyedDecodingContainer<UserId> = try self.nestedContainer(keyedBy: UserId.self, forKey: key)
        var decodedDict = [UserId:T]()
        for k in subContainer.allKeys {
            decodedDict[k] = try subContainer.decode(T.self, forKey: k)
        }
        return decodedDict
    }
}

extension KeyedEncodingContainer {
    mutating func encode<T:Encodable>(_ dict: Dictionary<UserId,T>, forKey key: KeyedEncodingContainer<K>.Key) throws {
        var subContainer: KeyedEncodingContainer<UserId> = self.nestedContainer(keyedBy: UserId.self, forKey: key)
        for (k,v) in dict {
            try subContainer.encode(v, forKey: k)
        }
    }
    
    mutating func encodeIfPresent<T:Encodable>(_ dict: Dictionary<UserId,T>?, forKey key: KeyedEncodingContainer<K>.Key) throws {
        if let d = dict {
            try self.encode(d, forKey: key)
        }
    }
}
