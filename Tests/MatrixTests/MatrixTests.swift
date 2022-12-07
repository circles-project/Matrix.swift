import XCTest
@testable import Matrix

import Yams

extension String: Error { }

final class MatrixTests: XCTestCase {
    
    struct Config: Decodable {
        var domain: String
    }
    
    struct UserInfo: Codable {
        var username: String
        var password: String
        var displayname: String?
    }
    
    func loadConfig(filename: String) throws -> Config {
        let configData = try Data(contentsOf: URL(fileURLWithPath: "testconfig.yml"))
        let decoder = YAMLDecoder()
        let config = try decoder.decode(Config.self, from: configData)
        return config
    }
    
    
    
    func testWellKnown() async throws {
        //let config = try loadConfig(filename: "testconfig.yml")
        let config = Config(domain: "us.circles-dev.net")
        print("Loaded config")
        print("Domain = \(config.domain)")
        
        let wellknown = try await Matrix.fetchWellKnown(for: config.domain)
        print("Got homeserver = \(wellknown.homeserver.baseUrl)")
        
        let url = URL(string: wellknown.homeserver.baseUrl)
        XCTAssertNotNil(url)
    }
    
    func testBsspekeRegistration() async throws {
        let domain = "us.circles-dev.net"
        
        let supportedAuthTypes = [
            AUTH_TYPE_ENROLL_USERNAME,
            AUTH_TYPE_ENROLL_PASSWORD,
            AUTH_TYPE_TERMS,
            AUTH_TYPE_DUMMY,
            AUTH_TYPE_ENROLL_BSSPEKE_OPRF,
            AUTH_TYPE_ENROLL_BSSPEKE_SAVE
        ]
        
        let r = Int.random(in: 0...100)
        let username = String(format: "user_%03d", r)
        print("Username: \(username)")
        let password = String(format: "%0llx", UInt64.random(in: UInt64.min...UInt64.max))
        print("Password: \(password)")
        let session = try await SignupSession(domain: domain)
        try await session.connect()
        XCTAssertNotNil(session.sessionState)
        let uiaState = session.sessionState!
        
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
        await session.selectFlow(flow: flow)
        
        for stage in flow.stages {
            print("Working on stage [\(stage)]")
            switch stage {
            case AUTH_TYPE_DUMMY:
                try await session.doDummyAuthStage()
            case AUTH_TYPE_TERMS:
                try await session.doTermsStage()
            case AUTH_TYPE_ENROLL_USERNAME:
                try await session.doUsernameStage(username: username)
            case AUTH_TYPE_ENROLL_PASSWORD:
                try await session.doPasswordEnrollStage(newPassword: password)
            case AUTH_TYPE_ENROLL_BSSPEKE_OPRF:
                try await session.doBSSpekeSignupOprfStage(password: password)
            case AUTH_TYPE_ENROLL_BSSPEKE_SAVE:
                try await session.doBSSpekeSignupSaveStage()
            default:
                print("Unknown stage [\(stage)]")
                throw "Unknown stage [\(stage)]"
            }
        }
    }
}
