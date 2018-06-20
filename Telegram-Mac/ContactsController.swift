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
    case vcard
    case separator
    case peerId(Int64)
    case addContact
    var hashValue: Int {
        switch self {
        case .vcard:
            return 1
        case .separator:
            return 2
        case .addContact:
            return 3
        case let .peerId(peerId):
            return peerId.hashValue
            
        }
    }
}

private func <(lhs: ContactsControllerEntryId, rhs: ContactsControllerEntryId) -> Bool {
    return lhs.hashValue < rhs.hashValue
}

private func ==(lhs: ContactsControllerEntryId, rhs: ContactsControllerEntryId) -> Bool {
    switch lhs {
    case .vcard:
        switch rhs {
        case .vcard:
            return true
        default:
            return false
        }
    case .separator:
        switch rhs {
        case .separator:
            return true
        default:
            return false
        }
    case .addContact:
        switch rhs {
        case .addContact:
            return true
        default:
            return false
        }
    case let .peerId(lhsId):
        switch rhs {
        case let .peerId(rhsId):
            return lhsId == rhsId
        default:
            return false
        }
    }
}

private enum ContactsEntry: Comparable, Identifiable {
    case vcard(Peer)
    case separator(String)
    case peer(Peer, PeerPresence?)
    case addContact
    var stableId: ContactsControllerEntryId {
        switch self {
        case .vcard:
            return .vcard
        case .separator:
            return .separator
        case .addContact:
            return .addContact
        case let .peer(peer,_):
            return .peerId(peer.id.toInt64())
        }
    }
}


private func ==(lhs: ContactsEntry, rhs: ContactsEntry) -> Bool {
    switch lhs {
  
    case let .vcard(lhsPeer):
        switch rhs {
        case let .vcard(rhsPeer):
            return lhsPeer.id == rhsPeer.id
        default:
            return false
        }
    case let .separator(ls):
        switch rhs {
        case let .separator(rs):
            return ls == rs
        default:
            return false
        }
    case .addContact:
        switch rhs {
        case .addContact:
            return true
        default:
            return false
        }
    case let .peer(lhsPeer, lhsPresence):
        switch rhs {
        case let .peer(rhsPeer, rhsPresence):
            if lhsPeer.id != rhsPeer.id {
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
    switch lhs {
    case .vcard(_):
        return false
    case .separator:
        switch rhs {
        case .vcard, .separator:
            return true
        case .peer:
            return false
        case .addContact:
            return false
        }
    case let .peer(lhsPeer, lhsPresence):
        switch rhs {
        case .separator, .vcard, .addContact:
            return true
        case let .peer(rhsPeer, rhsPresence):
            if let lhsPresence = lhsPresence as? TelegramUserPresence, let rhsPresence = rhsPresence as? TelegramUserPresence {
                if lhsPresence.status < rhsPresence.status {
                    return true
                } else if lhsPresence.status > rhsPresence.status {
                    return false
                }
            } else if let _ = lhsPresence {
                return false
            } else if let _ = rhsPresence {
                return true
            }
            return lhsPeer.id < rhsPeer.id
        }
    case .addContact:
        switch rhs {
        case .vcard, .separator, .addContact:
            return true
        case .peer:
            return false
        }
    }
}

private func entriesForView(_ view: ContactPeersView) -> [ContactsEntry] {
    var entries: [ContactsEntry] = []
    if let accountPeer = view.accountPeer {
        
        for peer in view.peers {
            if !peer.isEqual(accountPeer) {
                entries.append(.peer(peer,view.peerPresences[peer.id]))
            }
        }
        
        entries.append(.addContact)
        //entries.append(.separator(tr(L10n.contactsContacsSeparator)))
        //entries.append(.vcard(accountPeer))
        
        entries.sort()
        
    }
    
    return entries
}

private final class ContactsArguments {
    let addContact:()->Void
    init(addContact:@escaping()->Void) {
        self.addContact = addContact
    }
}

fileprivate func prepareEntries(from:[AppearanceWrapperEntry<ContactsEntry>]?, to:[AppearanceWrapperEntry<ContactsEntry>], account:Account, initialSize:NSSize, arguments: ContactsArguments, animated:Bool) -> Signal<TableUpdateTransition,Void> {
    
    return Signal { subscriber in
    
        let (deleted,inserted,updated) =  proccessEntries(from, right: to, { (entry) -> TableRowItem in
            
            var item:TableRowItem
            
            switch entry.entry {
            case let .vcard(peer):
                
                var status:String? = nil
                let phone = (peer as! TelegramUser).phone
                if let phone = phone {
                    status = formatPhoneNumber( phone )
                }
                
                item = ShortPeerRowItem(initialSize, peer: peer, account:account, height:60, photoSize:NSMakeSize(50,50), status: status, borderType: [.Right], drawCustomSeparator:false)
            case let .peer(peer, presence):
                
                var color:NSColor = theme.colors.grayText
                var string:String = tr(L10n.peerStatusRecently)
                if let presence = presence as? TelegramUserPresence {
                    let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                    (string, _, color) = stringAndActivityForUserPresence(presence, relativeTo: Int32(timestamp))
                }
                
                item = ShortPeerRowItem(initialSize, peer: peer, account:account,statusStyle: ControlStyle(foregroundColor:color), status: string, borderType: [.Right])
            case let .separator(str):
                item = SeparatorRowItem(initialSize, 1, string: str.uppercased())
            case .addContact:
                return AddContactTableItem(initialSize, stableId: entry.stableId, addContact: {
                    arguments.addContact()
                })
            }
            
            let _ = item.makeSize(initialSize.width)
            
            return item
            
            
        })
        
        subscriber.putNext(TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated:animated, state: .none(nil)))
        subscriber.putCompletion()
        
        return EmptyDisposable

    
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
    

    override func loadView() {
        super.loadView()
        backgroundColor = theme.colors.background
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        genericView.tableView.clipView.scroll(to: NSZeroPoint)

        let account = self.account
        
        let previousEntries = self.previousEntries
        let initialSize = self.atomicSize
        let first:Atomic<Bool> = Atomic(value:false)
        
        let arguments = ContactsArguments(addContact: {
            showModal(with: AddContactModalController(account: account), for: mainWindow)
        })
        
        let transition = combineLatest(account.postbox.contactPeersView(accountPeerId: account.peerId, includePresences: true) |> deliverOn(prepareQueue), appearanceSignal |> deliverOn(prepareQueue))
            |> mapToQueue { view, appearance -> Signal<TableUpdateTransition,Void> in
                let first:Bool = !first.swap(true)
                let entries = entriesForView(view).map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})

                return prepareEntries(from: previousEntries.swap(entries), to: entries, account: account, initialSize: initialSize.modify({$0}), arguments: arguments, animated: !first)

            }
        |> deliverOnMainQueue
        
        disposable.set(transition.start(next: { [weak self] transition in
            self?.genericView.tableView.merge(with: transition)
        }))
        
    }
    
    override func scrollup() {
        genericView.tableView.scroll(to: .up(true))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        _ = previousEntries.swap(nil)
        genericView.tableView.removeAll()
        disposable.set(nil)
    }

    deinit {
        disposable.dispose()
    }
    
    init(_ account:Account) {
        super.init(account, searchOptions: [.chats])
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
                let chat:ChatController = ChatController(account: self.account, chatLocation: .peer(item.peer.id))
                navigation.push(chat)
                
            }
        }
    }
    
}
