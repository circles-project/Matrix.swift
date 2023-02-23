//
//  Matrix+decoding.swift
//  
//
//  Created by Charles Wright on 10/26/22.
//

import Foundation

extension Matrix {
    
    public static func decodeEventContent(of eventType: String, from data: Data) throws -> Codable {
        let decoder = JSONDecoder()
        if let codableType = eventTypes[eventType] {
            let content = try decoder.decode(codableType.self, from: data)
            return content
        }
        if eventType == M_ROOM_MESSAGE {
            // Peek into the content struct to examine the `msgtype`
            struct MinimalMessageContent: Codable {
                var msgtype: String
            }
            let mmc = try decoder.decode(MinimalMessageContent.self, from: data)
            let msgtype = mmc.msgtype
            
            guard let codableType = messageTypes[msgtype]
            else {
                throw Matrix.Error("Cannot decode unknown message type \(msgtype)")
            }
            
            let content = try decoder.decode(codableType.self, from: data)
            return content
        }
        
        throw Matrix.Error("Cannot decode unknown event type \(eventType)")
    }
    
    public static func decodeEventContent(of eventType: String, from decoder: Decoder) throws -> Codable {
        let container = try decoder.container(keyedBy: MinimalEvent.CodingKeys.self)

        if let codableType = eventTypes[eventType] {
            let content = try container.decode(codableType.self, forKey: .content)
            return content
        }
        
        if eventType == M_ROOM_MESSAGE {
            // Peek into the content struct to examine the `msgtype`
            struct MinimalMessageContent: Codable {
                var msgtype: String
            }
            let mmc = try container.decode(MinimalMessageContent.self, forKey: .content)
            // Now use the msgtype to determine how we decode the content
            guard let codableType = messageTypes[mmc.msgtype]
            else {
                throw Matrix.Error("Cannot decode unknown message type \(mmc.msgtype)")
            }
            let content = try container.decode(codableType.self, forKey: .content)
            return content
        }
        
        throw Matrix.Error("Cannot decode unknown event type \(eventType)")
        
        /*
            
        switch type {
        case .mRoomCanonicalAlias:
            let content = try container.decode(RoomCanonicalAliasContent.self, forKey: .content)
            return content
        case .mRoomCreate:
            let content = try container.decode(RoomCreateContent.self, forKey: .content)
            return content
        case .mRoomMember:
            let content = try container.decode(RoomMemberContent.self, forKey: .content)
            return content
        case .mRoomJoinRules:
            let content = try container.decode(RoomJoinRuleContent.self, forKey: .content)
            return content
        case .mRoomPowerLevels:
            let content = try container.decode(RoomPowerLevelsContent.self, forKey: .content)
            return content
            
        case .mRoomName:
            let content = try container.decode(RoomNameContent.self, forKey: .content)
            return content
        case .mRoomAvatar:
            let content = try container.decode(RoomAvatarContent.self, forKey: .content)
            return content
        case .mRoomTopic:
            let content = try container.decode(RoomTopicContent.self, forKey: .content)
            return content
        
        case .mPresence:
            let content = try container.decode(PresenceContent.self, forKey: .content)
            return content
        
        case .mTyping:
            let content = try container.decode(TypingContent.self, forKey: .content)
            return content
            
        case .mReceipt:
            let content = try container.decode(ReceiptContent.self, forKey: .content)
            return content
          
        case .mRoomHistoryVisibility:
            let content = try container.decode(RoomHistoryVisibilityContent.self, forKey: .content)
            return content
 
        case .mRoomGuestAccess:
            let content = try container.decode(RoomGuestAccessContent.self, forKey: .content)
            return content
            
        case .mRoomTombstone:
            let content = try container.decode(RoomTombstoneContent.self, forKey: .content)
            return content
            
        case .mTag:
            let content = try container.decode(TagContent.self, forKey: .content)
            return content
            
        case .mRoomEncryption:
            let content = try container.decode(RoomEncryptionContent.self, forKey: .content)
            return content
        
        case .mEncrypted:
            let content = try container.decode(EncryptedEventContent.self, forKey: .content)
            return content
            
        case .mSpaceChild:
            let content = try container.decode(SpaceChildContent.self, forKey: .content)
            return content
            
        case .mSpaceParent:
            let content = try container.decode(SpaceParentContent.self, forKey: .content)
            return content
            
        case .mReaction:
            let content = try container.decode(ReactionContent.self, forKey: .content)
            return content
        
        case .mRoomMessage:
            // Peek into the content struct to examine the `msgtype`
            struct MinimalMessageContent: Codable {
                var msgtype: Matrix.MessageType
            }
            let mmc = try container.decode(MinimalMessageContent.self, forKey: .content)
            // Now use the msgtype to determine how we decode the content
            switch mmc.msgtype {
            case .text:
                let content = try container.decode(mTextContent.self, forKey: .content)
                return content
            case .emote:
                let content = try container.decode(mEmoteContent.self, forKey: .content)
                return content
            case .notice:
                let content = try container.decode(mNoticeContent.self, forKey: .content)
                return content
            case .image:
                let content = try container.decode(mImageContent.self, forKey: .content)
                return content
            case .location:
                let content = try container.decode(mLocationContent.self, forKey: .content)
                return content
            case .audio:
                let content = try container.decode(mAudioContent.self, forKey: .content)
                return content
            case .video:
                let content = try container.decode(mVideoContent.self, forKey: .content)
                return content
            case .file:
                let content = try container.decode(mFileContent.self, forKey: .content)
                return content
            }
        }
         */

    }
    
    public static func decodeAccountData(of dataType: String, from decoder: Decoder) throws -> Codable {
        enum CodingKeys: String, CodingKey {
            case content
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let codableType = accountDataTypes[dataType] {
            let content = try container.decode(codableType.self, forKey: .content)
            return content
        }
        
        if dataType.starts(with: M_SECRET_STORAGE_KEY) {
            guard let keyId = dataType.split(separator: ".").last
            else {
                let msg = "Couldn't get key id for \(M_SECRET_STORAGE_KEY)"
                print(msg)
                throw Matrix.Error(msg)
            }
            throw Matrix.Error("Not implemented")
        }
        
        throw Matrix.Error("Cannot decode unknown account data type \(dataType)")
    }

    
}
