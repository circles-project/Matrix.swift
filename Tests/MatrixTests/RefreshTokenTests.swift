//
//  RefreshTokenTests.swift
//  
//
//  Created by Charles Wright on 11/21/23.
//

import Foundation
import os

import XCTest
import Yams

//@testable import Matrix
// Not using @testable since we are validating public-facing API
import Matrix
import MatrixSDKCrypto

final class RefreshTokenTests: XCTestCase {
    
    let homeserver = URL(string: "https://matrix.us.circles-dev.net")!
    let domain = "us.circles-dev.net"
    
    var logger = os.Logger(subsystem: "RefreshTokenTests", category: "refresh")

    func registerNewUser(name: String,
                         password: String,
                         domain: String,
                         homeserver: URL
    ) async throws -> Matrix.Credentials {
                
        let supportedAuthTypes = [
            AUTH_TYPE_TERMS,
            AUTH_TYPE_DUMMY,
            AUTH_TYPE_ENROLL_USERNAME,
            AUTH_TYPE_ENROLL_BSSPEKE_OPRF,
            AUTH_TYPE_ENROLL_BSSPEKE_SAVE,
        ]
        
        let r = Int.random(in: 0...9999)
        let username = String(format: "\(name)_%04d", r)
        //logger.debug("Username: \(username)")
        //logger.debug("Password: \(password)")
        let session = try await SignupSession(domain: domain,
                                              homeserver: homeserver)
        try await session.connect()
        XCTAssertNotNil(session.sessionState)
        let uiaState = session.sessionState!
        
        
        let flows = uiaState.flows
        
        let maybeFlow = flows.filter(
            {
                for stage in $0.stages {
                    if !supportedAuthTypes.contains(stage) {
                        return false
                    }
                }
                return true
            }
        ).first
        XCTAssertNotNil(maybeFlow)
                
        let flow = maybeFlow!
        //logger.debug("Found a flow that we can do: ", flow.stages)
        await session.selectFlow(flow: flow)
        
        for stage in flow.stages {
            //logger.debug("Working on stage [\(stage)]")
            switch stage {
            case AUTH_TYPE_DUMMY:
                try await session.doDummyAuthStage()
            case AUTH_TYPE_TERMS:
                try await session.doTermsStage()
            case AUTH_TYPE_ENROLL_USERNAME:
                try await session.doUsernameStage(username: username)
            case AUTH_TYPE_ENROLL_BSSPEKE_OPRF:
                try await session.doBSSpekeEnrollOprfStage(userId: UserId("@\(username):\(domain)")!, password: password)
            case AUTH_TYPE_ENROLL_BSSPEKE_SAVE:
                try await session.doBSSpekeEnrollSaveStage()
            default:
                //logger.debug("Unknown stage [\(stage)]")
                throw "Unknown stage [\(stage)]"
            }
        }
        
        let decoder = JSONDecoder()
        guard case let .finished(data) = session.state,
              let creds = try? decoder.decode(Matrix.Credentials.self, from: data)
        else {
            throw "UIA is not finished"
        }
        
        //logger.debug("Got credentials:")
        //logger.debug("\tUser id: \(creds.userId)")
        //logger.debug("\tDevice id: \(creds.deviceId)")
        //logger.debug("\tAccess token: \(creds.accessToken)")
        
        if creds.wellKnown != nil {
            return creds
        } else {
            let fullCreds = Matrix.Credentials(userId: creds.userId,
                                               accessToken: creds.accessToken,
                                               deviceId: creds.deviceId,
                                               wellKnown: Matrix.WellKnown(homeserver: "\(homeserver)"))
            return fullCreds
        }
    }
    
    func login(userId: UserId,
               password: String
    ) async throws -> Matrix.Credentials {
        
        // Create a UIAuthSession with the homeserver
        let authSession = try await UiaLoginSession(userId: userId,
                                                    refreshToken: true)
        try await authSession.connect()
        XCTAssertNotNil(authSession.sessionState)
        let uiaState = authSession.sessionState!
        
        let supportedAuthTypes = [
            AUTH_TYPE_TERMS,
            AUTH_TYPE_DUMMY,
            AUTH_TYPE_LOGIN_BSSPEKE_OPRF,
            AUTH_TYPE_LOGIN_BSSPEKE_VERIFY
        ]
        
        let flows = uiaState.flows
        for flow in flows {
            print("\tFlow: ", flow.stages)
        }
        
        let maybeFlow = flows.filter(
            {
                for stage in $0.stages {
                    if !supportedAuthTypes.contains(stage) {
                        return false
                    }
                }
                return true
            }
        ).first
        XCTAssertNotNil(maybeFlow)
        
        let flow = maybeFlow!
        print("Found a flow that we can do: ", flow.stages)
        await authSession.selectFlow(flow: flow)
        
        for stage in flow.stages {
            print("Working on stage [\(stage)]")
            switch stage {
            case AUTH_TYPE_DUMMY:
                try await authSession.doDummyAuthStage()
            case AUTH_TYPE_TERMS:
                try await authSession.doTermsStage()
            case AUTH_TYPE_LOGIN_BSSPEKE_OPRF:
                try await authSession.doBSSpekeLoginOprfStage(userId: userId, password: password)
            case AUTH_TYPE_LOGIN_BSSPEKE_VERIFY:
                try await authSession.doBSSpekeLoginVerifyStage()
            default:
                print("Unknown stage [\(stage)]")
                throw "Unknown stage [\(stage)]"
            }
        }
        
        // Get creds
        let decoder = JSONDecoder()
        guard case let .finished(data) = authSession.state,
              let creds = try? decoder.decode(Matrix.Credentials.self, from: data)
        else {
            throw "UIA is not finished"
        }
        
        return creds
    }
    
    func testRefreshTokens() async throws {
        let password = String(format: "%0llx", UInt64.random(in: UInt64.min...UInt64.max))
        
        // Register a new account
        let registerCreds = try await registerNewUser(name: "refresh",
                                                      password: password,
                                                      domain: self.domain,
                                                      homeserver: self.homeserver)
        // Now log in with it
        let creds = try await login(userId: registerCreds.userId,
                                    password: password)
        
        // Verify that we did get a refresh token and expiration date
        XCTAssertNotNil(creds.refreshToken)
        XCTAssertNotNil(creds.expiration)
        
        guard let refreshToken = creds.refreshToken,
              let expiration = creds.expiration
        else {
            logger.error("No refresh token")
            throw Matrix.Error("No refresh token")
        }
        
        logger.debug("✅ Got refresh token  = \(refreshToken)")
        logger.debug("✅ Got expiraton date = \(expiration)")
        
        logger.debug("Initializing client")
        var client = try await Matrix.Client(creds: creds)
        logger.debug("✅ Client initialized")
        
        struct TestStruct: Codable {
            var random: String
        }
        let random = String(format: "%0llx", UInt64.random(in: UInt64.min...UInt64.max))
        let randomStruct = TestStruct(random: random)
        logger.debug("Setting account data, random = \(random)")
        try await client.putAccountData(randomStruct, for: "test.refresh_token.random")
        logger.debug("✅ Account data set")
        
        logger.debug("Waiting for 35 sec")
        try await Task.sleep(for: .seconds(35))
        logger.debug("Awake from sleep")
        
        logger.debug("Fetching account data...")
        guard let fooStruct = try await client.getAccountData(for: "test.refresh_token.random", of: TestStruct.self)
        else {
            logger.error("Failed to get account data")
            throw "Failed to get account data"
        }
        logger.debug("✅ Got account data")
        
        XCTAssertEqual(fooStruct.random, randomStruct.random)
        guard fooStruct.random == randomStruct.random
        else {
            logger.error("Account data does not match: \(fooStruct.random) vs \(randomStruct.random)")
            throw "Account data does not match"
        }
        logger.debug("✅ Account data matches")
    }
}
