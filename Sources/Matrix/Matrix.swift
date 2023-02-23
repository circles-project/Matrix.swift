//
//  Matrix.swift
//  Circles
//
//  Created by Charles Wright on 6/14/22.
//

import Foundation
#if !os(macOS)
import UIKit
#else
import AppKit
#endif
import AnyCodable

import MatrixSDKCrypto

@available(macOS 12.0, *)
public enum Matrix {
    
    // MARK: Error Types
    
    public struct Error: LocalizedError {
        public var msg: String
        public var errorDescription: String?
        
        public init(_ msg: String) {
            self.msg = msg
            self.errorDescription = NSLocalizedString(msg, comment: msg)
        }
    }
    
    public struct RateLimitError: Swift.Error, Codable {
        public var errcode: String
        public var error: String?
        public var retryAfterMs: Int?
    }

    // MARK: Utility Functions
    
    // MARK: Well-Known
    
    public struct WellKnown: Codable {
        public struct ServerConfig: Codable {
            public var baseUrl: String
            
            public enum CodingKeys: String, CodingKey {
                case baseUrl = "base_url"
            }
        }
        public var homeserver: ServerConfig
        public var identityserver: ServerConfig?

        public enum CodingKeys: String, CodingKey {
            case homeserver = "m.homeserver"
            case identityserver = "m.identity_server"
        }
        
        public init(homeserver: String, identityServer: String? = nil) {
            self.homeserver = ServerConfig(baseUrl: homeserver)
                 if let identity = identityServer {
                     self.identityserver = ServerConfig(baseUrl: identity)
             }
        }
    }
    
    public static func fetchWellKnown(for domain: String) async throws -> WellKnown {
        
        guard let url = URL(string: "https://\(domain)/.well-known/matrix/client") else {
            let msg = "Couldn't construct well-known URL"
            print("WELLKNOWN\t\(msg)")
            throw Matrix.Error(msg)
        }
        print("WELLKNOWN\tURL is \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        //request.cachePolicy = .reloadIgnoringLocalCacheData
        request.cachePolicy = .returnCacheDataElseLoad

        
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            let msg = "Couldn't decode HTTP response"
            print("WELLKNOWN\t\(msg)")
            throw Matrix.Error(msg)
        }
        guard httpResponse.statusCode == 200 else {
            let msg = "HTTP request failed"
            print("WELLKNOWN\t\(msg)")
            throw Matrix.Error(msg)
        }
        
        let decoder = JSONDecoder()
        let stuff = String(data: data, encoding: .utf8)!
        print("WELLKNOWN\tGot response data:\n\(stuff)")
        guard let wellKnown = try? decoder.decode(WellKnown.self, from: data) else {
            let msg = "Couldn't decode response data"
            print("WELLKNOWN\t\(msg)")
            throw Matrix.Error(msg)
        }
        print("WELLKNOWN\tSuccess!")
        return wellKnown
    }
        

    // MARK: Types
    // Swift doesn't allow you to nest protocols inside other types, because fuck you.
    // Well fuck you too Swift, we're doing it anyway.
    // See below for the "real" type definitions.
    public typealias EventType = _MatrixEventType
    public typealias Event = _MatrixEvent
    public typealias AccountDataType = _MatrixAccountDataType
    public typealias MessageType = _MatrixMessageType
    public typealias MessageContent = _MatrixMessageContent
    
    // We're still in this dumb situation where Apple uses UIImage everywhere except MacOS
    #if os(macOS)
    public typealias NativeImage = NSImage
    #else
    public typealias NativeImage = UIImage
    #endif
    
    // Types imported from the Rust Crypto SDK
    public typealias Device = MatrixSDKCrypto.Device
}


// MARK: EventType
public enum _MatrixEventType: String, Codable, Equatable, Hashable {
    case mRoomCanonicalAlias = "m.room.canonical_alias"
    case mRoomCreate = "m.room.create"
    case mRoomJoinRules = "m.room.join_rules"
    case mRoomMember = "m.room.member"
    case mRoomPowerLevels = "m.room.power_levels"
    case mRoomMessage = "m.room.message"
    case mReaction = "m.reaction"
    case mRoomEncryption = "m.room.encryption"
    case mEncrypted = "m.encrypted"
    case mRoomTombstone = "m.room.tombstone"
    
    case mRoomName = "m.room.name"
    case mRoomAvatar = "m.room.avatar"
    case mRoomTopic = "m.room.topic"
    
    case mPresence = "m.presence"
    case mTyping = "m.typing"
    case mReceipt = "m.receipt"
    case mRoomHistoryVisibility = "m.room.history_visibility"
    case mRoomGuestAccess = "m.room.guest_access"
    case mTag = "m.tag"
    // case mRoomPinnedEvents = "m.room.pinned_events" // https://spec.matrix.org/v1.2/client-server-api/#mroompinned_events
    
    case mSpaceChild = "m.space.child"
    case mSpaceParent = "m.space.parent"
    
    // Add types for extensible events here
}

// MARK: Event
public protocol _MatrixEvent: Codable {
    var type: Matrix.EventType {get}
    var content: Codable {get}
}

// MARK: AccountDataType
public enum _MatrixAccountDataType: Codable, Equatable, Hashable {
    case mIdentityServer // "m.identity_server"
    case mFullyRead // "m.fully_read"
    case mDirect // "m.direct"
    case mIgnoredUserList
    case mPushRules // "m.push_rules"
    case mSecretStorageKey(String) // "m.secret_storage.key.[key ID]"
    case mTag // "m.tag"
    
    public init(from decoder: Decoder) throws {
        let string = try String(from: decoder)
        
        switch string {
        case "m.identity_server":
            self = .mIdentityServer
            return
        case "m.fully_read":
            self = .mFullyRead
            return
            
        case "m.direct":
            self = .mDirect
            return
            
        case "m.ignored_user_list":
            self = .mIgnoredUserList
            return
            
        case "m.push_rules":
            self = .mPushRules
            return
            
        case "m.tag":
            self = .mTag
            return
            
        default:
            
            // OK it's not one of the "normal" ones.  Is it one of the weird ones?
            
            // Maybe it's a secret storage key?
            if string.starts(with: "m.secret_storage.key.") {
                guard let keyId = string.split(separator: ".").last
                else {
                    let msg = "Couldn't get key id for m.secret_storage.key"
                    print(msg)
                    throw Matrix.Error(msg)
                }
                self = .mSecretStorageKey(String(keyId))
            }
            
            // If we're still here, then we have *no* idea what to do with this thing.
            let msg = "Failed to decode MatrixAccountDataType from string [\(string)]"
            print(msg)
            throw Matrix.Error(msg)
        }
    }
}

// MARK: MessageType
public enum _MatrixMessageType: String, Codable {
    case text = "m.text"
    case emote = "m.emote"
    case notice = "m.notice"
    case image = "m.image"
    case file = "m.file"
    case audio = "m.audio"
    case video = "m.video"
    case location = "m.location"
}

// MARK: MessageContent
public protocol _MatrixMessageContent: Codable {
    var body: String {get}
    var msgtype: Matrix.MessageType {get}
}

extension _MatrixMessageContent {
    init(from: Decoder) throws {
        
    }
}
