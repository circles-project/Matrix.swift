//
//  Matrix+ChatRoom.swift
//  
//
//  Created by Charles Wright on 8/14/24.
//

import Foundation

extension Matrix {
    
    public class ChatRoom: Matrix.Room {
        
        // We keep a list of bursts for each thread in the room
        // This way we can render each thread nicely as a series of bursts of messages from different users
        @Published public var bursts: [EventId: [MessageBurst]] = [:]
        
        required init(roomId: RoomId,
                      session: Matrix.Session,
                      initialState: [ClientEventWithoutRoomId],
                      initialTimeline: [ClientEventWithoutRoomId] = [],
                      initialAccountData: [Matrix.AccountDataEvent] = [],
                      initialReadReceipt: EventId? = nil,
                      onLeave: (() async throws -> Void)? = nil
        ) throws {
            
            self.bursts = [:] // Initialize bursts to empty so we can call the parent constructor
            
            try super.init(roomId: roomId, session: session, initialState: initialState, initialTimeline: initialTimeline, initialAccountData: initialAccountData, initialReadReceipt: initialReadReceipt, onLeave: onLeave)
            
            // This last bit needs to happen asynchronously because the MessageBurst's messages are @Published, and so is our list of bursts, so we can't modify them in a sync context
            Task {
                // Now that the parent Room class is initialized, we can go back through, look at all of our messages, and assign them into bursts based on their sender
                
                let initialMessages = self.messages
                    .sorted { $0.timestamp < $1.timestamp }
                
                var currentBursts: [EventId: MessageBurst] = [:]
                
                // Assign each of the initial messages to bursts
                for message in initialMessages {
                    let threadId = message.threadId ?? ""
                
                    // Do we have a currently active burst of messages on this thread from this sender?
                    if let burst = currentBursts[threadId],
                       message.sender == burst.sender
                    {
                        // If so, assign the message there
                        try? await burst.append(message)
                    } else {
                        // Otherwise, there is no currently active burst for this thread/user combo
                        
                        // Find the list of bursts for the given thread
                        let threadBursts = self.bursts[threadId] ?? []
                        
                        // Create a new burst from this user
                        if let newBurst = MessageBurst(messages: [message]) {
                            // And add it to the given thread
                            await MainActor.run {
                                self.bursts[threadId] = threadBursts + [newBurst]
                            }
                            currentBursts[threadId] = newBurst
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
                
                // First, let's see which thread we are on
                let threadId = message.threadId ?? ""
                
                // Check to see if we have a burst from this user just before this message
                if let burstBefore = self.bursts[threadId]?.last(where: { $0.isBefore(date: message.timestamp) }),
                   burstBefore.sender == message.sender
                {
                    try? await burstBefore.append(message)
                }
                // Or maybe this is an older message, and we have a burst from this user right after it?
                else if let burstAfter = self.bursts[threadId]?.first(where: { $0.isAfter(date: message.timestamp) }),
                        burstAfter.sender == message.sender
                {
                    try? await burstAfter.prepend(message)
                }
                // Looks like this message doesn't fit with any existing burst
                else {
                    // Find the list of bursts in its thread
                    let threadBursts = self.bursts[threadId] ?? []
                    // Create a new burst sent from this user on this thread
                    if let newBurst = MessageBurst(messages: [message]) {
                        // And add it to the current list for the thread
                        await MainActor.run {
                            self.bursts[threadId] = threadBursts + [newBurst]
                        }
                    }
                }
            }
        }
    }

}
