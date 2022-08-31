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


private final class ChannelVisibilityControllerArguments {
    let context: AccountContext
    
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
    init(context: AccountContext, updateCurrentType: @escaping (CurrentChannelType) -> Void, updatePublicLinkText: @escaping (String?, String) -> Void, displayPrivateLinkMenu: @escaping (String) -> Void, revokePeerId: @escaping (PeerId) -> Void, copy: @escaping(String)->Void, revokeLink: @escaping()->Void, share: @escaping(String)->Void, manageLinks:@escaping()->Void, open:@escaping(_ExportedInvitation)->Void, toggleForwarding:@escaping(Bool)->Void, toggleWrite:@escaping(CurrentChannelJoinToSend)->Void, toggleApproveNewMembers: @escaping(Bool)->Void, premiumCallback:@escaping()->Void) {
        self.context = context
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
    }
}


fileprivate enum ChannelVisibilityEntryStableId: Hashable {
    case index(Int32)
    case peer(PeerId)
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
        case let .existingLinkPeerItem(sectionId, index, _, _, _, _):
            return (sectionId * 1000) + index + 30
        case let .section(sectionId: sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func <(lhs: ChannelVisibilityEntry, rhs: ChannelVisibilityEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: ChannelVisibilityControllerArguments, initialSize:NSSize) -> TableRowItem {
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
            
            return ExportedInvitationRowItem(initialSize, stableId: stableId, context: arguments.context, exportedLink: link, lastPeers: peers, viewType: viewType, mode: isNew ? .short : .normal, menuItems: {
                
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
                text = availability.description(for: addressName)
                switch availability {
                case .available:
                    color = theme.colors.accent
                default:
                    color = theme.colors.redUI
                }
            default:
                break
            }
            
            return GeneralTextRowItem(initialSize, stableId: stableId, text: NSAttributedString.initialize(string: text, color: color, font: .normal(.text)), viewType: viewType)
        case let .increaseLimit(_, counts, viewType):
            return PremiumIncreaseLimitItem(initialSize, stableId: stableId, context: arguments.context, type: .publicLink, counts: counts, viewType: viewType, callback: arguments.premiumCallback)
        case let .existingLinksInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .existingLinkPeerItem(_, _, peer, _, _, viewType):
            return ShortPeerRowItem(initialSize, peer: peer.peer, account: arguments.context.account, context: arguments.context, status: "t.me/\(peer.peer.addressName ?? "unknown")", inset: NSEdgeInsets(left: 30, right:30), interactionType:.deletable(onRemove: { peerId in
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
        case .section:
            return GeneralRowItem(initialSize, height: 30, stableId: stableId, viewType: .separator)
        }
 
    }
}


private struct ChannelVisibilityControllerState: Equatable {
    let selectedType: CurrentChannelType?
    let editingPublicLinkText: String?
    let addressNameValidationStatus: AddressNameValidationStatus?
    let updatingAddressName: Bool
    let revokingPeerId: PeerId?
    let forwardingEnabled: Bool?
    let joinToSend: CurrentChannelJoinToSend?
    let approveMembers: Bool?
    
    init() {
        self.selectedType = nil
        self.editingPublicLinkText = nil
        self.addressNameValidationStatus = nil
        self.updatingAddressName = false
        self.revokingPeerId = nil
        self.forwardingEnabled = nil
        self.joinToSend = nil
        self.approveMembers = nil
    }
    
    init(selectedType: CurrentChannelType?, editingPublicLinkText: String?, addressNameValidationStatus: AddressNameValidationStatus?, updatingAddressName: Bool, revokingPeerId: PeerId?, forwardingEnabled: Bool?, joinToSend: CurrentChannelJoinToSend?, approveMembers: Bool?) {
        self.selectedType = selectedType
        self.editingPublicLinkText = editingPublicLinkText
        self.addressNameValidationStatus = addressNameValidationStatus
        self.updatingAddressName = updatingAddressName
        self.revokingPeerId = revokingPeerId
        self.forwardingEnabled = forwardingEnabled
        self.joinToSend = joinToSend
        self.approveMembers = approveMembers

    }
    
    func withUpdatedSelectedType(_ selectedType: CurrentChannelType?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: self.updatingAddressName, revokingPeerId: self.revokingPeerId, forwardingEnabled: self.forwardingEnabled, joinToSend: self.joinToSend, approveMembers: self.approveMembers)
    }
    
    func withUpdatedEditingPublicLinkText(_ editingPublicLinkText: String?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: self.updatingAddressName, revokingPeerId: self.revokingPeerId, forwardingEnabled: self.forwardingEnabled, joinToSend: self.joinToSend, approveMembers: self.approveMembers)
    }
    
    func withUpdatedAddressNameValidationStatus(_ addressNameValidationStatus: AddressNameValidationStatus?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: addressNameValidationStatus, updatingAddressName: self.updatingAddressName, revokingPeerId: self.revokingPeerId, forwardingEnabled: self.forwardingEnabled, joinToSend: self.joinToSend, approveMembers: self.approveMembers)
    }
    
    func withUpdatedUpdatingAddressName(_ updatingAddressName: Bool) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: updatingAddressName, revokingPeerId: self.revokingPeerId, forwardingEnabled: self.forwardingEnabled, joinToSend: self.joinToSend, approveMembers: self.approveMembers)
    }
    
    func withUpdatedRevealedRevokePeerId(_ revealedRevokePeerId: PeerId?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: updatingAddressName, revokingPeerId: self.revokingPeerId, forwardingEnabled: self.forwardingEnabled, joinToSend: self.joinToSend, approveMembers: self.approveMembers)
    }
    
    func withUpdatedRevokingPeerId(_ revokingPeerId: PeerId?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: updatingAddressName, revokingPeerId: revokingPeerId, forwardingEnabled: self.forwardingEnabled, joinToSend: self.joinToSend, approveMembers: self.approveMembers)
    }
    func withUpdatedForwardingEnabled(_ forwardingEnabled: Bool) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: self.updatingAddressName, revokingPeerId: self.revokingPeerId, forwardingEnabled: forwardingEnabled, joinToSend: self.joinToSend, approveMembers: self.approveMembers)
    }
    func withUpdatedJoinToSend(_ joinToSend: CurrentChannelJoinToSend) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: self.updatingAddressName, revokingPeerId: self.revokingPeerId, forwardingEnabled: self.forwardingEnabled, joinToSend: joinToSend, approveMembers: self.approveMembers)
    }
    func withUpdatedApproveMembers(_ approveMembers: Bool) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: self.updatingAddressName, revokingPeerId: self.revokingPeerId, forwardingEnabled: self.forwardingEnabled, joinToSend: self.joinToSend, approveMembers: approveMembers)
    }
}

private func channelVisibilityControllerEntries(view: PeerView, arguments: ChannelVisibilityControllerArguments, publicChannelsToRevoke: [Peer]?, state: ChannelVisibilityControllerState, counts: PremiumLimitController.Counts?, onlyUsername: Bool, importers: PeerInvitationImportersState?, isNew: Bool) -> [ChannelVisibilityEntry] {
    var entries: [ChannelVisibilityEntry] = []
    
    var sectionId:Int32 = 0
    
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    if let peer = view.peers[view.peerId] as? TelegramChannel {
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
                displayAvailability = publicChannelsToRevoke == nil || !(publicChannelsToRevoke!.isEmpty)
            }
            if displayAvailability {
                if let publicChannelsToRevoke = publicChannelsToRevoke {
                    
                    if !arguments.context.isPremium && !arguments.context.premiumIsBlocked {
                        entries.append(.increaseLimit(sectionId: sectionId, counts: counts, .singleItem))
                    } else {
                        entries.append(.publicLinkAvailability(sectionId: sectionId, false, .textTopItem))
                    }
                    
                    var index: Int32 = 0
                    
                    let sorted = publicChannelsToRevoke.sorted(by: { lhs, rhs in
                        var lhsDate: Int32 = 0
                        var rhsDate: Int32 = 0
                        if let lhs = lhs as? TelegramChannel {
                            lhsDate = lhs.creationDate
                        }
                        if let rhs = rhs as? TelegramChannel {
                            rhsDate = rhs.creationDate
                        }
                        return lhsDate > rhsDate
                    })
                    
                    for (i, peer) in sorted.enumerated() {
                        entries.append(.existingLinkPeerItem(sectionId: sectionId, index, FoundPeer(peer: peer, subscribers: nil), nil, state.revokingPeerId == nil, bestGeneralViewType(sorted, for: i)))
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


            if peer.addressName != nil {
                entries.append(.section(sectionId: sectionId))
                sectionId += 1
                entries.append(.manageLinks(sectionId: sectionId, .singleItem))
            }

        case .privateChannel:
            entries.append(.privateLinkHeader(sectionId: sectionId, strings().channelVisibiltiyPermanentLink, .textTopItem))
            entries.append(.privateLink(sectionId: sectionId, (view.cachedData as? CachedChannelData)?.exportedInvitation?._invitation, importers, isNew, .singleItem))
            entries.append(.publicLinkInfo(sectionId: sectionId, isGroup ? strings().channelExportLinkAboutGroup : strings().channelExportLinkAboutChannel, .textBottomItem))

            entries.append(.section(sectionId: sectionId))
            sectionId += 1
            entries.append(.manageLinks(sectionId: sectionId, .singleItem))
            entries.append(.manageLinksDesc(sectionId: sectionId, .textBottomItem))

        }
                
    } else if let peer = view.peers[view.peerId] as? TelegramGroup {

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
                displayAvailability = publicChannelsToRevoke == nil || !(publicChannelsToRevoke!.isEmpty)
            }
            
            if displayAvailability {
                if let publicChannelsToRevoke = publicChannelsToRevoke {
                    
                    if !arguments.context.isPremium && !arguments.context.premiumIsBlocked {
                        entries.append(.increaseLimit(sectionId: sectionId, counts: counts, .singleItem))
                    } else {
                        entries.append(.publicLinkAvailability(sectionId: sectionId, false, .singleItem))
                    }
                    
                    var index: Int32 = 0
                    let sorted = publicChannelsToRevoke.sorted(by: { lhs, rhs in
                        var lhsDate: Int32 = 0
                        var rhsDate: Int32 = 0
                        if let lhs = lhs as? TelegramGroup {
                            lhsDate = lhs.creationDate
                        }
                        if let rhs = rhs as? TelegramGroup {
                            rhsDate = rhs.creationDate
                        }
                        return lhsDate > rhsDate
                    })
                    for (i, peer) in sorted.enumerated() {
                        entries.append(.existingLinkPeerItem(sectionId: sectionId, index, FoundPeer(peer: peer, subscribers: nil), nil, state.revokingPeerId == nil, bestGeneralViewType(sorted, for: i)))
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
            entries.append(.privateLink(sectionId: sectionId, (view.cachedData as? CachedGroupData)?.exportedInvitation?._invitation, importers, isNew, .singleItem))
            entries.append(.publicLinkInfo(sectionId: sectionId, strings().channelExportLinkAboutGroup, .textBottomItem))
            
            entries.append(.section(sectionId: sectionId))
            sectionId += 1
            entries.append(.manageLinks(sectionId: sectionId, .singleItem))
           
        }
    }
    
    if let peer = view.peers[view.peerId]  {
        entries.append(.section(sectionId: sectionId))
        sectionId += 1
        
        if let channel = peer as? TelegramChannel, channel.isSupergroup {
            
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
            entries.append(.writeHeader(sectionId: sectionId, strings().channelVisibilityMessagesWho, .textTopItem))
            entries.append(.writeEveryone(sectionId: sectionId, mode == .everyone, .firstItem))
            entries.append(.writeOnlyMembers(sectionId: sectionId, mode == .members, .lastItem))
            
            
            if mode == .members {
                entries.append(.section(sectionId: sectionId))
                sectionId += 1
                
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
private func effectiveChannelType(state: ChannelVisibilityControllerState, peer: TelegramChannel) -> CurrentChannelType {
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

private func updatedAddressName(state: ChannelVisibilityControllerState, peer: Peer) -> String? {
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



fileprivate func prepareTransition(left:[AppearanceWrapperEntry<ChannelVisibilityEntry>], right: [AppearanceWrapperEntry<ChannelVisibilityEntry>], initialSize:NSSize, arguments:ChannelVisibilityControllerArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}



class ChannelVisibilityController: EmptyComposeController<Void, PeerId?, TableView> {
    fileprivate let statePromise = ValuePromise(ChannelVisibilityControllerState(), ignoreRepeated: true)
    fileprivate let stateValue = Atomic(value: ChannelVisibilityControllerState())
    
    let peersDisablingAddressNameAssignment = Promise<[Peer]?>()
  
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
        let onlyUsername = self.onlyUsername
        
        let updateState: ((ChannelVisibilityControllerState) -> ChannelVisibilityControllerState) -> Void = { [weak self] f in
            if let strongSelf = self {
                strongSelf.statePromise.set(strongSelf.stateValue.modify { f($0) })
            }
        }
        
        
        peersDisablingAddressNameAssignment.set(.single(nil) |> then(context.engine.peers.channelAddressNameAssignmentAvailability(peerId: peerId.namespace == Namespaces.Peer.CloudChannel ? peerId : nil) |> mapToSignal { result -> Signal<[Peer]?, NoError> in
            if case .addressNameLimitReached = result {
                return context.engine.peers.adminedPublicChannels()
                    |> map { Optional($0) }
            } else {
                return .single([])
            }
        }))
        
        let arguments = ChannelVisibilityControllerArguments(context: context, updateCurrentType: { type in
            updateState { state in
                return state.withUpdatedSelectedType(type)
            }
        }, updatePublicLinkText: { [weak self] currentText, text in
            if text.isEmpty {
                self?.checkAddressNameDisposable.set(nil)
                updateState { state in
                    return state.withUpdatedEditingPublicLinkText(text).withUpdatedAddressNameValidationStatus(nil)
                }
            } else if currentText == text {
                self?.checkAddressNameDisposable.set(nil)
                updateState { state in
                    return state.withUpdatedEditingPublicLinkText(text).withUpdatedAddressNameValidationStatus(nil).withUpdatedAddressNameValidationStatus(nil)
                }
            } else {
                updateState { state in
                    return state.withUpdatedEditingPublicLinkText(text)
                }
                
                self?.checkAddressNameDisposable.set((context.engine.peers.validateAddressNameInteractive(domain: .peer(peerId), name: text)
                    |> deliverOnMainQueue).start(next: { result in
                        updateState { state in
                            return state.withUpdatedAddressNameValidationStatus(result)
                        }
                }))
            }
        }, displayPrivateLinkMenu: { [weak self] text in
            self?.show(toaster: ControllerToaster(text: strings().shareLinkCopied))
            copyToClipboard(text)
        }, revokePeerId: { [weak self] peerId in
            updateState { state in
                return state.withUpdatedRevokingPeerId(peerId)
            }
            
            self?.revokeAddressNameDisposable.set((confirmSignal(for: context.window, information: strings().channelVisibilityConfirmRevoke) |> mapToSignalPromotingError { result -> Signal<Bool, UpdateAddressNameError> in
                if !result {
                    return .fail(.generic)
                } else {
                    return .single(true)
                }
            } |> mapToSignal { _ -> Signal<Void, UpdateAddressNameError> in
                return context.engine.peers.updateAddressName(domain: .peer(peerId), name: nil)
            } |> deliverOnMainQueue).start(error: { _ in
                updateState { state in
                    return state.withUpdatedRevokingPeerId(nil)
                }
            }, completed: {
                updateState { state in
                    return state.withUpdatedRevokingPeerId(nil)
                }
                self?.peersDisablingAddressNameAssignment.set(.single([]))
            }))
        }, copy: { [weak self] link in
            self?.show(toaster: ControllerToaster(text: strings().shareLinkCopied))
            copyToClipboard(link)
        }, revokeLink: {
            confirm(for: context.window, header: strings().channelRevokeLinkConfirmHeader, information: strings().channelRevokeLinkConfirmText, okTitle: strings().channelRevokeLinkConfirmOK, cancelTitle: strings().modalCancel, successHandler: { _ in
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
                return current.withUpdatedForwardingEnabled(value)
            }
        }, toggleWrite: { value in
            updateState { current in
                return current.withUpdatedJoinToSend(value)
            }
        }, toggleApproveNewMembers: { value in
            updateState { current in
                return current.withUpdatedApproveMembers(value)
            }
        }, premiumCallback: {
            
        })
        
        
        let peerView = context.account.viewTracker.peerView(peerId)
        
        let initialSize = atomicSize
        let previousEntries:Atomic<[AppearanceWrapperEntry<ChannelVisibilityEntry>]> = Atomic(value: [])

        
        let permanentLink = peerView |> map {
            ($0.cachedData as? CachedChannelData)?.exportedInvitation?._invitation ?? ($0.cachedData as? CachedGroupData)?.exportedInvitation?._invitation
        }
        
        let manager = self.linksManager
        let isNew = self.isNew
        
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
        
        let counts: Signal<PremiumLimitController.Counts, NoError> = peersDisablingAddressNameAssignment.get()
        |> map { publicLinks in
            return PremiumLimitController.Counts(pinnedCount: nil, foldersCount: nil, savedGifsCount: nil, savedStickersCount: nil, publicLinksCount: publicLinks?.count)
        }
        |> deliverOnMainQueue
        
        let apply = combineLatest(queue: .mainQueue(), statePromise.get(), peerView, peersDisablingAddressNameAssignment.get(), importers, counts, appearanceSignal)
            |> map { state, view, publicChannelsToRevoke, importers, counts, appearance -> (TableUpdateTransition, Peer?, Bool, ChannelVisibilityControllerState) in
                let peer = peerViewMainPeer(view)
                
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
                        } else if let _ = publicChannelsToRevoke {
                            doneEnabled = false
                        }
                        
                    }
                }
                
                let entries = channelVisibilityControllerEntries(view: view, arguments: arguments, publicChannelsToRevoke: publicChannelsToRevoke, state: state, counts: counts, onlyUsername: onlyUsername, importers: importers, isNew: isNew).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                
                return (prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify({$0}), arguments: arguments), peer, doneEnabled, state)
            } |> deliverOnMainQueue
        
        disposable.set(apply.start(next: { [weak self] transition, peer, doneEnabled, state in
            if let strongSelf = self {
                strongSelf.genericView.merge(with: transition)
                strongSelf.readyOnce()
                
                strongSelf.doneButton?.isEnabled = doneEnabled
                strongSelf.doneButton?.removeAllHandlers()
                strongSelf.doneButton?.set(handler: { [weak self] _ in
                    if let peer = peer {
                        var updatedAddressNameValue: String?
                        self?.updateState { state in
                            updatedAddressNameValue = updatedAddressName(state: state, peer: peer)
                            
                            if updatedAddressNameValue != nil {
                                return state.withUpdatedUpdatingAddressName(true)
                            } else {
                                return state
                            }
                        }
                        
                        var signals: [Signal<Never, NoError>] = []
                        
                        if let updatedCopyProtection = state.forwardingEnabled {
                            signals.append(context.engine.peers.toggleMessageCopyProtection(peerId: peerId, enabled: updatedCopyProtection) |> ignoreValues)
                        }
                        
                        if let updatedJoinToSend = state.joinToSend {
                            signals.append(context.engine.peers.toggleChannelJoinToSend(peerId: peerId, enabled: updatedJoinToSend == .members) |> `catch` { _ in .complete() })
                        }
                        
                        if let updatedApproveMembers = state.approveMembers {
                            signals.append(context.engine.peers.toggleChannelJoinRequest(peerId: peerId, enabled: updatedApproveMembers) |> `catch` { _ in .complete() })
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
                                csignal = confirmSignal(for: context.window, information: text) |> filter { $0 } |> take(1) |> map { _ in
                                    updateState { state in
                                        return state.withUpdatedUpdatingAddressName(true)
                                    }
                                } |> castError(UpdateAddressNameError.self)
                            } else {
                                csignal = .single(Void()) |> map {
                                    updateState { state in
                                        return state.withUpdatedUpdatingAddressName(true)
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
                                updateState { state in
                                    return state.withUpdatedUpdatingAddressName(false)
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
    
    private func updateState (_ f:@escaping (ChannelVisibilityControllerState) -> ChannelVisibilityControllerState) -> Void {
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


