//
//  RoomAvatarContent.swift
//
//
//  Created by Charles Wright on 5/19/22.
//

import Foundation

/// m.room.avatar: https://spec.matrix.org/v1.5/client-server-api/#mroomavatar
struct RoomAvatarContent: Codable {
    let mxc: MXC
    let info: Matrix.mImageInfo
}
