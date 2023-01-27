//
//  UIAuthSession.swift
//  Circles
//
//  Created by Charles Wright on 4/26/22.
//

import Foundation
import AnyCodable
import BlindSaltSpeke

@available(macOS 12.0, *)
public protocol UIASession {
    var url: URL { get }
    
    var state: UIAuthSession.State { get }
    
    var sessionId: String? { get }
    
    func connect() async throws
    
    func selectFlow(flow: UIAA.Flow) async
    
    func doUIAuthStage(auth: [String:Codable]) async throws
    
    func doTermsStage() async throws
    
}

public let AUTH_TYPE_ENROLL_BSSPEKE_OPRF = "m.enroll.bsspeke-ecc.oprf"
public let AUTH_TYPE_ENROLL_BSSPEKE_SAVE = "m.enroll.bsspeke-ecc.save"
public let AUTH_TYPE_TERMS = "m.login.terms"
public let AUTH_TYPE_ENROLL_PASSWORD = "m.enroll.password"
public let AUTH_TYPE_DUMMY = "m.login.dummy"
public let AUTH_TYPE_ENROLL_EMAIL_REQUEST_TOKEN = "m.enroll.email.request_token"
public let AUTH_TYPE_ENROLL_EMAIL_SUBMIT_TOKEN = "m.enroll.email.submit_token"

public let AUTH_TYPE_LOGIN_PASSWORD = "m.login.password"
public let AUTH_TYPE_LOGIN_BSSPEKE_OPRF = "m.login.bsspeke-ecc.oprf"
public let AUTH_TYPE_LOGIN_BSSPEKE_VERIFY = "m.login.bsspeke-ecc.verify"
public let AUTH_TYPE_LOGIN_EMAIL_REQUEST_TOKEN = "m.login.email.request_token"
public let AUTH_TYPE_LOGIN_EMAIL_SUBMIT_TOKEN = "m.login.email.submit_token"

@available(macOS 12.0, *)
public class UIAuthSession: UIASession, ObservableObject {
        
    public enum State {
        case notConnected
        case connected(UIAA.SessionState)
        case inProgress(UIAA.SessionState,[String])
        case finished(Matrix.Credentials)
    }
    
    public let url: URL
    public let method: String
    //public let accessToken: String? // FIXME: Make this MatrixCredentials ???
    public let creds: Matrix.Credentials?
    @Published public var state: State
    public var realRequestDict: [String:AnyCodable] // The JSON fields for the "real" request behind the UIA protection
    public var storage = [String: Any]() // For holding onto data between requests, like we do on the server side
    
    // Shortcut to get around a bunch of `case let` nonsense everywhere
    public var sessionState: UIAA.SessionState? {
        switch state {
        case .connected(let sessionState):
            return sessionState
        case .inProgress(let sessionState, _):
            return sessionState
        default:
            return nil
        }
    }
        
    public init(method: String, url: URL, credentials: Matrix.Credentials? = nil, requestDict: [String:AnyCodable]) {
        self.method = method
        self.url = url
        //self.accessToken = accessToken
        self.creds = credentials
        self.state = .notConnected
        self.realRequestDict = requestDict
        
        /*
        let initTask = Task {
            try await self.initialize()
        }
        */
    }
    
    public var sessionId: String? {
        switch state {
        case .inProgress(let (uiaaState, selectedFlow)):
            return uiaaState.session
        default:
            return nil
        }
    }
    
    public func _checkBasicSanity(userInput: String) -> Bool {
        if userInput.contains(" ")
            || userInput.contains("\"")
            || userInput.isEmpty
        {
            return false
        }
        return true
    }
    
    public func _looksLikeValidEmail(userInput: String) -> Bool {
        if !_checkBasicSanity(userInput: userInput) {
            return false
        }
        if !userInput.contains("@")
            || userInput.hasPrefix("@") // Must have a user part before the @
            || userInput.hasSuffix("@") // Must have a domain part after the @
            || !userInput.contains(".") // Must have a dot somewhere
        {
            return false
        }
        
        // OK now we can bring out the big guns
        // See https://multithreaded.stitchfix.com/blog/2016/11/02/email-validation-swift/
        // And Apple's documentation on the DataDetector
        // https://developer.apple.com/documentation/foundation/nsdatadetector
        guard let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else {
            return false
        }
        
        let range = NSMakeRange(0, NSString(string: userInput).length)
        let allMatches = dataDetector.matches(in: userInput,
                                              options: [],
                                              range: range)
        if allMatches.count == 1,
            allMatches.first?.url?.absoluteString.contains("mailto:") == true
        {
            return true
        }
        return false
    }
    
    public func connect() async throws {
        let tag = "UIA(init)"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken = self.creds?.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        let encoder = JSONEncoder()
        if url.path.contains("/register") {
            let emptyDict = [String:AnyCodable]()
            request.httpBody = try encoder.encode(emptyDict)
        }
        else {
            request.httpBody = try encoder.encode(self.realRequestDict)
            let requestBody = String(decoding: request.httpBody!, as: UTF8.self)
            print("\(tag)\t\(requestBody)")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("\(tag)\tTrying to parse the response")
        guard let httpResponse = response as? HTTPURLResponse else {
            let msg = "Couldn't decode HTTP response"
            print("\(tag)\t\(msg)")
            throw Matrix.Error(msg)
        }
        print("\(tag)\tParsed HTTP response")
        
        guard httpResponse.statusCode == 401 else {
            let msg = "Got unexpected HTTP response code (\(httpResponse.statusCode))"
            print("\(tag)\t\(msg)")
            throw Matrix.Error(msg)
        }
        
        print("Raw HTTP response:")
        let rawStringResponse = String(data: data, encoding: .utf8)!
        print(rawStringResponse)
        
        let decoder = JSONDecoder()
        //decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        guard let sessionState = try? decoder.decode(UIAA.SessionState.self, from: data) else {
            let msg = "Couldn't decode response"
            print("\(tag)\t\(msg)")
            throw Matrix.Error(msg)
        }
        print("\(tag)\tGot a new UIA session")
        
        //self.state = .inProgress(sessionState)
        await MainActor.run {
            self.state = .connected(sessionState)
        }
    }
    
    public func selectFlow(flow: UIAA.Flow) async {
        guard case .connected(let uiaState) = state else {
            // throw some error
            return
        }
        guard uiaState.flows.contains(flow) else {
            // throw some error
            return
        }
        await MainActor.run {
            self.state = .inProgress(uiaState, flow.stages)
        }
    }
    
    public func doDummyAuthStage() async throws {
        let authDict = [
            "type": AUTH_TYPE_DUMMY
        ]
        
        try await doUIAuthStage(auth: authDict)
    }
    
    public func doPasswordAuthStage(password: String) async throws {

        // Added base64 encoding here to prevent a possible injection attack on the password field
        let base64Password = Data(password.utf8).base64EncodedString()

        let passwordAuthDict: [String: String] = [
            "type": AUTH_TYPE_LOGIN_PASSWORD,
            "password": base64Password,
        ]
        
        try await doUIAuthStage(auth: passwordAuthDict)
    }
    
    public func doPasswordEnrollStage(newPassword: String) async throws {
        let base64Password = Data(newPassword.utf8).base64EncodedString()

        let passwordAuthDict: [String: String] = [
            "type": AUTH_TYPE_ENROLL_PASSWORD,
            "new_password": base64Password,
        ]
        
        try await doUIAuthStage(auth: passwordAuthDict)
    }

    
    public func doTermsStage() async throws {
        let auth: [String: String] = [
            "type": AUTH_TYPE_TERMS,
        ]
        try await doUIAuthStage(auth: auth)
    }
    
    // FIXME: We need some way to know if this succeeded or failed
    public func doUIAuthStage(auth: [String:Codable]) async throws {
        guard let AUTH_TYPE = auth["type"] as? String else {
            print("No auth type")
            return
        }
        let tag = "UIA(\(AUTH_TYPE))"
        
        print("\(tag)\tValidating")
        
        guard case .inProgress(let uiaState, let stages) = state else {
            let msg = "Signup session must be started before attempting stages"
            print("\(tag)\t\(msg)")
            throw Matrix.Error(msg)
        }
        
        // Check to make sure that AUTH_TYPE is the next one in our list of stages???
        guard stages.first == AUTH_TYPE
        else {
            let msg = "Attempted stage \(AUTH_TYPE) but next required stage is [\(stages.first ?? "none")]"
            print("\(tag)\t\(msg)")
            throw Matrix.Error("Incorrect next stage: \(AUTH_TYPE)")
        }
        
        print("\(tag)\tStarting")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // We want to be generic: Handle both kinds of use cases: (1) signup (no access token) and (2) re-auth (already have an access token, but need to re-verify identity)
        if let accessToken = self.creds?.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        var requestBodyDict: [String: AnyCodable] = self.realRequestDict
        // Doh!  The caller doesn't need to care about the session id,
        // so it does not include "session" in its auth dict.
        // Therefore we have to include it before we send the request.
        var authWithSessionId = auth
        authWithSessionId["session"] = uiaState.session
        requestBodyDict["auth"] = AnyCodable(authWithSessionId)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBodyDict)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("\(tag)\tGot response")
        let stringResponse = String(data: data, encoding: .utf8)!
        print(stringResponse)
        
        guard let httpResponse = response as? HTTPURLResponse
        else {
            let msg = "Couldn't decode UI auth stage response"
            print("\(tag)\tError: \(msg)")
            throw Matrix.Error(msg)
        }
        
        guard [200,401].contains(httpResponse.statusCode)
        else {
            let msg = "UI auth stage failed"
            print("\(tag)\tError: \(msg)")
            print("\(tag)\tStatus Code: \(httpResponse.statusCode)")
            print("\(tag)\tRaw response: \(stringResponse)")
            throw Matrix.Error(msg)
        }
        
        if httpResponse.statusCode == 200 {
            print("\(tag)\tAll done!")
            let decoder = JSONDecoder()
            
            guard let newCreds = try? decoder.decode(Matrix.Credentials.self, from: data)
            else {
                let msg = "Couldn't decode Matrix credentials"
                print("\(tag)\tError: \(msg)")
                throw Matrix.Error(msg)
            }
            await MainActor.run {
                state = .finished(newCreds)
            }
            return
        }
        
        let decoder = JSONDecoder()
        guard let newUiaaState = try? decoder.decode(UIAA.SessionState.self, from: data)
        else {
            let msg = "Couldn't decode UIA response"
            print("\(tag)\tError: \(msg)")
            let rawDataString = String(data: data, encoding: .utf8)!
            print("\(tag)\tRaw response:\n\(rawDataString)")
            throw Matrix.Error(msg)
        }
        
        if let completed = newUiaaState.completed {
            if completed.contains(AUTH_TYPE) {
                print("\(tag)\tComplete")
                let newStages: [String] = Array(stages.suffix(from: 1))
                await MainActor.run {
                    state = .inProgress(newUiaaState,newStages)
                }
                print("New UIA state:")
                print("\tFlows:\t\(newUiaaState.flows)")
                print("\tCompleted:\t\(completed)")
                if let params = newUiaaState.params {
                    print("\tParams:\t\(params)")
                }

            } else {
                print("\(tag)\tStage isn't complete???  Completed = \(completed)")
            }
        } else {
            print("\(tag)\tNo completed stages :(")
        }
        
    }

    // MARK: BS-SPEKE protocol support
    
    // NOTE: The ..OPRF.. functions are *almost* but not exactly duplicates of those in the SignupSession and LoginSession.
    //       The SignupSession needs a userId:password: version of the Enroll OPRF,
    //       because it isn't logged in with a userId yet.
    //       Below, the Login OPRF has the same thing for the LoginSession.
    //       The "normal" UIAuthSession should always use the simple password: version when already logged in.
    public func doBSSpekeEnrollOprfStage(password: String) async throws {
        guard let userId = self.creds?.userId else {
            let msg = "Couldn't find user id for BS-SPEKE enrollment"
            print(msg)
            throw Matrix.Error(msg)
        }
        try await self.doBSSpekeEnrollOprfStage(userId: userId, password: password)
    }
    
    public func doBSSpekeEnrollOprfStage(userId: UserId, password: String) async throws {

        let stage = AUTH_TYPE_ENROLL_BSSPEKE_OPRF
        
        // Make sure that nobody is up to any shenanigans, calling this with a fake userId when already logged in
        if let creds = self.creds {
            guard userId == creds.userId else {
                throw Matrix.Error("BS-SPEKE: Can't enroll for a new user id while already logged in")
            }
        }
        
        guard let homeserver = self.url.host,
              homeserver.hasSuffix(userId.domain)
        else {
            throw Matrix.Error("Homeserver [\(self.url.host ?? "(none)")] does not match requested domain [\(userId.domain)]")
        }
        
        let bss = try BlindSaltSpeke.ClientSession(clientId: "\(userId)", serverId: userId.domain, password: password)
        let blind = bss.generateBlind()
        let args: [String: String] = [
            "type": stage,
            "blind": Data(blind).base64EncodedString(),
            "curve": "curve25519",
        ]
        self.storage[stage+".state"] = bss
        try await doUIAuthStage(auth: args)
    }
    
    public func b64decode(_ str: String) -> [UInt8]? {
        guard let data = Data(base64Encoded: str) else {
            return nil
        }
        let array = [UInt8](data)
        return array
    }
    
    // OK this one *is* exactly the same as in SignupSession
    public func doBSSpekeEnrollSaveStage() async throws {
        // Need to send
        // V, our long-term public key (from "verifier"?  Although here the actual verifiers are hashes.)
        // P, our base point on the curve
        let stage = AUTH_TYPE_ENROLL_BSSPEKE_SAVE
        
        guard let bss = self.storage[AUTH_TYPE_ENROLL_BSSPEKE_OPRF+".state"] as? BlindSaltSpeke.ClientSession
        else {
            let msg = "Couldn't find saved BS-SPEKE session"
            print("BS-SPEKE\tError: \(msg)")
            throw Matrix.Error(msg)
        }
        guard let oprfParams = self.sessionState?.params?[AUTH_TYPE_ENROLL_BSSPEKE_OPRF] as? BSSpekeOprfParams,
              let params = self.sessionState?.params?[stage] as? BSSpekeEnrollParams
        else {
            let msg = "Couldn't find BS-SPEKE enroll params"
            print("BS-SPEKE\t\(msg)")
            throw Matrix.Error(msg)
        }
        guard let blindSalt = b64decode(params.blindSalt)
        else {
            let msg = "Failed to decode base64 blind salt"
            print("BS-SPEKE\t\(msg)")
            throw Matrix.Error(msg)
        }
        let blocks = [100_000, oprfParams.phfParams.blocks].max()!
        let iterations = [3, oprfParams.phfParams.iterations].max()!
        let phfParams = BSSpekeOprfParams.PHFParams(name: "argon2i",
                                                    iterations: iterations,
                                                    blocks: blocks)

        guard let (P,V) = try? bss.generatePandV(blindSalt: blindSalt, phfBlocks: UInt32(blocks), phfIterations: UInt32(iterations))
        else {
            let msg = "Failed to generate public key"
            print("BS-SPEKE\t\(msg)")
            throw Matrix.Error(msg)
        }
        
        let args: [String: Codable] = [
            "type": stage,
            "P": Data(P).base64EncodedString(),
            "V": Data(V).base64EncodedString(),
            "phf_params": phfParams,
        ]
        try await doUIAuthStage(auth: args)
    }
    
    // NOTE: Just as the SignupSession needs a userId:password: version of the Enroll OPRF,
    //       here we also need a userId:password: version of the Login OPRF for the LoginSession.
    //       The "normal" UIAuthSession should always use the simple password: version when already logged in.
    public func doBSSpekeLoginOprfStage(password: String) async throws {
        guard let userId = self.creds?.userId
        else {
            let msg = "Couldn't find user id for BS-SPEKE login"
            print(msg)
            throw Matrix.Error(msg)
        }
        try await self.doBSSpekeLoginOprfStage(userId: userId, password: password)
    }
    
    public func doBSSpekeLoginOprfStage(userId: UserId, password: String) async throws {
        let stage = AUTH_TYPE_LOGIN_BSSPEKE_OPRF
        
        // Make sure that nobody is up to any shenanigans, calling this with a fake userId when already logged in
        if let creds = self.creds {
            guard userId == creds.userId else {
                throw Matrix.Error("BS-SPEKE: Can't authenticate with a different user id while already logged in")
            }
        }
        
        let bss = try BlindSaltSpeke.ClientSession(clientId: "\(userId)", serverId: userId.domain, password: password)
        let blind = bss.generateBlind()
        let args: [String: String] = [
            "type": stage,
            "blind": Data(blind).base64EncodedString(),
            "curve": "curve25519",
        ]
        self.storage[stage+".state"] = bss
        try await doUIAuthStage(auth: args)
    }
    
    
    
    public func doBSSpekeLoginVerifyStage() async throws {
        // Need to send
        // V, our long-term public key (from "verifier"?  Although here the actual verifiers are hashes.)
        // P, our base point on the curve
        let stage = AUTH_TYPE_LOGIN_BSSPEKE_VERIFY
        
        guard let bss = self.storage[AUTH_TYPE_LOGIN_BSSPEKE_OPRF+".state"] as? BlindSaltSpeke.ClientSession
        else {
            let msg = "Couldn't find saved BS-SPEKE session"
            print("BS-SPEKE\tError: \(msg)")
            throw Matrix.Error(msg)
        }
        
        guard let oprfParams = self.sessionState?.params?[AUTH_TYPE_LOGIN_BSSPEKE_OPRF] as? BSSpekeOprfParams,
              let params = self.sessionState?.params?[stage] as? BSSpekeVerifyParams
        else {
            let msg = "Couldn't find BS-SPEKE enroll params"
            print("BS-SPEKE\t\(msg)")
            throw Matrix.Error(msg)
        }
        
        guard let B = b64decode(params.B)
        else {
            let msg = "Failed to decode base64 server public key B"
            print("BS-SPEKE\t\(msg)")
            throw Matrix.Error(msg)
        }
        guard let blindSalt = b64decode(params.blindSalt)
        else {
            let msg = "Failed to decode base64 blind salt"
            print("BS-SPEKE\t\(msg)")
            throw Matrix.Error(msg)
        }
        
        let blocks = oprfParams.phfParams.blocks
        let iterations = oprfParams.phfParams.iterations
        guard blocks >= 100_000,
              iterations >= 3
        else {
            let msg = "PHF parameters from the server are below minimum values. Possible attack detected."
            print("BS-SPEKE\t\(msg)")
            throw Matrix.Error(msg)
        }
        
        let A = try bss.generateA(blindSalt: blindSalt, phfBlocks: UInt32(blocks), phfIterations: UInt32(iterations))
        bss.deriveSharedKey(serverPubkey: B)
        let verifier = bss.generateVerifier()
        
        let args: [String: String] = [
            "type": stage,
            "A": Data(A).base64EncodedString(),
            "verifier": Data(verifier).base64EncodedString(),
        ]
        print("BS-SPEKE: About to send args \(args)")
        
        try await doUIAuthStage(auth: args)
    }
    
}
