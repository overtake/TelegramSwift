//
//  PeerUtils.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07/03/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import SyncCore


extension ChatListFilterPeerCategories {
   
    static let excludeRead = ChatListFilterPeerCategories(rawValue: 1 << 6)
    static let excludeMuted = ChatListFilterPeerCategories(rawValue: 1 << 7)
    static let excludeArchived = ChatListFilterPeerCategories(rawValue: 1 << 8)
    
    static let Namespace: Int32 = 10
}


final class TelegramFilterCategory : Peer {
    
    
    
    var id: PeerId
    
    var indexName: PeerIndexNameRepresentation
    
    var associatedPeerId: PeerId?
    
    var notificationSettingsPeerId: PeerId?
    
    func isEqual(_ other: Peer) -> Bool {
        if let other = other as? TelegramFilterCategory {
            return other.category == self.category
        }
        return false
    }
    
    let category: ChatListFilterPeerCategories
    
    init(category: ChatListFilterPeerCategories) {
        self.id = PeerId(namespace: 10, id: category.rawValue)
        self.indexName = .title(title: "", addressName: "")
        self.notificationSettingsPeerId = nil
        self.category = category
    }
    
    var displayTitle: String? {
        if category == .contacts {
            return L10n.chatListFilterContacts
        }
        if category == .nonContacts {
            return L10n.chatListFilterNonContacts
        }
        if category == .groups {
            return L10n.chatListFilterGroups
        }
        if category == .channels {
            return L10n.chatListFilterChannels
        }
        if category == .bots {
            return L10n.chatListFilterBots
        }
        if category == .excludeRead {
            return L10n.chatListFilterReadChats
        }
        if category == .excludeMuted {
            return L10n.chatListFilterMutedChats
        }
        if category == .excludeArchived {
            return L10n.chatListFilterArchive
        }
        return nil
    }
    
    var icon: EmptyAvatartType? {
        if category == .contacts {
            return .icon(colors: theme.colors.peerColors(5), icon: theme.icons.chat_filter_private_chats_avatar, iconSize: NSMakeSize(20, 20), cornerRadius: nil)
        }
        if category == .nonContacts {
            return .icon(colors: theme.colors.peerColors(1), icon: theme.icons.chat_filter_non_contacts_avatar, iconSize: NSMakeSize(20, 20), cornerRadius: nil)
        }
        if category == .groups {
            return .icon(colors: theme.colors.peerColors(2), icon: theme.icons.chat_filter_large_groups_avatar, iconSize: NSMakeSize(20, 20), cornerRadius: nil)
        }
        if category == .channels {
            return .icon(colors: theme.colors.peerColors(0), icon: theme.icons.chat_filter_channels_avatar, iconSize: NSMakeSize(20, 20), cornerRadius: nil)
        }
        if category == .bots {
            return .icon(colors: theme.colors.peerColors(6), icon: theme.icons.chat_filter_bots_avatar, iconSize: NSMakeSize(20, 20), cornerRadius: nil)
        }
        if category == .excludeMuted {
            return .icon(colors: theme.colors.peerColors(0), icon: theme.icons.chat_filter_muted_avatar, iconSize: NSMakeSize(20, 20), cornerRadius: nil)
        }
        if category == .excludeRead {
            return .icon(colors: theme.colors.peerColors(3), icon: theme.icons.chat_filter_read_avatar, iconSize: NSMakeSize(20, 20), cornerRadius: nil)
        }
        if category == .excludeArchived {
            return .icon(colors: theme.colors.peerColors(5), icon: theme.icons.chat_filter_archive_avatar, iconSize: NSMakeSize(20, 20), cornerRadius: nil)
        }
        return nil
    }
    
    
    init(decoder: PostboxDecoder) {
        self.id = PeerId(0)
        self.indexName = .title(title: "", addressName: "")
        self.notificationSettingsPeerId = nil
        self.category = []
    }
    func encode(_ encoder: PostboxEncoder) {
        
    }
}

extension Peer {
    
    func hasBannedRights(_ flags: TelegramChatBannedRightsFlags) -> Bool {
        if let peer = self as? TelegramChannel {
            if let _ = peer.hasBannedPermission(flags) {
                return true
            }
        } else if let peer = self as? TelegramGroup {
            return peer.hasBannedPermission(flags)
        }
        return false
    }
    
    var webUrlRestricted: Bool {
        return hasBannedRights([.banEmbedLinks])
    }
    
    

    
    var canSendMessage: Bool {
        if let channel = self as? TelegramChannel {
            if case .broadcast(_) = channel.info {
                return channel.hasPermission(.sendMessages)
            } else if case .group = channel.info  {
                switch channel.participationStatus {
                case .member:
                    return !channel.hasBannedRights(.banSendMessages)
                default:
                    return false
                }
            }
        } else if let group = self as? TelegramGroup {
            return group.membership == .Member && !group.hasBannedPermission(.banSendMessages)
        } else if let secret = self as? TelegramSecretChat {
            switch secret.embeddedState {
            case .terminated:
                return false
            case .handshake:
                return false
            default:
                return true
            }
        }
        
        return true
    }
    
    var username:String? {
        if let peer = self as? TelegramChannel {
            return peer.username
        } else if let peer = self as? TelegramGroup {
            return peer.username
        } else if let peer = self as? TelegramUser {
            return peer.username
        }
        return nil
    }
    
    var emptyAvatar: EmptyAvatartType? {
        if let peer = self as? TelegramFilterCategory {
            return peer.icon
        }
        return nil
    }
    
    public var displayTitle: String {
        switch self {
        case let user as TelegramUser:
            if user.firstName == nil && user.lastName == nil {
                return L10n.peerDeletedUser
            } else {
                var name: String = ""
                if let firstName = user.firstName {
                    name += firstName
                }
                if let lastName = user.lastName {
                    if user.firstName != nil {
                        name += " "
                    }
                    name += lastName
                }
                return name
            }
        case let group as TelegramGroup:
            return group.title
        case let channel as TelegramChannel:
            return channel.title
        case let filter as TelegramFilterCategory:
            return filter.displayTitle ?? ""
        default:
            return ""
        }
    }
    
    var rawDisplayTitle: String {
        switch self {
        case let user as TelegramUser:
            if user.firstName == nil && user.lastName == nil {
                return ""
            } else {
                var name: String = ""
                if let firstName = user.firstName {
                    name += firstName
                }
                if let lastName = user.lastName {
                    if user.firstName != nil {
                        name += " "
                    }
                    name += lastName
                }
                return name
            }
        case let group as TelegramGroup:
            return group.title
        case let channel as TelegramChannel:
            return channel.title
        default:
            return ""
        }
    }
    
    public var compactDisplayTitle: String {
        switch self {
        case let user as TelegramUser:
            if let firstName = user.firstName {
                return firstName
            } else if let lastName = user.lastName {
                return lastName
            } else {
                return tr(L10n.peerDeletedUser)
            }
        case let group as TelegramGroup:
            return group.title
        case let channel as TelegramChannel:
            return channel.title
        case let filter as TelegramFilterCategory:
            return filter.displayTitle ?? ""
        default:
            return ""
        }
    }
    
    public var displayLetters: [String] {
        switch self {
        case let user as TelegramUser:
            if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty && !lastName.isEmpty {
                return [firstName.substring(to: firstName.index(after: firstName.startIndex)).uppercased(), lastName.substring(to: lastName.index(after: lastName.startIndex)).uppercased()]
            } else if let firstName = user.firstName, !firstName.isEmpty {
                return [firstName.substring(to: firstName.index(after: firstName.startIndex)).uppercased()]
            } else if let lastName = user.lastName, !lastName.isEmpty {
                return [lastName.substring(to: lastName.index(after: lastName.startIndex)).uppercased()]
            } else {
                let name = tr(L10n.peerDeletedUser)
                if !name.isEmpty {
                    return [name.substring(to: name.index(after: name.startIndex)).uppercased()]
                }
            }
            
            return []
        case let group as TelegramGroup:
            if group.title.startIndex != group.title.endIndex {
                return [group.title.substring(to: group.title.index(after: group.title.startIndex)).uppercased()]
            } else {
                return []
            }
        case let channel as TelegramChannel:
            if channel.title.startIndex != channel.title.endIndex {
                return [channel.title.substring(to: channel.title.index(after: channel.title.startIndex)).uppercased()]
            } else {
                return []
            }
        default:
            return []
        }
    }
    
    var isVerified: Bool {
        if let peer = self as? TelegramUser {
            return peer.flags.contains(.isVerified)
        } else if let peer = self as? TelegramChannel {
            return peer.flags.contains(.isVerified)
        } else {
            return false
        }
    }
    
}
