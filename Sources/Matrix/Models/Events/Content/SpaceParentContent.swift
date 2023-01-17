//
//  SpaceParentContent.swift
//  Circles
//
//  Created by Charles Wright on 6/15/22.
//

import Foundation

/// m.space.parent: https://spec.matrix.org/v1.5/client-server-api/#mspaceparent
struct SpaceParentContent: Codable {
    var canonical: Bool?
    var via: [String]?
}
