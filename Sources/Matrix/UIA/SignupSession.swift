//
//  SignupSession.swift
//  Matrix.swift
//
//  Created by Charles Wright on 4/20/22.
//

import Foundation
import AnyCodable
import BlindSaltSpeke

// Implements the Matrix UI Auth for the Matrix /register endpoint
// https://spec.matrix.org/v1.2/client-server-api/#post_matrixclientv3register

public class SignupSession: UIAuthSession {
    //public let domain: String // Moved this into the storage
    //public let deviceId: String?
    //public let initialDeviceDisplayName: String?
    //public let inhibitLogin = false
    var logger = Matrix.logger
    
    public convenience init(domain: String,
                            username: String? = nil,
                            password: String? = nil,
                            deviceId: String? = nil,
                            initialDeviceDisplayName: String? = nil,
                            //showMSISDN: Bool = false,
                            inhibitLogin: Bool = false,
                            refreshToken: Bool? = nil,
                            completion: ((UIAuthSession,Data) async throws -> Void)? = nil,
                            cancellation: (() async -> Void)? = nil
    ) async throws {

        let wellKnown = try await Matrix.fetchWellKnown(for: domain)
        guard let homeserver = URL(string: wellKnown.homeserver.baseUrl)
        else {
            throw Matrix.Error("Couldn't look up homeserver URL for domain [\(domain)]")
        }

        try await self.init(domain: domain,
                            homeserver: homeserver,
                            username: username,
                            password: password,
                            deviceId: deviceId,
                            initialDeviceDisplayName: initialDeviceDisplayName,
                            inhibitLogin: inhibitLogin,
                            refreshToken: refreshToken,
                            completion: completion,
                            cancellation: cancellation)
    }


    public init(domain: String,
                homeserver: URL,
                username: String? = nil,
                password: String? = nil,
                deviceId: String? = nil,
                initialDeviceDisplayName: String? = nil,
                //showMSISDN: Bool = false,
                inhibitLogin: Bool = false,
                refreshToken: Bool? = nil,
                completion: ((UIAuthSession,Data) async throws -> Void)? = nil,
                cancellation: (() async -> Void)? = nil
    ) async throws {
        
        guard let signupURL = URL(string: "/_matrix/client/v3/register", relativeTo: homeserver)
        else {
            throw Matrix.Error("Couldn't construct signup URL for domain [\(domain)]")
        }
        print("SIGNUP\tURL is \(signupURL)")

        guard password == nil || (password != nil && username != nil)
        else {
            throw Matrix.Error("Can't signup with a password but no username")
        }

        var requestDict: [String: Codable] = [
            //x_show_msisdn": showMSISDN,
            "inhibit_login": inhibitLogin,
        ]
        
        if let username = username {
            requestDict["username"] = username
        }
        if let password = password {
            requestDict["password"] = password
        }
        if let deviceId = deviceId {
            requestDict["device_id"] = deviceId
        }
        if let initialDeviceDisplayName = initialDeviceDisplayName {
            requestDict["initial_device_display_name"] = initialDeviceDisplayName
        }
        if let refreshToken = refreshToken {
            requestDict["refresh_token"] = refreshToken
        }

        super.init(method: "POST", url: signupURL, requestDict: requestDict, completion: completion, cancellation: cancellation)
        
        self.storage["domain"] = domain
    }
    
    // MARK: Username
    
    public func doUsernameStage(username: String) async throws {
        
        logger.debug("Attempting \(AUTH_TYPE_ENROLL_USERNAME) with username = [\(username)]")
        
        // Now that we allow legacy Matrix-spec registration
        // with username & password in the real request body,
        // we have to sanity check that the caller is not trying
        // to mix & match the old style with the new.
        guard self.realRequestDict["username"] == nil
        else {
            logger.error("Can't do \(AUTH_TYPE_ENROLL_USERNAME) when we already have a username set")
            throw Matrix.Error("Can't do \(AUTH_TYPE_ENROLL_USERNAME) when we already have a username set")
        }
        
        let authDict = [
            "type": AUTH_TYPE_ENROLL_USERNAME,
            "username": username,
        ]
        try await doUIAuthStage(auth: authDict)
        logger.debug("Username stage was successful.  Storing username in the UIA session")
        self.storage["username"] = username
    }
    
    // MARK: Token registration
    
    public func doTokenRegistrationStage(token: String) async throws {
        
        guard _checkBasicSanity(userInput: token) == true
        else {
            let msg = "Invalid token"
            print("Token registration Error: \(msg)")
            throw Matrix.Error(msg)
        }
        
        let tokenAuthDict: [String: String] = [
            "type": AUTH_TYPE_REGISTRATION_TOKEN,
            "token": token,
        ]
        try await doUIAuthStage(auth: tokenAuthDict)
    }
    
    // MARK: Free subscription
    
    public func doFreeSubscriptionStage() async throws {
        let authDict = [
            "type": AUTH_TYPE_FREE_SUBSCRIPTION
        ]
        
        try await doUIAuthStage(auth: authDict)
    }
    
    
    // MARK: Legacy email handling
    
    public struct LegacyEmailRequestTokenResponse: Codable {
        public var sid: String
        public var submitUrl: URL?
    }
    
    public func doLegacyEmailRequestToken(address: String) async throws -> LegacyEmailRequestTokenResponse {
        let version = "r0"
        let url = URL(string: "https://\(url.host!)/_matrix/client/\(version)/register/email/requestToken")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        struct RequestBody: Codable {
            var clientSecret: String
            var email: String
            var sendAttempt: Int
        }
        guard let sessionId = self.sessionState?.session else {
            let msg = "Must have an active session before attempting email stage"
            print("LEGACY-EMAIL\t\(msg)")
            throw Matrix.Error(msg)
        }
        
        let requestBody = RequestBody(clientSecret: sessionId, email: address, sendAttempt: 1)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
          [200,401].contains(httpResponse.statusCode)
        else {
            let msg = "Email token request failed"
            print("LEGACY-EMAIL\tError: \(msg)")
            throw Matrix.Error(msg)
        }
        

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let responseBody = try? decoder.decode(LegacyEmailRequestTokenResponse.self, from: data)
        else {
            let msg = "Could not decode response from server"
            print("LEGACY-EMAIL\tError: \(msg)")
            throw Matrix.Error(msg)
        }
        
        // FIXME Why not just return the whole thing?
        // Don't we need both the sid and the url???
        // Or we could save them in our local storage in the session!
        return responseBody
    }
    
    public func doLegacyEmailValidateAddress(token: String, sid: String, url: URL) async throws -> Bool {
        
        guard let sessionId = self.sessionId else {
            let msg = "No active signup session"
            print("LEGACY-EMAIL\t\(msg)")
            throw Matrix.Error(msg)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let args = [
            "sid": sid,
            "client_secret": sessionId,
            "token": token,
        ]
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(args)
        
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
          [200,401].contains(httpResponse.statusCode)
        else {
            let msg = "Email token validation request failed"
            print("LEGACY-EMAIL\tError: \(msg)")
            throw Matrix.Error(msg)
        }
        
        struct SubmitTokenResponse: Codable {
            var success: Bool
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let contents = try? decoder.decode(SubmitTokenResponse.self, from: data) else {
            let msg = "Failed to decode response from server"
            print("LEGACY-EMAIL\t\(msg)")
            throw Matrix.Error(msg)
        }
        
        return contents.success
    }

    public func doLegacyEmailStage(emailSessionId: String) async throws {
        guard let sessionId = self.sessionId else {
            let msg = "No active signup session"
            print("LEGACY-EMAIL\t\(msg)")
            throw Matrix.Error(msg)
        }
        let auth: [String: Codable] = [
            "type": AUTH_TYPE_LEGACY_EMAIL,
            "threepid_creds": [
                "sid": emailSessionId,
                "client_secret": sessionId,
            ],
        ]
        
        try await doUIAuthStage(auth: auth)
    }
}

