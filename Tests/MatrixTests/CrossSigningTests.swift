//
//  CrossSigningTests.swift
//  
//
//  Created by Charles Wright on 5/10/23.
//

import Foundation
import os

import XCTest
import Yams

//@testable import Matrix
// Not using @testable since we are validating public-facing API
import Matrix
import MatrixSDKCrypto

final class CrossSigningTests: XCTestCase {
    
    // Use the local Synapse development environment, or a local Conduit, for the tests.
    // Maintaining a public-facing test homeserver that offers registration is getting to be too much of a pain
    //let homeserver = URL(string: "http://localhost:6167")!
    //let domain = "localhost:6167"
    let homeserver = URL(string: "https://matrix.us.circles-dev.net")!
    let domain = "us.circles-dev.net"
    //let homeserver = URL(string: "http://localhost:8080")!
    //let domain = "localhost:8480"
    

    
    func registerNewUser(name: String, domain: String, homeserver: URL) async throws -> Matrix.Credentials {
        
        var logger = os.Logger(subsystem: "CrossSigningTests", category: "register")
        
        let supportedAuthTypes = [
            AUTH_TYPE_TERMS,
            AUTH_TYPE_DUMMY,
            AUTH_TYPE_ENROLL_USERNAME,
            AUTH_TYPE_ENROLL_BSSPEKE_OPRF,
            AUTH_TYPE_ENROLL_BSSPEKE_SAVE,
        ]
        
        let r = Int.random(in: 0..<5000)
        let username = String(format: "\(name)_%04d", r)
        //logger.debug("Username: \(username)")
        let password = String(format: "%0llx", UInt64.random(in: UInt64.min...UInt64.max))
        //logger.debug("Password: \(password)")
        let session = try await SignupSession(domain: domain, homeserver: homeserver)
        try await session.connect()
        XCTAssertNotNil(session.sessionState)
        let uiaState = session.sessionState!
        
        
        let flows = uiaState.flows
        for flow in flows {
            //logger.debug("\tFlow: ", flow.stages)
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
        
        guard case let .finished(codableCreds) = session.state,
              let creds = codableCreds as? Matrix.Credentials
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
    
    func testNewAccount() async throws {
        let creds = try await registerNewUser(name: "xsign_new_acct", domain: self.domain, homeserver: self.homeserver)
        let session = try await Matrix.Session(creds: creds, startSyncing: false)
    }
}
