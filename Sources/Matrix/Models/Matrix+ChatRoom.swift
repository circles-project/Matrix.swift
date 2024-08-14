//
//  Matrix+ChatRoom.swift
//  
//
//  Created by Charles Wright on 8/14/24.
//

import Foundation

extension Matrix {
    
    public class ChatRoom: Matrix.Room {
        
        @Published public var bursts: [MessageBurst]
        
        required init(roomId: RoomId,
                      session: Matrix.Session,
                      initialState: [ClientEventWithoutRoomId],
                      initialTimeline: [ClientEventWithoutRoomId] = [],
                      initialAccountData: [Matrix.AccountDataEvent] = [],
                      initialReadReceipt: EventId? = nil,
                      onLeave: (() async throws -> Void)? = nil
        ) throws {
            
            self.bursts = [] // Initialize bursts to empty so we can call the parent constructor
            
            try super.init(roomId: roomId, session: session, initialState: initialState, initialTimeline: initialTimeline, initialAccountData: initialAccountData, initialReadReceipt: initialReadReceipt, onLeave: onLeave)
            
            // This last bit needs to happen asynchronously because the MessageBurst's messages are @Published, and so is our list of bursts
            Task {
                // Now that the parent Room class is initialized, we can go back through, look at all of our messages, and assign them into bursts based on their sender
                var currentBurst: MessageBurst? = nil
                let topLevelMessages = self.messages
                    .filter { $0.relatedEventId == nil }
                    .sorted { $0.timestamp < $1.timestamp }
                for message in topLevelMessages {
                    if let burst = currentBurst,
                       message.sender == burst.sender
                    {
                        try? await burst.append(message)
                    } else {
                        if let newBurst = MessageBurst(messages: [message]) {
                            await MainActor.run {
                                self.bursts.append(newBurst)
                            }
                            currentBurst = newBurst
                        }
                    }
                }
            }
        }
        
        public override func updateTimeline(from events: [ClientEventWithoutRoomId]) async throws {
            // Use the parent class'es implementation to transform Events into Messages
            try await super.updateTimeline(from: events)
            
            // Now this is a bit clunky because we have to find which of our Messages are new
            let eventIds = Set(events.map { $0.eventId })
            let newMessages = self.messages.filter { eventIds.contains($0.eventId) }
                                           .sorted { $0.timestamp < $1.timestamp }
            
            // For each new message, find which burst it might go with
            for message in newMessages {
                // FIXME: Python's array bisect would be great here, but :sigh: instead we're just going to do it the dumb and simple way
                
                if let burstBefore = self.bursts.last(where: { $0.isBefore(date: message.timestamp) }),
                   burstBefore.sender == message.sender
                {
                    try? await burstBefore.append(message)
                }
                else if let burstAfter = self.bursts.first(where: { $0.isAfter(date: message.timestamp) }),
                        burstAfter.sender == message.sender
                {
                    try? await burstAfter.prepend(message)
                }
                else {
                    if let newBurst = MessageBurst(messages: [message]) {
                        self.bursts.append(newBurst)
                    }
                }
            }
        }
    }

}
