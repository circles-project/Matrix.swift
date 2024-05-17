//
//  File.swift
//  
//
//  Created by Michael Hollister on 5/16/24.
//

import Foundation
import Base58Swift

// Implementation taken from https://gitlab.futo.org/circles/matrix-android-sdk/-/blob/main/matrix-sdk-android/src/main/java/org/matrix/android/sdk/api/session/crypto/keysbackup/RecoveryKey.kt?ref_type=heads

extension Matrix.KeyBackup {
    public struct RecoveryKey {
        private static let CHAR_0 = UInt8(0x8B)
        private static let CHAR_1 = UInt8(0x01)

        private static let RECOVERY_KEY_LENGTH = 2 + 32 + 1
        
        /**
         * Tell if the format of the recovery key is correct.
         *
         * @param recoveryKey
         * @return true if the format of the recovery key is correct
         */
        public static func isValidRecoveryKey(recoveryKey: String?) -> Bool {
            return extractCurveKeyFromRecoveryKey(recoveryKey: recoveryKey) != nil
        }

        /**
         * Compute recovery key from curve25519 key.
         *
         * @param curve25519Key
         * @return the recovery key
         */
        public static func computeRecoveryKey(curve25519Key: [UInt8]) -> String {
            // Append header and parity
            var data = [UInt8](repeating: 0, count: curve25519Key.count + 3)
            
            // Header
            data[0] = CHAR_0
            data[1] = CHAR_1

            // Copy key and compute parity
            var parity = CHAR_0 ^ CHAR_1

            for i in curve25519Key.indices {
                data[i + 2] = curve25519Key[i]
                parity = parity ^ curve25519Key[i]
            }

            // Parity
            data[curve25519Key.count + 2] = parity

            // Do not add white space every 4 chars, it's up to the presenter to do it
            return Base58.base58Encode(data)
        }

        /**
         * Please call [.isValidRecoveryKey] and ensure it returns true before calling this method.
         *
         * @param recoveryKey the recovery key
         * @return curveKey, or null in case of error
         */
        public static func extractCurveKeyFromRecoveryKey(recoveryKey: String?) -> [UInt8]? {
            guard let recoveryKey = recoveryKey
            else {
                return nil
            }

            // Remove any space
            let spaceFreeRecoveryKey = recoveryKey.replacingOccurrences(of: " ", with: "")

            guard let b58DecodedKey = Base58.base58Decode(spaceFreeRecoveryKey)
            else {
                return nil
            }

            // Check length
            if (b58DecodedKey.count != RECOVERY_KEY_LENGTH) {
                return nil
            }

            // Check first byte
            if (b58DecodedKey[0] != CHAR_0) {
                return nil
            }

            // Check second byte
            if (b58DecodedKey[1] != CHAR_1) {
                return nil
            }

            // Check parity
            var parity = UInt8(0x00)

            for i in 0 ..< RECOVERY_KEY_LENGTH {
                parity = parity ^ b58DecodedKey[i]
            }

            if (parity != UInt8(0x00)) {
                return nil
            }

            // Remove header and parity bytes
            var result = [UInt8](repeating: 0, count: b58DecodedKey.count - 3)

            for i in 2 ..< b58DecodedKey.count - 1 {
                result[i - 2] = b58DecodedKey[i]
            }

            return result
        }
    }
}
