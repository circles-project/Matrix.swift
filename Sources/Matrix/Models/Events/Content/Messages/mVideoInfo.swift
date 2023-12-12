//
//  mVideoInfo.swift
//
//
//  Created by Charles Wright on 12/12/23.
//

import Foundation

extension Matrix {
    public struct mVideoInfo: Codable {
        public var duration: UInt
        public var h: UInt
        public var w: UInt
        public var mimetype: String
        public var size: UInt
        public var thumbnail_url: MXC?
        public var thumbnail_file: mEncryptedFile?
        public var thumbnail_info: mThumbnailInfo?
        public var blurhash: String?
        public var thumbhash: String?
        
        public init(duration: UInt,
                    h: UInt, w: UInt,
                    mimetype: String,
                    size: UInt,
                    thumbnail_file: mEncryptedFile? = nil,
                    thumbnail_info: mThumbnailInfo? = nil,
                    thumbnail_url: MXC? = nil,
                    blurhash: String? = nil,
                    thumbhash: String? = nil
        ) {
            self.duration = duration
            self.h = h
            self.w = w
            self.mimetype = mimetype
            self.size = size
            self.thumbnail_file = thumbnail_file
            self.thumbnail_info = thumbnail_info
            self.thumbnail_url = thumbnail_url
            self.blurhash = blurhash
            self.thumbhash = thumbhash
        }
        
        // Custom Decodable implementation -- Handle invalid optional elements
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
            self.duration = try container.decode(UInt.self, forKey: .duration)
            self.h = try container.decode(UInt.self, forKey: .h)
            self.w = try container.decode(UInt.self, forKey: .w)
            self.mimetype = try container.decode(String.self, forKey: .mimetype)
            self.size = try container.decode(UInt.self, forKey: .size)
            // Use optional try to handle the case where these things are present but invalid
            self.thumbnail_url = try? container.decodeIfPresent(MXC.self, forKey: .thumbnail_url)
            self.thumbnail_file = try? container.decodeIfPresent(mEncryptedFile.self, forKey: .thumbnail_file)
            self.thumbnail_info = try? container.decodeIfPresent(mThumbnailInfo.self, forKey: .thumbnail_info)
            self.blurhash = try? container.decodeIfPresent(String.self, forKey: .blurhash)
            self.thumbhash = try? container.decodeIfPresent(String.self, forKey: .thumbhash)
        }
    }
}
