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

let AUTH_TYPE_ENROLL_USERNAME = "m.enroll.username"
let AUTH_TYPE_REGISTRATION_TOKEN = "m.login.registration_token"
let AUTH_TYPE_APPLE_SUBSCRIPTION = "org.futo.subscriptions.apple"
let AUTH_TYPE_LEGACY_EMAIL = "m.login.email.identity"


class SignupSession: UIAuthSession {
    let domain: String
    //let deviceId: String?
    //let initialDeviceDisplayName: String?
    //let inhibitLogin = false

    init(domain: String,
         deviceId: String? = nil,
         initialDeviceDisplayName: String? = nil,
         //showMSISDN: Bool = false,
         inhibitLogin: Bool = false
    ) async throws {
        self.domain = domain
        
        let wellKnown = try await Matrix.fetchWellKnown(for: domain)
        guard let homeserverUrl = URL(string: wellKnown.homeserver.baseUrl),
              let signupURL = URL(string: "/_matrix/client/v3/register", relativeTo: homeserverUrl)
        else {
            throw Matrix.Error("Couldn't construct signup URL for domain [\(domain)]")
        }
        print("SIGNUP\tURL is \(signupURL)")
        var requestDict: [String: AnyCodable] = [:]

        if let d = deviceId {
            requestDict["device_id"] = AnyCodable(d)
        }
        if let iddn = initialDeviceDisplayName {
            requestDict["initial_device_display_name"] = AnyCodable(iddn)
        }
        //requestDict["x_show_msisdn"] = AnyCodable(showMSISDN)
        requestDict["inhibit_login"] = AnyCodable(inhibitLogin)
        super.init(method: "POST", url: signupURL, requestDict: requestDict)
    }
    
    // MARK: Set username and password
    
    func doUsernameStage(username: String) async throws {
        let authDict = [
            "type": AUTH_TYPE_ENROLL_USERNAME,
            "username": username,
        ]
        try await doUIAuthStage(auth: authDict)
        self.storage["username"] = username
    }
    
    // MARK: Token registration
    
    func doTokenRegistrationStage(token: String) async throws {
        
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
    
    // MARK: (New) Email stages
    
    func doEmailRequestTokenStage(email: String) async throws -> String? {

        guard _looksLikeValidEmail(userInput: email) == true
        else {
            let msg = "Invalid email address"
            print("Email signup Error: \(msg)")
            throw Matrix.Error(msg)
        }
        
        let clientSecretNumber = UInt64.random(in: 0 ..< UInt64.max)
        let clientSecret = String(format: "%016x", clientSecretNumber)
        
        let emailAuthDict: [String: String] = [
            "type": AUTH_TYPE_ENROLL_EMAIL_REQUEST_TOKEN,
            "email": email,
            "client_secret": clientSecret,
        ]
        
        // FIXME: We need to know if this succeeded or failed
        try await doUIAuthStage(auth: emailAuthDict)
        
        return clientSecret
    }
    
    func doEmailSubmitTokenStage(token: String, secret: String) async throws {
        let emailAuthDict: [String: String] = [
            "type": AUTH_TYPE_ENROLL_EMAIL_SUBMIT_TOKEN,
            "token": token,
            "client_secret": secret,
        ]
        try await doUIAuthStage(auth: emailAuthDict)
    }
    
    private func _canonicalize(_ username: String) -> String {
        let tmp = username.starts(with: "@") ? username : "@\(username)"
        let userId = tmp.contains(":") ? tmp : "\(tmp):\(self.domain)"
        return userId
    }
        
    // MARK: Apple Subscriptions
    
    func doAppleSubscriptionStage(receipt: String) async throws {
        let args = [
            "type": AUTH_TYPE_APPLE_SUBSCRIPTION,
            "receipt": receipt,
        ]
        try await doUIAuthStage(auth: args)
    }
    
    // MARK: Legacy email handling
    
    struct LegacyEmailRequestTokenResponse: Codable {
        var sid: String
        var submitUrl: URL?
    }
    
    func doLegacyEmailRequestToken(address: String) async throws -> LegacyEmailRequestTokenResponse {
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
    
    func doLegacyEmailValidateAddress(token: String, sid: String, url: URL) async throws -> Bool {
        
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

    func doLegacyEmailStage(emailSessionId: String) async throws {
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

