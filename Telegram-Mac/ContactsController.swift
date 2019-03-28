//
//  ContactsController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 29/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac

private enum ContactsControllerEntryId: Hashable {
    case peerId(Int64)
    case addContact
    var hashValue: Int {
        switch self {
        case .addContact:
            return 0
        case let .peerId(peerId):
            return peerId.hashValue
            
        }
    }
}


private enum ContactsEntry: Comparable, Identifiable {
    case peer(Peer, PeerPresence?, Int32)
    case addContact
    var stableId: ContactsControllerEntryId {
        switch self {
        case .addContact:
            return .addContact
        case let .peer(peer,_, _):
            return .peerId(peer.id.toInt64())
        }
    }
    
    var index: Int32 {
        switch self {
        case .addContact:
            return -1
        case let .peer(_, _, index):
            return index
        }
    }
}


private func ==(lhs: ContactsEntry, rhs: ContactsEntry) -> Bool {
    switch lhs {
    case .addContact:
        if case .addContact = rhs {
            return true
        } else {
            return false
        }
    case let .peer(lhsPeer, lhsPresence, lhsIndex):
        switch rhs {
        case let .peer(rhsPeer, rhsPresence, rhsIndex):
            if !lhsPeer.isEqual(rhsPeer) {
                return false
            }
            if lhsIndex != rhsIndex {
                return false
            }
            if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                if !lhsPresence.isEqual(to: rhsPresence) {
                    return false
                }
            } else if (lhsPresence != nil) != (rhsPresence != nil) {
                return false
            }
            return true
        default:
            return false
        }
    }
}

private func <(lhs: ContactsEntry, rhs: ContactsEntry) -> Bool {
   return lhs.index < rhs.index
}


private func entriesForView(_ view: ContactPeersView) -> [ContactsEntry] {
    var entries: [ContactsEntry] = []
    if let accountPeer = view.accountPeer {
        
        entries.append(.addContact)
        
        var peerIds: Set<PeerId> = Set()
        var index: Int32 = 0
        
        let orderedPeers = view.peers.sorted(by: { lhsPeer, rhsPeer in
            let lhsPresence = view.peerPresences[lhsPeer.id]
            let rhsPresence = view.peerPresences[rhsPeer.id]
            if let lhsPresence = lhsPresence as? TelegramUserPresence, let rhsPresence = rhsPresence as? TelegramUserPresence {
                if lhsPresence.status < rhsPresence.status {
                    return false
                } else if lhsPresence.status > rhsPresence.status {
                    return true
                }
            } else if let _ = lhsPresence {
                return true
            } else if let _ = rhsPresence {
                return false
            }
            return lhsPeer.id < rhsPeer.id
        })
        
        for peer in orderedPeers {
            if !peer.isEqual(accountPeer), !peerIds.contains(peer.id) {
                entries.append(.peer(peer, view.peerPresences[peer.id], index))
                peerIds.insert(peer.id)
                index += 1
            }
        }
        
    }
    
    return entries
}

private final class ContactsArguments {
    let addContact:()->Void
    init(addContact:@escaping()->Void) {
        self.addContact = addContact
    }
}

fileprivate func prepareEntries(from:[AppearanceWrapperEntry<ContactsEntry>]?, to:[AppearanceWrapperEntry<ContactsEntry>], context: AccountContext, initialSize:NSSize, arguments: ContactsArguments, animated:Bool) -> Signal<TableUpdateTransition, NoError> {
    
    return Signal { subscriber in
    
        
        func makeItem(_ entry: ContactsEntry) -> TableRowItem {
            let item:TableRowItem
            
            switch entry {
            case let .peer(peer, presence, _):
                var color:NSColor = theme.colors.grayText
                var string:String = L10n.peerStatusRecently
                if let presence = presence as? TelegramUserPresence {
                    let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                    (string, _, color) = stringAndActivityForUserPresence(presence, timeDifference: context.timeDifference, relativeTo: Int32(timestamp))
                }
                item = ShortPeerRowItem(initialSize, peer: peer, account: context.account, stableId: entry.stableId,statusStyle: ControlStyle(foregroundColor:color), status: string, borderType: [.Right])
            case .addContact:
                item = AddContactTableItem(initialSize, stableId: entry.stableId, addContact: {
                    arguments.addContact()
                })
            }
            return item
        }
        
        var cancelled = false

        
        if Thread.isMainThread {
            var initialIndex:Int = 0
            var height:CGFloat = 0
            var firstInsertion:[(Int, TableRowItem)] = []
            let entries = Array(to)
            
            let index:Int = 0

            for i in index ..< entries.count {
                let item = makeItem(entries[i].entry)
                height += item.height
                firstInsertion.append((i, item))
                if initialSize.height < height {
                    break
                }
            }
            
            
            initialIndex = firstInsertion.count
            subscriber.putNext(TableUpdateTransition(deleted: [], inserted: firstInsertion, updated: [], state: .none(nil)))
            
            prepareQueue.async {
                if !cancelled {
                    
                    
                    var insertions:[(Int, TableRowItem)] = []
                    let updates:[(Int, TableRowItem)] = []

                    for i in initialIndex ..< entries.count {
                        let item:TableRowItem
                        item = makeItem(entries[i].entry)
                        insertions.append((i, item))
                    }
                    
            
                    subscriber.putNext(TableUpdateTransition(deleted: [], inserted: insertions, updated: updates, state: .none(nil)))
                    subscriber.putCompletion()
                }
            }
        } else {
            let (deleted,inserted,updated) = proccessEntriesWithoutReverse(from, right: to, { entry -> TableRowItem in
                return makeItem(entry.entry)
            })

            subscriber.putNext(TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated:animated, state: .none(nil)))
            subscriber.putCompletion()
        }
        
        return ActionDisposable {
            cancelled = true
        }
    }
    
}


class ContactsController: PeersListController {
    
    private var previousEntries:Atomic<[AppearanceWrapperEntry<ContactsEntry>]?> = Atomic(value:nil)
    private let index: PeerNameIndex = .lastNameFirst
    private let disposable = MetaDisposable()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func becomeFirstResponder() -> Bool? {
        return false
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundColor = theme.colors.background
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let context = self.context
        
        let previousEntries = self.previousEntries
        let initialSize = self.atomicSize
        let first:Atomic<Bool> = Atomic(value:false)
        
        let arguments = ContactsArguments(addContact: {
            showModal(with: AddContactModalController(context), for: mainWindow)
        })
        
        
        let transition = combineLatest(queue: prepareQueue, context.account.postbox.contactPeersView(accountPeerId: context.peerId, includePresences: true), appearanceSignal)
            |> mapToQueue { view, appearance -> Signal<TableUpdateTransition, NoError> in
                let first:Bool = !first.swap(true)
                let entries = entriesForView(view).map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})

                return prepareEntries(from: previousEntries.swap(entries), to: entries, context: context, initialSize: initialSize.modify({$0}), arguments: arguments, animated: !first) |> runOn(first ? .mainQueue() : prepareQueue)

            }
        |> deliverOnMainQueue
        
        disposable.set(transition.start(next: { [weak self] transition in
            self?.genericView.tableView.merge(with: transition)
            self?.readyOnce()
        }))
        
    }
    
    override func scrollup() {
        genericView.tableView.scroll(to: .up(true))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        _ = previousEntries.swap(nil)
        genericView.tableView.cancelSelection()
        genericView.tableView.removeAll()
        genericView.tableView.documentView?.removeAllSubviews()
        disposable.set(nil)
    }

    deinit {
        disposable.dispose()
    }
    
    init(_ context:AccountContext) {
        super.init(context, searchOptions: [.chats])
    }
    
    override func changeSelection(_ location: ChatLocation?) {
        if let location = location {
            switch location {
            case let .peer(peerId):
                genericView.tableView.changeSelection(stableId: ContactsControllerEntryId.peerId(peerId.toInt64()))
            default:
                break
            }
        } else {
            genericView.tableView.cancelSelection()
        }
    }
    
    override func selectionWillChange(row:Int, item:TableRowItem) -> Bool {
        if  let item = item as? ShortPeerRowItem, let modalAction = navigationController?.modalAction {
            if !modalAction.isInvokable(for: item.peer) {
                modalAction.alertError(for: item.peer, with:window!)
                return false
            }
            modalAction.afterInvoke()
        }
        
        return true
    }
    
    override func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
        
        if let item = item as? ShortPeerRowItem, let navigation = navigationController {
            
            if !isNew {
                if let modalAction = navigation.modalAction {
                    navigation.controller.invokeNavigation(action: modalAction)
                }
            } else {
                let chat:ChatController = ChatController(context: self.context, chatLocation: .peer(item.peer.id))
                navigation.push(chat)
                
            }
        }
    }
    
}
