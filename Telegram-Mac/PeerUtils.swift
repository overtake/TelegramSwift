//
//  PeerUtils.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07/03/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import Postbox


let prod_repliesPeerId: PeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1271266957))
let test_repliesPeerId: PeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(708513))


var repliesPeerId: PeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1271266957))


extension ChatListFilterPeerCategories {
   
    static let excludeRead = ChatListFilterPeerCategories(rawValue: 1 << 6)
    static let excludeMuted = ChatListFilterPeerCategories(rawValue: 1 << 7)
    static let excludeArchived = ChatListFilterPeerCategories(rawValue: 1 << 8)
    
    static let Namespace: Int32 = 7
}


final class TelegramFilterCategory : Peer {
    
    var timeoutAttribute: UInt32? 
    
    var id: PeerId
    
    var indexName: PeerIndexNameRepresentation
    
    var associatedPeerId: PeerId?
    var associatedMediaIds: [MediaId]?
    var notificationSettingsPeerId: PeerId?
    
    func isEqual(_ other: Peer) -> Bool {
        if let other = other as? TelegramFilterCategory {
            return other.category == self.category
        }
        return false
    }
    
    let category: ChatListFilterPeerCategories
    
    init(category: ChatListFilterPeerCategories) {
        self.id = PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(Int64(category.rawValue)))
        self.indexName = .title(title: "", addressNames: [""])
        self.notificationSettingsPeerId = nil
        self.category = category
    }
    
    var displayTitle: String? {
        if category == .contacts {
            return strings().chatListFilterContacts
        }
        if category == .nonContacts {
            return strings().chatListFilterNonContacts
        }
        if category == .groups {
            return strings().chatListFilterGroups
        }
        if category == .channels {
            return strings().chatListFilterChannels
        }
        if category == .bots {
            return strings().chatListFilterBots
        }
        if category == .excludeRead {
            return strings().chatListFilterReadChats
        }
        if category == .excludeMuted {
            return strings().chatListFilterMutedChats
        }
        if category == .excludeArchived {
            return strings().chatListFilterArchive
        }
        return nil
    }
    
    var icon: EmptyAvatartType? {
        if category == .contacts {
            return .icon(colors: theme.colors.peerColors(5), icon: theme.icons.chat_filter_private_chats_avatar, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        if category == .nonContacts {
            return .icon(colors: theme.colors.peerColors(1), icon: theme.icons.chat_filter_non_contacts_avatar, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        if category == .groups {
            return .icon(colors: theme.colors.peerColors(2), icon: theme.icons.chat_filter_large_groups_avatar, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        if category == .channels {
            return .icon(colors: theme.colors.peerColors(0), icon: theme.icons.chat_filter_channels_avatar, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        if category == .bots {
            return .icon(colors: theme.colors.peerColors(6), icon: theme.icons.chat_filter_bots_avatar, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        if category == .excludeMuted {
            return .icon(colors: theme.colors.peerColors(0), icon: theme.icons.chat_filter_muted_avatar, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        if category == .excludeRead {
            return .icon(colors: theme.colors.peerColors(3), icon: theme.icons.chat_filter_read_avatar, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        if category == .excludeArchived {
            return .icon(colors: theme.colors.peerColors(5), icon: theme.icons.chat_filter_archive_avatar, iconSize: NSMakeSize(24, 24), cornerRadius: nil)
        }
        return nil
    }
    
    
    init(decoder: PostboxDecoder) {
        self.id = PeerId(0)
        self.indexName = .title(title: "", addressNames: [""])
        self.notificationSettingsPeerId = nil
        self.category = []
    }
    func encode(_ encoder: PostboxEncoder) {
        
    }
}

extension CachedPeerData {
    var photo: TelegramMediaImage? {
        if let data = self as? CachedUserData {
            return data.photo
        }
        if let data = self as? CachedChannelData {
            return data.photo
        }
        if let data = self as? CachedGroupData {
            return data.photo
        }
        return nil
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
    
    
    var hasVideo: Bool {
        if let image = self.profileImageRepresentations.first {
            return image.hasVideo
        }
        return false
    }
    
    func canSendMessage(_ isThreadMode: Bool = false, threadData: MessageHistoryThreadData? = nil) -> Bool {
        if self.id == repliesPeerId {
            return false
        }
        if let channel = self as? TelegramChannel {
            if case .broadcast(_) = channel.info {
                return channel.hasPermission(.sendMessages)
            } else if case .group = channel.info {
                
                if let data = threadData {
                    if data.isClosed, channel.adminRights == nil && !channel.flags.contains(.isCreator) && !data.isOwnedByMe {
                        return false
                    }
                }
                
                switch channel.participationStatus {
                case .member:
                    return !channel.hasBannedRights(.banSendMessages)
                case .left:
                    if isThreadMode {
                        return !channel.hasBannedRights(.banSendMessages)
                    }
                    return false
                case .kicked:
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
                return strings().peerDeletedUser
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
                
                return name.replacingOccurrences(of: "􀇻", with: "")
            }
        case let group as TelegramGroup:
            return group.title.replacingOccurrences(of: "􀇻", with: "")
        case let channel as TelegramChannel:
            return channel.title.replacingOccurrences(of: "􀇻", with: "")
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
                return firstName.replacingOccurrences(of: "􀇻", with: "")
            } else if let lastName = user.lastName {
                return lastName.replacingOccurrences(of: "􀇻", with: "")
            } else {
                return strings().peerDeletedUser
            }
        case let group as TelegramGroup:
            return group.title.replacingOccurrences(of: "􀇻", with: "")
        case let channel as TelegramChannel:
            return channel.title.replacingOccurrences(of: "􀇻", with: "")
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
                return [firstName[firstName.startIndex ..< firstName.index(after: firstName.startIndex)].uppercased(), lastName[lastName.startIndex ..< lastName.index(after: lastName.startIndex)].uppercased()]
            } else if let firstName = user.firstName, !firstName.isEmpty {
                return [firstName[firstName.startIndex ..< firstName.index(after: firstName.startIndex)].uppercased()]
            } else if let lastName = user.lastName, !lastName.isEmpty {
                return [lastName[lastName.startIndex ..< lastName.index(after: lastName.startIndex)].uppercased()]
            } else {
                let name = strings().peerDeletedUser
                if !name.isEmpty {
                    return [name[name.startIndex ..< name.index(after: name.startIndex)].uppercased()]
                }
            }
            
            return []
        case let group as TelegramGroup:
            if !group.title.isEmpty {
                return [group.title[group.title.startIndex ..< group.title.index(after: group.title.startIndex)].uppercased()]
            } else {
                return []
            }
        case let channel as TelegramChannel:
            if !channel.title.isEmpty {
                return [channel.title[channel.title.startIndex ..< channel.title.index(after: channel.title.startIndex)].uppercased()]
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
    
    
    var isPremium: Bool {
        if let peer = self as? TelegramUser {
            return peer.flags.contains(.isPremium)
        } else {
            return false
        }
    }
    
    var isForum: Bool {
        if let channel = self as? TelegramChannel {
            return channel.flags.contains(.isForum)
        } else {
            return false
        }
    }
    
    
}

extension PeerId {
    static func _optionalInternalFromInt64Value(_ id: Int64) -> PeerId.Id? {
        let peerId = PeerId.Id._internalFromInt64Value(id)
        if id < 0 {
            if let _ = Int32(exactly: id) {
                return peerId
            } else {
                return nil
            }
        }
        return peerId
    }
}
