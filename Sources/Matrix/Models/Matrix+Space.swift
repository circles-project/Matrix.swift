//
//  Matrix+Space.swift
//  
//
//  Created by Charles Wright on 3/10/23.
//

import Foundation

extension Matrix {
    open class SpaceRoom: Room {
        
        public required init(roomId: RoomId, session: Session,
                             initialState: [ClientEventWithoutRoomId],
                             initialTimeline: [ClientEventWithoutRoomId] = [],
                             initialAccountData: [AccountDataEvent] = [],
                             initialReadReceipt: EventId? = nil
        ) throws {

            try super.init(roomId: roomId,
                           session: session,
                           initialState: initialState,
                           initialTimeline: initialTimeline,
                           initialAccountData: initialAccountData,
                           initialReadReceipt: initialReadReceipt
            )
            
            guard self.type == M_SPACE
            else {
                throw Matrix.Error("Not an m.space room")
            }
        }
        
        
        public var children: [RoomId] {
            self.state[M_SPACE_CHILD]?.compactMap { (stateKey,event) -> RoomId? in
                guard let content = event.content as? SpaceChildContent,
                      content.via?.first != nil,
                      let childRoomId = RoomId(stateKey)
                else {
                    return nil
                }
                return childRoomId
            } ?? []
        }
        
        public var parents: [RoomId] {
            self.state[M_SPACE_PARENT]?.compactMap { (stateKey,event) -> RoomId? in
                guard let content = event.content as? SpaceParentContent,
                      content.via?.first != nil,
                      let parentRoomId = RoomId(stateKey)
                else {
                    return nil
                }
                return parentRoomId
            } ?? []
        }
        
        public func addChild(_ childRoomId: RoomId) async throws {
            try await self.session.addSpaceChild(childRoomId, to: self.roomId)
        }
        
        public func removeChild(_ childRoomId: RoomId) async throws {
            try await self.session.removeSpaceChild(childRoomId, from: self.roomId)
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
