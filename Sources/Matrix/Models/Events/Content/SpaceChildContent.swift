//
//  SpaceChildContent.swift
//  Circles
//
//  Created by Charles Wright on 6/15/22.
//

import Foundation

/// m.space.child: https://spec.matrix.org/v1.5/client-server-api/#mspacechild
public struct SpaceChildContent: Codable {
    public var order: String?
    public var suggested: Bool?
    public var via: [String]?
    
    public init(order: String? = nil, suggested: Bool? = nil, via: [String]? = nil) {
        self.order = order
        self.suggested = suggested
        self.via = via
    }
}
