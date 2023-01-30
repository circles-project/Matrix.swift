//
//  RoomAvatarContent.swift
//
//
//  Created by Charles Wright on 5/19/22.
//

import Foundation

/// m.room.avatar: https://spec.matrix.org/v1.5/client-server-api/#mroomavatar
public struct RoomAvatarContent: Codable {
    public let mxc: MXC
    public let info: Matrix.mImageInfo
    
    public init(mxc: MXC, info: Matrix.mImageInfo) {
        self.mxc = mxc
        self.info = info
    }
    
    public enum CodingKeys: String, CodingKey {
        case mxc = "url"
        case info
    }
}
