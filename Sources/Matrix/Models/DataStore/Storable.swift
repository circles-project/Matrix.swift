//
//  Storable.swift
//  
//
//  Created by Michael Hollister on 1/13/23.
//

import Foundation

/// Storable protocol provides a field that indicates the type structure used
/// for an object's key/identifier used for storage
public protocol Storable {
    associatedtype StorableKey
}
