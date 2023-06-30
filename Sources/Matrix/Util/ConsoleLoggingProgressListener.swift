//
//  ConsoleLoggingProgressListener.swift
//  
//
//  Created by Charles Wright on 6/30/23.
//

import os
import Foundation
import MatrixSDKCrypto

class ConsoleLoggingProgressListener: MatrixSDKCrypto.ProgressListener {
    var logger: os.Logger
    var message: String
    
    init(logger: os.Logger, message: String) {
        self.logger = logger
        self.message = message
    }
    
    func onProgress(progress: Int32, total: Int32) {
        logger.debug("\(self.message): \(progress) / \(total)")
    }
    
}
