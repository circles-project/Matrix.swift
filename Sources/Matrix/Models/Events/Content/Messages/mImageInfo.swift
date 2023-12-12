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
    }
}
