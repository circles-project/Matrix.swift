//
//  RoomJoinRuleContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

/// m.room.join_rules: https://spec.matrix.org/v1.5/client-server-api/#mroomjoin_rules
public struct RoomJoinRuleContent: Codable {
    public struct AllowCondition: Codable {
        public let roomId: RoomId
        public enum AllowConditionType: String, Codable {
            case mRoomMembership = "m.room_membership"
        }
        public let type: AllowConditionType
    }
    public enum JoinRule: String, Codable {
        case public_ = "public"
        case knock
        case invite
        case private_ = "private"
        case restricted
    }
    
    public let allow: [AllowCondition]?
    public let joinRule: JoinRule
    
    public init(allow: [AllowCondition]? = nil, joinRule: JoinRule) {
        self.allow = allow
        self.joinRule = joinRule
    }
    
    public enum CodingKeys: String, CodingKey {
        case allow
        case joinRule = "join_rule"
    }
}
