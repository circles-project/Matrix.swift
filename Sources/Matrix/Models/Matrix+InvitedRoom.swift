//
//  Matrix+InvitedRoom.swift
//  
//
//  Created by Charles Wright on 12/6/22.
//

import Foundation

extension Matrix {
    public class InvitedRoom: StrippedStateRoom {
        public var sender: UserId {
            let event = state[M_ROOM_MEMBER]!["\(session.creds.userId)"]!
            return event.sender
        }
    }
}
