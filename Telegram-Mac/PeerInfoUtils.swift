//
//  PeerInfoUtils.swift
//  Telegram
//
//  Created by keepcoder on 23/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import Postbox

struct GroupAccess {
    let highlightAdmins:Bool
    let canEditGroupInfo:Bool
    let canEditMembers:Bool
    let canAddMembers: Bool
    let isPublic:Bool
    let isCreator:Bool
    let canCreateInviteLink: Bool
    let canReport: Bool
    let canMakeVoiceChat: Bool
    let canEditMessages: Bool
    let canManageGifts: Bool
    let canPostMessages: Bool
    let canManageDirect: Bool
    let canManageStories: Bool
}

extension Peer {
    
    var groupAccess:GroupAccess {
        var highlightAdmins = false
        var canEditGroupInfo = false
        var canEditMembers = false
        var canAddMembers = false
        var isPublic = false
        var isCreator = false
        var canReport = true
        var canMakeVoiceChat = false
        var canPostMessages = false
        var canManageDirect = false
        var canEditMessages = false
        var canPin: Bool
        var canManageGifts = false
        var canManageStories = false
        if let group = self as? TelegramGroup {
            if case .creator = group.role {
                isCreator = true
                canReport = false
                canMakeVoiceChat = true
                canEditMessages = true
                canPostMessages = true
            }
            highlightAdmins = true
            switch group.role {
            case .admin, .creator:
                canEditGroupInfo = true
                canEditMembers = true
                canAddMembers = true
                canReport = false
                canMakeVoiceChat = true
                canEditMessages = true
                canPostMessages = true
            case .member:
                break
            }
            if !group.hasBannedPermission(.banChangeInfo) {
                canEditGroupInfo = true
            }
            if !group.hasBannedPermission(.banAddMembers) {
                canAddMembers = true
            }
        } else if let channel = self as? TelegramChannel {
            highlightAdmins = true
            isPublic = channel.username != nil
            isCreator = channel.flags.contains(.isCreator)
            canReport = !channel.flags.contains(.isCreator) && channel.adminRights == nil
            canManageStories = channel.flags.contains(.isCreator)
            canPostMessages = channel.flags.contains(.isCreator)
            canManageDirect = channel.flags.contains(.isCreator)
            if channel.hasPermission(.changeInfo) {
                canEditGroupInfo = true
            }
            if channel.hasPermission(.banMembers) {
                canEditMembers = true
            }
            if channel.hasPermission(.inviteMembers) || isCreator || channel.adminRights?.rights.contains(.canInviteUsers) == true {
                canAddMembers = true
            }
            canManageGifts = isCreator || channel.adminRights?.rights.contains(.canPostMessages) == true
        }
        
        var canCreateInviteLink = false
        if let group = self as? TelegramGroup {
            if case .creator = group.role {
                canCreateInviteLink = true
            }
        } else if let channel = self as? TelegramChannel {
            if let adminRights = channel.adminRights, adminRights.rights.contains(.canInviteUsers) {
                canCreateInviteLink = true
            }
            if channel.hasPermission(.manageCalls) {
                canMakeVoiceChat = true
            }
            if channel.hasPermission(.editStories) {
                canManageStories = true
            }
            if channel.hasPermission(.editAllMessages) {
                canEditMessages = true
            }
            if let adminRights = channel.adminRights {
                canPostMessages = adminRights.rights.contains(.canPostMessages)
                canManageDirect = adminRights.rights.contains(.canManageDirect)
            }
        }
        


        return GroupAccess(highlightAdmins: highlightAdmins, canEditGroupInfo: canEditGroupInfo, canEditMembers: canEditMembers, canAddMembers: canAddMembers, isPublic: isPublic, isCreator: isCreator, canCreateInviteLink: canCreateInviteLink, canReport: canReport, canMakeVoiceChat: canMakeVoiceChat, canEditMessages: canEditMessages, canManageGifts: canManageGifts, canPostMessages: canPostMessages, canManageDirect: canManageDirect, canManageStories: canManageStories)
    }
    
    var canInviteUsers:Bool {
        if let peer = self as? TelegramChannel {
            return peer.hasPermission(.inviteMembers)
        } else if let group = self as? TelegramGroup {
            return !group.hasBannedRights(.banAddMembers)
        }
        
        
        return false
    }
}

extension TelegramGroup {
    func canRemoveParticipant(_ participant: GroupParticipant) -> Bool {
        switch role {
        case .creator:
            switch participant {
            case .admin, .member:
                return true
            default :
                return false
            }
        case .admin:
            switch participant {
            case .member:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }
}

extension TelegramChannel {
    func canRemoveParticipant(_ participant: ChannelParticipant, accountId:PeerId) -> Bool {
        let hasRight = hasPermission(.banMembers)
        if accountId == participant.peerId {
            return false
        }
        switch participant {
        case let .member(_, _,  adminInfo, _, _, _):
            if let adminInfo = adminInfo {
                return accountId == adminInfo.promotedBy || flags.contains(.isCreator)
            } else {
                return hasRight
            }
        default:
            return false
        }
    }
}

func <(lhs:GroupParticipant, rhs:GroupParticipant) -> Bool {
    switch lhs {
    case .creator:
        return false
    case let .admin(lhsId, _, lhsInvitedAt):
        switch rhs {
        case .creator:
            return true
        case let .admin(rhsId, _, rhsInvitedAt):
            if lhsInvitedAt == rhsInvitedAt {
                return lhsId.id < rhsId.id
            }
            return lhsInvitedAt > rhsInvitedAt
        case let .member(rhsId, _, rhsInvitedAt):
            if lhsInvitedAt == rhsInvitedAt {
                return lhsId.id < rhsId.id
            }
            return lhsInvitedAt > rhsInvitedAt
        }
    case let .member(lhsId, _, lhsInvitedAt):
        switch rhs {
        case .creator:
            return true
        case let .admin(rhsId, _, rhsInvitedAt):
            if lhsInvitedAt == rhsInvitedAt {
                return lhsId.id < rhsId.id
            }
            return lhsInvitedAt > rhsInvitedAt
        case let .member(rhsId, _, rhsInvitedAt):
            if lhsInvitedAt == rhsInvitedAt {
                return lhsId.id < rhsId.id
            }
            return lhsInvitedAt > rhsInvitedAt
        }
    }
}

func <(lhs:ChannelParticipant, rhs: ChannelParticipant) -> Bool {
    switch lhs {
    case .creator:
        return false
    case let .member(_, lhsInvitedAt, _, _, _, _):
        switch rhs {
        case .creator:
            return true
        case let .member(_, rhsInvitedAt, _, _, _, _):
            return lhsInvitedAt < rhsInvitedAt
        }
    }

}
