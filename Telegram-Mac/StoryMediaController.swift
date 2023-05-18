//
//  StoryMediaController.swift
//  Telegram
//
//  Created by Mike Renoir on 18.05.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import SwiftSignalKit
import Postbox


private enum Entry : TableItemListNodeEntry {
    case month(index: MessageIndex, stableId: MessageIndex, peerId: PeerId, peerReference: PeerReference, items: [StoryListContext.Item], viewType: GeneralViewType)
    case date(index: MessageIndex)
    case section(index: MessageIndex)
        
    static func < (lhs: Entry, rhs: Entry) -> Bool {
        return lhs.index < rhs.index
    }

    func item(_ arguments: Arguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .month(_, stableId, peerId, peerReference, items, viewType):
            return StoryMonthRowItem(initialSize, stableId: stableId, context: arguments.context, peerId: peerId, peerReference: peerReference, items: items, viewType: viewType, openStory: arguments.openStory)
        case .date:
            return PeerMediaDateItem(initialSize, index: index, stableId: stableId)
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId, viewType: .separator)
        }
    }
    
    var stableId: MessageIndex {
        switch self {
        case let .month(_, stableId, _, _, _, _):
            return stableId
        default:
            return self.index
        }
    }
    
    var index: MessageIndex {
        switch self {
        case let .month(index, _, _, _, _, _):
            return index
        case let .date(index):
            return index
        case let .section(index):
            return index
        }
    }
}

private final class Arguments {
    let context: AccountContext
    let openStory:(StoryInitialIndex?)->Void
    init(context: AccountContext, openStory: @escaping(StoryInitialIndex?)->Void) {
        self.context = context
        self.openStory = openStory
    }
}

private struct State : Equatable {
    var stories:StoryListContext.PeerItemSet?
    var perRowCount: Int
    init(stories:StoryListContext.PeerItemSet?, perRowCount: Int) {
        self.stories = stories
        self.perRowCount = perRowCount
    }
}

private func entries(_ state: State, arguments: Arguments) -> [Entry] {
    var entries:[Entry] = []
    
    if let stories = state.stories, !stories.items.isEmpty, let peer = stories.peer, let peerReference = PeerReference(peer._asPeer()) {
        let timeDifference = Int32(arguments.context.timeDifference)
        var temp:[StoryListContext.Item] = []
        for i in 0 ..< stories.items.count {
            
            let item = stories.items[i]
            let peerId = stories.peerId
            temp.append(item)
            let next = i < stories.items.count - 1 ? stories.items[i + 1] : nil
            if let nextItem = next {
                let dateId = mediaDateId(for: item.timestamp - timeDifference)
                let nextDateId = mediaDateId(for: nextItem.timestamp - timeDifference)
                if dateId != nextDateId {
                    let index = MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: Int32(dateId))
                    var viewType: GeneralViewType = .modern(position: .single, insets: NSEdgeInsetsMake(0, 0, 0, 0))
                    if !entries.isEmpty {
                        entries.append(.section(index: index.peerLocalSuccessor()))
                        entries.append(.date(index: index))
                    } else {
                        viewType = .modern(position: .last, insets: NSEdgeInsetsMake(0, 0, 0, 0))
                    }
                    entries.append(.month(index: index.peerLocalPredecessor(), stableId: index.peerLocalPredecessor(), peerId: peer.id, peerReference: peerReference, items: temp, viewType: viewType))
                    temp.removeAll()
                }
            } else {
                let dateId = mediaDateId(for: item.timestamp - timeDifference)
                let index = MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: Int32(dateId))
                
                if !entries.isEmpty {
                    switch entries[entries.count - 1] {
                    case let .month(prevIndex, stableId, peerId, peerReference, items, viewType):
                        let prevDateId = mediaDateId(for: prevIndex.timestamp)
                        if prevDateId != dateId {
                            entries.append(.section(index: index.peerLocalSuccessor()))
                            entries.append(.date(index: index))
                            entries.append(.month(index: index.peerLocalPredecessor(), stableId: index.peerLocalPredecessor(), peerId: peerId, peerReference: peerReference, items: temp, viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 0, 0, 0))))
                        } else {
                            entries[entries.count - 1] = .month(index: prevIndex, stableId: stableId, peerId: peerId, peerReference: peerReference, items: items + temp, viewType: viewType)
                        }
                    default:
                        assertionFailure()
                    }
                } else {
                    entries.append(.month(index: index.peerLocalPredecessor(), stableId: index.peerLocalPredecessor(), peerId: peerId, peerReference: peerReference, items: temp, viewType: .modern(position: .last, insets: NSEdgeInsetsMake(0, 0, 0, 0))))

                }
            }
        }
    } else {
        entries.append(.section(index: MessageIndex.absoluteLowerBound()))
    }
    
    var updated:[Entry] = []
    
    
    
    var j: Int = 0
    for entry in entries {
        switch entry {
        case let .month(index, _, peerId, peerReference, items, _):
            let chunks = items.chunks(state.perRowCount)
            for (i, chunk) in chunks.enumerated() {
                let item = chunk[0]
                let stableId = MessageIndex(id: MessageId(peerId: index.id.peerId, namespace: 0, id: item.id), timestamp: item.timestamp)

                var viewType: GeneralViewType = bestGeneralViewType(chunks, for: i)
                if i == 0 && j == 0 {
                    viewType = chunks.count > 1 ? .innerItem : .lastItem
                }
                let updatedViewType: GeneralViewType = .modern(position: viewType.position, insets: NSEdgeInsetsMake(0, 0, 0, 0))
                updated.append(.month(index: index, stableId: stableId, peerId: peerId, peerReference: peerReference, items: chunk, viewType: updatedViewType))
            }
            j += 1
        case .date:
            updated.append(entry)
        case .section:
            updated.append(entry)
        }
    }

    return updated
}




fileprivate func prepareTransition(left:[AppearanceWrapperEntry<Entry>], right: [AppearanceWrapperEntry<Entry>], animated: Bool, initialSize:NSSize, arguments: Arguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: animated, state: .none(nil))
}



final class StoryMediaController : TableViewController {
    
    private let actionsDisposable = DisposableSet()
    private let peerId: EnginePeer.Id
    
    private var statePromise: ValuePromise<State> = ValuePromise(ignoreRepeated: true)
    private var stateValue: Atomic<State> = Atomic(value: State(stories: nil, perRowCount: 4))
    
    private func updateState(_ f:(State) -> State) {
        statePromise.set(stateValue.modify (f))
    }

    
    init(context: AccountContext, peerId: EnginePeer.Id) {
        self.peerId = peerId
        super.init(context)
        context.stories.loadPeer(id: peerId)
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        
        updateState { current in
            var current = current
            current.perRowCount = self.perRowCount
            return current
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        let peerId = self.peerId
        let initialSize = self.atomicSize

                
        let arguments = Arguments(context: context, openStory: { initialId in
            StoryModalController.ShowStories(context: context, stories: context.stories, initialId: initialId)
        })
        
        let stateSignal = context.stories.state |> deliverOnMainQueue
        actionsDisposable.add(stateSignal.start(next: { [weak self] state in
            self?.updateState { current in
                var current = current
                current.stories = state.itemSets.first(where: { $0.peerId == peerId })
                return current
            }
        }))
        
        
        let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
            return entries(state, arguments: arguments)
        }
        
        let previous: Atomic<[AppearanceWrapperEntry<Entry>]> = Atomic(value: [])
        let first = Atomic(value: true)
        
        let transition = combineLatest(signal, appearanceSignal) |> map { entries, appearance in
            let entries = entries.map { AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return prepareTransition(left: previous.swap(entries), right: entries, animated: !first.swap(false), initialSize: initialSize.with { $0 }, arguments: arguments)
        } |> deliverOnMainQueue
        
        actionsDisposable.add(transition.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
        
    }
    
    private var perRowCount: Int {
        var rowCount:Int = 4
        var perWidth: CGFloat = 0
        let blockWidth = min(600, atomicSize.with { $0.width })
        while true {
            let maximum = blockWidth - CGFloat(rowCount * 2)
            perWidth = maximum / CGFloat(rowCount)
            if perWidth >= 90 {
                break
            } else {
                rowCount -= 1
            }
        }
        return rowCount
    }
}
