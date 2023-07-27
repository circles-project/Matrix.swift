//
//  RelatedMessagesResponseBody.swift
//  
//
//  Created by Charles Wright on 7/27/23.
//

import Foundation

public struct RelatedMessagesResponseBody: Codable {
    var chunk: [ClientEvent]
    var nextBatch: String?
    var prevBatch: String?
    
    enum CodingKeys: String, CodingKey {
        case chunk
        case nextBatch = "next_batch"
        case prevBatch = "prev_batch"
    }
}
