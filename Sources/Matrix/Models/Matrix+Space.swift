//
//  Matrix+Space.swift
//  
//
//  Created by Charles Wright on 3/10/23.
//

import Foundation

extension Matrix {
    public class Space: Room {
        @Published var children: Set<RoomId>
        @Published var parent: RoomId?
        
        public init(roomId: RoomId, session: Session, initialState: [ClientEventWithoutRoomId]) throws {
            self.children = []
            self.parent = nil
            try super.init(roomId: roomId, session: session, initialState: initialState, initialTimeline: [])
            
            for event in initialState.filter({$0.type == M_SPACE_CHILD}) {
                guard let childRoomIdString = event.stateKey,
                      let childRoomId = RoomId(childRoomIdString)
                else {
                    continue
                }
                self.children.insert(childRoomId)
            }
        }
        
        public func addChild(_ childRoomId: RoomId) async throws {
            try await self.session.addSpaceChild(childRoomId, to: self.roomId)
            // Finally update our state locally
            self.children.insert(childRoomId)
        }
        
        public func removeChild(_ childRoomId: RoomId) async throws {
            try await self.session.removeSpaceChild(childRoomId, from: self.roomId)
            self.children.remove(childRoomId)
        }

    }
}
