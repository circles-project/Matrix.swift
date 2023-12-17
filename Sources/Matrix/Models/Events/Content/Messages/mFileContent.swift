//
//  mFileContent.swift
//
//
//  Created by Charles Wright on 12/12/23.
//

import Foundation

extension Matrix {
    // https://matrix.org/docs/spec/client_server/r0.6.0#m-file
    public struct mFileContent: Matrix.MessageContent {
        public let msgtype: String
        public var body: String
        public var filename: String
        public var url: MXC?
        public var info: mFileInfo
        public var file: mEncryptedFile?
        public var relatesTo: mRelatesTo?
        
        public enum CodingKeys: String, CodingKey {
            case msgtype
            case body
            case filename
            case url
            case info
            case file
            case relatesTo = "m.relates_to"
        }
        
        public init(body: String,
                    filename: String,
                    info: mFileInfo,
                    file: mEncryptedFile,
                    relatesTo: mRelatesTo? = nil
        ) {
            self.msgtype = M_FILE
            self.body = body
            self.filename = filename
            self.info = info
            self.file = file
            self.relatesTo = relatesTo
        }
        
        // Custom Decodable implementation -- Use optional try to ignore invalid optional members
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
            self.msgtype = try container.decode(String.self, forKey: .msgtype)
            self.body = try container.decode(String.self, forKey: .body)
            self.filename = try container.decode(String.self, forKey: .filename)
            self.url = try? container.decodeIfPresent(MXC.self, forKey: .url)
            self.info = try container.decode(Matrix.mFileInfo.self, forKey: .info)
            self.file = try? container.decodeIfPresent(Matrix.mEncryptedFile.self, forKey: .file)
            self.relatesTo = try? container.decodeIfPresent(mRelatesTo.self, forKey: .relatesTo)
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
