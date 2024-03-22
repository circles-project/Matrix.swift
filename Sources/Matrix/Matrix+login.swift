//
//  Matrix+login.swift
//
//
//  Created by Charles Wright on 10/31/23.
//

import Foundation

extension Matrix {
    
    public struct LoginRequestBody: Codable {
        public struct Identifier: Codable {
            public let type: String
            public let user: String
        }
        public var identifier: Identifier
        public var type: String?
        public var password: String?
        public var token: String?
        public var deviceId: String?
        public var initialDeviceDisplayName: String?
        public var refreshToken: Bool?
        
        public enum CodingKeys: String, CodingKey {
            case identifier
            case type
            case password
            case token
            case deviceId = "device_id"
            case initialDeviceDisplayName = "initial_device_display_name"
            case refreshToken = "refresh_token"
        }
        
        init(userId: UserId,
             password: String,
             deviceId: String? = nil,
             initialDeviceDisplayName: String? = nil,
             refreshToken: Bool? = nil
        ) {
            self.identifier = .init(type: "m.id.user", user: userId.stringValue)
            self.type = M_LOGIN_PASSWORD
            self.password = password
            self.deviceId = deviceId
            self.initialDeviceDisplayName = initialDeviceDisplayName
            self.refreshToken = refreshToken
        }
    }
    
    struct StandardLoginFlow: Codable {
        var type: String
    }
    
  
    
    // This thing may contain a mix of old/standard Matrix flows and UIA flows
    struct GetLoginResponseBody: Decodable {
        var uiaFlows: [UIAA.Flow]
        var oldFlows: [StandardLoginFlow]
        
        enum CodingKeys: String, CodingKey {
            case flows
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // First let's see which of the flows are decodable as UIA flows
            let lossyUIA = try container.decode(LossyCodableList<UIAA.Flow>.self, forKey: .flows)
            self.uiaFlows = lossyUIA.elements
            
            // Next let's see which of the flows are decodable as standard/old/legacy Matrix flows
            let lossyOld = try container.decode(LossyCodableList<StandardLoginFlow>.self, forKey: .flows)
            self.oldFlows = lossyOld.elements
        }
        
    }
    
    
    // MARK: Check for UIA login
    
    public static func checkForUiaLogin(homeserver: URL) async throws -> Bool {
        let urlPath = "/_matrix/client/v3/login"
        
        guard let url = URL(string: urlPath, relativeTo: homeserver) else {
            Matrix.logger.error("Couldn't construct /login URL")
            throw Matrix.Error("Couldn't construct /login URL")
        }
        Matrix.logger.debug("Checking for UIA login at \(url)")
        
        // Query the supported login types
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse
        else {
            Matrix.logger.error("Invalid URL response for GET \(url)")
            throw Matrix.Error("Invalid URL response")
        }
        Matrix.logger.debug("GET \(url) got response with status \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200
        else {
            Matrix.logger.error("Failed to get supported login flows")
            throw Matrix.Error("Failed to get supported login flows")
        }
        
        let decoder = JSONDecoder()
        
        // Does this server support UIA for /login ?
        guard let responseBody = try? decoder.decode(GetLoginResponseBody.self, from: data)
        else {
            Matrix.logger.error("Failed to parse GET /login response")
            throw Matrix.Error("Failed to parse GET /login response")
        }
        
        Matrix.logger.debug("GET /login response includes \(responseBody.uiaFlows.count) UIA flows and \(responseBody.oldFlows.count) legacy Matrix flows")
        
        if responseBody.uiaFlows.count > 0 {
            return true
        } else {
            Matrix.logger.debug("GET /login response does not support UIA")
            return false
        }
        
    }
    
    // MARK: Login
    
    // Matrix standard, non-UIA login
    public static func login(userId: UserId,
                             password: String,
                             deviceId: String? = nil,
                             initialDeviceDisplayName: String? = nil,
                             refreshToken: Bool? = nil
    ) async throws -> Credentials {
        let wellKnown = try await Matrix.fetchWellKnown(for: userId.domain)
        
        guard let server = URL(string: wellKnown.homeserver.baseUrl)
        else {
            Matrix.logger.error("Failed to look up well-known homeserver for domain \(userId.domain)")
            throw Matrix.Error("Failed to look up well-known")
        }
        
        let urlPath = "/_matrix/client/v3/login"
        
        guard let url = URL(string: urlPath, relativeTo: server) else {
            Matrix.logger.error("Couldn't construct /login URL")
            throw Matrix.Error("Couldn't construct /login URL")
        }
        
        let requestBody = LoginRequestBody(userId: userId,
                                           password: password,
                                           deviceId: deviceId,
                                           initialDeviceDisplayName: initialDeviceDisplayName,
                                           refreshToken: refreshToken)
        var encoder = JSONEncoder()
        guard let requestData = try? encoder.encode(requestBody)
        else {
            Matrix.logger.error("Failed to encode /login request")
            throw Matrix.Error("Failed to encode /login request")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse
        else {
            Matrix.logger.error("Invalid login response")
            throw Matrix.Error("Invalid login response")
        }
        
        guard httpResponse.statusCode == 200
        else {
            Matrix.logger.error("Login request failed - Got HTTP \(httpResponse.statusCode)")
            
            let decoder = JSONDecoder()
            if let err = try? decoder.decode(ErrorResponse.self, from: data) {
                Matrix.logger.error("Login got errcode = \(err.errcode)   error = \(err.error ?? "(none)")")
            }
            
            throw Matrix.Error("Login request failed")
        }
        Matrix.logger.debug("Login request success.  Decoding login response...")
        
        let decoder = JSONDecoder()
        guard let creds = try? decoder.decode(Credentials.self, from: data)
        else {
            Matrix.logger.error("Failed to decode login credentials from the server")
            throw Matrix.Error("Failed to decode login credentials")
        }
        Matrix.logger.debug("Login succeeded - Got userId \(creds.userId)")
        
        return creds
    }
    
}
