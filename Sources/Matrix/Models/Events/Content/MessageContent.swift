//
//  MessageContent.swift
//
//
//  Created by Charles Wright on 5/17/22.
//

import Foundation

extension Matrix {

    public struct mInReplyTo: Codable {
        public var event_id: String
    }
    public struct mRelatesTo: Codable {
        public var in_reply_to: mInReplyTo?

        public enum CodingKeys: String, CodingKey {
            case in_reply_to = "m.in_reply_to"
        }
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-text
    public struct mTextContent: Matrix.MessageContent {
        public var msgtype: Matrix.MessageType
        public var body: String
        public var format: String?
        public var formatted_body: String?

        // https://matrix.org/docs/spec/client_server/r0.6.0#rich-replies
        // Maybe should have made the "Rich replies" functionality a protocol...
        public var relates_to: mRelatesTo?

        public enum CodingKeys : String, CodingKey {
            case msgtype
            case body
            case format
            case formatted_body
            case relates_to = "m.relates_to"
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
        public var url: URL?
        public var info: mImageInfo
    }

    public struct mImageInfo: Codable {
        public var h: Int
        public var w: Int
        public var mimetype: String
        public var size: Int
        public var file: mEncryptedFile?
        public var thumbnail_url: URL?
        public var thumbnail_file: mEncryptedFile?
        public var thumbnail_info: mThumbnailInfo?
        public var blurhash: String?
    }

    public struct mThumbnailInfo: Codable {
        public var h: Int
        public var w: Int
        public var mimetype: String
        public var size: Int
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-file
    public struct mFileContent: Matrix.MessageContent {
        public let msgtype: Matrix.MessageType
        public var body: String
        public var filename: String
        public var info: mFileInfo
        public var file: mEncryptedFile
    }

    public struct mFileInfo: Codable {
        public var mimetype: String
        public var size: UInt
        public var thumbnail_file: mEncryptedFile
        public var thumbnail_info: mThumbnailInfo
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#extensions-to-m-message-msgtypes
    public struct mEncryptedFile: Codable {
        public var url: URL
        public var key: JWK
        public var iv: String
        public var hashes: [String: String]
        public var v: String
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#extensions-to-m-message-msgtypes
    public struct JWK: Codable {
        public var kty: String
        public var key_ops: [String]
        public var alg: String
        public var k: String
        public var ext: Bool
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-audio
    public struct mAudioContent: Matrix.MessageContent {
        public let msgtype: Matrix.MessageType
        public var body: String
        public var info: mAudioInfo
        public var file: mEncryptedFile
    }

    public struct mAudioInfo: Codable {
        public var duration: UInt
        public var mimetype: String
        public var size: UInt
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-location
    public struct mLocationContent: Matrix.MessageContent {
        public let msgtype: Matrix.MessageType
        public var body: String
        public var geo_uri: String
        public var info: mLocationInfo
    }

    public struct mLocationInfo: Codable {
        public var thumbnail_url: URL?
        public var thumbnail_file: mEncryptedFile?
        public var thumbnail_info: mThumbnailInfo
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-video
    public struct mVideoContent: Matrix.MessageContent {
        public let msgtype: Matrix.MessageType
        public var body: String
        public var info: mVideoInfo
        public var file: mEncryptedFile
    }

    public struct mVideoInfo: Codable {
        public var duration: UInt
        public var h: UInt
        public var w: UInt
        public var mimetype: String
        public var size: UInt
        public var thumbnail_url: URL?
        public var thumbnail_file: mEncryptedFile?
        public var thumbnail_info: mThumbnailInfo
    }

} // end extension Matrix
