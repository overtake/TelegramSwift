//
//  StickersViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac


private struct ChatMediaInputGridTransition {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let updateFirstIndexInSectionOffset: Int?
    let stationaryItems: GridNodeStationaryItems
    let scrollToItem: GridNodeScrollToItem?
    let animated: Bool
}



private func preparedChatMediaInputGridEntryTransition(account: Account, from fromEntries: [AppearanceWrapperEntry<ChatMediaInputGridEntry>], to toEntries: [AppearanceWrapperEntry<ChatMediaInputGridEntry>], update: StickerPacksCollectionUpdate, inputNodeInteraction: EStickersInteraction) -> ChatMediaInputGridTransition {
    var stationaryItems: GridNodeStationaryItems = .none
    var scrollToItem: GridNodeScrollToItem?
    var animated: Bool = false
    switch update {
    case .generic:
        animated = true
    case .scroll:
        var fromStableIds = Set<ChatMediaInputGridEntryStableId>()
        for entry in fromEntries {
            fromStableIds.insert(entry.entry.stableId)
        }
        var index = 0
        var indices = Set<Int>()
        for entry in toEntries {
            if fromStableIds.contains(entry.entry.stableId) {
                indices.insert(index)
            }
            index += 1
        }
        stationaryItems = .indices(indices)
    case let .navigate(index):
        for i in 0 ..< toEntries.count {
            if toEntries[i].entry.index >= index {
                var directionHint: GridNodePreviousItemsTransitionDirectionHint = .up
                if !fromEntries.isEmpty && fromEntries[0].entry.index < toEntries[i].entry.index {
                    directionHint = .down
                }
                scrollToItem = GridNodeScrollToItem(index: i, position: .top, transition: .animated(duration: 0.45, curve: .spring), directionHint: directionHint, adjustForSection: true)
                break
            }
        }
    }
    
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.entry.item(account: account, inputNodeInteraction: inputNodeInteraction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.entry.item(account: account, inputNodeInteraction: inputNodeInteraction)) }
    
    var firstIndexInSectionOffset = 0
    if !toEntries.isEmpty {
        firstIndexInSectionOffset = Int(toEntries[0].entry.index.hashValue)
    }
    
    return ChatMediaInputGridTransition(deletions: deletions, insertions: insertions, updates: updates, updateFirstIndexInSectionOffset: firstIndexInSectionOffset, stationaryItems: stationaryItems, scrollToItem:scrollToItem, animated: animated)
}

fileprivate func preparePackEntries(from:[AppearanceWrapperEntry<ChatMediaInputPanelEntry>]?, to:[AppearanceWrapperEntry<ChatMediaInputPanelEntry>], account:Account, initialSize:NSSize, stickersInteraction:EStickersInteraction) -> TableUpdateTransition {
    
    let (deleted,inserted,updated) = proccessEntries(from, right: to, { (entry) -> TableRowItem in
        switch entry.entry {
        case let .stickerPack(index, stableId, info, topItem):
            return EStickerPackRowItem(initialSize, account, index, stableId, info, topItem, stickersInteraction)
        case .recent:
            return ERecentPackRowItem(initialSize, entry.entry.stableId, stickersInteraction)
        case .saved:
            return ERecentPackRowItem(initialSize, entry.entry.stableId, stickersInteraction)
        case let .specificPack(info, peer):
            return EStickerSpecificPackItem(initialSize, entry.entry.stableId, specificPack: (info, peer), account: account, stickersInteraction)
        }
    })

    return TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated:true, state: .none(nil))
    
}

private func chatMediaInputPanelEntries(view: ItemCollectionsView, orderedItemListViews:[OrderedItemListView], specificPack:(StickerPackCollectionInfo?, Peer?)) -> [ChatMediaInputPanelEntry] {
    var entries: [ChatMediaInputPanelEntry] = []
    var index = 0
//    
    if !orderedItemListViews[1].items.isEmpty {
        entries.append(.saved)
    }
    
    if !orderedItemListViews[0].items.isEmpty {
        entries.append(.recent)
    }
    
    if let info = specificPack.0, let peer = specificPack.1 {
        entries.append(.specificPack(info: info, peer: peer))
    }

    for (_, info, item) in view.collectionInfos {
        if let info = info as? StickerPackCollectionInfo {
            entries.append(.stickerPack(index: index, stableId: .pack(info.id), info: info, topItem: item as? StickerPackItem))
            index += 1
        }
    }
    entries.sort(by: <)
    return entries
}

private func chatMediaInputGridEntries(view: ItemCollectionsView, orderedItemListViews:[OrderedItemListView], specificPack:(StickerPackCollectionInfo, [ItemCollectionItem])?) -> [ChatMediaInputGridEntry] {
    var entries: [ChatMediaInputGridEntry] = []
    
    var stickerPackInfos: [ItemCollectionId: StickerPackCollectionInfo] = [:]
    for (id, info, _) in view.collectionInfos {
        if let info = info as? StickerPackCollectionInfo {
            stickerPackInfos[id] = info
        }
    }
    
    var fileIds:[MediaId: MediaId] = [:]
    
    var j:Int = 0
    for item in orderedItemListViews[1].items {
        if let entry = item.contents as? SavedStickerItem {
            if let id = entry.file.id, fileIds[id] == nil {
                fileIds[id] = id
                entries.append(ChatMediaInputGridEntry(index: .saved(j), file: entry.file, packInfo: .saved, _stableId: .saved(entry.file), collectionId: .saved))
                j += 1
            }
           
        }
    }
    
    var i:Int = 0
    for item in orderedItemListViews[0].items {
        if let entry = item.contents as? RecentMediaItem {
            if let file = entry.media as? TelegramMediaFile, let id = file.id, fileIds[id] == nil {
                fileIds[id] = id
                entries.append(ChatMediaInputGridEntry(index: .recent(i), file: file, packInfo: .recent, _stableId: .recent(file), collectionId: .recent))
                i += 1
            }
            
        }
    }
    
    if let specificPack = specificPack {
        for entry in specificPack.1 {
            if let item = entry as? StickerPackItem {
                entries.append(ChatMediaInputGridEntry(index: .speficicSticker(entry.index), file: item.file, packInfo: .speficicPack(specificPack.0), _stableId: .speficicSticker(specificPack.0.id, entry.index.id), collectionId: .specificPack(specificPack.0.id)))
            }
        }
    }

    for entry in view.entries {
        if let item = entry.item as? StickerPackItem {
            entries.append(ChatMediaInputGridEntry(index: .sticker(entry.index), file: item.file, packInfo: .pack(stickerPackInfos[entry.index.collectionId]), _stableId: .sticker(entry.index.collectionId, entry.index.itemIndex.id), collectionId: .pack(entry.index.collectionId)))
        }
    }
    return entries
}

private enum StickerPacksCollectionPosition: Equatable {
    case initial
    case scroll(aroundIndex: ChatMediaInputGridIndex)
    case navigate(index: ChatMediaInputGridIndex)
    
    static func ==(lhs: StickerPacksCollectionPosition, rhs: StickerPacksCollectionPosition) -> Bool {
        switch lhs {
        case .initial:
            if case .initial = rhs {
                return true
            } else {
                return false
            }
        case let .scroll(aroundIndex):
            if case .scroll(aroundIndex) = rhs {
                return true
            } else {
                return false
            }
        case .navigate:
            return false
        }
    }
}

private enum StickerPacksCollectionUpdate {
    case generic
    case scroll
    case navigate(ChatMediaInputGridIndex)
}

final class EStickersInteraction {
    let navigateToCollectionId: (ChatMediaGridCollectionStableId) -> Void
    
    let sendSticker:(TelegramMediaFile) -> Void
    let previewStickerSet:(StickerPackReference) -> Void
    
    var highlightedItemCollectionId: ChatMediaGridCollectionStableId?
    
    init(navigateToCollectionId: @escaping (ChatMediaGridCollectionStableId) -> Void, sendSticker: @escaping(TelegramMediaFile)-> Void, previewStickerSet: @escaping(StickerPackReference)-> Void) {
        self.navigateToCollectionId = navigateToCollectionId
        self.sendSticker = sendSticker
        self.previewStickerSet = previewStickerSet
    }
}


class StickersControllerView : View {
    fileprivate var gridView:GridNode
    fileprivate var packsTable:HorizontalTableView
    private var separator:View!
    fileprivate var restrictedView:RestrictionWrappedView?
    required init(frame frameRect: NSRect) {
        self.gridView = GridNode(frame:NSZeroRect)
        self.packsTable = HorizontalTableView(frame: NSZeroRect)
        separator = View(frame: NSMakeRect(0,0,frameRect.width,.borderSize))
        separator.backgroundColor = .border
       
        super.init(frame: frameRect)
        
        addSubview(gridView)
        addSubview(packsTable)
        addSubview(separator)
        updateLocalizationAndTheme()
    }
    
    func updateRestricion(_ peer: Peer?) {
        if let peer = peer as? TelegramChannel {
            if peer.stickersRestricted, let bannedRights = peer.bannedRights {
                restrictedView = RestrictionWrappedView(bannedRights.untilDate != .max ? tr(.channelPersmissionDeniedSendStickersUntil(bannedRights.formattedUntilDate)) : tr(.channelPersmissionDeniedSendStickersForever))
                addSubview(restrictedView!)
            } else {
                restrictedView?.removeFromSuperview()
                restrictedView = nil
            }
        } else {
            restrictedView?.removeFromSuperview()
            restrictedView = nil
        }
        setFrameSize(frame.size)
        needsLayout = true
    }
    
    override func updateLocalizationAndTheme() {
        self.restrictedView?.updateLocalizationAndTheme()
        self.separator.backgroundColor = theme.colors.border
        gridView.updateLocalizationAndTheme()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        gridView.setFrameSize(frame.width, frame.height - 50)
        packsTable.setFrameSize(frame.width - 6.0, 49)
        separator.setFrameSize(frame.width, .borderSize)
        restrictedView?.setFrameSize(newSize)
    }
    
    override func layout() {
        super.layout()
        packsTable.setFrameOrigin(3, frame.height - 50)
        separator.setFrameOrigin(0, gridView.frame.maxY)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class StickersViewController: GenericViewController<StickersControllerView>, TableViewDelegate, Notifable {
    
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    
    private var interactions:EntertainmentInteractions?
    private var chatInteraction:ChatInteraction?
    private var account:Account

    private let peerIdPromise: ValuePromise<PeerId> = ValuePromise(ignoreRepeated: true)
    
    private let itemCollectionsViewPosition = Promise<StickerPacksCollectionPosition>()
    private var currentStickerPacksCollectionPosition: StickerPacksCollectionPosition?
    private var currentView: ItemCollectionsView?
    
    private(set) var inputNodeInteraction: EStickersInteraction!
    private let disposable = MetaDisposable()
    
    
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return true
    }
//    
    func selectionWillChange(row: Int, item: TableRowItem) -> Bool {
        return true
    }
//    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) {
        
    }
    
    func update(with interactions:EntertainmentInteractions, chatInteraction: ChatInteraction) {
        self.interactions = interactions
        self.chatInteraction?.remove(observer: self)
        self.chatInteraction = chatInteraction
        self.peerIdPromise.set(chatInteraction.peerId)
        chatInteraction.add(observer: self)
        if isLoaded() {
            genericView.updateRestricion(chatInteraction.presentation.peer)
        }
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState, let peer = value.peer, let oldPeer = oldValue.peer {
            if peer.stickersRestricted != oldPeer.stickersRestricted {
                genericView.updateRestricion(peer)
            }
        }
    }
    
    override func updateLocalizationAndTheme() {
        genericView.updateLocalizationAndTheme()
    }
    
    func isEqual(to other: Notifable) -> Bool {
        return other === self
    }
    
    
    init(account:Account) {
        self.account = account
        super.init()
        self.bar = NavigationBarStyle(height: 0)
        
        self.inputNodeInteraction = EStickersInteraction(navigateToCollectionId: { [weak self] collectionId in
            if let strongSelf = self, let currentView = strongSelf.currentView, collectionId != strongSelf.inputNodeInteraction.highlightedItemCollectionId {
                switch collectionId {
                case .pack(let itemCollectionId):
                    var index: Int32 = 0
                    for (id, _, _) in currentView.collectionInfos {
                        if id == itemCollectionId {
                            let itemIndex = ItemCollectionViewEntryIndex.lowerBound(collectionIndex: index, collectionId: id)
                            strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: .sticker(itemIndex))))
                            return
                        }
                        index += 1
                    }
                case .saved:
                    strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: .saved(0))))
                case .recent:
                    strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: .recent(0))))
                case .specificPack:
                    strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: .speficicSticker(ItemCollectionItemIndex(index: 0, id: 0)))))
                }
                

            }
        }, sendSticker: { [weak self] file in
            self?.interactions?.sendSticker(file)
        }, previewStickerSet: { [weak self] reference in
            if let eInteraction = self?.interactions, let account = self?.account {
                self?.account.context.entertainment.popover?.hide()
                showModal(with: StickersPackPreviewModalController(account, peerId: eInteraction.peerId, reference: reference), for: mainWindow)
            }
        })
        
        
    }
    
    deinit {
        disposable.dispose()
        chatInteraction?.remove(observer: self)
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        let layout = GridNodeLayout(size: CGSize(width: frame.width, height: frame.height - 50), insets: NSEdgeInsets(left: 10, right: 10, top: 10), preloadSize: size.height, type: .fixed(itemSize: CGSize(width: 80, height: 80), lineSpacing: 0))
        let updateLayout = GridNodeUpdateLayout(layout: layout, transition: .immediate)
        
        self.genericView.gridView.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: updateLayout, itemTransition: .immediate, stationaryItems: .all, updateFirstIndexInSectionOffset: nil), completion: { _ in })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let chatInteraction = chatInteraction {
            genericView.updateRestricion(chatInteraction.presentation.peer)
        }
        let account = self.account
        genericView.packsTable.delegate = self
        

        let itemCollectionsView = itemCollectionsViewPosition.get() |> distinctUntilChanged
            |> mapToSignal { position -> Signal<(ItemCollectionsView, StickerPacksCollectionUpdate), NoError> in
                
                switch position {
                case .initial:
                    return account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudSavedStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: 50)
                        |> map { view  in
                            return (view, .generic)
                    }
                case let .scroll(aroundIndex):
                    var firstTime = true
                    
                     return account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudSavedStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: aroundIndex.packIndex, count: 200)
                        |> map { view  in
                            let update: StickerPacksCollectionUpdate
                            if firstTime {
                                firstTime = false
                                update = .scroll
                            } else {
                                update = .generic
                            }
                            return (view, update)
                    }
                case let .navigate(index):
                    var firstTime = true
                    return account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudSavedStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: index.packIndex, count: 140)
                        |> map { view in
                            let update: StickerPacksCollectionUpdate
                            if firstTime {
                                firstTime = false
                                update = .navigate(index)
                            } else {
                                update = .generic
                            }
                            return (view, update)
                    }
                }
        }
        
        let previousEntries = Atomic<([AppearanceWrapperEntry<ChatMediaInputPanelEntry>],[AppearanceWrapperEntry<ChatMediaInputGridEntry>])>(value: ([],[]))
                
        let inputNodeInteraction = self.inputNodeInteraction!
        let initialSize = atomicSize
        
        let transitions = combineLatest(itemCollectionsView |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue, peerIdPromise.get() |> mapToSignal {
            
            combineLatest(account.viewTracker.peerView($0) |> take(1) |> map {peerViewMainPeer($0)}, peerSpecificStickerPack(postbox: account.postbox, network: account.network, peerId: $0))
            
        } |> deliverOnPrepareQueue)
        |> map { itemsView, appearance, specificData -> (ItemCollectionsView, TableUpdateTransition, Bool, ChatMediaInputGridTransition, Bool) in
            
            let update: StickerPacksCollectionUpdate = itemsView.1
            
            let gridEntries = chatMediaInputGridEntries(view: itemsView.0, orderedItemListViews: itemsView.0.orderedItemListsViews, specificPack: specificData.1)
            let panelEntries = chatMediaInputPanelEntries(view: itemsView.0, orderedItemListViews: itemsView.0.orderedItemListsViews, specificPack: (specificData.1?.0, specificData.0))
            
            let panelEntriesMapped = panelEntries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            let gridEntriesMapped = gridEntries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            
            let (previousPanelEntries, previousGridEntries) = previousEntries.swap((panelEntriesMapped, gridEntriesMapped))
            
            return (itemsView.0, preparePackEntries(from: previousPanelEntries, to: panelEntriesMapped, account: account, initialSize: initialSize.modify({$0}), stickersInteraction:inputNodeInteraction),previousPanelEntries.isEmpty, preparedChatMediaInputGridEntryTransition(account: account, from: previousGridEntries, to: gridEntriesMapped, update: update, inputNodeInteraction: inputNodeInteraction), previousGridEntries.isEmpty)
        }
        
        self.disposable.set((transitions |> deliverOnMainQueue).start(next: { [weak self] (view, packsTransition, packsFirstTime, gridTransition, gridFirstTime) in
            if let strongSelf = self {
                
                strongSelf.currentView = view
                strongSelf.genericView.packsTable.merge(with: packsTransition)
                strongSelf.enqueueGridTransition(gridTransition, firstTime: gridFirstTime)
                
                if packsFirstTime {
                    strongSelf.readyOnce()
                    if !strongSelf.genericView.packsTable.isEmpty {
                        let stableId = strongSelf.genericView.packsTable.item(at: 0).stableId
                        strongSelf.genericView.packsTable.changeSelection(stableId: stableId)
                    }
                }
            }
        }))
        
        genericView.gridView.visibleItemsUpdated = { [weak self] visibleItems in
            if let strongSelf = self {
                if let topVisible = visibleItems.topVisible {
                    if let item = topVisible.1 as? StickerGridItem {
                        let collectionId = item.collectionId
                        if strongSelf.inputNodeInteraction.highlightedItemCollectionId != collectionId {
                            strongSelf.inputNodeInteraction.highlightedItemCollectionId = collectionId
                            strongSelf.genericView.packsTable.scroll(to: .center(id: collectionId, animated: true, focus: false, inset: 0))
                            strongSelf.genericView.packsTable.changeSelection(stableId: collectionId)
                        }
                    }
                }
                
                if let currentView = strongSelf.currentView, let (topIndex, _) = visibleItems.top, let (bottomIndex, _) = visibleItems.bottom {
                    if topIndex <= 5, let lower = currentView.lower {
                        let position: StickerPacksCollectionPosition = .scroll(aroundIndex: .sticker(lower.index))
                        if strongSelf.currentStickerPacksCollectionPosition != position {
                            strongSelf.currentStickerPacksCollectionPosition = position
                            strongSelf.itemCollectionsViewPosition.set(.single(position))
                        }
                    } else if bottomIndex >= visibleItems.count - 5, let higher = currentView.higher {
                        let position: StickerPacksCollectionPosition = .scroll(aroundIndex: .sticker(higher.index))
                        if strongSelf.currentStickerPacksCollectionPosition != position {
                            strongSelf.currentStickerPacksCollectionPosition = position
                            strongSelf.itemCollectionsViewPosition.set(.single(position))
                        }
                    }
                }
            }
        }
        
        self.currentStickerPacksCollectionPosition = .initial
        self.itemCollectionsViewPosition.set(.single(.initial))
        
    }
    

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        genericView.packsTable.clipView.scroll(to: NSZeroPoint)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    private func enqueueGridTransition(_ transition: ChatMediaInputGridTransition, firstTime: Bool) {
        genericView.gridView.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: transition.scrollToItem, updateLayout: nil, itemTransition: .immediate, stationaryItems: transition.stationaryItems, updateFirstIndexInSectionOffset: transition.updateFirstIndexInSectionOffset), completion: { _ in })
    }
    
}
