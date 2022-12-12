//
//  MessageContent.swift
//
//
//  Created by Charles Wright on 5/17/22.
//

import Foundation

extension Matrix {

    struct mInReplyTo: Codable {
        var event_id: String
    }
    struct mRelatesTo: Codable {
        var in_reply_to: mInReplyTo?

        enum CodingKeys: String, CodingKey {
            case in_reply_to = "m.in_reply_to"
        }
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-text
    struct mTextContent: Matrix.MessageContent {
        var msgtype: Matrix.MessageType
        var body: String
        var format: String?
        var formatted_body: String?

        // https://matrix.org/docs/spec/client_server/r0.6.0#rich-replies
        // Maybe should have made the "Rich replies" functionality a protocol...
        var relates_to: mRelatesTo?

        enum CodingKeys : String, CodingKey {
            case msgtype
            case body
            case format
            case formatted_body
            case relates_to = "m.relates_to"
        }
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-emote
    // cvw: Same as text.
    typealias mEmoteContent = mTextContent

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-notice
    // cvw: Same as text.
    typealias mNoticeContent = mTextContent

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-image
    struct mImageContent: Matrix.MessageContent {
        var msgtype: Matrix.MessageType
        var body: String
        var url: MXC?
        var info: mImageInfo
    }

    struct mImageInfo: Codable {
        var h: Int
        var w: Int
        var mimetype: String
        var size: Int
        var file: mEncryptedFile?
        var thumbnail_url: URL?
        var thumbnail_file: mEncryptedFile?
        var thumbnail_info: mThumbnailInfo?
        var blurhash: String?
    }

    struct mThumbnailInfo: Codable {
        var h: Int
        var w: Int
        var mimetype: String
        var size: Int
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-file
    struct mFileContent: Matrix.MessageContent {
        let msgtype: Matrix.MessageType
        var body: String
        var filename: String
        var info: mFileInfo
        var file: mEncryptedFile
    }

    struct mFileInfo: Codable {
        var mimetype: String
        var size: UInt
        var thumbnail_file: mEncryptedFile
        var thumbnail_info: mThumbnailInfo
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#extensions-to-m-message-msgtypes
    struct mEncryptedFile: Codable {
        var url: MXC
        var key: JWK
        var iv: String
        var hashes: [String: String]
        var v: String
    }

    //https://spec.matrix.org/v1.5/client-server-api/#extensions-to-mroommessage-msgtypes
    struct JWK: Codable {
        enum KeyType: String, Codable {
            case oct
        }
        enum KeyOperation: String, Codable {
            case encrypt
            case decrypt
        }
        enum Algorithm: String, Codable {
            case A256CTR
        }
        
        var kty: KeyType
        var key_ops: [KeyOperation]
        var alg: Algorithm
        var k: String
        var ext: Bool
        
        init(_ key: [UInt8]) {
            self.kty = .oct
            self.key_ops = [.decrypt]
            self.alg = .A256CTR
            self.k = Data(key).base64EncodedString()
            self.ext = true
        }
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-audio
    struct mAudioContent: Matrix.MessageContent {
        let msgtype: Matrix.MessageType
        var body: String
        var info: mAudioInfo
        var file: mEncryptedFile
    }

    struct mAudioInfo: Codable {
        var duration: UInt
        var mimetype: String
        var size: UInt
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-location
    struct mLocationContent: Matrix.MessageContent {
        let msgtype: Matrix.MessageType
        var body: String
        var geo_uri: String
        var info: mLocationInfo
    }

    struct mLocationInfo: Codable {
        var thumbnail_url: URL?
        var thumbnail_file: mEncryptedFile?
        var thumbnail_info: mThumbnailInfo
    }

    // https://matrix.org/docs/spec/client_server/r0.6.0#m-video
    struct mVideoContent: Matrix.MessageContent {
        let msgtype: Matrix.MessageType
        var body: String
        var info: mVideoInfo
        var file: mEncryptedFile
    }

    struct mVideoInfo: Codable {
        var duration: UInt
        var h: UInt
        var w: UInt
        var mimetype: String
        var size: UInt
        var thumbnail_url: MXC?
        var thumbnail_file: mEncryptedFile?
        var thumbnail_info: mThumbnailInfo
    }

} // end extension Matrix
