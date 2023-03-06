//
//  EncryptedTests.swift
//  
//
//  Created by Charles Wright on 3/2/23.
//

import Foundation
import os

import XCTest
import Yams

//@testable import Matrix
// Not using @testable since we are validating public-facing API
import Matrix
import MatrixSDKCrypto

final class EncryptedTests: XCTestCase {
    
    // Use the local Synapse development environment, or a local Conduit, for the tests.
    // Maintaining a public-facing test homeserver that offers registration is getting to be too much of a pain
    let homeserver = URL(string: "http://localhost:6167")!
    let domain = "localhost:6167"
    //let homeserver = URL(string: "http://localhost:8080")!
    //let domain = "localhost:8480"
    var registerLogger = os.Logger(subsystem: "EncryptedTests", category: "register")
    
    func registerNewUser(name: String, domain: String, homeserver: URL) async throws -> Matrix.Credentials {
        
        var logger = registerLogger
        
        let supportedAuthTypes = [
            AUTH_TYPE_TERMS,
            AUTH_TYPE_DUMMY,
        ]
        
        let r = Int.random(in: 0..<5000)
        let username = String(format: "\(name)_%04d", r)
        //logger.debug("Username: \(username)")
        let password = String(format: "%0llx", UInt64.random(in: UInt64.min...UInt64.max))
        //logger.debug("Password: \(password)")
        let session = try await SignupSession(domain: domain, homeserver: homeserver, username: username, password: password)
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
            default:
                //logger.debug("Unknown stage [\(stage)]")
                throw "Unknown stage [\(stage)]"
            }
        }
        
        guard case let .finished(creds) = session.state
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
    
    func createEncryptedRoom(session: Matrix.Session, name: String) async throws -> RoomId {
        let roomId = try await session.createRoom(name: name, encrypted: true)
        print("✅ created room \(roomId)")
        
        print("Syncing until room \(roomId) appears in our session")
        let _ = try await session.waitUntil({
            session.rooms[roomId] != nil
        })
        
        guard let room = session.rooms[roomId]
        else {
            throw "Matrix session does not have room \(roomId)"
        }
        print("✅ room \(roomId) is in our session")
        
        guard room.isEncrypted == true
        else {
            throw "Room \(roomId) exists but is not encrypted"
        }
        print("✅ room \(roomId) is encrypted")
        
        return roomId
    }
    
    func testCreateEncryptedRoom() async throws {
        
        let creds = try await registerNewUser(name: "room_creator", domain: self.domain, homeserver: self.homeserver)
        
        let session = try await Matrix.Session(creds: creds, startSyncing: true)
        
        let roomId = try await createEncryptedRoom(session: session, name: "testCreateEncryptedRoom")
    }
    
    func testSendEncryptedMessage() async throws {
        
        let creds = try await registerNewUser(name: "message_sender", domain: self.domain, homeserver: self.homeserver)
        
        let session = try await Matrix.Session(creds: creds, startSyncing: true)
        
        //let roomId = try await createEncryptedRoom(session: session, name: "testSendEncryptedMessage")
        let roomId = try await session.createRoom(name: "testSendEncryptedMessage", encrypted: true)
        print("✅ created room \(roomId)")

        try await session.waitUntil {
            session.rooms.keys.contains(roomId)
        }
        
        guard let room = session.rooms[roomId]
        else {
            throw "Failed to get Matrix room \(roomId)"
        }
        print("✅ got Room object for \(roomId)")

        let eventId = try await room.sendText(text: "test encrypted message for testSendEncryptedRoom")
        print("✅ event sent with id \(eventId)")
        
        print("Syncing until the event appears in our timeline")
        try await session.waitUntil {
            let event = room.timeline.first { $0.eventId == eventId }
            return event != nil
        }
        
        guard let event = room.timeline.first(where: { $0.eventId == eventId })
        else {
            print("❌ event \(eventId) is not in our timeline")
            throw "❌ event \(eventId) is not in our timeline"
        }
        print("✅ found event \(event.eventId) in the timeline")
        
        XCTAssert(event.type != M_ROOM_ENCRYPTED)
        if event.type == M_ROOM_ENCRYPTED {
            print("❌ event is still encrypted")
            throw "Failed to decrypt"
        } else {
            print("✅ event has type [\(event.type)]")
        }
    }
    
    func testEncryptedConversation() async throws {
        MatrixSDKCrypto.setLogger(logger: Matrix.cryptoLogger)

        let aliceCreds = try await registerNewUser(name: "alice", domain: self.domain, homeserver: self.homeserver)
        print("✅ registered Alice as \(aliceCreds.userId)")
        let aliceSession = try await Matrix.Session(creds: aliceCreds, startSyncing: true)
        print("✅ Alice is online")
        
        let bobCreds = try await registerNewUser(name: "bob", domain: self.domain, homeserver: self.homeserver)
        print("✅ registered Bob as \(bobCreds.userId)")
        let bobSession = try await Matrix.Session(creds: bobCreds, startSyncing: true)
        print("✅ Bob is online")

        let roomId = try await aliceSession.createRoom(name: "testEncryptedConversation", encrypted: true)
        print("✅ Alice created room \(roomId)")
        try await aliceSession.waitUntil {
            aliceSession.rooms.keys.contains(roomId)
        }
        let roomA = try await aliceSession.getRoom(roomId: roomId)
        XCTAssertNotNil(roomA)
        guard let aliceRoom = roomA
        else {
            print("❌ room was nil")
            throw "Couldn't get Room object"
        }
        
        try await aliceRoom.invite(userId: bobCreds.userId)
        print("✅ Alice sent invite for Bob")
        try await aliceSession.waitUntil {
            guard let event = aliceRoom.state[M_ROOM_MEMBER]?["\(bobCreds.userId)"]
            else {
                print("🙁 no room member event for Bob")
                return false
            }
            guard let content = event.content as? RoomMemberContent
            else {
                print("🙁 could not parse room member event for Bob")
                return false
            }
            if content.membership == .invite {
                print("🙂 Bob is invited")
                return true
            } else {
                print("🙁 Bob's membership state is \(content.membership)")
                return false
            }
        }
        print("✅ Alice sees Bob in 'invited' state")

        try await bobSession.waitUntil {
            bobSession.invitations.keys.contains(roomId)
        }
        print("✅ Bob has the invitation")
        let invited = bobSession.invitations[roomId]
        XCTAssertNotNil(invited)
        guard let bobInvitedRoom = invited
        else {
            print("❌ Bob couldn't get InvitedRoom object")
            throw "Failed to get InvitedRoom"
        }
        print("✅ Bob has the InvitedRoom object")
        
        try await bobInvitedRoom.join()
        print("✅ Bob sent /join to the room")

        try await bobSession.waitUntil {
            bobSession.rooms.keys.contains(roomId)
        }
        print("✅ Bob has the room in joined state")
        let roomB = bobSession.rooms[roomId]
        XCTAssertNotNil(roomB)
        guard let bobRoom = roomB
        else {
            print("❌ Bob couldn't get Room object")
            throw "Failed to get Room object for Bob"
        }
        print("✅ Bob has the Room object")

        try await aliceSession.waitUntil {
            guard let event = aliceRoom.state[M_ROOM_MEMBER]?["\(bobCreds.userId)"]
            else {
                print("🙁 no member event for Bob")
                return false
            }
            guard let content = event.content as? RoomMemberContent
            else {
                print("🙁 could not parse room member event for Bob")
                return false
            }
            if content.membership == .join {
                print("🙂 Bob is joined")
                return true
            } else {
                print("🙁 Bob's membership state is \(content.membership)")
                return false
            }
        }
        print("✅ Alice sees Bob in joined state")

        let millisecs = UInt64(30_000)
        try await Task.sleep(nanoseconds: millisecs * 1_000_000)
        
        let message1text = "Message 1"
        let eventId1 = try await aliceRoom.sendText(text: message1text)
        print("✅ Alice sent message 1")
        
        //print("❗️ Alice stopping syncing to make debugging easier")
        //try await aliceSession.pause()

        print("Waiting until Alice sees the message")
        try await aliceSession.waitUntil {
            aliceRoom.timeline.first(where: {$0.eventId == eventId1}) != nil
        }
        guard let aliceMessage1 = aliceRoom.timeline.first(where: {$0.eventId == eventId1})
        else {
            print("❌ Alice doesn't have message 1")
            throw "Alice doesn't have message 1"
        }
        print("✅ Alice sees message 1 of type \(aliceMessage1.type)")
        XCTAssert(aliceMessage1.type == M_ROOM_MESSAGE)
        guard let aliceContent1 = aliceMessage1.content as? Matrix.mTextContent,
              aliceContent1.body == message1text
        else {
            print("❌ Alice failed to decrypt")
            throw "Alice failed to decrypt"
        }
        print("✅ Alice decrypted successfully")

        print("Waiting until Bob sees the message")
        try await bobSession.waitUntil {
            bobRoom.timeline.first(where: {$0.eventId == eventId1}) != nil
        }
        guard let bobMessage1 = bobRoom.timeline.first(where: {$0.eventId == eventId1})
        else {
            print("❌ Bob doesn't have message 1")
            throw "Bob doesn't have message 1"
        }
        print("✅ Bob sees message 1 of type \(bobMessage1.type)")
        XCTAssert(bobMessage1.type == M_ROOM_MESSAGE)
        guard let bobContent1 = bobMessage1.content as? Matrix.mTextContent,
              bobContent1.body == message1text
        else {
            print("❌ Bob failed to decrypt")
            throw "Bob failed to decrypt"
        }
        print("✅ Bob decrypted successfully")

    }
    
    func testUploadEncryptedMedia() async throws {
        // TODO
        throw "Not implemented"
    }
}
