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



fileprivate func prepareEntries(from:[AppearanceWrapperEntry<ChatListEntry>]?, to:[AppearanceWrapperEntry<ChatListEntry>], account:Account, initialSize:NSSize, animated:Bool, scrollState:TableScrollState? = nil, onMainQueue: Bool = false, state: ChatListRowState) -> Signal<TableUpdateTransition,Void> {
    
    return Signal { subscriber in
        
        let (deleted,inserted,updated) = proccessEntries(from, right: to, { entry -> TableRowItem in
            
            switch entry.entry {
            case let .HoleEntry(hole):
                return ChatListHoleRowItem(initialSize, account, hole)
            case let .MessageEntry(index, message, readState, notifySettings,embeddedState, renderedPeer, summaryInfo):
                
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
        
        let previousState:Atomic<ChatListRowState> = Atomic(value: .plain)
        
        let list:Signal<TableUpdateTransition,Void> = (request.get() |> distinctUntilChanged |> mapToSignal { location -> Signal<TableUpdateTransition,Void> in
            
            var signal:Signal<(ChatListView,ViewUpdateType),Void>
            var scroll:TableScrollState? = nil
            switch(location) {
            case let .Initial(count, st):
                signal = account.viewTracker.tailChatListView(groupId: groupId, count: count)
                scroll = st
            case let .Index(index):
                signal = account.viewTracker.aroundChatListView(groupId: groupId, index: index, count: 100)
            }
            
             return combineLatest(signal, appearanceSignal |> deliverOnPrepareQueue, stateValue.get()
                |> deliverOnPrepareQueue) |> mapToQueue { value, appearance, state -> Signal<TableUpdateTransition, Void> in
                
                var animated: Bool = true
                let previous = first.swap((value.0.earlierIndex, value.0.laterIndex))
                    
                if previous.0 != value.0.earlierIndex || previous.1 != value.0.laterIndex {
                    scroll = nil
                    animated = false
                }
                _ = previousChatList.swap(value.0)
                    
                let stateWasUpdated = previousState.swap(state) != state
                
                    let entries = value.0.entries.map({AppearanceWrapperEntry(entry: $0, appearance: stateWasUpdated ? appearance.newAllocation : appearance)})
                
                return prepareEntries(from: previousEntries.swap(entries), to: entries, account: account, initialSize: initialSize.modify({$0}), animated: animated, scrollState: scroll, onMainQueue: onMainQueue.swap(false), state: state)
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
                    strongSelf.request.set(.single(.Index(messageIndex)))
                }
            }
        })
        
    }
    
    override func scrollup() {
        
        let view = previousChatList.modify({$0})
        if view?.laterIndex != nil {
            _ = first.swap(true)
            request.set(.single(.Initial(100, .up(true))))
        } else {
            genericView.tableView.scroll(to: .up(true))
        }
        
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
                open(with: item.chatLocation, addition: mode.groupId != nil)
            }
        }
    }
  
}

