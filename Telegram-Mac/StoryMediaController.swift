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



private final class FilterRowItem : GeneralRowItem {
    fileprivate let item: CollectionRowItem.Item
    fileprivate let layout: TextViewLayout
    fileprivate let context: AccountContext
    fileprivate let arguments: Arguments
    fileprivate let selected: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable, item: CollectionRowItem.Item, selected: Bool, arguments: Arguments) {
        self.item = item
        self.selected = selected
        self.layout = .init(item.text, maximumNumberOfLines: 1)
        self.layout.measure(width: .greatestFiniteMagnitude)
        self.context = arguments.context
        self.arguments = arguments
        super.init(initialSize)
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        return .single(self.arguments.collectionContextMenu(self.item.value))
    }
    
    override func viewClass() -> AnyClass {
        return FilterRowView.self
    }
    
    override var height: CGFloat {
        return self.layout.layoutSize.width + 24
    }
    override var width: CGFloat {
        return 40
    }
}

private final class FilterRowView : HorizontalRowView {
    private let textView: InteractiveTextView = InteractiveTextView()
    private var selectedView: View?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.scaleOnClick = false
        textView.userInteractionEnabled = false
        
        
//        textView.set(handler: { [weak self] _ in
//            if let event = NSApp.currentEvent {
//                self?.item?.table?.mouseDown(with: event)
//            }
//        }, for: .Down)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? FilterRowItem else {
            return
        }
        
        self.textView.set(text: item.layout, context: item.context)
        self.textView.center()
                
        if item.selected {
            let current: View
            let isNew: Bool
            if let view = self.selectedView {
                current = view
                isNew = false
            } else {
                current = View()
                addSubview(current, positioned: .below, relativeTo: textView)
                self.selectedView = current
                isNew = true
            }
            current.backgroundColor = theme.colors.listGrayText.withAlphaComponent(0.15)
            current.frame = textView.frame.insetBy(dx: -10, dy: -5)
            current.layer?.cornerRadius = current.frame.height / 2
            if isNew, animated {
                current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
            }
        } else if let selectedView {
            performSubviewRemoval(selectedView, animated: animated)
            self.selectedView = nil
        }
    }
    
    override func layout() {
        super.layout()
        self.textView.center()
    }
}


private final class CollectionRowItem : TableStickItem {
    
    struct Item : Comparable, Identifiable {
        let value: State.Collection
        let index: Int
        let selected: Bool
        
        var stableId: AnyHashable {
            return value.stableId
        }
        static func < (lhs: Item, rhs: Item) -> Bool {
            return lhs.index < rhs.index
        }
        
        func makeItem(_ size: NSSize, arguments: Arguments) -> TableRowItem {
            return FilterRowItem(size, stableId: stableId, item: self, selected: self.selected, arguments: arguments)
        }
        
        var text: NSAttributedString {
            let attr = NSMutableAttributedString()
            //TODOLANG
            switch self.value {
            case .all:
                attr.append(string: "All Stories", color: selected ? theme.colors.darkGrayText : theme.colors.listGrayText, font: .normal(.text))
            case let .collection(value):
                attr.append(string: value.title, color: selected ? theme.colors.darkGrayText : theme.colors.listGrayText, font: .normal(.text))
            case .add:
                attr.append(string: "\(clown_space)Add Album", color: selected ? theme.colors.darkGrayText : theme.colors.listGrayText, font: .normal(.text))
                attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.menu_add.file, color: theme.colors.listGrayText, playPolicy: .framesCount(1)), for: clown)
            }
            return attr
        }
    }
    
    fileprivate let items: [Item]
    fileprivate let selected: Int64?
    fileprivate let context: AccountContext?
    fileprivate let arguments: Arguments?
    fileprivate let _stableId: AnyHashable
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, filters: [State.Collection], selected: Int64, arguments: Arguments) {
        var items: [Item] = []
        for (i, filter) in filters.enumerated() {
            items.append(.init(value: filter, index: i, selected: filter.stableId == selected))
        }
        self.items = items
        self.context = context
        self.selected = selected
        self.arguments = arguments
        self._stableId = stableId
        super.init(initialSize)
    }
    
    override var stableId: AnyHashable {
        return _stableId
    }
    
    required init(_ initialSize: NSSize) {
        self.arguments = nil
        self.context = nil
        self.items = []
        self._stableId = AnyHashable(InputDataEntryId.custom(_id_collections))
        self.selected = nil
        super.init(initialSize)
        
    }
    
    override var height: CGFloat {
        return 50
    }
    
    override func viewClass() -> AnyClass {
        return CollectionFilterRowView.self
    }
}

private final class CollectionFilterRowView : TableStickView, TableViewDelegate {
    func selectionDidChange(row: Int, item: TableRowItem, byClick: Bool, isNew: Bool) {
        if let item = item as? FilterRowItem {
            item.arguments.collection(item.item.value, nil)
        }
    }
    
    func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        return true
    }
    
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return true
    }
    private var ignoreNextAnimation: Bool = false
    private let tableView = HorizontalTableView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        tableView.getBackgroundColor = {
            .clear
        }
        
        tableView.delegate = self
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var items: [CollectionRowItem.Item] = []
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        let animated = animated && !ignoreNextAnimation
        
        guard let item = item as? CollectionRowItem else {
            return
        }
        let context = item.context
        let items = item.items
        let arguments = item.arguments
        
        guard let arguments else {
            return
        }
        
        tableView.beginTableUpdates()
        
        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.items, rightList: items)
        
        for rdx in deleteIndices.reversed() {
            tableView.remove(at: rdx, animation: animated ? .effectFade : .none)
            self.items.remove(at: rdx)
        }
        
        for (idx, item, _) in indicesAndItems {
            _ = tableView.insert(item: item.makeItem(bounds.size, arguments: arguments), at: idx, animation: animated ? .effectFade : .none)
            self.items.insert(item, at: idx)
        }
        for (idx, item, _) in updateIndices {
            let item =  item
            tableView.replace(item: item.makeItem(bounds.size, arguments: arguments), at: idx, animated: animated)
            self.items[idx] = item
        }

        tableView.endTableUpdates()
        

        tableView.resortController = .init(resortRange: NSMakeRange(1, items.count - 2), start: { _ in }, resort: { _ in }, complete: { [weak self] from, to in
            self?.ignoreNextAnimation = true
            arguments.resort(from, to)
        })
        
    }
    
    override func layout() {
        super.layout()
        if tableView.listHeight < bounds.width {
            tableView.frame = focus(NSMakeSize(tableView.listHeight, 40))
        } else {
            tableView.frame = focus(NSMakeSize(bounds.width, 40))
        }
    }
}


private enum Entry : TableItemListNodeEntry {
    case headerText(index: MessageIndex, stableId: MessageIndex, text: String, viewType: GeneralViewType)
    case month(index: MessageIndex, stableId: MessageIndex, peerId: PeerId, peerReference: PeerReference, items: [StoryListContextState.Item], selected: Set<StoryId>?, pinnedIds: [Int32], rowCount: Int, viewType: GeneralViewType)
    case date(index: MessageIndex)
    case section(index: MessageIndex, height: CGFloat)
    case collections(index: MessageIndex, [State.Collection], Int64)
    case emptySelf(index: MessageIndex, collection: State.Collection, viewType: GeneralViewType)
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
        case let .emptySelf(index, collection, viewType):
            if collection != .all {
                //TODOLANG
                return SearchEmptyRowItem(initialSize, stableId: stableId, header: "Organize Your Stories", text: "Add some stories to this folder.", action: .init(click: {
                    arguments.addToCollection(collection, nil)
                }, title: "Add to Folder"))
            } else {
                return StoryMyEmptyRowItem(initialSize, stableId: index, context: arguments.context, viewType: viewType, isArchive: arguments.isArchive, showArchive: arguments.showArchive)
            }
        case .date:
            return PeerMediaDateItem(initialSize, index: index, stableId: stableId, inset: !arguments.standalone ? .init() : NSEdgeInsets(left: 20, right: 20))
        case let .collections(index, collections, selected):
            return CollectionRowItem(initialSize, stableId: stableId, context: arguments.context, filters: collections, selected: selected, arguments: arguments)
        case let .section(_, height):
            return GeneralRowItem(initialSize, height: height, stableId: stableId, viewType: .separator)
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
        case let .emptySelf(index, _, _):
            return index
        case let .date(index):
            return index
        case let .section(index, _):
            return index
        case let .collections(index, _, _):
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
    let collection:(State.Collection, StoryListContextState.Item?)->Void
    let addToCollection:(State.Collection, StoryListContextState.Item?)->Void
    let collectionContextMenu:(State.Collection)->[ContextMenuItem]
    let resort:(Int, Int)->Void
    init(context: AccountContext, standalone: Bool, isArchive: Bool, isMy: Bool, openStory: @escaping(StoryInitialIndex?)->Void, toggleSelected:@escaping(StoryId)->Void, showArchive:@escaping()->Void, archiveSelected:@escaping()->Void, toggleStory: @escaping(EngineStoryItem)->Void, deleteStory:@escaping(EngineStoryItem)->Void, deleteSelected:@escaping()->Void, togglePinned:@escaping(EngineStoryItem)->Void, togglePinSelected:@escaping()->Void, collection:@escaping(State.Collection, StoryListContextState.Item?)->Void, addToCollection: @escaping(State.Collection, StoryListContextState.Item?)->Void, collectionContextMenu:@escaping(State.Collection)->[ContextMenuItem], resort:@escaping(Int, Int)->Void) {
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
        self.collection = collection
        self.addToCollection = addToCollection
        self.collectionContextMenu = collectionContextMenu
        self.resort = resort
        
    }
}

private struct State : Equatable {
    
    enum Collection : Equatable {
        case all
        case collection(value: PeerStoryListContext.State.Folder)
        case add
        
        var stableId: Int64 {
            switch self {
            case .all:
                return -1
            case let .collection(value):
                return value.id
            case .add:
                return .max
            }
        }
    }
    
    var state:PeerStoryListContext.State? {
        return collectionStates[selectedCollection] ?? collectionStates[Collection.all.stableId]
    }
    
    var mainState: PeerStoryListContext.State? {
        return collectionStates[Collection.all.stableId]
    }
    
    func contains(collectionId: Int64, storyId: StoryId) -> Bool {
        return collectionStates[collectionId]?.items.contains(where: { $0.id == storyId }) == true
    }
    
    var sortedFolderIds: [Int64] {
        return collections.filter { value in
            switch value {
            case .collection:
                return true
            default:
                return false
            }
        }.map {
            $0.stableId
        }
    }
    
    var selected:Set<StoryId>? = nil
    var perRowCount: Int
    var peer: EnginePeer?
    var collectionStates:[Int64: PeerStoryListContext.State] = [:]
    var onStage: Bool = false
    func access(_ accountPeerId: PeerId) -> Bool {
        return peer?.id == accountPeerId || peer?._asPeer().groupAccess.canManageStories == true
    }
    
    var collections: [Collection] = []
    var selectedCollection: Int64 = Collection.all.stableId
    
    var collection: Collection {
        return self.collections.first(where: { $0.stableId == selectedCollection}) ?? .all
    }

    init(state: PeerStoryListContext.State?, selected:Set<StoryId>?, perRowCount: Int) {
        self.collectionStates[Collection.all.stableId] = state
        self.selected = selected
        self.perRowCount = perRowCount
    }
}

private let _id_collections = InputDataIdentifier("_id_collections")

private func entries(_ state: State, arguments: Arguments) -> [Entry] {
    var entries:[Entry] = []
    
    let standalone = arguments.standalone

    let selected = state.selected
    
    let perRowCount = state.perRowCount
    
    var hasFolders: Bool = false
    
    var index = MessageIndex.absoluteLowerBound()

    
    if !arguments.standalone, !state.collections.isEmpty {
                
        entries.append(.section(index: index, height: 0))
        index = index.peerLocalSuccessor()
        entries.append(.collections(index: index, state.collections, state.selectedCollection))
//        index = index.peerLocalSuccessor()
//        entries.append(.section(index: index, height: 0))

        hasFolders = true
    }

    if let state = state.state, !state.items.isEmpty, let peerReference = state.peerReference {
        
        
        
        let items = state.items.uniqueElements
        let peerId = peerReference.id
        let viewType: GeneralViewType = .modern(position: .single, insets: NSEdgeInsetsMake(0, 0, 0, 0))
        
        entries.append(.month(index: MessageIndex.absoluteUpperBound(), stableId: MessageIndex.absoluteUpperBound(), peerId: peerId, peerReference: peerReference, items: items, selected: selected, pinnedIds: state.pinnedIds, rowCount: perRowCount, viewType: viewType))

        var index = MessageIndex.absoluteUpperBound()
        
        if standalone {
            if arguments.isArchive, arguments.isMy {
                entries.append(.section(index: index, height: 20))
                index = index.peerLocalPredecessor()
                entries.insert(.headerText(index: index, stableId: index, text: strings().storyMediaArchiveText, viewType: .singleItem), at: 0)
                index = index.peerLocalPredecessor()
            }
            entries.append(.section(index: index, height: 20))
            index = index.peerLocalPredecessor()
        } else {
//            if !hasFolders {
//            entries.append(.section(index: index, height: 20))
//                index = index.peerLocalSuccessor()
//            }
        }

    } else {
        entries.append(.section(index: index, height: 20))
        index = index.peerLocalSuccessor()
        if arguments.isMy {
            entries.append(.emptySelf(index: index, collection: state.collection, viewType: .singleItem))
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
                    if chunks.count > 1 {
                        viewType = hasFolders ? .firstItem : .innerItem
                    } else {
                        viewType = hasFolders ? .singleItem : .lastItem
                    }
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
        case .collections:
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
    
    fileprivate var willMove: ((NSWindow?)->Void)? = nil

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        
        self.willMove?(newWindow)
    }
    
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
    
    private class FolderPanel : View {
        private var add = TextButton()
        private var arguments: Arguments?
        
        private var collection: State.Collection?
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(add)
            
            add.set(handler: { [weak self] _ in
                if let arguments = self?.arguments, let collection = self?.collection {
                    arguments.addToCollection(collection, nil)
                }
            }, for: .Click)
        }
        
        
        func update(collection: State.Collection, arguments: Arguments) {
            
            self.arguments = arguments
            self.collection = collection
            
            self.border = [.Top]
            self.borderColor = theme.colors.border
            self.backgroundColor = theme.colors.background

            self.add.set(font: .medium(.text), for: .Normal)
            self.add.set(color: theme.colors.underSelectedColor, for: .Normal)
            //TODOLANG
            self.add.set(text: "Add Stories", for: .Normal)
            self.add.sizeToFit(.zero, NSMakeSize(frame.width - 40, 40), thatFit: true)
            self.add.set(background: theme.colors.accent, for: .Normal)
            
            self.add.scaleOnClick = true
            self.add.autohighlight = false
            
            self.add.layer?.cornerRadius = 10
            
            needsLayout = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            add.frame = NSMakeRect(5, 5, frame.width - 10, 40)
        }
    }

    
    let tableView: TableView
    private var panel: Panel?
    private var folderPanel: FolderPanel?
    
    required init(frame frameRect: NSRect) {
        self.tableView = .init(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        addSubview(tableView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func updateState(_ state: State, arguments: Arguments, animated: Bool) {
        
        
        if let selected = state.selected, !selected.isEmpty, let view = superview?.superview?.superview, state.onStage {
            
            if let view = self.folderPanel, let superview = view.superview {
                performSubviewPosRemoval(view, pos: NSMakePoint(0, superview.frame.height + view.frame.height), animated: animated)
                self.folderPanel = nil
            }
            
            let current: Panel
            if let view = self.panel {
                current = view
            } else {
                current = Panel(frame: NSMakeRect(0, view.frame.height - 50, view.frame.width, 50))
                self.panel = current
                view.addSubview(current)
                
                if animated {
                    current.layer?.animatePosition(from: NSMakePoint(0, view.frame.height), to: current.frame.origin)
                }
            }
            current.update(selected: selected, isArchive: arguments.isArchive, arguments: arguments)
        } else {
            
            if let view = self.panel, let superview = view.superview {
                performSubviewPosRemoval(view, pos: NSMakePoint(0, superview.frame.height + view.frame.height), animated: animated)
                self.panel = nil
            }
            
            if state.access(arguments.context.peerId), state.selectedCollection != State.Collection.all.stableId, let storyState = state.state, !storyState.items.isEmpty, let view = superview?.superview?.superview, state.onStage {
                let current: FolderPanel
                if let view = self.folderPanel {
                    current = view
                } else {
                    current = FolderPanel(frame: NSMakeRect(0, view.frame.height - 50, view.frame.width, 50))
                    self.folderPanel = current
                    view.addSubview(current)
                    
                    if animated {
                        current.layer?.animatePosition(from: NSMakePoint(0, view.frame.height), to: current.frame.origin)
                    }
                }
                current.update(collection: state.collection, arguments: arguments)
            } else if let view = self.folderPanel, let superview = view.superview {
                performSubviewPosRemoval(view, pos: NSMakePoint(0, superview.frame.height + view.frame.height), animated: animated)
                self.folderPanel = nil
            }
            
        }
        tableView.contentInsets = .init(top: 0, left: 0, bottom: self.panel != nil || folderPanel != nil ? 60 : 0, right: 0)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        if let panel = self.panel, let view = panel.superview {
            transition.updateFrame(view: panel, frame: NSMakeRect(0, view.frame.height - 50, view.frame.width, 50))
        }
        if let panel = self.folderPanel, let view = panel.superview {
            transition.updateFrame(view: panel, frame: NSMakeRect(0, view.frame.height - 50, view.frame.width, 50))
        }
        transition.updateFrame(view: tableView, frame: size.bounds)
    }
}

private struct StoryReferenceEntry : Comparable, Identifiable {
    var index: Int
    var story: EngineStoryItem
    
    var stableId: AnyHashable {
        return story.id
    }
    static func <(lhs: StoryReferenceEntry, rhs: StoryReferenceEntry) -> Bool {
        return lhs.index < rhs.index
    }
}


final class StoryMediaController : TelegramGenericViewController<StoryMediaView> {
    
    private let actionsDisposable = DisposableSet()
    private let collectionsDisposable = DisposableDict<Int64>()
    private var collectionsContexts:[Int64: PeerStoryListContext] = [:]

    private let peerId: EnginePeer.Id
    private let standalone: Bool
    private let isArchived: Bool
    private var statePromise: ValuePromise<State> = ValuePromise(ignoreRepeated: true)
    private var stateValue: Atomic<State> = Atomic(value: State(state: nil, selected: nil, perRowCount: 4))
    private let listContext: StoryListContext
    private let archiveContext: PeerStoryListContext?
    
    weak var parentController: PeerMediaController?
    
    private var peerListContext: PeerStoryListContext? {
        return listContext as? PeerStoryListContext
    }
    
    var currentContext: StoryListContext {
        let folderId = self.stateValue.with { $0.selectedCollection }
        if folderId == State.Collection.all.stableId {
            return self.listContext
        } else {
            return collectionsContexts[folderId] ?? self.listContext
        }
    }

    
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
    
    private func addCollection() {
        var text: String = ""
        //TODOLANG
        
        var footer: ModalAlertData.Footer = .init(value: { initialSize, stableId, presentation, updateData in
            return InputDataRowItem(initialSize, stableId: stableId, mode: .plain, error: nil, viewType: .singleItem, currentText: "", placeholder: nil, inputPlaceholder: "Title...", filter: { $0 }, updated: { updated in
                text = updated
                DispatchQueue.main.async(execute: updateData)
            }, limit: 16)
        })
        
        footer.validateData = { _ in
            if text.isEmpty {
                return .fail(.fields([InputDataIdentifier("footer") : .shake]))
            } else {
                return .none
            }
        }
        
        let data = ModalAlertData(title: "Create a New Folder", info: "Choose a name for your folder and start adding your stories there.", description: nil, ok: "Create", options: [], mode: .confirm(text: strings().modalCancel, isThird: false), footer: footer)
        
        if let window = self.window {
            showModalAlert(for: window, data: data, completion: { [weak self] result in
                self?.peerListContext?.addFolder(title: text, completion: { id in
                    self?.updateState { current in
                        var current = current
                        current.selectedCollection = id
                        return current
                    }
                })
            })
        }
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
        let stateValue = self.stateValue
        
        
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

    override func menuItems() -> [ContextMenuItem] {
        let state = stateValue.with { $0 }
        
        var items: [ContextMenuItem] = []
        
        
        items.append(ContextMenuItem(strings().chatContextEdit1, handler: { [weak self] in
            self?.parentController?.changeState()
        }, itemImage: MenuAnimation.menu_edit.value))
        
        //TODOLANG
        #if DEBUG
        if state.access(context.peerId), !self.isArchived {
            items.append(ContextSeparatorItem())
            items.append(ContextMenuItem("Add Folder", handler: { [weak self] in
               self?.addCollection()
           }, itemImage: MenuAnimation.menu_add.value))
        }
        #endif
        
        
        
       
        
        return items
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
    
    init(context: AccountContext, peerId: EnginePeer.Id, listContext: StoryListContext, standalone: Bool = false, isArchived: Bool = false) {
        self.peerId = peerId
        self.isArchived = isArchived
        self.standalone = standalone
        self.listContext = listContext
        if !isArchived {
            self.archiveContext = .init(account: context.account, peerId: peerId, isArchived: true, folderId: nil)
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
        
        
        genericView.tableView.set(stickClass: CollectionRowItem.self, handler: { _ in
            
        })
        
        genericView.willMove = { [weak self] window in
            self?.updateState { current in
                var current = current
                current.onStage = window != nil
                return current
            }
        }
        
        let context = self.context
        let peerId = self.peerId
        let initialSize = self.atomicSize
        let isArchived = self.isArchived
        
        genericView.tableView.getBackgroundColor = {
           return theme.colors.listBackground
        }
        
        genericView.tableView.setScrollHandler({ [weak self] _ in
            
            guard let self else {
                return
            }
            let state = self.stateValue.with { $0 }
            if state.selectedCollection == State.Collection.all.stableId {
                listContext.loadMore(completion: {
                    
                })
            } else {
                self.collectionsContexts[state.selectedCollection]?.loadMore(completion: {
                    
                })
            }
            
        })
        let maxPinLimit = context.appConfiguration.getGeneralValue("stories_pinned_to_top_count_max", orElse: 3)
        
        
        let renameCollection:(State.Collection)->Void = { [weak self] collection in
        
            switch collection {
            case let .collection(value):
                
                var text: String = ""
                //TODOLANG
                
                var footer: ModalAlertData.Footer = .init(value: { initialSize, stableId, presentation, updateData in
                    return InputDataRowItem(initialSize, stableId: stableId, mode: .plain, error: nil, viewType: .singleItem, currentText: value.title, placeholder: nil, inputPlaceholder: "Title...", filter: { $0 }, updated: { updated in
                        text = updated
                        DispatchQueue.main.async(execute: updateData)
                    }, limit: 16)
                })
                
                footer.validateData = { _ in
                    if text.isEmpty {
                        return .fail(.fields([InputDataIdentifier("footer") : .shake]))
                    } else {
                        return .none
                    }
                }
                
                let data = ModalAlertData(title: "Update Name", info: "Update a name for your folder.", description: nil, ok: "Update", options: [], mode: .confirm(text: strings().modalCancel, isThird: false), footer: footer)
                
                if let window = self?.window {
                    showModalAlert(for: window, data: data, completion: { result in
                        
                    })
                }
            default:
                break
            }
        }
        
        
        let addToCollection:(State.Collection, StoryListContextState.Item?)->Void = { [weak self] collection, story in
            
            guard let self, let window = self.window else {
                return
            }
            
            switch collection {
            case let .collection(value):
                
                let state = self.stateValue.with { $0 }
                
                let folderContext = self.collectionsContexts[value.id]

                
                if let story {
                    let contains = state.contains(collectionId: value.id, storyId: story.id)
                    //TODOLANG
                    if contains {
                        folderContext?.removeFromFolder(id: value.id, itemIds: [story.id.id])
                        showModalText(for: window, text: "Story removed from **\(value.title)**")
                    } else {
                        folderContext?.addToFolder(id: value.id, items: [story.storyItem])
                        showModalText(for: window, text: "Story added to **\(value.title)**")
                    }
                } else {
                    
                    let prevItems = stateValue.with { $0.collectionStates[value.id]?.items ?? [] }
//
                    var previous: [StoryReferenceEntry] = []
                    for i in 0 ..< prevItems.count {
                        previous.append(.init(index: i, story: prevItems[i].storyItem))
                    }
                    
                    if let folderContext = self.collectionsContexts[collection.stableId] {
                        showModal(with: SelectStoryModalController(context: context, peerId: peerId, listContext: self.peerListContext, folderContext: folderContext, callback: { [weak folderContext] result in
                            
                            var current: [StoryReferenceEntry] = []
                            for i in 0 ..< result.count {
                                current.append(.init(index: i, story: result[i]))
                            }
                            
                            let (deleteIndices, indicesAndItems) = mergeListsStable(leftList: previous, rightList: current)
                            
                            if !indicesAndItems.isEmpty {
                                folderContext?.addToFolder(id: collection.stableId, items: indicesAndItems.map(\.1.story))
                            }
                            if !deleteIndices.isEmpty {
                                let removeValue = deleteIndices.map { previous[$0] }
                                folderContext?.removeFromFolder(id: collection.stableId, itemIds: removeValue.map(\.story.id))
                            }
                            
                        }), for: context.window)
                    }
                }
                
            default:
                break
            }
        }

                
        self.setCenterTitle(isArchived ? strings().storyMediaTitleArchive : peerId == context.peerId ? strings().storyMediaTitleMyStories : "")
        
        let arguments = Arguments(context: context, standalone: standalone, isArchive: isArchived, isMy: peerId == context.peerId || isArchived, openStory: { [weak self] initialId in
            if let list = self?.currentContext {
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
            var pinned = Array(self?.stateValue.with ({ $0.state?.pinnedIds }) ?? [])
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
        }, collection: { [weak self] collection, story in
            if collection == .add {
                
                self?.addCollection()
            } else {
                self?.updateState { current in
                    var current = current
                    current.selectedCollection = collection.stableId
                    return current
                }
            }
            
            self?.parentController?.currentMainTableView?(self?.parentController?.genericView.mainTable, true, true)
            
        }, addToCollection: { collection, story in
    //        let state = stateValue.with { $0 }
    //        let collection = state.collections.first(where: { $0.stableId == state.selectedCollection }) ?? .all
            addToCollection(collection, story)
        }, collectionContextMenu: { [weak self] collection in
            
            guard let self else {
                return []
            }
            
            switch collection {
            case .add:
               return []
            case .all:
                return []
            case let .collection(value):
                var items: [ContextMenuItem] = []
                
                let state = self.stateValue.with { $0 }
                let access = state.access(context.peerId)

                if access {
                    //TODOLANG
                    items.append(ContextMenuItem("Add Stories", handler: {
                        addToCollection(collection, nil)
                    }, itemImage: MenuAnimation.menu_add.value))
                    
                    items.append(ContextMenuItem("Rename", handler: {
                        renameCollection(collection)
                    }, itemImage: MenuAnimation.menu_edit.value))
                    
                    items.append(ContextSeparatorItem())
                    
                    //TODOLANG
                    items.append(ContextMenuItem("Delete", handler: { [weak self] in
                        if let window = self?.window {
                            verifyAlert(for: window, information: "Are you sure you want to delete **\(value.title)**?", successHandler: { _ in
                                self?.peerListContext?.removeFolder(id: value.id)
                            })
                        }
                    }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                    
                }
               
                return items
            }
        }, resort: { [weak self] from, to in
            guard let self else {
                return
            }
            
            var list = self.stateValue.with { $0.collections }
            list.move(at: from, to: to)
            
            self.peerListContext?.reorderFolders(ids: list.compactMap { value in
                switch value {
                case let .collection(value):
                    return value.id
                default:
                    return nil
                }
            })
        })

        let stateSignal = listContext.state |> deliverOnMainQueue
        let peer = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        actionsDisposable.add(combineLatest(queue: .mainQueue(), stateSignal, peer).start(next: { [weak self] state, peer in
            
            guard let self else {
                return
            }
            
            self.updateState { current in
                var current = current
                current.collectionStates[State.Collection.all.stableId] = state
                current.peer = peer
                if !state.availableFolders.isEmpty {
                    current.collections = [.all] + state.availableFolders.map { .collection(value: $0) }
                    if current.access(context.peerId)  {
                        current.collections.append(.add)
                    }
                }
                if !current.collections.contains(where: { $0.stableId == current.selectedCollection }) {
                    current.selectedCollection = State.Collection.all.stableId
                }
                return current
            }
            if state.totalCount > 0 {
                self.setCenterStatus(strings().chatListArchiveStoryCountCountable(state.totalCount).lowercased())
            } else {
                self.setCenterStatus(nil)
            }
            
            var validKeys:Set<Int64> = Set()
            
            for collection in state.availableFolders {
                if self.collectionsContexts[collection.id] == nil {
                    let value = PeerStoryListContext(account: context.account, peerId: peerId, isArchived: self.isArchived, folderId: collection.id)
                    
                    self.collectionsContexts[collection.id] = value
                    self.collectionsDisposable.set(value.state.start(next: { [weak self] state in
                        self?.updateState { current in
                            var current = current
                            current.collectionStates[collection.id] = state
                            return current
                        }
                    }), forKey: collection.id)
                }
                validKeys.insert(collection.id)
            }
            
            var removeKeys:Set<Int64> = Set()
            for (key, _) in self.collectionsContexts {
                if !validKeys.contains(key) {
                    removeKeys.insert(key)
                }
            }
            for key in removeKeys {
                self.collectionsContexts.removeValue(forKey: key)
                self.collectionsDisposable.set(nil, forKey: key)
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    deinit {
        collectionsDisposable.dispose()
        actionsDisposable.dispose()
    }
}
