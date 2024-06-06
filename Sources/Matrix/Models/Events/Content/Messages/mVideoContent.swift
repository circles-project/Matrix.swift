//
//  mVideoContent.swift
//
//
//  Created by Charles Wright on 12/12/23.
//

import Foundation

extension Matrix {
    // https://matrix.org/docs/spec/client_server/r0.6.0#m-video
    public struct mVideoContent: Matrix.MessageContent {
        public let msgtype: String
        public var body: String
        public var info: mVideoInfo
        public var file: mEncryptedFile?
        public var url: MXC?
        public var caption: String?
        public var relatesTo: mRelatesTo?
        
        public enum CodingKeys: String, CodingKey {
            case msgtype
            case body
            case info
            case file
            case url
            case caption
            case relatesTo = "m.relates_to"
        }
        
        public init(body: String,
                    info: mVideoInfo,
                    file: mEncryptedFile,
                    caption: String? = nil,
                    relatesTo: mRelatesTo? = nil
        ) {
            self.msgtype = M_VIDEO
            self.body = body
            self.info = info
            self.file = file
            self.url = nil
            self.caption = caption
            self.relatesTo = relatesTo
        }
        
        public init(body: String,
                    info: mVideoInfo,
                    url: MXC,
                    caption: String? = nil,
                    relatesTo: mRelatesTo? = nil
        ) {
            self.msgtype = M_VIDEO
            self.body = body
            self.info = info
            self.file = nil
            self.url = url
            self.caption = caption
            self.relatesTo = relatesTo
        }
        
        // Copy constructor, with the option to update any/all of the fields
        // This is sort of like how Elm lets you update just one piece of a structure
        public init(_ copy: mVideoContent,
                    body: String? = nil,
                    caption: String? = nil,
                    file: mEncryptedFile? = nil,
                    info: mVideoInfo? = nil,
                    relatesTo: mRelatesTo? = nil,
                    url: MXC? = nil
        ) {
            self.msgtype = M_VIDEO
            self.body = body ?? copy.body
            self.caption = caption ?? copy.caption
            self.file = file ?? copy.file
            self.info = info ?? copy.info
            self.relatesTo = relatesTo ?? copy.relatesTo
            self.url = url ?? copy.url
        }
        
        // Custom Decodable implementation -- Use optional try to ignore any invalid elements as long as they are optionals
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
            
            self.msgtype = try container.decode(String.self, forKey: .msgtype)
            self.body = try container.decode(String.self, forKey: .body)
            self.caption = try? container.decodeIfPresent(String.self, forKey: .caption)
            self.info = try container.decode(mVideoInfo.self, forKey: .info)
            self.file = try? container.decodeIfPresent(mEncryptedFile.self, forKey: .file)
            self.url = try? container.decodeIfPresent(MXC.self, forKey: .url)
            self.relatesTo = try? container.decodeIfPresent(mRelatesTo.self, forKey: .relatesTo)
        }
        
        public var mimetype: String? {
            info.mimetype
        }
        
        public var captionMessage: String? {
            caption
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
        
        public var relationType: String? {
            self.relatesTo?.relType
        }
        
        public var relatedEventId: EventId? {
            self.relatesTo?.eventId
        }
        
        public var replyToEventId: EventId? {
            self.relatesTo?.inReplyTo?.eventId
        }
        
        public var replacesEventId: EventId? {
            guard let relation = self.relatesTo,
                  relation.relType == M_REPLACE
            else {
                return nil
            }
            return relation.eventId
        }
        
        public func mentions(userId: UserId) -> Bool {
            if let caption = self.caption {
                return caption.contains(userId.username)
            } else {
                return self.body.contains(userId.username)
            }
        }
    }
}
