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
import SyncCore
import SwiftSignalKit

private enum CurrentChannelType {
    case publicChannel
    case privateChannel
}

private final class ChannelVisibilityControllerArguments {
    let context: AccountContext
    
    let updateCurrentType: (CurrentChannelType) -> Void
    let updatePublicLinkText: (String?, String) -> Void
    let displayPrivateLinkMenu: (String) -> Void
    let revokePeerId: (PeerId) -> Void
    let revokeLink: ()->Void
    init(context: AccountContext, updateCurrentType: @escaping (CurrentChannelType) -> Void, updatePublicLinkText: @escaping (String?, String) -> Void, displayPrivateLinkMenu: @escaping (String) -> Void, revokePeerId: @escaping (PeerId) -> Void, revokeLink: @escaping()->Void) {
        self.context = context
        self.updateCurrentType = updateCurrentType
        self.updatePublicLinkText = updatePublicLinkText
        self.displayPrivateLinkMenu = displayPrivateLinkMenu
        self.revokePeerId = revokePeerId
        self.revokeLink = revokeLink
    }
}


fileprivate enum ChannelVisibilityEntryStableId: Hashable {
    case index(Int32)
    case peer(PeerId)
}

private enum ChannelVisibilityEntry: TableItemListNodeEntry {
    case typeHeader(sectionId:Int32, String, GeneralViewType)
    case typePublic(sectionId:Int32, Bool, GeneralViewType)
    case typePrivate(sectionId:Int32, Bool, GeneralViewType)
    case typeInfo(sectionId:Int32, String, GeneralViewType)
    
    case publicLinkAvailability(sectionId:Int32, Bool, GeneralViewType)
    case privateLink(sectionId:Int32, String?, GeneralViewType)
    case editablePublicLink(sectionId:Int32, String?, String, AddressNameValidationStatus?, GeneralViewType)
    case privateLinkInfo(sectionId:Int32, String, GeneralViewType)
    case publicLinkInfo(sectionId:Int32, String, GeneralViewType)
    case publicLinkStatus(sectionId:Int32, String, AddressNameValidationStatus, GeneralViewType)
    
    case revokePrivateLink(sectionId:Int32, GeneralViewType)

    case existingLinksInfo(sectionId:Int32, String, GeneralViewType)
    case existingLinkPeerItem(sectionId:Int32, Int32, Peer, ShortPeerDeleting?, Bool, GeneralViewType)
    
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
        case .privateLink:
            return .index(5)
        case .editablePublicLink:
            return .index(6)
        case .privateLinkInfo:
            return .index(7)
        case .publicLinkStatus:
            return .index(8)
        case .publicLinkInfo:
            return .index(9)
        case .existingLinksInfo:
            return .index(10)
        case .revokePrivateLink:
            return .index(11)
        case let .existingLinkPeerItem(_,_, peer, _, _, _):
            return .peer(peer.id)
        case let .section(sectionId: sectionId):
            return .index((sectionId + 1) * 1000 - sectionId)
        }
    }
    static func ==(lhs: ChannelVisibilityEntry, rhs: ChannelVisibilityEntry) -> Bool {
        switch lhs {
        case let .typeHeader(sectionId, title, viewType):
            if case .typeHeader(sectionId, title, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .typePublic(sectionId, selected, viewType):
            if case .typePublic(sectionId, selected, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .typePrivate(sectionId, selected, viewType):
            if case .typePrivate(sectionId, selected, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .typeInfo(sectionId, text, viewType):
            if case .typeInfo(sectionId, text, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .publicLinkAvailability(sectionId, value, viewType):
            if case .publicLinkAvailability(sectionId, value, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .privateLink(sectionId, link, viewType):
            if case .privateLink(sectionId, link, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .editablePublicLink(sectionId, currenttext, text, status, viewType):
            if case .editablePublicLink(sectionId, currenttext, text, status, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .privateLinkInfo(sectionId, text, viewType):
            if case .privateLinkInfo(sectionId, text, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .publicLinkInfo(sectionId, text, viewType):
            if case .publicLinkInfo(sectionId, text, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .publicLinkStatus(sectionId, addressName, status, viewType):
            if case .publicLinkStatus(sectionId, addressName, status, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .existingLinksInfo(sectionId, text, viewType):
            if case .existingLinksInfo(sectionId, text, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .existingLinkPeerItem(sectionId, index, lhsPeer, editing, enabled, viewType):
            if case .existingLinkPeerItem(sectionId, index, let rhsPeer, editing, enabled, viewType) = rhs {
                if !lhsPeer.isEqual(rhsPeer) {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .revokePrivateLink(sectionId, viewType):
            if case .revokePrivateLink(sectionId, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .section(sectionId):
            if case .section(sectionId) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    var index: Int32 {
        switch self {
        case let .typeHeader(sectionId: sectionId, _, _):
            return (sectionId * 1000) + 0
        case let .typePublic(sectionId: sectionId, _, _):
            return (sectionId * 1000) + 1
        case let .typePrivate(sectionId: sectionId, _, _):
            return (sectionId * 1000) + 2
        case let .typeInfo(sectionId: sectionId, _, _):
            return (sectionId * 1000) + 3
        case let .publicLinkAvailability(sectionId: sectionId, _, _):
            return (sectionId * 1000) + 4
        case let .privateLink(sectionId: sectionId, _, _):
            return (sectionId * 1000) + 5
        case let .editablePublicLink(sectionId: sectionId, _, _, _, _):
            return (sectionId * 1000) + 6
        case let .privateLinkInfo(sectionId: sectionId, _, _):
            return (sectionId * 1000) + 7
        case let .publicLinkStatus(sectionId: sectionId, _, _, _):
            return (sectionId * 1000) + 8
        case let .publicLinkInfo(sectionId: sectionId, _, _):
            return (sectionId * 1000) + 9
        case let .existingLinksInfo(sectionId: sectionId, _, _):
            return (sectionId * 1000) + 10
        case let .revokePrivateLink(sectionId: sectionId, _):
            return (sectionId * 1000) + 11
        case let .existingLinkPeerItem(sectionId, index, _, _, _, _):
            return (sectionId * 1000) + index + 20
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
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.channelPublic, type: .selectable(selected), viewType: viewType, action: {
                arguments.updateCurrentType(.publicChannel)
            })
        case let .typePrivate(_, selected, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.channelPrivate, type: .selectable(selected), viewType: viewType, action: {
                arguments.updateCurrentType(.privateChannel)
            })
        case let .typeInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .publicLinkAvailability(_, value, viewType):
            let color: NSColor
            let text: String
            if value {
                text = L10n.channelVisibilityChecking
                color = theme.colors.grayText
            } else {
                text = L10n.channelPublicNamesLimitError
                color = theme.colors.redUI
            }
            return GeneralTextRowItem(initialSize, stableId: stableId, text: .initialize(string: text, color: color, font: .normal(.text)), viewType: viewType)
            
        case let .privateLink(_, link, viewType):
            let color:NSColor
            if let _ = link {
                color =  theme.colors.link
            } else {
                color = theme.colors.grayText
            }
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: link ?? L10n.channelVisibilityLoading, nameStyle: ControlStyle(font: .normal(.text), foregroundColor: color), type: .none, viewType: viewType, action: {
                if let link = link {
                    arguments.context.sharedContext.bindings.showControllerToaster(ControllerToaster(text: L10n.shareLinkCopied), true)
                    copyToClipboard(link)
                }
            })
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
            }, limit: 33)
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
        case let .existingLinksInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .existingLinkPeerItem(_, _, peer, _, _, viewType):
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, status: "t.me/\(peer.addressName ?? "unknown")", inset: NSEdgeInsets(left: 30, right:30), interactionType:.deletable(onRemove: { peerId in
                arguments.revokePeerId(peerId)
            }, deletable: true), viewType: viewType)
        case let .revokePrivateLink(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.channelRevokeLink, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                arguments.revokeLink()
            })
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
    
    init() {
        self.selectedType = nil
        self.editingPublicLinkText = nil
        self.addressNameValidationStatus = nil
        self.updatingAddressName = false
        self.revokingPeerId = nil
    }
    
    init(selectedType: CurrentChannelType?, editingPublicLinkText: String?, addressNameValidationStatus: AddressNameValidationStatus?, updatingAddressName: Bool, revokingPeerId: PeerId?) {
        self.selectedType = selectedType
        self.editingPublicLinkText = editingPublicLinkText
        self.addressNameValidationStatus = addressNameValidationStatus
        self.updatingAddressName = updatingAddressName
        self.revokingPeerId = revokingPeerId
    }
    
    func withUpdatedSelectedType(_ selectedType: CurrentChannelType?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: self.updatingAddressName, revokingPeerId: self.revokingPeerId)
    }
    
    func withUpdatedEditingPublicLinkText(_ editingPublicLinkText: String?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: self.updatingAddressName, revokingPeerId: self.revokingPeerId)
    }
    
    func withUpdatedAddressNameValidationStatus(_ addressNameValidationStatus: AddressNameValidationStatus?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: addressNameValidationStatus, updatingAddressName: self.updatingAddressName, revokingPeerId: self.revokingPeerId)
    }
    
    func withUpdatedUpdatingAddressName(_ updatingAddressName: Bool) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: updatingAddressName, revokingPeerId: self.revokingPeerId)
    }
    
    func withUpdatedRevealedRevokePeerId(_ revealedRevokePeerId: PeerId?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: updatingAddressName, revokingPeerId: self.revokingPeerId)
    }
    
    func withUpdatedRevokingPeerId(_ revokingPeerId: PeerId?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: updatingAddressName, revokingPeerId: revokingPeerId)
    }
}

private func channelVisibilityControllerEntries(view: PeerView, publicChannelsToRevoke: [Peer]?, state: ChannelVisibilityControllerState, onlyUsername: Bool) -> [ChannelVisibilityEntry] {
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
        
        entries.append(.typeHeader(sectionId: sectionId, isGroup ? L10n.channelTypeHeaderGroup : L10n.channelTypeHeaderChannel, .textTopItem))
        entries.append(.typePublic(sectionId: sectionId, selectedType == .publicChannel, .firstItem))
        entries.append(.typePrivate(sectionId: sectionId, selectedType == .privateChannel, .lastItem))
        
        switch selectedType {
        case .publicChannel:
            entries.append(.typeInfo(sectionId: sectionId, isGroup ? L10n.channelPublicAboutGroup : L10n.channelPublicAboutChannel, .textBottomItem))
        case .privateChannel:
            entries.append(.typeInfo(sectionId: sectionId, isGroup ? L10n.channelPrivateAboutGroup : L10n.channelPrivateAboutChannel, .textBottomItem))
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
                    entries.append(.publicLinkAvailability(sectionId: sectionId, false, .textTopItem))
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
                        entries.append(.existingLinkPeerItem(sectionId: sectionId, index, peer, nil, state.revokingPeerId == nil, bestGeneralViewType(sorted, for: i)))
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
                entries.append(.publicLinkInfo(sectionId: sectionId, isGroup ? L10n.channelUsernameAboutGroup : L10n.channelUsernameAboutChannel, .textBottomItem))
            }
        case .privateChannel:
            entries.append(.privateLink(sectionId: sectionId, (view.cachedData as? CachedChannelData)?.exportedInvitation?.link, .singleItem))
            entries.append(.publicLinkInfo(sectionId: sectionId, isGroup ? L10n.channelExportLinkAboutGroup : L10n.channelExportLinkAboutChannel, .textBottomItem))
            
            
            if (view.cachedData as? CachedChannelData)?.exportedInvitation?.link != nil {
                entries.append(.section(sectionId: sectionId))
                sectionId += 1
                entries.append(.revokePrivateLink(sectionId: sectionId, .singleItem))
            }
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
        
        entries.append(.typeHeader(sectionId: sectionId, L10n.channelTypeHeaderGroup, .textTopItem))
        entries.append(.typePublic(sectionId: sectionId, selectedType == .publicChannel, .firstItem))
        entries.append(.typePrivate(sectionId: sectionId, selectedType == .privateChannel, .lastItem))
        
        switch selectedType {
        case .publicChannel:
            entries.append(.typeInfo(sectionId: sectionId, L10n.channelPublicAboutGroup, .textBottomItem))

        case .privateChannel:
            entries.append(.typeInfo(sectionId: sectionId, L10n.channelPrivateAboutGroup, .textBottomItem))
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
                    
                    
                    entries.append(.publicLinkAvailability(sectionId: sectionId, false, .singleItem))
                    var index: Int32 = 0
                    for peer in publicChannelsToRevoke.sorted(by: { lhs, rhs in
                        var lhsDate: Int32 = 0
                        var rhsDate: Int32 = 0
                        if let lhs = lhs as? TelegramGroup {
                            lhsDate = lhs.creationDate
                        }
                        if let rhs = rhs as? TelegramGroup {
                            rhsDate = rhs.creationDate
                        }
                        return lhsDate > rhsDate
                    }) {
                        entries.append(.existingLinkPeerItem(sectionId: sectionId, index, peer, nil, state.revokingPeerId == nil, .singleItem))
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
                entries.append(.publicLinkInfo(sectionId: sectionId, L10n.channelUsernameAboutGroup, .textBottomItem))
            }
        case .privateChannel:
            entries.append(.privateLink(sectionId: sectionId, (view.cachedData as? CachedGroupData)?.exportedInvitation?.link, .singleItem))
            entries.append(.publicLinkInfo(sectionId: sectionId, L10n.channelExportLinkAboutGroup, .textBottomItem))
            
            if (view.cachedData as? CachedGroupData)?.exportedInvitation?.link != nil {
                entries.append(.section(sectionId: sectionId))
                sectionId += 1
                entries.append(.revokePrivateLink(sectionId: sectionId, .singleItem))
            }
        }
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
  
    let checkAddressNameDisposable = MetaDisposable()
    let updateAddressNameDisposable = MetaDisposable()
    let revokeAddressNameDisposable = MetaDisposable()
    let disposable = MetaDisposable()
    let exportedLinkDisposable = MetaDisposable()
    let peerId:PeerId
    let onlyUsername:Bool
    
    init(_ context: AccountContext, peerId:PeerId, onlyUsername: Bool = false) {
        self.peerId = peerId
        self.onlyUsername = onlyUsername
        super.init(context)
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
    
    override var removeAfterDisapper: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.getBackgroundColor = {
            theme.colors.listBackground
        }
        
        let context = self.context
        let peerId = self.peerId
        let onlyUsername = self.onlyUsername
        
        let updateState: ((ChannelVisibilityControllerState) -> ChannelVisibilityControllerState) -> Void = { [weak self] f in
            if let strongSelf = self {
                strongSelf.statePromise.set(strongSelf.stateValue.modify { f($0) })
            }
        }
        
        
        peersDisablingAddressNameAssignment.set(.single(nil) |> then(channelAddressNameAssignmentAvailability(account: context.account, peerId: peerId.namespace == Namespaces.Peer.CloudChannel ? peerId : nil) |> mapToSignal { result -> Signal<[Peer]?, NoError> in
            if case .addressNameLimitReached = result {
                return adminedPublicChannels(account: context.account)
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
                
                self?.checkAddressNameDisposable.set((validateAddressNameInteractive(account: context.account, domain: .peer(peerId), name: text)
                    |> deliverOnMainQueue).start(next: { result in
                        updateState { state in
                            return state.withUpdatedAddressNameValidationStatus(result)
                        }
                }))
            }
        }, displayPrivateLinkMenu: { [weak self] text in
            self?.show(toaster: ControllerToaster(text: tr(L10n.shareLinkCopied)))
            copyToClipboard(text)
        }, revokePeerId: { [weak self] peerId in
            updateState { state in
                return state.withUpdatedRevokingPeerId(peerId)
            }
            
            self?.revokeAddressNameDisposable.set((confirmSignal(for: context.window, information: L10n.channelVisibilityConfirmRevoke) |> mapToSignalPromotingError { result -> Signal<Bool, UpdateAddressNameError> in
                if !result {
                    return .fail(.generic)
                } else {
                    return .single(true)
                }
            } |> mapToSignal { _ -> Signal<Void, UpdateAddressNameError> in
                return updateAddressName(account: context.account, domain: .peer(peerId), name: nil)
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
        }, revokeLink: {
            confirm(for: context.window, header: L10n.channelRevokeLinkConfirmHeader, information: L10n.channelRevokeLinkConfirmText, okTitle: L10n.channelRevokeLinkConfirmOK, cancelTitle: L10n.modalCancel, successHandler: { _ in
                 _ = showModalProgress(signal: ensuredExistingPeerExportedInvitation(account: context.account, peerId: peerId, revokeExisted: true), for: context.window).start()
            })
        })
        
        let peerView = context.account.viewTracker.peerView(peerId)
        
        let initialSize = atomicSize
        let previousEntries:Atomic<[AppearanceWrapperEntry<ChannelVisibilityEntry>]> = Atomic(value: [])

        
        let apply = combineLatest(queue: prepareQueue, statePromise.get(), peerView, peersDisablingAddressNameAssignment.get(), appearanceSignal)
            |> map { state, view, publicChannelsToRevoke, appearance -> (TableUpdateTransition, Peer?, Bool) in
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
                
                let entries = channelVisibilityControllerEntries(view: view, publicChannelsToRevoke: publicChannelsToRevoke, state: state, onlyUsername: onlyUsername).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                
                return (prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify({$0}), arguments: arguments), peer, doneEnabled)
            } |> deliverOnMainQueue
        
        disposable.set(apply.start(next: { [weak self] transition, peer, doneEnabled in
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
                        
                        if let updatedAddressNameValue = updatedAddressNameValue {
                           
                            
                            let signal: Signal<PeerId?, ConvertGroupToSupergroupError>
                            
                            let csignal: Signal<Void, UpdateAddressNameError>
                            
                            if updatedAddressNameValue.isEmpty && peer.addressName != updatedAddressNameValue, let address = peer.addressName {
                                let text: String
                                if peer.isChannel {
                                    text = L10n.channelVisibilityConfirmMakePrivateChannel(address)
                                } else {
                                    text = L10n.channelVisibilityConfirmMakePrivateGroup(address)
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
                                signal = convertGroupToSupergroup(account: context.account, peerId: peerId)
                                    |> mapToSignal { upgradedPeerId -> Signal<PeerId?, ConvertGroupToSupergroupError> in
                                        return csignal
                                            |> mapToSignal {
                                                showModalProgress(signal: updateAddressName(account: context.account, domain: .peer(upgradedPeerId), name: updatedAddressNameValue.isEmpty ? nil : updatedAddressNameValue), for: context.window)
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
                                        showModalProgress(signal: updateAddressName(account: context.account, domain: .peer(peerId), name: updatedAddressNameValue.isEmpty ? nil : updatedAddressNameValue), for: context.window)
                                    }
                                    |> mapToSignal { _ in
                                        return .single(nil)
                                    }
                                    |> mapError {_ in
                                        return ConvertGroupToSupergroupError.generic
                                    }
                            }
                            
                            self?.updateAddressNameDisposable.set(signal.start(next: { updatedPeerId in
                                self?.onComplete.set(.single(updatedPeerId))
                            }, error: { error in
                                switch error {
                                case .tooManyChannels:
                                    showInactiveChannels(context: context, source: .upgrade)
                                case .generic:
                                    alert(for: context.window, info: L10n.unknownError)
                                }
                                updateState { state in
                                    return state.withUpdatedUpdatingAddressName(false)
                                }
                            }))
                        } else {
                            self?.onComplete.set(.single(nil))
                        }
                    }
                   
                }, for: .SingleClick)
                
            }
        }))
        
        exportedLinkDisposable.set((context.account.viewTracker.peerView(peerId) |> filter { $0.cachedData != nil } |> take(1) |> mapToSignal { _ in
            return ensuredExistingPeerExportedInvitation(account: context.account, peerId: peerId)
        }).start())
        
    }
    
    private func updateState (_ f:@escaping (ChannelVisibilityControllerState) -> ChannelVisibilityControllerState) -> Void {
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var doneButton:Control? {
        return rightBarView
    }
    
    override func getRightBarViewOnce() -> BarView {
        let button = TextButtonBarView(controller: self, text: tr(L10n.navigationDone))
        
        return button
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
}


