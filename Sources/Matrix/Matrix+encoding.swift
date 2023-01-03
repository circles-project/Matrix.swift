//
//  Matrix+encoding.swift
//  
//
//  Created by Charles Wright on 10/26/22.
//

import Foundation

extension Matrix {
    
    // MARK: Encoding
    
    static func encodeEventContent(content: Codable, of type: Matrix.EventType, to encoder: Encoder) throws {
        enum CodingKeys: String, CodingKey {
            case content
        }
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch type {
        case .mRoomAvatar:
            guard let avatarContent = content as? RoomAvatarContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(avatarContent, forKey: .content)
            
        case .mRoomCanonicalAlias:
            guard let aliasContent = content as? CanonicalAliasContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(aliasContent, forKey: .content)
            
        case .mRoomCreate:
            guard let createContent = content as? CreateContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(createContent, forKey: .content)
            
        case .mRoomJoinRules:
            guard let joinruleContent = content as? JoinRuleContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(joinruleContent, forKey: .content)
            
        case .mRoomMember:
            guard let roomMemberContent = content as? RoomMemberContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(roomMemberContent, forKey: .content)
            
        case .mRoomPowerLevels:
            guard let powerlevelsContent = content as? RoomPowerLevelsContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(powerlevelsContent, forKey: .content)
            
            
        case .mReaction:
            guard let reactionContent = content as? ReactionContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(reactionContent, forKey: .content)
            
        case .mRoomMessage:
            guard let messageContent = content as? Matrix.MessageContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            switch messageContent.msgtype {
            case .audio:
                guard let audioContent = messageContent as? mAudioContent else {
                    throw Matrix.Error("Couldn't convert audio message content")
                }
                try container.encode(audioContent, forKey: .content)
                
            case .text:
                guard let textContent = messageContent as? mTextContent else {
                    throw Matrix.Error("Couldn't convert audio message content")
                }
                try container.encode(textContent, forKey: .content)
                
            case .emote:
                guard let emoteContent = messageContent as? mEmoteContent else {
                    throw Matrix.Error("Couldn't convert audio message content")
                }
                try container.encode(emoteContent, forKey: .content)
                
            case .notice:
                guard let noticeContent = messageContent as? mNoticeContent else {
                    throw Matrix.Error("Couldn't convert audio message content")
                }
                try container.encode(noticeContent, forKey: .content)
                
            case .image:
                guard let imageContent = messageContent as? mImageContent else {
                    throw Matrix.Error("Couldn't convert audio message content")
                }
                try container.encode(imageContent, forKey: .content)
                
            case .file:
                guard let fileContent = messageContent as? mFileContent else {
                    throw Matrix.Error("Couldn't convert audio message content")
                }
                try container.encode(fileContent, forKey: .content)
                
            case .video:
                guard let videoContent = messageContent as? mVideoContent else {
                    throw Matrix.Error("Couldn't convert audio message content")
                }
                try container.encode(videoContent, forKey: .content)
                
            case .location:
                guard let locationContent = messageContent as? mLocationContent else {
                    throw Matrix.Error("Couldn't convert audio message content")
                }
                try container.encode(locationContent, forKey: .content)
                
            }
            
        case .mRoomEncryption:
            guard let encryptionContent = content as? RoomEncryptionContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(encryptionContent, forKey: .content)
            
        case .mEncrypted:
            guard let encryptedContent = content as? EncryptedEventContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(encryptedContent, forKey: .content)
            
        case .mRoomHistoryVisibility:
            guard let historyVisibilityContent = content as? HistoryVisibilityContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(historyVisibilityContent, forKey: .content)
            
        case .mRoomName:
            guard let roomNameContent = content as? RoomNameContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(roomNameContent, forKey: .content)
            
        case .mRoomTopic:
            guard let roomTopicContent = content as? RoomTopicContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(roomTopicContent, forKey: .content)

        case .mPresence:
            guard let presenceContent = content as? PresenceContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(presenceContent, forKey: .content)
        
        case .mTyping:
            guard let typingContent = content as? TypingContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(typingContent, forKey: .content)
            
        case .mReceipt:
            guard let receiptContent = content as? ReceiptContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(receiptContent, forKey: .content)
            
        case .mRoomHistoryVisibility:
            guard let roomHistoryVisibilityContent = content as? RoomHistoryVisibilityContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(roomHistoryVisibilityContent, forKey: .content)
      
        case .mRoomGuestAccess:
            guard let roomGuestAccessContent = content as? RoomGuestAccessContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(roomGuestAccessContent, forKey: .content)
            
        case .mRoomTombstone:
            guard let roomTombstoneContent = content as? RoomTombstoneContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(roomTombstoneContent, forKey: .content)
            
        case .mTag:
            guard let roomTagContent = content as? RoomTagContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(roomTagContent, forKey: .content)
            
        case .mSpaceChild:
            guard let spaceChildContent = content as? SpaceChildContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(spaceChildContent, forKey: .content)
            
        case .mSpaceParent:
            guard let spaceParentContent = content as? SpaceParentContent else {
                throw Matrix.Error("Couldn't convert content")
            }
            try container.encode(spaceParentContent, forKey: .content)
        }
    }
}
