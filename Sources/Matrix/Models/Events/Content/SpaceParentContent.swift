//
//  SpaceParentContent.swift
//  Circles
//
//  Created by Charles Wright on 6/15/22.
//

import Foundation

/// m.space.parent: https://spec.matrix.org/v1.5/client-server-api/#mspaceparent
public struct SpaceParentContent: Codable {
    public var canonical: Bool?
    public var via: [String]?
}
