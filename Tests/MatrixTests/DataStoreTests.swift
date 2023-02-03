import XCTest
import Matrix
//@testable import GRDBDataStore

// Not using @testable since we are validating public-facing API
import GRDBDataStore

// Sanity tests for GRDB implementation of the DataStore protocol
final class DataStoreTests: XCTestCase {
    func testDataStoreInitialization() async throws {
        let decoder = JSONDecoder()
        let creds = try decoder.decode(Matrix.Credentials.self, from: JSONResponses.login)
        let store = try await GRDBDataStore(userId: creds.userId, deviceId: creds.deviceId)

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.url.path))

        addTeardownBlock {
            try store.dbQueue.close()
            try FileManager.default.removeItem(atPath: store.url.path)
        }
    }

    func testDataStoreClear() async throws {
        let decoder = JSONDecoder()
        let creds = try decoder.decode(Matrix.Credentials.self, from: JSONResponses.login)
        let store = try await GRDBDataStore(userId: creds.userId, deviceId: creds.deviceId)

        let roomName = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.name)
        try await store.save(creds)
        try await store.save(roomName)
        try await store.clearStore()
        
        let newCreds = try await store.load(Matrix.Credentials.self, key: (creds.userId, creds.deviceId))
        XCTAssertNil(newCreds)
        
        let newRoomName = try await store.load(ClientEventWithoutRoomId.self, key: roomName.eventId)
        XCTAssertNil(newRoomName)
        
        let rooms = try await store.loadAll(Matrix.Room.self)!
        XCTAssertEqual(rooms.count, 0)
    }
    
    func testDataStoreModelClientEvent() async throws {
        let decoder = JSONDecoder()
        let creds = try decoder.decode(Matrix.Credentials.self, from: JSONResponses.login)
        let store = try await GRDBDataStore(userId: creds.userId, deviceId: creds.deviceId)

        let roomName = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.name)
        
        // Verify proper key retrevial for later validation
        let test1 = try ClientEvent(content: RoomNameContent(name: "foo"), eventId: "$foo:bar.com",
                                    originServerTS: 1234, roomId: RoomId("!foo:bar.com")!,
                                    sender: UserId("@foo:bar.com")!, type: Matrix.EventType.mRoomName)
        try await store.save(test1)

        let test2 = try ClientEventWithoutRoomId(content: RoomNameContent(name: "bar"),
                                                 eventId: "$bar:foo.com", originServerTS: 1234,
                                                 sender: UserId("@bar:foo.com")!, type: Matrix.EventType.mRoomName)
        try await store.save(test2)

        // Save/load validation
        try await store.save(roomName)
        var newRoomName: ClientEventWithoutRoomId? = try await store.load(ClientEventWithoutRoomId.self,
                                                                          key: roomName.eventId)!
        XCTAssertEqual(roomName, newRoomName)

        // Remove
        try await store.remove(roomName)
        newRoomName = try await store.load(ClientEventWithoutRoomId.self, key: roomName.eventId)
        XCTAssertNil(newRoomName)

        // Remove by key
        try await store.save(roomName)
        try await store.remove(ClientEventWithoutRoomId.self, key: roomName.eventId)
        newRoomName = try await store.load(ClientEventWithoutRoomId.self, key: roomName.eventId)
        XCTAssertNil(newRoomName)

        // Save all / load all validation
        try await store.clearStore()
        try await store.saveAll([roomName, test2])
        var eventList = try await store.loadAll(ClientEventWithoutRoomId.self)!
        XCTAssertEqual([roomName, test2], eventList)

        // Remove all
        try await store.removeAll(eventList)
        eventList = try await store.loadAll(ClientEventWithoutRoomId.self)!
        XCTAssertEqual(eventList, [])
        
        // Additional tests
        try await store.save(test1)
        let newTest1 = try await store.load(ClientEvent.self, key: test1.eventId)!
        XCTAssertEqual(test1, newTest1)
        
        let newTest1WithoutRoomId = try await store.load(ClientEventWithoutRoomId.self, key: test1.eventId)!
        XCTAssertEqual(test1.eventId, newTest1WithoutRoomId.eventId)
        XCTAssertEqual(test1.type, newTest1WithoutRoomId.type)
        XCTAssertEqual(test1.originServerTS, newTest1WithoutRoomId.originServerTS)
        XCTAssertEqual(test1.sender, newTest1WithoutRoomId.sender)
    }
    
    func testDataStoreModelCredentials() async throws {
        let decoder = JSONDecoder()
        var creds = try decoder.decode(Matrix.Credentials.self, from: JSONResponses.login)
        let store = try await GRDBDataStore(userId: creds.userId, deviceId: creds.deviceId)

        // Verify proper key retrevial for later validation
        let test1 = Matrix.Credentials(userId: UserId("@foo:bar.com")!, deviceId: "foobar", accessToken: "baz")
        try await store.save(test1)

        let test2 = Matrix.Credentials(userId: UserId("@bar:foo.com")!, deviceId: "barfoo", accessToken: "zab")

        // Save/load validation
        try await store.save(creds)
        creds.accessToken = "def456"
        creds.expiresInMs = 999999
        creds.refreshToken = nil
        creds.homeServer = "https://example.org"
        creds.wellKnown?.homeserver.baseUrl = "https://org.example"
        creds.wellKnown?.identityserver?.baseUrl = "https://org.example.id"

        creds = try await store.load(Matrix.Credentials.self, key: (creds.userId, creds.deviceId))!
        let originalCreds = try decoder.decode(Matrix.Credentials.self, from: JSONResponses.login)

        let initCreds = try await store.load(Matrix.Credentials.self, key: (originalCreds.userId,
                                                                            originalCreds.deviceId))!
        XCTAssertEqual(initCreds, originalCreds)

        // Remove
        try await store.remove(creds)
        var newCreds = try await store.load(Matrix.Credentials.self, key: (creds.userId, creds.deviceId))
        XCTAssertNil(newCreds)
        
        // Remove by key
        try await store.save(creds)
        try await store.remove(Matrix.Credentials.self, key: (creds.userId, creds.deviceId))
        newCreds = try await store.load(Matrix.Credentials.self, key: (creds.userId, creds.deviceId))
        XCTAssertNil(newCreds)
        
        // Save all / load all validation
        try await store.clearStore()
        try await store.saveAll([creds, test1, test2])
        var credList = try await store.loadAll(Matrix.Credentials.self)!
        XCTAssertEqual([creds, test1, test2], credList)
        
        // Remove all
        try await store.removeAll(credList)
        credList = try await store.loadAll(Matrix.Credentials.self)!
        XCTAssertEqual(credList, [])
    }

    func testDataStoreModelRoom() async throws {
        let decoder = JSONDecoder()
        let creds = try decoder.decode(Matrix.Credentials.self, from: JSONResponses.login)
        let store = try await GRDBDataStore(userId: creds.userId, deviceId: creds.deviceId)

        let session = try Matrix.Session(creds: creds, startSyncing: false, dataStore: store)
        var initialState: [ClientEventWithoutRoomId] = []
        var messages: [ClientEventWithoutRoomId] = []

        let roomCreate = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.roomCreate)
        let roomName = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.name)
        let roomTopic = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.topic)
        let roomAvatarUrl = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.avatar)
        let roomTombstone = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.tombstone)
        let roomEncryption = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.encryption)
        initialState.append(contentsOf: [roomCreate, roomName, roomTopic, roomAvatarUrl, roomTombstone, roomEncryption])

        let roomMessage1 = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.message)
        let roomMessage2 = try ClientEventWithoutRoomId(content: Matrix.mTextContent(msgtype: Matrix.MessageType.text,
                                                                                     body: "bar message"),
                                                        eventId: "$bar123:foo.com",
                                                        originServerTS: 4321,
                                                        sender: UserId("@bar:foo.com")!,
                                                        type: Matrix.EventType.mRoomMessage)
        let roomMessage3 = try ClientEventWithoutRoomId(content: Matrix.mTextContent(msgtype: Matrix.MessageType.text,
                                                                                     body: "foo message"),
                                                        eventId: "$foo123:bar.com",
                                                        originServerTS: 1234,
                                                        sender: UserId("@foo:bar.com")!,
                                                        type: Matrix.EventType.mRoomMessage)

        messages.append(contentsOf: [roomMessage1, roomMessage2])

        var room = try Matrix.Room(roomId: RoomId("!foo:bar.com")!, session: session,
                                   initialState: initialState, initialMessages: messages)
        let originalRoom = try Matrix.Room(roomId: RoomId("!foo:bar.com")!, session: session,
                                           initialState: initialState, initialMessages: messages)

        // Verify proper key retrevial for later validation
        let test1: Matrix.Room? = try Matrix.Room(roomId: RoomId("!bar:foo.com")!,
                                                  session: session, initialState: initialState)
        try await store.save(test1)

        let test2: Matrix.Room? = try Matrix.Room(roomId: RoomId("!baz:oof.com")!,
                                                  session: session, initialState: initialState)
        try await store.save(test2)

        // Save/load validation
        try await store.save(room)
        room.name = "Another room name"
        room.topic = "Another topic"
        room.messages.insert(roomMessage3)

        room = try await store.load(Matrix.Room.self, key: room.roomId, session: session)!
        XCTAssertEqual(room.name, originalRoom.name)
        XCTAssertEqual(room.topic, originalRoom.topic)
        XCTAssertEqual(room.messages, originalRoom.messages)
        
        // Remove
        try await store.remove(room)
        var newRoom = try await store.load(Matrix.Room.self, key: room.roomId)
        XCTAssertNil(newRoom)
        
        // Remove by key
        try await store.save(room)
        try await store.remove(Matrix.Room.self, key: room.roomId)
        newRoom = try await store.load(Matrix.Room.self, key: room.roomId, session: session)
        XCTAssertNil(newRoom)
        
        // Save all / load all validation
        try await store.clearStore()
        try await store.saveAll([room, test1, test2])
        
        var roomList = try await store.loadAll(Matrix.Room.self, session: session)!
        XCTAssertEqual(roomList.count, 3)
        XCTAssertEqual(room.name, originalRoom.name)
        XCTAssertEqual(room.topic, originalRoom.topic)
        XCTAssertEqual(room.messages, originalRoom.messages)

        // Remove all
        try await store.removeAll(roomList)
        roomList = try await store.loadAll(Matrix.Room.self, session: session)!
        XCTAssertEqual(roomList.count, 0)
    }

    func testDataStoreSession() async throws {
        let decoder = JSONDecoder()
        let creds = try decoder.decode(Matrix.Credentials.self, from: JSONResponses.login)
        let store = try await GRDBDataStore(userId: creds.userId, deviceId: creds.deviceId)

        let session = try Matrix.Session(creds: creds, startSyncing: false, dataStore: store)
        var initialState: [ClientEventWithoutRoomId] = []
        var messages: [ClientEventWithoutRoomId] = []
        var stateEvents: [StrippedStateEvent] = []

        let roomCreate = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.roomCreate)
        let roomName = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.name)
        let roomTopic = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.topic)
        let roomAvatarUrl = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.avatar)
        let roomTombstone = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.tombstone)
        let roomEncryption = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.encryption)
        initialState.append(contentsOf: [roomCreate, roomName, roomTopic, roomAvatarUrl, roomTombstone, roomEncryption])
        
        let roomCreate2 = try decoder.decode(StrippedStateEvent.self, from: JSONResponses.RoomEvent.roomCreate)
        let roomName2 = try decoder.decode(StrippedStateEvent.self, from: JSONResponses.RoomEvent.name)
        let roomTopic2 = try decoder.decode(StrippedStateEvent.self, from: JSONResponses.RoomEvent.topic)
        let roomAvatarUrl2 = try decoder.decode(StrippedStateEvent.self, from: JSONResponses.RoomEvent.avatar)
        let roomTombstone2 = try decoder.decode(StrippedStateEvent.self, from: JSONResponses.RoomEvent.tombstone)
        let roomEncryption2 = try decoder.decode(StrippedStateEvent.self, from: JSONResponses.RoomEvent.encryption)
        let roomMember1_temp = try decoder.decode(StrippedStateEvent.self, from: JSONResponses.RoomEvent.member1)
        let roomMember1 = StrippedStateEvent(sender: roomMember1_temp.sender, stateKey: creds.userId.description,
                                             type: roomMember1_temp.type, content: roomMember1_temp.content)
        let roomMember2_temp = try decoder.decode(StrippedStateEvent.self, from: JSONResponses.RoomEvent.member2)
        let roomMember2 = StrippedStateEvent(sender: roomMember2_temp.sender, stateKey: creds.userId.description,
                                             type: roomMember2_temp.type, content: roomMember2_temp.content)
        stateEvents.append(contentsOf: [roomCreate2, roomName2, roomTopic2, roomAvatarUrl2, roomTombstone2,
                                        roomEncryption2, roomMember1, roomMember2])

        let roomName3 = try ClientEventWithoutRoomId(content: RoomNameContent(name: "foo"), eventId: "$foo:bar.com",
                                                     originServerTS: 1234, sender: UserId("@foo:bar.com")!,
                                                     type: Matrix.EventType.mRoomName)
        let roomName4 = try ClientEventWithoutRoomId(content: RoomNameContent(name: "bar"), eventId: "$bar:foo.com",
                                                     originServerTS: 4321, sender: UserId("@bar:foo.com")!,
                                                     type: Matrix.EventType.mRoomName)
        let roomMessage1 = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.message)
        let roomMessage2 = try ClientEventWithoutRoomId(content: Matrix.mTextContent(msgtype: Matrix.MessageType.text,
                                                                                     body: "bar message"),
                                                        eventId: "$bar123:foo.com",
                                                        originServerTS: 4321,
                                                        sender: UserId("@bar:foo.com")!,
                                                        type: Matrix.EventType.mRoomMessage)
        let roomMessage3 = try ClientEventWithoutRoomId(content: Matrix.mTextContent(msgtype: Matrix.MessageType.text,
                                                                                     body: "foo message"),
                                                        eventId: "$foo123:bar.com",
                                                        originServerTS: 1234,
                                                        sender: UserId("@foo:bar.com")!,
                                                        type: Matrix.EventType.mRoomMessage)

        messages.append(contentsOf: [roomName3, roomName4, roomMessage1, roomMessage2, roomMessage3])

        // Verify proper key retrevial for later validation
        let test1: Matrix.Room = try Matrix.Room(roomId: RoomId("!bar:foo.com")!,
                                                 session: session, initialState: initialState,
                                                 initialMessages: messages)
        let test2: Matrix.Room = try Matrix.Room(roomId: RoomId("!baz:oof.com")!,
                                                 session: session, initialState: initialState,
                                                 initialMessages: messages)
        let test3: Matrix.InvitedRoom = try Matrix.InvitedRoom(session: session,
                                                               roomId: RoomId("!rab:oof.com")!,
                                                               stateEvents: stateEvents)
        let test4: Matrix.InvitedRoom = try Matrix.InvitedRoom(session: session,
                                                               roomId: RoomId("!oof:rab.com")!,
                                                               stateEvents: stateEvents)

        session.displayName = "foo"
        session.rooms = [test1.roomId: test1, test2.roomId: test2]
        session.invitations = [test3.roomId: test3, test4.roomId: test4]
        let originalSession = try Matrix.Session(creds: creds, startSyncing: false, dataStore: store)
        originalSession.displayName = session.displayName
        originalSession.rooms = session.rooms
        originalSession.invitations = session.invitations

        // Save/load validation
        try await store.save(session)
        session.displayName = "bar"
        session.rooms = [:]
        session.invitations = [:]

        let newSession = try await store.load(Matrix.Session.self, key: (session.creds.userId, session.creds.deviceId))!
        XCTAssertEqual(newSession.displayName, originalSession.displayName)
        XCTAssertEqual(newSession.rooms.isEmpty, false)
        XCTAssertEqual(newSession.invitations.isEmpty, false)

        // Remove
        try await store.remove(session)
        var newSession2: Matrix.Session? = try await store.load(Matrix.Session.self,
                                                                key: (session.creds.userId, session.creds.deviceId))
        XCTAssertNil(newSession2)

        // Remove by key
        try await store.save(session)
        try await store.remove(Matrix.Session.self, key: (session.creds.userId, session.creds.deviceId))
        newSession2 = try await store.load(Matrix.Session.self, key: (session.creds.userId, session.creds.deviceId))
        XCTAssertNil(newSession2)

        // Save all / load all validation
        try await store.clearStore()
        var creds2 = Matrix.Credentials(userId: UserId("@foo:bar.com")!, deviceId: "abc123", accessToken: "def456")
        creds2.wellKnown = Matrix.WellKnown(homeserverUrl: "https://foo.bar")
        let session2 = try Matrix.Session(creds: creds2, startSyncing: false)
        try await store.saveAll([session, session2])

        var sessionList = try await store.loadAll(Matrix.Session.self)!
        XCTAssertEqual(sessionList.count, 2)

        // Remove all
        try await store.removeAll(sessionList)
        sessionList = try await store.loadAll(Matrix.Session.self)!
        XCTAssertEqual(sessionList.count, 0)
    }
    
    func testDataStoreUser() async throws {
        let decoder = JSONDecoder()
        let creds = try decoder.decode(Matrix.Credentials.self, from: JSONResponses.login)
        let store = try await GRDBDataStore(userId: creds.userId, deviceId: creds.deviceId)
        let session = try Matrix.Session(creds: creds, startSyncing: false, dataStore: store)

        // Verify proper key retrevial for later validation
        let test1 = Matrix.User(userId: UserId("@foo:bar.com")!, session: session)
        try await store.save(test1)

        let test2 = Matrix.User(userId: UserId("@bar:foo.com")!, session: session)
        let originalTest2 = Matrix.User(userId: UserId("@bar:foo.com")!, session: session)
        
        test2.avatarUrl = "https://bar.foo"
        test2.displayName = "BarFoo"
        test2.statusMessage = "status"
        originalTest2.avatarUrl = "https://bar.foo"
        originalTest2.displayName = "BarFoo"
        originalTest2.statusMessage = "status"
        try await store.save(test2)
        
        // Save/load validation
        test2.displayName = "Raboof"
        test2.statusMessage = "sutats"

        let newTest2 = try await store.load(Matrix.User.self, key: test2.id, session: session)!
        XCTAssertEqual(originalTest2.id, newTest2.id)
//        XCTAssertEqual(test2.session, newTest2.session)
        XCTAssertEqual(originalTest2.displayName, newTest2.displayName)
        XCTAssertEqual(originalTest2.avatarUrl, newTest2.avatarUrl)
        XCTAssertEqual(originalTest2.statusMessage, newTest2.statusMessage)

        // Remove
        try await store.remove(test1)
        var newUser = try await store.load(Matrix.User.self, key: test1.id)
        XCTAssertNil(newUser)

        // Remove by key
        try await store.save(test1)
        try await store.remove(Matrix.User.self, key: test1.id)
        newUser = try await store.load(Matrix.User.self, key: test1.id)
        XCTAssertNil(newUser)

        // Save all / load all validation
        try await store.clearStore()
        try await store.saveAll([test1, test2])
        var userList = try await store.loadAll(Matrix.User.self)!
        XCTAssertEqual([test1, test2].count, userList.count)

        // Remove all
        try await store.removeAll(userList)
        userList = try await store.loadAll(Matrix.User.self)!
        XCTAssertEqual(userList.count, 0)
    }
}
