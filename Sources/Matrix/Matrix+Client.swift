//
//  Matrix+API.swift
//  Circles
//
//  Created by Charles Wright on 6/15/22.
//

import Foundation
#if !os(macOS)
import UIKit
#else
import AppKit
#endif

import AnyCodable

extension Matrix {
    
@available(macOS 12.0, *)
public class Client {
    public var creds: Matrix.Credentials
    public var baseUrl: URL
    public let version: String
    private var apiUrlSession: URLSession   // For making API calls
    private var mediaUrlSession: URLSession // For downloading media
    
    // MARK: Init
    
    public init(creds: Matrix.Credentials) throws {
        self.version = "v3"
        
        self.creds = creds
        
        let apiConfig = URLSessionConfiguration.default
        apiConfig.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Authorization": "Bearer \(creds.accessToken)",
        ]
        apiConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        apiConfig.httpMaximumConnectionsPerHost = 4 // Default is 6 but we're getting some 429's from Synapse...
        self.apiUrlSession = URLSession(configuration: apiConfig)
        
        let mediaConfig = URLSessionConfiguration.default
        mediaConfig.httpAdditionalHeaders = [
            "Authorization": "Bearer \(creds.accessToken)",
        ]
        mediaConfig.requestCachePolicy = .returnCacheDataElseLoad
        self.mediaUrlSession = URLSession(configuration: mediaConfig)
        
        guard let wk = creds.wellKnown
        else {
            let msg = "Homeserver info is required to instantiate a Matrix API"
            print(msg)
            throw Matrix.Error(msg)
        }
        
        self.baseUrl = URL(string: wk.homeserver.baseUrl)!
    }
    
    // MARK: API Call
    public func call(method: String,
                     path: String,
                     params: [String:String]? = nil,
                     body: Codable? = nil,
                     expectedStatuses: [Int] = [200]
    ) async throws -> (Data, HTTPURLResponse) {
        if let stringBody = body as? String {
            print("APICALL\t\(self.creds.userId) String request body = \n\(stringBody)")
            let data = stringBody.data(using: .utf8)!
            return try await call(method: method, path: path, params: params, bodyData: data, expectedStatuses: expectedStatuses)
        } else if let codableBody = body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let encodedBody = try encoder.encode(AnyCodable(codableBody))
            print("APICALL\t\(self.creds.userId) Raw request body = \n\(String(decoding: encodedBody, as: UTF8.self))")
            return try await call(method: method, path: path, params: params, bodyData: encodedBody, expectedStatuses: expectedStatuses)
        } else {
            let noBody: Data? = nil
            return try await call(method: method, path: path, params: params, bodyData: noBody, expectedStatuses: expectedStatuses)
        }

    }
    
    public func call(method: String,
                     path: String,
                     params: [String:String]? = nil,
                     bodyData: Data?=nil,
                     expectedStatuses: [Int] = [200]
    ) async throws -> (Data, HTTPURLResponse) {
        print("APICALL\t\(self.creds.userId) Calling \(method) \(path)")

        //let url = URL(string: path, relativeTo: baseUrl)!.appending(queryItems: queryItems)
        var components = URLComponents(url: URL(string: path, relativeTo: self.baseUrl)!, resolvingAgainstBaseURL: true)!
        if let urlParams = params {
            let queryItems: [URLQueryItem] = urlParams.map { (key,value) -> URLQueryItem in
                URLQueryItem(name: key, value: value)
            }
            components.queryItems = queryItems
        }
        let url = components.url!
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = bodyData
               
        var slowDown = true
        var delayNs: UInt64 = 1_000_000_000
        var count = 0
        
        repeat {
            let (data, response) = try await apiUrlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse
            else {
                let msg = "Couldn't handle HTTP response"
                print("APICALL\t\(self.creds.userId) \(msg)")
                throw Matrix.Error(msg)
            }
            
            if httpResponse.statusCode == 429 {
                slowDown = true

                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                if let rateLimitError = try? decoder.decode(Matrix.RateLimitError.self, from: data),
                   let delayMs = rateLimitError.retryAfterMs
                {
                    delayNs = 1_000_000 * UInt64(delayMs)
                } else {
                    delayNs *= 2
                }
                
                print("APICALL\t\(self.creds.userId) Got 429 error...  Waiting \(delayNs) nanosecs and then retrying")
                try await Task.sleep(nanoseconds: delayNs)
                
                count += 1
            } else {
                slowDown = false
                guard expectedStatuses.contains(httpResponse.statusCode)
                else {
                    let msg = "Matrix API call \(method) \(path) rejected with status \(httpResponse.statusCode)"
                    print("APICALL\t\(self.creds.userId) \(msg)")
                    let decoder = JSONDecoder()
                    if let errorResponse = try? decoder.decode(Matrix.ErrorResponse.self, from: data) {
                        print("APICALL\terrcode = \(errorResponse.errcode)\terror = \(errorResponse.error)")
                    } else {
                        let errorString = String(decoding: data, as: UTF8.self)
                        print("APICALL\tGot error response = \(errorString)")
                    }
                    throw Matrix.Error(msg)
                }
                print("APICALL\tGot response with status \(httpResponse.statusCode)")
                
                return (data, httpResponse)
            }
            
        } while slowDown && count < 5
        
        throw Matrix.Error("API call failed")
    }
    
    // MARK: My User Profile
    
    // https://spec.matrix.org/v1.2/client-server-api/#put_matrixclientv3profileuseriddisplayname
    public func setMyDisplayName(_ name: String) async throws {
        let (_, _) = try await call(method: "PUT",
                                    path: "/_matrix/client/\(version)/profile/\(creds.userId)/displayname",
                                    body: [
                                        "displayname": name,
                                    ])
    }
    
    public func setMyAvatarImage(_ image: NativeImage) async throws {
        // First upload the image
        let mxc = try await uploadImage(image, maxSize: CGSize(width: 256, height: 256))
        // Then set that as our avatar
        try await setMyAvatarUrl(mxc)
    }

    
    public func setMyAvatarUrl(_ mxc: MXC) async throws {
        let (_,_) = try await call(method: "PUT",
                                   path: "_matrix/client/\(version)/profile/\(creds.userId)/avatar_url",
                                   body: [
                                     "avatar_url": mxc,
                                   ])
    }
    
    public func setMyStatus(message: String) async throws {
        let body = [
            "presence": "online",
            "status_msg": message,
        ]
        try await call(method: "PUT", path: "/_matrix/client/\(version)/presence/\(creds.userId)/status", body: body)
    }
    
    // MARK: Other User Profiles
    
    public func getDisplayName(userId: UserId) async throws -> String? {
        let path = "/_matrix/client/\(version)/profile/\(userId)/displayname"
        let (data, response) = try await call(method: "GET", path: path)
        
        struct ResponseBody: Codable {
            var displayname: String?
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        guard let responseBody = try? decoder.decode(ResponseBody.self, from: data)
        else {
            return nil
        }
        
        return responseBody.displayname
    }
    
    // https://spec.matrix.org/v1.2/client-server-api/#get_matrixclientv3profileuseridavatar_url
    public func getAvatarUrl(userId: UserId) async throws -> String? {
        let path = "/_matrix/client/\(version)/profile/\(userId)/avatar_url"
        let (data, response) = try await call(method: "GET", path: path)
        
        struct ResponseBody: Codable {
            var avatarUrl: String?
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        guard let responseBody = try? decoder.decode(ResponseBody.self, from: data)
        else {
            return nil
        }
        
        return responseBody.avatarUrl
    }
    
    public func getAvatarImage(userId: UserId) async throws -> Matrix.NativeImage? {
        // Download the bytes from the given uri
        guard let uri = try await getAvatarUrl(userId: userId)
        else {
            let msg = "Couldn't get mxc:// URI"
            print("USER\t\(msg)")
            throw Matrix.Error(msg)
        }
        guard let mxc = MXC(uri)
        else {
            let msg = "Invalid mxc:// URI"
            print("USER\t\(msg)")
            throw Matrix.Error(msg)
        }
        
        let data = try await downloadData(mxc: mxc)
        
        // Create a UIImage or NSImage as appropriate
        let image = Matrix.NativeImage(data: data)
        
        // return the UIImage
        return image
    }

    
    public func getProfileInfo(userId: UserId) async throws -> (String?,MXC?) {
               
        let (data, response) = try await call(method: "GET", path: "/_matrix/client/\(version)/profile/\(userId)")
        
        struct UserProfileInfo: Codable {
            let displayName: String?
            let avatarUrl: MXC?
            
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let profileInfo: UserProfileInfo = try? decoder.decode(UserProfileInfo.self, from: data)
        else {
            let msg = "Failed to decode user profile"
            print(msg)
            throw Matrix.Error(msg)
        }
        
        return (profileInfo.displayName, profileInfo.avatarUrl)
    }
    
    // MARK: Account Data
    
    // https://spec.matrix.org/v1.2/client-server-api/#get_matrixclientv3useruseridaccount_datatype
    public func getAccountData<T>(for eventType: String, of dataType: T.Type) async throws -> T where T: Decodable {
        let path = "/_matrix/client/v3/user/\(creds.userId)/account_data/\(eventType)"
        let (data, response) = try await call(method: "GET", path: path)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let content = try decoder.decode(dataType, from: data)
        
        return content
    }
    
    // https://spec.matrix.org/v1.6/client-server-api/#put_matrixclientv3useruseridaccount_datatype
    public func putAccountData(_ content: Codable, for eventType: String) async throws {
        let path = "/_matrix/client/v3/user/\(creds.userId)/account_data/\(eventType)"
        let (data, response) = try await call(method: "PUT", path: path, body: content)
    }
    
    // MARK: Devices
    
    public func getDevices() async throws -> [Matrix.MyDevice] {
        let path = "/_matrix/client/\(version)/devices"
        let (data, response) = try await call(method: "GET", path: path)
        
        struct DeviceInfo: Codable {
            var deviceId: String
            var displayName: String?
            var lastSeenIp: String?
            var lastSeenTs: Int?
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let infos = try? decoder.decode([DeviceInfo].self, from: data)
        else {
            let msg = "Couldn't decode device info"
            print("DEVICES\t\(msg)")
            throw Matrix.Error(msg)
        }
        
        let devices = infos.map {
            Matrix.MyDevice(/*matrix: self,*/ deviceId: $0.deviceId, displayName: $0.displayName, lastSeenIp: $0.lastSeenIp, lastSeenUnixMs: $0.lastSeenTs)
        }
        
        return devices
    }
    
    public func getDevice(deviceId: String) async throws -> Matrix.MyDevice {
        let path = "/_matrix/client/\(version)/devices/\(deviceId)"
        let (data, response) = try await call(method: "GET", path: path)
        
        struct DeviceInfo: Codable {
            var deviceId: String
            var displayName: String?
            var lastSeenIp: String?
            var lastSeenTs: Int?
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let info = try? decoder.decode(DeviceInfo.self, from: data)
        else {
            let msg = "Couldn't decode info for device \(deviceId)"
            print("DEVICES\t\(msg)")
            throw Matrix.Error(msg)
        }
        
        let device = Matrix.MyDevice(/*matrix: self,*/ deviceId: info.deviceId, displayName: info.displayName, lastSeenIp: info.lastSeenIp, lastSeenUnixMs: info.lastSeenTs)
        
        return device
    }
    
    public func setDeviceDisplayName(deviceId: String, displayName: String) async throws {
        let path = "/_matrix/client/\(version)/devices/\(deviceId)"
        let (data, response) = try await call(method: "PUT",
                                              path: path,
                                              body: [
                                                "display_name": displayName
                                              ])
    }
    
    // https://spec.matrix.org/v1.3/client-server-api/#delete_matrixclientv3devicesdeviceid
    // FIXME This must support UIA.  Return a UIAASession???
    public func deleteDevice(deviceId: String) async throws -> UIAuthSession<EmptyStruct>? {
        let path = "/_matrix/client/\(version)/devices/\(deviceId)"
        let (data, response) = try await call(method: "DELETE",
                                              path: path,
                                              body: nil,
                                              expectedStatuses: [200,401])
        switch response.statusCode {
        case 200:
            // No need to do UIA.  Maybe we recently authenticated ourselves for another API call?
            // Anyway, we're happy.  Tell the caller that we're good to go; no more work to do.
            return nil
        case 401:
            // We need to auth
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            guard let uiaState = try? decoder.decode(UIAA.SessionState.self, from: data)
            else {
                let msg = "Could not decode UIA info"
                print("API\t\(msg)")
                throw Matrix.Error(msg)
            }
            let uiaSession = UIAuthSession<EmptyStruct>(method: "DELETE", url: URL(string: path, relativeTo: baseUrl)!, credentials: creds, requestDict: [:])
            uiaSession.state = .connected(uiaState)
            
            return uiaSession
        default:
            throw Matrix.Error("Got unexpected response")
        }
    }
    
    // MARK: Rooms
    
    // https://spec.matrix.org/v1.2/client-server-api/#get_matrixclientv3joined_rooms
    public func getJoinedRoomIds() async throws -> [RoomId] {
        
        let (data, response) = try await call(method: "GET", path: "/_matrix/client/\(version)/joined_rooms")
        
        struct ResponseBody: Codable {
            var joinedRooms: [RoomId]
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let responseBody = try? decoder.decode(ResponseBody.self, from: data)
        else {
            let msg = "Failed to decode list of joined rooms"
            print("GETJOINEDROOMS\t\(msg)")
            throw Matrix.Error(msg)
        }
        
        return responseBody.joinedRooms
    }
    
    // https://spec.matrix.org/v1.2/client-server-api/#post_matrixclientv3createroom
    public func createRoom(name: String,
                    type: String? = nil,
                    encrypted: Bool = true,
                    invite userIds: [UserId] = [],
                    direct: Bool = false
    ) async throws -> RoomId {
        print("CREATEROOM\tCreating room with name=[\(name)] and type=[\(type ?? "(none)")]")
        
        struct CreateRoomRequestBody: Codable {
            var creation_content: [String: String] = [:]
            
            struct StateEvent: Matrix.Event {
                var content: Codable
                var stateKey: String
                var type: String
                
                enum CodingKeys: String, CodingKey {
                    case content
                    case stateKey = "state_key"
                    case type
                }
                
                init(type: String, stateKey: String = "", content: Codable) {
                    self.type = type
                    self.stateKey = stateKey
                    self.content = content
                }
                
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.stateKey = try container.decode(String.self, forKey: .stateKey)
                    self.type = try container.decode(String.self, forKey: .type)
                    //let minimal = try MinimalEvent(from: decoder)
                    //self.content = minimal.content
                    self.content = try Matrix.decodeEventContent(of: type, from: decoder)
                }
                
                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode(stateKey, forKey: .stateKey)
                    try container.encode(type, forKey: .type)
                    try container.encode(AnyCodable(content), forKey:.content)
                }
            }
            var initial_state: [StateEvent]?
            var invite: [String]?
            var invite_3pid: [String]?
            var is_direct: Bool = false
            var name: String?
            enum Preset: String, Codable {
                case private_chat
                case public_chat
                case trusted_private_chat
            }
            var preset: Preset = .private_chat
            var room_alias_name: String?
            var room_version: String = "7"
            var topic: String?
            enum Visibility: String, Codable {
                case pub = "public"
                case priv = "private"
            }
            var visibility: Visibility = .priv
            
            init(name: String, type: String? = nil, encrypted: Bool) {
                self.name = name
                if encrypted {
                    let encryptionEvent = StateEvent(
                        type: M_ROOM_ENCRYPTION,
                        stateKey: "",
                        content: RoomEncryptionContent()
                    )
                    self.initial_state = [encryptionEvent]
                }
                if let roomType = type {
                    self.creation_content = ["type": roomType]
                }
            }
        }
        let requestBody = CreateRoomRequestBody(name: name, type: type, encrypted: encrypted)
        
        print("CREATEROOM\tSending Matrix API request...")
        let (data, response) = try await call(method: "POST",
                                    path: "/_matrix/client/\(version)/createRoom",
                                    body: requestBody)
        print("CREATEROOM\tGot Matrix API response")
        
        struct CreateRoomResponseBody: Codable {
            var roomId: String
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let responseBody = try? decoder.decode(CreateRoomResponseBody.self, from: data)
        else {
            let msg = "Failed to decode response from server"
            print(msg)
            throw Matrix.Error(msg)
        }
        
        return RoomId(responseBody.roomId)!
    }
    
    public func sendStateEvent(to roomId: RoomId,
                        type: String,
                        content: Codable,
                        stateKey: String = ""
    ) async throws -> EventId {
        print("SENDSTATE\tSending state event of type [\(type)] to room [\(roomId)]")
        
        let txnId = "\(UInt16.random(in: UInt16.min...UInt16.max))"
        let (data, response) = try await call(method: "PUT",
                                              path: "/_matrix/client/\(version)/rooms/\(roomId)/state/\(type)/\(stateKey)/\(txnId)",
                                              body: content)
        struct ResponseBody: Codable {
            var eventId: EventId
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let responseBody = try? decoder.decode(ResponseBody.self, from: data)
        else {
            let msg = "Failed to decode state event response"
            print(msg)
            throw Matrix.Error(msg)
        }
    
        return responseBody.eventId
    }
    
    // https://spec.matrix.org/v1.5/client-server-api/#put_matrixclientv3roomsroomidsendeventtypetxnid
    public func sendMessageEvent(to roomId: RoomId,
                          type: String,
                          content: Codable
    ) async throws -> EventId {
        print("SENDMESSAGE\tSending message event of type [\(type)] to room [\(roomId)]")

        let txnId = "\(UInt16.random(in: UInt16.min...UInt16.max))"
        let (data, response) = try await call(method: "PUT",
                                              path: "/_matrix/client/\(version)/rooms/\(roomId)/send/\(type)/\(txnId)",
                                              body: content)
        
        struct ResponseBody: Codable {
            var eventId: EventId
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let responseBody = try? decoder.decode(ResponseBody.self, from: data)
        else {
            let msg = "Failed to decode state event response"
            print(msg)
            throw Matrix.Error(msg)
        }
    
        return responseBody.eventId
    }
    
    // "m.reaction relationships are not currently specified, but are shown here for their conceptual place in a threaded DAG. They are currently proposed as MSC2677."
    // See MSC2677: https://github.com/matrix-org/matrix-spec-proposals/pull/2677
    public func addReaction(reaction: String,
                            to eventId: EventId,
                            in roomId: RoomId
    ) async throws -> EventId {
        let content = ReactionContent(eventId: eventId, reaction: reaction)
        return try await sendMessageEvent(to: roomId, type: M_REACTION, content: content)
    }
    
    public func sendRedactionEvent(to roomId: RoomId,
                            for eventId: EventId,
                            reason: String? = nil
    ) async throws -> EventId {
        print("REDACT\tSending redaction for event [\(eventId)] to room [\(roomId)]")
        
        let txnId = "\(UInt16.random(in: UInt16.min...UInt16.max))"
        let (data, response) = try await call(method: "PUT",
                                              path: "/_matrix/client/\(version)/rooms/\(roomId)/redact/\(eventId)/\(txnId)",
                                              body: ["reason": reason])
        
        struct ResponseBody: Codable {
            var eventId: EventId
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let responseBody = try? decoder.decode(ResponseBody.self, from: data)
        else {
            let msg = "Failed to decode state event response"
            print(msg)
            throw Matrix.Error(msg)
        }
    
        return responseBody.eventId
    }
    
    public func sendReport(for eventId: EventId,
                    in roomId: RoomId,
                    score: Int,
                    reason: String? = nil
    ) async throws {
        print("REPORT\tSending report for event [\(eventId)] in room [\(roomId)]")
        
        let txnId = "\(UInt16.random(in: UInt16.min...UInt16.max))"
        let (data, response) = try await call(method: "PUT",
                                              path: "/_matrix/client/\(version)/rooms/\(roomId)/report/\(eventId)/\(txnId)",
                                              body: [
                                                "reason": AnyCodable(reason),
                                                "score": AnyCodable(score)
                                              ])
    }
    
    
    // MARK: Room tags
    
    public func addTag(roomId: RoomId, tag: String, order: Float? = nil) async throws {
        let path = "/_matrix/client/\(version)/user/\(creds.userId)/rooms/\(roomId)/tags/\(tag)"
        let body = ["order": order ?? Float.random(in: 0.0 ..< 1.0)]
        let _ = try await call(method: "PUT", path: path, body: body)
    }
    
    private func getTagEventContent(roomId: RoomId) async throws -> TagContent {
        let path = "/_matrix/client/\(version)/user/\(creds.userId)/rooms/\(roomId)/tags"
        let (data, response) = try await call(method: "GET", path: path, body: nil)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let tagContent = try? decoder.decode(TagContent.self, from: data)
        else {
            let msg = "Failed to decode room tag content"
            print(msg)
            throw Matrix.Error(msg)
        }
        
        return tagContent
    }
    
    public func getTags(roomId: RoomId) async throws -> [String] {
        let tagContent = try await getTagEventContent(roomId: roomId)
        let tags: [String] = [String](tagContent.tags.keys)
        return tags
    }
    
    // MARK: Room Metadata

    public func setAvatarImage(roomId: RoomId, image: NativeImage) async throws {
        let maxSize = CGSize(width: 640, height: 640)
        
        guard let scaledImage = image.downscale(to: maxSize)
        else {
            let msg = "Failed to downscale image"
            print(msg)
            throw Matrix.Error(msg)
        }
        
        guard let jpegData = scaledImage.jpegData(compressionQuality: 0.90)
        else {
            let msg = "Failed to compress image"
            print(msg)
            throw Matrix.Error(msg)
        }
        
        guard let mxc = try? await uploadData(data: jpegData, contentType: "image/jpeg") else {
            let msg = "Failed to upload image for room avatar"
            print(msg)
            throw Matrix.Error(msg)
        }
        
        let info = mImageInfo(h: Int(scaledImage.size.height),
                              w: Int(scaledImage.size.width),
                              mimetype: "image/jpeg",
                              size: jpegData.count)
        
        let _ = try await sendStateEvent(to: roomId, type: M_ROOM_AVATAR, content: RoomAvatarContent(mxc: mxc, info: info))
    }

    
    public func getAvatarImage(roomId: RoomId) async throws -> Matrix.NativeImage? {
        guard let content = try? await getRoomState(roomId: roomId, eventType: M_ROOM_AVATAR) as? RoomAvatarContent
        else {
            // No avatar for this room???
            return nil
        }
        
        let data = try await downloadData(mxc: content.mxc)
        let image = Matrix.NativeImage(data: data)
        return image
    }
    
    public func setTopic(roomId: RoomId, topic: String) async throws {
        let _ = try await sendStateEvent(to: roomId, type: M_ROOM_TOPIC, content: ["topic": topic])
    }
    
    public func setRoomName(roomId: RoomId, name: String) async throws {
        try await sendStateEvent(to: roomId, type: M_ROOM_NAME, content: RoomNameContent(name: name))
    }
    
    public func getRoomName(roomId: RoomId) async throws -> String? {
        guard let content = try await getRoomState(roomId: roomId, eventType: M_ROOM_NAME) as? RoomNameContent
        else {
            return nil
        }
        return content.name
    }
    
    // MARK: Room Messages
    
    // https://spec.matrix.org/v1.2/client-server-api/#get_matrixclientv3roomsroomidmessages
    // Good news!  `from` is no longer required as of v1.3 (June 2022),
    // so we no longer have to call /sync before fetching messages.
    public func getMessages(roomId: RoomId,
                            forward: Bool = false,
                            from startToken: String? = nil,
                            to endToken: String? = nil,
                            limit: UInt? = 25
    ) async throws -> RoomMessagesResponseBody {
        let path = "/_matrix/client/v3/rooms/\(roomId)/messages"
        var params: [String:String] = [
            "dir" : forward ? "f" : "b",
        ]
        if let start = startToken {
            params["from"] = start
        }
        if let end = endToken {
            params["to"] = end
        }
        if let limit = limit {
            params["limit"] = "\(limit)"
        }
        let (data, response) = try await call(method: "GET", path: path, params: params)
        
        let decoder = JSONDecoder()
        
        let responseBody = try decoder.decode(RoomMessagesResponseBody.self, from: data)
        
        return responseBody
    }
    
    // https://spec.matrix.org/v1.2/client-server-api/#get_matrixclientv3roomsroomidjoined_members
    public func getJoinedMembers(roomId: RoomId) async throws -> [UserId] {
        let path = "/_matrix/client/\(version)/rooms/\(roomId)/joined_members"
        let (data, response) = try await call(method: "GET", path: path)
        let string = String(decoding: data, as: UTF8.self)
        print("getJoinedMembers:\t\(self.creds.userId) Got response = \(string)")
        
        struct ResponseBody: Codable {
            struct RoomMember: Codable {
                var avatarUrl: String?
                var displayName: String?
                enum CodingKeys: String, CodingKey {
                    case avatarUrl = "avatar_url"
                    case displayName = "displayname"
                }
            }
            var joined: [UserId: RoomMember]
        }
        
        let decoder = JSONDecoder()
        //decoder.keyDecodingStrategy = .convertFromSnakeCase
        let responseBody = try decoder.decode(ResponseBody.self, from: data)
        let users = [UserId](responseBody.joined.keys)
        return users
    }
    
    // https://spec.matrix.org/v1.2/client-server-api/#get_matrixclientv3roomsroomidstate
    // FIXME This actually returns [ClientEvent] but we're returning the version without the roomid in order to match /sync
    // It's possible that we're introducing a vulnerability here -- The server could return events from other rooms
    // OTOH it can already do that when we call /sync, so what's new?
    public func getRoomStateEvents(roomId: RoomId) async throws -> [ClientEventWithoutRoomId] {
        let path = "/_matrix/client/\(version)/rooms/\(roomId)/state"
        
        let (data, response) = try await call(method: "GET", path: path)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let events = try decoder.decode([ClientEventWithoutRoomId].self, from: data)
        return events
    }
    
    public func getRoomState(roomId: RoomId, eventType: String, with stateKey: String = "") async throws -> Codable {
        let path = "/_matrix/client/\(version)/rooms/\(roomId)/state/\(eventType)/\(stateKey)"
        let (data, response) = try await call(method: "GET", path: path)
        
        let decoder = JSONDecoder()

        guard let codableType = Matrix.eventTypes[eventType],
              let content = try? decoder.decode(codableType.self, from: data)
        else {
            let msg = "Couldn't decode room state for event type \(eventType)"
            print(msg)
            throw Matrix.Error(msg)
        }
        
        return content
    }
    
    public func inviteUser(roomId: RoomId, userId: UserId, reason: String? = nil) async throws {
        let path = "/_matrix/client/\(version)/rooms/\(roomId)/invite"
        let (data, response) = try await call(method: "POST",
                                              path: path,
                                              body: [
                                                "user_id": "\(userId)",
                                                "reason": reason
                                              ])
        // FIXME: Parse and handle any Matrix 400 or 403 errors
    }
    
    public func kickUser(roomId: RoomId, userId: UserId, reason: String? = nil) async throws {
        let path = "/_matrix/client/\(version)/rooms/\(roomId)/kick"
        let (data, response) = try await call(method: "POST",
                                              path: path,
                                              body: [
                                                "user_id": "\(userId)",
                                                "reason": reason
                                              ])
    }
    
    public func banUser(roomId: RoomId, userId: UserId, reason: String? = nil) async throws {
        let path = "/_matrix/client/\(version)/rooms/\(roomId)/ban"
        let (data, response) = try await call(method: "POST",
                                              path: path,
                                              body: [
                                                "user_id": "\(userId)",
                                                "reason": reason
                                              ])
    }
    
    public func join(roomId: RoomId, reason: String? = nil) async throws {
        let path = "/_matrix/client/\(version)/rooms/\(roomId)/join"
        let (data, response) = try await call(method: "POST",
                                              path: path,
                                              body: [
                                                "reason": reason
                                              ])
    }
    
    public func knock(roomId: RoomId, reason: String? = nil) async throws {
        let path = "/_matrix/client/\(version)/knock/\(roomId)"
        let (data, response) = try await call(method: "POST",
                                              path: path,
                                              body: [
                                                "reason": reason
                                              ])
    }
    
    public func leave(roomId: RoomId, reason: String? = nil) async throws {
        let path = "/_matrix/client/\(version)/rooms/\(roomId)/leave"
        let (data, response) = try await call(method: "POST",
                                              path: path,
                                              body: [
                                                "reason": reason
                                              ])
    }
    
    public func forget(roomId: RoomId) async throws {
        let path = "/_matrix/client/\(version)/rooms/\(roomId)/forget"
        let (data, response) = try await call(method: "POST", path: path)
    }
    
    public func getRoomPowerLevels(roomId: RoomId) async throws -> [String: Int] {
        throw Matrix.Error("Not implemented")
    }
    
    // MARK: Spaces
    
    public func createSpace(name: String) async throws -> RoomId {
        print("CREATESPACE\tCreating space with name [\(name)]")
        let roomId = try await createRoom(name: name, type: "m.space", encrypted: false)
        return roomId
    }
    
    public func addSpaceChild(_ child: RoomId, to parent: RoomId) async throws {
        print("SPACES\tAdding [\(child)] as a child space of [\(parent)]")
        let servers = Array(Set([child.domain, parent.domain]))
        let order = (0x20 ... 0x7e).randomElement()?.description ?? "A"
        let content = SpaceChildContent(order: order, via: servers)
        let _ = try await sendStateEvent(to: parent, type: M_SPACE_CHILD, content: content, stateKey: child.description)
    }
    
    public func addSpaceParent(_ parent: RoomId, to child: RoomId, canonical: Bool = false) async throws {
        let servers = Array(Set([child.domain, parent.domain]))
        let content = SpaceParentContent(canonical: canonical, via: servers)
        let _ = try await sendStateEvent(to: child, type: M_SPACE_PARENT, content: content, stateKey: parent.description)
    }
    
    // https://spec.matrix.org/v1.5/client-server-api/#get_matrixclientv1roomsroomidhierarchy
    public func getSpaceChildren(_ roomId: RoomId) async throws -> [RoomId] {
        var children: [RoomId] = []
        var nextBatch: String? = nil
        
        repeat {
            var path = "/_matrix/client/v1/rooms/\(roomId)/hierarchy?max_depth=1"
            if let start = nextBatch {
                path += "&from=\(start)"
            }
            let (data, response) = try await call(method: "GET", path: path)
            
            struct SpaceHierarchyResponseBody: Decodable {
                var nextBatch: String?
                var rooms: [ChildRoomsChunk]
                
                enum CodingKeys: String, CodingKey {
                    case nextBatch = "next_batch"
                    case rooms
                }
                
                struct ChildRoomsChunk: Decodable {
                    var avatarUrl: MXC?
                    var canonicalAlias: String?
                    var childrenState: [StrippedStateEvent]
                    var guestCanJoin: Bool
                    var joinRule: RoomJoinRuleContent.JoinRule?
                    var name: String?
                    var numJoinedMembers: Int
                    var roomId: RoomId
                    var roomType: String?
                    var topic: String?
                    var worldReadable: Bool
                    
                    enum CodingKeys: String, CodingKey {
                        case avatarUrl = "avatar_url"
                        case canonicalAlias = "canonical_alias"
                        case childrenState = "children_state"
                        case guestCanJoin = "guest_can_join"
                        case joinRule = "join_rule"
                        case name
                        case numJoinedMembers = "num_joined_members"
                        case roomId = "room_id"
                        case roomType = "room_type"
                        case topic
                        case worldReadable = "world_readable"
                    }
                }
            }
            let decoder = JSONDecoder()
            let hierarchy = try decoder.decode(SpaceHierarchyResponseBody.self, from: data)
            nextBatch = hierarchy.nextBatch
            children += hierarchy.rooms.map { $0.roomId }
        } while nextBatch != nil
                    
        return children
    }
    
    public func removeSpaceChild(_ child: RoomId, from parent: RoomId) async throws {
        print("SPACES\tRemoving [\(child)] as a child space of [\(parent)]")
        let order = "\(0x7e)"
        let content = SpaceChildContent(order: order, via: nil)  // This stupid `via = nil` thing is the only way we have to remove a child relationship
        let _ = try await sendStateEvent(to: parent, type: M_SPACE_CHILD, content: content, stateKey: child.description)
    }
    

    
    // MARK: Media API
    
    public func downloadData(mxc: MXC) async throws -> Data {
        let path = "/_matrix/media/\(version)/download/\(mxc.serverName)/\(mxc.mediaId)"
        
        let url = URL(string: path, relativeTo: baseUrl)!
        let request = URLRequest(url: url)
        
        let (data, response) = try await mediaUrlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            let msg = "Failed to download media"
            print("DOWNLOAD\t\(msg)")
            throw Matrix.Error(msg)
        }
        
        return data
    }
    
    public func uploadImage(_ original: NativeImage, maxSize: CGSize, quality: CGFloat = 0.90) async throws -> MXC {
        guard let scaled = original.downscale(to: maxSize)
        else {
            let msg = "Failed to downscale image"
            print(msg)
            throw Matrix.Error(msg)
        }
        
        let uri = try await uploadImage(scaled, quality: quality)
        return uri
    }

    
    public func uploadImage(_ image: NativeImage, quality: CGFloat = 0.90) async throws -> MXC {

        guard let jpeg = image.jpegData(compressionQuality: quality)
        else {
            let msg = "Failed to encode image as JPEG"
            print(msg)
            throw Matrix.Error(msg)
        }
        
        return try await uploadData(data: jpeg, contentType: "image/jpeg")
    }

    
    public func uploadData(data: Data, contentType: String) async throws -> MXC {
        
        let url = URL(string: "/_matrix/media/\(version)/upload", relativeTo: baseUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        let (responseData, response) = try await mediaUrlSession.upload(for: request, from: data)
        
        guard let httpResponse = response as? HTTPURLResponse,
              [200].contains(httpResponse.statusCode)
        else {
            let msg = "Upload request failed"
            print(msg)
            throw Matrix.Error(msg)
        }
        
        struct UploadResponse: Codable {
            var contentUri: String
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let responseBody = try? decoder.decode(UploadResponse.self, from: responseData)
        else {
            let msg = "Failed to decode upload response"
            print(msg)
            throw Matrix.Error(msg)
        }
        
        guard let mxc = MXC(responseBody.contentUri)
        else {
            let msg = "Could not parse MXC URL"
            print(msg)
            throw Matrix.Error(msg)
        }
        return mxc
    }
}

} // end extension Matrix
