//
//  IgnoredUserList.swift
//  Matrix.swift
//
//  Created by Charles Wright on 7/5/22.
//

import Foundation

public struct IgnoredUserListContent: Codable {
    public var ignoredUsers: [UserId: [String:String]]
}
