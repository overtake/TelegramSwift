//
//  IsEqualMessages.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02.11.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import TelegramCore

import Postbox


func isEqualMessages(_ lhsMessage: Message, _ rhsMessage: Message) -> Bool {
    
    
    if MessageIndex(id: lhsMessage.id, timestamp: lhsMessage.timestamp) != MessageIndex(id: rhsMessage.id, timestamp: rhsMessage.timestamp) || lhsMessage.stableVersion != rhsMessage.stableVersion {
        return false
    }
    if lhsMessage.flags != rhsMessage.flags {
        return false
    }
    
    if lhsMessage.media.count != rhsMessage.media.count {
        return false
    }
    for i in 0 ..< lhsMessage.media.count {
        if !lhsMessage.media[i].isEqual(to: rhsMessage.media[i]) {
            return false
        }
    }
    
    if lhsMessage.attributes.count != rhsMessage.attributes.count {
        return false
    }
    
    for (_, lhsAttr) in lhsMessage.attributes.enumerated() {
        if let lhsAttr = lhsAttr as? ReplyThreadMessageAttribute {
            let rhsAttr = rhsMessage.attributes.compactMap { $0 as? ReplyThreadMessageAttribute }.first
            if let rhsAttr = rhsAttr {
                if lhsAttr.count != rhsAttr.count {
                    return false
                }
                if lhsAttr.latestUsers != rhsAttr.latestUsers {
                    return false
                }
                if lhsAttr.maxMessageId != rhsAttr.maxMessageId {
                    return false
                }
                if lhsAttr.maxReadMessageId != rhsAttr.maxReadMessageId {
                    return false
                }
            } else {
                return false
            }
        }
        if let lhsAttr = lhsAttr as? ViewCountMessageAttribute {
            let rhsAttr = rhsMessage.attributes.compactMap { $0 as? ViewCountMessageAttribute }.first
            if let rhsAttr = rhsAttr {
                if lhsAttr.count != rhsAttr.count {
                    return false
                }
            } else {
                return false
            }
        }
    }
    
    if lhsMessage.associatedMessages.count != rhsMessage.associatedMessages.count {
        return false
    } else {
        for (messageId, lhsAssociatedMessage) in lhsMessage.associatedMessages {
            if let rhsAssociatedMessage = rhsMessage.associatedMessages[messageId] {
                if !isEqualMessages(lhsAssociatedMessage, rhsAssociatedMessage) {
                    return false
                }
            } else {
                return false
            }
        }
    }
    
    if lhsMessage.peers.count != rhsMessage.peers.count {
        return false
    } else {
        for (lhsPeerId, lhsPeer) in lhsMessage.peers {
            if let rhsPeer = rhsMessage.peers[lhsPeerId] {
                if rhsPeer.displayTitle != lhsPeer.displayTitle {
                    return false
                }
            } else {
                return false
            }
        }
    }
    
    return true
}
