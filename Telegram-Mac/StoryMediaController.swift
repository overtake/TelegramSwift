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
    case month(index: MessageIndex, stableId: MessageIndex, peerId: PeerId, peerReference: PeerReference, items: [EngineStoryItem], viewType: GeneralViewType)
    case date(index: MessageIndex)
    case section(index: MessageIndex)
    case emptySelf(index: MessageIndex, viewType: GeneralViewType)
    static func < (lhs: Entry, rhs: Entry) -> Bool {
        return lhs.index < rhs.index
    }

    func item(_ arguments: Arguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .month(_, stableId, peerId, peerReference, items, viewType):
            return StoryMonthRowItem(initialSize, stableId: stableId, context: arguments.context, standalone: arguments.standalone, peerId: peerId, peerReference: peerReference, items: items, viewType: viewType, openStory: arguments.openStory)
        case let .emptySelf(index, viewType):
            return StoryMyEmptyRowItem(initialSize, stableId: index, context: arguments.context, viewType: viewType, showArchive: arguments.showArchive)
        case .date:
            return PeerMediaDateItem(initialSize, index: index, stableId: stableId, inset: !arguments.standalone ? .init() : NSEdgeInsets(left: 30, right: 30))
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
        case let .emptySelf(index, _):
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
    let standalone: Bool
    let openStory:(StoryInitialIndex?)->Void
    let showArchive:()->Void
    init(context: AccountContext, standalone: Bool, openStory: @escaping(StoryInitialIndex?)->Void, showArchive:@escaping()->Void) {
        self.context = context
        self.standalone = standalone
        self.openStory = openStory
        self.showArchive = showArchive
    }
}

private struct State : Equatable {
    var state:PeerStoryListContext.State?
    var perRowCount: Int
    init(state: PeerStoryListContext.State?, perRowCount: Int) {
        self.state = state
        self.perRowCount = perRowCount
    }
}

private func entries(_ state: State, arguments: Arguments) -> [Entry] {
    var entries:[Entry] = []
    
    let standalone = arguments.standalone


    if let state = state.state, !state.items.isEmpty, let peerReference = state.peerReference {
        let timeDifference = Int32(arguments.context.timeDifference)
        var temp:[EngineStoryItem] = []

        for i in 0 ..< state.items.count {

            let item = state.items[i]
            let peerId = peerReference.id
            temp.append(item)
            let next = i < state.items.count - 1 ? state.items[i + 1] : nil
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
                    entries.append(.month(index: index.peerLocalPredecessor(), stableId: index.peerLocalPredecessor(), peerId: peerId, peerReference: peerReference, items: temp, viewType: viewType))
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

        if standalone {
            var index = MessageIndex.absoluteLowerBound()
            entries.insert(.section(index: index), at: 0)
        }

    } else {
        var index = MessageIndex.absoluteLowerBound()
        entries.append(.section(index: index))
        index = index.globalSuccessor()
        if state.state?.peerReference?.id == arguments.context.peerId {
            entries.append(.emptySelf(index: index, viewType: .singleItem))
        }
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
                if i == 0 && j == 0, !standalone {
                    viewType = chunks.count > 1 ? .innerItem : .lastItem
                }
                let updatedViewType: GeneralViewType = .modern(position: viewType.position, insets: NSEdgeInsetsMake(0, 0, 0, 0))
                updated.append(.month(index: index, stableId: stableId, peerId: peerId, peerReference: peerReference, items: chunk, viewType: updatedViewType))
            }
            j += 1
        case .date:
            updated.append(entry)
        case .emptySelf:
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
    private let standalone: Bool
    private let isArchived: Bool
    private var statePromise: ValuePromise<State> = ValuePromise(ignoreRepeated: true)
    private var stateValue: Atomic<State> = Atomic(value: State(state: nil, perRowCount: 4))
    private let listContext: PeerStoryListContext
    private let archiveContext: PeerStoryListContext?

    private func updateState(_ f:(State) -> State) {
        statePromise.set(stateValue.modify (f))
    }

    override func getRightBarViewOnce() -> BarView {
        if !isArchived {
            let bar = ImageBarView(controller: self, theme.icons.chatActions)
            bar.button.contextMenu = { [weak self] in
                let menu = ContextMenu()
                menu.addItem(ContextMenuItem("Archive", handler: {
                    self?.openArchive()
                }, itemImage: MenuAnimation.menu_archive.value))
                return menu
            }
            return bar
        } else {
            return super.getRightBarViewOnce()
        }
    }
    
    private func openArchive() {
        if let archiveContext = self.archiveContext {
            self.navigationController?.push(StoryMediaController(context: context, peerId: peerId, listContext: archiveContext, standalone: self.standalone, isArchived: true))
        }
    }
    
    init(context: AccountContext, peerId: EnginePeer.Id, listContext: PeerStoryListContext, standalone: Bool = false, isArchived: Bool = false) {
        self.peerId = peerId
        self.isArchived = isArchived
        self.standalone = standalone
        self.listContext = listContext
        if !isArchived {
            self.archiveContext = .init(account: context.account, peerId: peerId, isArchived: true)
        } else {
            self.archiveContext = nil
        }
        super.init(context)
        self.bar = standalone ? .init(height: 50) : .init(height: 0)
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        
        updateState { current in
            var current = current
            current.perRowCount = self.perRowCount
            return current
        }
    }
    
    override var removeAfterDisapper: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        genericView.set(stickClass: PeerMediaDateItem.self, handler: { _ in
            
        })
        
        let context = self.context
        let peerId = self.peerId
        let initialSize = self.atomicSize
        
        genericView.setScrollHandler({ [weak self] _ in
            if let list = self?.listContext {
                list.loadMore()
            }
        })

                
        self.setCenterTitle(isArchived ? "Archive" : peerId == context.peerId ? "My Stories" : "")

        
        let arguments = Arguments(context: context, standalone: standalone, openStory: { [weak self] initialId in
            if let list = self?.listContext {
                StoryModalController.ShowPeerStory(context: context, listContext: list, peerId: peerId, initialId: initialId)
            }
        }, showArchive: { [weak self] in
            self?.openArchive()
        })

        let stateSignal = listContext.state |> deliverOnMainQueue
        actionsDisposable.add(stateSignal.start(next: { [weak self] state in
            self?.updateState { current in
                var current = current
                current.state = state
                return current
            }
        }))


        let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
            return entries(state, arguments: arguments)
        }

        let previous: Atomic<[AppearanceWrapperEntry<Entry>]> = Atomic(value: [])
        let first = Atomic(value: true)

        let transition: Signal<TableUpdateTransition, NoError> = combineLatest(signal, appearanceSignal) |> map { entries, appearance -> TableUpdateTransition in
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
