//
//  UIASession.swift
//  
//
//  Created by Charles Wright on 6/22/23.
//

import Foundation
import AnyCodable
import BlindSaltSpeke

@available(macOS 12.0, *)

public enum UIASessionState {
    case notConnected
    case connected(UIAA.SessionState)
    case inProgress(UIAA.SessionState,[String])
    case finished(Data)
}

public protocol UIASession {
    
    var url: URL { get }
    
    var state: UIASessionState { get }
    
    var storage: [String: Any] { get }
    
    var sessionId: String? { get }
    
    func connect() async throws
    
    func selectFlow(flow: UIAA.Flow) async
    
    func doUIAuthStage(auth: [String:Codable]) async throws
    
    func doTermsStage() async throws
 
    func doEmailRequestTokenStage(email: String) async throws -> String?
    func doEmailSubmitTokenStage(token: String, secret: String) async throws
    
    func doBSSpekeEnrollOprfStage(userId: UserId, password: String) async throws
    func doBSSpekeEnrollOprfStage(password: String) async throws
    func doBSSpekeEnrollSaveStage() async throws
    
    func doBSSpekeLoginOprfStage(userId: UserId, password: String) async throws
    func doBSSpekeLoginOprfStage(password: String) async throws
    func doBSSpekeLoginVerifyStage() async throws
    
    func getBSSpekeClient() -> BlindSaltSpeke.ClientSession?
}
