//
//  TagContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

/// m.tag: https://spec.matrix.org/v1.5/client-server-api/#mtag
public struct TagContent: Codable {
    public struct Tag: Codable {
        public let order: Float
    }
    public let tags: [String: Tag]
}
