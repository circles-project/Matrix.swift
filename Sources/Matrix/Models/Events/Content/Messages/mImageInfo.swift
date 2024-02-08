//
//  mImageInfo.swift
//
//
//  Created by Charles Wright on 12/12/23.
//

import Foundation

extension Matrix {
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
        
        public init(_ copy: mImageInfo,
                    h: Int? = nil,
                    w: Int? = nil,
                    mimetype: String? = nil,
                    size: Int? = nil,
                    thumbnail_url: MXC? = nil,
                    thumbnail_file: mEncryptedFile? = nil,
                    thumbnail_info: mThumbnailInfo? = nil,
                    blurhash: String? = nil,
                    thumbhash: String? = nil
        ) {
            self.h = h ?? copy.h
            self.w = w ?? copy.w
            self.mimetype = mimetype ?? copy.mimetype
            self.size = size ?? copy.size
            self.thumbnail_url = thumbnail_url ?? copy.thumbnail_url
            self.thumbnail_file = thumbnail_file ?? copy.thumbnail_file
            self.thumbnail_info = thumbnail_info ?? copy.thumbnail_info
            self.blurhash = blurhash ?? copy.blurhash
            self.thumbhash = thumbhash ?? copy.thumbhash
        }
        
        // Custom Decodable implementation -- Handle invalid optional elements
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
            self.h = try container.decode(Int.self, forKey: .h)
            self.w = try container.decode(Int.self, forKey: .w)
            self.mimetype = try container.decode(String.self, forKey: .mimetype)
            self.size = try container.decode(Int.self, forKey: .size)
            // Use optional try to handle the case where these things are present but invalid
            self.thumbnail_url = try? container.decodeIfPresent(MXC.self, forKey: .thumbnail_url)
            self.thumbnail_file = try? container.decodeIfPresent(mEncryptedFile.self, forKey: .thumbnail_file)
            self.thumbnail_info = try? container.decodeIfPresent(mThumbnailInfo.self, forKey: .thumbnail_info)
            self.blurhash = try? container.decodeIfPresent(String.self, forKey: .blurhash)
            self.thumbhash = try? container.decodeIfPresent(String.self, forKey: .thumbhash)
        }
    }
}
