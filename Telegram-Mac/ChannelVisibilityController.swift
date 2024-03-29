//
//  ChannelVisibilityController.swift
//  Telegram
//
//  Created by keepcoder on 23/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore

import SwiftSignalKit

private enum CurrentChannelType {
    case publicChannel
    case privateChannel
}

private enum CurrentChannelJoinToSend {
    case everyone
    case members
}


private final class Arguments {
    let context: AccountContext
    let isNew: Bool
    let onlyUsername: Bool
    
    let updateCurrentType: (CurrentChannelType) -> Void
    let updatePublicLinkText: (String?, String) -> Void
    let displayPrivateLinkMenu: (String) -> Void
    let revokePeerId: (PeerId) -> Void
    let copy:(String)->Void
    let revokeLink: ()->Void
    let share:(String)->Void
    let manageLinks:()->Void
    let open:(_ExportedInvitation)->Void
    let toggleForwarding:(Bool)->Void
    let toggleWrite:(CurrentChannelJoinToSend)->Void
    let toggleApproveNewMembers: (Bool)->Void
    let premiumCallback:()->Void
    let toggleUsername:(TelegramPeerUsername)->Void
    init(context: AccountContext, isNew: Bool, onlyUsername: Bool, updateCurrentType: @escaping (CurrentChannelType) -> Void, updatePublicLinkText: @escaping (String?, String) -> Void, displayPrivateLinkMenu: @escaping (String) -> Void, revokePeerId: @escaping (PeerId) -> Void, copy: @escaping(String)->Void, revokeLink: @escaping()->Void, share: @escaping(String)->Void, manageLinks:@escaping()->Void, open:@escaping(_ExportedInvitation)->Void, toggleForwarding:@escaping(Bool)->Void, toggleWrite:@escaping(CurrentChannelJoinToSend)->Void, toggleApproveNewMembers: @escaping(Bool)->Void, premiumCallback:@escaping()->Void, toggleUsername:@escaping(TelegramPeerUsername)->Void) {
        self.context = context
        self.isNew = isNew
        self.onlyUsername = onlyUsername
        self.updateCurrentType = updateCurrentType
        self.updatePublicLinkText = updatePublicLinkText
        self.displayPrivateLinkMenu = displayPrivateLinkMenu
        self.revokePeerId = revokePeerId
        self.revokeLink = revokeLink
        self.copy = copy
        self.share = share
        self.manageLinks = manageLinks
        self.open = open
        self.toggleForwarding = toggleForwarding
        self.toggleWrite = toggleWrite
        self.toggleApproveNewMembers = toggleApproveNewMembers
        self.premiumCallback = premiumCallback
        self.toggleUsername = toggleUsername
    }
}


fileprivate enum ChannelVisibilityEntryStableId: Hashable {
    case index(Int32)
    case peer(PeerId)
    case username(String)
    var index: Int32 {
        switch self {
        case let .index(index):
            return index
        default:
            fatalError()
        }
    }
}

private enum ChannelVisibilityEntry: TableItemListNodeEntry {
    case typeHeader(sectionId:Int32, String, GeneralViewType)
    case typePublic(sectionId:Int32, Bool, GeneralViewType)
    case typePrivate(sectionId:Int32, Bool, GeneralViewType)
    case typeInfo(sectionId:Int32, String, GeneralViewType)
    
    case publicLinkAvailability(sectionId:Int32, Bool, GeneralViewType)
    case privateLinkHeader(sectionId:Int32, String, GeneralViewType)
    case privateLink(sectionId:Int32, _ExportedInvitation?, PeerInvitationImportersState?, Bool, GeneralViewType)
    case editablePublicLink(sectionId:Int32, String?, String, AddressNameValidationStatus?, GeneralViewType)
    case privateLinkInfo(sectionId:Int32, String, GeneralViewType)
    case publicLinkInfo(sectionId:Int32, String, GeneralViewType)
    case publicLinkStatus(sectionId:Int32, String, AddressNameValidationStatus, GeneralViewType)
    
    case manageLinks(sectionId:Int32, GeneralViewType)
    case manageLinksDesc(sectionId:Int32, GeneralViewType)

    case increaseLimit(sectionId: Int32, counts: PremiumLimitController.Counts?, GeneralViewType)
    case existingLinksInfo(sectionId:Int32, String, GeneralViewType)
    case existingLinkPeerItem(sectionId:Int32, Int32, FoundPeer, ShortPeerDeleting?, Bool, GeneralViewType)
    
    
    case writeHeader(sectionId:Int32, String, GeneralViewType)
    case writeEveryone(sectionId:Int32, Bool, GeneralViewType)
    case writeOnlyMembers(sectionId:Int32, Bool, GeneralViewType)
    
    case approveNewMembers(sectionId:Int32, Bool, GeneralViewType)
    case approveNewMembersInfo(sectionId:Int32, String, GeneralViewType)

    
    case forwardHeader(sectionId:Int32, String, GeneralViewType)
    case allowForward(sectionId:Int32, Bool, GeneralViewType)
    case forwardInfo(sectionId:Int32, String, GeneralViewType)
    
    
    case usernamesTitle(sectionId: Int32, String, GeneralViewType)
    case username(sectionId: Int32, index: Int32, username: TelegramPeerUsername, GeneralViewType)
    case usernamesInfo(sectionId: Int32, index: Int32, String, GeneralViewType)
    
    case section(sectionId:Int32)
    
    var stableId: ChannelVisibilityEntryStableId {
        switch self {
        case .typeHeader:
            return .index(0)
        case .typePublic:
            return .index(1)
        case .typePrivate:
            return .index(2)
        case .typeInfo:
            return .index(3)
        case .publicLinkAvailability:
            return .index(4)
        case .privateLinkHeader:
            return .index(5)
        case .privateLink:
            return .index(6)
        case .editablePublicLink:
            return .index(7)
        case .privateLinkInfo:
            return .index(8)
        case .publicLinkStatus:
            return .index(9)
        case .publicLinkInfo:
            return .index(10)
        case .increaseLimit:
            return .index(11)
        case .existingLinksInfo:
            return .index(12)
        case .manageLinks:
            return .index(13)
        case .manageLinksDesc:
            return .index(14)
        case .writeHeader:
            return .index(15)
        case .writeEveryone:
            return .index(16)
        case .writeOnlyMembers:
            return .index(17)
        case .approveNewMembers:
            return .index(18)
        case .approveNewMembersInfo:
            return .index(19)
        case .forwardHeader:
            return .index(20)
        case .allowForward:
            return .index(21)
        case .forwardInfo:
            return .index(22)
        case .usernamesTitle:
            return .index(23)
        case let .username(_, _, username, _):
            return .username(username.username)
        case let .usernamesInfo(_, index, _, _):
            return .index(24 + index)
        case let .existingLinkPeerItem(_,_, peer, _, _, _):
            return .peer(peer.peer.id)
        case let .section(sectionId: sectionId):
            return .index((sectionId + 1) * 1000 - sectionId)
        }
    }
    
    var index: Int32 {
        switch self {
        case let .typeHeader(sectionId: sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .typePublic(sectionId: sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .typePrivate(sectionId: sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .typeInfo(sectionId: sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .publicLinkAvailability(sectionId: sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .privateLinkHeader(sectionId: sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .privateLink(sectionId: sectionId, _, _, _, _):
            return (sectionId * 1000) + stableId.index
        case let .editablePublicLink(sectionId: sectionId, _, _, _, _):
            return (sectionId * 1000) + stableId.index
        case let .privateLinkInfo(sectionId: sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .publicLinkStatus(sectionId: sectionId, _, _, _):
            return (sectionId * 1000) + stableId.index
        case let .publicLinkInfo(sectionId: sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .increaseLimit(sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .existingLinksInfo(sectionId: sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .manageLinks(sectionId: sectionId, _):
            return (sectionId * 1000) + stableId.index
        case let .manageLinksDesc(sectionId: sectionId, _):
            return (sectionId * 1000) + stableId.index
        case let .writeHeader(sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .writeEveryone(sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .writeOnlyMembers(sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .approveNewMembers(sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .approveNewMembersInfo(sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .forwardHeader(sectionId, _ , _):
            return (sectionId * 1000) + stableId.index
        case let .allowForward(sectionId, _ , _):
            return (sectionId * 1000) + stableId.index
        case let .forwardInfo(sectionId, _ , _):
            return (sectionId * 1000) + stableId.index
        case let .usernamesTitle(sectionId, _, _):
            return (sectionId * 1000) + stableId.index
        case let .username(sectionId, index, _, _):
            return (sectionId * 1000) + 200 + index
        case let .usernamesInfo(sectionId, index, _, _):
            return (sectionId * 1000) + 200 + index
        case let .existingLinkPeerItem(sectionId, index, _, _, _, _):
            return (sectionId * 1000) + index + 100
        case let .section(sectionId: sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func <(lhs: ChannelVisibilityEntry, rhs: ChannelVisibilityEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: Arguments, initialSize:NSSize) -> TableRowItem {
        switch self {
        case let .typeHeader(_, title, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: title, viewType: viewType)
        case let .typePublic(_, selected, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().channelPublic, type: .selectable(selected), viewType: viewType, action: {
                arguments.updateCurrentType(.publicChannel)
            })
        case let .typePrivate(_, selected, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().channelPrivate, type: .selectable(selected), viewType: viewType, action: {
                arguments.updateCurrentType(.privateChannel)
            })
        case let .typeInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .publicLinkAvailability(_, value, viewType):
            let color: NSColor
            let text: String
            if value {
                text = strings().channelVisibilityChecking
                color = theme.colors.grayText
            } else {
                text = strings().channelPublicNamesLimitError
                color = theme.colors.redUI
            }
            return GeneralTextRowItem(initialSize, stableId: stableId, text: .initialize(string: text, color: color, font: .normal(.text)), viewType: viewType)
        case let .privateLinkHeader(_, title, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: title, viewType: viewType)
        case let .privateLink(_, link, importers, isNew, viewType):
            
            var peers = importers?.importers.map { $0.peer } ?? []
            peers = Array(peers.prefix(3))
            
            return ExportedInvitationRowItem(initialSize, stableId: stableId, context: arguments.context, exportedLink: link, lastPeers: peers, viewType: viewType, mode: isNew ? .short : .normal(hasUsage: true), menuItems: {
                
                var items:[ContextMenuItem] = []
                if let link = link {
                    items.append(ContextMenuItem(strings().channelVisibiltiyContextCopy, handler: {
                        arguments.copy(link.link)
                    }, itemImage: MenuAnimation.menu_copy.value))
                    items.append(ContextSeparatorItem())
                    items.append(ContextMenuItem(strings().channelVisibiltiyContextRevoke, handler: {
                        arguments.revokeLink()
                    }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                }
                
                return .single(items)
            }, share: arguments.share, open: arguments.open, copyLink: arguments.copy)

        case let .editablePublicLink(_, currentText, text, status, viewType):
            var rightItem: InputDataRightItem? = nil
            if let status = status {
                switch status {
                case .checking:
                    rightItem = .loading
                default:
                    break
                }
            }
            return InputDataRowItem(initialSize, stableId: stableId, mode: .plain, error: nil, viewType: viewType, currentText: text, placeholder: nil, inputPlaceholder: "t.me", defaultText:"https://t.me/", rightItem: rightItem, filter: { $0 }, updated: { updatedText in
                arguments.updatePublicLinkText(currentText, updatedText)
            }, limit: 32 + 13)
        case let .privateLinkInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .publicLinkInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .publicLinkStatus(_, addressName, status, viewType):
            
            var text:String = ""
            var color:NSColor = .text
            
            switch status {
            case let .invalidFormat(format):
                text = format.description
                color = theme.colors.redUI
            case let .availability(availability):
                text = availability.description(for: addressName, target: .channel)
                switch availability {
                case .available:
                    color = theme.colors.accent
                case .purchaseAvailable:
                    color = theme.colors.grayText
                default:
                    color = theme.colors.redUI
                }
            default:
                break
            }
            
            return GeneralTextRowItem(initialSize, stableId: stableId, text: .markdown(text, linkHandler: { link in
                if link == "fragment" {
                    let link: String = "fragment.com/username/\(addressName)"
                    execute(inapp: inApp(for: link.nsstring))
                }
            }), textColor: color, viewType: viewType)
        case let .increaseLimit(_, counts, viewType):
            return PremiumIncreaseLimitItem(initialSize, stableId: stableId, context: arguments.context, type: .publicLink, counts: counts, viewType: viewType, callback: arguments.premiumCallback)
        case let .existingLinksInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .existingLinkPeerItem(_, _, peer, _, _, viewType):
            return ShortPeerRowItem(initialSize, peer: peer.peer, account: arguments.context.account, context: arguments.context, status: "t.me/\(peer.peer.addressName ?? "unknown")", inset: NSEdgeInsets(left: 20, right: 20), interactionType:.deletable(onRemove: { peerId in
                arguments.revokePeerId(peerId)
            }, deletable: true), viewType: viewType)
        case let .manageLinks(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().channelVisibiltiyManageLinks, icon: theme.icons.group_invite_via_link, nameStyle: blueActionButton, type: .none, viewType: viewType, action: arguments.manageLinks)
        case let .manageLinksDesc(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: strings().manageLinksEmptyDesc, detectBold: true, textColor: theme.colors.listGrayText, viewType: viewType)
        case let .writeHeader(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, detectBold: true, textColor: theme.colors.listGrayText, viewType: viewType)
        case let .writeEveryone(_, selected, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().channelVisibilityMessagesEveryone, type: .selectable(selected), viewType: viewType, action: {
                arguments.toggleWrite(.everyone)
                arguments.toggleApproveNewMembers(false)

            })
        case let .writeOnlyMembers(_, selected, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().channelVisibilityMessagesMembers, type: .selectable(selected), viewType: viewType, action: {
                arguments.toggleWrite(.members)
            })
        case let .approveNewMembers(_, selected, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().channelVisibilityMessagesApprove, type: .switchable(selected), viewType: viewType, action: {
                arguments.toggleApproveNewMembers(!selected)
            })
        case let .approveNewMembersInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, detectBold: true, textColor: theme.colors.listGrayText, viewType: viewType)
        case let .forwardHeader(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, detectBold: true, textColor: theme.colors.listGrayText, viewType: viewType)
        case let .allowForward(_, selected, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().channelVisibilityForwardingRestrict, type: .switchable(selected), viewType: viewType, action: {
                arguments.toggleForwarding(!selected)
            })
        case let .forwardInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, detectBold: true, textColor: theme.colors.listGrayText, viewType: viewType)
        case let .usernamesTitle(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, detectBold: true, textColor: theme.colors.listGrayText, viewType: viewType)
        case let .usernamesInfo(_, _, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, detectBold: true, textColor: theme.colors.listGrayText, viewType: viewType)
        case let .username(_, _, username, viewType):
            return ExternalUsernameRowItem.init(initialSize, stableId: stableId, username: username, viewType: viewType, activate: {
                arguments.toggleUsername(username)
            })
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId, viewType: .separator)
        }
 
    }
}


private struct State: Equatable {
    var selectedType: CurrentChannelType?
    var editingPublicLinkText: String?
    var addressNameValidationStatus: AddressNameValidationStatus?
    var updatingAddressName: Bool
    var revokingPeerId: PeerId?
    var forwardingEnabled: Bool?
    var joinToSend: CurrentChannelJoinToSend?
    var approveMembers: Bool?
    var peer: PeerEquatable?
    var cachedData: CachedDataEquatable?
    var usernames: [TelegramPeerUsername]
    var importers: PeerInvitationImportersState?
    var counts: PremiumLimitController.Counts?
    var publicChannelsToRevoke: [PeerEquatable]?
    init() {
        self.selectedType = nil
        self.editingPublicLinkText = nil
        self.addressNameValidationStatus = nil
        self.updatingAddressName = false
        self.revokingPeerId = nil
        self.forwardingEnabled = nil
        self.joinToSend = nil
        self.approveMembers = nil
        self.usernames = []
        
    }
}

private func entries(arguments: Arguments, state: State) -> [ChannelVisibilityEntry] {
    var entries: [ChannelVisibilityEntry] = []
    
    var sectionId:Int32 = 0
    
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    if let peer = state.peer?.peer as? TelegramChannel {
        var isGroup = false
        if case .group = peer.info {
            isGroup = true
        }
        
        let selectedType: CurrentChannelType
        if let current = state.selectedType {
            selectedType = current
        } else {
            if let addressName = peer.addressName, !addressName.isEmpty {
                selectedType = .publicChannel
            } else {
                selectedType = .privateChannel
            }
        }
        
        let currentAddressName: String
        if let current = state.editingPublicLinkText {
            currentAddressName = current
        } else {
            if let addressName = peer.addressName {
                currentAddressName = addressName
            } else {
                currentAddressName = ""
            }
        }
        
        entries.append(.typeHeader(sectionId: sectionId, isGroup ? strings().channelTypeHeaderGroup : strings().channelTypeHeaderChannel, .textTopItem))
        entries.append(.typePublic(sectionId: sectionId, selectedType == .publicChannel, .firstItem))
        entries.append(.typePrivate(sectionId: sectionId, selectedType == .privateChannel, .lastItem))
        
        switch selectedType {
        case .publicChannel:
            entries.append(.typeInfo(sectionId: sectionId, isGroup ? strings().channelPublicAboutGroup : strings().channelPublicAboutChannel, .textBottomItem))
        case .privateChannel:
            entries.append(.typeInfo(sectionId: sectionId, isGroup ? strings().channelPrivateAboutGroup : strings().channelPrivateAboutChannel, .textBottomItem))
        }
        
        entries.append(.section(sectionId: sectionId))
        sectionId += 1
        
        switch selectedType {
        case .publicChannel:
            var displayAvailability = false
            if peer.addressName == nil {
                displayAvailability = state.publicChannelsToRevoke == nil || !(state.publicChannelsToRevoke!.isEmpty)
            }
            if displayAvailability {
                if let publicChannelsToRevoke = state.publicChannelsToRevoke {
                    
                    if !arguments.context.isPremium && !arguments.context.premiumIsBlocked {
                        entries.append(.increaseLimit(sectionId: sectionId, counts: state.counts, .singleItem))
                    } else {
                        entries.append(.publicLinkAvailability(sectionId: sectionId, false, .textTopItem))
                    }
                    
                    var index: Int32 = 0
                    
                    let sorted = publicChannelsToRevoke.sorted(by: { lhs, rhs in
                        var lhsDate: Int32 = 0
                        var rhsDate: Int32 = 0
                        if let lhs = lhs.peer as? TelegramChannel {
                            lhsDate = lhs.creationDate
                        }
                        if let rhs = rhs.peer as? TelegramChannel {
                            rhsDate = rhs.creationDate
                        }
                        return lhsDate > rhsDate
                    })
                    
                    for (i, peer) in sorted.enumerated() {
                        entries.append(.existingLinkPeerItem(sectionId: sectionId, index, FoundPeer(peer: peer.peer, subscribers: nil), nil, state.revokingPeerId == nil, bestGeneralViewType(sorted, for: i)))
                        index += 1
                    }
                } else {
                    entries.append(.publicLinkAvailability(sectionId: sectionId, true, .singleItem))
                }
            } else {
                entries.append(.editablePublicLink(sectionId: sectionId, peer.addressName, currentAddressName, state.addressNameValidationStatus, .singleItem))
                if let status = state.addressNameValidationStatus {
                    switch status {
                    case .invalidFormat, .availability:
                        entries.append(.publicLinkStatus(sectionId: sectionId, currentAddressName, status, .textBottomItem))
                    default:
                        break
                    }
                }
                entries.append(.publicLinkInfo(sectionId: sectionId, isGroup ? strings().channelUsernameAboutGroup : strings().channelUsernameAboutChannel, .textBottomItem))
            }
            
            if !state.usernames.isEmpty {
                let isGroup = peer.isGroup || peer.isSupergroup
                
                entries.append(.section(sectionId: sectionId))
                sectionId += 1
                let title = strings().channelUsernameListTitle
                let info = isGroup ? strings().channelUsernameListInfoGroup : strings().channelUsernameListInfoChannel
                entries.append(.usernamesTitle(sectionId: sectionId, title, .textTopItem))
                
                var index:Int32 = 0
                for (i, username) in state.usernames.enumerated() {
                    entries.append(.username(sectionId: sectionId, index: index, username: username, bestGeneralViewType(state.usernames, for: i)))
                    index += 1
                }
                index += 1
                entries.append(.usernamesInfo(sectionId: sectionId, index: index, info, .textBottomItem))
            }


            if peer.addressName != nil {
                entries.append(.section(sectionId: sectionId))
                sectionId += 1
                entries.append(.manageLinks(sectionId: sectionId, .singleItem))
            }
            
        case .privateChannel:
            entries.append(.privateLinkHeader(sectionId: sectionId, strings().channelVisibiltiyPermanentLink, .textTopItem))
            entries.append(.privateLink(sectionId: sectionId, (state.cachedData?.data as? CachedChannelData)?.exportedInvitation?._invitation, state.importers, arguments.isNew, .singleItem))
            entries.append(.publicLinkInfo(sectionId: sectionId, isGroup ? strings().channelExportLinkAboutGroup : strings().channelExportLinkAboutChannel, .textBottomItem))

            entries.append(.section(sectionId: sectionId))
            sectionId += 1
            entries.append(.manageLinks(sectionId: sectionId, .singleItem))
            entries.append(.manageLinksDesc(sectionId: sectionId, .textBottomItem))
        }
                
    } else if let peer = state.peer?.peer as? TelegramGroup {

        let selectedType: CurrentChannelType
        if let current = state.selectedType {
            selectedType = current
        } else {
            if let addressName = peer.addressName, !addressName.isEmpty {
                selectedType = .publicChannel
            } else {
                selectedType = .privateChannel
            }
        }
        
        let currentAddressName: String
        if let current = state.editingPublicLinkText {
            currentAddressName = current
        } else {
            if let addressName = peer.addressName {
                currentAddressName = addressName
            } else {
                currentAddressName = ""
            }
        }
        
        entries.append(.typeHeader(sectionId: sectionId, strings().channelTypeHeaderGroup, .textTopItem))
        entries.append(.typePublic(sectionId: sectionId, selectedType == .publicChannel, .firstItem))
        entries.append(.typePrivate(sectionId: sectionId, selectedType == .privateChannel, .lastItem))
        
        switch selectedType {
        case .publicChannel:
            entries.append(.typeInfo(sectionId: sectionId, strings().channelPublicAboutGroup, .textBottomItem))

        case .privateChannel:
            entries.append(.typeInfo(sectionId: sectionId, strings().channelPrivateAboutGroup, .textBottomItem))
        }
        
        entries.append(.section(sectionId: sectionId))
        sectionId += 1
        
        switch selectedType {
        case .publicChannel:
            var displayAvailability = false
            if peer.addressName == nil {
                displayAvailability = state.publicChannelsToRevoke == nil || !(state.publicChannelsToRevoke!.isEmpty)
            }
            
            if displayAvailability {
                if let publicChannelsToRevoke = state.publicChannelsToRevoke {
                    
                    if !arguments.context.isPremium && !arguments.context.premiumIsBlocked {
                        entries.append(.increaseLimit(sectionId: sectionId, counts: state.counts, .singleItem))
                    } else {
                        entries.append(.publicLinkAvailability(sectionId: sectionId, false, .singleItem))
                    }
                    
                    var index: Int32 = 0
                    let sorted = publicChannelsToRevoke.sorted(by: { lhs, rhs in
                        var lhsDate: Int32 = 0
                        var rhsDate: Int32 = 0
                        if let lhs = lhs.peer as? TelegramGroup {
                            lhsDate = lhs.creationDate
                        }
                        if let rhs = rhs.peer as? TelegramGroup {
                            rhsDate = rhs.creationDate
                        }
                        return lhsDate > rhsDate
                    })
                    for (i, peer) in sorted.enumerated() {
                        entries.append(.existingLinkPeerItem(sectionId: sectionId, index, FoundPeer(peer: peer.peer, subscribers: nil), nil, state.revokingPeerId == nil, bestGeneralViewType(sorted, for: i)))
                        index += 1
                    }
                } else {
                    entries.append(.publicLinkAvailability(sectionId: sectionId, true, .textTopItem))
                }
            } else {
                entries.append(.editablePublicLink(sectionId: sectionId, peer.addressName, currentAddressName, state.addressNameValidationStatus, .singleItem))
                if let status = state.addressNameValidationStatus {
                    switch status {
                    case .invalidFormat, .availability:
                        entries.append(.publicLinkStatus(sectionId: sectionId, currentAddressName, status, .singleItem))
                    default:
                        break
                    }
                }
                entries.append(.publicLinkInfo(sectionId: sectionId, strings().channelUsernameAboutGroup, .textBottomItem))
            }
            
        case .privateChannel:
            entries.append(.privateLinkHeader(sectionId: sectionId, strings().channelVisibiltiyPermanentLink, .textTopItem))
            entries.append(.privateLink(sectionId: sectionId, (state.cachedData?.data as? CachedGroupData)?.exportedInvitation?._invitation, state.importers, arguments.isNew, .singleItem))
            entries.append(.publicLinkInfo(sectionId: sectionId, strings().channelExportLinkAboutGroup, .textBottomItem))
            
            entries.append(.section(sectionId: sectionId))
            sectionId += 1
            entries.append(.manageLinks(sectionId: sectionId, .singleItem))
           
        }
    }
    
    if let peer = state.peer?.peer  {
      
        
       
        entries.append(.section(sectionId: sectionId))
        sectionId += 1
        
        if let channel = peer as? TelegramChannel, channel.isSupergroup {
            
            
            
            var isDiscussion = false
            if let cachedData = state.cachedData?.data as? CachedChannelData, case let .known(peerId) = cachedData.linkedDiscussionPeerId, peerId != nil {
                isDiscussion = true
            }
            
            if  (state.selectedType == .publicChannel || isDiscussion || (state.selectedType == nil && channel.addressName != nil)) {
                
                let mode: CurrentChannelJoinToSend
                if let value = state.joinToSend {
                    mode = value
                } else {
                    if channel.flags.contains(.joinToSend) {
                        mode = .members
                    } else {
                        mode = .everyone
                    }
                }
                
                if isDiscussion {
                    entries.append(.writeHeader(sectionId: sectionId, strings().channelVisibilityMessagesWho, .textTopItem))
                    entries.append(.writeEveryone(sectionId: sectionId, mode == .everyone, .firstItem))
                    entries.append(.writeOnlyMembers(sectionId: sectionId, mode == .members, .lastItem))
                }
                
                
                if mode == .members || !isDiscussion {
                    if isDiscussion {
                        entries.append(.section(sectionId: sectionId))
                        sectionId += 1
                    }
                    
                    let approve: Bool
                    if let value = state.approveMembers {
                        approve = value
                    } else {
                        approve = channel.flags.contains(.requestToJoin)
                    }
                    entries.append(.approveNewMembers(sectionId: sectionId, approve, .singleItem))
                    entries.append(.approveNewMembersInfo(sectionId: sectionId, strings().channelVisibilityMessagesApproveInfo, .textBottomItem))
                }
                
                entries.append(.section(sectionId: sectionId))
                sectionId += 1
            }
            
        }
        
               
        let allowed: Bool
        if let value = state.forwardingEnabled {
            allowed = value
        } else {
            if let peer = peer as? TelegramGroup {
                allowed = !peer.flags.contains(.copyProtectionEnabled)
            } else if let peer = peer as? TelegramChannel {
                allowed = !peer.flags.contains(.copyProtectionEnabled)
            } else {
                allowed = false
            }
        }
        
        
        entries.append(.allowForward(sectionId: sectionId, !allowed, .singleItem))
        
        let desc: String
        
        if peer.isChannel {
            if allowed {
                desc = strings().channelVisibilityForwardingChannelInfo1
            } else {
                desc = strings().channelVisibilityForwardingChannelInfo1Restrict
            }
        } else {
            if allowed {
                desc = strings().channelVisibilityForwardingGroupInfo1
            } else {
                desc = strings().channelVisibilityForwardingGroupInfo1Restrict
            }
        }
        entries.append(.forwardInfo(sectionId: sectionId, desc, .textBottomItem))
        
    }
    
    entries.append(.section(sectionId: sectionId))
    sectionId += 1

    return entries
}
private func effectiveChannelType(state: State, peer: TelegramChannel) -> CurrentChannelType {
    let selectedType: CurrentChannelType
    if let current = state.selectedType {
        selectedType = current
    } else {
        if let addressName = peer.addressName, !addressName.isEmpty {
            selectedType = .publicChannel
        } else {
            selectedType = .privateChannel
        }
    }
    return selectedType
}

private func updatedAddressName(state: State, peer: Peer) -> String? {
    if let peer = peer as? TelegramChannel {
        let selectedType = effectiveChannelType(state: state, peer: peer)
        
        let currentAddressName: String
        
        switch selectedType {
        case .privateChannel:
            currentAddressName = ""
        case .publicChannel:
            if let current = state.editingPublicLinkText {
                currentAddressName = current
            } else {
                if let addressName = peer.addressName {
                    currentAddressName = addressName
                } else {
                    currentAddressName = ""
                }
            }
        }
        
        if !currentAddressName.isEmpty {
            if currentAddressName != peer.addressName {
                return currentAddressName
            } else {
                return nil
            }
        } else if peer.addressName != nil {
            return ""
        } else {
            return nil
        }
    } else if let _ = peer as? TelegramGroup {
        let currentAddressName = state.editingPublicLinkText ?? ""
        if !currentAddressName.isEmpty {
            return currentAddressName
        } else {
            return nil
        }
    } else {
        return nil
    }
}



fileprivate func prepareTransition(left:[AppearanceWrapperEntry<ChannelVisibilityEntry>], right: [AppearanceWrapperEntry<ChannelVisibilityEntry>], initialSize:NSSize, arguments:Arguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}



class ChannelVisibilityController: EmptyComposeController<Void, PeerId?, TableView> {
    fileprivate let statePromise = ValuePromise(State(), ignoreRepeated: true)
    fileprivate let stateValue = Atomic(value: State())
    
  
    private let checkAddressNameDisposable = MetaDisposable()
    private let updateAddressNameDisposable = MetaDisposable()
    private let revokeAddressNameDisposable = MetaDisposable()
    private let toggleForwardDisposable = MetaDisposable()
    private let disposable = MetaDisposable()
    private let exportedLinkDisposable = MetaDisposable()
    let peerId:PeerId
    let onlyUsername:Bool
    let isChannel: Bool
    let linksManager: InviteLinkPeerManager?
    let isNew: Bool
    init(_ context: AccountContext, peerId:PeerId, isChannel: Bool, onlyUsername: Bool = false, isNew: Bool = false, linksManager: InviteLinkPeerManager? = nil) {
        self.peerId = peerId
        self.onlyUsername = onlyUsername
        self.isChannel = isChannel
        self.isNew = isNew
        self.linksManager = linksManager
        
        super.init(context)
    }
    
    override var defaultBarTitle: String {
        if isChannel {
            return strings().telegramChannelVisibilityControllerChannel
        } else {
            return strings().telegramChannelVisibilityControllerGroup
        }
    }
    
    override var enableBack: Bool {
        return true
    }
    override func backKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override func firstResponder() -> NSResponder? {
        var responder: NSResponder?
        genericView.enumerateViews { view -> Bool in
            if responder == nil, let firstResponder = view.firstResponder {
                responder = firstResponder
                return false
            }
            return true
        }
        return responder
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.getBackgroundColor = {
            theme.colors.listBackground
        }
        
        let actionsDisposable = DisposableSet()
        
        
        let toggleCopyProtectionDisposable = MetaDisposable()
        actionsDisposable.add(toggleCopyProtectionDisposable)
        
        let toggleJoinToSendDisposable = MetaDisposable()
        actionsDisposable.add(toggleJoinToSendDisposable)
        
        let toggleRequestToJoinDisposable = MetaDisposable()
        actionsDisposable.add(toggleRequestToJoinDisposable)

        
        onDeinit = {
            actionsDisposable.dispose()
        }
        
        let context = self.context
        let peerId = self.peerId
        let stateValue = self.stateValue
        
        let updateState: ((State) -> State) -> Void = { [weak self] f in
            if let strongSelf = self {
                strongSelf.statePromise.set(strongSelf.stateValue.modify { f($0) })
            }
        }
        
        
        let addressNameAssignment: Signal<[Peer]?, NoError> = .single(nil) |> then(context.engine.peers.channelAddressNameAssignmentAvailability(peerId: peerId.namespace == Namespaces.Peer.CloudChannel ? peerId : nil) |> mapToSignal { result -> Signal<[Peer]?, NoError> in
            if case .addressNameLimitReached = result {
                return context.engine.peers.adminedPublicChannels()
                |> map { Optional($0.map { $0.peer._asPeer() }) }
            } else {
                return .single([])
            }
        })
        
        let arguments = Arguments(context: context, isNew: self.isNew, onlyUsername: self.onlyUsername, updateCurrentType: { type in
            updateState { current in
                var current = current
                current.selectedType = type
                return current
            }
        }, updatePublicLinkText: { [weak self] currentText, text in
            if text.isEmpty {
                self?.checkAddressNameDisposable.set(nil)
                updateState { current in
                    var current = current
                    current.editingPublicLinkText = text
                    current.addressNameValidationStatus = nil
                    return current
                }
            } else if currentText == text {
                self?.checkAddressNameDisposable.set(nil)
                updateState { current in
                    var current = current
                    current.editingPublicLinkText = text
                    current.addressNameValidationStatus = nil
                    return current
                }
            } else {
                updateState { current in
                    var current = current
                    current.editingPublicLinkText = text
                    return current
                }
                
                self?.checkAddressNameDisposable.set((context.engine.peers.validateAddressNameInteractive(domain: .peer(peerId), name: text)
                    |> deliverOnMainQueue).start(next: { result in
                    updateState { current in
                        var current = current
                        current.addressNameValidationStatus = result
                        return current
                    }
                }))
            }
        }, displayPrivateLinkMenu: { [weak self] text in
            self?.show(toaster: ControllerToaster(text: strings().shareLinkCopied))
            copyToClipboard(text)
        }, revokePeerId: { [weak self] peerId in
            updateState { current in
                var current = current
                current.revokingPeerId = peerId
                return current
            }
            self?.revokeAddressNameDisposable.set((verifyAlertSignal(for: context.window, information: strings().channelVisibilityConfirmRevoke) |> mapToSignalPromotingError { result -> Signal<Bool, UpdateAddressNameError> in
                if result == nil {
                    return .fail(.generic)
                } else {
                    return .single(true)
                }
            } |> mapToSignal { _ -> Signal<Void, UpdateAddressNameError> in
                return context.engine.peers.updateAddressName(domain: .peer(peerId), name: nil)
            } |> deliverOnMainQueue).start(error: { _ in
                updateState { current in
                    var current = current
                    current.revokingPeerId = nil
                    return current
                }
            }, completed: {
                updateState { current in
                    var current = current
                    current.revokingPeerId = nil
                    current.publicChannelsToRevoke = []
                    return current
                }
            }))
        }, copy: { [weak self] link in
            self?.show(toaster: ControllerToaster(text: strings().shareLinkCopied))
            copyToClipboard(link)
        }, revokeLink: {
            verifyAlert_button(for: context.window, header: strings().channelRevokeLinkConfirmHeader, information: strings().channelRevokeLinkConfirmText, ok: strings().channelRevokeLinkConfirmOK, cancel: strings().modalCancel, successHandler: { _ in
                _ = showModalProgress(signal: context.engine.peers.revokePersistentPeerExportedInvitation(peerId: peerId), for: context.window).start()
            })
        }, share: { link in
            showModal(with: ShareModalController(ShareLinkObject.init(context, link: link)), for: context.window)
        }, manageLinks: { [weak self] in
            self?.navigationController?.push(InviteLinksController(context: context, peerId: peerId, manager: self?.linksManager))
        }, open: { [weak self] invitation in
            if let manager = self?.linksManager {
                showModal(with: ExportedInvitationController(invitation: invitation, peerId: peerId, accountContext: context, manager: manager, context: manager.importer(for: invitation)), for: context.window)
            }
        }, toggleForwarding: { value in
            updateState { current in
                var current = current
                current.forwardingEnabled = value
                return current
            }
        }, toggleWrite: { value in
            updateState { current in
                var current = current
                current.joinToSend = value
                return current
            }
        }, toggleApproveNewMembers: { value in
            updateState { current in
                var current = current
                current.approveMembers = value
                return current
            }
        }, premiumCallback: {
            
        }, toggleUsername: { username in
            guard !username.flags.contains(.isEditable) else {
                return
            }
            
            let value = !username.flags.contains(.isActive)
            var updatedFlags: TelegramPeerUsername.Flags = username.flags
            if value {
                updatedFlags.insert(.isActive)
            } else {
                updatedFlags.remove(.isActive)
            }
            
            let isGroup = stateValue.with { $0.peer?.peer.isGroup == true || $0.peer?.peer.isSupergroup == true } 
            
            let activate_t = isGroup ? strings().channelUsernameActivateTitleGroup : strings().channelUsernameActivateTitleChannel
            let activate_i = isGroup ? strings().channelUsernameActivateInfoGroup : strings().channelUsernameActivateInfoChannel
            let activate_ok = isGroup ? strings().channelUsernameActivateOkGroup : strings().channelUsernameActivateOkChannel

            let deactivate_t = isGroup ? strings().channelUsernameDeactivateTitleGroup : strings().channelUsernameDeactivateTitleChannel
            let deactivate_i = isGroup ? strings().channelUsernameDeactivateInfoGroup : strings().channelUsernameDeactivateInfoChannel
            let deactivate_ok = isGroup ? strings().channelUsernameDeactivateOkGroup : strings().channelUsernameDeactivateOkChannel

            
            
            let title: String = value ? activate_t : deactivate_t
            let info: String = value ? activate_i : deactivate_i
            let ok: String = value ? activate_ok : deactivate_ok
            
            
            verifyAlert_button(for: context.window, header: title, information: info, ok: ok, successHandler: { _ in
                _ = context.engine.peers.toggleAddressNameActive(domain: .peer(peerId), name: username.username, active: value).start()
                
                updateState { current in
                    var current = current
                    
                    let index = current.usernames.firstIndex(where: { $0.username == username.username })
                    if let index = index {
                        current.usernames[index] = .init(flags: updatedFlags, username: username.username)
                    }
                    return current
                }
            })
        })
        
        
        let peerView = context.account.viewTracker.peerView(peerId)
        
        let initialSize = atomicSize
        let previousEntries:Atomic<[AppearanceWrapperEntry<ChannelVisibilityEntry>]> = Atomic(value: [])

        
        let permanentLink = peerView |> map {
            ($0.cachedData as? CachedChannelData)?.exportedInvitation?._invitation ?? ($0.cachedData as? CachedGroupData)?.exportedInvitation?._invitation
        }
        
        let manager = self.linksManager
        
        let importers: Signal<PeerInvitationImportersState?, NoError> = permanentLink |> deliverOnMainQueue |> mapToSignal { [weak manager] permanent in
            if let permanent = permanent {
                if enableBetaFeatures {
                    if let state = manager?.importer(for: permanent).joined.state {
                        return state |> map(Optional.init)
                    } else {
                        return .single(nil)
                    }
                } else {
                    return .single(nil)
                }
            } else {
                return .single(nil)
            }
        }
        
        
        actionsDisposable.add(combineLatest(peerView, addressNameAssignment, importers).start(next: { peerView, publicChannelsToRevoke, importers in
            updateState { current in
                var current = current
                
                current.peer = PeerEquatable(peerViewMainPeer(peerView))
                current.cachedData = CachedDataEquatable(peerView.cachedData)
                current.publicChannelsToRevoke = publicChannelsToRevoke?.map {
                    .init($0)
                }
                current.importers = importers
                current.counts = .init(publicLinksCount: publicChannelsToRevoke?.count)
                current.usernames = current.peer?.peer.usernames ?? []
                return current
            }
        }))
        
        
        let apply = combineLatest(queue: .mainQueue(), statePromise.get(), appearanceSignal)
            |> map { state, appearance -> (TableUpdateTransition, Bool, State) in
                
                var doneEnabled = true

                if let selectedType = state.selectedType {
                    switch selectedType {
                    case .privateChannel:
                        break
                    case .publicChannel:
                        if let addressNameValidationStatus = state.addressNameValidationStatus {
                            switch addressNameValidationStatus {
                            case .availability(.available):
                                break
                            default:
                                doneEnabled = false
                            }
                        } else if let _ = state.publicChannelsToRevoke {
                            doneEnabled = false
                        }
                        
                    }
                }
                
                let entries = entries(arguments: arguments, state: state).map {
                    AppearanceWrapperEntry(entry: $0, appearance: appearance)
                }
                
                return (prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.with { $0 }, arguments: arguments), doneEnabled, state)
            } |> deliverOnMainQueue
        
        disposable.set(apply.start(next: { [weak self] transition, doneEnabled, state in
            if let strongSelf = self {
                strongSelf.genericView.merge(with: transition)
                strongSelf.readyOnce()
                
                var range: NSRange = NSMakeRange(NSNotFound, 0)
                
                strongSelf.genericView.enumerateItems(with: { item in
                    if let item = item as? ExternalUsernameRowItem {
                        if item.username.flags.contains(.isActive) {
                            if range.location == NSNotFound {
                                range.location = item.index
                            }
                            range.length += 1
                        } else {
                            return false
                        }
                    }
                    return true
                })
                
                if range.location != NSNotFound {
                    strongSelf.genericView.resortController = .init(resortRange: range, start: { _ in
                        
                    }, resort: { _ in }, complete: { from, to in
                        let fromValue = from - range.location
                        let toValue = to - range.location
                        var names = stateValue.with { $0.usernames }
                        names.move(at: fromValue, to: toValue)
                        updateState { current in
                            var current = current
                            current.usernames = names
                            return current
                        }
                        actionsDisposable.add(context.engine.peers.reorderAddressNames(domain: .peer(peerId), names: names).start())
                    })
                } else {
                    strongSelf.genericView.resortController = nil
                }
                
                strongSelf.doneButton?.isEnabled = doneEnabled
                strongSelf.doneButton?.removeAllHandlers()
                
                strongSelf.doneButton?.set(handler: { [weak self] _ in
                    if let peer = state.peer?.peer {
                        var updatedAddressNameValue: String?
                        
                        self?.updateState { current in
                            var current = current
                            updatedAddressNameValue = updatedAddressName(state: state, peer: peer)
                            if updatedAddressNameValue != nil {
                                current.updatingAddressName = true
                            }
                            return current
                        }
                        
                        var signals: [Signal<Never, NoError>] = []
                        
                        if let updatedCopyProtection = state.forwardingEnabled {
                            signals.append(context.engine.peers.toggleMessageCopyProtection(peerId: peerId, enabled: updatedCopyProtection) |> ignoreValues)
                        }
                        
                        if let updatedJoinToSend = state.joinToSend {
                            signals.append(context.engine.peers.toggleChannelJoinToSend(peerId: peerId, enabled: updatedJoinToSend == .members) |> `catch` { _ in .complete() })
                        }
                        
                        if let updatedApproveMembers = state.approveMembers {
                            signals.append(context.engine.peers.toggleChannelJoinRequest(peerId: peerId, enabled: updatedApproveMembers)
                                           |> `catch` { _ in
                                .complete()
                            })
                        }
                                        
                        
                        if let updatedAddressNameValue = updatedAddressNameValue {
                           
                            
                            let signal: Signal<PeerId?, ConvertGroupToSupergroupError>
                            
                            let csignal: Signal<Void, UpdateAddressNameError>
                            
                            if updatedAddressNameValue.isEmpty && peer.addressName != updatedAddressNameValue, let address = peer.addressName {
                                let text: String
                                if peer.isChannel {
                                    text = strings().channelVisibilityConfirmMakePrivateChannel(address)
                                } else {
                                    text = strings().channelVisibilityConfirmMakePrivateGroup(address)
                                }
                                csignal = verifyAlertSignal(for: context.window, information: text) |> filter { $0 == .basic } |> take(1) |> map { _ in
                                    
                                    updateState { current in
                                        var current = current
                                        current.updatingAddressName = true
                                        return current
                                    }
        
                                } |> castError(UpdateAddressNameError.self)
                            } else {
                                csignal = .single(Void()) |> map {
                                    updateState { current in
                                        var current = current
                                        current.updatingAddressName = true
                                        return current
                                    }
                                }
                            }
                            
                            if peer.isGroup {
                                
                                signal = context.engine.peers.convertGroupToSupergroup(peerId: peerId)
                                    |> mapToSignal { upgradedPeerId -> Signal<PeerId?, ConvertGroupToSupergroupError> in
                                        return csignal
                                            |> mapToSignal {
                                                showModalProgress(signal: context.engine.peers.updateAddressName(domain: .peer(upgradedPeerId), name: updatedAddressNameValue.isEmpty ? nil : updatedAddressNameValue), for: context.window)
                                            }
                                        |> mapError {_ in return ConvertGroupToSupergroupError.generic}
                                        |> mapToSignal { _ in
                                            return .single(Optional(upgradedPeerId))
                                        }
                                    }
                                    |> deliverOnMainQueue
                            } else {
                               
                                signal = csignal
                                    |> mapToSignal {
                                        showModalProgress(signal: context.engine.peers.updateAddressName(domain: .peer(peerId), name: updatedAddressNameValue.isEmpty ? nil : updatedAddressNameValue), for: context.window)
                                    }
                                    |> mapToSignal { _ in
                                        return .single(nil)
                                    }
                                    |> mapError {_ in
                                        return ConvertGroupToSupergroupError.generic
                                    }
                            }
                            
                            let others = combineLatest(signals)
                            |> castError(ConvertGroupToSupergroupError.self)
                            |> deliverOnMainQueue
                            
                            self?.updateAddressNameDisposable.set(combineLatest(signal, others).start(next: { updatedPeerId, _ in
                                self?.onComplete.set(.single(updatedPeerId))
                            }, error: { error in
                                switch error {
                                case .tooManyChannels:
                                    showInactiveChannels(context: context, source: .upgrade)
                                case .generic:
                                    alert(for: context.window, info: strings().unknownError)
                                }
                                updateState { current in
                                    var current = current
                                    current.updatingAddressName = false
                                    return current
                                }
                            }))
                        } else {
                            let others = combineLatest(signals) |> deliverOnMainQueue
                            self?.updateAddressNameDisposable.set(others.start(completed: { [weak self] in
                                self?.onComplete.set(.single(nil))
                            }))
                        }
                    }
                }, for: .SingleClick)
                
            }
        }))
        
        exportedLinkDisposable.set(context.account.viewTracker.peerView(peerId, updateData: true).start())

    }
    
    private func updateState (_ f:@escaping (State) -> State) -> Void {
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var doneButton:Control? {
        return rightBarView
    }
    
    override func getRightBarViewOnce() -> BarView {
        let button = TextButtonBarView(controller: self, text: strings().navigationDone)
        
        return button
    }
    
    deinit {
        checkAddressNameDisposable.dispose()
        updateAddressNameDisposable.dispose()
        revokeAddressNameDisposable.dispose()
        disposable.dispose()
        exportedLinkDisposable.dispose()
        toggleForwardDisposable.dispose()
    }
    
}


