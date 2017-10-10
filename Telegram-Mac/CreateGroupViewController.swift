//
//  CreateGroupViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit

fileprivate enum CreateGroupEntry : Comparable, Identifiable {
    case info
    case peer(Peer, Int, PeerPresence?)
    
    fileprivate var stableId:AnyHashable {
        switch self {
        case .info:
            return Int32(0)
        case let .peer(peer, _, _):
            return peer.id
        }
    }
    
    var index:Int {
        switch self {
        case .info:
            return 0
        case let .peer(_, index, _):
            return index + 1
        }
    }
}

fileprivate func ==(lhs:CreateGroupEntry, rhs:CreateGroupEntry) -> Bool {
    switch lhs {
    case .info:
        if case .info = rhs {
            return true
        } else {
            return false
        }
    case let .peer(lhsPeer,lhsIndex, lhsPresence):
        if case let .peer(rhsPeer,rhsIndex, rhsPresence) = rhs {
            if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                if !lhsPresence.isEqual(to: rhsPresence) {
                    return false
                }
         } else if (lhsPresence != nil) != (rhsPresence != nil) {
                return false
            }
            return lhsPeer.isEqual(rhsPeer) && lhsIndex == rhsIndex
        } else {
            return false
        }
    }
}

fileprivate func <(lhs:CreateGroupEntry, rhs:CreateGroupEntry) -> Bool {
    return lhs.index < rhs.index
}

struct CreateGroupResult {
    let title:String
    let peerIds:[PeerId]
}

fileprivate func prepareEntries(from:[AppearanceWrapperEntry<CreateGroupEntry>], to:[AppearanceWrapperEntry<CreateGroupEntry>], account:Account, initialSize:NSSize, animated:Bool) -> Signal<TableUpdateTransition,Void> {
    
    return Signal { subscriber in
        let (deleted,inserted,updated) = proccessEntriesWithoutReverse(from, right: to, { entry -> TableRowItem in
            
            switch entry.entry {
            case .info:
                return GroupNameRowItem(initialSize, stableId:entry.stableId, placeholder:tr(.createGroupNameHolder), limit:140)
            case let .peer(peer, _, presence):
                
                var color:NSColor = theme.colors.grayText
                var string:String = tr(.peerStatusRecently)
                if let presence = presence as? TelegramUserPresence {
                    let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                    (string, _, color) = stringAndActivityForUserPresence(presence, relativeTo: Int32(timestamp))
                }
                return  ShortPeerRowItem(initialSize, peer: peer, account:account, height:50, photoSize:NSMakeSize(36, 36), statusStyle: ControlStyle(foregroundColor: color), status: string, inset:NSEdgeInsets(left: 30, right:30))
            }
        })
        
        let transition = TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated:animated, state:.none(nil))
        
        subscriber.putNext(transition)
        subscriber.putCompletion()
        return EmptyDisposable
        
    }
    
}

private func createGroupEntries(_ view: MultiplePeersView, appearance: Appearance) -> [AppearanceWrapperEntry<CreateGroupEntry>] {
    
    var entries:[CreateGroupEntry] = [.info]
    var index:Int = 0
    for peer in view.peers.map({$1}) {
        entries.append(.peer(peer, index, view.presences[peer.id]))
        index += 1
    }
    return entries.map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
}


class CreateGroupViewController: ComposeViewController<CreateGroupResult, [PeerId], TableView> { // Title, photo path
    private let entries:Atomic<[AppearanceWrapperEntry<CreateGroupEntry>]> = Atomic(value:[])
    private let disposable:MetaDisposable = MetaDisposable()
    
    
    override func restart(with result: ComposeState<[PeerId]>) {
        super.restart(with: result)
        assert(isLoaded())
        let initialSize = self.atomicSize
        let table = self.genericView
        
        let account: Account = self.account
        let entries = self.entries
        
        let signal:Signal<TableUpdateTransition, Void> = combineLatest(account.postbox.multiplePeersView(result.result) |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue) |> mapToSignal { view, appearance in
            let list = createGroupEntries(view, appearance: appearance)
           
            return prepareEntries(from: entries.swap(list), to: list, account: account, initialSize: initialSize.modify({$0}), animated: true)
            
        } |> deliverOnMainQueue
        
        
        disposable.set(signal.start(next: { (transition) in
            table.merge(with: transition)
            table.reloadData()
        }))
    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override func firstResponder() -> NSResponder? {
        if let view = genericView.viewNecessary(at: 0) as? GroupNameRowView {
            return view.textView
        }
        return nil
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        return .rejected
    }
    
    deinit {
        disposable.dispose()
        _ = entries.swap([])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
    }
    
    override func executeNext() -> Void {
        if let previousResult = previousResult, let item = self.genericView.item(at: 0) as? GroupNameRowItem {
            onComplete.set(.single(CreateGroupResult(title: item.text, peerIds: previousResult.result)))
        }
    }
    
    
    
}
