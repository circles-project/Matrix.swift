//
//  Matrix+encoding.swift
//  
//
//  Created by Charles Wright on 10/26/22.
//

/* // Ha!  So this just winds up being a thin wrapper around AnyCodable.  Let's just use that instead.
import Foundation
import AnyCodable

extension Matrix {
    
    // MARK: Encoding
    
    public static func encodeContent(_ content: Codable) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(AnyCodable(content))
    }
    
    public static func encodeContent(_ content: Codable, to encoder: Encoder) throws {
        enum CodingKeys: String, CodingKey {
            case content
        }
        
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(AnyCodable(content), forKey: .content)
    }
    
}
*/
