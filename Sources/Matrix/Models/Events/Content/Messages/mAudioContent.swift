//
//  mAudioContent.swift
//
//
//  Created by Charles Wright on 12/12/23.
//

import Foundation

extension Matrix {
    // https://matrix.org/docs/spec/client_server/r0.6.0#m-audio
    public struct mAudioContent: Matrix.MessageContent {
        public let msgtype: String
        public var body: String
        public var info: mAudioInfo
        public var file: mEncryptedFile?
        public var url: MXC?
        public var relatesTo: mRelatesTo?
        
        public enum CodingKeys: String, CodingKey {
            case msgtype
            case body
            case info
            case file
            case url
            case relatesTo = "m.relates_to"
        }
        
        public init(body: String,
                    info: mAudioInfo,
                    file: mEncryptedFile,
                    relatesTo: mRelatesTo? = nil
        ) {
            self.msgtype = M_AUDIO
            self.body = body
            self.info = info
            self.file = file
            self.url = nil
            self.relatesTo = relatesTo
        }
        
        public init(body: String,
                    info: mAudioInfo,
                    url: MXC,
                    relatesTo: mRelatesTo? = nil
        ) {
            self.msgtype = M_AUDIO
            self.body = body
            self.info = info
            self.file = nil
            self.url = url
            self.relatesTo = relatesTo
        }
        
        // Custom Decodable implementation -- Ignore invalid members as long as they're optionals and we can use optional try
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
            self.msgtype = try container.decode(String.self, forKey: .msgtype)
            self.body = try container.decode(String.self, forKey: .body)
            self.info = try container.decode(mAudioInfo.self, forKey: .info)
            self.file = try? container.decodeIfPresent(mEncryptedFile.self, forKey: .file)
            self.url = try? container.decodeIfPresent(MXC.self, forKey: .url)
            self.relatesTo = try? container.decodeIfPresent(mRelatesTo.self, forKey: .relatesTo)
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
            self.body.contains(userId.username)
        }
    }
}
