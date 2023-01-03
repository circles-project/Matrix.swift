//
//  RoomGuestAccessContent.swift
//  
//
//  Created by Michael Hollister on 1/3/23.
//

import Foundation

/// m.room.guest_access: https://spec.matrix.org/v1.5/client-server-api/#mroomguest_access
struct RoomGuestAccessContent: Codable {
    enum GuestAccess: String, Codable {
        case canJoin = "can_join"
        case forbidden
    }
    
    let guestAccess: GuestAccess
    
    enum CodingKeys: String, CodingKey {
        case guestAccess = "guest_access"
    }
}

