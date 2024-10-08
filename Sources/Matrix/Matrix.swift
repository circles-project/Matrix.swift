//
//  Matrix.swift
//  Circles
//
//  Created by Charles Wright on 6/14/22.
//

import Foundation
import os
#if !os(macOS)
import UIKit
#else
import AppKit
#endif
import AnyCodable

import MatrixSDKCrypto

@available(macOS 12.0, *)
public enum Matrix {

    // MARK: Utility Functions
    
    public static var logger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "Matrix.swift", category: "matrix")
    
    public class CryptoLogger: MatrixSDKCrypto.Logger {
        var logger = os.Logger(subsystem: "matrix", category: "crypto")
        public func log(logLine: String) {
            logger.info("\(logLine)")
        }
    }
    public static var cryptoLogger = CryptoLogger()
    
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
    public typealias Event = _MatrixEvent
    public typealias MessageContent = _MatrixMessageContent
    
    // We're still in this dumb situation where Apple uses UIImage everywhere except MacOS
    #if os(macOS)
    public typealias NativeImage = NSImage
    #else
    public typealias NativeImage = UIImage
    #endif
    
    // Mappings from String type names to Codable implementations
    // Used for encoding and decoding Matrix events
    static var eventTypes: [String: Codable.Type] = [
        M_ROOM_CANONICAL_ALIAS : RoomCanonicalAliasContent.self,
        M_ROOM_CREATE : RoomCreateContent.self,
        M_ROOM_MEMBER : RoomMemberContent.self,
        M_ROOM_JOIN_RULES : RoomJoinRuleContent.self,
        M_ROOM_POWER_LEVELS : RoomPowerLevelsContent.self,
        M_ROOM_NAME : RoomNameContent.self,
        M_ROOM_AVATAR : RoomAvatarContent.self,
        M_ROOM_TOPIC : RoomTopicContent.self,
        M_PRESENCE : PresenceContent.self,
        M_TYPING : TypingContent.self,
        M_RECEIPT : ReceiptContent.self,
        M_ROOM_HISTORY_VISIBILITY : RoomHistoryVisibilityContent.self,
        M_ROOM_GUEST_ACCESS : RoomGuestAccessContent.self,
        M_ROOM_TOMBSTONE : RoomTombstoneContent.self,
        M_TAG : TagContent.self,
        M_ROOM_ENCRYPTION : RoomEncryptionContent.self,
        M_ROOM_ENCRYPTED : EncryptedEventContent.self,
        M_SPACE_CHILD : SpaceChildContent.self,
        M_SPACE_PARENT : SpaceParentContent.self,
        M_REACTION : ReactionContent.self,
        M_ROOM_REDACTION: RedactionContent.self,
        M_ROOM_KEY : RoomKeyContent.self,
        M_ROOM_KEY_REQUEST : RoomKeyRequestContent.self,
        M_FORWARDED_ROOM_KEY : ForwardedRoomKeyContent.self,
        M_ROOM_KEY_WITHHELD : RoomKeyWithheldContent.self,
        M_SECRET_REQUEST : SecretRequestContent.self,
        M_SECRET_SEND : SecretSendContent.self,
        ORG_MATRIX_MSC3381_POLL_START : PollStartContent.self,
        ORG_MATRIX_MSC3381_POLL_RESPONSE : PollResponseContent.self,
        ORG_MATRIX_MSC3381_POLL_END : PollEndContent.self,
    ]
    static var messageTypes: [String: Codable.Type] = [
        M_TEXT : mTextContent.self,
        M_EMOTE : mEmoteContent.self,
        M_NOTICE : mNoticeContent.self,
        M_IMAGE : mImageContent.self,
        M_FILE : mFileContent.self,
        M_AUDIO : mAudioContent.self,
        M_VIDEO : mVideoContent.self,
        M_LOCATION : mLocationContent.self,
    ]
    static var accountDataTypes: [String: Codable.Type] = [
        //M_IDENTITY_SERVER : IdentityServerContent.self,
        M_FULLY_READ : FullyReadContent.self,
        M_DIRECT : DirectContent.self,
        M_IGNORED_USER_LIST : IgnoredUserListContent.self,
        M_PUSH_RULES : PushRulesContent.self,
        M_TAG : TagContent.self,
        M_SECRET_STORAGE_DEFAULT_KEY : DefaultKeyContent.self,
        M_CROSS_SIGNING_MASTER : SecretStore.Secret.self,
        M_CROSS_SIGNING_USER_SIGNING : SecretStore.Secret.self,
        M_CROSS_SIGNING_SELF_SIGNING : SecretStore.Secret.self,
        M_MEGOLM_BACKUP_V1: SecretStore.Secret.self,
        M_DEHYDRATED_DEVICE: SecretStore.Secret.self,
    ]
    static var cryptoKeyTypes: [String: Codable.Type] = [
        : // FIXME
    ]
    static var roomTypes: [String: Room.Type] = [
        M_SPACE : SpaceRoom.self,
    ]
    static var defaultRoomType: Room.Type = ChatRoom.self
    
    public static func registerEventType(_ string: String, _ codable: Codable.Type) {
        eventTypes[string] = codable
    }
    
    public static func registerMessageType(_ string: String, _ codable: Codable.Type) {
        messageTypes[string] = codable
    }
    
    public static func registerAccountDataType(_ string: String, _ codable: Codable.Type) {
        accountDataTypes[string] = codable
    }
    
    public static func registerRoomType(_ string: String, _ room: Matrix.Room.Type) {
        roomTypes[string] = room
    }
}


// MARK: Event
public protocol _MatrixEvent: Codable {
    var type: String {get}
    var content: Codable {get}
}


// MARK: MessageContent
public protocol _MatrixMessageContent: Codable, RelatedEventContent {
    var body: String {get}
    var msgtype: String {get}
    
    var mimetype: String? {get}
    
    var thumbnail_info: Matrix.mThumbnailInfo? {get}
    var thumbnail_file: Matrix.mEncryptedFile? {get}
    var thumbnail_url: MXC? {get}
    var blurhash: String? {get}
    var thumbhash: String? {get}
    
    func mentions(userId: UserId) -> Bool
    
    var debugString: String {get}
}

extension _MatrixMessageContent {
    public var debugString: String {
        """
        msg_type: \(msgtype)
        body: \(body)
        """
    }
}
