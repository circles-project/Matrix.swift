//
//  Matrix+Space.swift
//  
//
//  Created by Charles Wright on 3/10/23.
//

import Foundation

extension Matrix {
    public class SpaceRoom: Room {
        @Published var children: Set<RoomId>
        @Published var parents: Set<RoomId>
        
        public init(roomId: RoomId, session: Session, initialState: [ClientEventWithoutRoomId]) throws {
            self.children = []
            self.parents = []
            try super.init(roomId: roomId, session: session, initialState: initialState, initialTimeline: [])
            
            guard self.type == M_SPACE
            else {
                throw Matrix.Error("Not an m.space room")
            }
            
            let initialChildren = self.state[M_SPACE_CHILD]?.values.compactMap { event in
                RoomId(event.stateKey!)
            } ?? []
            self.children = Set(initialChildren)

            let initialParents = self.state[M_SPACE_PARENT]?.values.compactMap { event in
                RoomId(event.stateKey!)
            } ?? []
            self.parents = Set(initialParents)
        }
        
        public func addChild(_ childRoomId: RoomId) async throws {
            if !self.children.contains(childRoomId) {
                try await self.session.addSpaceChild(childRoomId, to: self.roomId)
                // Finally update our state locally
                await MainActor.run {
                    self.children.insert(childRoomId)
                }
            }
        }
        
        public func removeChild(_ childRoomId: RoomId) async throws {
            if self.children.contains(childRoomId) {
                try await self.session.removeSpaceChild(childRoomId, from: self.roomId)
                await MainActor.run {
                    self.children.remove(childRoomId)
                }
            }
        }
        
        public func getChildRoomIds() async throws -> [RoomId] {
            try await self.session.getSpaceChildren(self.roomId)
        }

    }
}

/*

extension Matrix {
    // This will be the class that we use to track nodes in the Spaces hierarchy
    // These are not necessarily rooms that we are joined in, so everything that we know about them comes to us via the /hierarchy API
    public class SpaceNode: ObservableObject {
        @Published public var avatar: Matrix.NativeImage?
        public var avatarUrl: MXC?
        public var canonicalAlias: String?
        //var childrenState: [StrippedStateEvent]
        public var state: [String: [String:StrippedStateEvent]]
        public var guestCanJoin: Bool
        public var joinRule: RoomJoinRuleContent.JoinRule?
        public var name: String?
        public var numJoinedMembers: Int
        public var roomId: RoomId
        //public var roomType: String?
        public var type: String?
        public var topic: String?
        public var worldReadable: Bool
        
        public var parents: Set<SpaceNode>
        public var children: Set<SpaceNode>
    }
    
    public init(roomId: RoomId, session: Session) throws {
        throw Matrix.Error("Not implemented")
    }
}

extension Matrix.SpaceNode: Identifiable {
    public var id: String {
        "\(self.roomId)"
    }
}

extension Matrix.SpaceNode: Equatable {
    public static func == (lhs: Matrix.SpaceNode, rhs: Matrix.SpaceNode) -> Bool {
        lhs.roomId == rhs.roomId
    }
    
    
}

extension Matrix.SpaceNode: Hashable {
    public func hash(into hasher: inout Hasher) {
        self.roomId.hash(into: &hasher)
    }
}
*/
