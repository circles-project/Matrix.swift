//
//  PollContent.swift
//
//
//  Created by Michael Hollister on 11/28/23.
//

import Foundation
import AnyCodable

// MSC: https://github.com/matrix-org/matrix-spec-proposals/pull/3381

/// Indicates that events should use unstable fields when being encoded
private let ENCODE_UNSTABLE_FIELDS = true

public struct PollAnswer: Codable, Identifiable {
    public let id: String
    public let answer: Matrix.MessageContent
    
    public enum UnstableCodingKeys: String, CodingKey {
        case id
        case answer = "org.matrix.msc1767.text"
    }
    
    public init(id: String, answer: Matrix.MessageContent) {
        self.id = id
        self.answer = answer
    }
    
    public init(from decoder: Decoder) throws {
        // Both unstable and stable decoding is allowed for backward compatability
        let stableContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
        let unstableContainer = try decoder.container(keyedBy: UnstableCodingKeys.self)
        
        if let id = try stableContainer.decodeIfPresent(String.self, forKey: .init(stringValue: "id")) {
            self.id = id
        }
        else if let id = try unstableContainer.decodeIfPresent(String.self, forKey: .id) {
            self.id = id
        }
        else {
            throw Matrix.Error("Error decoding PollAnswer: Missing ID field")
        }
        
        if let answer = try unstableContainer.decodeIfPresent(String.self, forKey: .answer) {
            var text = Matrix.mTextContent(body: answer)
            text.msgtype = ORG_MATRIX_MSC1767_TEXT
            self.answer = text
            
            return
        }
        else {
            for type in Matrix.messageTypes.keys {
                let key = DynamicCodingKeys(stringValue: type)
                if stableContainer.contains(key) {
                    if let codableType = Matrix.messageTypes[type],
                       let answerContent = try stableContainer.decode(codableType.self, forKey: key) as? Matrix.MessageContent {
                        self.answer = answerContent
                        return
                    }
                }
            }
        }

        throw Matrix.Error("Error decoding PollAnswer: answer field is not in the correct format")
    }
    
    public func encode(to encoder: Encoder) throws {
        if ENCODE_UNSTABLE_FIELDS {
            var container = encoder.container(keyedBy: UnstableCodingKeys.self)
            
            try container.encode(id, forKey: .id)
            try container.encode(answer.body, forKey: .answer)
        }
        else {
            var container = encoder.container(keyedBy: DynamicCodingKeys.self)
            
            try container.encode(id, forKey: .init(stringValue: "m.id"))
            try container.encode(AnyCodable(answer), forKey: .init(stringValue: answer.msgtype))
        }
    }
}

public struct PollStartContent: Matrix.MessageContent {
    public let msgtype: String
    public let body: String
    
    /// Optional fallback text representation of the message, for clients that don't support polls.
    public let message: String
    /// The poll start content of the message.
    public var start: PollStart
    
    public enum UnstableCodingKeys: String, CodingKey {
        case message = "org.matrix.msc1767.text"
        case start = "org.matrix.msc3381.poll.start"
    }
    
    public enum StableCodingKeys: String, CodingKey {
        case message = "m.text"
        case start = "m.poll"
    }
    
    public struct PollStart: Codable {
        public enum Kind: String, Codable {
            /// The votes are visible up until and including when the poll is closed.
            case open // "m.disclosed"
            /// The results are revealed once the poll is closed.
            case closed // "m.undisclosed"
        }
        
        public let kind: Kind
        
        /// The maximum number of responses a user is able to select.
        ///
        /// Must be greater or equal to `1`.
        ///
        /// Defaults to `1`.
        public let maxSelections: UInt
        
        public let question: Matrix.MessageContent
        public let answers: [PollAnswer]

        enum CodingKeys: String, CodingKey {
            case kind
            case maxSelections = "max_selections"
            case question
            case answers
        }
        
        public init(kind: Kind?, maxSelections: UInt?, question: Matrix.MessageContent, answers: [PollAnswer]) {
            self.kind = kind ?? Kind.closed
            self.maxSelections = maxSelections ?? 1
            self.question = question
            self.answers = answers
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let kind = try container.decodeIfPresent(String.self, forKey: .kind)
            
            if kind == "m.disclosed" || kind == "m.poll.disclosed" || kind == "org.matrix.msc3381.poll.disclosed" {
                self.kind = Kind.open
            }
            else { // "m.undisclosed" || "m.poll.undisclosed" || "org.matrix.msc3381.poll.undisclosed" || default
                self.kind = Kind.closed
            }
            
            self.maxSelections = try container.decodeIfPresent(UInt.self, forKey: .maxSelections) ?? 1
            guard self.maxSelections >= 1
            else {
                throw Matrix.Error("Error decoding PollStart: maxSelections must be >= 1")
            }
            
            let question = try container.decode([String: AnyCodable].self, forKey: .question)
            guard let questionType = question.first?.key
            else {
                throw Matrix.Error("Error decoding PollStart: question is missing message content")
            }
            
            if Matrix.messageTypes.keys.contains(questionType),
               let questionContent = question[questionType] as? Matrix.MessageContent {
                self.question = questionContent
            }
            else if questionType == ORG_MATRIX_MSC1767_TEXT,
                    let questionContent = question[questionType]?.value as? String {
                var content = Matrix.mTextContent(body: questionContent)
                content.msgtype = ORG_MATRIX_MSC1767_TEXT
                
                self.question = content
            }
            else {
                throw Matrix.Error("Error decoding PollStart: question content is unknown")
            }
            
            self.answers = try container.decode([PollAnswer].self, forKey: .answers)
            guard self.answers.count >= 1 && self.answers.count <= 20
            else {
                throw Matrix.Error("Error decoding PollStart: answers count (\(self.answers.count)) must be >= 1 and <= 20")
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(maxSelections, forKey: .maxSelections)
            try container.encode(AnyCodable(answers), forKey: .answers)
            
            if ENCODE_UNSTABLE_FIELDS {
                switch kind {
                case .open:
                    try container.encode("org.matrix.msc3381.poll.disclosed", forKey: .kind)
                case .closed:
                    try container.encode("org.matrix.msc3381.poll.undisclosed", forKey: .kind)
                }
                
                try container.encode(AnyCodable([ORG_MATRIX_MSC1767_TEXT: question]), forKey: .question)
            }
            else {
                switch kind {
                case .open:
                    try container.encode("m.disclosed", forKey: .kind)
                case .closed:
                    try container.encode("m.undisclosed", forKey: .kind)
                }
                
                try container.encode(AnyCodable([question.msgtype: question]), forKey: .question)
            }
        }
    }

    public init(message: String, start: PollStart) {
        self.message = message
        self.start = start
        
        // Protocol required implementations
        self.body = message
        self.msgtype = ORG_MATRIX_MSC3381_POLL_START
    }
    
    public init(from decoder: Decoder) throws {
        // Both unstable and stable decoding is allowed for backward compatability
        let stableContainer = try decoder.container(keyedBy: StableCodingKeys.self)
        let unstableContainer = try decoder.container(keyedBy: UnstableCodingKeys.self)
        
        if let pollStart = try stableContainer.decodeIfPresent(PollStart.self, forKey: .start) {
            self.start = pollStart
        }
        else if let pollStart = try unstableContainer.decodeIfPresent(PollStart.self, forKey: .start) {
            self.start = pollStart
        }
        else {
            throw Matrix.Error("Error decoding PollStartContent: \(ORG_MATRIX_MSC3381_POLL_START) field is missing from event")
        }

        if let message = try stableContainer.decodeIfPresent(Matrix.mTextContent.self, forKey: .message) {
            self.message = message.body
        }
        else if let message = try unstableContainer.decodeIfPresent(String.self, forKey: .message) {
            self.message = message
        }
        // Android does not also provide the required fallback m.text message
        else {
            self.message = self.start.question.body
        }
        
        // Protocol required implementations
        self.body = self.message
        self.msgtype = ORG_MATRIX_MSC3381_POLL_START
    }
    
    public func encode(to encoder: Encoder) throws {
        if ENCODE_UNSTABLE_FIELDS {
            var container = encoder.container(keyedBy: UnstableCodingKeys.self)
            
            try container.encode(start, forKey: .start)
            try container.encode(message, forKey: .message)
        }
        else {
            var container = encoder.container(keyedBy: StableCodingKeys.self)
            
            try container.encode(start, forKey: .start)
            try container.encode([Matrix.mTextContent(body: message)], forKey: .message)
        }
    }
    
    // Protocol required implementations
    public var mimetype: String? {
        nil
    }
    
    public var captionMessage: String? {
        nil
    }
    
    public var thumbnail_info: Matrix.mThumbnailInfo? {
        nil
    }
    
    public var thumbnail_file: Matrix.mEncryptedFile? {
        nil
    }
    
    public var thumbnail_url: MXC? {
        nil
    }
    
    public var blurhash: String? {
        nil
    }
    
    public var thumbhash: String? {
        nil
    }
    
    public var relationType: String? {
        nil
    }
    
    public var relatedEventId: EventId? {
        nil
    }
    
    public var replyToEventId: EventId? {
        nil
    }
    
    public var replacesEventId: EventId? {
        nil
    }
    
    public func mentions(userId: UserId) -> Bool {
        self.body.contains(userId.username)
    }
    
    public var debugString: String {
        """
        msg_type: \(msgtype)
        body: \(body)
        """
    }
}

public struct PollResponseContent: Matrix.MessageContent {
    public var msgtype: String
    public var body: String
    
    public let relatesTo: mRelatesTo
    
    /// The IDs of the selected answers of the poll.
    ///
    /// It should be truncated to `max_selections` from the related poll start event.
    ///
    /// If this is an empty array or includes unknown IDs, this vote should be considered as
    /// spoiled.
    public let selections: [String]
    
    public enum UnstableCodingKeys: String, CodingKey {
        case relatesTo = "m.relates_to"
        case selections = "org.matrix.msc3381.poll.response"
    }
    
    public enum StableCodingKeys: String, CodingKey {
        case relatesTo = "m.relates_to"
        case selections = "m.selections"
    }
    
    public init(relatesTo: mRelatesTo, selections: [String]) {
        self.relatesTo = relatesTo
        self.selections = selections
        
        // Protocol required implementations
        self.body = selections.description
        self.msgtype = ORG_MATRIX_MSC3381_POLL_RESPONSE
    }
    
    public init(from decoder: Decoder) throws {
        // Both unstable and stable decoding is allowed for backward compatability
        let stableContainer = try decoder.container(keyedBy: StableCodingKeys.self)
        let unstableContainer = try decoder.container(keyedBy: UnstableCodingKeys.self)
        
        if let relatesTo = try stableContainer.decodeIfPresent(mRelatesTo.self, forKey: .relatesTo) {
            self.relatesTo = relatesTo
        }
        else {
            throw Matrix.Error("Error decoding PollResponseContent: relatesTo field is missing from event")
        }
        
        if let selections = try stableContainer.decodeIfPresent([String].self, forKey: .selections) {
            self.selections = selections
        }
        else if let selections = try unstableContainer.decodeIfPresent([String: [String]].self, forKey: .selections),
            let answers = selections["answers"] {
            
            self.selections = answers
        }
        else {
            throw Matrix.Error("Error decoding PollResponseContent: selections field is missing from event")
        }
        
        // Protocol required implementations
        self.body = selections.description
        self.msgtype = ORG_MATRIX_MSC3381_POLL_RESPONSE
    }
    
    public func encode(to encoder: Encoder) throws {
        if ENCODE_UNSTABLE_FIELDS {
            var container = encoder.container(keyedBy: UnstableCodingKeys.self)
            
            try container.encode(relatesTo, forKey: .relatesTo)
            try container.encode(["answers": selections], forKey: .selections)
        }
        else {
            var container = encoder.container(keyedBy: StableCodingKeys.self)
            
            try container.encode(relatesTo, forKey: .relatesTo)
            try container.encode(["answers": selections], forKey: .selections)
        }
    }
    
    // Protocol required implementations
    public var mimetype: String? {
        nil
    }
    
    public var captionMessage: String? {
        nil
    }
    
    public var thumbnail_info: Matrix.mThumbnailInfo? {
        nil
    }
    
    public var thumbnail_file: Matrix.mEncryptedFile? {
        nil
    }
    
    public var thumbnail_url: MXC? {
        nil
    }
    
    public var blurhash: String? {
        nil
    }
    
    public var thumbhash: String? {
        nil
    }
    
    public var relationType: String? {
        self.relatesTo.relType
    }
    
    public var relatedEventId: EventId? {
        self.relatesTo.eventId
    }
    
    public var replyToEventId: EventId? {
        self.relatesTo.inReplyTo?.eventId
    }
    
    public var replacesEventId: EventId? {
        if self.relatesTo.relType == M_REPLACE {
            return self.relatesTo.eventId
        }
        else {
            return nil
        }
    }
    
    public func mentions(userId: UserId) -> Bool {
        self.body.contains(userId.username)
    }
    
    public var debugString: String {
        """
        msg_type: \(msgtype)
        body: \(body)
        """
    }
}

public struct PollEndContent: Matrix.MessageContent {
    public var msgtype: String
    public var body: String
    
    public var relatesTo: mRelatesTo
    public var text: String
    public var results: [String: UInt]?

    enum CodingKeys: String, CodingKey {
        case relatesTo = "m.relates_to"
        case text = "org.matrix.msc1767.text"
        // org.matrix.msc3381.poll.end
    }
    
    public enum UnstableCodingKeys: String, CodingKey {
        case relatesTo = "m.relates_to"
        case text = "org.matrix.msc1767.text"
        case end = "org.matrix.msc3381.poll.end"
    }
    
    public enum StableCodingKeys: String, CodingKey {
        case relatesTo = "m.relates_to"
        case text = "m.text"
        case results = "m.poll.results"
    }
    
    public init(relatesTo: mRelatesTo, text: String, results: [String: UInt]?) {
        self.relatesTo = relatesTo
        self.text = text
        self.results = results
        
        // Protocol required implementations
        self.body = text
        self.msgtype = ORG_MATRIX_MSC3381_POLL_END
    }
    
    public init(from decoder: Decoder) throws {
        // Both unstable and stable decoding is allowed for backward compatability
        let stableContainer = try decoder.container(keyedBy: StableCodingKeys.self)
        let unstableContainer = try decoder.container(keyedBy: UnstableCodingKeys.self)
        
        if let relatesTo = try stableContainer.decodeIfPresent(mRelatesTo.self, forKey: .relatesTo) {
            self.relatesTo = relatesTo
        }
        else {
            throw Matrix.Error("Error decoding PollResponseContent: relatesTo field is missing from event")
        }
        
        if let text = try stableContainer.decodeIfPresent(Matrix.mTextContent.self, forKey: .text) {
            self.text = text.body
        }
        else if let text = try unstableContainer.decodeIfPresent(String.self, forKey: .text) {
            self.text = text
        }
        else {
            throw Matrix.Error("Error decoding PollResponseContent: text field is missing from event")
        }
        
        if let results = try stableContainer.decodeIfPresent([String: UInt].self, forKey: .results) {
            self.results = results
        }
        
        // org.matrix.msc3381.poll.end is required per MSC for unstable, but Android/Rust implementations ignore this
        
        // Protocol required implementations
        self.body = self.text
        self.msgtype = ORG_MATRIX_MSC3381_POLL_END
    }
    
    public func encode(to encoder: Encoder) throws {
        if ENCODE_UNSTABLE_FIELDS {
            var container = encoder.container(keyedBy: UnstableCodingKeys.self)
            
            try container.encode(relatesTo, forKey: .relatesTo)
            try container.encode(text, forKey: .text)
            try container.encode([String:String](), forKey: .end)
        }
        else {
            var container = encoder.container(keyedBy: StableCodingKeys.self)
            
            try container.encode(relatesTo, forKey: .relatesTo)
            try container.encode(Matrix.mTextContent(body: text), forKey: .text)
            try container.encodeIfPresent(results, forKey: .results)
        }
    }
    
    // Protocol required implementations
    public var mimetype: String? {
        nil
    }
    
    public var captionMessage: String? {
        nil
    }
    
    public var thumbnail_info: Matrix.mThumbnailInfo? {
        nil
    }
    
    public var thumbnail_file: Matrix.mEncryptedFile? {
        nil
    }
    
    public var thumbnail_url: MXC? {
        nil
    }
    
    public var blurhash: String? {
        nil
    }
    
    public var thumbhash: String? {
        nil
    }
    
    public var relationType: String? {
        self.relatesTo.relType
    }
    
    public var relatedEventId: EventId? {
        self.relatesTo.eventId
    }
    
    public var replyToEventId: EventId? {
        self.relatesTo.inReplyTo?.eventId
    }
    
    public var replacesEventId: EventId? {
        if self.relatesTo.relType == M_REPLACE {
            return self.relatesTo.eventId
        }
        else {
            return nil
        }
    }
    
    public func mentions(userId: UserId) -> Bool {
        self.body.contains(userId.username)
    }
    
    public var debugString: String {
        """
        msg_type: \(msgtype)
        body: \(body)
        """
    }
}
