//
//  mLocationInfo.swift
//
//
//  Created by Charles Wright on 12/12/23.
//

import Foundation

extension Matrix {
    public struct mLocationInfo: Codable {
        public var thumbnail_url: MXC?
        public var thumbnail_file: mEncryptedFile?
        public var thumbnail_info: mThumbnailInfo
        public var blurhash: String?
        public var thumbhash: String?
        
        public init(thumbnail_url: MXC? = nil,
                    thumbnail_file: mEncryptedFile? = nil,
                    thumbnail_info: mThumbnailInfo,
                    blurhash: String? = nil,
                    thumbhash: String? = nil
        ) {
            self.thumbnail_url = thumbnail_url
            self.thumbnail_file = thumbnail_file
            self.thumbnail_info = thumbnail_info
            self.blurhash = blurhash
            self.thumbhash = thumbhash
        }
        
        // Custom Decodable implementation -- Ignore invalid elements if they're optionals
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
            self.thumbnail_url = try container.decodeIfPresent(MXC.self, forKey: .thumbnail_url)
            self.thumbnail_file = try? container.decodeIfPresent(mEncryptedFile.self, forKey: .thumbnail_file)
            self.thumbnail_info = try container.decode(mThumbnailInfo.self, forKey: .thumbnail_info)
            self.blurhash = try? container.decodeIfPresent(String.self, forKey: .blurhash)
            self.thumbhash = try? container.decodeIfPresent(String.self, forKey: .thumbhash)
        }
    }
}
