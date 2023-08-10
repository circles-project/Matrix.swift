//
//  GRDBDataStoreTests.swift
//  
//
//  Created by Charles Wright on 3/1/23.
//

import XCTest

@testable import Matrix

final class GRDBDataStoreTests: XCTestCase {
 
    var userId = UserId("@bob:example.com")!
    var store: GRDBDataStore?
    var logger = Matrix.logger
    
    override func setUp() async throws {
        store = try await GRDBDataStore(userId: userId, type: .persistent(preserve: false))
    }
    
    override func tearDown() async throws {
        try await store?.close()
    }
    
    func testSaveAndLoadTimeline() async throws {
        let roomId = RoomId.random()
        let range = 0 ..< 10
        let originalEvents: [ClientEventWithoutRoomId] = range.compactMap { i -> ClientEventWithoutRoomId? in
            try? ClientEventWithoutRoomId(content: Matrix.mTextContent(msgtype: M_TEXT, body: "This is message \(i)."),
                                          eventId: EventId.random(),
                                          originServerTS: UInt64(Date().timeIntervalSince1970 * 1000),
                                          sender: UserId.random(),
                                          type: M_ROOM_MESSAGE)
        }
        print("✅ generated \(originalEvents.count) events")
        guard let store = self.store
        else {
            throw "No store"
        }
        print("✅ got data store")
        
        try await store.saveTimeline(events: originalEvents, in: roomId)
        print("✅ saved events to timeline")
        
        let loadedEvents = try await store.loadTimeline(for: roomId)
        print("✅ loaded \(loadedEvents.count) timeline events from the datastore")
        
        XCTAssert(originalEvents.count == loadedEvents.count)
        
        for originalEvent in originalEvents {
            guard let loadedEvent = loadedEvents.first(where: { $0.eventId == originalEvent.eventId })
            else {
                throw "Could not find a matching event for event \(originalEvent.eventId)"
            }
            logger.debug("found loaded event for \(originalEvent.eventId)")
            XCTAssert(loadedEvent.type == originalEvent.type)
            XCTAssert(loadedEvent.stateKey == originalEvent.stateKey)
            XCTAssert(loadedEvent.originServerTS == originalEvent.originServerTS)
            XCTAssert(loadedEvent.sender == originalEvent.sender)
            
            guard let originalContent = originalEvent.content as? Matrix.mTextContent,
                  let loadedContent = loadedEvent.content as? Matrix.mTextContent
            else {
                throw "Could not parse event content"
            }
            XCTAssert(loadedContent.msgtype == originalContent.msgtype)
            XCTAssert(loadedContent.body == originalContent.body)

            print("✅ event \(originalEvent.eventId) matches")
        }
    }
    
    func testSaveAndLoadState() async throws {
        let roomId = RoomId.random()
        let creationEvent = try ClientEventWithoutRoomId(content: RoomCreateContent(creator: UserId.random(),
                                                                                    federate: true,
                                                                                    predecessor: nil,
                                                                                    roomVersion: "9",
                                                                                    type: nil),
                                                         eventId: .random(),
                                                         originServerTS: UInt64(Date().timeIntervalSince1970 * 1000),
                                                         sender: .random(),
                                                         stateKey: "",
                                                         type: M_ROOM_CREATE)
        let nameEvent1 = try ClientEventWithoutRoomId(content: RoomNameContent(name: "Original Name"),
                                                      eventId: .random(),
                                                      originServerTS: UInt64(Date().timeIntervalSince1970 * 1000),
                                                      sender: .random(),
                                                      stateKey: "",
                                                      type: M_ROOM_NAME)
        let topicEvent1 = try ClientEventWithoutRoomId(content: RoomTopicContent(topic: "Original Topic"),
                                                       eventId: .random(),
                                                       originServerTS: UInt64(Date().timeIntervalSince1970 * 1000),
                                                       sender: .random(),
                                                       stateKey: "",
                                                       type: M_ROOM_TOPIC)
        let nameEvent2 = try ClientEventWithoutRoomId(content: RoomNameContent(name: "New Name"),
                                                      eventId: .random(),
                                                      originServerTS: UInt64(Date().timeIntervalSince1970 * 1000),
                                                      sender: .random(),
                                                      stateKey: "",
                                                      type: M_ROOM_NAME)
        print("✅ generated state events")

        guard let store = self.store
        else {
            throw "Store is not initialized"
        }
        print("✅ got data store")

        try await store.saveState(events: [creationEvent, nameEvent1, topicEvent1, nameEvent2], in: roomId)
        print("✅ saved state to store")

        let loadedEvents = try await store.loadState(for: roomId, limit: 1000)
        XCTAssert(loadedEvents.count == 3)
        print("✅ got the correct number of events")
        /*
        for loadedEvent in loadedEvents {
            print("event\t\(loadedEvent.eventId)\ntype\t\(loadedEvent.type)\nstateKey\t\(loadedEvent.stateKey ?? "(none)")")
        }
        */

        for originalEvent in [creationEvent, nameEvent2, topicEvent1] {
            logger.debug("Looking for an event of type \(originalEvent.type) ...")
            let e = loadedEvents.first(where: { $0.type == originalEvent.type && $0.stateKey == originalEvent.stateKey })
            XCTAssertNotNil(e)
            guard let loadedEvent = e
            else {
                throw "No matching event for \(originalEvent.eventId) (\(originalEvent.type))"
            }
            logger.debug("found loaded event for \(originalEvent.eventId)")
            XCTAssert(loadedEvent.type == originalEvent.type)
            XCTAssert(loadedEvent.stateKey == originalEvent.stateKey)
            XCTAssert(loadedEvent.originServerTS == originalEvent.originServerTS)
            XCTAssert(loadedEvent.sender == originalEvent.sender)
            
            switch originalEvent.type {
            case M_ROOM_CREATE:
                XCTAssertNotNil(originalEvent.content as? RoomCreateContent)
                XCTAssertNotNil(loadedEvent.content as? RoomCreateContent)
                let originalContent = originalEvent.content as! RoomCreateContent
                let loadedContent = loadedEvent.content as! RoomCreateContent
                XCTAssert(originalContent.roomVersion == loadedContent.roomVersion)
                XCTAssert(originalContent.type == loadedContent.type)
                XCTAssert(originalContent.creator == loadedContent.creator)
                XCTAssert(originalContent.federate == loadedContent.federate)
                XCTAssertNil(originalContent.predecessor)
                XCTAssertNil(loadedContent.predecessor)
            case M_ROOM_NAME:
                XCTAssertNotNil(originalEvent.content as? RoomNameContent)
                XCTAssertNotNil(loadedEvent.content as? RoomNameContent)
                let originalContent = originalEvent.content as! RoomNameContent
                let loadedContent = loadedEvent.content as! RoomNameContent
                XCTAssert(originalContent.name == loadedContent.name)
            case M_ROOM_TOPIC:
                XCTAssertNotNil(originalEvent.content as? RoomTopicContent)
                XCTAssertNotNil(loadedEvent.content as? RoomTopicContent)
                let originalContent = originalEvent.content as! RoomTopicContent
                let loadedContent = loadedEvent.content as! RoomTopicContent
                XCTAssert(originalContent.topic == loadedContent.topic)
            default:
                logger.error("Got unexpected event type \(originalEvent.type)")
                XCTAssert(false)
            }
        }
        print("✅ all events matched")
    }
}
