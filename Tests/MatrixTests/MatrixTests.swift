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
    
    func doBsspekeRegistration() async throws -> Matrix.Credentials? {
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
        let userId = UserId("@\(username):\(domain)")!
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
                try await session.doBSSpekeEnrollOprfStage(userId: userId, password: password)
            case AUTH_TYPE_ENROLL_BSSPEKE_SAVE:
                try await session.doBSSpekeEnrollSaveStage()
            default:
                print("Unknown stage [\(stage)]")
                throw "Unknown stage [\(stage)]"
            }
        }
        
        guard case let .finished(creds) = session.state
        else {
            throw "UIA is not finished"
        }
        
        print("Got credentials:")
        print("\tUser id: \(creds.userId)")
        print("\tDevice id: \(creds.deviceId)")
        print("\tAccess token: \(creds.accessToken)")
        
        return creds
    }
    
    func testBsspekeRegistration() async throws {
        let creds = try await doBsspekeRegistration()
        XCTAssertNotNil(creds)
    }
    
    func testRegisterAndSync() async throws {
        var creds = try await doBsspekeRegistration()
        XCTAssertNotNil(creds)
        
        if creds!.wellKnown == nil {
            creds!.wellKnown = try await Matrix.fetchWellKnown(for: creds!.userId.domain)
        }
        let session = try Matrix.Session(creds: creds!, startSyncing: false)
        
        let token = try await session.sync()
        XCTAssertNotNil(token)
    }
    
    func testLoginAndSync() async throws {
        // Get user id and password
        let username = "test_5d52"
        let password = "d7dee558c71a4b91e096c14e"
        let domain = "us.circles-dev.net"
        let userId = UserId("@\(username):\(domain)")!
        
        // Look up well known
        let wellknown = try await Matrix.fetchWellKnown(for: domain)
        
        // Create a UIAuthSession with the homeserver
        let authSession = try await LoginSession(username: username, domain: domain)
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
        guard case let .finished(creds) = authSession.state
        else {
            throw "UIA is not finished"
        }
        
        // Create a Matrix.Session
        let session = try Matrix.Session(creds: creds, startSyncing: false)
        
        // Sync
        print("Syncing...")
        let token0 = try await session.sync()
        XCTAssertNotNil(token0)
        
        // Create a room
        let roomName = "Test Room"
        print("Creating room [\(roomName)]")
        let roomId = try await session.createRoom(name: roomName)
        print("Got roomId = \(roomId) for \(roomName)")
        
        // Sync -- Is the room id now in the sync resonse?
        print("Syncing...")
        let token1 = try await session.sync()
        print("Got sync token \(token1)")
        let myRoom = session.rooms[roomId]
        XCTAssertNotNil(myRoom)
        
        // Send a message into the room
        // TBD
        
        // Sync -- Is the message now in the room?
    }
}
