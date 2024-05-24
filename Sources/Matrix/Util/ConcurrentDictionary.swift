//
//  ConcurrentDictionary.swift
//
//
//  Created by Charles Wright on 3/31/21.
//
import Foundation

// SynchronizedDictionary
// A Dictionary that uses a DispatchQueue to synchronize access.
// Can handle multiple readers in parallel, as long as there are
// no writers.
//public struct SynchronizedDictionary<Key, Value> where Key : Hashable {
public struct DispatchQueueDictionary<Key, Value> where Key: Hashable {
    private var dict: [Key:Value]
    private var queue: DispatchQueue
    
    init() {
        self.dict = [:]
        self.queue = DispatchQueue(label: "synchronized dict", qos: .default, attributes: .concurrent)
    }
    
    subscript(index: Key) -> Value? {
        get {
            var result: Value?
            self.queue.sync {
            result = self.dict[index]
            }
            return result
        }
        
        set(newValue) {
            self.queue.sync(flags: .barrier) {
                self.dict[index] = newValue
            }
        }
    }
    
}

// ConcurrentDictionary
// A synchronized dictionary that can be accessed by more than one
// writer at a time.  Built using a hash table of n "buckets", ie
// SynchronizedDictionary structs.  Access to a key only blocks if
// there is already a writer writing to the same bucket.
public struct ConcurrentDictionary<Key, Value> where Key : Hashable {
    //private var buckets: [SynchronizedDictionary<Key,Value>]
    private var buckets: [DispatchQueueDictionary<Key,Value>]
    
    init(n: Int = 1) {
        self.buckets = []
        for _ in 0 ..< n {
            //self.buckets.append( SynchronizedDictionary<Key,Value>() )
            self.buckets.append( DispatchQueueDictionary<Key,Value>() )
        }
    }
    
    subscript(index: Key) -> Value? {
        get {
            let b = abs(index.hashValue) % buckets.count
            return buckets[b][index]
        }
        
        set(newValue) {
            let b = abs(index.hashValue) % buckets.count
            buckets[b][index] = newValue
        }
    }

}

public actor ActorDictionary<Key,Value> where Key: Hashable {
    private var dict: [Key:Value]
    
    init() {
        self.dict = [:]
    }
    
    subscript(index: Key) -> Value? {
        get {
            self.dict[index]
        }
        
        set(newValue) {
            self.dict[index] = newValue
        }
    }
    
    func set(_ index: Key, _ newValue: Value) async {
        self.dict[index] = newValue
    }
}

public struct ShardedActorDictionary<Key, Value> where Key: Hashable {
    private var buckets: [ActorDictionary<Key,Value>]
    
    init(n: Int = 64) {
        self.buckets = []
        for _ in 0 ..< n {
            self.buckets.append( ActorDictionary<Key,Value>() )
        }
    }
    
    func get(_ index: Key) async  -> Value? {
        let b = abs(index.hashValue) % buckets.count
        return await buckets[b][index]
    }
        
    func set(_ index: Key, _ newValue: Value) async {
        let b = abs(index.hashValue) % buckets.count
        await buckets[b].set(index, newValue)
    }
}
