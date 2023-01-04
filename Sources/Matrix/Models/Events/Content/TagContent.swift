//
//  TagContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

/// m.tag: https://spec.matrix.org/v1.5/client-server-api/#mtag
struct TagContent: Codable {
    struct Tag: Codable {
        let order: Float
    }
    let tags: [String: Tag]
}
