//
//  RoomGuestAccessContent.swift
//  
//
//  Created by Michael Hollister on 1/3/23.
//

import Foundation

/// m.room.guest_access: https://spec.matrix.org/v1.5/client-server-api/#mroomguest_access
public struct RoomGuestAccessContent: Codable {
    public enum GuestAccess: String, Codable {
        case canJoin = "can_join"
        case forbidden
    }
    
    public let guestAccess: GuestAccess
    
    public init(guestAccess: GuestAccess) {
        self.guestAccess = guestAccess
    }
    
    public enum CodingKeys: String, CodingKey {
        case guestAccess = "guest_access"
    }
}

