//
//  MessageContent.swift
//
//
//  Created by Charles Wright on 5/17/22.
//

import Foundation

extension Matrix {

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-text
    public struct mTextContent: Matrix.MessageContent {
        public var msgtype: Matrix.MessageType
        public var body: String
        public var format: String?
        public var formatted_body: String?

        // https://matrix.org/docs/spec/client_server/r0.6.0#rich-replies
        // Maybe should have made the "Rich replies" functionality a protocol...
        public var relatesTo: mRelatesTo?

        public init(msgtype: Matrix.MessageType, body: String, format: String? = nil,
                    formatted_body: String? = nil, relatesTo: mRelatesTo? = nil) {
            self.msgtype = msgtype
            self.body = body
            self.format = format
            self.formatted_body = formatted_body
            self.relatesTo = relatesTo
        }
        
        public enum CodingKeys : String, CodingKey {
            case msgtype
            case body
            case format
            case formatted_body
            case relatesTo = "m.relates_to"
        }
        
        public var mimetype: String? {
            nil
        }
        
        public var thumbnail_info: Matrix.mThumbnailInfo? {
            nil
        }
        
        public var thumbnail_file: Matrix.mEncryptedFile? {
            nil
        }
        
        public var thumbnail_url: MXC? {
            nil
        }
        
        public var blurhash: String? {
            nil
        }
        
        public var thumbhash: String? {
            nil
        }
        
        public var relationshipType: String? {
            self.relatesTo?.relType
        }
        
        public var relatedEventId: EventId? {
            self.relatesTo?.eventId
        }
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-emote
    // cvw: Same as text.
    public typealias mEmoteContent = mTextContent

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-notice
    // cvw: Same as text.
    public typealias mNoticeContent = mTextContent

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-image
    public struct mImageContent: Matrix.MessageContent {
        public var msgtype: Matrix.MessageType
        public var body: String
        public var file: mEncryptedFile?
        public var url: MXC?
        public var info: mImageInfo
        public var caption: String?
        public var relatesTo: mRelatesTo?
        
        public init(msgtype: Matrix.MessageType,
                    body: String,
                    url: MXC? = nil,
                    info: mImageInfo,
                    caption: String? = nil,
                    relatesTo: mRelatesTo? = nil
        ) {
            self.msgtype = msgtype
            self.body = body
            self.file = nil
            self.url = url
            self.info = info
            self.caption = caption
            self.relatesTo = relatesTo
        }

        public init(msgtype: Matrix.MessageType,
                    body: String,
                    file: mEncryptedFile? = nil,
                    info: mImageInfo,
                    caption: String? = nil,
                    relatesTo: mRelatesTo? = nil
        ) {
            self.msgtype = msgtype
            self.body = body
            self.file = file
            self.url = nil
            self.info = info
            self.caption = caption
            self.relatesTo = relatesTo
        }
        
        public var mimetype: String? {
            info.mimetype
        }
        
        public var thumbnail_info: Matrix.mThumbnailInfo? {
            info.thumbnail_info
        }
        
        public var thumbnail_file: Matrix.mEncryptedFile? {
            info.thumbnail_file
        }
        
        public var thumbnail_url: MXC? {
            info.thumbnail_url
        }
        
        public var blurhash: String? {
            info.blurhash
        }
        
        public var thumbhash: String? {
            info.thumbhash
        }
        
        public var relationshipType: String? {
            self.relatesTo?.relType
        }
        
        public var relatedEventId: EventId? {
            self.relatesTo?.eventId
        }
    }


    public struct mImageInfo: Codable {
        public var h: Int
        public var w: Int
        public var mimetype: String
        public var size: Int
        public var thumbnail_url: MXC?
        public var thumbnail_file: mEncryptedFile?
        public var thumbnail_info: mThumbnailInfo?
        public var blurhash: String?
        public var thumbhash: String?
        
        public init(h: Int, w: Int, mimetype: String, size: Int,
                    thumbnail_url: MXC? = nil,
                    thumbnail_file: mEncryptedFile? = nil,
                    thumbnail_info: mThumbnailInfo? = nil,
                    blurhash: String? = nil,
                    thumbhash: String? = nil
        ) {
            self.h = h
            self.w = w
            self.mimetype = mimetype
            self.size = size
            self.thumbnail_url = thumbnail_url
            self.thumbnail_file = thumbnail_file
            self.thumbnail_info = thumbnail_info
            self.blurhash = blurhash
            self.thumbhash = thumbhash
        }
    }

    public struct mThumbnailInfo: Codable {
        public var h: Int
        public var w: Int
        public var mimetype: String
        public var size: Int
        
        public init(h: Int, w: Int, mimetype: String, size: Int) {
            self.h = h
            self.w = w
            self.mimetype = mimetype
            self.size = size
        }
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-file
    public struct mFileContent: Matrix.MessageContent {
        public let msgtype: Matrix.MessageType
        public var body: String
        public var filename: String
        public var info: mFileInfo
        public var file: mEncryptedFile
        public var relatesTo: mRelatesTo?
        
        public init(msgtype: Matrix.MessageType,
                    body: String,
                    filename: String,
                    info: mFileInfo,
                    file: mEncryptedFile,
                    relatesTo: mRelatesTo? = nil
        ) {
            self.msgtype = msgtype
            self.body = body
            self.filename = filename
            self.info = info
            self.file = file
            self.relatesTo = relatesTo
        }
        
        public var mimetype: String? {
            info.mimetype
        }
        
        public var thumbnail_info: Matrix.mThumbnailInfo? {
            info.thumbnail_info
        }
        
        public var thumbnail_file: Matrix.mEncryptedFile? {
            info.thumbnail_file
        }
        
        public var thumbnail_url: MXC? {
            info.thumbnail_url
        }
        
        public var blurhash: String? {
            info.blurhash
        }
        
        public var thumbhash: String? {
            info.thumbhash
        }
        
        public var relationshipType: String? {
            self.relatesTo?.relType
        }
        
        public var relatedEventId: EventId? {
            self.relatesTo?.eventId
        }
    }

    public struct mFileInfo: Codable {
        public var mimetype: String
        public var size: UInt
        public var thumbnail_file: mEncryptedFile?
        public var thumbnail_info: mThumbnailInfo
        public var thumbnail_url: MXC?
        public var blurhash: String?
        public var thumbhash: String?
        
        public init(mimetype: String, size: UInt, thumbnail_file: mEncryptedFile?, thumbnail_url: MXC? = nil,
                    thumbnail_info: mThumbnailInfo,
                    blurhash: String? = nil,
                    thumbhash: String? = nil
        ) {
            self.mimetype = mimetype
            self.size = size
            self.thumbnail_info = thumbnail_info
            self.thumbnail_file = thumbnail_file
            self.thumbnail_url = thumbnail_url
            self.blurhash = blurhash
            self.thumbhash = thumbhash
        }
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#extensions-to-m-message-msgtypes
    public struct mEncryptedFile: Codable {
        public var url: MXC
        public var key: JWK
        public var iv: String
        public var hashes: [String: String]
        public var v: String
        
        public init(url: MXC, key: JWK, iv: String, hashes: [String : String], v: String) {
            self.url = url
            self.key = key
            self.iv = iv
            self.hashes = hashes
            self.v = v
        }
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#extensions-to-m-message-msgtypes
    public struct JWK: Codable {
        public enum KeyType: String, Codable {
            case oct
        }
        public enum KeyOperation: String, Codable {
            case encrypt
            case decrypt
        }
        public enum Algorithm: String, Codable {
            case A256CTR
        }

        public var kty: KeyType
        public var key_ops: [KeyOperation]
        public var alg: Algorithm
        public var k: String
        public var ext: Bool

        public init(_ key: [UInt8]) {
            self.kty = .oct
            self.key_ops = [.decrypt]
            self.alg = .A256CTR
            self.k = Data(key).base64EncodedString()
            self.ext = true
        }
        
        public init(kty: KeyType, key_ops: [KeyOperation], alg: Algorithm, k: String, ext: Bool) {
            self.kty = kty
            self.key_ops = key_ops
            self.alg = alg
            self.k = k
            self.ext = ext
        }
    }


    // https://matrix.org/docs/spec/client_server/r0.6.0#m-audio
    public struct mAudioContent: Matrix.MessageContent {
        public let msgtype: Matrix.MessageType
        public var body: String
        public var info: mAudioInfo
        public var file: mEncryptedFile?
        public var url: MXC?
        public var relatesTo: mRelatesTo?
        
        public init(msgtype: Matrix.MessageType,
                    body: String,
                    info: mAudioInfo,
                    file: mEncryptedFile,
                    relatesTo: mRelatesTo? = nil
        ) {
            self.msgtype = msgtype
            self.body = body
            self.info = info
            self.file = file
            self.url = nil
            self.relatesTo = relatesTo
        }
        
        public init(msgtype: Matrix.MessageType,
                    body: String,
                    info: mAudioInfo,
                    url: MXC,
                    relatesTo: mRelatesTo? = nil
        ) {
            self.msgtype = msgtype
            self.body = body
            self.info = info
            self.file = nil
            self.url = url
            self.relatesTo = relatesTo
        }
        
        public var mimetype: String? {
            info.mimetype
        }
        
        public var thumbnail_info: Matrix.mThumbnailInfo? {
            nil
        }
        
        public var thumbnail_file: Matrix.mEncryptedFile? {
            nil
        }
        
        public var thumbnail_url: MXC? {
            nil
        }
        
        public var blurhash: String? {
            nil
        }
        
        public var thumbhash: String? {
            nil
        }
        
        public var relationshipType: String? {
            self.relatesTo?.relType
        }
        
        public var relatedEventId: EventId? {
            self.relatesTo?.eventId
        }
    }

    public struct mAudioInfo: Codable {
        public var duration: UInt
        public var mimetype: String
        public var size: UInt
        
        public init(duration: UInt, mimetype: String, size: UInt) {
            self.duration = duration
            self.mimetype = mimetype
            self.size = size
        }
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-location
    public struct mLocationContent: Matrix.MessageContent {
        public let msgtype: Matrix.MessageType
        public var body: String
        public var geo_uri: String
        public var info: mLocationInfo
        public var relatesTo: mRelatesTo?
        
        public init(msgtype: Matrix.MessageType,
                    body: String,
                    geo_uri: String,
                    info: mLocationInfo,
                    relatesTo: mRelatesTo? = nil
        ) {
            self.msgtype = msgtype
            self.body = body
            self.geo_uri = geo_uri
            self.info = info
            self.relatesTo = relatesTo
        }
        
        public var mimetype: String? {
            nil
        }
        
        public var thumbnail_info: Matrix.mThumbnailInfo? {
            info.thumbnail_info
        }
        
        public var thumbnail_file: Matrix.mEncryptedFile? {
            info.thumbnail_file
        }
        
        public var thumbnail_url: MXC? {
            info.thumbnail_url
        }
        
        public var blurhash: String? {
            info.blurhash
        }
        
        public var thumbhash: String? {
            info.thumbhash
        }
        
        public var relationshipType: String? {
            self.relatesTo?.relType
        }
        
        public var relatedEventId: EventId? {
            self.relatesTo?.eventId
        }
    }

    public struct mLocationInfo: Codable {
        public var thumbnail_url: MXC?
        public var thumbnail_file: mEncryptedFile?
        public var thumbnail_info: mThumbnailInfo
        public var blurhash: String?
        public var thumbhash: String?
        
        public init(thumbnail_url: MXC? = nil, thumbnail_file: mEncryptedFile? = nil,
                    thumbnail_info: mThumbnailInfo,
                    blurhash: String? = nil,
                    thumbhash: String? = nil
        ) {
            self.thumbnail_url = thumbnail_url
            self.thumbnail_file = thumbnail_file
            self.thumbnail_info = thumbnail_info
            self.blurhash = blurhash
            self.thumbhash = thumbhash
        }
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-video
    public struct mVideoContent: Matrix.MessageContent {
        public let msgtype: Matrix.MessageType
        public var body: String
        public var info: mVideoInfo
        public var file: mEncryptedFile?
        public var url: MXC?
        public var caption: String?
        public var relatesTo: mRelatesTo?
        
        public init(msgtype: Matrix.MessageType,
                    body: String,
                    info: mVideoInfo,
                    file: mEncryptedFile,
                    caption: String? = nil,
                    relatesTo: mRelatesTo? = nil
        ) {
            self.msgtype = msgtype
            self.body = body
            self.info = info
            self.file = file
            self.url = nil
            self.caption = caption
            self.relatesTo = relatesTo
        }
        
        public init(msgtype: Matrix.MessageType,
                    body: String,
                    info: mVideoInfo,
                    url: MXC,
                    caption: String? = nil,
                    relatesTo: mRelatesTo? = nil
        ) {
            self.msgtype = msgtype
            self.body = body
            self.info = info
            self.file = nil
            self.url = url
            self.caption = caption
            self.relatesTo = relatesTo
        }
        
        public var mimetype: String? {
            info.mimetype
        }
        
        public var thumbnail_info: Matrix.mThumbnailInfo? {
            info.thumbnail_info
        }
        
        public var thumbnail_file: Matrix.mEncryptedFile? {
            info.thumbnail_file
        }
        
        public var thumbnail_url: MXC? {
            info.thumbnail_url
        }
        
        public var blurhash: String? {
            info.blurhash
        }
        
        public var thumbhash: String? {
            info.thumbhash
        }
        
        public var relationshipType: String? {
            self.relatesTo?.relType
        }
        
        public var relatedEventId: EventId? {
            self.relatesTo?.eventId
        }
    }

    public struct mVideoInfo: Codable {
        public var duration: UInt
        public var h: UInt
        public var w: UInt
        public var mimetype: String
        public var size: UInt
        public var thumbnail_url: MXC?
        public var thumbnail_file: mEncryptedFile?
        public var thumbnail_info: mThumbnailInfo
        public var blurhash: String?
        public var thumbhash: String?
        
        public init(duration: UInt, h: UInt, w: UInt, mimetype: String, size: UInt,
                    thumbnail_url: MXC? = nil, thumbnail_file: mEncryptedFile? = nil,
                    thumbnail_info: mThumbnailInfo,
                    blurhash: String? = nil,
                    thumbhash: String? = nil
        ) {
            self.duration = duration
            self.h = h
            self.w = w
            self.mimetype = mimetype
            self.size = size
            self.thumbnail_url = thumbnail_url
            self.thumbnail_file = thumbnail_file
            self.thumbnail_info = thumbnail_info
            self.blurhash = blurhash
            self.thumbhash = thumbhash
        }
    }

} // end extension Matrix
