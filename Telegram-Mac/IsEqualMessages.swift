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
    
    if lhsMessage.id != rhsMessage.id {
        return false
    }
    if lhsMessage.stableVersion != rhsMessage.stableVersion {
        return false
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
    if lhsMessage.associatedStories.count != rhsMessage.associatedStories.count {
        return false
    } else {
        for (storyId, lhsAssociatedStory) in lhsMessage.associatedStories {
            if let rhsAssociatedStory = rhsMessage.associatedStories[storyId] {
                let lhsStory = lhsAssociatedStory.get(Stories.StoredItem.self)
                let rhsStory = rhsAssociatedStory.get(Stories.StoredItem.self)
                if lhsStory != rhsStory {
                    return false
                }
            } else {
                return false
            }
        }
    }
    
    if lhsMessage.media.count != rhsMessage.media.count {
        return false
    } else {
        for i in 0 ..< lhsMessage.media.count {
            if !lhsMessage.media[i].isEqual(to: rhsMessage.media[i]) {
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
