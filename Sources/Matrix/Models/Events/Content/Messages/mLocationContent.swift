//
//  mLocationContent.swift
//
//
//  Created by Charles Wright on 12/12/23.
//

import Foundation

extension Matrix {
    // https://matrix.org/docs/spec/client_server/r0.6.0#m-location
    public struct mLocationContent: Matrix.MessageContent {
        public let msgtype: String
        public var body: String
        public var geo_uri: String
        public var info: mLocationInfo
        public var relatesTo: mRelatesTo?
        
        public enum CodingKeys: String, CodingKey {
            case msgtype
            case body
            case geo_uri
            case info
            case relatesTo = "m.relates_to"
        }
        
        public init(body: String,
                    geo_uri: String,
                    info: mLocationInfo,
                    relatesTo: mRelatesTo? = nil
        ) {
            self.msgtype = M_LOCATION
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
