//
//  PeerInfoUtils.swift
//  Telegram
//
//  Created by keepcoder on 23/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac

struct GroupAccess {
    let highlightAdmins:Bool
    let canEditGroupInfo:Bool
    let canEditMembers:Bool
    let canAddMembers: Bool
    let isPublic:Bool
    let isCreator:Bool
    let canCreateInviteLink: Bool
}

extension Peer {
    
    var groupAccess:GroupAccess {
        var highlightAdmins = false
        var canEditGroupInfo = false
        var canEditMembers = false
        var canAddMembers = false
        var isPublic = false
        var isCreator = false
        if let group = self as? TelegramGroup {
            if case .creator = group.role {
                isCreator = true
            }
            highlightAdmins = true
            switch group.role {
            case .admin, .creator:
                canEditGroupInfo = true
                canEditMembers = true
                canAddMembers = true
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
            if channel.hasPermission(.changeInfo) {
                canEditGroupInfo = true
            }
            if channel.hasPermission(.banMembers) {
                canEditMembers = true
            }
            if channel.hasPermission(.inviteMembers) {
                canAddMembers = true
            }
        }
        
        var canCreateInviteLink = false
        if let group = self as? TelegramGroup {
            if case .creator = group.role {
                canCreateInviteLink = true
            }
        } else if let channel = self as? TelegramChannel {
            if channel.hasPermission(.inviteMembers) {
                canCreateInviteLink = true
            }
        }
        


        return GroupAccess(highlightAdmins: highlightAdmins, canEditGroupInfo: canEditGroupInfo, canEditMembers: canEditMembers, canAddMembers: canAddMembers, isPublic: isPublic, isCreator: isCreator, canCreateInviteLink: canCreateInviteLink)
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
        
        switch participant {
        case let .member(_, _,  adminInfo, _, _):
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
    case let .member(lhsId, lhsInvitedAt, lhsAdminInfo, lhsBanInfo, lhsRank):
        switch rhs {
        case .creator:
            return true
        case let .member(rhsId, rhsInvitedAt, rhsAdminInfo, rhsBanInfo, rhsRank):
            return lhsInvitedAt < rhsInvitedAt
        }
    }

}
