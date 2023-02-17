//
//  DataStore.swift
//  
//
//  Created by Charles Wright on 2/14/23.
//

import Foundation

protocol DataStore {
    
    //init(userId: UserId, deviceId: String) async throws
    
    func save(events: [ClientEvent]) async throws
    
    func loadEvents(for roomId: RoomId, limit: Int, offset: Int?) async throws -> [ClientEvent]
    
    // FIXME: Add all the other function prototypes that got built out in the GRDBDataStore
}
