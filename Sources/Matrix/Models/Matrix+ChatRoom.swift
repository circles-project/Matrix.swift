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
            
            logger.debug("ChatRoom: updating timeline")
            
            // Now this is a bit clunky because we have to find which of our Messages are new
            let eventIds = Set(events.map { $0.eventId })
            let newMessages = self.messages.filter { eventIds.contains($0.eventId) }
                                           .sorted { $0.timestamp < $1.timestamp }
            
            logger.debug("ChatRoom: Assigning \(newMessages.count) new messages to bursts")
            // For each new message, find which burst it might go with
            for message in newMessages {
                // FIXME: Python's array bisect would be great here, but :sigh: instead we're just going to do it the dumb and simple way
                
                logger.debug("ChatRoom: Assigning message \(message.eventId)")
                
                // First, let's see which thread we are on
                let threadId = message.threadId ?? ""
                
                if let bestMatchBurst = self.bursts[threadId]?.first(where: {$0.includes(date: message.timestamp)}) {
                    logger.debug("ChatRoom: Found a burst that contains our message")
                    if bestMatchBurst.sender == message.sender {
                        logger.debug("ChatRoom: Sender matches")
                        try? await bestMatchBurst.append(message)
                        continue
                    } else {
                        logger.debug("ChatRoom: Best match burst doesn't match")
                        // Now we have a problem - Our bursts are not in a nice chronological, non-overlapping order
                        // We thought we had an unbroken burst of messages from bestMatchBurst.sender but now message.sender is butting in
                        // The fix is to split this existing burst in two, and insert a new burst, containing the new message, in between
                                                
                        let startBursts: [MessageBurst] = self.bursts[threadId]?.prefix(while: {$0.isBefore(date: message.timestamp)}) ?? []
                        
                        guard let middleBursts = try? bestMatchBurst.splitOn(message: message)
                        else {
                            Matrix.logger.error("Failed to split a burst of messages")
                            continue
                        }
                        
                        let endBursts = Array( self.bursts[threadId]?.suffix(from: startBursts.count) ?? [])
                        
                        let newBursts = startBursts + middleBursts + endBursts
                        
                        await MainActor.run {
                            self.bursts[threadId] = newBursts
                        }
                    }
                    
                }
                
                // Check to see if we have a burst from this user just before this message
                if let burstBefore = self.bursts[threadId]?.last(where: { $0.isBefore(date: message.timestamp) })
                {
                    logger.debug("ChatRoom: Found burst before the message")
                    if burstBefore.sender == message.sender {
                        logger.debug("ChatRoom: Sender matches")
                        try? await burstBefore.append(message)
                        continue
                    } else {
                        logger.debug("ChatRoom: Burst before doesn't match")
                    }
                }
                // Or maybe this is an older message, and we have a burst from this user right after it?
                if let burstAfter = self.bursts[threadId]?.first(where: { $0.isAfter(date: message.timestamp) })
                {
                    logger.debug("ChatRoom: Found burst before the message")
                    if burstAfter.sender == message.sender {
                        logger.debug("ChatRoom: Burst after matches")
                        try? await burstAfter.prepend(message)
                        continue
                    } else {
                        logger.debug("ChatRoom: Burst after doesn't match")
                    }
                }
                // Looks like this message doesn't fit with any existing burst
                logger.debug("ChatRoom: Looks like we need a new burst")
                // Find the list of bursts in its thread
                let threadBursts = self.bursts[threadId] ?? []
                // Create a new burst sent from this user on this thread
                if let newBurst = MessageBurst(messages: [message]) {
                    // And add it to the current list for the thread
                    await MainActor.run {
                        self.bursts[threadId] = threadBursts + [newBurst]
                    }
                }
                
                logger.debug("ChatRoom: Done assigning message \(message.eventId)")
            }
        }
    }

}
