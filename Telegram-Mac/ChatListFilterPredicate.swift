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
    
    guard let filter = filter?.data else {
        return nil
    }
    let includePeers = Set(filter.includePeers)
    let excludePeers = Set(filter.excludePeers)
    var includeAdditionalPeerGroupIds: [PeerGroupId] = []
    if !filter.excludeArchived {
        includeAdditionalPeerGroupIds.append(Namespaces.PeerGroup.archive)
    }
    return ChatListFilterPredicate(includePeerIds: includePeers, excludePeerIds: excludePeers, includeAdditionalPeerGroupIds: includeAdditionalPeerGroupIds, include: { peer, notificationSettings, isUnread, isContact in
        if filter.excludeRead {
            if !isUnread {
                return false
            }
        }
        if filter.excludeMuted {
            if let notificationSettings = notificationSettings as? TelegramPeerNotificationSettings {
                if case .muted = notificationSettings.muteState {
                    return false
                }
            } else {
                return false
            }
        }
        if !filter.categories.contains(.contacts) && isContact {
            if let user = peer as? TelegramUser {
                if user.botInfo == nil {
                    return false
                }
            } else if let _ = peer as? TelegramSecretChat {
                return false
            }
        }
        if !filter.categories.contains(.nonContacts) && !isContact {
            if let user = peer as? TelegramUser {
                if user.botInfo == nil {
                    return false
                }
            } else if let _ = peer as? TelegramSecretChat {
                return false
            }
        }
        if !filter.categories.contains(.bots) {
            if let user = peer as? TelegramUser {
                if user.botInfo != nil {
                    return false
                }
            }
        }
        if !filter.categories.contains(.groups) {
            if let _ = peer as? TelegramGroup {
                return false
            } else if let channel = peer as? TelegramChannel {
                if case .group = channel.info {
                    return false
                }
            }
        }
        if !filter.categories.contains(.channels) {
            if let channel = peer as? TelegramChannel {
                if case .broadcast = channel.info {
                    return false
                }
            }
        }
        return true
    })

}
