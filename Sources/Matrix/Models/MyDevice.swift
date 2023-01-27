//
//  MatrixMyDevice.swift
//  Circles
//
//  Created by Charles Wright on 6/23/22.
//

import Foundation

extension Matrix {
    
    public class MyDevice: ObservableObject {
        //public var matrix: MatrixAPI
        public var deviceId: String
        @Published public var displayName: String?
        @Published public var lastSeenIp: String?
        @Published public var lastSeenTs: Date?
        
        public init(/*matrix: MatrixAPI,*/ deviceId: String, displayName: String? = nil, lastSeenIp: String? = nil, lastSeenUnixMs: Int? = nil) {
            //self.matrix = matrix
            self.deviceId = deviceId
            self.displayName = displayName
            self.lastSeenIp = lastSeenIp
            if let unixMs = lastSeenUnixMs {
                let interval = TimeInterval(1000 * unixMs)
                self.lastSeenTs = Date(timeIntervalSince1970: interval)
            }
        }
    }

}
