//
//  RoomMemberContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

/// m.room.member: https://spec.matrix.org/v1.5/client-server-api/#mroommember
public struct RoomMemberContent: Codable {
    public let avatarUrl: String?
    public let displayname: String?
    public let isDirect: Bool?
    public let joinAuthorizedUsersViaServer: String?
    public enum Membership: String, Codable {
        case invite
        case join
        case knock
        case leave
        case ban
    }
    public let membership: Membership
    public let reason: String?
    public struct Invite: Codable {
        public let displayName: String
        
        public init(displayName: String) {
            self.displayName = displayName
        }
    }
    public let thirdPartyInvite: Invite?
    
    public init(avatarUrl: String? = nil, displayname: String? = nil, isDirect: Bool? = nil,
                joinAuthorizedUsersViaServer: String? = nil, membership: Membership, reason: String? = nil,
                thirdPartyInvite: Invite? = nil) {
        self.avatarUrl = avatarUrl
        self.displayname = displayname
        self.isDirect = isDirect
        self.joinAuthorizedUsersViaServer = joinAuthorizedUsersViaServer
        self.membership = membership
        self.reason = reason
        self.thirdPartyInvite = thirdPartyInvite
    }
    
    public enum CodingKeys: String, CodingKey {
        case avatarUrl = "avatar_url"
        case displayname
        case isDirect = "is_direct"
        case joinAuthorizedUsersViaServer = "join_authorised_via_users_server"
        case membership
        case reason
        case thirdPartyInvite = "third_party_invite"
    }
}
