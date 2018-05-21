//
//  ChannelVisibilityController.swift
//  Telegram
//
//  Created by keepcoder on 23/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

private enum CurrentChannelType {
    case publicChannel
    case privateChannel
}

private final class ChannelVisibilityControllerArguments {
    let account: Account
    
    let updateCurrentType: (CurrentChannelType) -> Void
    let updatePublicLinkText: (String?, String) -> Void
    let displayPrivateLinkMenu: (String) -> Void
    let revokePeerId: (PeerId) -> Void
    
    init(account: Account, updateCurrentType: @escaping (CurrentChannelType) -> Void, updatePublicLinkText: @escaping (String?, String) -> Void, displayPrivateLinkMenu: @escaping (String) -> Void, revokePeerId: @escaping (PeerId) -> Void) {
        self.account = account
        self.updateCurrentType = updateCurrentType
        self.updatePublicLinkText = updatePublicLinkText
        self.displayPrivateLinkMenu = displayPrivateLinkMenu
        self.revokePeerId = revokePeerId
    }
}


fileprivate enum ChannelVisibilityEntryStableId: Hashable {
    case index(Int32)
    case peer(PeerId)
    
    var hashValue: Int {
        switch self {
        case let .index(index):
            return index.hashValue
        case let .peer(peerId):
            return peerId.hashValue
        }
    }
    
    static func ==(lhs: ChannelVisibilityEntryStableId, rhs: ChannelVisibilityEntryStableId) -> Bool {
        switch lhs {
        case let .index(index):
            if case .index(index) = rhs {
                return true
            } else {
                return false
            }
        case let .peer(peerId):
            if case .peer(peerId) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

private enum ChannelVisibilityEntry: Identifiable, Comparable {
    case typeHeader(sectionId:Int32, String)
    case typePublic(sectionId:Int32, Bool)
    case typePrivate(sectionId:Int32, Bool)
    case typeInfo(sectionId:Int32, String)
    
    case publicLinkAvailability(sectionId:Int32, Bool)
    case privateLink(sectionId:Int32, String?)
    case editablePublicLink(sectionId:Int32, String?, String, AddressNameValidationStatus?)
    case privateLinkInfo(sectionId:Int32, String)
    case publicLinkInfo(sectionId:Int32, String)
    case publicLinkStatus(sectionId:Int32, String, AddressNameValidationStatus)
    
    case existingLinksInfo(sectionId:Int32, String)
    case existingLinkPeerItem(sectionId:Int32, Int32, Peer, ShortPeerDeleting?, Bool)
    
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
        case let .existingLinkPeerItem(_,_, peer, _, _):
            return .peer(peer.id)
        case let .section(sectionId: sectionId):
            return .index((sectionId + 1) * 1000 - sectionId)
        }
    }
    
    static func ==(lhs: ChannelVisibilityEntry, rhs: ChannelVisibilityEntry) -> Bool {
        switch lhs {
        case let .typeHeader(_, title):
            if case .typeHeader(_, title) = rhs {
                return true
            } else {
                return false
            }
        case let .typePublic(_, selected):
            if case .typePublic(_, selected) = rhs {
                return true
            } else {
                return false
            }
        case let .typePrivate(_, selected):
            if case .typePrivate(_, selected) = rhs {
                return true
            } else {
                return false
            }
        case let .typeInfo(_, text):
            if case .typeInfo(_, text) = rhs {
                return true
            } else {
                return false
            }
        case let .publicLinkAvailability(_, value):
            if case .publicLinkAvailability(_, value) = rhs {
                return true
            } else {
                return false
            }
        case let .privateLink(_, lhsLink):
            if case let .privateLink(_, rhsLink) = rhs, lhsLink == rhsLink {
                return true
            } else {
                return false
            }
        case let .editablePublicLink(_, lhsCurrentText, lhsText, lhsStatus):
            if case let .editablePublicLink(_, rhsCurrentText, rhsText, rhsStatus) = rhs, lhsCurrentText == rhsCurrentText, lhsText == rhsText, lhsStatus == rhsStatus {
                return true
            } else {
                return false
            }
        case let .privateLinkInfo(_, text):
            if case .privateLinkInfo(_, text) = rhs {
                return true
            } else {
                return false
            }
        case let .publicLinkInfo(_, text):
            if case .publicLinkInfo(_, text) = rhs {
                return true
            } else {
                return false
            }
        case let .publicLinkStatus(_, addressName, status):
            if case .publicLinkStatus(_, addressName, status) = rhs {
                return true
            } else {
                return false
            }
        case let .existingLinksInfo(_, text):
            if case .existingLinksInfo(_, text) = rhs {
                return true
            } else {
                return false
            }
        case let .existingLinkPeerItem(_, lhsIndex, lhsPeer, lhsEditing, lhsEnabled):
            if case let .existingLinkPeerItem(_, rhsIndex, rhsPeer, rhsEditing, rhsEnabled) = rhs {
                if lhsIndex != rhsIndex {
                    return false
                }
                if !lhsPeer.isEqual(rhsPeer) {
                    return false
                }
                if lhsEditing != rhsEditing {
                    return false
                }
                if lhsEnabled != rhsEnabled {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .section(sectionId: sectionId):
            if case .section(sectionId: sectionId) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    var index: Int32 {
        switch self {
        case let .typeHeader(sectionId: sectionId, _):
            return (sectionId * 1000) + 0
        case let .typePublic(sectionId: sectionId, _):
            return (sectionId * 1000) + 1
        case let .typePrivate(sectionId: sectionId, _):
            return (sectionId * 1000) + 2
        case let .typeInfo(sectionId: sectionId, _):
            return (sectionId * 1000) + 3
        case let .publicLinkAvailability(sectionId: sectionId, _):
            return (sectionId * 1000) + 4
        case let .privateLink(sectionId: sectionId, _):
            return (sectionId * 1000) + 5
        case let .editablePublicLink(sectionId: sectionId, _, _, _):
            return (sectionId * 1000) + 6
        case let .privateLinkInfo(sectionId: sectionId, _):
            return (sectionId * 1000) + 7
        case let .publicLinkStatus(sectionId: sectionId, _, _):
            return (sectionId * 1000) + 8
        case let .publicLinkInfo(sectionId: sectionId, _):
            return (sectionId * 1000) + 9
        case let .existingLinksInfo(sectionId: sectionId, _):
            return (sectionId * 1000) + 10
        case let .existingLinkPeerItem(sectionId, index, _, _, _):
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
        case let .typeHeader(_, title):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: title)
        case let .typePublic(_, selected):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.channelPublic, type: .selectable(selected), action: {
                arguments.updateCurrentType(.publicChannel)
            })
        case let .typePrivate(_, selected):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.channelPrivate, type: .selectable(selected), action: {
                arguments.updateCurrentType(.privateChannel)
            })
        case let .typeInfo(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case let .publicLinkAvailability(_, value):
            if value {
                return GeneralTextRowItem(initialSize, stableId: stableId, text: .initialize(string: L10n.channelVisibilityChecking, color: theme.colors.redUI, font:.normal(.text)))
            } else {
                return GeneralTextRowItem(initialSize, stableId: stableId, text: .initialize(string: L10n.channelPublicNamesLimitError, color: theme.colors.redUI, font:.normal(.text)))
            }
        case let .privateLink(_, link):
            let color:NSColor
            if let _ = link {
                color =  theme.colors.link
            } else {
                color = theme.colors.grayText
            }
            return GeneralTextRowItem(initialSize, stableId: stableId, text: .initialize(string:link ?? L10n.channelVisibilityLoading, color: color, font:.normal(.text)), drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:5, bottom:8), action: {
                if let link = link {
                    arguments.displayPrivateLinkMenu(link)
                }
            })
        case let .editablePublicLink(_, currentText, text, status):
            return UsernameInputRowItem(initialSize, stableId: stableId, placeholder: "t.me/", limit: 30, status: status, text: text, changeHandler: { updatedText in
                arguments.updatePublicLinkText(currentText, updatedText)
            }, holdText:true)
        case let .privateLinkInfo(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case let .publicLinkInfo(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case let .publicLinkStatus(_, addressName, status):
            
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
                    color = theme.colors.blueUI
                default:
                    color = theme.colors.redUI
                }
            default:
                break
            }
            
             return GeneralTextRowItem(initialSize, stableId: stableId, text: NSAttributedString.initialize(string: text, color: color, font: .normal(.text)), alignment: .left, inset:NSEdgeInsets(left: 30.0, right: 30.0, top:6, bottom:4))
        case let .existingLinksInfo(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case let .existingLinkPeerItem(_, _, peer, _, _):
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.account, status:"t.me/\(peer.addressName ?? "unknown")", inset:NSEdgeInsets(left: 30, right:30), interactionType:.deletable(onRemove:{ peerId in
                arguments.revokePeerId(peerId)
            }, deletable: true))
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
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
    
    static func ==(lhs: ChannelVisibilityControllerState, rhs: ChannelVisibilityControllerState) -> Bool {
        if lhs.selectedType != rhs.selectedType {
            return false
        }
        if lhs.editingPublicLinkText != rhs.editingPublicLinkText {
            return false
        }
        if lhs.addressNameValidationStatus != rhs.addressNameValidationStatus {
            return false
        }
        if lhs.updatingAddressName != rhs.updatingAddressName {
            return false
        }
        if lhs.revokingPeerId != rhs.revokingPeerId {
            return false
        }
        
        return true
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
        
        entries.append(.typeHeader(sectionId: sectionId, isGroup ? tr(L10n.channelTypeHeaderGroup) : tr(L10n.channelTypeHeaderChannel)))
        entries.append(.typePublic(sectionId: sectionId, selectedType == .publicChannel))
        entries.append(.typePrivate(sectionId: sectionId, selectedType == .privateChannel))
        
        switch selectedType {
        case .publicChannel:
            if isGroup {
                entries.append(.typeInfo(sectionId: sectionId, tr(L10n.channelPublicAboutGroup)))
            } else {
                entries.append(.typeInfo(sectionId: sectionId, tr(L10n.channelPublicAboutChannel)))
            }
        case .privateChannel:
            if isGroup {
                entries.append(.typeInfo(sectionId: sectionId, tr(L10n.channelPrivateAboutGroup)))
            } else {
                entries.append(.typeInfo(sectionId: sectionId, tr(L10n.channelPrivateAboutChannel)))
            }
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
                    
                    
                    entries.append(.publicLinkAvailability(sectionId: sectionId, false))
                    var index: Int32 = 0
                    for peer in publicChannelsToRevoke.sorted(by: { lhs, rhs in
                        var lhsDate: Int32 = 0
                        var rhsDate: Int32 = 0
                        if let lhs = lhs as? TelegramChannel {
                            lhsDate = lhs.creationDate
                        }
                        if let rhs = rhs as? TelegramChannel {
                            rhsDate = rhs.creationDate
                        }
                        return lhsDate > rhsDate
                    }) {
                        entries.append(.existingLinkPeerItem(sectionId: sectionId, index, peer, nil, state.revokingPeerId == nil))
                        index += 1
                    }
                } else {
                    entries.append(.publicLinkAvailability(sectionId: sectionId, true))
                }
            } else {
                entries.append(.editablePublicLink(sectionId: sectionId, peer.addressName, currentAddressName, state.addressNameValidationStatus))
                if let status = state.addressNameValidationStatus {
                    switch status {
                    case .invalidFormat, .availability:
                        entries.append(.publicLinkStatus(sectionId: sectionId, currentAddressName, status))
                    default:
                        break
                    }
                }
                entries.append(.publicLinkInfo(sectionId: sectionId, isGroup ? tr(L10n.channelUsernameAboutGroup) : tr(L10n.channelUsernameAboutChannel)))
            }
        case .privateChannel:
            entries.append(.privateLink(sectionId: sectionId, (view.cachedData as? CachedChannelData)?.exportedInvitation?.link))
            entries.append(.publicLinkInfo(sectionId: sectionId, isGroup ? tr(L10n.channelExportLinkAboutGroup) : tr(L10n.channelExportLinkAboutChannel)))
        }
    }
    
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

private func updatedAddressName(state: ChannelVisibilityControllerState, peer: TelegramChannel) -> String? {
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
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<ChannelVisibilityEntry>], right: [AppearanceWrapperEntry<ChannelVisibilityEntry>], initialSize:NSSize, arguments:ChannelVisibilityControllerArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}



class ChannelVisibilityController: EmptyComposeController<Void, Bool, TableView> {
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
    
    init(account:Account, peerId:PeerId, onlyUsername: Bool = false) {
        self.peerId = peerId
        self.onlyUsername = onlyUsername
        super.init(account)
    }
    
    override var enableBack: Bool {
        return true
    }
    override func backKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    
    override var removeAfterDisapper: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let account = self.account
        let peerId = self.peerId
        let onlyUsername = self.onlyUsername
        
        let updateState: ((ChannelVisibilityControllerState) -> ChannelVisibilityControllerState) -> Void = { [weak self] f in
            if let strongSelf = self {
                strongSelf.statePromise.set(strongSelf.stateValue.modify { f($0) })
            }
        }
        
        
        peersDisablingAddressNameAssignment.set(.single(nil) |> then(channelAddressNameAssignmentAvailability(account: account, peerId: peerId) |> mapToSignal { result -> Signal<[Peer]?, NoError> in
            
            if case .addressNameLimitReached = result {
                return adminedPublicChannels(account: account)
                    |> map { Optional($0) }
            } else {
                return .single([])
            }
        }))
        
        let arguments = ChannelVisibilityControllerArguments(account: account, updateCurrentType: { type in
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
                
                self?.checkAddressNameDisposable.set((validateAddressNameInteractive(account: account, domain: .peer(peerId), name: text)
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
            
            self?.revokeAddressNameDisposable.set((confirmSignal(for: mainWindow, information: L10n.channelVisibilityConfirmRevoke) |> mapToSignalPromotingError { result -> Signal<Bool, UpdateAddressNameError> in
                if !result {
                    return .fail(.generic)
                } else {
                    return .single(true)
                }
            } |> mapToSignal { _ -> Signal<Void, UpdateAddressNameError> in
                return updateAddressName(account: account, domain: .peer(peerId), name: nil)
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
        })
        
        let peerView = account.viewTracker.peerView(peerId)
        
        let initialSize = atomicSize
        let previousEntries:Atomic<[AppearanceWrapperEntry<ChannelVisibilityEntry>]> = Atomic(value: [])

        
        let apply = combineLatest(statePromise.get(), peerView, peersDisablingAddressNameAssignment.get(), appearanceSignal)
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
                    
                    var updatedAddressNameValue: String?
                    self?.updateState { state in
                        if let peer = peer as? TelegramChannel {
                            updatedAddressNameValue = updatedAddressName(state: state, peer: peer)
                            
                            if updatedAddressNameValue != nil {
                                return state.withUpdatedUpdatingAddressName(true)
                            } else {
                                return state
                            }
                        } else {
                            return state
                        }
                    }
                    
                    if let updatedAddressNameValue = updatedAddressNameValue {
                        self?.updateAddressNameDisposable.set((updateAddressName(account: account, domain: .peer(peerId), name: updatedAddressNameValue.isEmpty ? nil : updatedAddressNameValue)
                            |> deliverOnMainQueue).start(error: { [weak self] _ in
                                self?.updateState { state in
                                    return state.withUpdatedUpdatingAddressName(false)
                                }
                            }, completed: { [weak self] in
                                self?.updateState { state in
                                    return state.withUpdatedUpdatingAddressName(false)
                                }
                                self?.onComplete.set(.single(true))
                            }))
                    } else {
                        self?.onComplete.set(.single(true))
                    }
                }, for: .SingleClick)
                
            }
        }))
        
        exportedLinkDisposable.set((account.viewTracker.peerView(peerId) |> filter { $0.cachedData != nil } |> take(1) |> mapToSignal { _ in return ensuredExistingPeerExportedInvitation(account: account, peerId: peerId)}).start())
        
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


