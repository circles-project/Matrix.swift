//
//  TicketTaskQueue.swift
//
//
//  Created by Charles Wright on 4/7/22.
//

import Foundation

public actor TicketTaskQueue<T: Sendable> {
    
    public struct TicketTaskQueueError: Error {
        var msg: String
        init(_ msg: String) {
            self.msg = msg
        }
    }
    
    private actor TicketQueue {
        private var tickets: [UInt64] = []
        
        func new() -> UInt64 {
            let ticket = UInt64.random(in: UInt64.min...UInt64.max)
            tickets.append(ticket)
            return ticket
        }
        
        func first() -> UInt64? {
            tickets.first
        }
        
        func pop() {
            tickets.removeFirst()
        }
    }
    
    private var ticketQueue = TicketQueue()
    private var currentTask: Task<T,Error>?
    
    public func run(block: @escaping () async throws -> T) async throws -> T {
        // Add ourselves to the queue
        let ticket = await ticketQueue.new()
                
        // This is like we're trying to grab the lock
        var currentTicket = await ticketQueue.first()
        // Is it our turn yet???
        while currentTicket != ticket {
            // Failed to get the lock -- Ok fine it's not our turn
            // Find the current task that's running
            if let runningTask = currentTask {
                // And wait until the current thing is done
                let _ = try await runningTask.value
            }
            // Now we get another try to see if it's our turn.
            currentTicket = await ticketQueue.first()
        }
        // Now we've got the lock
        
        // Set up our task and let it run with our block of code
        let task: Task<T,Error> = Task {
            do {
                // Run the code that we came here to run
                let result = try await block()
                // Release the lock (ie, take our ticket off of the front of the queue)
                await ticketQueue.pop()
                // And notify all threads waiting on the lock
                return result
            } catch {
                // Unblock the queue, so the next task in line can have its turn
                await ticketQueue.pop()
                throw TicketTaskQueueError("Child task #\(ticket) failed")
            }
        }
        // Now our task is running
        // Set the current task so that others have something to wait on
        currentTask = task
        
        // Wait until our code actually finishes
        // And return whatever value it produced
        return try await task.value
    }
    
    
}
