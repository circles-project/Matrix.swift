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
    }
    
    public static func decodeAccountData(of dataType: String, from decoder: Decoder) throws -> Codable {
        enum CodingKeys: String, CodingKey {
            case content
        }
        logger.debug("Matrix decoding Account Data content of type \(dataType)")
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let codableType = accountDataTypes[dataType] {
            let content = try container.decode(codableType.self, forKey: .content)
            logger.debug("Matrix decoded content of type \(codableType)")
            return content
        }
        
        if dataType.starts(with: "\(M_SECRET_STORAGE_KEY).") {
            guard let keyId = dataType.split(separator: ".").last
            else {
                let msg = "Couldn't get key id for \(M_SECRET_STORAGE_KEY)"
                logger.error("Couldn't get key id for \(M_SECRET_STORAGE_KEY)")
                throw Matrix.Error(msg)
            }
            let content = try container.decode(KeyDescriptionContent.self, forKey: .content)
            logger.debug("Matrix decoded content of type \(KeyDescriptionContent.self)")
            return content
        }
        
        logger.error("Cannot decode unknown account data type \(dataType)")
        throw Matrix.Error("Cannot decode unknown account data type \(dataType)")
    }

    
}
