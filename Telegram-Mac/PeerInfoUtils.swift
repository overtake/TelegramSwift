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
    let canManageMembers:Bool
    let canManageGroup:Bool
    let isCreator:Bool
}

extension Peer {
    
    var groupAccess:GroupAccess {
        var highlightAdmins = false
        var canManageGroup = false
        var canManageMembers = false
        var isCreator = false
        if let group = self as? TelegramGroup {
            highlightAdmins = true
            if group.flags.contains(.adminsEnabled) {
                switch group.role {
                case .creator:
                    canManageGroup = true
                    canManageMembers = true
                    isCreator = true
                case .admin:
                    canManageGroup = true
                    canManageMembers = true
                case .member:
                    break
                }
            } else {
                canManageGroup = group.membership == .Member
                canManageMembers = group.membership == .Member
                switch group.role {
                case .creator:
                    isCreator = true
                default:
                    break
                }
            }
        } else if let channel = self as? TelegramChannel {
            highlightAdmins = true
            isCreator = channel.flags.contains(.isCreator)
            canManageGroup = channel.adminRights != nil || channel.flags.contains(.isCreator)
            canManageMembers = channel.hasAdminRights(.canBanUsers)

        }
        return GroupAccess(highlightAdmins: highlightAdmins, canManageMembers: canManageMembers, canManageGroup: canManageGroup, isCreator: isCreator)
    }
    
    var canInviteUsers:Bool {
        if let peer = self as? TelegramChannel {
            switch peer.info {
            case .group(let info):
                return peer.hasAdminRights(.canInviteUsers) || info.flags.contains(.everyMemberCanInviteMembers)
            default:
                break
            }
            return peer.hasAdminRights(.canInviteUsers)
        } else if let group = self as? TelegramGroup {
            if group.flags.contains(.adminsEnabled) {
                switch group.role {
                case .creator, .admin:
                    return true
                default:
                    return false
                }
            } else {
                return true
            }
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
        let hasRight = hasAdminRights(.canBanUsers)
        
        switch participant {
        case let .member(_, _,  adminInfo, _):
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
    case let .member(lhsId, lhsInvitedAt, lhsAdminInfo, lhsBanInfo):
        switch rhs {
        case .creator:
            return true
        case let .member(rhsId, rhsInvitedAt, rhsAdminInfo, rhsBanInfo):
            return lhsInvitedAt < rhsInvitedAt
        }
    }

}
