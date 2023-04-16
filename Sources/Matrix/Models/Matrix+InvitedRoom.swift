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
        
        public func accept(reason: String? = nil) async throws {
            try await join(reason: reason)
        }
        
        public func reject(reason: String? = nil) async throws {
            try await session.leave(roomId: self.roomId, reason: reason)
        }
        
        public func ignore() async throws {
            try await session.deleteInvitedRoom(roomId: roomId)
        }
    }
}
