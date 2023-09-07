//
//  TagContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

/// m.tag: https://spec.matrix.org/v1.5/client-server-api/#mtag
public struct TagContent: Codable {
    
    public struct Tag: Codable, Comparable {
        public let order: Float?
        
        public static func < (lhs: TagContent.Tag, rhs: TagContent.Tag) -> Bool {
            guard let right = rhs.order
            else {
                return true
            }
            
            guard let left = lhs.order
            else {
                return false
            }

            return left < right
        }
    }
    
    public let tags: [String: Tag]
    
    public init(tags: [String : Tag]) {
        self.tags = tags
    }
}
