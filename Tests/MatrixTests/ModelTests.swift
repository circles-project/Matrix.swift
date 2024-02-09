import XCTest

enum XCTError: Error {
    case error(String)
}

//@testable import Matrix
// Not using @testable since we are validating public-facing API
import Matrix

/// Sanity tests for validating the JSON parsing from the examples given in the spec: https://spec.matrix.org/v1.5/
final class ModelTests: XCTestCase {
    func testWellKnownModel() throws {
        let decoder = JSONDecoder()
        let wellKnown = try decoder.decode(Matrix.WellKnown.self, from: JSONResponses.wellKnown)
        print(wellKnown)

        XCTAssertEqual(wellKnown.homeserver.baseUrl, "https://matrix.example.com")
        XCTAssertEqual(wellKnown.identityserver?.baseUrl, "https://identity.example.com")
        // Custom property validation not implmeneted
    }

    func testCredentialModel() throws {
        let decoder = JSONDecoder()
        let credentials = try decoder.decode(Matrix.Credentials.self, from: JSONResponses.login)
        print(credentials)
        
        XCTAssertEqual(credentials.accessToken, "abc123")
        XCTAssertEqual(credentials.deviceId, "GHTYAJCE")
        XCTAssertEqual(credentials.userId.description, "@cheeky_monkey:matrix.org")
        XCTAssertNotNil(credentials.wellKnown)
    }
    
    func testSyncResponseModel() throws {
        let decoder = JSONDecoder()
        let syncResponse = try decoder.decode(Matrix.SyncResponseBody.self, from: JSONResponses.sync)
        print("Full Sync Response:\n\t \(syncResponse)\n")
        
        print("AccountData:\n\t \(syncResponse.accountData!)")
        XCTAssertEqual(syncResponse.accountData!.events![0].type, M_TAG)
        XCTAssertEqual((syncResponse.accountData!.events![0].content
                        as! TagContent).tags["u.work"]!.order, 0.9)
        
        XCTAssertEqual(syncResponse.nextBatch, "s72595_4483_1934")
        
        let presenceData = syncResponse.presence!.events![0]
        let presenceDataContent = presenceData.content as! PresenceContent
        print("Presence:\n\t \(syncResponse.presence!)")
        XCTAssertEqual(presenceData.type, M_PRESENCE)
        XCTAssertEqual(presenceData.sender, UserId("@example:localhost.com"))
        XCTAssertEqual(presenceDataContent.avatarUrl, MXC("mxc://localhost/wefuiwegh8742w"))
        XCTAssertEqual(presenceDataContent.currentlyActive, false)
        XCTAssertEqual(presenceDataContent.presence, PresenceContent.Presence.online)
        XCTAssertEqual(presenceDataContent.statusMessage, "Making cupcakes")
 
        let invite = syncResponse.rooms!.invite!
        let inviteRoomId = RoomId("!696r7674:example.com")!
        print("Room Invite:\n\t \(invite)")
        XCTAssertEqual(invite[inviteRoomId]!.inviteState!.events![0].type,
                       M_ROOM_NAME)
        XCTAssertEqual(invite[inviteRoomId]!.inviteState!.events![0].sender,
                       UserId("@alice:example.com"))
        XCTAssertEqual((invite[inviteRoomId]!.inviteState!.events![0].content
                        as! RoomNameContent).name, "My Room Name")
        XCTAssertEqual(invite[inviteRoomId]!.inviteState!.events![1].type,
                       M_ROOM_MEMBER)
        XCTAssertEqual(invite[inviteRoomId]!.inviteState!.events![1].sender,
                       UserId("@alice:example.com"))
        XCTAssertEqual(invite[inviteRoomId]!.inviteState!.events![1].stateKey,
                       "@bob:example.com")
        XCTAssertEqual((invite[inviteRoomId]!.inviteState!.events![1].content
                        as! RoomMemberContent).membership, RoomMemberContent.Membership.invite)
        
        let join = syncResponse.rooms!.join!
        let joinRoomId = RoomId("!726s6s6q:example.com")!
        // cvw: Commenting these out for quick testing of the simplified implementation
        //let joinReceiptContentEvents = (join[joinRoomId]!.ephemeral!.events![1].content as! ReceiptContent).events
        //let joinReceiptContentEventId = "$1435641916114394fHBLK:matrix.org"
        print("Room Join:\n\t \(join)")
        XCTAssertEqual(join[joinRoomId]!.accountData!.events![0].type, M_TAG)
        XCTAssertEqual((join[joinRoomId]!.accountData!.events![0].content
                        as! TagContent).tags["u.work"]!.order, 0.9)
        
        XCTAssertEqual(join[joinRoomId]!.ephemeral!.events![0].type, M_TYPING)
        XCTAssertEqual((join[joinRoomId]!.ephemeral!.events![0].content
                        as! TypingContent).userIds,
                       [UserId("@alice:matrix.org"), UserId("@bob:example.com")])
        XCTAssertEqual(join[joinRoomId]!.ephemeral!.events![1].type, M_RECEIPT)
  
        /*
        for receiptType in joinReceiptContentEvents[joinReceiptContentEventId]! {
            switch receiptType {
            case .read(let userDict):
                XCTAssertEqual(userDict[UserId("@rikj:jki.re")!]!.ts, 1436451550453)
                break
            case .readPrivate(let userDict):
                XCTAssertEqual(userDict[UserId("@self:example.org")!]!.ts, 1661384801651)
                break
            default:
                throw XCTError.error("Failed to validate \(joinReceiptContentEvents[joinReceiptContentEventId]!)")
            }
        }
        */
        
        XCTAssertEqual(join[joinRoomId]!.state!.events![0].type, M_ROOM_MEMBER)
        XCTAssertEqual(join[joinRoomId]!.state!.events![0].eventId, "$143273582443PhrSn:example.org")
        XCTAssertEqual(join[joinRoomId]!.state!.events![0].originServerTS, 1432735824653)
        XCTAssertEqual(join[joinRoomId]!.state!.events![0].sender, UserId("@example:example.org"))
        XCTAssertEqual(join[joinRoomId]!.state!.events![0].stateKey, "@alice:example.org")
        XCTAssertEqual(join[joinRoomId]!.state!.events![0].unsigned!.age, 1234)
        XCTAssertEqual((join[joinRoomId]!.state!.events![0].content
                        as! RoomMemberContent).avatarUrl, "mxc://example.org/SEsfnsuifSDFSSEF")
        XCTAssertEqual((join[joinRoomId]!.state!.events![0].content
                        as! RoomMemberContent).displayname, "Alice Margatroid")
        XCTAssertEqual((join[joinRoomId]!.state!.events![0].content
                        as! RoomMemberContent).membership, RoomMemberContent.Membership.join)
        XCTAssertEqual((join[joinRoomId]!.state!.events![0].content
                        as! RoomMemberContent).reason, "Looking for support")
           
        XCTAssertEqual(join[joinRoomId]!.summary!.heroes![0], UserId("@alice:example.com"))
        XCTAssertEqual(join[joinRoomId]!.summary!.heroes![1], UserId("@bob:example.com"))
        XCTAssertEqual(join[joinRoomId]!.summary!.invitedMemberCount, 0)
        XCTAssertEqual(join[joinRoomId]!.summary!.joinedMemberCount, 2)
        
        XCTAssertEqual(join[joinRoomId]!.timeline!.limited, true)
        XCTAssertEqual(join[joinRoomId]!.timeline!.prevBatch, "t34-23535_0_0")
        XCTAssertEqual(join[joinRoomId]!.timeline!.events[0].type, M_ROOM_MEMBER)
        XCTAssertEqual(join[joinRoomId]!.timeline!.events[0].eventId, "$143273582443PhrSn:example.org")
        XCTAssertEqual(join[joinRoomId]!.timeline!.events[0].originServerTS, 1432735824653)
        XCTAssertEqual(join[joinRoomId]!.timeline!.events[0].sender, UserId("@example:example.org"))
        XCTAssertEqual(join[joinRoomId]!.timeline!.events[0].stateKey, "@alice:example.org")
        XCTAssertEqual(join[joinRoomId]!.timeline!.events[0].unsigned!.age, 1234)
        XCTAssertEqual((join[joinRoomId]!.timeline!.events[0].content
                        as! RoomMemberContent).avatarUrl, "mxc://example.org/SEsfnsuifSDFSSEF")
        XCTAssertEqual((join[joinRoomId]!.timeline!.events[0].content
                        as! RoomMemberContent).displayname, "Alice Margatroid")
        XCTAssertEqual((join[joinRoomId]!.timeline!.events[0].content
                        as! RoomMemberContent).membership, RoomMemberContent.Membership.join)
        XCTAssertEqual((join[joinRoomId]!.timeline!.events[0].content
                        as! RoomMemberContent).reason, "Looking for support")
        
        XCTAssertEqual(join[joinRoomId]!.timeline!.events[1].type, M_ROOM_MESSAGE)
        XCTAssertEqual(join[joinRoomId]!.timeline!.events[1].eventId, "$143273582443PhrSn:example.org")
        XCTAssertEqual(join[joinRoomId]!.timeline!.events[1].originServerTS, 1432735824653)
        XCTAssertEqual(join[joinRoomId]!.timeline!.events[1].sender, UserId("@example:example.org"))
        XCTAssertEqual(join[joinRoomId]!.timeline!.events[1].unsigned!.age, 1234)
        XCTAssertEqual((join[joinRoomId]!.timeline!.events[1].content
                        as! Matrix.mTextContent).body, "This is an example text message")
        XCTAssertEqual((join[joinRoomId]!.timeline!.events[1].content
                        as! Matrix.mTextContent).format, "org.matrix.custom.html")
        XCTAssertEqual((join[joinRoomId]!.timeline!.events[1].content
                        as! Matrix.mTextContent).formatted_body, "<b>This is an example text message</b>")
        XCTAssertEqual((join[joinRoomId]!.timeline!.events[1].content
                        as! Matrix.mTextContent).msgtype, M_TEXT)
        
        XCTAssertEqual(join[joinRoomId]!.unreadNotifications!.highlightCount, 1)
        XCTAssertEqual(join[joinRoomId]!.unreadNotifications!.notificationCount, 5)
        XCTAssertEqual(join[joinRoomId]!.unreadThreadNotifications!["$threadroot"]!.highlightCount, 3)
        XCTAssertEqual(join[joinRoomId]!.unreadThreadNotifications!["$threadroot"]!.notificationCount, 6)
                
        let knock = syncResponse.rooms!.knock!
        let knockRoomId = RoomId("!223asd456:example.com")!
        print("Room Knock:\n\t \(knock)")
        XCTAssertEqual(knock[knockRoomId]!.knockState!.events![0].type, M_ROOM_NAME)
        XCTAssertEqual(knock[knockRoomId]!.knockState!.events![0].sender, UserId("@alice:example.com"))
        XCTAssertEqual((knock[knockRoomId]!.knockState!.events![0].content
                        as! RoomNameContent).name, "My Room Name")
        XCTAssertEqual(knock[knockRoomId]!.knockState!.events![1].type, M_ROOM_MEMBER)
        XCTAssertEqual(knock[knockRoomId]!.knockState!.events![1].sender, UserId("@bob:example.com"))
        XCTAssertEqual(knock[knockRoomId]!.knockState!.events![1].stateKey, "@bob:example.com")
        XCTAssertEqual((knock[knockRoomId]!.knockState!.events![1].content
                        as! RoomMemberContent).membership, RoomMemberContent.Membership.knock)
    }
    
    func testEventCreateContentModel() throws {
        let decoder = JSONDecoder()
        let room = try decoder.decode(ClientEvent.self, from: JSONResponses.RoomEvent.roomCreate)
        print(room)
        
        XCTAssertEqual(room.type, M_ROOM_CREATE)
        XCTAssertEqual(room.eventId, "$143273582443PhrSn:example.org")
        XCTAssertEqual(room.originServerTS, 1432735824653)
        XCTAssertEqual(room.roomId, RoomId("!jEsUZKDJdhlrceRyVU:example.org"))
        XCTAssertEqual(room.sender, UserId("@example:example.org"))
        XCTAssertEqual(room.stateKey, "")
        XCTAssertEqual(room.unsigned!.age, 1234)
        
        let roomContent = room.content as! RoomCreateContent
        XCTAssertEqual(roomContent.creator, UserId("@example:example.org"))
        XCTAssertEqual(roomContent.federate, true)
        XCTAssertEqual(roomContent.predecessor!.eventId, "$something:example.org")
        XCTAssertEqual(roomContent.predecessor!.roomId, RoomId("!oldroom:example.org"))
        XCTAssertEqual(roomContent.roomVersion, "1")
    }
}
