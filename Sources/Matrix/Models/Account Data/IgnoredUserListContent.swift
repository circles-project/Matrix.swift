//
//  IgnoredUserList.swift
//  Matrix.swift
//
//  Created by Charles Wright on 7/5/22.
//

import Foundation

// https://spec.matrix.org/v1.5/client-server-api/#mignored_user_list
// NOTE: The spec doesn't say what the values in the dictionary should be.
//       The example only shows an empty JSON object.
//       Ha!  Even Synapse doesn't know what it should be: https://github.com/matrix-org/synapse/blob/25f43faa70f7cc58493b636c2702ae63395779dc/synapse/storage/schema/main/delta/59/01ignored_user.py
//       I guess the correct thing to do here is to write our own Codable
//       implementation that only looks at the keys and ignores the values.
public struct IgnoredUserListContent: Codable {
    //public var ignoredUsers: [UserId: [String:String]]
    struct UserInfo: Codable {
        // Empty for now because the Matrix spec doesn't say what it should contain
    }
    
    enum CodingKeys: String, CodingKey {
        case ignoredUsers = "ignored_users"
    }
    
    public var ignoredUsers: [UserId]
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fakeDictionary = try container.decode([UserId: UserInfo].self, forKey: .ignoredUsers)
        self.ignoredUsers = Array(fakeDictionary.keys)
    }
    
    public func encode(to encoder: Encoder) throws {
        var fakeDictionary: [UserId: UserInfo] = [:]
        for ignoredUser in ignoredUsers {
            fakeDictionary[ignoredUser] = .init()
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fakeDictionary, forKey: .ignoredUsers)
    }
}
