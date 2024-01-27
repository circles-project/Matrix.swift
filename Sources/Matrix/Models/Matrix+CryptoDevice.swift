//
//  Matrix+CryptoDevice.swift
//
//
//  Created by Charles Wright on 1/27/24.
//

import Foundation
import MatrixSDKCrypto

extension MatrixSDKCrypto.Device: Identifiable {
    public var id: String {
        deviceId
    }
}

extension Matrix {
    public typealias CryptoDevice = MatrixSDKCrypto.Device
}
