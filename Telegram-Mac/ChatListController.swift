//
//  TGDialogsViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 07/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac



extension ChatListEntry: Identifiable {
    public var stableId: AnyHashable {
        return index.messageIndex.id.peerId
    }
}


//enum ChatListEntryWrap : Identifiable, Comparable {
//    
//    static func < (lhs: ChatListEntryWrap, rhs: ChatListEntryWrap) -> Bool {
//        switch lhs {
//        case let .empty(lhsIndex):
//            if case let .empty(rhsIndex) = rhs {
//                return lhsIndex < rhsIndex
//            } else {
//                return false
//            }
//        case let .chatList(lhs):
//            if case let .empty(rhs) = rhs {
//                return lhs < rhs
//            } else {
//                return false
//            }
//        }
//    }
//    
//    case empty(Int32)
//    case chatList(ChatListEntry)
//    
//}


fileprivate func prepareEntries(from:[AppearanceWrapperEntry<ChatListEntry>]?, to:[AppearanceWrapperEntry<ChatListEntry>], adIndex: UInt16?, context: AccountContext, initialSize:NSSize, animated:Bool, scrollState:TableScrollState? = nil, state: ChatListRowState) -> Signal<TableUpdateTransition, NoError> {
    
    return Signal { subscriber in
        
        var cancelled: Bool = false
        
        func makeItem(_ entry: AppearanceWrapperEntry<ChatListEntry>) -> TableRowItem {
            switch entry.entry {
            case let .HoleEntry(hole):
                return ChatListHoleRowItem(initialSize, context, hole)
            case let .MessageEntry(index, message, readState, notifySettings,embeddedState, renderedPeer, summaryInfo):
                
                var pinnedType: ChatListPinnedType = .some
                if let i = to.index(of: entry) {
                    if let pinningIndex = index.pinningIndex {
                        if pinningIndex == adIndex {
                            pinnedType = .ad
                        } else {
                            if i > 0 {
                                if case let .MessageEntry(index, _, _, _ ,_ , _, _) = to[i - 1].entry, index.pinningIndex == nil {
                                    pinnedType = .last
                                }
                            }
                        }
                    } else {
                        pinnedType = .none
                    }
                }
                return ChatListRowItem(initialSize, context: context, message: message, index: entry.entry.index, readState:readState, notificationSettings: notifySettings, embeddedState: embeddedState, pinnedType: pinnedType, renderedPeer: renderedPeer, summaryInfo: summaryInfo, state: state)
            case let .GroupReferenceEntry(groupId, index, message, peers, unreadCounters):
                var pinnedType: ChatListPinnedType = .some
                if let i = to.index(of: entry) {
                    if index.pinningIndex != nil {
                        if i > 0 {
                            if case let .MessageEntry(index, _, _, _ ,_ , _, _) = to[i - 1].entry, index.pinningIndex == nil {
                                pinnedType = .last
                            }
                        }
                    } else {
                        pinnedType = .none
                    }
                }
                return ChatListRowItem(initialSize, context: context, pinnedType: pinnedType, groupId: groupId, message: message, peers: peers, unreadCounters: unreadCounters, state: state)
            }
        }
        
        
        
        let (deleted,inserted,updated) = proccessEntries(from, right: to, { entry -> TableRowItem in
            return makeItem(entry)
        })
        
        let nState = scrollState ?? (animated ? .none(nil) : .saveVisible(.lower))
        let transition = TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated:animated, state: nState, animateVisibleOnly: false)
        
        subscriber.putNext(transition)
        subscriber.putCompletion()
        return ActionDisposable {
           cancelled = true
        }
    }
}




class ChatListController : PeersListController {

    private let request = Promise<ChatListIndexRequest>()
    private let previousChatList:Atomic<ChatListView?> = Atomic(value: nil)
    private let first = Atomic(value:true)
    private let stateValue:ValuePromise<ChatListRowState> = ValuePromise(.plain)
    private let removePeerIdGroupDisposable = MetaDisposable()
    private let disposable = MetaDisposable()
    private let scrollDisposable = MetaDisposable()
    private let reorderDisposable = MetaDisposable()
    private let globalPeerDisposable = MetaDisposable()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        genericView.tableView.emptyItem = ChatListEmptyRowItem(frame.size)
        
        let initialSize = self.atomicSize
        let context = self.context
        let previousChatList = self.previousChatList
        let first = Atomic<(ChatListIndex?, ChatListIndex?)>(value: (nil, nil))
        let scrollUp:Atomic<Bool> = self.first
        let groupId = self.mode.groupId
        let onMainQueue:Atomic<Bool> = Atomic(value: true)
        let previousEntries:Atomic<[AppearanceWrapperEntry<ChatListEntry>]?> = Atomic(value: nil)
        let stateValue = self.stateValue
        let animated: Atomic<Bool> = Atomic(value: false)

        let previousState:Atomic<ChatListRowState> = Atomic(value: .plain)
        
        var scroll:TableScrollState? = nil

        
        let chatHistoryView: Signal<(ChatListView, ViewUpdateType, Bool), NoError> = request.get() |> distinctUntilChanged |> mapToSignal { location -> Signal<(ChatListView, ViewUpdateType, Bool), NoError> in
            
            var signal:Signal<(ChatListView,ViewUpdateType), NoError>
            var removeNextAnimation: Bool = false
            switch location {
            case let .Initial(count, st):
                signal = context.account.viewTracker.tailChatListView(groupId: groupId, count: count)
                scroll = st
            case let .Index(index, st):
                signal = context.account.viewTracker.aroundChatListView(groupId: groupId, index: index, count: 100)
                scroll = st
                removeNextAnimation = st != nil
            }
            return signal |> map { ($0.0, $0.1, removeNextAnimation)}
        }
        
        let queue = self.queue

        let list:Signal<TableUpdateTransition,NoError> = combineLatest(queue: queue, chatHistoryView, appearanceSignal, stateValue.get(), context.chatUndoManager.allStatuses()) |> mapToQueue { value, appearance, state, undoStatuses -> Signal<TableUpdateTransition, NoError> in
                    
                    var removeNextAnimation = value.2
                    
                    let previous = first.swap((value.0.earlierIndex, value.0.laterIndex))
            
                    let ignoreFlags = scrollUp.swap(false)
            
            
            
                    if !ignoreFlags || (!ignoreFlags && (previous.0 != value.0.earlierIndex || previous.1 != value.0.laterIndex) && !removeNextAnimation) {
                        scroll = nil
                    }
                
                    if removeNextAnimation {
                        removeNextAnimation = false
                    }
                   
                    
                _ = previousChatList.swap(value.0)
                    
                    
                let stateWasUpdated = previousState.swap(state) != state
                    var prepare = value.0.entries
                    var pinnedIndex:UInt16 = 11
                    if value.0.laterIndex == nil {
                        prepare.removeAll()
                       
                        for value in  value.0.entries {
                            switch value {
                            case let .MessageEntry(index, a, b, c, d, e, f):
                                if let _ = index.pinningIndex {
                                    prepare.append(.MessageEntry(ChatListIndex(pinningIndex: pinnedIndex, messageIndex: index.messageIndex), a, b, c, d, e, f))
                                    pinnedIndex -= 1
                                } else {
                                    prepare.append(value)
                                }
                            default:
                                prepare.append(value)
                            }
                        }
                        
                        if let value = value.0.additionalItemEntries.first {
                            switch value {
                            case let .MessageEntry(index, a, b, c, d, e, f):
                                prepare.append(ChatListEntry.MessageEntry(ChatListIndex(pinningIndex: pinnedIndex, messageIndex: index.messageIndex), a, b, c, d, e, f))
                            default:
                                break
                            }
                        }
                    }
                    
                    let entries = prepare.compactMap { entry -> AppearanceWrapperEntry<ChatListEntry>? in
                        switch entry {
                        case .HoleEntry:
                            return nil
                        default:
                            if undoStatuses.isActive(peerId: entry.index.messageIndex.id.peerId, types: [.deleteChat, .leftChat, .leftChannel, .deleteChannel]) {
                                return nil
                            } else if undoStatuses.isActive(peerId: entry.index.messageIndex.id.peerId, types: [.clearHistory]) {
                                switch entry {
                                case let .MessageEntry(values):
                                    let entry: ChatListEntry = ChatListEntry.MessageEntry(values.0, nil, values.2, values.3, values.4, values.5, values.6)
                                    return AppearanceWrapperEntry(entry: entry, appearance: stateWasUpdated ? appearance.newAllocation : appearance)
                                default:
                                    return AppearanceWrapperEntry(entry: entry, appearance: stateWasUpdated ? appearance.newAllocation : appearance)
                                }
                            } else {
                                return AppearanceWrapperEntry(entry: entry, appearance: stateWasUpdated ? appearance.newAllocation : appearance)
                            }
                        }
                    }
                
                    let prev = previousEntries.swap(entries)
                    
            return prepareEntries(from: prev, to: entries, adIndex: value.0.additionalItemEntries.first != nil ? pinnedIndex : nil, context: context, initialSize: initialSize.modify({$0}), animated: animated.swap(true), scrollState: scroll, state: state)
            }
        
        
        var firstRequest: Bool = true
        let appliedTransition = list |> deliverOnMainQueue |> mapToQueue { [weak self] transition -> Signal<Void, NoError> in
            self?.enqueueTransition(transition)
            if firstRequest, let `self` = self {
                firstRequest = false
                self.request.set(.single(.Initial(Int(50), nil)))
            }
            return .complete()
        }
        
        disposable.set(appliedTransition.start())
        
        
        request.set(.single(.Initial(Int(frame.height / 70) + 1, nil)))
        
        var pinnedCount: Int = 0
        self.genericView.tableView.enumerateItems { item -> Bool in
            guard let item = item as? ChatListRowItem, item.pinnedType != .none else {return false}
            pinnedCount += 1
            return item.pinnedType != .none
        }
        
        genericView.tableView.resortController = TableResortController(resortRange: NSMakeRange(0, pinnedCount), start: { row in
            
        }, resort: { row in
            
        }, complete: { [weak self] from, to in
            self?.resortPinned(from, to)
        })
        
        
        genericView.tableView.addScroll(listener: TableScrollListener({ [weak self] scroll in

            guard let `self` = self, let view = previousChatList.modify({$0}) else {return}
//            #if !STABLE && !APP_STORE
//            if scroll.visibleRows.location == 0 && view.laterIndex != nil {
//                self.lastScrolledIndex = nil
//            }
//            self.account.context.mainViewController.isUpChatList = scroll.visibleRows.location > 0 || view.laterIndex != nil
//            #else
            context.sharedContext.bindings.mainController().isUpChatList = false
            //#endif
           
        }))
        
        

        genericView.tableView.setScrollHandler({ [weak self] scroll in
            
            let view = previousChatList.modify({$0})
            
            if let strongSelf = self, let view = view {
                var messageIndex:ChatListIndex?
                
                switch scroll.direction {
                case .bottom:
                    messageIndex = view.earlierIndex
                case .top:
                    messageIndex = view.laterIndex
                case .none:
                    break
                }
                if let messageIndex = messageIndex {
                    _ = animated.swap(false)
                    strongSelf.request.set(.single(.Index(messageIndex, nil)))
                }
            }
        })
        
        let previousLocation: Atomic<ChatLocation?> = Atomic(value: nil)
        globalPeerDisposable.set(context.globalPeerHandler.get().start(next: { [weak self] location in
            if previousLocation.swap(location) != location {
                self?.removeSwipingStateIfNeeded(nil)
            }
            
            self?.removeHighlightEvents()
            
            if let searchController = self?.searchController {
                searchController.updateHighlightEvents(location != nil)
            }
            if location == nil {
                self?.setHighlightEvents()
            }
        }))
        
//        return account.postbox.unreadMessageCountsView(items: items) |> map { view in
//            var totalCount:Int32 = 0
//            if let total = view.count(for: .total(value, .messages)) {
//                totalCount = total
//            }
//            
//            return (view, totalCount)
//        }
        
    }
    
    private func enqueueTransition(_ transition: TableUpdateTransition) {
        self.genericView.tableView.merge(with: transition)
        readyOnce()
        switch self.mode {
        case .feedChannels:
            if self.genericView.tableView.isEmpty {
                self.navigationController?.close()
            }
        default:
            break
        }
        
        var pinnedCount: Int = 0
        self.genericView.tableView.enumerateItems { item -> Bool in
            guard let item = item as? ChatListRowItem, item.pinnedType != .none else {return false}
            pinnedCount += 1
            return item.pinnedType != .none
        }
        self.searchController?.pinnedItems = self.collectPinnedItems
        self.genericView.tableView.resortController?.resortRange = NSMakeRange(0, pinnedCount)
    }
    
    private func resortPinned(_ from: Int, _ to: Int) {
        
        var items:[PinnedItemId] = []

        
        self.genericView.tableView.enumerateItems { item -> Bool in
            guard let item = item as? ChatListRowItem, item.pinnedType != .none else {return false}
            items.append(item.chatLocation.pinnedItemId)
            return item.pinnedType != .none
        }
        
         items.move(at: from, to: to)
        
        reorderDisposable.set(context.account.postbox.transaction { transaction -> Void in
            _ = reorderPinnedItemIds(transaction: transaction, itemIds: items)
        }.start())
    }
    
    override var collectPinnedItems:[PinnedItemId] {
        var items:[PinnedItemId] = []
        
        
        self.genericView.tableView.enumerateItems { item -> Bool in
            guard let item = item as? ChatListRowItem, item.pinnedType != .none else {return false}
            items.append(item.chatLocation.pinnedItemId)
            return item.pinnedType != .none
        }
        return items
    }

    private var lastScrolledIndex: ChatListIndex? = nil
    
    
    override func scrollup() {
        
        if searchController != nil {
            self.genericView.searchView.change(state: .None, true)
            return
        }
        
        let lastScrolledIndex = self.lastScrolledIndex
        
        let scrollToTop:()->Void = { [weak self] in
            guard let `self` = self else {return}

            let view = self.previousChatList.modify({$0})
            if view?.laterIndex != nil {
                _ = self.first.swap(true)
                self.request.set(.single(.Initial(50, .up(true))))
            } else {
                self.genericView.tableView.scroll(to: .up(true))
            }
        }
        
//        #if !STABLE && !APP_STORE
//        let view = self.previousChatList.modify({$0})
//
//
//        if lastScrolledIndex == nil, view?.laterIndex != nil || genericView.tableView.scrollPosition().current.visibleRows.location > 0  {
//            scrollToTop()
//            return
//        }
//        let postbox = account.postbox
//
//        let signal:Signal<ChatListIndex?, NoError> = account.context.badgeFilter.get() |> mapToSignal { filter -> Signal<ChatListIndex?, NoError> in
//            return postbox.transaction { transaction -> ChatListIndex? in
//                return transaction.getEarliestUnreadChatListIndex(filtered: filter == .filtered, earlierThan: lastScrolledIndex)
//            }
//            } |> deliverOnMainQueue
//
//        scrollDisposable.set(signal.start(next: { [weak self] index in
//            guard let `self` = self else {return}
//            if let index = index {
//                self.lastScrolledIndex = index
//                self.request.set(.single(ChatListIndexRequest.Index(index, TableScrollState.center(id: ChatLocation.peer(index.messageIndex.id.peerId), innerId: nil, animated: true, focus: true, inset: 0))))
//            } else {
//                self.lastScrolledIndex = nil
//                scrollToTop()
//            }
//        }))
//
//        #else
            scrollToTop()
       // #endif
        
        
    }
    
    
    func globalSearch(_ query: String) {
        let invoke = { [weak self] in
            self?.genericView.searchView.change(state: .Focus, false)
            self?.genericView.searchView.setString(query)
        }
        
        switch context.sharedContext.layout {
        case .single:
            context.sharedContext.bindings.rootNavigation().back()
            Queue.mainQueue().justDispatch(invoke)
        case .minimisize:
            context.sharedContext.bindings.needFullsize()
            Queue.mainQueue().justDispatch(invoke)
        default:
            invoke()
        }
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.window?.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            if event.modifierFlags.contains(.control) {
                if self.genericView.tableView._mouseInside() {
                    let row = self.genericView.tableView.row(at: self.genericView.tableView.clipView.convert(event.locationInWindow, from: nil))
                    if row >= 0 {
                        self.genericView.tableView.item(at: row).view?.mouseDown(with: event)
                        return .invoked
                    }
                }
            }
            return .rejected
        }, with: self, for: .leftMouseDown, priority: .high)
        
//        self.window?.set(responder: { [weak self] () -> NSResponder? in
//
//            guard let `self` = self else {return nil}
//            switch self.genericView.searchView.state {
//            case .None:
//                return self.genericView.searchView.input
//            default:
//                break
//            }
//            return nil
//        }, with: self, priority: .low)
        
        self.window?.add(swipe: { [weak self] direction -> SwipeHandlerResult in
            guard let `self` = self, let window = self.window else {return .failed}
            let swipeState: SwipeState?
            switch direction {
            case let .left(_state):
                swipeState = _state
            case let .right(_state):
                swipeState = _state
            case .none:
                swipeState = nil
            }
            
            
            guard let state = swipeState else {return .failed}
            

            
            switch state {
            case .start:
                let row = self.genericView.tableView.row(at: self.genericView.tableView.clipView.convert(window.mouseLocationOutsideOfEventStream, from: nil))
                if row != -1 {
                    let item = self.genericView.tableView.item(at: row) as! ChatListRowItem
                    guard item.pinnedType != .ad else {return .failed}
                    self.removeSwipingStateIfNeeded(item.peerId)
                    (item.view as? SwipingTableView)?.initSwipingState()
                    return .success(SwipingTableItemController(item: item))
                } else {
                    return .failed
                }
               
            case let .swiping(_delta, controller):
                let controller = controller as! SwipingTableItemController

                guard let view = controller.item.view as? SwipingTableView else {return .nothing}
                
                var delta:CGFloat
                switch direction {
                case .left:
                    delta = _delta//max(0, _delta)
                case .right:
                    delta = -_delta//min(-_delta, 0)
                default:
                    delta = _delta
                }
                
                
                delta -= view.additionalSwipingDelta
                
                let newDelta = min(view.width * log2(abs(delta) + 1) * log2(delta < 0 ? view.width * 4 : view.width) / 100.0, abs(delta))

                if delta < 0 {
                    delta = -newDelta
                } else {
                    delta = newDelta
                }

                

                view.moveSwiping(delta: delta)
            case let .success(_, controller), let .failed(_, controller):
                let controller = controller as! SwipingTableItemController
                guard let view = (controller.item.view as? SwipingTableView) else {return .nothing}
                
                
                var direction = direction
                
                switch direction {
                case let .left(state):
                  
                    if view.containerX < 0 && abs(view.containerX) > view.rightSwipingWidth / 2 {
                        direction = .right(state.withAlwaysSuccess())
                    } else if abs(view.containerX) < view.rightSwipingWidth / 2 && view.containerX < view.leftSwipingWidth / 2 {
                       direction = .left(state.withAlwaysFailed())
                    } else {
                        direction = .left(state.withAlwaysSuccess())
                    }
                case .right:
                    if view.containerX > 0 && view.containerX > view.leftSwipingWidth / 2 {
                        direction = .left(state.withAlwaysSuccess())
                    } else if abs(view.containerX) < view.rightSwipingWidth / 2 && view.containerX < view.leftSwipingWidth / 2 {
                        direction = .right(state.withAlwaysFailed())
                    } else {
                        direction = .right(state.withAlwaysSuccess())
                    }
                default:
                    break
                }
                

                
                view.completeSwiping(direction: direction)
            }
            
          //  return .success()
            
            return .nothing
        }, with: self.genericView.tableView, identifier: "chat-list")
        
        if context.sharedContext.bindings.rootNavigation().stackCount == 1 {
            setHighlightEvents()
        }
    }
    
    private func setHighlightEvents() {
        
        removeHighlightEvents()
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            if let item = self?.genericView.tableView.highlightedItem(), item.index > 0 {
                self?.genericView.tableView.highlightPrev(turnDirection: false)
                while self?.genericView.tableView.highlightedItem() is PopularPeersRowItem || self?.genericView.tableView.highlightedItem() is SeparatorRowItem {
                    self?.genericView.tableView.highlightNext(turnDirection: false)
                }
            }
            return .invoked
        }, with: self, for: .UpArrow, priority: .low)
        
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.genericView.tableView.highlightNext(turnDirection: false)
            
            while self?.genericView.tableView.highlightedItem() is PopularPeersRowItem || self?.genericView.tableView.highlightedItem() is SeparatorRowItem {
                self?.genericView.tableView.highlightNext(turnDirection: false)
            }
            
            return .invoked
        }, with: self, for: .DownArrow, priority: .low)
        
    }
    
    private func removeHighlightEvents() {
        genericView.tableView.cancelHighlight()
        self.window?.remove(object: self, for: .DownArrow, forceCheckFlags: true)
        self.window?.remove(object: self, for: .UpArrow, forceCheckFlags: true)
    }
    
    private func removeSwipingStateIfNeeded(_ ignoreId: PeerId?) {
        genericView.tableView.enumerateItems { item -> Bool in
            if let item = item as? ChatListRowItem, item.peerId != ignoreId {
                (item.view as? ChatListRowView)?.endSwipingState = nil
            }
            return true
        }
    }
    
    func openChat(_ index: Int) {
        if genericView.tableView.count > index {
            _ = genericView.tableView.select(item: genericView.tableView.item(at: index), notify: true, byClick: true)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
        window?.removeAllHandlers(for: genericView.tableView)
    }
    
    override func update(with state: ViewControllerState) {
        super.update(with: state)
        switch state {
        case .Edit:
            stateValue.set(.deletable(onRemove: { [weak self] chatLocation in
                if let peerId = chatLocation.peerId {
                    self?.removePeerIdGroup(peerId)
                }
            }, deletable: true))
        default:
            stateValue.set(.plain)
        }
    }
    
    private func removePeerIdGroup(_ peerId: PeerId) {
        removePeerIdGroupDisposable.set(updatePeerGroupIdInteractively(postbox: context.account.postbox, peerId: peerId, groupId: nil).start())
    }
    
    deinit {
        removePeerIdGroupDisposable.dispose()
        disposable.dispose()
        scrollDisposable.dispose()
        reorderDisposable.dispose()
        globalPeerDisposable.dispose()
    }
    
    
    override var enableBack: Bool {
        return mode.groupId != nil
    }
    
    override var defaultBarTitle: String {
        if let _ = mode.groupId {
            return L10n.chatListFeeds
        }
        return super.defaultBarTitle
    }

    override func escapeKeyAction() -> KeyHandlerResult {
        if let _ = mode.groupId {
            return .rejected
        }
        return super.escapeKeyAction()
    }
    
    init(_ context: AccountContext, modal:Bool = false, groupId: PeerGroupId? = nil) {
        super.init(context, followGlobal:!modal, mode: groupId != nil ? .feedChannels(groupId!) : .plain)
    }

    override func selectionWillChange(row:Int, item:TableRowItem) -> Bool {
        if  let item = item as? ChatListRowItem, let peer = item.peer, let modalAction = navigationController?.modalAction {
            if !modalAction.isInvokable(for: peer) {
                modalAction.alertError(for: peer, with:mainWindow)
                return false
            }
            modalAction.afterInvoke()
            
            if let modalAction = modalAction as? FWDNavigationAction {
                if item.peerId == context.peerId {
                    _ = Sender.forwardMessages(messageIds: modalAction.messages.map{$0.id}, context: context, peerId: context.peerId).start()
                    _ = showModalSuccess(for: mainWindow, icon: theme.icons.successModalProgress, delay: 1.0).start()
                    navigationController?.removeModalAction()
                    return false
                }
            }
            
        }
        return true
    }
    
    override  func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
        if let item = item as? ChatListRowItem, let navigation = navigationController {
            if !isNew, let controller = navigation.controller as? ChatController {
                if let modalAction = navigation.modalAction {
                    navigation.controller.invokeNavigation(action: modalAction)
                }
                controller.clearReplyStack()
                controller.scrollup()
            } else {
                open(with: item.chatLocation, initialAction: item.pinnedType == .ad && FastSettings.showAdAlert ? .ad : nil, addition: mode.groupId != nil)
            }
        }
    }
  
}

