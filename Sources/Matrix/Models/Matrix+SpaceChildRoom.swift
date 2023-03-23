//
//  Matrix+SpaceChildRoom.swift
//  
//
//  Created by Charles Wright on 3/23/23.
//

import Foundation

extension Matrix {
    public class SpaceChildRoom: StrippedStateRoom {
        
        public func knock(reason: String? = nil) async throws {
            try await self.session.knock(roomId: self.roomId, reason: reason)
        }
    }
}
