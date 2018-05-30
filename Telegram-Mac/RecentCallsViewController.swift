//
//  RecentCallsViewController.swift
//  Telegram
//
//  Created by keepcoder on 07/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

private final class RecentCallsArguments {
    let call:(PeerId)->Void
    let removeCalls:([MessageId]) -> Void
    let account:Account
    init(account: Account, call:@escaping(PeerId)->Void, removeCalls:@escaping([MessageId]) ->Void ) {
        self.account = account
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
                
                if lhsMessage.stableVersion != rhsMessage.stableVersion {
                    return false
                }
                
                if lhsMessages.count != rhsMessages.count {
                    return false
                } else {
                    for i in 0 ..< lhsMessages.count {
                        if lhsMessages[i].stableVersion != rhsMessages[i].stableVersion {
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
            
            let interactionType:ShortPeerItemInteractionType
            if editing {
                interactionType = .deletable(onRemove: { peerId in
                    arguments.removeCalls(messages.map{$0.id})
                }, deletable: true)
            } else {
                interactionType = .plain
            }
            
            let peer = messageMainPeer(message)!
            
            let titleStyle = ControlStyle(font: .medium(.title), foregroundColor: failed ? theme.colors.redUI : theme.colors.text)
            
            var outgoing:Bool
            if let message = messages.first {
                outgoing = !message.flags.contains(.Incoming)
            } else {
                outgoing = false
            }
            
            
            
            let statusText:String
            if failed {
                statusText = tr(L10n.callRecentMissed)
            } else {
                let text = outgoing ? tr(L10n.callRecentOutgoing) : tr(L10n.callRecentIncoming)
                if messages.count == 1 {
                    if let action = messages[0].media.first as? TelegramMediaAction, case .phoneCall(_,_,let duration) = action.action, let value = duration, value > 0 {
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
            
            
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.account, stableId: stableId, height: 46, titleStyle: titleStyle, titleAddition: countText, leftImage: outgoing ? theme.icons.callOutgoing : nil, status: statusText , borderType: [.Right], drawCustomSeparator:true, deleteInset: 10, inset: NSEdgeInsets( left: outgoing ? 10 : theme.icons.callOutgoing.backingSize.width + 15, right: 10), drawSeparatorIgnoringInset: true, interactionType: interactionType, generalType: .context(DateUtils.string(forMessageListDate: messages.first!.timestamp)), action: {
                if !editing {
                    arguments.call(peer.id)
                }
            })
        case .empty(let loading):
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: loading, text: tr(L10n.recentCallsEmpty), border: [.Right])
        }
    }
}



class RecentCallsViewController: NavigationViewController {
    private var layoutController:LayoutRecentCallsViewController
    init(_ account:Account) {
        self.layoutController = LayoutRecentCallsViewController(account)
        super.init(layoutController)
        bar = .init(height: 0)
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


fileprivate func prepareTransition(left:[AppearanceWrapperEntry<RecentCallEntry>], right: [AppearanceWrapperEntry<RecentCallEntry>], initialSize:NSSize, arguments:RecentCallsArguments, animated: Bool) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntries(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    for (_, item) in inserted {
        _ = item.makeSize(initialSize.width, oldWidth: initialSize.width)
    }
    for (_, item) in updated {
        _ = item.makeSize(initialSize.width, oldWidth: initialSize.width)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: animated)
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


private func makeEntries(from: [CallListViewEntry], state: RecentCallsControllerState) -> [RecentCallEntry] {
    var entries:[RecentCallEntry] = []
    for entry in from {
        switch entry {
        case let .message(message, messages):
            var failed:Bool = false
            let outgoing: Bool = !message.flags.contains(.Incoming)
            if let action = message.media.first as? TelegramMediaAction {
                if case .phoneCall(_, let discardReason, _) = action.action {
                    
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
            entries.append(.calls( message, messages, state.editing, failed))
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
        return false
    }
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        navigationController?.updateLocalizationAndTheme()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.border = [.Right]
        self.rightBarView.border = [.Right]
        
        let previous = self.previous
        let initialSize = self.atomicSize
        let account = self.account
        
        
        let updateState: ((RecentCallsControllerState) -> RecentCallsControllerState) -> Void = { [weak self] f in
            if let strongSelf = self {
                strongSelf.statePromise.set(strongSelf.stateValue.modify { f($0) })
            }
        }
        
        let arguments = RecentCallsArguments(account: account, call: { [weak self] peerId in
            self?.callDisposable.set((phoneCall(account, peerId: peerId) |> deliverOnMainQueue).start(next: { result in
                applyUIPCallResult(account, result)
            }))
            }, removeCalls: { [weak self] messageIds in
                _ = deleteMessagesInteractively(postbox: account.postbox, messageIds: messageIds, type: .forLocalPeer).start()
                updateState({$0.withAdditionalIgnoringIds(messageIds)})
                
                if let strongSelf = self {
                    strongSelf.againDisposable.set((Signal<()->Void, Void>.single({ [weak strongSelf] in
                        strongSelf?.viewWillAppear(false)
                    }) |> delay(1.5, queue: Queue.mainQueue())).start(next: {value in value()}))
                }
                self?.viewWillAppear(false)
        })
        
        
        let callListView:Atomic<CallListView?> = Atomic(value: nil)
        
        let location:ValuePromise<MessageIndex> = ValuePromise()
        
        let first:Atomic<Bool> = Atomic(value: true)
        let signal: Signal<CallListView, NoError> = location.get() |> distinctUntilChanged |> mapToSignal { index in
            return account.viewTracker.callListView(type: .all, index: index, count: 200)
        }
        
        let transition:Signal<TableUpdateTransition, Void> = combineLatest(signal |> deliverOnPrepareQueue, statePromise.get() |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue) |> map { result in
            _ = callListView.swap(result.0)
            let entries = makeEntries(from: result.0.entries, state: result.1).map({AppearanceWrapperEntry(entry: $0, appearance: result.2)})
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments, animated: !first.swap(false))
            } |> deliverOnMainQueue
        
        disposable.set(transition.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
        }))
        
        
        readyOnce()
        
        genericView.setScrollHandler({ scroll in
            
            let view = callListView.modify({$0})
            
            if let view = view {
                var messageIndex:MessageIndex?
                
                switch scroll.direction {
                case .bottom:
                    messageIndex = view.earlier
                case .top:
                    messageIndex = view.later
                case .none:
                    break
                }
                if let messageIndex = messageIndex {
                    _ = first.swap(true)
                    location.set(messageIndex)
                }
            }
        })
        location.set(MessageIndex.absoluteUpperBound())
        
    }
    
    override func update(with state: ViewControllerState) {
        super.update(with: state)
        self.statePromise.set(stateValue.modify({$0.withUpdatedEditing(state == .Edit)}))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateLocalizationAndTheme()
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
