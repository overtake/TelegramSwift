//
//  RestictedModalViewController.swift
//  Telegram
//
//  Created by keepcoder on 08/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit

private final class RestrictedControllerArguments {
    let context: AccountContext
    let toggleRight: (TelegramChatBannedRightsFlags, Bool) -> Void
    let changeUntil:()->Void
    let alertError:() -> Void
    let deleteException:()->Void
    let toggleMedia:()->Void
    init(context: AccountContext, toggleRight: @escaping (TelegramChatBannedRightsFlags, Bool) -> Void, changeUntil: @escaping () -> Void, alertError: @escaping() -> Void,  deleteException:@escaping()->Void, toggleMedia:@escaping()->Void) {
        self.context = context
        self.toggleRight = toggleRight
        self.changeUntil = changeUntil
        self.alertError = alertError
        self.deleteException = deleteException
        self.toggleMedia = toggleMedia
    }
}

private enum RestrictedEntryStableId: Hashable {
    case info
    case right(TelegramChatBannedRightsFlags)
    case description(Int32)
    case section(Int32)
    case timeout
    case exceptionInfo
    case delete
    var hashValue: Int {
        return 0
    }
}

private enum RestrictedEntry: TableItemListNodeEntry {
    case info(Int32, Peer, TelegramUserPresence?, GeneralViewType)
    case rightItem(Int32, Int32, NSAttributedString, TelegramChatBannedRightsFlags, Bool, Bool, GeneralViewType)
    case mediaRightItem(Int32, Int32, String, TelegramChatBannedRightsFlags, Bool, Bool, GeneralViewType)
    case description(Int32, Int32, String, GeneralViewType)
    case section(Int32, CGFloat)
    case timeout(Int32, Int32, String, String, GeneralViewType)
    case exceptionInfo(Int32, Int32, String, GeneralViewType)
    case delete(Int32, Int32, String, GeneralViewType)
    
    
    static func ==(lhs: RestrictedEntry, rhs: RestrictedEntry) -> Bool {
        switch lhs {
        case let .info(lhsSectionId, lhsPeer, lhsPresence, lhsViewType):
            if case let .info(rhsSectionId, rhsPeer, rhsPresence, rhsViewType) = rhs {
                if lhsSectionId != rhsSectionId {
                    return false
                }
                if !arePeersEqual(lhsPeer, rhsPeer) {
                    return false
                }
                if lhsPresence != rhsPresence {
                    return false
                }
                if lhsViewType != rhsViewType {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .rightItem(sectionId, index, text, flags, value, enabled, viewType):
            if case .rightItem(sectionId, index, text, flags, value, enabled, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .mediaRightItem(sectionId, index, text, flags, value, enabled, viewType):
            if case .mediaRightItem(sectionId, index, text, flags, value, enabled, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .description(sectionId, index, text, viewType):
            if case .description(sectionId, index, text, viewType) = rhs{
                return true
            } else {
                return false
            }
        case let .section(sectionId, height):
            if case .section(sectionId, height) = rhs{
                return true
            } else {
                return false
            }
        case let .exceptionInfo(sectionId, index, text, viewType):
            if case .exceptionInfo(sectionId, index, text, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .delete(sectionId, index, text, viewType):
            if case .delete(sectionId, index, text, viewType) = rhs {
                return true
            } else {
                return false
            }
        case let .timeout(sectionId, index, title, value, viewType):
            if case .timeout(sectionId, index, title, value, viewType) = rhs{
                return true
            } else {
                return false
            }
        }
    }
    

    var stableId: RestrictedEntryStableId {
        switch self {
        case .info:
            return .info
        case .timeout:
            return .timeout
        case let .rightItem(_, _, _, right, _, _, _):
            return .right(right)
        case let .mediaRightItem(_, _, _, right, _, _, _):
            return .right(right)
        case .description(_, let index, _, _):
            return .description(index)
        case .exceptionInfo:
            return .exceptionInfo
        case .delete:
            return .delete
        case .section(let sectionId, _):
            return .section(sectionId)
        }
    }
    
    var index:Int32 {
        switch self {
        case .info(let sectionId, _, _, _):
            return (sectionId * 1000) + 0
        case .description(let sectionId, let index, _, _):
            return (sectionId * 1000) + index
        case .delete(let sectionId, let index, _, _):
            return (sectionId * 1000) + index
        case .exceptionInfo(let sectionId, let index, _, _):
            return (sectionId * 1000) + index
        case .rightItem(let sectionId, let index, _, _, _, _, _):
            return (sectionId * 1000) + Int32(index) + 10
        case .mediaRightItem(let sectionId, let index, _, _, _, _, _):
            return (sectionId * 1000) + Int32(index) + 10
        case .section(let sectionId, _):
            return (sectionId + 1) * 1000 - sectionId
        case .timeout(let sectionId, let index, _, _, _):
            return (sectionId * 1000) + index
        }
    }
    
    static func <(lhs: RestrictedEntry, rhs: RestrictedEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: RestrictedControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .section(_, height):
            return GeneralRowItem(initialSize, height: height, stableId: stableId, viewType: .separator)
        case let .info(_, peer, presence, viewType):
            var string:String = peer.isBot ? strings().presenceBot : strings().peerStatusRecently
            var color:NSColor = theme.colors.grayText
            
            if let presence = presence {
                let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                (string,_, color) = stringAndActivityForUserPresence(presence, timeDifference: arguments.context.timeDifference, relativeTo: Int32(timestamp))
            }
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, context: arguments.context, stableId: stableId, enabled: true, height: 60, photoSize: NSMakeSize(40, 40), statusStyle: ControlStyle(font: .normal(.title), foregroundColor: color), status: string, borderType: [], drawCustomSeparator: false, drawLastSeparator: false, inset: NSEdgeInsets(left: 25, right: 25), drawSeparatorIgnoringInset: false, viewType: viewType, action: {})
        case let .rightItem(_, _, name, right, value, enabled, viewType):
            let action:()->Void
            if right == .banSendMedia {
                action = arguments.toggleMedia
            } else {
                action = {
                    arguments.toggleRight(right, !value)
                }
            }
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: name.string, nameAttributed: name, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: enabled ? theme.colors.text : theme.colors.grayText), type: .switchable(value), viewType: viewType, action: action, enabled: enabled, switchAppearance: SwitchViewAppearance(backgroundColor: .white, stateOnColor: theme.colors.accent, stateOffColor: theme.colors.redUI, disabledColor: theme.colors.grayBackground, borderColor: .clear), disabledAction: {
                arguments.alertError()
            }, switchAction: {
                arguments.toggleRight(right, !value)
            })
        case let .mediaRightItem(_, _, name, right, value, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: name, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: enabled ? theme.colors.text : theme.colors.grayText), type: .selectableLeft(value), viewType: viewType, action: {
                arguments.toggleRight(right, !value)
            }, enabled: enabled, switchAppearance: SwitchViewAppearance(backgroundColor: .white, stateOnColor: theme.colors.accent, stateOffColor: theme.colors.redUI, disabledColor: theme.colors.grayBackground, borderColor: .clear), disabledAction: {
                arguments.alertError()
            })
        case let .description(_, _, name, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: name, viewType: viewType)
        case let .timeout(_, _, title, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, type: .nextContext(value), viewType: viewType, action: {
                arguments.changeUntil()
            })
        case let .exceptionInfo(_, _, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .delete(_, _, name, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: name, nameStyle: redActionButton, type: .next, viewType: viewType, action: arguments.deleteException)
        }
    }
}


private enum RestrictUntil : Int32 {
    case day = 86400
    case week = 604800
    case month = 2592000
    case forever = 0
}

private struct RestrictedControllerState: Equatable {
    var referenceTimestamp: Int32
    var updatedFlags: TelegramChatBannedRightsFlags?
    var updatedTimeout: Int32?
    var updating: Bool = false
    var mediaRevealed: Bool = false
}
private func completeRights(_ flags: TelegramChatBannedRightsFlags) -> TelegramChatBannedRightsFlags {
    var result = flags
    result.remove(.banReadMessages)
    if result.contains(.banSendGifs) {
        result.insert(.banSendStickers)
        result.insert(.banSendGifs)
        result.insert(.banSendGames)
        result.insert(.banSendInline)
    } else {
        result.remove(.banSendStickers)
        result.remove(.banSendGifs)
        result.remove(.banSendGames)
        result.insert(.banSendInline)
    }
    return result
}


private func restrictedEntries(state: RestrictedControllerState, accountPeerId: PeerId, channelView: PeerView, memberView: PeerView, initialParticipant: ChannelParticipant?, initialBannedBy: Peer?) -> [RestrictedEntry] {
    var index:Int32 = 0
    var sectionId:Int32 = 0
    var entries:[RestrictedEntry] = []
    
    entries.append(.section(sectionId, 10))
    sectionId += 1
    
    
    
    if let peer = channelView.peers[channelView.peerId] as? TelegramChannel, let defaultBannedRights = peer.defaultBannedRights, let member = memberView.peers[memberView.peerId] {
        entries.append(.info(sectionId, member, memberView.peerPresences[member.id] as? TelegramUserPresence, .singleItem))
        
        entries.append(.section(sectionId, 20))
        sectionId += 1
        
        entries.append(.description(sectionId, index, strings().groupPermissionSectionTitle, .textTopItem))
        index += 1

        let currentRightsFlags: TelegramChatBannedRightsFlags
        if let updatedFlags = state.updatedFlags {
            currentRightsFlags = updatedFlags
        } else if let initialParticipant = initialParticipant, case let .member(_, _, _, maybeBanInfo, _) = initialParticipant, let banInfo = maybeBanInfo {
            currentRightsFlags = banInfo.rights.flags
        } else {
            currentRightsFlags = defaultBannedRights.flags
        }
        
        let currentTimeout: Int32
        if let updatedTimeout = state.updatedTimeout {
            currentTimeout = updatedTimeout
        } else if let initialParticipant = initialParticipant, case let .member(_, _, _, maybeBanInfo, _) = initialParticipant, let banInfo = maybeBanInfo {
            currentTimeout = banInfo.rights.untilDate
        } else {
            currentTimeout = Int32.max
        }
        
        let currentTimeoutString: String
        if currentTimeout == 0 || currentTimeout == Int32.max {
            currentTimeoutString = strings().timerForever
        } else {
            let remainingTimeout = currentTimeout - state.referenceTimestamp
            currentTimeoutString = timeIntervalString(Int(remainingTimeout))
        }
        
        let list = allGroupPermissionList(peer: peer)
        for (i, (right, _)) in list.enumerated() {
            
            let string: NSMutableAttributedString = NSMutableAttributedString()
            string.append(string: stringForGroupPermission(right: right, channel: peer), color: theme.colors.text, font: .normal(.title))
            
            if right == .banSendMedia {
                let count = banSendMediaSubList().filter({ !(currentRightsFlags.contains($0.0)) }).count
                string.append(string: " \(count)/\(banSendMediaSubList().count)", color: theme.colors.text, font: .bold(.small))
            }
            
            let defaultEnabled = !defaultBannedRights.flags.contains(right)
            entries.append(.rightItem(sectionId, index, string, right, defaultEnabled && !currentRightsFlags.contains(right), defaultEnabled && !state.updating, bestGeneralViewType(list, for: i)))
            index += 1
            if right == .banSendMedia, state.mediaRevealed {
                for (subRight, _) in banSendMediaSubList() {
                    let defaultEnabled = !defaultBannedRights.flags.contains(subRight)
                    entries.append(.mediaRightItem(sectionId, index, stringForGroupPermission(right: subRight, channel: peer), subRight, defaultEnabled && !currentRightsFlags.contains(subRight), defaultEnabled && !state.updating, .innerItem))
                    index += 1
                }
            }
        }
        
        entries.append(.section(sectionId, 20))
        sectionId += 1
        
      
        
        if let initialParticipant = initialParticipant, case let .member(member) = initialParticipant, let banInfo = member.banInfo, let initialBannedBy = initialBannedBy {
            entries.append(.timeout(sectionId, index, strings().groupPermissionDuration, currentTimeoutString, .firstItem))
            index += 1
            entries.append(.delete(sectionId, index, strings().groupPermissionDelete, .lastItem))
            index += 1
            entries.append(.exceptionInfo(sectionId, index, strings().groupPermissionAddedInfo(initialBannedBy.displayTitle, stringForRelativeSymbolicTimestamp(relativeTimestamp: banInfo.timestamp, relativeTo: state.referenceTimestamp)), .textBottomItem))
            index += 1
        } else {
            entries.append(.timeout(sectionId, index, strings().groupPermissionDuration, currentTimeoutString, .singleItem))
            index += 1
        }

    } else if let group = channelView.peers[channelView.peerId] as? TelegramGroup, let defaultBannedRights = group.defaultBannedRights, let member = memberView.peers[memberView.peerId] {
        entries.append(.info(sectionId, member, memberView.peerPresences[member.id] as? TelegramUserPresence, .singleItem))

        
        entries.append(.section(sectionId, 20))
        sectionId += 1

        entries.append(.description(sectionId, index, strings().groupPermissionSectionTitle, .textTopItem))
        index += 1
        
        let currentRightsFlags: TelegramChatBannedRightsFlags
        if let updatedFlags = state.updatedFlags {
            currentRightsFlags = updatedFlags
        } else if let initialParticipant = initialParticipant, case let .member(_, _, _, maybeBanInfo, _) = initialParticipant, let banInfo = maybeBanInfo {
            currentRightsFlags = banInfo.rights.flags
        } else {
            currentRightsFlags = defaultBannedRights.flags
        }
        
        let currentTimeout: Int32
        if let updatedTimeout = state.updatedTimeout {
            currentTimeout = updatedTimeout
        } else if let initialParticipant = initialParticipant, case let .member(_, _, _, maybeBanInfo, _) = initialParticipant, let banInfo = maybeBanInfo {
            currentTimeout = banInfo.rights.untilDate
        } else {
            currentTimeout = Int32.max
        }
        
        let currentTimeoutString: String
        if currentTimeout == 0 || currentTimeout == Int32.max {
            currentTimeoutString = strings().timerForever
        } else {
            let remainingTimeout = currentTimeout - state.referenceTimestamp
            currentTimeoutString = timeIntervalString(Int(remainingTimeout))
        }
                
        let list = allGroupPermissionList(peer: group)
        for (i, (right, _)) in list.enumerated() {
            
            let string: NSMutableAttributedString = NSMutableAttributedString()
            string.append(string: stringForGroupPermission(right: right, channel: nil), color: theme.colors.text, font: .normal(.title))
            
            if right == .banSendMedia {
                let count = banSendMediaSubList().filter({ !(currentRightsFlags.contains($0.0)) }).count
                string.append(string: " \(count)/\(banSendMediaSubList().count)", color: theme.colors.text, font: .bold(.small))
            }
            
            let defaultEnabled = !defaultBannedRights.flags.contains(right)
            entries.append(.rightItem(sectionId, index, string, right, defaultEnabled && !currentRightsFlags.contains(right), defaultEnabled && !state.updating, bestGeneralViewType(list, for: i)))
            index += 1
            if right == .banSendMedia, state.mediaRevealed {
                for (subRight, _) in banSendMediaSubList() {
                    let defaultEnabled = !defaultBannedRights.flags.contains(subRight)
                    entries.append(.mediaRightItem(sectionId, index, stringForGroupPermission(right: subRight, channel: nil), subRight, defaultEnabled && !currentRightsFlags.contains(subRight), defaultEnabled && !state.updating, .innerItem))
                    index += 1
                }
            }
        }
        
        entries.append(.section(sectionId, 20))
        sectionId += 1
        
        if let initialParticipant = initialParticipant, case let .member(member) = initialParticipant, let banInfo = member.banInfo, let initialBannedBy = initialBannedBy {
            entries.append(.timeout(sectionId, index, strings().groupPermissionDuration, currentTimeoutString, .firstItem))
            index += 1
            entries.append(.delete(sectionId, index, strings().groupPermissionDelete, .lastItem))
            index += 1
            entries.append(.exceptionInfo(sectionId, index, strings().groupPermissionAddedInfo(initialBannedBy.displayTitle, stringForRelativeSymbolicTimestamp(relativeTimestamp: banInfo.timestamp, relativeTo: state.referenceTimestamp)), .textBottomItem))
            index += 1
        } else {
            entries.append(.timeout(sectionId, index, strings().groupPermissionDuration, currentTimeoutString, .singleItem))
            index += 1
        }
    }


    entries.append(.section(sectionId, 20))
    sectionId += 1
    
    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<RestrictedEntry>], right: [AppearanceWrapperEntry<RestrictedEntry>], initialSize:NSSize, arguments:RestrictedControllerArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class RestrictedModalViewController: TableModalViewController {
    private let initialParticipant:ChannelParticipant?
    private let context:AccountContext
    private let disposable = MetaDisposable()
    private let peerId:PeerId
    private let memberId: PeerId
    private let updated:(TelegramChatBannedRights)->Void
    
    private var okClicked:(()->Void)?
    private var cancelClicked:(()->Void)?

    init(_ context: AccountContext, peerId:PeerId, memberId: PeerId, initialParticipant:ChannelParticipant?, updated: @escaping(TelegramChatBannedRights)->Void) {
        self.initialParticipant = initialParticipant
        self.context = context
        self.updated = updated
        self.peerId = peerId
        self.memberId = memberId
        super.init(frame: NSMakeRect(0, 0, 350, 360))
        bar = .init(height : 0)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        genericView.notifyScrollHandlers()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let initialState = RestrictedControllerState(referenceTimestamp: Int32(Date().timeIntervalSince1970), updatedFlags: nil, updatedTimeout: nil, updating: false)
        
        genericView.getBackgroundColor = {
            theme.colors.listBackground
        }

        
        let initialParticipant = self.initialParticipant
        let memberId = self.memberId
        let peerId = self.peerId
        let context = self.context
        
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((RestrictedControllerState) -> RestrictedControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }


        let actionsDisposable = DisposableSet()
        
        let updateRightsDisposable = MetaDisposable()
        actionsDisposable.add(updateRightsDisposable)


        let peerView = Promise<PeerView>()
        peerView.set(context.account.viewTracker.peerView(peerId))

        
        let arguments = RestrictedControllerArguments(context: context, toggleRight: { rights, value in
            let _ = (peerView.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { view in
                    
                    var defaultBannedRightsFlagsValue: TelegramChatBannedRightsFlags?
                    guard let peer = view.peers[peerId] else {
                        return
                    }
                    if let channel = peer as? TelegramChannel, let initialRightFlags = channel.defaultBannedRights?.flags {
                        defaultBannedRightsFlagsValue = initialRightFlags
                    } else if let group = peer as? TelegramGroup, let initialRightFlags = group.defaultBannedRights?.flags {
                        defaultBannedRightsFlagsValue = initialRightFlags
                    }
                    guard let defaultBannedRightsFlags = defaultBannedRightsFlagsValue else {
                        return
                    }
                    updateState { state in
                        var state = state
                        var effectiveRightsFlags: TelegramChatBannedRightsFlags
                        if let updatedFlags = state.updatedFlags {
                            effectiveRightsFlags = updatedFlags
                        } else if let initialParticipant = initialParticipant, case let .member(_, _, _, banInfo?, _) = initialParticipant {
                            effectiveRightsFlags = banInfo.rights.flags
                        } else {
                            effectiveRightsFlags = defaultBannedRightsFlags
                        }
                        if value {
                            effectiveRightsFlags.remove(rights)
                            effectiveRightsFlags = effectiveRightsFlags.subtracting(groupPermissionDependencies(rights))
                        } else {
                            effectiveRightsFlags.insert(rights)
                            effectiveRightsFlags = effectiveRightsFlags.union(groupPermissionDependencies(rights))
                        }
                        state.updatedFlags = effectiveRightsFlags
                        return state
                    }
                })
        }, changeUntil: { [weak self] in
            guard let `self` = self else {return}
            
            if let index = self.genericView.index(hash: RestrictedEntryStableId.timeout) {
                
                
                let applyValue: (Int32?) -> Void = { value in
                    updateState { state in
                        var state = state
                        state.updatedTimeout = value
                        return state
                    }
                }
                
                let intervals: [Int32] = [
                    1 * 60 * 60 * 24,
                    7 * 60 * 60 * 24,
                    30 * 60 * 60 * 24
                ]
                if let view = (self.genericView.viewNecessary(at: index) as? GeneralInteractedRowView)?.textView {
                    var items:[ContextMenuItem] = []
                    for interval in intervals {
                        items.append(ContextMenuItem(timeIntervalString(Int(interval)), handler: {
                            applyValue(initialState.referenceTimestamp + interval)
                        }))
                    }
                    items.append(ContextMenuItem(strings().channelBanForever, handler: {
                        applyValue(Int32.max)
                    }))
                    
                    let menu = ContextMenu()
                    for item in items {
                        menu.addItem(item)
                    }
                    
                    if let event = NSApp.currentEvent {
                        let value = AppMenu(menu: menu)
                        value.show(event: event, view: view)
                    }
                }
            }
        }, alertError: { [weak self] in
            let _ = (peerView.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] view in
                    if let peer = peerViewMainPeer(view) {
                        self?.show(toaster: ControllerToaster(text: peer.isSupergroup || peer.isGroup ? strings().channelExceptionDisabledOptionGroup : strings().channelExceptionDisabledOptionChannel))
                    }
                })
        }, deleteException: { [weak self] in
            self?.updated(TelegramChatBannedRights(flags: TelegramChatBannedRightsFlags(rawValue: 0), untilDate: 0))
            self?.close()
        }, toggleMedia: {
            updateState { current in
                var current = current
                current.mediaRevealed = !current.mediaRevealed
                return current
            }
        })
        
        
        let previous:Atomic<[AppearanceWrapperEntry<RestrictedEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        
        
        var keys: [PostboxViewKey] = [.peer(peerId: peerId, components: .all), .peer(peerId: memberId, components: .all)]
        if let banInfo = initialParticipant?.banInfo {
            keys.append(.peer(peerId: banInfo.restrictedBy, components: []))
        }
        let combinedView = context.account.postbox.combinedView(keys: keys)
        
        
        
        let signal:Signal<(TableUpdateTransition, PeerView, PeerView), NoError> = combineLatest(queue: prepareQueue, appearanceSignal, statePromise.get(), combinedView) |> map { appearance, state, combinedView in
            
            let channelView = combinedView.views[.peer(peerId: peerId, components: .all)] as! PeerView
            let memberView = combinedView.views[.peer(peerId: memberId, components: .all)] as! PeerView
            var initialBannedByPeer: Peer?
            if let banInfo = initialParticipant?.banInfo {
                initialBannedByPeer = (combinedView.views[.peer(peerId: banInfo.restrictedBy, components: [])] as? PeerView)?.peers[banInfo.restrictedBy]
            }
            
            let entries = restrictedEntries(state: state, accountPeerId: context.account.peerId, channelView: channelView, memberView: memberView, initialParticipant: initialParticipant, initialBannedBy: initialBannedByPeer).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            
           return (prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.with {$0}, arguments: arguments), channelView, memberView)
        } |> deliverOnMainQueue
        
        let animated:Atomic<Bool> = Atomic(value: false)
        disposable.set(signal.start(next: { [weak self] transition, channelView, memberView in
            self?.genericView.merge(with: transition)
            self?.updateSize(animated.swap(true))
            self?.readyOnce()
            self?.modal?.interactions?.updateDone({ button in
                if let peer = peerViewMainPeer(memberView) as? TelegramChannel {
                    button.isEnabled = peer.hasPermission(.banMembers)
                }
            })
            self?.modal?.interactions?.updateCancel({ [weak self] button in
                if self?.genericView.item(stableId: RestrictedEntryStableId.exceptionInfo) != nil {
                    button.set(text: strings().groupPermissionDelete, for: .Normal)
                    button.set(color: theme.colors.redUI, for: .Normal)
                } else {
                    button.set(text: "", for: .Normal)
                }
            })
            
            
            self?.okClicked = { [weak self] in
                
                let _ = (peerView.get()
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] view in
                       
                    var defaultBannedRightsFlagsValue: TelegramChatBannedRightsFlags?
                    guard let peer = view.peers[peerId] else {
                        return
                    }
                    if let channel = peer as? TelegramChannel, let initialRightFlags = channel.defaultBannedRights?.flags {
                        defaultBannedRightsFlagsValue = initialRightFlags
                    } else if let group = peer as? TelegramGroup, let initialRightFlags = group.defaultBannedRights?.flags {
                        defaultBannedRightsFlagsValue = initialRightFlags
                    }
                    guard let defaultBannedRightsFlags = defaultBannedRightsFlagsValue else {
                        return
                    }
                    
                    
                    var resolvedRights: TelegramChatBannedRights?
                    if let initialParticipant = initialParticipant {
                        var updateFlags: TelegramChatBannedRightsFlags?
                        var updateTimeout: Int32?
                        updateState { current in
                            updateFlags = current.updatedFlags
                            updateTimeout = current.updatedTimeout
                            return current
                        }
                        
                        if updateFlags == nil && updateTimeout == nil {
                            if case let .member(_, _, _, maybeBanInfo, _) = initialParticipant {
                                if maybeBanInfo == nil {
                                    updateFlags = defaultBannedRightsFlags
                                    updateTimeout = Int32.max
                                }
                            }
                        }
                        
                        if updateFlags != nil || updateTimeout != nil {
                            let currentRightsFlags: TelegramChatBannedRightsFlags
                            if let updatedFlags = updateFlags {
                                currentRightsFlags = updatedFlags
                            } else if case let .member(_, _, _, maybeBanInfo, _) = initialParticipant, let banInfo = maybeBanInfo {
                                currentRightsFlags = banInfo.rights.flags
                            } else {
                                currentRightsFlags = defaultBannedRightsFlags
                            }
                            
                            let currentTimeout: Int32
                            if let updateTimeout = updateTimeout {
                                currentTimeout = updateTimeout
                            } else if case let .member(_, _, _, maybeBanInfo, _) = initialParticipant, let banInfo = maybeBanInfo {
                                currentTimeout = banInfo.rights.untilDate
                            } else {
                                currentTimeout = Int32.max
                            }
                            
                            resolvedRights = TelegramChatBannedRights(flags: completeRights(currentRightsFlags), untilDate: currentTimeout)
                        }
                    } else if let _ = channelView.peers[channelView.peerId] as? TelegramChannel {
                        var updateFlags: TelegramChatBannedRightsFlags?
                        var updateTimeout: Int32?
                        updateState { state in
                            var state = state
                            updateFlags = state.updatedFlags
                            updateTimeout = state.updatedTimeout
                            state.updating = false
                            return state
                        }
                        
                        if updateFlags == nil {
                            updateFlags = defaultBannedRightsFlags
                        }
                        if updateTimeout == nil {
                            updateTimeout = Int32.max
                        }
                        
                        if let updateFlags = updateFlags, let updateTimeout = updateTimeout {
                           resolvedRights = TelegramChatBannedRights(flags: completeRights(updateFlags), untilDate: updateTimeout)
                        }
                    }
                    
                    var previousRights: TelegramChatBannedRights?
                    if let initialParticipant = initialParticipant, case let .member(_, _, _, banInfo, _) = initialParticipant, banInfo != nil {
                        previousRights = banInfo?.rights
                    }
                    if let resolvedRights = resolvedRights, previousRights != resolvedRights {
                        let cleanResolvedRightsFlags = resolvedRights.flags.union(defaultBannedRightsFlags)
                        let cleanResolvedRights = TelegramChatBannedRights(flags: cleanResolvedRightsFlags, untilDate: resolvedRights.untilDate)

                        if cleanResolvedRights.flags.isEmpty && previousRights == nil {
                            self?.close()
                        } else {
                            self?.updated(cleanResolvedRights)
                        }
                        
                    }
                })
                
            }
        }))
        
        genericView.addScroll(listener: .init(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            guard let `self` = self else {
                return
            }
            if self.genericView.documentSize.height > self.genericView.frame.height {
                self.genericView.verticalScrollElasticity = .automatic
            } else {
                self.genericView.verticalScrollElasticity = .none
            }
            if position.rect.minY - self.genericView.frame.height > 0 {
                self.modal?.makeHeaderState(state: .active, animated: true)
            } else {
                self.modal?.makeHeaderState(state: .normal, animated: true)
            }
        }))
        
    }
    
    deinit {
        disposable.dispose()
    }
    
    override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        return (left: ModalHeaderData(image: theme.icons.modalClose, handler: { [weak self] in
            self?.close()
        }), center: ModalHeaderData(title: strings().groupPermissionTitle), right: nil)
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: strings().modalApply, accept: { [weak self] in
            self?.close()
            self?.okClicked?()
        }, singleButton: true)
    }
    
    override var containerBackground: NSColor {
        return theme.colors.listBackground
    }
    
    override var modalTheme: ModalViewController.Theme {
        return .init(text: presentation.colors.text, grayText: presentation.colors.grayText, background: .clear, border: .clear, accent: presentation.colors.accent, grayForeground: presentation.colors.grayBackground, activeBackground: presentation.colors.background, activeBorder: presentation.colors.border)
    }
    
}
