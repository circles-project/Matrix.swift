//
//  Matrix+Session.swift
//  
//
//  Created by Charles Wright on 12/5/22.
//

import Foundation

#if !os(macOS)
import UIKit
#else
import AppKit
#endif

extension Matrix {
    public class Session: Matrix.Client, ObservableObject {
        @Published public var displayName: String?
        @Published public var avatarUrl: URL?
        @Published public var avatar: Matrix.NativeImage?
        @Published public var statusMessage: String?
        
        // cvw: Leaving these as comments for now, as they require us to define even more types
        //@Published public var device: MatrixDevice
        
        @Published public var rooms: [RoomId: Matrix.Room]
        @Published public var invitations: [RoomId: Matrix.InvitedRoom]
        
        // cvw: Stuff that we need to add, but haven't got to yet
        public var accountData: [Matrix.AccountDataType: Codable]

        // Need some private stuff that outside callers can't see
        private var dataStore: DataStore?
        private var syncRequestTask: Task<String?,Swift.Error>? // FIXME Use a TaskGroup to make this subordinate to the backgroundSyncTask
        private var syncToken: String? = nil
        private var syncRequestTimeout: Int = 30_000
        private var keepSyncing: Bool
        private var syncDelayNS: UInt64 = 30_000_000_000
        private var backgroundSyncTask: Task<UInt,Swift.Error>? // FIXME use a TaskGroup
        
        // FIXME: Derive this from our account data???
        // The type is `m.ignored_user_list` https://spec.matrix.org/v1.5/client-server-api/#mignored_user_list
        private var ignoreUserIds: [UserId] {
            guard let content = self.accountData[.mIgnoredUserList] as? IgnoredUserListContent
            else {
                return []
            }
            return content.ignoredUsers
        }

        // We need to use the Matrix 'recovery' feature to back up crypto keys etc
        // This saves us from struggling with UISI errors and unverified devices
        private var recoverySecretKey: Data?
        private var recoveryTimestamp: Date?
        
        public init(creds: Credentials,
                    syncToken: String? = nil, startSyncing: Bool = true,
                    displayname: String? = nil, avatarUrl: MXC? = nil, statusMessage: String? = nil,
                    recoverySecretKey: Data? = nil, recoveryTimestamp: Data? = nil,
                    storageType: StorageType = .persistent
        ) async throws {
            self.rooms = [:]
            self.invitations = [:]
            self.accountData = [:]
                        
            self.keepSyncing = startSyncing
            // Initialize the sync tasks to nil so we can run super.init()
            self.syncRequestTask = nil
            self.backgroundSyncTask = nil
            
            // Another Swift annoyance.  It's hard (impossible) to have a hierarchy of objects that are all initialized together.
            // So we have to make the DataStore an optional in order for it to get a pointer to us.
            // And here we initialize it to nil so we can call super.init()
            self.dataStore = nil
            
            try super.init(creds: creds)

            // Phase 1 init is done -- Now we can reference `self`
            
            self.dataStore = try await GRDBDataStore(session: self, type: storageType)

            
            // Ok now we're initialized as a valid Matrix.Client (super class)
            // Are we supposed to start syncing?
            if startSyncing {
                backgroundSyncTask = .init(priority: .background) {
                    var count: UInt = 0
                    while keepSyncing {
                        let token = try await sync()
                        count += 1
                    }
                    return count
                }
            }
        }
        
        // MARK: Sync
        // https://spec.matrix.org/v1.2/client-server-api/#get_matrixclientv3sync
        @Sendable
        private func syncRequestTaskOperation() async throws -> String? {
            var url = "/_matrix/client/v3/sync?timeout=\(self.syncRequestTimeout)"
            if let token = syncToken {
                url += "&since=\(token)"
            }
            let (data, response) = try await self.call(method: "GET", path: url)
            
            let rawDataString = String(data: data, encoding: .utf8)
            print("\n\n\(rawDataString!)\n\n")
            
            guard response.statusCode == 200 else {
                print("ERROR: /sync got HTTP \(response.statusCode) \(response.description)")

                //return self.syncToken
                return nil
            }
            
            let decoder = JSONDecoder()
            //decoder.keyDecodingStrategy = .convertFromSnakeCase
            guard let responseBody = try? decoder.decode(SyncResponseBody.self, from: data)
            else {
                self.syncRequestTask = nil
                throw Matrix.Error("Could not decode /sync response")
            }
            
            // Process the sync response, updating local state
            
            // Handle invites
            if let invitedRoomsDict = responseBody.rooms?.invite {
                print("/sync:\t\(invitedRoomsDict.count) invited rooms")
                for (roomId, info) in invitedRoomsDict {
                    print("/sync:\tFound invited room \(roomId)")
                    guard let events = info.inviteState?.events
                    else {
                        continue
                    }
                    //if self.invitations[roomId] == nil {
                        let room = try InvitedRoom(session: self, roomId: roomId, stateEvents: events)
                        self.invitations[roomId] = room
                    //}
                }
            } else {
                print("/sync:\tNo invited rooms")
            }
            
            // Handle rooms where we're already joined
            if let joinedRoomsDict = responseBody.rooms?.join {
                print("/sync:\t\(joinedRoomsDict.count) joined rooms")
                for (roomId, info) in joinedRoomsDict {
                    print("/sync:\tFound joined room \(roomId)")
                    let stateEvents = info.state?.events ?? []
                    let timelineEvents = info.timeline?.events ?? []
                    
                    if let store = self.dataStore {
                        try await store.saveState(events: stateEvents, in: roomId)
                        try await store.save(events: timelineEvents, in: roomId)
                    }

                    if let room = self.rooms[roomId] {
                        print("\tWe know this room already")
                        print("\t\(stateEvents.count) new state events")
                        print("\t\(timelineEvents.count) new timeline events")

                        // Update the room with the latest data from `info`
                        try await room.updateState(from: stateEvents)
                        try await room.updateTimeline(from: timelineEvents)
                        
                        if let unread = info.unreadNotifications {
                            print("\t\(unread.notificationCount) notifications")
                            print("\t\(unread.highlightCount) highlights")
                            room.notificationCount = unread.notificationCount
                            room.highlightCount = unread.highlightCount
                        }
                        
                    } else {
                        // New approach: Don't automatically allocate a Room object for every room we know about
                        //               Let the application request them when it needs them.
                        //               This should save us substantial RAM and CPU for users who are in a large number of rooms.
                        
                        // Nevertheless, we should still remove the room id from the invited rooms
                        invitations.removeValue(forKey: roomId)
                    }
                }
            } else {
                print("/sync:\tNo joined rooms")
            }
            
            // Handle rooms that we've left
            if let leftRoomsDict = responseBody.rooms?.leave {
                print("/sync:\t\(leftRoomsDict.count) left rooms")
                for (roomId, info) in leftRoomsDict {
                    print("/sync:\tFound left room \(roomId)")
                    // TODO: What should we do here?
                    // For now, just make sure these rooms are taken out of the other lists
                    invitations.removeValue(forKey: roomId)
                    rooms.removeValue(forKey: roomId)
                }
            } else {
                print("/sync:\tNo left rooms")
            }
            
            // FIXME: Do something with AccountData
            
            // FIXME: Handle to-device messages

            print("/sync:\tUpdating sync token...  awaiting MainActor")
            await MainActor.run {
                print("/sync:\tMainActor updating sync token")
                self.syncToken = responseBody.nextBatch
                self.syncRequestTask = nil
            }

            print("/sync:\tDone!")
            return responseBody.nextBatch
        
        }
        public func sync() async throws -> String? {
            
            // FIXME: Use a TaskGroup
            syncRequestTask = syncRequestTask ?? .init(priority: .background, operation: syncRequestTaskOperation)
            
            guard let task = syncRequestTask else {
                print("Error: /sync Failed to launch sync request task")
                return nil
            }
            return try await task.value
        }

        
        public func pause() async throws {
            // pause() doesn't actually make any API calls
            // It just tells our own local sync task to take a break
            throw Matrix.Error("Not implemented yet")
        }
        
        public func close() async throws {
            // close() is like pause; it doesn't make any API calls
            // It just tells our local sync task to shut down
            throw Matrix.Error("Not implemented yet")
        }
        
        public func createRecovery(privateKey: Data) async throws {
            throw Matrix.Error("Not implemented yet")
        }
        
        public func deleteRecovery() async throws {
            throw Matrix.Error("Not implemented yet")
        }
        
        public func whoAmI() async throws -> UserId {
            return self.creds.userId
        }
        
        public override func getRoomStateEvents(roomId: RoomId) async throws -> [ClientEventWithoutRoomId] {
            let events = try await super.getRoomStateEvents(roomId: roomId)
            if let store = self.dataStore {
                try await store.saveState(events: events, in: roomId)
            }
            if let room = self.rooms[roomId] {
                try await room.updateState(from: events)
            }
            return events
        }
        
        public func getRoom(roomId: RoomId) async throws -> Matrix.Room? {
            if let existingRoom = self.rooms[roomId] {
                return existingRoom
            }
            
            // Apparently we don't already have a Room object for this one
            // Let's see if we can find the necessary data to construct it
            
            // Do we have this room in our data store?
            if let store = self.dataStore {
                return try await store.loadRoom(roomId)
            }
            
            // Ok we didn't have anything cached locally
            // Maybe the server knows about this room?
            let events = try await getRoomStateEvents(roomId: roomId)
            if let room = try? Matrix.Room(roomId: roomId, session: self, initialState: events, initialTimeline: []) {
                await MainActor.run {
                    self.rooms[roomId] = room
                }
                return room
            }
            
            // Looks like we got nothing
            return nil
        }
    }
}
