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
    let call:(PeerId)->Void
    let removeCalls:([MessageId], Peer) -> Void
    let context:AccountContext
    init(context: AccountContext, call:@escaping(PeerId)->Void, removeCalls:@escaping([MessageId], Peer) ->Void ) {
        self.context = context
        self.removeCalls = removeCalls
        self.call = call
    }
}

private enum RecentCallEntry : TableItemListNodeEntry {
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
            }
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
        }
    }

    
    var stableId: AnyHashable {
        switch self {
        case .calls( let message, _, _, _):
            return message.chatStableId
        case .empty:
            return "empty"
        }
    }
    
    
    
    func item(_ arguments: RecentCallsArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
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
            
            
            
            let statusText:String
            if failed {
                statusText = strings().callRecentMissed
            } else {
                let text = outgoing ? strings().callRecentOutgoing : strings().callRecentIncoming
                if messages.count == 1 {
                    if let action = messages[0].media.first as? TelegramMediaAction, case .phoneCall(_, _, let duration, _) = action.action, let value = duration, value > 0 {
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
            
            
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, stableId: stableId, height: 46, titleStyle: titleStyle, titleAddition: countText, leftImage: outgoing ? theme.icons.callOutgoing : nil, status: statusText , borderType: [.Right], drawCustomSeparator:true, deleteInset: 10, inset: NSEdgeInsets( left: outgoing ? 10 : theme.icons.callOutgoing.backingSize.width + 15, right: 10), drawSeparatorIgnoringInset: true, interactionType: interactionType, generalType: .context(DateUtils.string(forMessageListDate: messages.first!.timestamp)), action: {
                if !editing {
                    arguments.call(peer.id)
                }
            }, contextMenuItems: {
                return .single([ContextMenuItem(strings().recentCallsDelete, handler: {
                    arguments.removeCalls(messages.map{ $0.id }, peer)
                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value)])
            })
        case .empty(let loading):
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: loading, text: strings().recentCallsEmpty, border: [.Right])
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
                state = .saveVisible(.aroundIndex(stableId))
            } else {
                switch position {
                case .Bottom:
                    state = .saveVisible(.lower)
                case .Top:
                    state = .saveVisible(.upper)
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
                }
            }
            entries.append(.calls( message._asMessage(), messages.map { $0._asMessage() }, state.editing, failed))
        default:
            break
        }
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
        
        let arguments = RecentCallsArguments(context: context, call: { [weak self] peerId in
            self?.callDisposable.set((phoneCall(context: context, peerId: peerId) |> deliverOnMainQueue).start(next: { result in
                applyUIPCallResult(context, result)
            }))
        }, removeCalls: { [weak self] messageIds, peer in
            modernConfirm(for: context.window, account: context.account, peerId: nil, header: strings().recentCallsDeleteHeader, information: strings().recentCallsDeleteCalls, okTitle: strings().recentCallsDelete, cancelTitle: strings().modalCancel, thridTitle: strings().recentCallsDeleteForMeAnd(peer.compactDisplayTitle), thridAutoOn: true, successHandler: { [weak self] result in
                
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
        return ("", theme.icons.callSettings)
    }
    
    override func scrollup(force: Bool = false) {
        super.scrollup(force: force)
        self.genericView.scroll(to: .up(true))
    }
    
    override func executeReturn() {
        showModal(with: CallSettingsModalController(context.sharedContext), for: context.window)
    }
    
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
