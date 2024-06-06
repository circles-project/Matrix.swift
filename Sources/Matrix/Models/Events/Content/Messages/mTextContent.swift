//
//  mTextContent.swift
//
//
//  Created by Charles Wright on 12/12/23.
//

import Foundation

extension Matrix {
    // https://matrix.org/docs/spec/client_server/r0.6.0#m-text
    public struct mTextContent: Matrix.MessageContent {
        public var msgtype: String
        public var body: String
        public var format: String?
        public var formatted_body: String?

        // https://matrix.org/docs/spec/client_server/r0.6.0#rich-replies
        // Maybe should have made the "Rich replies" functionality a protocol...
        public var relatesTo: mRelatesTo?

        public init(body: String,
                    format: String? = nil,
                    formatted_body: String? = nil,
                    relatesTo: mRelatesTo? = nil
        ) {
            self.msgtype = M_TEXT
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
        
        public var captionMessage: String? {
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
        
        public var debugString: String {
            """
            msg_type: \(msgtype)
            body: \(body)
            """
        }
    }
}
