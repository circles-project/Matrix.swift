//
//  Identifiers+random.swift
//  
//
//  Created by Charles Wright on 3/1/23.
//

import Foundation
import Matrix

let usernames = ["alice", "bob", "carol", "dave", "ethan", "flora", "gloria", "henry", "isaac", "joe", "katherine", "lanie", "maggie", "nolan", "opal", "penelope", "quentin", "rashika", "shelley", "tomas", "uma", "viola", "wade", "xander", "yuna", "zoe"]
let domains = ["example.com", "example.org", "example.net", "example.us", "example.eu"]

func randomString(length: Int) -> String {
    if length < 1 {
        return ""
    }
    let alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    let characters = (0 ..< length).map { _ -> Character in
        alphabet.randomElement()!
    }
    return String(characters)
}

extension UserId {
    static func random() -> UserId {
        UserId("@\(usernames.randomElement()!):\(domains.randomElement()!)")!
    }
}

extension RoomId {
    static func random() -> RoomId {
        RoomId("!\(randomString(length: 12)):\(domains.randomElement()!)")!
    }
}

extension EventId {
    static func random() -> EventId {
        "$\(randomString(length: 48))"
    }
}
