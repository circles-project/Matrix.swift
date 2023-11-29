//
//  PollContent.swift
//
//
//  Created by Michael Hollister on 11/28/23.
//

import Foundation

// Stubs until proper support for polls is implemented
// MSC: https://github.com/matrix-org/matrix-spec-proposals/pull/3381

public struct PollStartContent: Codable {
    var body: String?
    var text: String?
    var start: PollStart

    struct PollStart: Codable {
        var kind: String
        var maxSelections: Int
        var question: [String: String]
        var answers: [[String: String]]

        enum CodingKeys: String, CodingKey {
            case kind
            case maxSelections = "max_selections"
            case question
            case answers
        }
    }

    enum CodingKeys: String, CodingKey {
        case body
        case text = "org.matrix.msc1767.text"
        case start = "org.matrix.msc3381.poll.start"
    }
}

public struct PollResponseContent: Codable {
    var body: String?
    var relatesTo: mRelatesTo
    var response: [String: [String]]

    enum CodingKeys: String, CodingKey {
        case body
        case relatesTo = "m.relates_to"
        case response = "org.matrix.msc3381.poll.response"
    }
}

public struct PollEndContent: Codable {
    var relatesTo: mRelatesTo
    var text: String

    enum CodingKeys: String, CodingKey {
        case relatesTo = "m.relates_to"
        case text = "org.matrix.msc1767.text"
        // org.matrix.msc3381.poll.end
    }
}
