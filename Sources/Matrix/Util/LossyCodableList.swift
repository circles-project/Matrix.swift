//
//  LossyCodableList.swift
//  https://www.swiftbysundell.com/articles/ignoring-invalid-json-elements-codable/
//
//  Created by Charles Wright on 8/9/23.
//

import Foundation

@propertyWrapper
public struct LossyCodableList<Element> {
    public var elements: [Element]

    public var wrappedValue: [Element] {
        get { elements }
        set { elements = newValue }
    }
}

extension LossyCodableList: Decodable where Element: Decodable {
    private struct ElementWrapper: Decodable {
        var element: Element?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            element = try? container.decode(Element.self)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let wrappers = try container.decode([ElementWrapper].self)
        elements = wrappers.compactMap(\.element)
    }
}

extension LossyCodableList: Encodable where Element: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        for element in elements {
            try? container.encode(element)
        }
    }
}

