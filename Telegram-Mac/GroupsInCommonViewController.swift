//
//  GroupsInCommonViewController.swift
//  Telegram
//
//  Created by keepcoder on 03/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

final class GroupsInCommonArguments {
    let context: AccountContext
    let open:(PeerId)->Void
    init(context: AccountContext, open: @escaping(PeerId) -> Void) {
        self.open = open
        self.context = context
    }
}

private enum GroupsInCommonEntry : Comparable, Identifiable {
    case empty(Bool)
    case peer(Int, Peer)
    case section
    
    var stableId: AnyHashable {
        switch self {
        case .empty:
            return -1
        case .section:
            return 0
        case let .peer(_, peer):
            return peer.id.hashValue
        }
    }
    
    var index:Int {
        switch self {
        case .empty:
            return -1
        case .section:
            return 0
        case let .peer(index, _):
            return index + 10
        }
    }
    
    func item(arguments: GroupsInCommonArguments, initialSize:NSSize) -> TableRowItem {
        switch self {
        case let .empty(loading):
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: loading, text: tr(L10n.groupsInCommonEmpty))
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId, type: .none)
        case let .peer(_, peer):
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, stableId: stableId, inset:NSEdgeInsets(left:30.0,right:30.0), action: {
                arguments.open(peer.id)
            })
        }
    }
}

private func ==(lhs:GroupsInCommonEntry, rhs: GroupsInCommonEntry) -> Bool {
    switch lhs {
    case let .empty(loading):
        if case .empty(loading) = rhs {
            return true
        } else {
            return false
        }
    case .section:
        if case .section = rhs {
            return true
        } else {
            return false
        }
    case let .peer(lhsIndex, lhsPeer):
        if case let .peer(rhsIndex, rhsPeer) = rhs {
            return lhsIndex == rhsIndex && lhsPeer.isEqual(rhsPeer)
        } else {
            return false
        }
    }
}

private func groupsInCommonEntries(_ peers:[Peer], loading:Bool) -> [GroupsInCommonEntry] {
    if peers.isEmpty {
        return [.empty(loading)]
    } else {
        var entries:[GroupsInCommonEntry] = []
        entries.append(.section)
        var index:Int = 0
        for peer in peers {
            entries.append(.peer(index, peer))
            index += 1
        }
        return entries
    }
}

private func prepareTransition(left:[AppearanceWrapperEntry<GroupsInCommonEntry>], right:[AppearanceWrapperEntry<GroupsInCommonEntry>], arguments: GroupsInCommonArguments, initialSize: NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right, { entry -> TableRowItem in
        return entry.entry.item(arguments: arguments, initialSize: initialSize)
    })
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

private func <(lhs:GroupsInCommonEntry, rhs: GroupsInCommonEntry) -> Bool {
    return lhs.index < rhs.index
}

class GroupsInCommonViewController: TableViewController {
    private let peerId:PeerId
    init(_ context: AccountContext, peerId:PeerId) {
        self.peerId = peerId
        super.init(context)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context
        
        let arguments = GroupsInCommonArguments(context: context, open: { [weak self] peerId in
            if let strongSelf = self {
                strongSelf.navigationController?.push(ChatController(context: strongSelf.context, chatLocation: .peer(peerId)))
            }
        })
        
        let previous:Atomic<[AppearanceWrapperEntry<GroupsInCommonEntry>]> = Atomic(value: [])
        let initialSize = atomicSize
        let signal = combineLatest(Signal<([Peer], Bool), NoError>.single(([], true)), appearanceSignal |> take(1)) |> then(combineLatest(groupsInCommon(account: context.account, peerId: peerId) |> mapToSignal { peerIds -> Signal<([Peer], Bool), NoError> in
            return context.account.postbox.transaction { transaction -> ([Peer], Bool) in
                var peers:[Peer] = []
                for peerId in peerIds {
                    if let peer = transaction.getPeer(peerId) {
                        peers.append(peer)
                    }
                }
                return (peers, false)
            }
        }, appearanceSignal)) |> map { result -> TableUpdateTransition in
            let entries = groupsInCommonEntries(result.0.0, loading: result.0.1).map {AppearanceWrapperEntry(entry: $0, appearance: result.1)}
            
            return prepareTransition(left: previous.swap(entries), right: entries, arguments: arguments, initialSize: initialSize.modify {$0} )
        } |> deliverOnMainQueue

        self.genericView.merge(with: signal)
        
        readyOnce()
    }
    
}
