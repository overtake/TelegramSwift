//
//  RecentCallsViewController.swift
//  Telegram
//
//  Created by keepcoder on 07/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import DateUtils
import Postbox
import SwiftSignalKit


private extension EngineCallList.Item {
    var lowestIndex: EngineMessage.Index {
        switch self {
            case let .hole(index):
                return index
            case let .message(_, messages):
                var lowest = messages[0].index
                for i in 1 ..< messages.count {
                    let index = messages[i].index
                    if index < lowest {
                        lowest = index
                    }
                }
                return lowest
        }
    }
    
    var highestIndex: EngineMessage.Index {
        switch self {
        case let .hole(index):
            return index
        case let .message(_, messages):
            var highest = messages[0].index
            for i in 1 ..< messages.count {
                let index = messages[i].index
                if index > highest {
                    highest = index
                }
            }
            return highest
        }
    }
}


private final class RecentCallsArguments {
    let call:(PeerId, MessageId, TelegramMediaActionType.ConferenceCall?)->Void
    let removeCalls:([MessageId], Peer) -> Void
    let context:AccountContext
    let newCallLink:()->Void
    init(context: AccountContext, call:@escaping(PeerId, MessageId, TelegramMediaActionType.ConferenceCall?)->Void, removeCalls:@escaping([MessageId], Peer) ->Void, newCallLink:@escaping()->Void) {
        self.context = context
        self.removeCalls = removeCalls
        self.call = call
        self.newCallLink = newCallLink
    }
}

private enum RecentCallEntry : TableItemListNodeEntry {
    case newCallLink
    case recentCalls
    case calls(Message, [Message], Bool, Bool) // editing, failed
    case empty(Bool)
    static func <(lhs:RecentCallEntry, rhs:RecentCallEntry) -> Bool {
        switch lhs {
        case .calls(let lhsMessage, _, _, _):
            switch rhs {
            case .calls(let rhsMessage, _, _, _):
                return MessageIndex(lhsMessage) < MessageIndex(rhsMessage)
            case .empty:
                return false
            case .newCallLink :
                return true
            case .recentCalls:
                return true
            }
        case .newCallLink:
            return false
        case .recentCalls:
            return false
        case .empty:
            return true
        }
    }
    
    static func ==(lhs: RecentCallEntry, rhs: RecentCallEntry) -> Bool {
        switch lhs {
        case let .calls(lhsMessage, lhsMessages, lhsEditing, lhsFailed):
            switch rhs {
            case let .calls(rhsMessage, rhsMessages, rhsEditing, rhsFailed):
                if lhsFailed != rhsFailed {
                    return false
                }
                if lhsEditing != rhsEditing {
                    return false
                }
                
                if lhsMessage.id != rhsMessage.id {
                    return false
                }
                
                if lhsMessages.count != rhsMessages.count {
                    return false
                } else {
                    for i in 0 ..< lhsMessages.count {
                        if lhsMessages[i].id != rhsMessages[i].id {
                            return false
                        }
                    }
                }
                return true
            default:
                return false
            }
        case .empty(let loading):
            if case .empty(loading) = rhs {
                return true
            } else {
                return false
            }
        case .newCallLink:
            if case .newCallLink = rhs {
                return true
            } else {
                return false
            }
        case .recentCalls:
            if case .recentCalls = rhs {
                return true
            } else {
                return false
            }
        }
    }

    
    var stableId: AnyHashable {
        switch self {
        case .calls( let message, _, _, _):
            return message.chatStableId
        case .empty:
            return "empty"
        case .newCallLink:
            return "newCallLink"
        case .recentCalls:
            return "recentCalls"
        }
    }
    
    
    
    func item(_ arguments: RecentCallsArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .newCallLink:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().recentCallsNewCall, icon: NSImage.init(resource: .iconCreatePhoneCall).precomposed(theme.colors.accent, flipVertical: true), nameStyle: blueActionButton, viewType: .legacy, action: arguments.newCallLink, inset: NSEdgeInsets(left: 10, right: 0), disableBorder: true)
        case .recentCalls:
            return SeparatorRowItem(initialSize, stableId, string: strings().recentCallsRecentCalls)
        case let .calls(message, messages, editing, failed):
            let peer = coreMessageMainPeer(message)!

            let interactionType:ShortPeerItemInteractionType
            if editing {
                interactionType = .deletable(onRemove: { peerId in
                    arguments.removeCalls(messages.map{ $0.id }, peer)
                }, deletable: true)
            } else {
                interactionType = .plain
            }
            
            
            let titleStyle = ControlStyle(font: .medium(.title), foregroundColor: failed ? theme.colors.redUI : theme.colors.text)
            
            var outgoing:Bool
            if let message = messages.first {
                outgoing = !message.flags.contains(.Incoming)
            } else {
                outgoing = false
            }
            
            var conference: TelegramMediaActionType.ConferenceCall? = nil
            
            
            
            let statusText:String
            if let action = message.media.first as? TelegramMediaAction, case let .conferenceCall(call) = action.action {
                statusText = strings().callStatusGroupCall
                conference = call
            } else if failed {
                statusText = strings().callRecentMissed
            } else {
                let text = outgoing ? strings().callRecentOutgoing : strings().callRecentIncoming
                if messages.count == 1 {
                    if let action = messages[0].extendedMedia as? TelegramMediaAction, case .phoneCall(_, _, let duration, _) = action.action, let value = duration, value > 0 {
                        statusText = text + " (\(String.stringForShortCallDurationSeconds(for: value)))"
                    } else {
                        statusText = text
                    }
                } else {
                    statusText = text
                }
            }
            
            let countText:String?
            if messages.count > 1 {
                countText = " (\(messages.count))"
            } else {
                countText = nil
            }
            
            
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, context: arguments.context, stableId: stableId, height: 46, titleStyle: titleStyle, titleAddition: countText, status: statusText , borderType: [.Right], drawCustomSeparator:true, deleteInset: 10, inset: NSEdgeInsets(left: 10, right: 10), drawSeparatorIgnoringInset: true, interactionType: interactionType, generalType: .context(DateUtils.string(forMessageListDate: messages.last!.timestamp)), action: {
                if !editing {
                    arguments.call(peer.id, message.id, conference)
                }
            }, contextMenuItems: {
                return .single([ContextMenuItem(strings().recentCallsDelete, handler: {
                    arguments.removeCalls(messages.map{ $0.id }, peer)
                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value)])
            }, highlightVerified: true, statusImage: theme.icons.callOutgoing)
        case .empty(let loading):
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: loading, text: strings().recentCallsEmpty, border: [.Right], action: .init(click: arguments.newCallLink, title: strings().recentCallsNewCall))
        }
    }
}



class RecentCallsViewController: NavigationViewController {
    private var layoutController:LayoutRecentCallsViewController
    init(_ context:AccountContext) {
        self.layoutController = LayoutRecentCallsViewController(context)
        super.init(layoutController, context.window)
        bar = .init(height: 0)
    }
    
    override func scrollup(force: Bool = false) {
        super.scrollup(force: force)
        self.layoutController.scrollup(force: force)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.push(layoutController, false)
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        navigationBar.frame = NSMakeRect(0, 0, bounds.width, layoutController.bar.height)
        layoutController.frame = NSMakeRect(0, layoutController.bar.height, bounds.width, bounds.height - layoutController.bar.height)
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        layoutController.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        layoutController.viewDidAppear(animated)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        layoutController.viewWillDisappear(animated)
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        layoutController.viewDidDisappear(animated)
    }
}


fileprivate func prepareTransition(left:[AppearanceWrapperEntry<RecentCallEntry>], right: [AppearanceWrapperEntry<RecentCallEntry>], initialSize:NSSize, arguments:RecentCallsArguments, animated: Bool, scrollPosition: CallListViewScrollPosition?) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntries(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    for (_, item) in inserted {
        _ = item.makeSize(initialSize.width, oldWidth: initialSize.width)
    }
    for (_, item) in updated {
        _ = item.makeSize(initialSize.width, oldWidth: initialSize.width)
    }
    
    var state: TableScrollState = .none(nil)
    
    if let scrollPosition = scrollPosition {
        loop: switch scrollPosition {
        case let .index(index, position, directionHint, animated: animated):
            
            var stableId: AnyHashable?
            for entry in right {
                switch entry.entry {
                case let .calls(msg, msgs, _, _):
                    if msg.id == index.id || msgs.contains(where: { $0.id == index.id }) {
                        stableId = entry.stableId
                        break loop
                    }
                default:
                    break
                }
            }
            if let stableId = stableId {
                state = .saveVisible(.aroundIndex(stableId), false)
            } else {
                switch position {
                case .Bottom:
                    state = .saveVisible(.lower, false)
                case .Top:
                    state = .saveVisible(.upper, false)
                default:
                    state = .none(nil)
                }
            }
            
        }
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: animated, state: state)
}

private struct RecentCallsControllerState: Equatable {
    let editing: Bool
    let ignoringIds:Set<MessageId>
    let loading:Bool
    init() {
        self.editing = false
        ignoringIds = []
        loading = true
    }
    
    init(editing: Bool, ignoringIds:Set<MessageId>, loading:Bool) {
        self.editing = editing
        self.ignoringIds = ignoringIds
        self.loading = loading
    }
    
    static func ==(lhs: RecentCallsControllerState, rhs: RecentCallsControllerState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.ignoringIds != rhs.ignoringIds {
            return false
        }
        if lhs.loading != rhs.loading {
            return false
        }
        
        
        return true
    }
    
    func withUpdatedEditing(_ editing: Bool) -> RecentCallsControllerState {
        return RecentCallsControllerState(editing: editing, ignoringIds: self.ignoringIds, loading: self.loading)
    }
    func withUpdatedLoading(_ loading: Bool) -> RecentCallsControllerState {
        return RecentCallsControllerState(editing: self.editing, ignoringIds: self.ignoringIds, loading: loading)
    }
    
    func withAdditionalIgnoringIds(_ ids: [MessageId]) -> RecentCallsControllerState {
        var ignoring:Set<MessageId> = self.ignoringIds
        for id in ids {
            if !ignoring.contains(id) {
                ignoring.insert(id)
            }
        }
        return RecentCallsControllerState(editing: editing, ignoringIds: ignoring, loading: self.loading)
    }
    
}


private func makeEntries(from: CallListViewUpdate, state: RecentCallsControllerState) -> [RecentCallEntry] {
    var entries:[RecentCallEntry] = []
    
    
    
    for entry in from.view.items {
        switch entry {
        case let .message(message, messages):
            var failed:Bool = false
            let outgoing: Bool = !message.flags.contains(.Incoming)
            if let action = message.media.first as? TelegramMediaAction {
                if case .phoneCall(_, let discardReason, _, _) = action.action {
                    var missed: Bool = false
                    if let reason = discardReason {
                        switch reason {
                        case.missed, .busy:
                            missed = true
                        default:
                            break
                        }
                    }
                    failed = !outgoing && missed
                } else if case let .conferenceCall(call) = action.action {
                    failed = !outgoing && call.flags.contains(.isMissed)
                }
            }
            entries.append(.calls( message._asMessage(), messages.map { $0._asMessage() }, state.editing, failed))
        default:
            break
        }
    }
    
    if !from.view.items.isEmpty {
        entries.append(.recentCalls)
        entries.append(.newCallLink)
    }
    
    if entries.isEmpty {
        entries.append(.empty(false))
    }
    return entries
}

class LayoutRecentCallsViewController: EditableViewController<TableView> {
    private let previous:Atomic<[AppearanceWrapperEntry<RecentCallEntry>]> = Atomic(value: [])
    
    private let statePromise = ValuePromise(RecentCallsControllerState(), ignoreRepeated: true)
    private let stateValue = Atomic(value: RecentCallsControllerState())
    private let removePeerDisposable:MetaDisposable = MetaDisposable()
    private let callDisposable:MetaDisposable = MetaDisposable()
    private let againDisposable:MetaDisposable = MetaDisposable()
    private var first:Bool = false
    private let disposable = MetaDisposable()
    
    
    var navigation:NavigationViewController? {
        return super.navigationController?.navigationController
    }
    
    override var enableBack: Bool {
        return true
    }
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        navigationController?.updateLocalizationAndTheme(theme: theme)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.border = [.Right]
        self.rightBarView.border = [.Right]
        
        let previous = self.previous
        let initialSize = self.atomicSize
        let context = self.context
        
        
        let updateState: ((RecentCallsControllerState) -> RecentCallsControllerState) -> Void = { [weak self] f in
            if let strongSelf = self {
                strongSelf.statePromise.set(strongSelf.stateValue.modify { f($0) })
            }
        }
        
        let arguments = RecentCallsArguments(context: context, call: { [weak self] peerId, messageId, conferenceCall in
            
            
            if let conferenceCall {
                if conferenceCall.duration != nil {
                    return
                }

                _ = showModalProgress(signal: context.engine.peers.joinCallInvitationInformation(messageId: messageId), for: context.window).startStandalone(next: { [weak self] info in
                    guard let self else {
                        return
                    }
                    self.callDisposable.set(requestOrJoinConferenceCall(context: context, initialInfo: .init(id: info.id, accessHash: info.accessHash, participantCount: info.totalMemberCount, streamDcId: nil, title: nil, scheduleTimestamp: nil, subscribedToScheduled: false, recordingStartTimestamp: nil, sortAscending: false, defaultParticipantsAreMuted: nil, isVideoEnabled: false, unmutedVideoLimit: 0, isStream: false, isCreator: false), reference: .message(id: messageId)).start(next: { result in
                        switch result {
                        case let .samePeer(callContext), let .success(callContext):
                            applyGroupCallResult(context.sharedContext, callContext)
                        default:
                            alert(for: context.window, info: strings().errorAnError)
                        }
                    }))
                }, error: { error in
                    switch error {
                    case .flood:
                        showModalText(for: context.window, text: strings().loginFloodWait)
                    case .generic:
                        showModalText(for: context.window, text: strings().unknownError)
                    case .doesNotExist:
                        showModalText(for: context.window, text: strings().groupCallInviteNotAvailable)
                    }
                })
            } else {
                self?.callDisposable.set((phoneCall(context: context, peerId: peerId) |> deliverOnMainQueue).start(next: { result in
                    applyUIPCallResult(context, result)
                }))
            }
        }, removeCalls: { [weak self] messageIds, peer in
            verifyAlert(for: context.window, header: strings().recentCallsDeleteHeader, information: strings().recentCallsDeleteCalls, ok: strings().recentCallsDelete, cancel: strings().modalCancel, option: strings().recentCallsDeleteForMeAnd(peer.compactDisplayTitle), optionIsSelected: true, successHandler: { [weak self] result in
                
                let type: InteractiveMessagesDeletionType
                switch result {
                case .thrid:
                    type = .forEveryone
                default:
                    type = .forLocalPeer
                }
                _ = context.engine.messages.deleteMessagesInteractively(messageIds: messageIds, type: type).start()
                updateState({$0.withAdditionalIgnoringIds(messageIds)})
                
                self?.againDisposable.set((Signal<()->Void, NoError>.single({ [weak self] in
                    self?.viewWillAppear(false)
                }) |> delay(1.5, queue: Queue.mainQueue())).start(next: {value in value()}))
            })
        }, newCallLink: { [weak self] in
            
            guard let self, let window = self.window else {
                return
            }
            
            let limit = self.context.appConfiguration.getGeneralValue("conference_call_size_limit", orElse: 10)
                        
            let signal = (selectModalPeers(window: window, context: context, title: strings().callGroupCall, settings: [], excludePeerIds: [], limit: limit, behavior: SelectContactsBehavior(limit: limit, additionTopItem: SelectPeers_AdditionTopItem.init(title: strings().recentCallsNewCallLink, color: theme.colors.accent, icon: theme.icons.group_invite_via_link, callback: { [weak window] in
                closeAllModals(window: window)
                _ = showModalProgress(signal: context.engine.calls.createConferenceCall(), for: context.window).startStandalone(next: { groupCall in
                    showModal(with: GroupCallInviteLinkController(context: context, source: .groupCall(groupCall), mode: .basic, presentation: theme), for: context.window)
                })
            })), okTitle: strings().recentCallsNewCallOK) |> castError(CreateConferenceCallError.self) |> mapToSignal { peerIds -> Signal<(GroupCallInfo, [PeerId]), CreateConferenceCallError> in
                return context.engine.calls.createConferenceCall() |> map {
                    return ($0.callInfo, peerIds)
                } |> deliverOnMainQueue
            })
            
            _ = signal.startStandalone(next: { info, peerIds in
                _ = requestOrJoinConferenceCall(context: context, initialInfo: info, reference: .id(id: info.id, accessHash: info.accessHash)).start(next: { result in
                    switch result {
                    case let .samePeer(callContext), let .success(callContext):
                        applyGroupCallResult(context.sharedContext, callContext)
                        for peerId in peerIds {
                            _ = callContext.call.invitePeer(peerId, isVideo: false)
                        }
                    default:
                        alert(for: context.window, info: strings().errorAnError)
                    }
                })
            }, error: { [weak window] error in
                guard let window else {
                    return
                }
                switch error {
                case .generic:
                    showModalText(for: window, text: strings().unknownError)
                }
            })
            
            /*
             .start(next: { [weak window] info, peerIds in
                 guard let window else {
                     return
                 }
                 
                 
                 
             })
             
             */

        })
        
        
        let callListView:Atomic<CallListViewUpdate?> = Atomic(value: nil)
        
        let locationValue:ValuePromise<CallListLocation> = ValuePromise()
        
        let first:Atomic<Bool> = Atomic(value: true)
        let signal: Signal<CallListViewUpdate, NoError> = locationValue.get() |> distinctUntilChanged |> mapToSignal { location in
            return callListViewForLocationAndType(locationAndType: .init(location: location, scope: .all), engine: context.engine) |> map { $0.0 }
        }
        
        let transition:Signal<TableUpdateTransition, NoError> = combineLatest(queue: prepareQueue, signal, statePromise.get(), appearanceSignal) |> map { result, state, appearnace in
            _ = callListView.swap(result)
            let entries = makeEntries(from: result, state: state).map({AppearanceWrapperEntry(entry: $0, appearance: appearnace)})
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments, animated: !first.swap(false), scrollPosition: result.scrollPosition)
            } |> deliverOnMainQueue
        
        disposable.set(transition.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
        
        
        
//        genericView.setScrollHandler({ scroll in
//            
//            let view = callListView.with { $0 }
//            
//            if let view = view?.view {
//                var location: CallListLocation?
//                
//                switch scroll.direction {
//                case .bottom:
//                    if view.hasEarlier {
//                        location = .scroll(index: view.items[0].lowestIndex, sourceIndex: view.items[0].lowestIndex, scrollPosition: .Bottom, animated: false)
//                    }
//                case .top:
//                    if view.hasLater {
//                        location = .scroll(index: view.items[view.items.count - 1].highestIndex, sourceIndex: view.items[view.items.count - 1].highestIndex, scrollPosition: .Top, animated: false)
//                    }
//                case .none:
//                    break
//                }
//                if let location = location {
//                    locationValue.set(location)
//                }
//            }
//        })
        locationValue.set(.initial(count: 100))
        
    }
    
    override func update(with state: ViewControllerState) {
        super.update(with: state)
        self.statePromise.set(stateValue.modify({$0.withUpdatedEditing(state == .Edit)}))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func backSettings() -> (String, CGImage?) {
        return ("", nil)
    }
    
    override func scrollup(force: Bool = false) {
        super.scrollup(force: force)
        self.genericView.scroll(to: .up(true))
    }
    
//    override func executeReturn() {
//        showModal(with: CallSettingsModalController(context.sharedContext), for: context.window)
//    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        callDisposable.set(nil)
        againDisposable.set(nil)
    }
    
    deinit {
        callDisposable.dispose()
        againDisposable.dispose()
        disposable.dispose()
    }
    
}
