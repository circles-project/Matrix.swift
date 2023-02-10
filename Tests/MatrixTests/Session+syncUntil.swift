//
//  File.swift
//  
//
//  Created by Charles Wright on 2/7/23.
//

import Foundation

import Matrix

extension Matrix.Session {
    
    func syncUntil(_ f: () -> Bool, maxTries: Int = 10) async throws -> Bool {
        var tries: Int = 0
        while maxTries == 0 || tries < maxTries {
            tries += 1
            print("Syncing - Try #\(tries)")
            guard let token = try await self.sync()
            else {
                print("\tSync #\(tries) failed")
                continue
            }
            print("\tSync #\(tries) completed; Got new token \(token)")
            if f() {
                print("syncUntil: Condition satisfied.  Done syncing.")
                return true
            } else {
                print("syncUntil: Condition not satisfied.  Will continue to sync.")
            }
        }
        return false
    }
}
