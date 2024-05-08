//
//  Matrix+Errors.swift
//
//
//  Created by Charles Wright on 11/21/23.
//

import Foundation

public protocol MatrixErrorResponseProtocol: Codable {
    var errcode: String { get }
    var error: String? { get }
}

extension Matrix {
    
    // MARK: Error Types
    
    public struct Error: LocalizedError {
        public var msg: String
        public var errorDescription: String?
        
        public init(_ msg: String) {
            self.msg = msg
            self.errorDescription = NSLocalizedString(msg, comment: msg)
        }
    }
    
    public struct ErrorResponse: MatrixErrorResponseProtocol {
        public var errcode: String
        public var error: String?
    }
    
    public struct ApiError: LocalizedError {
        public var status: Int
        public var response: ErrorResponse
        
        public init(status: Int, response: ErrorResponse) {
            self.status = status
            self.response = response
        }
    }
    
    public struct RateLimitError: Swift.Error, Codable {
        public var errcode: String
        public var error: String?
        public var retryAfterMs: UInt?
        
        public enum CodingKeys: String, CodingKey {
            case errcode
            case error
            case retryAfterMs = "retry_after_ms"
        }
    }
    
    public struct InvalidTokenError: Swift.Error, Codable {
        public var errcode: String
        public var error: String?
        public var softLogout: Bool?
        
        public enum CodingKeys: String, CodingKey {
            case errcode
            case error
            case softLogout = "soft_logout"
        }
    }
}
