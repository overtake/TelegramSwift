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
    case month(index: MessageIndex, stableId: MessageIndex, peerId: PeerId, peerReference: PeerReference, items: [StoryListContextState.Item], selected: Set<StoryId>?, pinnedIds: Set<Int32>, rowCount: Int, viewType: GeneralViewType)
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
        case let .month(_, stableId, peerId, peerReference, items, selected, pinnedIds, rowCount, viewType):
            return StoryMonthRowItem(initialSize, stableId: stableId, context: arguments.context, standalone: arguments.standalone, peerId: peerId, peerReference: peerReference, items: items, selected: selected, pinnedIds: pinnedIds, rowCount: rowCount, viewType: viewType, openStory: arguments.openStory, toggleSelected: arguments.toggleSelected, menuItems: { story in
                var items: [ContextMenuItem] = []
                if selected == nil, arguments.isMy {
                   
                    if !story.isPinned {
                        items.append(ContextMenuItem(strings().storyMediaUnarchive, handler: { [weak arguments] in
                            arguments?.toggleStory(story)
                        }, itemImage: MenuAnimation.menu_save_to_profile.value))
                    } else {
                        items.append(ContextMenuItem(strings().storyMediaArchive, handler: { [weak arguments] in
                            arguments?.toggleStory(story)
                        }, itemImage: MenuAnimation.menu_archive.value))
                    }
                    
                    items.append(ContextMenuItem(pinnedIds.contains(story.id) ? strings().messageContextUnpin : strings().messageContextPin, handler: { [weak arguments] in
                        arguments?.togglePinned(story)
                    }, itemImage: pinnedIds.contains(story.id) ? MenuAnimation.menu_unpin.value : MenuAnimation.menu_pin.value))
                    
                    items.append(ContextMenuItem(strings().messageContextSelect, handler: { [weak arguments] in
                        arguments?.toggleSelected(.init(peerId: peerId, id: story.id))
                    }, itemImage: MenuAnimation.menu_check_selected.value))
                    
                    items.append(ContextSeparatorItem())
                    
                    items.append(ContextMenuItem(strings().messageContextDelete, handler: { [weak arguments] in
                        arguments?.deleteStory(story)
                    }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
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
        case let .month(_, stableId, _, _, _, _, _, _, _):
            return stableId
        default:
            return self.index
        }
    }
    
    var index: MessageIndex {
        switch self {
        case let .month(index, _, _, _, _, _, _, _, _):
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
    let archiveSelected:()->Void
    let toggleStory: (EngineStoryItem)->Void
    let deleteStory:(EngineStoryItem)->Void
    let togglePinned:(EngineStoryItem)->Void
    let deleteSelected:()->Void
    let togglePinSelected:()->Void
    init(context: AccountContext, standalone: Bool, isArchive: Bool, isMy: Bool, openStory: @escaping(StoryInitialIndex?)->Void, toggleSelected:@escaping(StoryId)->Void, showArchive:@escaping()->Void, archiveSelected:@escaping()->Void, toggleStory: @escaping(EngineStoryItem)->Void, deleteStory:@escaping(EngineStoryItem)->Void, deleteSelected:@escaping()->Void, togglePinned:@escaping(EngineStoryItem)->Void, togglePinSelected:@escaping()->Void) {
        self.context = context
        self.standalone = standalone
        self.isArchive = isArchive
        self.isMy = isMy
        self.openStory = openStory
        self.showArchive = showArchive
        self.toggleSelected = toggleSelected
        self.archiveSelected = archiveSelected
        self.toggleStory = toggleStory
        self.deleteStory = deleteStory
        self.deleteSelected = deleteSelected
        self.togglePinned = togglePinned
        self.togglePinSelected = togglePinSelected
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
    
    let perRowCount = state.perRowCount

    if let state = state.state, !state.items.isEmpty, let peerReference = state.peerReference {
        let items = state.items.uniqueElements
        let peerId = peerReference.id
        let viewType: GeneralViewType = .modern(position: .single, insets: NSEdgeInsetsMake(0, 0, 0, 0))
        entries.append(.month(index: MessageIndex.absoluteUpperBound(), stableId: MessageIndex.absoluteUpperBound(), peerId: peerId, peerReference: peerReference, items: items, selected: selected, pinnedIds: state.pinnedIds, rowCount: perRowCount, viewType: viewType))

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
        case let .month(index, _, peerId, peerReference, items, _, pinnedIds, rowCount, _):
            let chunks = items.chunks(state.perRowCount)
            for (i, chunk) in chunks.enumerated() {
                let item = chunk[0]
                let stableId = MessageIndex(id: MessageId(peerId: index.id.peerId, namespace: 0, id: item.storyItem.id), timestamp: item.storyItem.timestamp)

                var viewType: GeneralViewType = bestGeneralViewType(chunks, for: i)
                if i == 0 && j == 0, !standalone {
                    viewType = chunks.count > 1 ? .innerItem : .lastItem
                }
                let updatedViewType: GeneralViewType = .modern(position: viewType.position, insets: NSEdgeInsetsMake(0, 0, 0, 0))
                updated.append(.month(index: index, stableId: stableId, peerId: peerId, peerReference: peerReference, items: chunk, selected: selected, pinnedIds: pinnedIds, rowCount: rowCount, viewType: updatedViewType))
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
        private var pin = TextButton()
        private var archive = TextButton()
        private var delete = TextButton()
        
        private var arguments: Arguments?
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(pin)
            addSubview(archive)
            addSubview(delete)

            self.pin.autohighlight = false
            self.pin.scaleOnClick = true
            
            self.archive.autohighlight = false
            self.archive.scaleOnClick = true

            self.delete.autohighlight = false
            self.delete.scaleOnClick = true
            
            delete.set(handler: { [weak self] _ in
                self?.arguments?.deleteSelected()
            }, for: .Click)

            
            archive.set(handler: { [weak self] _ in
                if let arguments = self?.arguments {
                    arguments.archiveSelected()
                }
            }, for: .Click)
            
            pin.set(handler: { [weak self] _ in
                if let arguments = self?.arguments {
                    arguments.togglePinSelected()
                }
            }, for: .Click)
        }
        
        
        func update(selected: Set<StoryId>, isArchive: Bool, arguments: Arguments) {
            
            self.arguments = arguments
            
            self.border = [.Top]
            self.borderColor = theme.colors.border
            self.backgroundColor = theme.colors.background

            self.pin.set(font: .medium(.text), for: .Normal)
            self.pin.set(color: theme.colors.accent, for: .Normal)
            self.pin.set(text: strings().storyMediaPin, for: .Normal)
            self.pin.sizeToFit(NSMakeSize(10, 10))
            
            self.archive.set(font: .medium(.text), for: .Normal)
            self.archive.set(color: theme.colors.accent, for: .Normal)
            self.archive.set(text: isArchive ? strings().storyMediaUnarchive : strings().storyMediaArchive, for: .Normal)
            self.archive.sizeToFit(NSMakeSize(10, 10))

            self.delete.set(font: .medium(.text), for: .Normal)
            self.delete.set(color: theme.colors.redUI, for: .Normal)
            self.delete.set(text: strings().storyMediaDelete, for: .Normal)
            self.delete.sizeToFit(NSMakeSize(10, 10))

            self.pin.isEnabled = !selected.isEmpty
            self.archive.isEnabled = !selected.isEmpty
            self.delete.isEnabled = !selected.isEmpty

            
            
            
            needsLayout = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            pin.centerY(x: 10)
            archive.center()
            delete.centerY(x: frame.width - delete.frame.width - 10)
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
                current = Panel(frame: NSMakeRect(0, frame.height - 50, frame.width, 50))
                self.panel = current
                addSubview(current)
                
                if animated {
                    current.layer?.animatePosition(from: NSMakePoint(0, frame.height), to: current.frame.origin)
                }
            }
            current.update(selected: selected, isArchive: arguments.isArchive, arguments: arguments)
        } else if let view = self.panel {
            performSubviewPosRemoval(view, pos: NSMakePoint(0, frame.height), animated: animated)
            self.panel = nil
        }
        tableView.contentInsets = .init(top: 0, left: 0, bottom: self.panel != nil ? 60 : 0, right: 0)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        if let panel = self.panel {
            transition.updateFrame(view: panel, frame: NSMakeRect(0, size.height - 50, size.width, 50))
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
    
    var parentToggleSelection: (()->Void)?

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

    
    func toggleSelection() {
        
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
        let maxPinLimit = context.appConfiguration.getGeneralValue("stories_pinned_to_top_count_max", orElse: 3)

                
        self.setCenterTitle(isArchived ? strings().storyMediaTitleArchive : peerId == context.peerId ? strings().storyMediaTitleMyStories : "")
        
        let arguments = Arguments(context: context, standalone: standalone, isArchive: isArchived, isMy: peerId == context.peerId, openStory: { [weak self] initialId in
            if let list = self?.listContext {
                StoryModalController.ShowListStory(context: context, listContext: list, peerId: peerId, initialId: initialId)
            }
        }, toggleSelected: { [weak self] storyId in
            
            let value = self?.stateValue.with { $0.selected != nil }
            if value == false {
                self?.parentToggleSelection?()
            }
            
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
        }, archiveSelected: { [weak self] in
            let selected = self?.stateValue.with { $0.selected } ?? Set()
            let list = self?.stateValue.with { $0.state?.items } ?? []
            var stories: [Int32 : EngineStoryItem] = [:]
            for selected in selected {
                if let story = list.first(where: { $0.storyItem.id == selected.id }) {
                    stories[story.storyItem.id] = story.storyItem
                }
            }
            _ = context.engine.messages.updateStoriesArePinned(peerId: peerId, ids: stories, isPinned: isArchived).start()
            if isArchived {
                let text: String = peerId.namespace == Namespaces.Peer.CloudChannel ? strings().storyTooltipSavedToProfileChannel : strings().storyTooltipSavedToProfile
                showModalText(for: context.window, text: text)
            } else {
                let text: String = peerId.namespace == Namespaces.Peer.CloudChannel ? strings().storyTooltipRemovedFromProfileChannel : strings().storyTooltipRemovedFromProfile
                showModalText(for: context.window, text: text)
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
        }, deleteStory: { story in
            verifyAlert_button(for: context.window, information: strings().storyConfirmDelete, ok: strings().modalDelete, successHandler: { _ in
                _ = context.engine.messages.deleteStories(peerId: peerId, ids: [story.id]).startStandalone()
                _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 3).startStandalone()
            })
        }, deleteSelected: { [weak self] in
            let ids:[Int32] = self?.stateValue.with { state in
                return state.selected?.map { $0.id }
            } ?? []
            verifyAlert_button(for: context.window, information: strings().storyMediaDeleteConfirmCountable(ids.count), ok: strings().modalDelete, successHandler: { _ in
                _ = context.engine.messages.deleteStories(peerId: peerId, ids: ids).startStandalone()
                _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 3).startStandalone()
                self?.toggleSelection()
            })
            
        }, togglePinned: { [weak self] story in
            var pinned = Array(self?.stateValue.with ({ $0.state?.pinnedIds }) ?? Set())
            if let index = pinned.firstIndex(where: { $0 == story.id }) {
                pinned.remove(at: index)
                showModalText(for: context.window, text: strings().storyMediaTooltipUnpinnedCountable(1))
            } else {
                pinned.append(story.id)
                showModalText(for: context.window, text: strings().storyMediaTooltipPinnedCountable(1))
            }
            _ = context.engine.messages.updatePinnedToTopStories(peerId: peerId, ids: pinned).startStandalone()
            
        }, togglePinSelected: { [weak self] in
            let ids:[Int32] = self?.stateValue.with { state in
                return state.selected?.map { $0.id }
            } ?? []
            
            if ids.count <= maxPinLimit {
                _ = context.engine.messages.updatePinnedToTopStories(peerId: peerId, ids: ids).startStandalone()
                showModalText(for: context.window, text: strings().storyMediaTooltipPinnedCountable(ids.count))
            } else {
                showModalText(for: context.window, text: strings().storyMediaTooltipLimitCountable(Int(maxPinLimit)))
            }
            self?.toggleSelection()
        })

        let stateSignal = listContext.state |> deliverOnMainQueue
        actionsDisposable.add(stateSignal.start(next: { [weak self] state in
            self?.updateState { current in
                var current = current
                current.state = state
                return current
            }
            if state.totalCount > 0 {
                self?.setCenterStatus(strings().chatListArchiveStoryCountCountable(state.totalCount).lowercased())
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
