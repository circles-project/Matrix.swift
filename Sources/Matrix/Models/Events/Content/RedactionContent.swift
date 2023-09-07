//
//  RedactionContent.swift
//  
//
//  Created by Charles Wright on 9/6/23.
//

import Foundation

public struct RedactionContent: Codable {
    public let reason: String?
    public let redacts: EventId?
    
    public init(reason: String? = nil, redacts: EventId? = nil) {
        self.reason = reason
        self.redacts = redacts
    }
}
