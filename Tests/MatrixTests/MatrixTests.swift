import XCTest
@testable import Matrix

import Yams

final class MatrixTests: XCTestCase {
    
    struct Config: Decodable {
        var domain: String
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
    
    func testRegistration() async throws {
        let domain = "us.circles-dev.net"
        
        let r = Int.random(in: 0...10)
        let username = "user_\(r)"
        let signup = try await SignupSession(domain: domain)
        try await signup.connect()
        XCTAssertNotNil(signup.sessionState)
        let uiaState = signup.sessionState!
        let flows = uiaState.flows
        for flow in flows {
            print("Found flow: ", flow.stages)
        }
    }
}
