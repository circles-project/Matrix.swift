import XCTest
import Matrix
@testable import DataStore

final class DataStoreTests: XCTestCase {
    func testDataStoreInitialization() async throws {
        let decoder = JSONDecoder()
        let credentials = try decoder.decode(Matrix.Credentials.self, from: JSONResponses.login)
        let store = try await GRDBDataStore(userId: credentials.userId, deviceId: credentials.deviceId)

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.url.path))

        addTeardownBlock {
            try FileManager.default.removeItem(atPath: store.url.path)
        }
    }

    func testDataStoreClear() throws {

    }

    func testDataStoreModelCredentials() async throws {
        let decoder = JSONDecoder()
        var creds = try decoder.decode(Matrix.Credentials.self, from: JSONResponses.login)
        let store = try await GRDBDataStore(userId: creds.userId, deviceId: creds.deviceId)

        // Verify proper key retrevial for later validation
        var test1 = Matrix.Credentials(userId: UserId("@foo:bar.com")!, deviceId: "foobar", accessToken: "baz")
        try await test1.save(store)

        var test2 = Matrix.Credentials(userId: UserId("@bar:foo.com")!, deviceId: "barfoo", accessToken: "zab")

        // Save/load validation
        try await creds.save(store)
        creds.accessToken = "def456"
        creds.expiresInMs = 999999
        creds.refreshToken = nil
        creds.homeServer = "https://example.org"
        creds.wellKnown?.homeserver.baseUrl = "https://org.example"
        creds.wellKnown?.identityserver?.baseUrl = "https://org.example.id"

        creds = try await creds.load(store)!
        let originalCreds = try decoder.decode(Matrix.Credentials.self, from: JSONResponses.login)
        XCTAssertEqual(creds.accessToken, originalCreds.accessToken)
        XCTAssertEqual(creds.deviceId, originalCreds.deviceId)
        XCTAssertEqual(creds.expiresInMs, originalCreds.expiresInMs)
        XCTAssertEqual(creds.refreshToken, originalCreds.refreshToken)
        XCTAssertEqual(creds.userId, originalCreds.userId)
        XCTAssertEqual(creds.wellKnown!.homeserver.baseUrl, originalCreds.wellKnown!.homeserver.baseUrl)
        XCTAssertEqual(creds.wellKnown!.identityserver!.baseUrl, originalCreds.wellKnown!.identityserver!.baseUrl)

        // Initialization
        let initCreds = try await Matrix.Credentials.load(store, key: (originalCreds.userId, originalCreds.deviceId))!
        XCTAssertEqual(initCreds.accessToken, originalCreds.accessToken)
        XCTAssertEqual(initCreds.deviceId, originalCreds.deviceId)
        XCTAssertEqual(initCreds.expiresInMs, originalCreds.expiresInMs)
        XCTAssertEqual(initCreds.refreshToken, originalCreds.refreshToken)
        XCTAssertEqual(initCreds.userId, originalCreds.userId)
        XCTAssertEqual(initCreds.wellKnown!.homeserver.baseUrl, originalCreds.wellKnown!.homeserver.baseUrl)
        XCTAssertEqual(initCreds.wellKnown!.identityserver!.baseUrl, originalCreds.wellKnown!.identityserver!.baseUrl)

        // Delete
        try await creds.remove(store)
        let newCreds = try await creds.load(store)
        XCTAssertNil(newCreds)

    }

    func testDataStoreModelRoom() async throws {
        let decoder = JSONDecoder()
        var creds = try decoder.decode(Matrix.Credentials.self, from: JSONResponses.login)
        let store = try await GRDBDataStore(userId: creds.userId, deviceId: creds.deviceId)

        var session = try Matrix.Session(creds: creds)
        var initialState: [ClientEventWithoutRoomId] = []
        
        var roomCreate = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.roomCreate)
        var roomName = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.name)
        var roomTopic = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.topic)
        //var roomAvatarUrl = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.avatar)
        var roomTombstone = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.tombstone)
        var roomEncryption = try decoder.decode(ClientEventWithoutRoomId.self, from: JSONResponses.RoomEvent.encryption)
        
        
        initialState.append(contentsOf: [roomCreate, roomName, roomTopic, roomTombstone, roomEncryption]) // roomAvatarUrl
        
        var room = try Matrix.Room(roomId: RoomId("!foo:bar.com")!, session: session, initialState: initialState)
        let originalRoom = try Matrix.Room(roomId: RoomId("!foo:bar.com")!, session: session, initialState: initialState)
                
        // Verify proper key retrevial for later validation
        var test1 = try Matrix.Room(roomId: RoomId("!bar:foo.com")!, session: session, initialState: initialState)
        try await test1.save(store)

        var test2 = try Matrix.Room(roomId: RoomId("!baz:oof.com")!, session: session, initialState: initialState)

        print("ROOM INFO")
        print(room.name, room.topic, room.avatarUrl, room.predecessorRoomId, room.successorRoomId, room.tombstoneEventId,
              room.messages, room.localEchoEvent, room.highlightCount, room.notificationCount,
              room.joinedMembers, room.invitedMembers, room.leftMembers, room.bannedMembers, room.knockingMembers, room.encryptionParams) // avatar
        
        
        
        
        
//        public let roomId: RoomId
//        public let session: Session
//
//        public let type: String?
//        public let version: String
//
//        @Published public var name: String?
//        @Published public var topic: String?
//        @Published public var avatarUrl: MXC?
//        @Published public var avatar: NativeImage?
//
//        public let predecessorRoomId: RoomId?
//        public let successorRoomId: RoomId?
//        public let tombstoneEventId: EventId?
//
//        @Published public var messages: Set<ClientEventWithoutRoomId>
//        @Published public var localEchoEvent: Event?
//
//        @Published public var highlightCount: Int = 0
//        @Published public var notificationCount: Int = 0
//
//        @Published public var joinedMembers: Set<UserId> = []
//        @Published public var invitedMembers: Set<UserId> = []
//        @Published public var leftMembers: Set<UserId> = []
//        @Published public var bannedMembers: Set<UserId> = []
//        @Published public var knockingMembers: Set<UserId> = []
//
//        @Published public var encryptionParams: RoomEncryptionContent?
        
        // Save/load validation
        try await room.save(store)
        
        room.name = "Another room name"
//        creds.accessToken = "def456"
//        creds.expiresInMs = 999999
//        creds.refreshToken = nil
//        creds.homeServer = "https://example.org"
//        creds.wellKnown?.homeserver.baseUrl = "https://org.example"
//        creds.wellKnown?.identityserver?.baseUrl = "https://org.example.id"

        print("loading room, before: \(room.name)")
        room = try await room.load(store)!
        print(room.name)
//        XCTAssertEqual(creds.accessToken, originalCreds.accessToken)
//        XCTAssertEqual(creds.deviceId, originalCreds.deviceId)
//        XCTAssertEqual(creds.expiresInMs, originalCreds.expiresInMs)
//        XCTAssertEqual(creds.refreshToken, originalCreds.refreshToken)
//        XCTAssertEqual(creds.userId, originalCreds.userId)
//        XCTAssertEqual(creds.wellKnown!.homeserver.baseUrl, originalCreds.wellKnown!.homeserver.baseUrl)
//        XCTAssertEqual(creds.wellKnown!.identityserver!.baseUrl, originalCreds.wellKnown!.identityserver!.baseUrl)

//        // Initialization
//        let initCreds = try await Matrix.Credentials(store, key: (originalCreds.userId, originalCreds.deviceId))!
//        XCTAssertEqual(initCreds.accessToken, originalCreds.accessToken)
//        XCTAssertEqual(initCreds.deviceId, originalCreds.deviceId)
//        XCTAssertEqual(initCreds.expiresInMs, originalCreds.expiresInMs)
//        XCTAssertEqual(initCreds.refreshToken, originalCreds.refreshToken)
//        XCTAssertEqual(initCreds.userId, originalCreds.userId)
//        XCTAssertEqual(initCreds.wellKnown!.homeserver.baseUrl, originalCreds.wellKnown!.homeserver.baseUrl)
//        XCTAssertEqual(initCreds.wellKnown!.identityserver!.baseUrl, originalCreds.wellKnown!.identityserver!.baseUrl)
//
//        // Delete
//        try await creds.remove(store)
//        let newCreds = try await creds.load(store)
//        XCTAssertNil(newCreds)

        
    }

    func testDataStoreUserLogin() async throws {
        // uses pre-existing user db and attempts login from stored credentials
    }

    func testDataStoreSync() async throws {
        // test saving sync data to store
    }

}
