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
        public var info: mFileInfo
        public var file: mEncryptedFile
        public var relatesTo: mRelatesTo?
        
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
