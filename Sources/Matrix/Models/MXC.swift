//
//  MXC.swift
//  Circles
//
//  Created by Charles Wright on 6/20/22.
//

import Foundation

public struct MXC: Codable, Equatable, LosslessStringConvertible {
    
    public var serverName: String
    public var mediaId: String
    
    public var description: String {
        "mxc://\(serverName)/\(mediaId)"
    }
    
    public init?(_ description: String) {
        guard description.starts(with: "mxc://")
        else { return nil }
        
        let toks = description.split(separator: "/", omittingEmptySubsequences: true)
        
        guard toks.count == 3
        else { return nil }
        
        self.serverName = String(toks[1])
        self.mediaId = String(toks[2])
    }

    public init(from decoder: Decoder) throws {
        let mxc = try String(from: decoder)
        guard let me: MXC = .init(mxc) else {
            throw Matrix.Error("Invalid MXC URI")
        }
        self = me
    }
    
    public enum CodingKeys: CodingKey {
        case serverName
        case mediaId
    }
    
    public func encode(to encoder: Encoder) throws {
        try self.description.encode(to: encoder)
    }
}
