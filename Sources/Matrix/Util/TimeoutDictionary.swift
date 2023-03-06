//
//  TimeoutDictionary.swift
//  
//
//  Created by Charles Wright on 12/6/22.
//

import Foundation

class TimeoutDictionary<K,V> where K: Hashable {
    let timeout: TimeInterval
    var timestamp: Date
    var storage: [K:(Date,V)]
    
    init(timeout: TimeInterval) {
        self.timeout = timeout
        self.timestamp = Date()
        self.storage = [K:(Date,V)]()
    }
    
    subscript(index: K) -> V? {
        get {
            if let (ts, v) = storage[index] {
                let now = Date()
                if now.timeIntervalSince(ts) < timeout {
                    return v
                } else {
                    // Our entry has timed out.  Remove it.
                    storage.removeValue(forKey: index)
                    
                    // Actually *all* entries have timed out.  Start over.
                    if now.timeIntervalSince(timestamp) > timeout {
                        storage.removeAll()
                    }
                }
            }
            return nil
        }
        
        set(newValue) {
            if let v = newValue {
                let now = Date()
                storage[index] = (now, v)
                timestamp = now
            } else {
                storage[index] = nil
            }
        }
    }
}
