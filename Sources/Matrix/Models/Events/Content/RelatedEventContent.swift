//
//  File.swift
//  
//
//  Created by Charles Wright on 4/24/23.
//

import Foundation

public protocol RelatedEventContent: Codable {
    var relationType: String? {get}
    var relatedEventId: EventId? {get}
    var replyToEventId: EventId? {get}
    var replacesEventId: EventId? {get}
}
