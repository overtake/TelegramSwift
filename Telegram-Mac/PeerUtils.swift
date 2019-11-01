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
    
    
    var peerSummaryTags: PeerSummaryCounterTags {
        if let peer = self as? TelegramChannel {
            switch peer.info {
            case .group:
                if let addressName = peer.addressName, !addressName.isEmpty {
                    return [.publicGroups]
                } else {
                    return [.regularChatsAndPrivateGroups]
                }
            case .broadcast:
                return [.channels]
            }
        } else {
            return [.regularChatsAndPrivateGroups]
        }
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
