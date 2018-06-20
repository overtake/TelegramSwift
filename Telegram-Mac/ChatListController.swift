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
        switch self {
        case let .HoleEntry(hole):
            return Int64(hole.index.id.id)
        default:
            return index.messageIndex.id.peerId.toInt64()
        }
    }
}



fileprivate func prepareEntries(from:[AppearanceWrapperEntry<ChatListEntry>]?, to:[AppearanceWrapperEntry<ChatListEntry>], adIndex: UInt16?, account:Account, initialSize:NSSize, animated:Bool, scrollState:TableScrollState? = nil, onMainQueue: Bool = false, state: ChatListRowState) -> Signal<TableUpdateTransition,Void> {
    
    return Signal { subscriber in
        
        let (deleted,inserted,updated) = proccessEntries(from, right: to, { entry -> TableRowItem in
            
            switch entry.entry {
            case let .HoleEntry(hole):
                return ChatListHoleRowItem(initialSize, account, hole)
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
                return ChatListRowItem(initialSize, account: account, message: message, readState:readState, notificationSettings: notifySettings, embeddedState: embeddedState, pinnedType: pinnedType, renderedPeer: renderedPeer, summaryInfo: summaryInfo, state: state)
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
                return ChatListRowItem(initialSize, account: account, pinnedType: pinnedType, groupId: groupId, message: message, peers: peers, unreadCounters: unreadCounters, state: state)
            }
            
        })
        let nState = scrollState ?? (animated ? .none(nil) : .saveVisible(.lower))
        let transition = TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated:animated, state: nState, animateVisibleOnly: false)
        
        
        subscriber.putNext(transition)
        subscriber.putCompletion()
        return EmptyDisposable
    } |> runOn(onMainQueue ? Queue.mainQueue() : prepareQueue)

}



class ChatListController : PeersListController {

    private let request = Promise<ChatListIndexRequest>()
    private let previousChatList:Atomic<ChatListView?> = Atomic(value: nil)
    private let first = Atomic(value:true)
    private let stateValue:ValuePromise<ChatListRowState> = ValuePromise(.plain)
    private let removePeerIdGroupDisposable = MetaDisposable()
    private let disposable = MetaDisposable()
    private let scrollDisposable = MetaDisposable()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let initialSize = self.atomicSize
        let account = self.account
        let previousChatList = self.previousChatList
        let first = Atomic<(ChatListIndex?, ChatListIndex?)>(value: (nil, nil))
        let groupId = self.mode.groupId
        let onMainQueue:Atomic<Bool> = Atomic(value: true)
        let previousEntries:Atomic<[AppearanceWrapperEntry<ChatListEntry>]?> = Atomic(value: nil)
        let stateValue = self.stateValue
        let animated: Atomic<Bool> = Atomic(value: true)

        let previousState:Atomic<ChatListRowState> = Atomic(value: .plain)
        
        let list:Signal<TableUpdateTransition,Void> = (request.get() |> distinctUntilChanged |> mapToSignal { location -> Signal<TableUpdateTransition,Void> in
            
            var signal:Signal<(ChatListView,ViewUpdateType),Void>
            var scroll:TableScrollState? = nil
            var removeNextAnimation: Bool = false
            switch location {
            case let .Initial(count, st):
                signal = account.viewTracker.tailChatListView(groupId: groupId, count: count)
                scroll = st
            case let .Index(index, st):
                signal = account.viewTracker.aroundChatListView(groupId: groupId, index: index, count: 100)
                scroll = st
                removeNextAnimation = st != nil
            }
            
             return combineLatest(signal |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue, stateValue.get()
                |> deliverOnPrepareQueue) |> mapToQueue { value, appearance, state -> Signal<TableUpdateTransition, Void> in
                
                    let previous = first.swap((value.0.earlierIndex, value.0.laterIndex))
                        
                    if (previous.0 != value.0.earlierIndex || previous.1 != value.0.laterIndex) && !removeNextAnimation {
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
                    
                    let entries = prepare.map({AppearanceWrapperEntry(entry: $0, appearance: stateWasUpdated ? appearance.newAllocation : appearance)})
                
                    return prepareEntries(from: previousEntries.swap(entries), to: entries, adIndex: value.0.additionalItemEntries.first != nil ? pinnedIndex : nil, account: account, initialSize: initialSize.modify({$0}), animated: animated.swap(true), scrollState: scroll, onMainQueue: onMainQueue.swap(false), state: state)
            }
            
        })
        |> deliverOnMainQueue
        
        disposable.set(list.start(next: { [weak self] transition in
            guard let `self` = self else {return}
            self.genericView.tableView.merge(with: transition)
            switch self.mode {
            case .feedChannels:
                if self.genericView.tableView.isEmpty {
                    self.navigationController?.close()
                }
            default:
                break
            }
        }))
        
        
        request.set(.single(.Initial(50, nil)))
        
        genericView.tableView.addScroll(listener: TableScrollListener({ [weak self] scroll in

            guard let `self` = self, let view = previousChatList.modify({$0}) else {return}
            #if !STABLE && !APP_STORE
            if scroll.visibleRows.location == 0 && view.laterIndex != nil {
                self.lastScrolledIndex = nil
            }
            self.account.context.mainViewController.isUpChatList = scroll.visibleRows.location > 0 || view.laterIndex != nil
            #else
            self.account.context.mainViewController.isUpChatList = false
            #endif
           
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
        
//        return account.postbox.unreadMessageCountsView(items: items) |> map { view in
//            var totalCount:Int32 = 0
//            if let total = view.count(for: .total(value, .messages)) {
//                totalCount = total
//            }
//            
//            return (view, totalCount)
//        }
        
    }

    private var lastScrolledIndex: ChatListIndex? = nil
    
    
    override func scrollup() {
        
        let lastScrolledIndex = self.lastScrolledIndex
        
        let scrollToTop:()->Void = { [weak self] in
            guard let `self` = self else {return}

            let view = self.previousChatList.modify({$0})
            if view?.laterIndex != nil {
                _ = self.first.swap(true)
                self.request.set(.single(.Initial(100, .up(true))))
            } else {
                self.genericView.tableView.scroll(to: .up(true))
            }
        }
        
        #if !STABLE && !APP_STORE
        let view = self.previousChatList.modify({$0})
        
        
        if lastScrolledIndex == nil, view?.laterIndex != nil || genericView.tableView.scrollPosition().current.visibleRows.location > 0  {
            scrollToTop()
            return
        }
        let postbox = account.postbox
        
        let signal:Signal<ChatListIndex?, Void> = account.context.badgeFilter.get() |> mapToSignal { filter -> Signal<ChatListIndex?, Void> in
            return postbox.transaction { transaction -> ChatListIndex? in
                return transaction.getEarliestUnreadChatListIndex(filtered: filter == .filtered, earlierThan: lastScrolledIndex)
            }
            } |> deliverOnMainQueue
        
        scrollDisposable.set(signal.start(next: { [weak self] index in
            guard let `self` = self else {return}
            if let index = index {
                self.lastScrolledIndex = index
                self.request.set(.single(ChatListIndexRequest.Index(index, TableScrollState.center(id: ChatLocation.peer(index.messageIndex.id.peerId), innerId: nil, animated: true, focus: true, inset: 0))))
            } else {
                self.lastScrolledIndex = nil
                scrollToTop()
            }
        }))
        
        #else
            scrollToTop()
        #endif
        
       
        
        

        
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
        removePeerIdGroupDisposable.set(updatePeerGroupIdInteractively(postbox: account.postbox, peerId: peerId, groupId: nil).start())
    }
    
    deinit {
        removePeerIdGroupDisposable.dispose()
        disposable.dispose()
        scrollDisposable.dispose()
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
    
    init(_ account:Account, modal:Bool = false, groupId: PeerGroupId? = nil) {
        super.init(account, followGlobal:!modal, mode: groupId != nil ? .feedChannels(groupId!) : .plain)
    }

    override func selectionWillChange(row:Int, item:TableRowItem) -> Bool {
        if  let item = item as? ChatListRowItem, let peer = item.peer, let modalAction = navigationController?.modalAction {
            if !modalAction.isInvokable(for: peer) {
                modalAction.alertError(for: peer, with:mainWindow)
                return false
            }
            modalAction.afterInvoke()
            
            if let modalAction = modalAction as? FWDNavigationAction {
                if item.peerId == account.peerId {
                    _ = Sender.forwardMessages(messageIds: modalAction.messages.map{$0.id}, account: account, peerId: account.peerId).start()
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
            if !isNew && navigation.controller is ChatController {
                if let modalAction = navigation.modalAction {
                    navigation.controller.invokeNavigation(action: modalAction)
                }
                navigation.controller.scrollup()
            } else {
                open(with: item.chatLocation, initialAction: item.pinnedType == .ad && FastSettings.showAdAlert ? .ad : nil, addition: mode.groupId != nil)
            }
        }
    }
  
}

