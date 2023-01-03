//
//  RoomEncryptionContent.swift
//
//
//  Created by Charles Wright on 5/18/22.
//

import Foundation

/// m.room.encryption: https://spec.matrix.org/v1.5/client-server-api/#mroomencryption
struct RoomEncryptionContent: Codable {
    enum Algorithm: String, Codable {
        case megolmV1AesSha2 = "m.megolm.v1.aes-sha2"
    }
    let algorithm: Algorithm
    let rotationPeriodMs: Int
    let rotationPeriodMsgs: Int
    
    init() {
        algorithm = .megolmV1AesSha2
        rotationPeriodMs = 604800000  // FIXME: Does it really make sense to rotate this frequently?  We're just going to store all the keys on the server anyway, protected by a single symmetric backup key.  WTF?
        rotationPeriodMsgs = 100
    }
    
    enum CodingKeys: String, CodingKey {
        case algorithm
        case rotationPeriodMs = "rotation_period_ms"
        case rotationPeriodMsgs = "rotation_period_msgs"
    }
}
