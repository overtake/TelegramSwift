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
    case headerText(index: MessageIndex, stableId: MessageIndex, text: String, viewType: GeneralViewType)
    case month(index: MessageIndex, stableId: MessageIndex, peerId: PeerId, peerReference: PeerReference, items: [EngineStoryItem], selected: Set<StoryId>?, viewType: GeneralViewType)
    case date(index: MessageIndex)
    case section(index: MessageIndex)
    case emptySelf(index: MessageIndex, viewType: GeneralViewType)
    static func < (lhs: Entry, rhs: Entry) -> Bool {
        return lhs.index < rhs.index
    }

    func item(_ arguments: Arguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .headerText(_, stableId, text, viewType):
            return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: viewType, text: text, font: .normal(.text))
        case let .month(_, stableId, peerId, peerReference, items, selected, viewType):
            return StoryMonthRowItem(initialSize, stableId: stableId, context: arguments.context, standalone: arguments.standalone, peerId: peerId, peerReference: peerReference, items: items, selected: selected, viewType: viewType, openStory: arguments.openStory, toggleSelected: arguments.toggleSelected, menuItems: { story in
                var items: [ContextMenuItem] = []
                if selected == nil, arguments.isMy {
                    items.append(ContextMenuItem(strings().messageContextSelect, handler: { [weak arguments] in
                        arguments?.toggleSelected(.init(peerId: peerId, id: story.id))
                    }, itemImage: MenuAnimation.menu_check_selected.value))
                }
                return items
            })
        case let .emptySelf(index, viewType):
            return StoryMyEmptyRowItem(initialSize, stableId: index, context: arguments.context, viewType: viewType, isArchive: arguments.isArchive, showArchive: arguments.showArchive)
        case .date:
            return PeerMediaDateItem(initialSize, index: index, stableId: stableId, inset: !arguments.standalone ? .init() : NSEdgeInsets(left: 20, right: 20))
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId, viewType: .separator)
        }
    }
    
    var stableId: MessageIndex {
        switch self {
        case let .month(_, stableId, _, _, _, _, _):
            return stableId
        default:
            return self.index
        }
    }
    
    var index: MessageIndex {
        switch self {
        case let .month(index, _, _, _, _, _, _):
            return index
        case let .headerText(index, _, _, _):
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
    let isArchive: Bool
    let isMy: Bool
    let openStory:(StoryInitialIndex?)->Void
    let toggleSelected:(StoryId)->Void
    let showArchive:()->Void
    let processSelected:()->Void
    let toggleStory: (EngineStoryItem)->Void
    init(context: AccountContext, standalone: Bool, isArchive: Bool, isMy: Bool, openStory: @escaping(StoryInitialIndex?)->Void, toggleSelected:@escaping(StoryId)->Void, showArchive:@escaping()->Void, processSelected:@escaping()->Void, toggleStory: @escaping(EngineStoryItem)->Void) {
        self.context = context
        self.standalone = standalone
        self.isArchive = isArchive
        self.isMy = isMy
        self.openStory = openStory
        self.showArchive = showArchive
        self.toggleSelected = toggleSelected
        self.processSelected = processSelected
        self.toggleStory = toggleStory
    }
}

private struct State : Equatable {
    var state:PeerStoryListContext.State?
    var selected:Set<StoryId>? = nil
    var perRowCount: Int
    init(state: PeerStoryListContext.State?, selected:Set<StoryId>?, perRowCount: Int) {
        self.state = state
        self.selected = selected
        self.perRowCount = perRowCount
    }
}

private func entries(_ state: State, arguments: Arguments) -> [Entry] {
    var entries:[Entry] = []
    
    let standalone = arguments.standalone

    let selected = state.selected

    if let state = state.state, !state.items.isEmpty, let peerReference = state.peerReference {
        let timeDifference = Int32(arguments.context.timeDifference)
        var temp:[EngineStoryItem] = []
        var items = state.items.uniqueElements
        for i in 0 ..< items.count {

            let item = items[i]
            let peerId = peerReference.id
            temp.append(item)
            let next = i < items.count - 1 ? items[i + 1] : nil
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
                    entries.append(.month(index: index.peerLocalPredecessor(), stableId: index.peerLocalPredecessor(), peerId: peerId, peerReference: peerReference, items: temp, selected: selected, viewType: viewType))
                    temp.removeAll()
                }
            } else {
                let dateId = mediaDateId(for: item.timestamp - timeDifference)
                let index = MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: Int32(dateId))

                if !entries.isEmpty {
                    switch entries[entries.count - 1] {
                    case let .month(prevIndex, stableId, peerId, peerReference, items, _, viewType):
                        let prevDateId = mediaDateId(for: prevIndex.timestamp)
                        if prevDateId != dateId {
                            entries.append(.section(index: index.peerLocalSuccessor()))
                            entries.append(.date(index: index))
                            entries.append(.month(index: index.peerLocalPredecessor(), stableId: index.peerLocalPredecessor(), peerId: peerId, peerReference: peerReference, items: temp, selected: selected, viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 0, 0, 0))))
                        } else {
                            entries[entries.count - 1] = .month(index: prevIndex, stableId: stableId, peerId: peerId, peerReference: peerReference, items: items + temp, selected: selected, viewType: viewType)
                        }
                    default:
                        assertionFailure()
                    }
                } else {
                    entries.append(.month(index: index.peerLocalPredecessor(), stableId: index.peerLocalPredecessor(), peerId: peerId, peerReference: peerReference, items: temp, selected: selected, viewType: .modern(position: .last, insets: NSEdgeInsetsMake(0, 0, 0, 0))))

                }
            }
        }

        if standalone {
            var index = MessageIndex.absoluteUpperBound()
            
            if arguments.isArchive, arguments.isMy {
                entries.insert(.section(index: index), at: 0)
                index = index.globalPredecessor()
                entries.insert(.headerText(index: index, stableId: index, text: strings().storyMediaArchiveText, viewType: .singleItem), at: 0)
                index = index.globalPredecessor()
            }
            entries.insert(.section(index: index), at: 0)
            entries.append(.section(index: MessageIndex.absoluteLowerBound()))
        } else {
            entries.append(.section(index: MessageIndex.absoluteLowerBound()))
            entries.append(.section(index: MessageIndex.absoluteLowerBound().globalSuccessor()))

        }

    } else {
        var index = MessageIndex.absoluteLowerBound()
        entries.append(.section(index: index))
        index = index.globalSuccessor()
        if arguments.isMy {
            entries.append(.emptySelf(index: index, viewType: .singleItem))
        }
    }

    var updated:[Entry] = []
    
    
    var j: Int = 0
    for entry in entries {
        switch entry {
        case let .month(index, _, peerId, peerReference, items, _, _):
            let chunks = items.chunks(state.perRowCount)
            for (i, chunk) in chunks.enumerated() {
                let item = chunk[0]
                let stableId = MessageIndex(id: MessageId(peerId: index.id.peerId, namespace: 0, id: item.id), timestamp: item.timestamp)

                var viewType: GeneralViewType = bestGeneralViewType(chunks, for: i)
                if i == 0 && j == 0, !standalone {
                    viewType = chunks.count > 1 ? .innerItem : .lastItem
                }
                let updatedViewType: GeneralViewType = .modern(position: viewType.position, insets: NSEdgeInsetsMake(0, 0, 0, 0))
                updated.append(.month(index: index, stableId: stableId, peerId: peerId, peerReference: peerReference, items: chunk, selected: selected, viewType: updatedViewType))
            }
            j += 1
        case .date:
            updated.append(entry)
        case .emptySelf:
            updated.append(entry)
        case .section:
            updated.append(entry)
        case .headerText:
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


final class StoryMediaView : View {
    
    private class Panel : View {
        private let button = TextButton()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(button)
            self.button.autohighlight = false
            self.button.scaleOnClick = true
        }
        
        
        func update(title: String, enabled: Bool, callback:@escaping()->Void) {
            self.border = [.Top]
            self.borderColor = theme.colors.border
            self.backgroundColor = theme.colors.background

            self.button.set(color: theme.colors.underSelectedColor, for: .Normal)
            self.button.set(background: theme.colors.accent, for: .Normal)
            self.button.set(font: .medium(.text), for: .Normal)
            self.button.set(text: title, for: .Normal)
            
            self.button.removeAllHandlers()
            self.button.set(handler: { _ in
                callback()
            }, for: .SingleClick)
            
            self.button.isEnabled = enabled
            
            needsLayout = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            self.button.sizeToFit(.zero, NSMakeSize(frame.width - 20, frame.height - 20), thatFit: true)
            self.button.layer?.cornerRadius = 10
            self.button.center()
        }
    }
    
    let tableView: TableView
    private var panel: Panel?
    
    required init(frame frameRect: NSRect) {
        self.tableView = .init(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        addSubview(tableView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func updateState(_ state: State, arguments: Arguments, animated: Bool) {
        
        if let selected = state.selected, !selected.isEmpty {
            let current: Panel
            if let view = self.panel {
                current = view
            } else {
                current = Panel(frame: NSMakeRect(0, frame.height - 60, frame.width, 60))
                self.panel = current
                addSubview(current)
                
                if animated {
                    current.layer?.animatePosition(from: NSMakePoint(0, frame.height), to: current.frame.origin)
                }
            }
            current.update(title: arguments.isArchive ? "Save to Profile" : "Remove from Profile", enabled: !selected.isEmpty, callback: { [weak arguments] in
                arguments?.processSelected()
            })
        } else if let view = self.panel {
            performSubviewPosRemoval(view, pos: NSMakePoint(0, frame.height), animated: animated)
            self.panel = nil
        }
        tableView.contentInsets = .init(top: 0, left: 0, bottom: self.panel != nil ? 70 : 0, right: 0)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        if let panel = self.panel {
            transition.updateFrame(view: panel, frame: NSMakeRect(0, size.height - 60, size.width, 60))
        }
        transition.updateFrame(view: tableView, frame: size.bounds)
    }
}


final class StoryMediaController : TelegramGenericViewController<StoryMediaView> {
    
    private let actionsDisposable = DisposableSet()
    private let peerId: EnginePeer.Id
    private let standalone: Bool
    private let isArchived: Bool
    private var statePromise: ValuePromise<State> = ValuePromise(ignoreRepeated: true)
    private var stateValue: Atomic<State> = Atomic(value: State(state: nil, selected: nil, perRowCount: 4))
    private let listContext: PeerStoryListContext
    private let archiveContext: PeerStoryListContext?

    private func updateState(_ f:(State) -> State) {
        statePromise.set(stateValue.modify (f))
    }

    
    private var editButton:ImageButton? = nil
    private var doneButton:TextButton? = nil

    override func requestUpdateRightBar() {
        editButton?.style = navigationButtonStyle
        editButton?.set(image: theme.icons.chatActions, for: .Normal)
        editButton?.set(image: theme.icons.chatActionsActive, for: .Highlight)

        
        editButton?.setFrameSize(70, 50)
        editButton?.center()
        doneButton?.set(color: theme.colors.accent, for: .Normal)
        doneButton?.style = navigationButtonStyle
    }
    
    override func getRightBarViewOnce() -> BarView {
        let back = BarView(70, controller: self) //MajorBackNavigationBar(self, account: account, excludePeerId: peerId)
        
        let editButton = ImageButton()
       // editButton.disableActions()
        back.addSubview(editButton)
        
        self.editButton = editButton
//
        let doneButton = TextButton()
      //  doneButton.disableActions()
        doneButton.set(font: .medium(.text), for: .Normal)
        doneButton.set(text: strings().navigationDone, for: .Normal)
        
        
        _ = doneButton.sizeToFit()
        back.addSubview(doneButton)
        doneButton.center()
        
        self.doneButton = doneButton

        doneButton.set(handler: { [weak self] _ in
            self?.toggleSelection()
        }, for: .Click)
        
        doneButton.isHidden = true
        
        let context = self.context
        let isArchived = self.isArchived
        
        editButton.contextMenu = { [weak self] in
            
            let menu = ContextMenu()
            if !isArchived {
                menu.addItem(ContextMenuItem(strings().storyMediaContextArchive, handler: {
                    self?.openArchive()
                }, itemImage: MenuAnimation.menu_archive.value))
            }
            let selecting = self?.stateValue.with { $0.selected != nil } == true
            let hasItems = self?.stateValue.with { $0.state?.items.count } != 0
            if hasItems {
                menu.addItem(ContextMenuItem(selecting ? strings().storyMediaDone : strings().storyMediaSelect, handler: {
                    self?.toggleSelection()
                }, itemImage: MenuAnimation.menu_select_multiple.value))
            }

            return menu
        }
        requestUpdateRightBar()
        return back
    }

    
    private func toggleSelection() {
        
        let button = self.rightBarView as? TextButtonBarView
        
        
        updateState { current in
            var current = current
            if current.selected == nil {
                current.selected = []
            } else {
                current.selected = nil
            }
            return current
        }
        
        button?.set(text: stateValue.with { $0.selected != nil } ? strings().storyMediaDone : strings().storyMediaSelect, for: .Normal)
    }
    
    private func openArchive() {
        if let archiveContext = self.archiveContext {
            self.navigationController?.push(StoryMediaController(context: context, peerId: peerId, listContext: archiveContext, standalone: self.standalone, isArchived: true))
        }
    }
    
    static func push(context: AccountContext, peerId: PeerId, listContext: PeerStoryListContext, standalone: Bool = false, isArchived: Bool = false) {
        if let controller = context.bindings.rootNavigation().controller as? StoryMediaController {
            if controller.isArchived == isArchived && controller.standalone == standalone {
                return
            }
        }
        context.bindings.rootNavigation().push(StoryMediaController(context: context, peerId: peerId, listContext: listContext, standalone: standalone, isArchived: isArchived))
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
        
        
        genericView.tableView.set(stickClass: PeerMediaDateItem.self, handler: { _ in
            
        })
        
        let context = self.context
        let peerId = self.peerId
        let initialSize = self.atomicSize
        let isArchived = self.isArchived
        
        genericView.tableView.getBackgroundColor = {
           return theme.colors.listBackground
        }
        
        genericView.tableView.setScrollHandler({ [weak self] _ in
            if let list = self?.listContext {
                list.loadMore()
            }
        })

                
        self.setCenterTitle(isArchived ? strings().storyMediaTitleArchive : peerId == context.peerId ? strings().storyMediaTitleMyStories : "")
        
        let arguments = Arguments(context: context, standalone: standalone, isArchive: isArchived, isMy: peerId == context.peerId, openStory: { [weak self] initialId in
            if let list = self?.listContext {
                StoryModalController.ShowPeerStory(context: context, listContext: list, peerId: peerId, initialId: initialId)
            }
        }, toggleSelected: { [weak self] storyId in
            self?.updateState { current in
                var current = current
                if var selected = current.selected {
                    if selected.contains(storyId) {
                        selected.remove(storyId)
                    } else {
                        selected.insert(storyId)
                    }
                    current.selected = selected
                } else {
                    current.selected = Set([storyId])
                }
                return current
            }
        }, showArchive: { [weak self] in
            self?.openArchive()
        }, processSelected: { [weak self] in
            let selected = self?.stateValue.with { $0.selected } ?? Set()
            let list = self?.stateValue.with { $0.state?.items } ?? []
            var stories: [Int32 : EngineStoryItem] = [:]
            for selected in selected {
                if let story = list.first(where: { $0.id == selected.id }) {
                    stories[story.id] = story
                }
            }
            _ = context.engine.messages.updateStoriesArePinned(peerId: peerId, ids: stories, isPinned: isArchived).start()
            if isArchived {
                let text: String = peerId.namespace == Namespaces.Peer.CloudChannel ? strings().storyTooltipSavedToProfileChannel : strings().storyTooltipSavedToProfile
                showModalText(for: context.window, text: text, title: strings().storyTooltipSavedTitle)
            } else {
                let text: String = peerId.namespace == Namespaces.Peer.CloudChannel ? strings().storyTooltipRemovedFromProfileChannel : strings().storyTooltipRemovedFromProfile
                showModalText(for: context.window, text: text, title: strings().storyTooltipRemovedTitle)
            }
            self?.updateState({ current in
                var current = current
                current.selected = nil
                return current
            })
        }, toggleStory: { story in
            _ = context.engine.messages.updateStoriesArePinned(peerId: peerId, ids: [story.id : story], isPinned: isArchived).start()
            
            if isArchived {
                let text: String = peerId.namespace == Namespaces.Peer.CloudChannel ? strings().storyTooltipSavedToProfileChannel : strings().storyTooltipSavedToProfile
                showModalText(for: context.window, text: text, title: strings().storyTooltipSavedTitle)
            } else {
                let text: String = peerId.namespace == Namespaces.Peer.CloudChannel ? strings().storyTooltipRemovedFromProfileChannel : strings().storyTooltipRemovedFromProfile
                showModalText(for: context.window, text: text, title: strings().storyTooltipRemovedTitle)
            }
        })

        let stateSignal = listContext.state |> deliverOnMainQueue
        actionsDisposable.add(stateSignal.start(next: { [weak self] state in
            self?.updateState { current in
                var current = current
                current.state = state
                return current
            }
            if state.totalCount > 0 {
                self?.setCenterStatus("\(state.totalCount) stories")
            } else {
                self?.setCenterStatus(nil)
            }
        }))


        let signal: Signal<([Entry], State), NoError> = statePromise.get() |> deliverOnPrepareQueue |> map { state in
            return (entries(state, arguments: arguments), state)
        }

        let previous: Atomic<[AppearanceWrapperEntry<Entry>]> = Atomic(value: [])
        let first = Atomic(value: true)

        let transition: Signal<(TableUpdateTransition, State), NoError> = combineLatest(signal, appearanceSignal) |> map { values, appearance -> (TableUpdateTransition, State) in
            let entries = values.0.map { AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return (prepareTransition(left: previous.swap(entries), right: entries, animated: !first.swap(false), initialSize: initialSize.with { $0 }, arguments: arguments), values.1)
        } |> deliverOnMainQueue

        actionsDisposable.add(transition.start(next: { [weak self, weak arguments] (transition, state) in
            guard let arguments = arguments else {
                return
            }
            self?.genericView.tableView.merge(with: transition)
            self?.readyOnce()
            
            self?.genericView.updateState(state, arguments: arguments, animated: transition.animated)
            self?.doneButton?.isHidden = state.selected == nil
            self?.editButton?.isHidden = state.selected != nil
            
        }))
        
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        let selecting = self.stateValue.with({ $0.selected != nil })
        if selecting {
            self.toggleSelection()
            return .invoked
        } else {
            return super.escapeKeyAction()
        }
    }
    
    override var enableBack: Bool {
        return true
    }
    
    private var perRowCount: Int {
        var rowCount:Int = 4
        var perWidth: CGFloat = 0
        let blockWidth = min(600, atomicSize.with { $0.width }) - (standalone ? 60 : 0)
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
