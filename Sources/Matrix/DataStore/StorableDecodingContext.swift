//
//  StorableDecodingContext.swift
//
//
//  Created by Michael Hollister on 1/13/23.
//

import Foundation
import GRDB

/// Protocol defines additional information required for decoding storable objects
public protocol StorableDecodingContext {
    static var decodingDataStore: GRDBDataStore? { get set }
    static var decodingDatabase: Database? { get set }
    static var decodingSession: Matrix.Session? { get set }
}
