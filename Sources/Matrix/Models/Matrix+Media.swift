//
//  Matrix+Media.swift
//
//
//  Created by Charles Wright on 4/11/24.
//

import Foundation

extension Matrix {

    // https://spec.matrix.org/v1.10/client-server-api/#get_matrixmediav3config
    // https://github.com/matrix-org/matrix-spec-proposals/pull/4034
    public struct MediaConfigInfo: Codable {
        public var maxUploadSize: Int?
        public var storageSize: Int?
        public var maxFiles: Int?
        
        public enum CodingKeys: String, CodingKey {
            case maxUploadSize = "m.upload.size"
            case storageSize = "m.storage.size"
            case maxFiles = "m.storage.max_files"
        }
        
    }
    
    // https://github.com/matrix-org/matrix-spec-proposals/pull/4034
    public struct MediaUsageInfo: Codable {
        public var storageUsed: Int?
        public var storageFiles: Int?
        
        public enum CodingKeys: String, CodingKey {
            case storageUsed = "m.storage.used"
            case storageFiles = "m.storage.files"
        }
    }
}
