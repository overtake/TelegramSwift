//
//  ChatListFilterPredicate.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02.03.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore


func chatListFilterPredicate(for filter: ChatListFilter?) -> ChatListFilterPredicate? {
    let filterPredicate: ((Peer, PeerNotificationSettings?, Bool) -> Bool)
    
    guard let filter = filter else {
        return nil
    }
    filterPredicate = { peer, notificationSettings, isUnread in
        
        let check:()->Bool = {
            if filter.data.excludeMuted {
                if let notificationSettings = notificationSettings as? TelegramPeerNotificationSettings {
                    if case let .muted(until) = notificationSettings.muteState {
                        return until < Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                    }
                } else {
                    return false
                }
            }
            
            
            if !filter.data.categories.contains(.privateChats) {
                if let user = peer as? TelegramUser {
                    if user.botInfo == nil {
                        return false
                    }
                } else if let _ = peer as? TelegramSecretChat {
                    return false
                }
            }
            
            if !filter.data.categories.contains(.secretChats) {
                if let _ = peer as? TelegramSecretChat {
                    return false
                }
            }
            
            if !filter.data.categories.contains(.bots) {
                if let user = peer as? TelegramUser {
                    if user.botInfo != nil {
                        return false
                    }
                }
            }
            if !filter.data.categories.contains(.privateGroups) {
                if let _ = peer as? TelegramGroup {
                    return false
                } else if let channel = peer as? TelegramChannel {
                    if case .group = channel.info {
                        if channel.username == nil {
                            return false
                        }
                    }
                }
            }
            if !filter.data.categories.contains(.publicGroups) {
                if let channel = peer as? TelegramChannel {
                    if case .group = channel.info {
                        if channel.username != nil {
                            return false
                        }
                    }
                }
            }
            
            if !filter.data.categories.contains(.channels) {
                if let channel = peer as? TelegramChannel {
                    if case .broadcast = channel.info {
                        return false
                    }
                }
            }
            return true
        }
        
        if filter.data.excludeRead {
            if !isUnread {
                return false
            }
        }
        
        return check()
    }
    return ChatListFilterPredicate(includePeerIds: Set(filter.data.includePeers), include: filterPredicate)
}
