//
//  GroupsInCommonViewController.swift
//  Telegram
//
//  Created by keepcoder on 03/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

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
    case peer(Int, Int, Peer, GeneralViewType)
    case section(Int)
    
    var stableId: AnyHashable {
        switch self {
        case .empty:
            return -1
        case let .section(section):
            return section
        case let .peer(_, _, peer, _):
            return peer.id.hashValue
        }
    }
    
    var index:Int {
        switch self {
        case .empty:
            return -1
        case let .section(section):
            return (section * 1000) - section
        case let .peer(section, index, _, _):
            return (section * 1000) + index + 10
        }
    }
    
    func item(arguments: GroupsInCommonArguments, initialSize:NSSize) -> TableRowItem {
        switch self {
        case let .empty(loading):
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: loading, text: L10n.groupsInCommonEmpty, viewType: .singleItem)
        case .section:
            return GeneralRowItem(initialSize, height: 30, stableId: stableId, viewType: .separator)
        case let .peer(_, _, peer, viewType):
            return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, stableId: stableId, height: 46, photoSize: NSMakeSize(32, 32), inset: NSEdgeInsets(left: 30.0, right: 30.0), viewType: viewType, action: {
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
    case let .peer(sectionId, index, lhsPeer, viewType):
        if case .peer(sectionId, index, let rhsPeer, viewType) = rhs {
            return lhsPeer.isEqual(rhsPeer)
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
        entries.append(.section(0))
        var index:Int = 0
        for (i, peer) in peers.enumerated() {
            entries.append(.peer(1, index, peer, bestGeneralViewType(peers, for: i)))
            index += 1
        }
        entries.append(.section(1))
        return entries
    }
}

private func prepareTransition(left:[AppearanceWrapperEntry<GroupsInCommonEntry>], right:[AppearanceWrapperEntry<GroupsInCommonEntry>], arguments: GroupsInCommonArguments, initialSize: NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right, { entry -> TableRowItem in
        return entry.entry.item(arguments: arguments, initialSize: initialSize)
    })
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: false, grouping: false)
}

private func <(lhs:GroupsInCommonEntry, rhs: GroupsInCommonEntry) -> Bool {
    return lhs.index < rhs.index
}

class GroupsInCommonViewController: TableViewController {
    private let peerId:PeerId
    private let commonGroups:[Peer]
    init(_ context: AccountContext, peerId:PeerId, commonGroups: [Peer] = []) {
        self.peerId = peerId
        self.commonGroups = commonGroups
        super.init(context)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context
        
        genericView.alwaysOpenRowsOnMouseUp = true
        
        let arguments = GroupsInCommonArguments(context: context, open: { [weak self] peerId in
            if let strongSelf = self {
                strongSelf.navigationController?.push(ChatAdditionController(context: strongSelf.context, chatLocation: .peer(peerId)))
            }
        })
        
        let previous:Atomic<[AppearanceWrapperEntry<GroupsInCommonEntry>]> = Atomic(value: [])
        let initialSize = atomicSize
        let signal = combineLatest(Signal<([Peer], Bool), NoError>.single((commonGroups, commonGroups.isEmpty)), appearanceSignal |> take(1)) |> then(combineLatest(groupsInCommon(account: context.account, peerId: peerId) |> map { peers -> ([Peer], Bool) in
            return (peers, false)
        }, appearanceSignal)) |> map { result -> TableUpdateTransition in
            let entries = groupsInCommonEntries(result.0.0, loading: result.0.1).map {AppearanceWrapperEntry(entry: $0, appearance: result.1)}
            
            return prepareTransition(left: previous.swap(entries), right: entries, arguments: arguments, initialSize: initialSize.modify {$0} )
        } |> deliverOnMainQueue

        self.genericView.merge(with: signal)
        
        readyOnce()
    }
    
}
