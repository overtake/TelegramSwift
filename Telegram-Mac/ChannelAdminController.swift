//
//  ChannelAdminController.swift
//  Telegram
//
//  Created by keepcoder on 06/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

private final class ChannelAdminControllerArguments {
    let account: Account
    let toggleRight: (TelegramChannelAdminRightsFlags, TelegramChannelAdminRightsFlags) -> Void
    let dismissAdmin: () -> Void
    
    init(account: Account, toggleRight: @escaping (TelegramChannelAdminRightsFlags, TelegramChannelAdminRightsFlags) -> Void, dismissAdmin: @escaping () -> Void) {
        self.account = account
        self.toggleRight = toggleRight
        self.dismissAdmin = dismissAdmin
    }
}

private enum ChannelAdminEntryStableId: Hashable {
    case info
    case right(TelegramChannelAdminRightsFlags)
    case description(Int32)
    case section(Int32)
    var hashValue: Int {
        switch self {
        case .info:
            return 0
        case .description(let index):
            return Int(index)
        case .section(let section):
            return Int(section)
        case let .right(flags):
            return flags.rawValue.hashValue
        }
    }
    
    static func ==(lhs: ChannelAdminEntryStableId, rhs: ChannelAdminEntryStableId) -> Bool {
        switch lhs {
        case .info:
            if case .info = rhs {
                return true
            } else {
                return false
            }
        case let .right(flags):
            if case .right(flags) = rhs {
                return true
            } else {
                return false
            }
        case let .section(section):
            if case .section(section) = rhs {
                return true
            } else {
                return false
            }
        case .description(let text):
            if case .description(text) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

private enum ChannelAdminEntry: TableItemListNodeEntry {
    case info(Int32, Peer, TelegramUserPresence?)
    case rightItem(Int32, Int, String, TelegramChannelAdminRightsFlags, TelegramChannelAdminRightsFlags, Bool, Bool)
    case description(Int32, Int32, String)
    case section(Int32)
    
    
    var stableId: ChannelAdminEntryStableId {
        switch self {
        case .info:
            return .info
        case let .rightItem(_, _, _, right, _, _, _):
            return .right(right)
        case .description(_, let index, _):
            return .description(index)
        case .section(let sectionId):
            return .section(sectionId)
        }
    }
    
    static func ==(lhs: ChannelAdminEntry, rhs: ChannelAdminEntry) -> Bool {
        switch lhs {
        case let .info(lhsSectionId, lhsPeer, lhsPresence):
            if case let .info(rhsSectionId, rhsPeer, rhsPresence) = rhs {
                if lhsSectionId != rhsSectionId {
                    return false
                }
                if !arePeersEqual(lhsPeer, rhsPeer) {
                    return false
                }
                if lhsPresence != rhsPresence {
                    return false
                }
                
                return true
            } else {
                return false
            }
        case let .rightItem(lhsSectionId, lhsIndex, lhsText, lhsRight, lhsFlags, lhsValue, lhsEnabled):
            if case let .rightItem(rhsSectionId, rhsIndex, rhsText, rhsRight, rhsFlags, rhsValue, rhsEnabled) = rhs {
                if lhsSectionId != rhsSectionId {
                    return false
                }
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsText != rhsText {
                    return false
                }
                if lhsRight != rhsRight {
                    return false
                }
                if lhsFlags != rhsFlags {
                    return false
                }
                if lhsValue != rhsValue {
                    return false
                }
                if lhsEnabled != rhsEnabled {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .description(sectionId, index, text):
            if case .description(sectionId, index, text) = rhs{
                return true
            } else {
                return false
            }
        case let .section(sectionId):
            if case .section(sectionId) = rhs{
                return true
            } else {
                return false
            }
        }
    }

    var index:Int32 {
        switch self {
        case .info(let sectionId, _, _):
            return (sectionId * 1000) + 0
        case .description(let sectionId, let index, _):
            return (sectionId * 1000) + index
        case .rightItem(let sectionId, let index, _, _, _, _, _):
            return (sectionId * 1000) + Int32(index) + 10
        case .section(let sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func <(lhs: ChannelAdminEntry, rhs: ChannelAdminEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: ChannelAdminControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case .info(_, let peer, let presence):
            var string:String = peer.isBot ? tr(L10n.presenceBot) : tr(L10n.peerStatusRecently)
            var color:NSColor = theme.colors.grayText
            if let presence = presence {
                let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                (string, _, color) = stringAndActivityForUserPresence(presence, relativeTo: Int32(timestamp))
            }
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.account, stableId: stableId, enabled: true, height: 60, photoSize: NSMakeSize(50, 50), statusStyle: ControlStyle(font: .normal(.title), foregroundColor: color), status: string, borderType: [], drawCustomSeparator: false, drawLastSeparator: false, inset: NSEdgeInsets(left: 25, right: 25), drawSeparatorIgnoringInset: false, action: {})
        case let .rightItem(_, _, name, right, flags, value, enabled):
            //ControlStyle(font: NSFont.)
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: name, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: enabled ? theme.colors.text : theme.colors.grayText), type: .switchable(value), action: { 
                arguments.toggleRight(right, flags)
            }, enabled: enabled, switchAppearance: SwitchViewAppearance(backgroundColor: theme.colors.background, stateOnColor: enabled ? theme.colors.blueUI : theme.colors.blueUI.withAlphaComponent(0.6), stateOffColor: enabled ? theme.colors.redUI : theme.colors.redUI.withAlphaComponent(0.6), disabledColor: .grayBackground, borderColor: .clear))
        case .description(_, _, let name):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: name)//GeneralInteractedRowItem(initialSize, stableId: stableId, name: name)
        }
        //return TableRowItem(initialSize)
    }
}

private struct ChannelAdminControllerState: Equatable {
    let updatedFlags: TelegramChannelAdminRightsFlags?
    let updating: Bool
    let editable:Bool
    init(updatedFlags: TelegramChannelAdminRightsFlags? = nil, updating: Bool = false, editable: Bool = false) {
        self.updatedFlags = updatedFlags
        self.updating = updating
        self.editable = editable
    }
    
    static func ==(lhs: ChannelAdminControllerState, rhs: ChannelAdminControllerState) -> Bool {
        if lhs.updatedFlags != rhs.updatedFlags {
            return false
        }
        if lhs.updating != rhs.updating {
            return false
        }
        if lhs.editable != rhs.editable {
            return false
        }
        return true
    }
    
    func withUpdatedUpdatedFlags(_ updatedFlags: TelegramChannelAdminRightsFlags?) -> ChannelAdminControllerState {
        return ChannelAdminControllerState(updatedFlags: updatedFlags, updating: self.updating, editable: self.editable)
    }
    
    func withUpdatedEditable(_ editable:Bool) -> ChannelAdminControllerState {
        return ChannelAdminControllerState(updatedFlags: updatedFlags, updating: self.updating, editable: editable)
    }
    
    func withUpdatedUpdating(_ updating: Bool) -> ChannelAdminControllerState {
        return ChannelAdminControllerState(updatedFlags: self.updatedFlags, updating: updating, editable: self.editable)
    }
}

private func stringForRight(right: TelegramChannelAdminRightsFlags, isGroup: Bool) -> String {
    if right.contains(.canChangeInfo) {
        return isGroup ? tr(L10n.groupEditAdminPermissionChangeInfo) : tr(L10n.channelEditAdminPermissionChangeInfo)
    } else if right.contains(.canPostMessages) {
        return tr(L10n.channelEditAdminPermissionPostMessages)
    } else if right.contains(.canEditMessages) {
        return tr(L10n.channelEditAdminPermissionEditMessages)
    } else if right.contains(.canDeleteMessages) {
        return tr(L10n.channelEditAdminPermissionDeleteMessages)
    } else if right.contains(.canBanUsers) {
        return tr(L10n.channelEditAdminPermissionBanUsers)
    } else if right.contains(.canInviteUsers) {
        return tr(L10n.channelEditAdminPermissionInviteUsers)
    } else if right.contains(.canChangeInviteLink) {
        return "tr(L10n.channelEditAdminPermissionInviteViaLink)"
    } else if right.contains(.canPinMessages) {
        return tr(L10n.channelEditAdminPermissionPinMessages)
    } else if right.contains(.canAddAdmins) {
        return tr(L10n.channelEditAdminPermissionAddNewAdmins)
    } else {
        return ""
    }
}

private func rightDependencies(_ right: TelegramChannelAdminRightsFlags) -> [TelegramChannelAdminRightsFlags] {
    if right.contains(.canChangeInfo) {
        return []
    } else if right.contains(.canPostMessages) {
        return []
    } else if right.contains(.canEditMessages) {
        return []
    } else if right.contains(.canDeleteMessages) {
        return []
    } else if right.contains(.canBanUsers) {
        return []
    } else if right.contains(.canInviteUsers) {
        return []
    } else if right.contains(.canChangeInviteLink) {
        return [.canInviteUsers]
    } else if right.contains(.canPinMessages) {
        return []
    } else if right.contains(.canAddAdmins) {
        return []
    } else {
        return []
    }
}

private func canEditAdminRights(accountPeerId: PeerId, channelView: PeerView, initialParticipant: ChannelParticipant?) -> Bool {
    if let channel = channelView.peers[channelView.peerId] as? TelegramChannel {
        if channel.flags.contains(.isCreator) {
            return true
        } else if let initialParticipant = initialParticipant {
            switch initialParticipant {
            case .creator:
                return false
            case let .member(_, _, adminInfo, _):
                if let adminInfo = adminInfo {
                    return adminInfo.canBeEditedByAccountPeer || adminInfo.promotedBy == accountPeerId
                } else {
                    return true
                }
            }
        } else {
            return channel.hasAdminRights(.canAddAdmins)
        }
    } else {
        return false
    }
}

private func channelAdminControllerEntries(state: ChannelAdminControllerState, accountPeerId: PeerId, channelView: PeerView, adminView: PeerView, initialParticipant: ChannelParticipant?) -> ([ChannelAdminEntry], TelegramChannelAdminRightsFlags) {
    var entries: [ChannelAdminEntry] = []
    
    var sectionId:Int32 = 1
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    var addAdminsEnabled: Bool = false
    var rights:TelegramChannelAdminRightsFlags = []
    if let channel = channelView.peers[channelView.peerId] as? TelegramChannel, let admin = adminView.peers[adminView.peerId] {
        entries.append(.info(sectionId, admin, adminView.peerPresences[admin.id] as? TelegramUserPresence))
        
        entries.append(.section(sectionId))
        sectionId += 1
        
        entries.append(.description(sectionId, 1, tr(L10n.channelAdminWhatCanAdminDo)))
        
        let isGroup: Bool
        let maskRightsFlags: TelegramChannelAdminRightsFlags
        var rightsOrder: [TelegramChannelAdminRightsFlags] = []
        
        switch channel.info {
        case .broadcast:
            isGroup = false
            maskRightsFlags = .broadcastSpecific
            rightsOrder = [
                .canChangeInfo,
                .canInviteUsers,
                .canPostMessages,
                .canEditMessages,
                .canDeleteMessages,
                .canAddAdmins
            ]
        case let .group(info):
            isGroup = true
            maskRightsFlags = .groupSpecific
            
            rightsOrder.append(.canChangeInfo)
            rightsOrder.append(.canDeleteMessages)
            rightsOrder.append(.canBanUsers)
            if !info.flags.contains(.everyMemberCanInviteMembers)  {
                rightsOrder.append(.canInviteUsers)
            }
            rightsOrder.append(.canPinMessages)
            rightsOrder.append(.canAddAdmins)
            
        }
        if canEditAdminRights(accountPeerId: accountPeerId, channelView: channelView, initialParticipant: initialParticipant) {
            let accountUserRightsFlags: TelegramChannelAdminRightsFlags
            if channel.flags.contains(.isCreator) {
                accountUserRightsFlags = maskRightsFlags
            } else if let adminRights = channel.adminRights {
                accountUserRightsFlags = maskRightsFlags.intersection(adminRights.flags)
            } else {
                accountUserRightsFlags = []
            }
            
            var currentRightsFlags: TelegramChannelAdminRightsFlags
            if let updatedFlags = state.updatedFlags {
                currentRightsFlags = updatedFlags
            } else if let initialParticipant = initialParticipant, case let .member(_, _, maybeAdminRights, _) = initialParticipant, let adminRights = maybeAdminRights {
                currentRightsFlags = adminRights.rights.flags
            } else {
                currentRightsFlags = accountUserRightsFlags.subtracting(.canAddAdmins)
            }

            
            rights = currentRightsFlags
            
            if accountUserRightsFlags.contains(.canAddAdmins) {
                addAdminsEnabled = currentRightsFlags.contains(.canAddAdmins)
            }
            
            var index = 0
            for right in rightsOrder {
                if accountUserRightsFlags.contains(right) {
                    
                    entries.append(.rightItem(sectionId, index, stringForRight(right: right, isGroup: isGroup), right, currentRightsFlags, currentRightsFlags.contains(right), !state.updating))
                    index += 1
                }
            }
            entries.append(.description(sectionId, 50, addAdminsEnabled ? tr(L10n.channelAdminAdminAccess) : tr(L10n.channelAdminAdminRestricted)))
        } else if let initialParticipant = initialParticipant, case let .member(_, _, maybeAdminInfo, _) = initialParticipant, let adminInfo = maybeAdminInfo {
            var index = 0
            for right in rightsOrder {
                entries.append(.rightItem(sectionId, index, stringForRight(right: right, isGroup: isGroup), right, adminInfo.rights.flags, adminInfo.rights.flags.contains(right), false))
                index += 1
            }
            entries.append(.description(sectionId, 50, tr(L10n.channelAdminCantEditRights)))
        }
    }
    
    return (entries, rights)
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<ChannelAdminEntry>], right: [AppearanceWrapperEntry<ChannelAdminEntry>], initialSize:NSSize, arguments:ChannelAdminControllerArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


class ChannelAdminController: ModalViewController {
    private var arguments: ChannelAdminControllerArguments?
    private let account:Account
    private let peerId:PeerId
    private let adminId:PeerId
    private let initialParticipant:ChannelParticipant?
    private let updated:(TelegramChannelAdminRights) -> Void
    private let disposable = MetaDisposable()
    private let currentRightFlags:Atomic<TelegramChannelAdminRightsFlags> = Atomic(value: [])
    private let stateValue = Atomic(value: ChannelAdminControllerState())
    init(account: Account, peerId: PeerId, adminId: PeerId, initialParticipant: ChannelParticipant?, updated: @escaping (TelegramChannelAdminRights) -> Void) {
        self.account = account
        self.peerId = peerId
        self.adminId = adminId
        self.initialParticipant = initialParticipant
        self.updated = updated
        super.init(frame: NSMakeRect(0, 0, 300, 360))
        bar = .init(height : 0)
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 70, genericView.listHeight)), animated: false)
    }
    
    override func viewClass() -> AnyClass {
        return TableView.self
    }
    
    private var genericView:TableView {
        return self.view as! TableView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let account = self.account
        let peerId = self.peerId
        let adminId = self.adminId
        let initialParticipant = self.initialParticipant
        let updated = self.updated

        let stateValue = self.stateValue
        let statePromise = ValuePromise(ChannelAdminControllerState(), ignoreRepeated: true)
        let updateState: ((ChannelAdminControllerState) -> ChannelAdminControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        let actionsDisposable = DisposableSet()
        
        let updateRightsDisposable = MetaDisposable()
        actionsDisposable.add(updateRightsDisposable)
        
        let arguments = ChannelAdminControllerArguments(account: account, toggleRight: { right, flags in
            updateState { current in
                var updated = flags
                if flags.contains(right) {
                    updated.remove(right)
                } else {
                    if right.contains(.canInviteUsers) {
                        updated.insert(.canChangeInviteLink)
                    }
                    updated.insert(right)
                }
                
                return current.withUpdatedUpdatedFlags(updated)
            }
        }, dismissAdmin: { [weak self] in
            if let strongSelf = self {
                updateState { current in
                    return current.withUpdatedUpdating(true)
                }
                updateRightsDisposable.set((updatePeerAdminRights(account: account, peerId: peerId, adminId: adminId, rights: TelegramChannelAdminRights(flags: [])) |> deliverOnMainQueue).start(error: { _ in
                    
                }, completed: { [weak strongSelf] in
                    updated(TelegramChannelAdminRights(flags: []))
                    strongSelf?.close()
                }))
            }
        })
        
        self.arguments = arguments
        
        let combinedView = account.postbox.combinedView(keys: [.peer(peerId: peerId), .peer(peerId: adminId)])
        
        let previous:Atomic<[AppearanceWrapperEntry<ChannelAdminEntry>]> = Atomic(value: [])
        let initialSize = atomicSize
        
        let signal = combineLatest(statePromise.get(), combinedView, appearanceSignal)
            |> deliverOn(prepareQueue)
            |> map { state, combinedView, appearance -> (transition: TableUpdateTransition, canEdit: Bool, canDismiss: Bool) in
                let channelView = combinedView.views[.peer(peerId: peerId)] as! PeerView
                let adminView = combinedView.views[.peer(peerId: adminId)] as! PeerView
                let canEdit = canEditAdminRights(accountPeerId: account.peerId, channelView: channelView, initialParticipant: initialParticipant)
                var canDismiss = false

                if let channel = peerViewMainPeer(channelView) as? TelegramChannel {
                    
                    if let initialParticipant = initialParticipant {
                        if channel.flags.contains(.isCreator) {
                            canDismiss = true
                        } else {
                            switch initialParticipant {
                            case .creator:
                                break
                            case let .member(_, _, adminInfo, _):
                                if let adminInfo = adminInfo {
                                    if adminInfo.promotedBy == account.peerId || adminInfo.canBeEditedByAccountPeer {
                                        canDismiss = true
                                    }
                                }
                            }
                        }
                    }
                }
                let result = channelAdminControllerEntries(state: state, accountPeerId: account.peerId, channelView: channelView, adminView: adminView, initialParticipant: initialParticipant)
                let entries = result.0.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
                _ = stateValue.modify({$0.withUpdatedUpdatedFlags(result.1).withUpdatedEditable(canEdit)})
                return (transition: prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments), canEdit: canEdit, canDismiss: canDismiss)
                
        } |> afterDisposed {
            actionsDisposable.dispose()
        } |> deliverOnMainQueue
        
        let updatedSize:Atomic<Bool> = Atomic(value: false)
        
        disposable.set(signal.start(next: { [weak self] values in
            self?.genericView.merge(with: values.transition)
            self?.readyOnce()
            self?.updateSize(updatedSize.swap(true))
            
            self?.modal?.interactions?.updateDone { button in
                button.set(text: tr(L10n.modalOK), for: .Normal)
                let flags = (stateValue.modify({$0}).updatedFlags ?? []).subtracting(.canChangeInviteLink)
                button.isEnabled = !flags.isEmpty
                if !values.canEdit {
                    button.isEnabled = true
                    button.set(text: tr(L10n.navigationDone), for: .Normal)
                }
            }
            self?.modal?.interactions?.updateCancel { button in
                button.set(text: values.canDismiss ? tr(L10n.channelAdminDismiss) : "", for: .Normal)
                button.set(color: values.canDismiss ? theme.colors.redUI : theme.colors.blueText, for: .Normal)
            }
        }))
        
        
    }
    
    private func updateSize(_ animated: Bool) {
        if let contentSize = self.window?.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(contentSize.height - 70, genericView.listHeight)), animated: animated)
        }
    }
    
    deinit {
        disposable.dispose()
    }
    
    
    override func close() {
        disposable.set(nil)
        super.close()
    }
    
    func updateRights(_ updateFlags: TelegramChannelAdminRightsFlags) {
        close()
        
        if !stateValue.modify({$0}).editable {
            return
        }
        
        let updated = self.updated
        
        _ = showModalProgress(signal: updatePeerAdminRights(account: account, peerId: peerId, adminId: adminId, rights: TelegramChannelAdminRights(flags: updateFlags)) |> deliverOnMainQueue, for: mainWindow).start(error: { error in
            alert(for: mainWindow, info: tr(L10n.channelAdminsAddAdminError))
        }, completed: {
            updated(TelegramChannelAdminRights(flags: updateFlags))
        })
    
    }
    func addAdmin(_ updateFlags: TelegramChannelAdminRightsFlags) {
        close()
    
        _ = showModalProgress(signal: addPeerAdmin(account: account, peerId: peerId, adminId: adminId, adminRightsFlags: updateFlags) |> deliverOnMainQueue, for: mainWindow).start(error: { error in
            
        }, completed: { [weak self] in
            self?.updated(TelegramChannelAdminRights(flags: updateFlags))
        })
        
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: tr(L10n.modalOK), accept: { [weak self] in
            if let _ = self?.initialParticipant {
                if let updatedFlags = self?.stateValue.modify({$0}).updatedFlags {
                    self?.updateRights(updatedFlags)
                } else {
                    self?.close()
                }
            } else {
                if let updatedFlags = self?.stateValue.modify({$0}).updatedFlags {
                    self?.addAdmin(updatedFlags)
                }
            }
            
        }, cancelTitle: tr(L10n.modalCancel), cancel: { [weak self] in
            self?.arguments?.dismissAdmin()
        }, height: 40)
    }
}

