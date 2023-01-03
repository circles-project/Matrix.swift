//
//  RoomMemberContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

/// m.room.member: https://spec.matrix.org/v1.5/client-server-api/#mroommember
struct RoomMemberContent: Codable {
    let avatarUrl: String?
    let displayname: String?
    let isDirect: Bool?
    let joinAuthorizedUsersViaServer: String?
    enum Membership: String, Codable {
        case invite
        case join
        case knock
        case leave
        case ban
    }
    let membership: Membership
    let reason: String?
    struct Invite: Codable {
        let displayName: String
    }
    let thirdPartyInvite: Invite?
    
    enum CodingKeys: String, CodingKey {
        case avatarUrl = "avatar_url"
        case displayname
        case isDirect = "is_direct"
        case joinAuthorizedUsersViaServer = "join_authorised_via_users_server"
        case membership
        case reason
        case thirdPartyInvite = "third_party_invite"
    }
}
