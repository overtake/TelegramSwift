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

private func chatMediaInputPanelEntries(view: (ItemCollectionsView?, (FoundStickerSets?, Bool)?), orderedItemListViews:[OrderedItemListView]?, specificPack:(StickerPackCollectionInfo?, Peer?)?) -> [ChatMediaInputPanelEntry] {
    var entries: [ChatMediaInputPanelEntry] = []
    var index = 0

    if let orderedItemListViews = orderedItemListViews {
        if !orderedItemListViews[1].items.isEmpty {
            entries.append(.saved)
        }
        
        if !orderedItemListViews[0].items.isEmpty {
            entries.append(.recent)
        }
    }
   
    
    if let info = specificPack?.0, let peer = specificPack?.1 {
        entries.append(.specificPack(info: info, peer: peer))
    }

    if let collectionInfos = view.0?.collectionInfos {
        for (_, info, item) in collectionInfos {
            if let info = info as? StickerPackCollectionInfo {
                entries.append(.stickerPack(index: index, stableId: .pack(info.id), info: info, topItem: item as? StickerPackItem))
                index += 1
            }
        }
    }
//    else if let result = view.1?.0?.infos {
//        for (_, info, item) in result {
//            if let info = info as? StickerPackCollectionInfo {
//                entries.append(.stickerPack(index: index, stableId: .pack(info.id), info: info, topItem: item as? StickerPackItem))
//                index += 1
//            }
//        }
//    }
    
    entries.sort(by: <)
    return entries
}

private func chatMediaInputGridEntries(view: (ItemCollectionsView?, (FoundStickerSets?, Bool)?), orderedItemListViews:[OrderedItemListView]?, specificPack:(StickerPackCollectionInfo, [ItemCollectionItem])?) -> [ChatMediaInputGridEntry] {
    var entries: [ChatMediaInputGridEntry] = []
    
    var stickerPackInfos: [ItemCollectionId: StickerPackCollectionInfo] = [:]
    
    var itemEntries:[ItemCollectionViewEntry] = []
    var installedPacks: [ItemCollectionId: Bool] = [:]
    
    if let itemsView = view.0 {
        for (id, info, _) in itemsView.collectionInfos {
            if let info = info as? StickerPackCollectionInfo {
                stickerPackInfos[id] = info
                installedPacks[id] = true
            }
        }
        itemEntries.append(contentsOf: itemsView.entries)
    } else if let result = view.1?.0 {
        for found in result.infos {
            if let info = found.1 as? StickerPackCollectionInfo {
                stickerPackInfos[found.0] = info
                installedPacks[found.0] = found.3

            }
        }
        itemEntries.append(contentsOf: result.entries)
    }
    
    
    if let orderedItemListViews = orderedItemListViews {
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
        for item in Array(orderedItemListViews[0].items.prefix(20)) {
            if let entry = item.contents as? RecentMediaItem {
                if let file = entry.media as? TelegramMediaFile, let id = file.id, fileIds[id] == nil {
                    fileIds[id] = id
                    entries.append(ChatMediaInputGridEntry(index: .recent(i), file: file, packInfo: .recent, _stableId: .recent(file), collectionId: .recent))
                    i += 1
                }
                
            }
        }
    }
    
    
    if let specificPack = specificPack, view.1 == nil {
        for entry in specificPack.1 {
            if let item = entry as? StickerPackItem {
                entries.append(ChatMediaInputGridEntry(index: .speficicSticker(entry.index), file: item.file, packInfo: .speficicPack(specificPack.0), _stableId: .speficicSticker(specificPack.0.id, entry.index.id), collectionId: .specificPack(specificPack.0.id)))
            }
        }
    }

    for entry in itemEntries {
        if let item = entry.item as? StickerPackItem {
            entries.append(ChatMediaInputGridEntry(index: .sticker(entry.index), file: item.file, packInfo: .pack(stickerPackInfos[entry.index.collectionId], installedPacks[entry.index.collectionId] ?? true), _stableId: .sticker(entry.index.collectionId, entry.index.itemIndex.id), collectionId: .pack(entry.index.collectionId)))
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
    let addStickerSet: (StickerPackReference) -> Void
    var highlightedItemCollectionId: ChatMediaGridCollectionStableId?
    var showStickerPack: (StickerPackReference)->Void
    init(navigateToCollectionId: @escaping (ChatMediaGridCollectionStableId) -> Void, sendSticker: @escaping(TelegramMediaFile)-> Void, previewStickerSet: @escaping(StickerPackReference)-> Void, addStickerSet:@escaping(StickerPackReference) -> Void, showStickerPack: @escaping(StickerPackReference)->Void) {
        self.navigateToCollectionId = navigateToCollectionId
        self.sendSticker = sendSticker
        self.previewStickerSet = previewStickerSet
        self.addStickerSet = addStickerSet
        self.showStickerPack = showStickerPack
    }
}


class StickersControllerView : View {
    fileprivate var gridView:GridNode
    fileprivate var packsTable:HorizontalTableView
    private var separator:View!
    fileprivate let searchView: SearchView
    fileprivate let tabsContainer: View = View()
    private let searchContainer: View = View()
    fileprivate var restrictedView:RestrictionWrappedView?
    private let emptySearchView = ImageView()
    private let emptySearchContainer: View = View()
    private let progressView = ProgressIndicator(frame: NSMakeRect(0, 0, 30, 30))
    required init(frame frameRect: NSRect) {
        searchView = SearchView(frame: NSMakeRect(0,0, frameRect.width - 20, 30))
        self.gridView = GridNode(frame:NSZeroRect)
        self.packsTable = HorizontalTableView(frame: NSZeroRect)
        separator = View(frame: NSMakeRect(0,0,frameRect.width,.borderSize))
        separator.backgroundColor = .border
       
        super.init(frame: frameRect)
        
        searchContainer.addSubview(searchView)
        addSubview(gridView)
        addSubview(searchContainer)
        
        emptySearchContainer.addSubview(emptySearchView)
        addSubview(progressView)
        tabsContainer.addSubview(packsTable)
        tabsContainer.addSubview(separator)
        addSubview(tabsContainer)
        addSubview(emptySearchContainer)
        
        emptySearchContainer.isHidden = true
        progressView.isHidden = true
        emptySearchContainer.isEventLess = true
        progressView.isEventLess = true
        
        updateLocalizationAndTheme()
    }
    
    func updateRestricion(_ peer: Peer?) {
        if let peer = peer as? TelegramChannel {
            if peer.stickersRestricted, let bannedRights = peer.bannedRights {
                restrictedView?.removeFromSuperview()
                restrictedView = RestrictionWrappedView(bannedRights.untilDate != .max ? tr(L10n.channelPersmissionDeniedSendStickersUntil(bannedRights.formattedUntilDate)) : tr(L10n.channelPersmissionDeniedSendStickersForever))
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
    
    func updateEmpties(isEmpty: Bool, isLoading: Bool, animated: Bool) {
        
        let emptySearchHidden: Bool = !isEmpty || isLoading
        
        if !emptySearchHidden {
            emptySearchContainer.isHidden = false
        }
        if isLoading {
            progressView.isHidden = false
        }
        
        emptySearchContainer.change(opacity: emptySearchHidden ? 0 : 1, animated: animated, completion: { [weak self] completed in
            if completed {
                self?.emptySearchContainer.isHidden = emptySearchHidden
            }
        })

        progressView.change(opacity: !isLoading ? 0 : 1, animated: animated, completion: { [weak self] completed in
            if completed {
                self?.progressView.isHidden = !isLoading
            }
        })
        needsLayout = true
    }
    
    func hidePacks(_ hide: Bool, _ animated: Bool) {
        tabsContainer.change(pos: NSMakePoint(0, frame.height - (hide ? 0 : 50)), animated: animated)
        //tabsContainer.change(opacity: hide ? 0 : 1, animated: true)
        gridView.change(size: NSMakeSize(frame.width, frame.height - searchContainer.frame.maxY - (hide ? 0 : tabsContainer.frame.height)), animated: animated)
        needsLayout = true
    }
    
    override func updateLocalizationAndTheme() {
        self.restrictedView?.updateLocalizationAndTheme()
        self.separator.backgroundColor = theme.colors.border
        gridView.updateLocalizationAndTheme()
        gridView.backgroundColor = theme.colors.background
        gridView.documentView?.background = theme.colors.background
        searchContainer.backgroundColor = theme.colors.background
        emptySearchView.image = theme.icons.stickersEmptySearch
        emptySearchView.sizeToFit()
        emptySearchContainer.backgroundColor = theme.colors.background
        searchView.updateLocalizationAndTheme()
        progressView.updateLocalizationAndTheme()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    override func layout() {
        super.layout()
        searchContainer.setFrameSize(NSMakeSize(frame.width, 50))
        
        tabsContainer.frame = NSMakeRect(0, frame.height - (searchView.query.isEmpty ? 50 : 0), frame.width, 50)
        separator.frame = NSMakeRect(0, 0, tabsContainer.frame.width, .borderSize)
        packsTable.frame = tabsContainer.focus(NSMakeSize(frame.width - 6.0, 50))
        
        gridView.frame = NSMakeRect(0, searchContainer.frame.maxY, frame.width, frame.height - (searchView.query.isEmpty ? 50 : 0) - searchContainer.frame.height)
        restrictedView?.setFrameSize(frame.size)
        searchView.center()
        progressView.center()
        
        emptySearchContainer.frame = NSMakeRect(0, searchContainer.frame.maxY, frame.width, frame.height - searchContainer.frame.maxY)
        emptySearchView.center()
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
    private var collectionInfos: [(ItemCollectionId, ItemCollectionInfo, ItemCollectionItem?, Bool)]?
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
            if let strongSelf = self, collectionId != strongSelf.inputNodeInteraction.highlightedItemCollectionId {
                
                switch collectionId {
                case .pack(let itemCollectionId):
                    
                    if let infos = strongSelf.collectionInfos {
                        var index: Int32 = 0
                        for (id, _, _, _) in infos {
                            if id == itemCollectionId {
                                let itemIndex = ItemCollectionViewEntryIndex.lowerBound(collectionIndex: index, collectionId: id)
                                strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: .sticker(itemIndex))))
                                return
                            }
                            index += 1
                        }
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
        }, addStickerSet: { [weak self] reference in
            guard let `self` = self else {return}
            
            self.genericView.searchView.change(state: .None, true)
            
            _ = showModalProgress(signal: loadedStickerPack(postbox: account.postbox, network: account.network, reference: reference)
                |> filter { result in
                    switch result {
                    case .result:
                        return true
                    default:
                        return false
                    }
                }
                |> take(1)
                |> mapToSignal { result -> Signal<ItemCollectionId, Void> in
                    switch result {
                    case let .result(info, items, _):
                        return addStickerPackInteractively(postbox: account.postbox, info: info, items: items) |> map { info.id }
                    default:
                        return .complete()
                    }
                }
                |> deliverOnMainQueue, for: mainWindow).start(next: { [weak self] result in
                    delay(0.2, closure: {
                        self?.inputNodeInteraction.navigateToCollectionId(.pack(result))
                    })
                })
            
        }, showStickerPack: { [weak self] reference in
            guard let `self` = self else {return}
            let peerId = self.chatInteraction?.peerId
            switch reference {
            case let .id(id, _):
                let signal = account.postbox.transaction { transaction -> Bool in
                    return transaction.getItemCollectionInfo(collectionId: ItemCollectionId(namespace: Namespaces.ItemCollection.CloudStickerPacks, id: id)) != nil
                } |> deliverOnMainQueue

                _ = signal.start(next: { [weak self] installed in
                    if installed {
                        self?.inputNodeInteraction.navigateToCollectionId(.pack(ItemCollectionId(namespace: Namespaces.ItemCollection.CloudStickerPacks, id: id)))
                    } else {
                        showModal(with: StickersPackPreviewModalController(account, peerId: peerId, reference: reference), for: mainWindow)
                        self?.closePopover()
                    }
                })
            default:
                showModal(with: StickersPackPreviewModalController(account, peerId: peerId, reference: reference), for: mainWindow)
                self.closePopover()
            }
            
        })
        
        
    }
    
    deinit {
        disposable.dispose()
        chatInteraction?.remove(observer: self)
    }
    
    private var requestCount: Int = 150
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        let layout = GridNodeLayout(size: CGSize(width: frame.width - 20, height: frame.height - 50), insets: NSEdgeInsets(left: 0, right: 0, top: 0), preloadSize: size.height, type: .fixed(itemSize: CGSize(width: 60, height: 60), lineSpacing: 0))
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
        
        
        let search:ValuePromise<SearchState> = ValuePromise(SearchState(state: .None, request: nil), ignoreRepeated: true)

        let searchInteractions = SearchInteractions({ [weak self] state in
            search.set(state)
            if state.request.isEmpty {
                self?.itemCollectionsViewPosition.set(.single(.initial))
            }
            self?.genericView.hidePacks(!state.request.isEmpty, true)
            self?.scrollup()
        }, { [weak self] state in
           search.set(state)
            if state.request.isEmpty {
                self?.itemCollectionsViewPosition.set(.single(.initial))
            }
            self?.genericView.hidePacks(!state.request.isEmpty, true)
            self?.scrollup()
        })
        
        
        let requestCount:()->Int = { [weak self] in
            return self?.requestCount ?? 250
        }
        
        
        genericView.searchView.searchInteractions = searchInteractions

        let itemCollectionsView = combineLatest(itemCollectionsViewPosition.get()
            |> distinctUntilChanged
            |> deliverOnMainQueue
            |> beforeNext { [weak self] position -> StickerPacksCollectionPosition in
                self?.requestCount += 200
                return position
            }, search.get() |> deliverOnMainQueue)
            |> mapToSignal { position, search -> Signal<((ItemCollectionsView?, (FoundStickerSets?, Bool)?), StickerPacksCollectionUpdate), NoError> in
                
                if search.request.isEmpty {
                    switch position {
                    case .initial:
                        return account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudSavedStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: requestCount())
                            |> map { view  in
                                return ((view, nil), .generic)
                        }
                    case let .scroll(aroundIndex):
                        var firstTime = true
                        
                        return account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudSavedStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: aroundIndex.packIndex, count: requestCount())
                            |> map { view  in
                                let update: StickerPacksCollectionUpdate
                                if firstTime {
                                    firstTime = false
                                    update = .scroll
                                } else {
                                    update = .generic
                                }
                                return ((view, nil), update)
                        }
                    case let .navigate(index):
                        var firstTime = true
                        return account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudSavedStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: index.packIndex, count: requestCount())
                            |> map { view in
                                let update: StickerPacksCollectionUpdate
                                if firstTime {
                                    firstTime = false
                                    update = .navigate(index)
                                } else {
                                    update = .generic
                                }
                                return ((view, nil), update)
                        }
                    }
                } else {
                    var firstTime = true
                    if search.request.isSingleEmoji {
                        return searchStickers(account: account, query: search.request) |> map { stickers in
                            //((ItemCollectionsView?, (FoundStickerSets?, Bool)?), StickerPacksCollectionUpdate)
                            var index:Int32 = 0
                            var items: [ItemCollectionItem] = []

                            for sticker in stickers {
                                let file = sticker.file
                                if let id = file.id {
                                    items.append(StickerPackItem(index: ItemCollectionItemIndex(index: Int32(items.count), id: id.id), file: file, indexKeys: []))
                                }
                            }
                            var entries: [ItemCollectionViewEntry] = []
                            for item in items {
                                entries.append(ItemCollectionViewEntry(index: ItemCollectionViewEntryIndex.lowerBound(collectionIndex: -1, collectionId: ItemCollectionId(namespace: 0, id: 0)), item: item))
                                
                                index += 1
                            }
                            return ((nil, (FoundStickerSets(entries: entries), false)), .generic)
                        }
                    } else {
                        return searchEmojiClue(query: search.request, postbox: account.postbox) |> mapToSignal { clues in
                            if clues.isEmpty {
                                return combineLatest(searchStickerSets(postbox: account.postbox, query: search.request.lowercased()) |> map {Optional($0)}, Signal<FoundStickerSets?, Void>.single(nil) |> then(searchStickerSetsRemotely(network: account.network, query: search.request) |> map {Optional($0)}))  |> map { local, remote in
                                    let update: StickerPacksCollectionUpdate
                                    if firstTime {
                                        firstTime = remote == nil
                                        switch position {
                                        case .initial:
                                            update = .generic
                                        case .scroll:
                                            update = .scroll
                                        case let .navigate(index):
                                            update = .navigate(index)
                                        }
                                    } else {
                                        update = .generic
                                    }
                                    
                                    var value = FoundStickerSets()
                                    if let local = local {
                                        value = value.merge(with: local)
                                    }
                                    if let remote = remote {
                                        value = value.merge(with: remote)
                                    }
                                    return ((nil, (value, remote == nil && value.entries.isEmpty)), update)
                                }
                            } else {
                                return combineLatest(combineLatest(clues.map({searchStickers(account: account, query: $0.emoji)})), searchStickerSets(postbox: account.postbox, query: search.request.lowercased()) |> map {Optional($0)}, Signal<FoundStickerSets?, Void>.single(nil) |> then(searchStickerSetsRemotely(network: account.network, query: search.request) |> map {Optional($0)})) |> map { clueSets, local, remote in
                                    var index:Int32 = randomInt32()
                                   //
                                    var sortedStickers:[String : (Int32, [ItemCollectionViewEntry])] = [:]
                                    
                                    for stickers in clueSets {
                                        for sticker in stickers {
                                            let file = sticker.file
                                            if let id = file.id {
                                                if let emoji = file.stickerText?.fixed {
                                                    var values = sortedStickers[emoji] ?? (index, [])
                                                    let count = sortedStickers.reduce(0, { current, value  in
                                                        return current + values.1.count
                                                    })
                                                    let item = StickerPackItem(index: ItemCollectionItemIndex(index: Int32(count), id: id.id), file: file, indexKeys: [])
                                                    values.1.append(ItemCollectionViewEntry(index: ItemCollectionViewEntryIndex.lowerBound(collectionIndex: -(values.0), collectionId: ItemCollectionId(namespace: 0, id: ItemCollectionId.Id(values.0))), item: item))
                                                    sortedStickers[emoji] = values
                                                }
                                            }
                                        }
                                        index = randomInt32()
                                    }
                                    var entries: [ItemCollectionViewEntry] = []
                                    for clue in clues {
                                        if let stickers = sortedStickers[clue.emoji] {
                                            entries.append(contentsOf: stickers.1)
                                        }
                                    }
                                    
                                    let clueValues = FoundStickerSets(entries: entries)
                                    
                                    let update: StickerPacksCollectionUpdate
                                    if firstTime {
                                        firstTime = remote == nil
                                        switch position {
                                        case .initial:
                                            update = .generic
                                        case .scroll:
                                            update = .scroll
                                        case let .navigate(index):
                                            update = .navigate(index)
                                        }
                                    } else {
                                        update = .generic
                                    }
                                    
                                    var value = FoundStickerSets()
                                    if let local = local {
                                        value = value.merge(with: local)
                                    }
                                    if let remote = remote {
                                        value = value.merge(with: remote)
                                    }
                                    value = clueValues.merge(with: value)
                                    return ((nil, (value, remote == nil && value.entries.isEmpty)), update)
                                }
                            }
                            
                        }
                        
                    }
                    //searchStickerSetsRemotly(network: account.network, query: search.request)))
                   
                }
                
        }
        
        let previousEntries = Atomic<([AppearanceWrapperEntry<ChatMediaInputPanelEntry>],[AppearanceWrapperEntry<ChatMediaInputGridEntry>])>(value: ([],[]))
                
        let inputNodeInteraction = self.inputNodeInteraction!
        let initialSize = atomicSize
        
        let transitions = combineLatest(itemCollectionsView |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue, peerIdPromise.get() |> mapToSignal {
            
            combineLatest(account.viewTracker.peerView($0) |> take(1) |> map {peerViewMainPeer($0)}, peerSpecificStickerPack(postbox: account.postbox, network: account.network, peerId: $0))
            
        } |> deliverOnPrepareQueue)
        |> map { itemsView, appearance, specificData -> ((ItemCollectionsView?, (FoundStickerSets?, Bool)?), TableUpdateTransition, Bool, ChatMediaInputGridTransition, Bool) in
            
            let update: StickerPacksCollectionUpdate = itemsView.1
            
            let gridEntries = chatMediaInputGridEntries(view: itemsView.0, orderedItemListViews: itemsView.0.0?.orderedItemListsViews, specificPack: specificData.1)
            let panelEntries = chatMediaInputPanelEntries(view: itemsView.0, orderedItemListViews: itemsView.0.0?.orderedItemListsViews, specificPack: (specificData.1?.0, specificData.0))
            
            let panelEntriesMapped = panelEntries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            let gridEntriesMapped = gridEntries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            
            let (previousPanelEntries, previousGridEntries) = previousEntries.swap((panelEntriesMapped, gridEntriesMapped))
            
            return (itemsView.0, preparePackEntries(from: previousPanelEntries, to: panelEntriesMapped, account: account, initialSize: initialSize.modify({$0}), stickersInteraction:inputNodeInteraction),previousPanelEntries.isEmpty, preparedChatMediaInputGridEntryTransition(account: account, from: previousGridEntries, to: gridEntriesMapped, update: update, inputNodeInteraction: inputNodeInteraction), previousGridEntries.isEmpty)
           
        }
        
        self.disposable.set((transitions |> deliverOnMainQueue).start(next: { [weak self] (view, packsTransition, packsFirstTime, gridTransition, gridFirstTime) in
            if let strongSelf = self {
                
                strongSelf.currentView = view.0
                strongSelf.collectionInfos = view.0?.collectionInfos.map({($0.0, $0.1, $0.2, true)}) ?? view.1?.0?.infos
                
                
                strongSelf.genericView.packsTable.merge(with: packsTransition)
                strongSelf.enqueueGridTransition(gridTransition, firstTime: gridFirstTime)
                
                strongSelf.genericView.updateEmpties(isEmpty: strongSelf.genericView.gridView.isEmpty, isLoading: (view.1?.1 ?? false), animated: true)
                
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
                            strongSelf.genericView.packsTable.scroll(to: .center(id: collectionId, innerId: nil, animated: true, focus: false, inset: 0))
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
    
    
    override func firstResponder() -> NSResponder? {
        return self.genericView.searchView.input
    }
    
    
    override var responderPriority: HandlerPriority {
        return .modal
    }
    
    override var canBecomeResponder: Bool {
        if let view = account.context.mainNavigation?.view as? SplitView {
            return view.state == .single
        }
        return false
    }
    
    override func becomeFirstResponder() -> Bool? {
        return false
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
    
    override func scrollup() {
        let clipView = genericView.gridView.clipView
        clipView._changeBounds(from: clipView.bounds, to: NSMakeRect(0, 0, clipView.bounds.width, clipView.bounds.height), animated: true, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    private func enqueueGridTransition(_ transition: ChatMediaInputGridTransition, firstTime: Bool) {
        genericView.gridView.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: transition.scrollToItem, updateLayout: nil, itemTransition: .immediate, stationaryItems: transition.stationaryItems, updateFirstIndexInSectionOffset: transition.updateFirstIndexInSectionOffset), completion: { _ in })
    }
    
}
