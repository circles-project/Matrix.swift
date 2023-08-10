//
//  Base64.swift
//  
//
//  Created by Charles Wright on 8/10/23.
//

import Foundation

extension Matrix {
    public enum Base64 {

        public static func ensurePadding(_ encoded: String) -> String? {
            /* YOLO
            guard encoded.allSatisfy({c in
                "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=".contains(c)
            })
            else {
                logger.error("Can't base64-pad a non-base64 string")
                return nil
            }
            */
            
            if encoded.count % 4 == 0 {
                return encoded
            }
            
            let padLength = 4 - encoded.count % 4
            
            return encoded + String(repeating: "=", count: padLength)
        }
        
        public static func removePadding(_ padded: String) -> String? {
            /* YOLO
            guard padded.allSatisfy({c in
                "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=".contains(c)
            })
            else {
                logger.error("Can't remove base64 pading from a non-base64 string")
                return nil
            }
            */
            
            return padded.trimmingCharacters(in: CharacterSet(["="]))
        }
        
        public static func unpadded(_ data: Data) -> String? {
            removePadding(data.base64EncodedString())
        }
        
        public static func unpadded(_ array: [UInt8]) -> String? {
            removePadding(Data(array).base64EncodedString())
        }
        
        public static func data(_ encoded: String, urlSafe: Bool=false) -> Data? {
            guard let padded = ensurePadding(encoded)
            else {
                logger.error("Can't base64 decode a non-base64 string")
                return nil
            }
            if urlSafe {
                let translated = padded.replacingOccurrences(of: "_", with: "/")
                                       .replacingOccurrences(of: "-", with: "+")
                return Data(base64Encoded: translated)
            } else {
                return Data(base64Encoded: padded)
            }
        }

    }
}
