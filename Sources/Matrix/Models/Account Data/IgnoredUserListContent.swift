//
//  IgnoredUserList.swift
//  Matrix.swift
//
//  Created by Charles Wright on 7/5/22.
//

import Foundation

struct IgnoredUserListContent: Codable {
    var ignoredUsers: [UserId: [String:String]]
}
