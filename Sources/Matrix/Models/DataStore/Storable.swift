//
//  Storable.swift
//  
//
//  Created by Michael Hollister on 1/13/23.
//

import Foundation

/// docs TBD (documentation tag for indicating the key schema used for the datastore)
public protocol Storable {
    associatedtype StorableKey
}
