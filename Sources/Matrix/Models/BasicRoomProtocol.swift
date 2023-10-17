//
//  RoomAvatarInfo.swift
//  
//
//  Created by Michael Hollister on 9/4/23.
//

import Foundation

public protocol BasicRoomProtocol: ObservableObject {
    var roomId: RoomId { get }
    var name: String? { get }
    var avatar: Matrix.NativeImage? { get }
    func updateAvatarImage()
}
