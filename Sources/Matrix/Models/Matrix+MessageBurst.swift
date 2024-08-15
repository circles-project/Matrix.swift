//
//  Matrix+MessageBurst.swift
//
//
//  Created by Charles Wright on 8/14/24.
//

import Foundation
import Combine

extension Matrix {
    // Contains a series of messages all from the same sender,
    // for easier rendering into a chat timeline with SwiftUI
    public class MessageBurst: ObservableObject, Identifiable {
        @Published public var messages: [Matrix.Message]
        public var room: Matrix.Room
        public var sender: Matrix.User
        public var startingEventId: EventId
        
        // Combine framework stuff, so we can re-publish updates from our Messages and get re-drawn when one of them updates
        private var sinks: [EventId: Cancellable] = [:]
        
        public init?(messages: [Matrix.Message]) {
            guard let firstMessage = messages.first
            else {
                return nil
            }
            
            self.messages = messages
            self.room = firstMessage.room
            self.sender = firstMessage.sender
            self.startingEventId = firstMessage.eventId
            
            for message in messages {
                // Also re-publish changes from this message
                self.sinks[message.eventId] = message.objectWillChange
                                                     .receive(on: DispatchQueue.main)
                                                     .sink { _ in
                                                         self.objectWillChange.send()
                                                     }
            }
        }
        
        @MainActor
        public func append(_ message: Matrix.Message) async throws {
            guard message.sender == self.sender
            else {
                Matrix.logger.error("Can't append message to burst - sender does not match")
                throw Matrix.Error("Can't append message to burst")
            }
            
            messages.append(message)
            
            // Also re-publish changes from this message
            self.sinks[message.eventId] = message.objectWillChange
                                                 .receive(on: DispatchQueue.main)
                                                 .sink { _ in
                                                     self.objectWillChange.send()
                                                 }
        }
        
        @MainActor
        public func prepend(_ message: Matrix.Message) async throws {
            guard message.sender == self.sender
            else {
                Matrix.logger.error("Can't prepend message to burst - sender does not match")
                throw Matrix.Error("Can't prepend message to burst")
            }
            
            messages.insert(message, at: 0)
            
            // Also re-publish changes from this message
            self.sinks[message.eventId] = message.objectWillChange
                                                 .receive(on: DispatchQueue.main)
                                                 .sink { _ in
                                                     self.objectWillChange.send()
                                                 }
        }
        
        public var isEmpty: Bool {
            messages.isEmpty
        }
        
        public var startTime: Date? {
            messages.first?.timestamp
        }
        
        public var endTime: Date? {
            messages.last?.timestamp
        }
        
        public func isBefore(date: Date) -> Bool {
            if let end = self.endTime,
               end < date
            {
                return true
            }
            else {
                return false
            }
        }
        
        public func isAfter(date: Date) -> Bool {
            if let start = self.startTime,
               start > date
            {
                return true
            }
            else {
                return false
            }
        }
        
        public func contains(date: Date) -> Bool {
            guard let start = self.startTime,
                  let end = self.endTime
            else {
                return false
            }
            
            return start <= date && date <= end
        }
        
        public var id: String {
            self.startingEventId
        }
    }
    
}
