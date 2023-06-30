//
//  ContactsController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 29/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore


private enum ContactsControllerEntryId: Hashable {
    case peerId(Int64)
    case addContact
    case space
    case story(Int64)
    case separator(Int32)
    func hash(into hasher: inout Hasher) {
        switch self {
        case let .story(peerId):
            hasher.combine(0)
            hasher.combine(peerId)
        case .addContact:
            hasher.combine(1)
        case let .peerId(peerId):
            hasher.combine(2)
            hasher.combine(peerId)
        case let .separator(index):
            hasher.combine(3)
            hasher.combine(index)
        case .space:
            hasher.combine(4)
        }
    }
    
}


private enum ContactsEntry: Comparable, Identifiable {
    case space
    case separator(String, Int32)
    case story(EngineStorySubscriptions.Item, Int32)
    case peer(Peer, PeerPresence?, Int32, EngineStorySubscriptions.Item?)
    case addContact
    var stableId: ContactsControllerEntryId {
        switch self {
        case let .story(item, _):
            return .story(item.peer.id.toInt64())
        case .addContact:
            return .addContact
        case .space:
            return .space
        case let .peer(peer,_, _, _):
            return .peerId(peer.id.toInt64())
        case let .separator(_, index):
            return .separator(index)
        }
    }
    
    var index: Int32 {
        switch self {
        case let .story(_, index):
            return index
        case .space:
            return -2
        case .addContact:
            return -1
        case let .peer(_, _, index, _):
            return index
        case let .separator(_, index):
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
    case .space:
        if case .space = rhs {
            return true
        } else {
            return false
        }
    case let .story(item, index):
        if case .story(item, index) = rhs {
            return true
        } else {
            return false
        }
    case let .separator(text, index):
        if case .separator(text, index) = rhs {
            return true
        } else {
            return false
        }
    case let .peer(lhsPeer, lhsPresence, lhsIndex, lhsStory):
        switch rhs {
        case let .peer(rhsPeer, rhsPresence, rhsIndex, rhsStory):
            if !lhsPeer.isEqual(rhsPeer) {
                return false
            }
            if lhsIndex != rhsIndex {
                return false
            }
            if lhsStory != rhsStory {
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


private func entriesForView(_ view: EngineContactList, storyList: EngineStorySubscriptions?, accountPeer: Peer?) -> [ContactsEntry] {
    var entries: [ContactsEntry] = []
    
    entries.append(.space)
    
    if let accountPeer = accountPeer {
        
        var peerIds: Set<PeerId> = Set()
        let orderedPeers = view.peers.map { $0._asPeer() }.sorted(by: { lhsPeer, rhsPeer in
            let lhsPresence = view.presences[lhsPeer.id]
            let rhsPresence = view.presences[rhsPeer.id]
            if let lhsPresence = lhsPresence?._asPresence() as? TelegramUserPresence, let rhsPresence = rhsPresence?._asPresence() as? TelegramUserPresence {
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
        
        //entries.append(.addContact)
        var index: Int32 = 0
        if let storyList = storyList {
            let storyItems = storyList.items
            if !storyItems.isEmpty {
                entries.append(.separator("HIDDEN STORIES", index))
                index += 1
                for item in storyItems {
                    entries.append(.story(item, index))
                  //  index += 1
                }
                
                if !orderedPeers.isEmpty {
                    entries.append(.separator("CONTACTS", index))
                  //  index += 1
                }
            }
        }
        
    
        
        for peer in orderedPeers {
            if !peer.isEqual(accountPeer), !peerIds.contains(peer.id) {
                entries.append(.peer(peer, view.presences[peer.id]?._asPresence(), index, storyList?.items.first(where: { $0.peer.id == peer.id })))
                peerIds.insert(peer.id)
                index += 1
            }
        }
        
    }
    
    return entries
}

private final class ContactsArguments {
    let addContact:()->Void
    let openStory:(StoryInitialIndex?, Bool)->Void
    init(addContact:@escaping()->Void, openStory:@escaping(StoryInitialIndex?, Bool)->Void) {
        self.addContact = addContact
        self.openStory = openStory
    }
}

fileprivate func prepareEntries(from:[AppearanceWrapperEntry<ContactsEntry>]?, to:[AppearanceWrapperEntry<ContactsEntry>], context: AccountContext, initialSize:NSSize, arguments: ContactsArguments, animated:Bool) -> Signal<TableUpdateTransition, NoError> {
    
    return Signal { subscriber in
    
        
        func makeItem(_ entry: ContactsEntry) -> TableRowItem {
            let item:TableRowItem
            
            switch entry {
            case let .peer(peer, presence, _, story):
                var color:NSColor = theme.colors.grayText
                var string:String = strings().peerStatusRecently
                if let presence = presence as? TelegramUserPresence {
                    let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                    (string, _, color) = stringAndActivityForUserPresence(presence, timeDifference: context.timeDifference, relativeTo: Int32(timestamp))
                }
                item = ShortPeerRowItem(initialSize, peer: peer, account: context.account, context: context, stableId: entry.stableId,statusStyle: ControlStyle(foregroundColor:color), status: string, borderType: [.Right], highlightVerified: true, story: nil, openStory: { initialId in
                    arguments.openStory(initialId, true)
                })
            case .addContact:
                item = AddContactTableItem(initialSize, stableId: entry.stableId, addContact: {
                    arguments.addContact()
                })
            case .space:
                item = GeneralRowItem(initialSize, height: 90, stableId: entry.stableId)
            case let .story(story, _):
                let string = "\(story.storyCount) stories"
                item = ShortPeerRowItem(initialSize, peer: story.peer._asPeer(), account: context.account, context: context, stableId: entry.stableId, statusStyle: ControlStyle(foregroundColor: theme.colors.grayText), status: string, borderType: [.Right], contextMenuItems: {
                    
                    var items: [ContextMenuItem] = []
                    
                    items.append(.init("Unhide", handler: {
                        context.engine.peers.updatePeerStoriesHidden(id: story.peer.id, isHidden: false)
                        showModalText(for: context.window, text: "Stories from \(story.peer._asPeer().compactDisplayTitle) will now be shown in Chats, not Contacts.")
                    }, itemImage: MenuAnimation.menu_show_message.value))
                    
                    return .single(items)
                }, highlightVerified: true, story: story, openStory: { initialId in
                    arguments.openStory(initialId, true)
                })
            case let .separator(text, _):
                item = SeparatorRowItem(initialSize, entry.stableId, string: text)
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
            showModal(with: AddContactModalController(context), for: context.window)
        }, openStory: { initialId, singlePeer in
            StoryModalController.ShowStories(context: context, includeHidden: true, initialId: initialId, singlePeer: singlePeer)
        })
        
        
        let contacts = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Contacts.List(includePresences: true))
        
        let accountPeer = context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: context.peerId)
        ) |> map { $0?._asPeer() }
        
        let storyState: Signal<EngineStorySubscriptions?, NoError>
        if let storyList = storyList {
            storyState = storyList |> map(Optional.init)
        } else {
            storyState = .single(nil)
        }
        
        let transition = combineLatest(queue: prepareQueue, contacts, accountPeer, appearanceSignal, storyState)
            |> mapToQueue { view, accountPeer, appearance, storyList -> Signal<TableUpdateTransition, NoError> in
                let first:Bool = !first.swap(true)
                let entries = entriesForView(view, storyList: storyList, accountPeer: accountPeer).map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})

                return prepareEntries(from: previousEntries.swap(entries), to: entries, context: context, initialSize: initialSize.modify({$0}), arguments: arguments, animated: !first) |> runOn(first ? .mainQueue() : prepareQueue)

            }
        |> deliverOnMainQueue
        
        disposable.set(transition.start(next: { [weak self] transition in
            self?.genericView.tableView.merge(with: transition)
            self?.readyOnce()
            self?.afterTransaction(transition)
        }))
        
    }
    
    override func afterTransaction(_ transition: TableUpdateTransition) {
        super.afterTransaction(transition)
        self.updateLocalizationAndTheme(theme: theme)
    }
    
    override func scrollup(force: Bool = false) {
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
        super.init(context, isContacts: true, searchOptions: [.chats])
    }
    
    override func changeSelection(_ location: ChatLocation?, globalForumId: PeerId?) {
        if let location = location {
            switch location {
            case let .peer(peerId):
                genericView.tableView.changeSelection(stableId: ContactsControllerEntryId.peerId(peerId.toInt64()))
            case .thread:
                break
            }
        } else {
            genericView.tableView.cancelSelection()
        }
    }
    
    override func selectionWillChange(row:Int, item:TableRowItem, byClick: Bool) -> Bool {
        
        if let item = item as? ShortPeerRowItem, let id = item.stableId.base as? ContactsControllerEntryId {
            switch id {
            case .story:
                item.openPeerStory()
                return false
            default:
                break
            }
        }
        
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
        
        if let item = item as? ShortPeerRowItem {
            
            let navigation = context.bindings.rootNavigation()
            if !isNew {
                if let modalAction = navigation.modalAction {
                    navigation.controller.invokeNavigation(action: modalAction)
                }
            } else {
                
                let context = self.context
                
                _ = (context.globalPeerHandler.get() |> take(1)).start(next: { location in
                    context.globalPeerHandler.set(.single(location))
                })
                
                let chat:ChatController = ChatController(context: self.context, chatLocation: .peer(item.peer.id))
                navigation.push(chat)
                
            }
        }
    }
    
}
