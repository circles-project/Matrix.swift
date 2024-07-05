//
//  RelatedMessagesResponseBody.swift
//  
//
//  Created by Charles Wright on 7/27/23.
//

import Foundation

public struct RelatedMessagesResponseBody: Codable {
    public var chunk: [ClientEvent]
    public var nextBatch: String?
    public var prevBatch: String?
    
    public enum CodingKeys: String, CodingKey {
        case chunk
        case nextBatch = "next_batch"
        case prevBatch = "prev_batch"
    }
}
