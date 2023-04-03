//
//  UnencryptedTests.swift
//  
//
//  Created by Charles Wright on 2/10/23.
//

import XCTest
import Yams

//@testable import Matrix
// Not using @testable since we are validating public-facing API
import Matrix

final class UnencryptedTests: XCTestCase {
    
    // Use the local Synapse development environment, or a local Conduit, for the tests.
    // Maintaining a public-facing test homeserver that offers registration is getting to be too much of a pain
    let homeserver = URL(string: "http://localhost:6167")!
    let domain = "localhost:6167"
    
    
    func registerNewUser(domain: String, homeserver: URL) async throws -> Matrix.Credentials {
        
        let supportedAuthTypes = [
            AUTH_TYPE_TERMS,
            AUTH_TYPE_DUMMY,
        ]
        
        let r = Int.random(in: 0..<5000)
        let username = String(format: "user_%04d", r)
        print("Username: \(username)")
        let password = String(format: "%0llx", UInt64.random(in: UInt64.min...UInt64.max))
        print("Password: \(password)")
        let session = try await SignupSession(domain: domain, homeserver: homeserver, username: username, password: password)
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
            default:
                print("Unknown stage [\(stage)]")
                throw "Unknown stage [\(stage)]"
            }
        }
        
        guard case let .finished(codableCreds) = session.state,
              let creds = codableCreds as? Matrix.Credentials
        else {
            throw "UIA is not finished"
        }
        
        print("Got credentials:")
        print("\tUser id: \(creds.userId)")
        print("\tDevice id: \(creds.deviceId)")
        print("\tAccess token: \(creds.accessToken)")
        
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
    
    func createUnencryptedRoom(session: Matrix.Session, name: String) async throws -> RoomId {
        let roomId = try await session.createRoom(name: name, encrypted: false)
        print("✅ created room \(roomId)")
        
        print("Syncing until room \(roomId) appears in our session")
        let _ = try await session.syncUntil({
            session.rooms[roomId] != nil
        })
        
        guard let room = session.rooms[roomId]
        else {
            throw "Matrix session does not have room \(roomId)"
        }
        print("✅ room \(roomId) is in our session")
        
        guard room.isEncrypted == false
        else {
            throw "Room \(roomId) exists but is encrypted"
        }
        print("✅ room \(roomId) is unencrypted")
        
        return roomId
    }
    
    func testCreateUnencryptedRoom() async throws {
        
        let creds = try await registerNewUser(domain: self.domain, homeserver: self.homeserver)
        
        let session = try await Matrix.Session(creds: creds, startSyncing: false)
        
        let roomId = try await createUnencryptedRoom(session: session, name: "testCreateUnencryptedRoom")
    }
    
    func testSendUnencryptedMessage() async throws {
        
        let creds = try await registerNewUser(domain: self.domain, homeserver: self.homeserver)
        
        let session = try await Matrix.Session(creds: creds, startSyncing: false)
        
        let roomId = try await createUnencryptedRoom(session: session, name: "testSendUnencryptedMessage")
        print("✅ created room \(roomId)")

        try await session.syncUntil {
            session.rooms.keys.contains(roomId)
        }
        
        guard let room = session.rooms[roomId]
        else {
            throw "Failed to get Matrix room \(roomId)"
        }
        print("✅ got Room object for \(roomId)")

        let eventId = try await room.sendText(text: "test message for testSendUnencryptedRoom")
        print("✅ event sent with id \(eventId)")
        
        print("Syncing until the event appears in our timeline")
        try await session.syncUntil {
            let event = room.timeline.values.first { $0.eventId == eventId }
            return event != nil
        }
        
        guard let event = room.timeline.values.first(where: { $0.eventId == eventId })
        else {
            throw "❌ event \(eventId) is not in our timeline"
        }
        print("✅ found event \(event.eventId) in the timeline")
    }
    
    func testUploadUnencryptedMedia() async throws {
        // TODO
        throw "Not implemented"
    }
}
