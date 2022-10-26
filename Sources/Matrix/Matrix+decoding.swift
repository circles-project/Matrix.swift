//
//  Matrix+decoding.swift
//  
//
//  Created by Charles Wright on 10/26/22.
//

import Foundation

extension Matrix {
    
    static func decodeEventContent(of type: Matrix.EventType, from decoder: Decoder) throws -> Codable {
        
        let container = try decoder.container(keyedBy: MinimalEvent.CodingKeys.self)
            
        switch type {
        case .mRoomCanonicalAlias:
            let content = try container.decode(CanonicalAliasContent.self, forKey: .content)
            return content
        case .mRoomCreate:
            let content = try container.decode(CreateContent.self, forKey: .content)
            return content
        case .mRoomMember:
            let content = try container.decode(RoomMemberContent.self, forKey: .content)
            return content
        case .mRoomJoinRules:
            let content = try container.decode(JoinRuleContent.self, forKey: .content)
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
            
        case .mTag:
            let content = try container.decode(RoomTagContent.self, forKey: .content)
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
    }
    
    static func decodeAccountData(of dataType: Matrix.AccountDataType, from decoder: Decoder) throws -> Decodable {
        let container = try decoder.container(keyedBy: MinimalEvent.CodingKeys.self)

        switch dataType {
            
        case .mIdentityServer:
            throw Matrix.Error("Not implemented")
            
        case .mIgnoredUserList:
            throw Matrix.Error("Not implemented")

        case .mFullyRead:
            throw Matrix.Error("Not implemented")

        case .mDirect:
            let content = try container.decode(mDirectContent.self, forKey: .content)
            return content

        case .mSecretStorageKey(let string):
            throw Matrix.Error("Not implemented")

        }
    }

    
}
