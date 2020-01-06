//
//  StickersViewController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08/07/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox

final class StickerPanelArguments {
    let context: AccountContext
    let sendMedia:(Media, NSView, Bool)->Void
    let showPack:(StickerPackReference)->Void
    let navigate:(ItemCollectionViewEntryIndex)->Void
    let addPack: (StickerPackReference)->Void
    init(context: AccountContext, sendMedia: @escaping(Media, NSView, Bool)->Void, showPack: @escaping(StickerPackReference)->Void, addPack: @escaping(StickerPackReference)->Void, navigate: @escaping(ItemCollectionViewEntryIndex)->Void) {
        self.context = context
        self.sendMedia = sendMedia
        self.showPack = showPack
        self.addPack = addPack
        self.navigate = navigate
    }
}

struct SpecificPackData : Equatable {
    let info: StickerPackCollectionInfo
    let peer: Peer
    
    static func ==(lhs: SpecificPackData, rhs: SpecificPackData) -> Bool {
        if lhs.info != rhs.info {
            return false
        } else if !lhs.peer.isEqual(rhs.peer) {
            return false
        } else {
            return true
        }
    }
}

enum PackEntry: Comparable, Identifiable {
    case stickerPack(index:Int, stableId: StickerPackCollectionId, info: StickerPackCollectionInfo, topItem: StickerPackItem?)
    case recent
    case saved
    case specificPack(data: SpecificPackData)
    
    var stableId: StickerPackCollectionId {
        switch self {
        case let .stickerPack(data):
            return data.stableId
        case .recent:
            return .recent
        case .saved:
            return .saved
        case let .specificPack(data):
            return .specificPack(data.info.id)
            
        }
    }
    
    var index: Int {
        switch self {
        case .saved:
            return 0
        case .recent:
            return 1
        case .specificPack:
            return 2
        case let .stickerPack(index, _, _, _):
            return 3 + index
        }
    }
    
    static func <(lhs: PackEntry, rhs: PackEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    
}


private enum StickerPacksUpdate {
    case generic(animated: Bool, scrollToTop: Bool)
    case scroll(animated: Bool)
    case navigate(StickerPacksIndex, animated: Bool)
}


private enum StickerPacksIndex : Hashable, Comparable {
    case sticker(ItemCollectionViewEntryIndex)
    case speficicPack(ItemCollectionId)
    case recent(Int)
    case saved(Int)
    
    var packIndex:ItemCollectionViewEntryIndex {
        switch self {
        case let .sticker(index):
            return index
        case let .saved(index), let .recent(index):
            return ItemCollectionViewEntryIndex.lowerBound(collectionIndex: Int32(index), collectionId: ItemCollectionId(namespace: 0, id: 0))
        case let .speficicPack(id):
            return ItemCollectionViewEntryIndex.lowerBound(collectionIndex: 2, collectionId: id)
        }
    }
    
    var collectionId: StickerPackCollectionId {
        switch self {
        case let .sticker(index):
            return .pack(index.collectionId)
        case .recent:
            return .recent
        case .saved:
            return .saved
        case let .speficicPack(id):
            return .specificPack(id)
        }
    }
    
    func hash(into hasher: inout Hasher) {
        
    }
    
    var index: Int {
        switch self {
        case .saved:
            return 0
        case .recent:
            return 1
        case .speficicPack:
            return 2
        case .sticker:
            return 3
        }
    }
    
    static func <(lhs: StickerPacksIndex, rhs: StickerPacksIndex) -> Bool {
        switch lhs {
        case let .sticker(lhsIndex):
            if case let .sticker(rhsIndex) = rhs {
                return lhsIndex < rhsIndex
            } else {
                return lhs.index < rhs.index
            }
        default:
            return lhs.index < rhs.index
        }
    }
}

private enum StickerPacksScrollState: Equatable {
    case initial
    case scroll(aroundIndex: StickerPacksIndex)
    case navigate(index: StickerPacksIndex)
}

private struct StickerPacksSearchData {
    let sets: FoundStickerSets
    let loading: Bool
}

private struct StickerPacksUpdateData {
    let view: ItemCollectionsView?
    let update: StickerPacksUpdate
    let specificPack:Tuple2<PeerSpecificStickerPackData, Peer>?
    let searchData: StickerPacksSearchData?
    init(_ view: ItemCollectionsView?, _ update: StickerPacksUpdate, _ specificPack: Tuple2<PeerSpecificStickerPackData, Peer>?, searchData: StickerPacksSearchData? = nil) {
        self.view = view
        self.update = update
        self.specificPack = specificPack
        self.searchData = searchData
    }
}
enum StickerPackInfo : Equatable {
    case pack(StickerPackCollectionInfo?, Bool)
    case speficicPack(StickerPackCollectionInfo?)
    case recent
    case saved
    
    var installed: Bool {
        switch self {
        case let .pack(_, installed):
            return installed
        default:
            return true
        }
    }
}

enum StickerPackCollectionId : Hashable {
    case pack(ItemCollectionId)
    case recent
    case specificPack(ItemCollectionId)
    case saved
    
    var itemCollectionId:ItemCollectionId? {
        switch self {
        case let .pack(collectionId):
            return collectionId
        case let .specificPack(collectionId):
            return collectionId
        default:
            return nil
        }
    }
    
}


private enum StickerPackEntry : TableItemListNodeEntry {
    case pack(index: StickerPacksIndex, files:[TelegramMediaFile], packInfo: StickerPackInfo, collectionId: StickerPackCollectionId)
    
    static func < (lhs: StickerPackEntry, rhs: StickerPackEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    static func == (lhs: StickerPackEntry, rhs: StickerPackEntry) -> Bool {
        switch lhs {
        case let .pack(index, lhsFiles, packInfo, collectionId):
            if case .pack(index, let rhsFiles, packInfo, collectionId) = rhs {
                if lhsFiles.count != rhsFiles.count {
                    return false
                } else {
                    for (i, lhsFile) in lhsFiles.enumerated() {
                        if !lhsFile.isEqual(to: rhsFiles[i]) {
                            return false
                        }
                    }
                }
                return true
            } else {
                return false
            }
        }
    }
    
    var index: StickerPacksIndex {
        switch self {
        case let .pack(index, _, _, _):
            return index
        }
    }
    
    var stableId: StickerPackCollectionId {
        switch self {
        case let .pack( _, _, _, collectionId):
            return collectionId
        }
    }
    
    func item(_ arguments: StickerPanelArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .pack(_, files, packInfo, collectionId):
            return StickerPackPanelRowItem(initialSize, context: arguments.context, arguments: arguments, files: files, packInfo: packInfo, collectionId: collectionId)
        }
    }
}

private func stickersEntries(view: ItemCollectionsView?, searchData: StickerPacksSearchData?, specificPack:Tuple2<PeerSpecificStickerPackData, Peer>?) -> [StickerPackEntry] {
    var entries:[StickerPackEntry] = []
    
    if let view = view {
        var available: [ItemCollectionViewEntry] = view.entries
        var index: Int32 = 0
        
        var ids:[MediaId : MediaId] = [:]
        
        if view.lower == nil {
            if !view.orderedItemListsViews[1].items.isEmpty {
                var files:[TelegramMediaFile] = []
                for item in view.orderedItemListsViews[1].items {
                    if let entry = item.contents as? SavedStickerItem {
                        if let id = entry.file.id, ids[id] == nil, entry.file.isStaticSticker || entry.file.isAnimatedSticker {
                            ids[id] = id
                            files.append(entry.file)
                        }
                    }
                }
                if !files.isEmpty {
                    entries.append(.pack(index: .saved(0), files: files, packInfo: .saved, collectionId: .saved))
                }
            }
            
            if !view.orderedItemListsViews[0].items.isEmpty {
                var files:[TelegramMediaFile] = []
                for item in view.orderedItemListsViews[0].items {
                    if let entry = item.contents as? RecentMediaItem {
                        if let file = entry.media as? TelegramMediaFile, let id = file.id, ids[id] == nil, file.isStaticSticker || file.isAnimatedSticker {
                            ids[id] = id
                            files.append(file)
                        }
                    }
                    if files.count == 20 {
                        break
                    }
                }
                if !files.isEmpty {
                    entries.append(.pack(index: .recent(1), files: files, packInfo: .recent, collectionId: .recent))
                }
            }
            
            
            if let specificPack = specificPack, let info = specificPack._0.packInfo {
                var files:[TelegramMediaFile] = []
                for item in info.1 {
                    if let item = item as? StickerPackItem {
                        if let id = item.file.id, ids[id] == nil, item.file.isStaticSticker || item.file.isAnimatedSticker {
                            ids[id] = id
                            files.append(item.file)
                        }
                    }
                }
                if !files.isEmpty {
                    entries.append(.pack(index: .speficicPack(info.0.id), files: files, packInfo: .speficicPack(info.0), collectionId: .specificPack(info.0.id)))
                }
            }
            
        }
        
        for (id, info, item) in view.collectionInfos {
            if !available.isEmpty, let item = item {
                var files: [TelegramMediaFile] = []
                if let info = info as? StickerPackCollectionInfo {
                    let items = available.enumerated().reversed()
                    for (i, entry) in items {
                        if entry.index.collectionId == info.id {
                            if let item = available.remove(at: i).item as? StickerPackItem {
                                files.insert(item.file, at: 0)
                            }
                        }
                    }
                    if !files.isEmpty {
                        entries.append(.pack(index: .sticker(ItemCollectionViewEntryIndex(collectionIndex: index, collectionId: id, itemIndex: item.index)), files: files, packInfo: .pack(info, true), collectionId: .pack(id)))
                    }
                }
            } else {
                break
            }
            index += 1
        }
    } else if let searchData = searchData {
        if !searchData.loading {
            var available = searchData.sets.entries
            var index: Int32 = 0
            for set in searchData.sets.infos {
                if !available.isEmpty {
                    var files: [TelegramMediaFile] = []
                    if let info = set.1 as? StickerPackCollectionInfo {
                        let items = available.enumerated().reversed()
                        for (i, entry) in items {
                            if entry.index.collectionId == info.id {
                                if let item = available.remove(at: i).item as? StickerPackItem {
                                    files.insert(item.file, at: 0)
                                }
                            }
                        }
                        if !files.isEmpty {
                            entries.append(.pack(index: .sticker(ItemCollectionViewEntryIndex(collectionIndex: index, collectionId: info.id, itemIndex: .init(index: 0, id: 0))), files: files, packInfo: .pack(info, set.3), collectionId: .pack(info.id)))
                        }
                    }
                } else {
                    break
                }
                index += 1
            }
        }
       
    }
    
    return entries
}

private func packEntries(view: ItemCollectionsView?, specificPack:Tuple2<PeerSpecificStickerPackData, Peer>?) -> [PackEntry] {
    var entries:[PackEntry] = []
    var index: Int = 0
    
    if let view = view {
        if !view.orderedItemListsViews[1].items.isEmpty {
            entries.append(.saved)
        }
        if !view.orderedItemListsViews[0].items.isEmpty {
            entries.append(.recent)
        }
        if let specificPack = specificPack, let info = specificPack._0.packInfo?.0 {
            entries.append(.specificPack(data: SpecificPackData(info: info, peer: specificPack._1)))
        }
        
        for (_, info, item) in view.collectionInfos {
            if let info = info as? StickerPackCollectionInfo {
                entries.append(.stickerPack(index: index, stableId: .pack(info.id), info: info, topItem: item as? StickerPackItem))
                index += 1
            }
        }
    }

    return entries
}


private func prepareStickersTransition(from:[AppearanceWrapperEntry<StickerPackEntry>], to: [AppearanceWrapperEntry<StickerPackEntry>], initialSize: NSSize, arguments: StickerPanelArguments, update: StickerPacksUpdate) -> TableUpdateTransition {
    let (removed,inserted,updated) = proccessEntriesWithoutReverse(from, right: to, { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    })
    let state: TableScrollState
    var anim: Bool
    switch update {
    case let .generic(animated, scrollToTop):
        anim = animated
        if scrollToTop {
            state = .up(animated)
        } else {
            state = .saveVisible(.lower)
        }
    case let .scroll(animated):
        state = .saveVisible(.upper)
        anim = animated
    case let .navigate(index, animated):
        state = .top(id: index.collectionId, innerId: nil, animated: true, focus: .init(focus: false), inset: 0)
        anim = animated
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: anim, state: state, grouping: !anim)
}

fileprivate func preparePackTransition(from:[AppearanceWrapperEntry<PackEntry>]?, to:[AppearanceWrapperEntry<PackEntry>], context: AccountContext, initialSize:NSSize) -> TableUpdateTransition {
    
    let (deleted,inserted,updated) = proccessEntriesWithoutReverse(from, right: to, { (entry) -> TableRowItem in
        switch entry.entry {
        case let .stickerPack(index, stableId, info, topItem):
            return StickerPackRowItem(initialSize, packIndex: index, context: context, stableId: stableId, info: info, topItem: topItem)
        case .recent:
            return RecentPackRowItem(initialSize, entry.entry.stableId)
        case .saved:
            return RecentPackRowItem(initialSize, entry.entry.stableId)
        case let .specificPack(data):
            return StickerSpecificPackItem(initialSize, stableId: entry.entry.stableId, specificPack: (data.info, data.peer), account: context.account)
        }
    })
    
    return TableUpdateTransition(deleted: deleted, inserted: inserted, updated:updated, animated: true, state: .none(nil))
    
}

class NStickersView : View {
    fileprivate let tableView:TableView = TableView(frame: NSZeroRect)
    fileprivate let packsView:HorizontalTableView = HorizontalTableView(frame: NSZeroRect)
    private let separator:View = View()
    fileprivate let tabsContainer: View = View()
    fileprivate var restrictedView:RestrictionWrappedView?
    private let emptySearchView = ImageView()
    private let emptySearchContainer: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(tableView)
        
        emptySearchContainer.addSubview(emptySearchView)
        tabsContainer.addSubview(packsView)
        tabsContainer.addSubview(separator)
        addSubview(tabsContainer)
        addSubview(emptySearchContainer)
        
        emptySearchContainer.isHidden = true
        emptySearchContainer.isEventLess = true
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    func updateRestricion(_ peer: Peer?) {
        if let peer = peer, let text = permissionText(from: peer, for: .banSendStickers) {
            restrictedView?.removeFromSuperview()
            restrictedView = RestrictionWrappedView(text)
            addSubview(restrictedView!)
        } else {
            restrictedView?.removeFromSuperview()
            restrictedView = nil
        }
        setFrameSize(frame.size)
        needsLayout = true
    }
    
    func updateEmpties(isEmpty: Bool, animated: Bool) {
        
        let emptySearchHidden: Bool = !isEmpty
        
        if !emptySearchHidden {
            emptySearchContainer.isHidden = false
        }
        
        emptySearchContainer.change(opacity: emptySearchHidden ? 0 : 1, animated: animated, completion: { [weak self] completed in
            if completed {
                self?.emptySearchContainer.isHidden = emptySearchHidden
            }
        })
        
        needsLayout = true
    }
    
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        self.restrictedView?.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        self.separator.backgroundColor = theme.colors.border
        self.tableView.updateLocalizationAndTheme(theme: theme)
        self.tableView.backgroundColor = theme.colors.background
        self.tableView.documentView?.background = theme.colors.background
        self.emptySearchView.image = theme.icons.stickersEmptySearch
        self.emptySearchView.sizeToFit()
        self.emptySearchContainer.backgroundColor = theme.colors.background
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    override func layout() {
        super.layout()

        tabsContainer.frame = NSMakeRect(0, 0, frame.width, 50)
        separator.frame = NSMakeRect(0, tabsContainer.frame.height - .borderSize, tabsContainer.frame.width, .borderSize)
        packsView.frame = tabsContainer.focus(NSMakeSize(frame.width, 40))
        
        tableView.frame = NSMakeRect(0, tabsContainer.frame.maxY, frame.width, frame.height - tabsContainer.frame.height)
        restrictedView?.setFrameSize(frame.size)
        
        emptySearchContainer.frame = self.bounds
        emptySearchView.center()
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



class NStickersViewController: TelegramGenericViewController<NStickersView>, TableViewDelegate, Notifable {

    private let searchValue = ValuePromise<SearchState>()
    private var searchState: SearchState = .init(state: .None, request: nil) {
        didSet {
            self.searchValue.set(searchState)
        }
    }
    private let position = ValuePromise<StickerPacksScrollState>(ignoreRepeated: true)
    private let disposable = MetaDisposable()
    private let searchStateDisposable = MetaDisposable()
    private let specificPeerId = ValuePromise<PeerId>(ignoreRepeated: true)
    private var listener: TableScrollListener!
    private var interactions: EntertainmentInteractions?
    private weak var chatInteraction: ChatInteraction?
    var makeSearchCommand:((ESearchCommand)->Void)?
    init(_ context: AccountContext, search: Signal<SearchState, NoError>) {
        super.init(context)
        bar = .init(height: 0)
        
        self.searchStateDisposable.set(search.start(next: { [weak self] state in
            self?.searchState = state
            if !state.request.isEmpty {
                self?.makeSearchCommand?(.loading)
            }
            switch state.state {
            case .None:
                self?.position.set(.initial)
            default:
                break
            }
        }))
    }
    
    deinit {
        disposable.dispose()
        searchStateDisposable.dispose()
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.genericView.packsView.updateLocalizationAndTheme(theme: theme)
    }
    
    func update(with interactions:EntertainmentInteractions, chatInteraction: ChatInteraction) {
        self.interactions = interactions
        self.chatInteraction?.remove(observer: self)
        self.chatInteraction = chatInteraction
        chatInteraction.add(observer: self)
        if isLoaded() {
            genericView.updateRestricion(chatInteraction.presentation.peer)
        }
        self.specificPeerId.set(chatInteraction.peerId)
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState, let peer = value.peer, let oldPeer = oldValue.peer {
            if permissionText(from: peer, for: .banSendStickers) != permissionText(from: oldPeer, for: .banSendStickers) {
                genericView.updateRestricion(peer)
            }
        }
    }
    
    func isEqual(to other: Notifable) -> Bool {
        return other === self
    }
    
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return true
    }
    func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        return true
    }
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) {
        if byClick, let collectionId = item.stableId.base as? StickerPackCollectionId {
            if let item = genericView.tableView.item(stableId: collectionId) {
                self.genericView.tableView.removeScroll(listener: self.listener)
                self.genericView.tableView.scroll(to: .top(id: item.stableId, innerId: nil, animated: true, focus: .init(focus: false), inset: 0), completion: { [weak self] _ in
                    if let `self` = self {
                        self.genericView.tableView.addScroll(listener: self.listener)
                    }
                })
            } else {
                var index: StickerPacksIndex? = nil
                switch collectionId {
                case let .pack(id):
                    if let item = item as? StickerPackRowItem {
                        index = .sticker(ItemCollectionViewEntryIndex.lowerBound(collectionIndex: Int32(item.packIndex), collectionId: id))
                    }
                case .saved:
                    index = .saved(0)
                case .recent:
                    index = .recent(1)
                case let .specificPack(id):
                    index = .speficicPack(id)
                    
                }
                if let index = index {
                    self.genericView.tableView.removeScroll(listener: self.listener)
                    self.position.set(.navigate(index: index))
                }
            }
            
        }
    }
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context
        let initialSize = self.atomicSize
        
       
        
        listener = TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            guard let `self` = self, position.visibleRows.length > 0 else {
                return
            }
            let item = self.genericView.tableView.item(at: position.visibleRows.location)
            self.genericView.packsView.changeSelection(stableId: item.stableId)
            self.genericView.packsView.scroll(to: .center(id: item.stableId, innerId: nil, animated: true, focus: .init(focus: false), inset: 0))
        })

        self.genericView.packsView.delegate = self
        
        let previous:Atomic<[AppearanceWrapperEntry<StickerPackEntry>]> = Atomic(value: [])
        let previousPacks:Atomic<[AppearanceWrapperEntry<PackEntry>]> = Atomic(value: [])

        
        let arguments = StickerPanelArguments(context: context, sendMedia: { [weak self] media, view, silent in
            guard let `self` = self, let chatInteraction = self.chatInteraction else { return }
            if let slowMode = chatInteraction.presentation.slowMode, slowMode.hasLocked {
                showSlowModeTimeoutTooltip(slowMode, for: view)
            } else if let file = media as? TelegramMediaFile {
                self.interactions?.sendSticker(file, silent)
            }
        }, showPack: { [weak self] reference in
            if let peerId = self?.chatInteraction?.peerId {
                showModal(with: StickerPackPreviewModalController(context, peerId: peerId, reference: reference), for: context.window)
            }
        }, addPack: { [weak self] reference in
            _ = showModalProgress(signal: loadedStickerPack(postbox: context.account.postbox, network: context.account.network, reference: reference, forceActualized: false)
                |> filter { result in
                    switch result {
                    case .result:
                        return true
                    default:
                        return false
                    }
                }
                |> take(1)
                |> mapToSignal { result -> Signal<ItemCollectionId, NoError> in
                    switch result {
                    case let .result(info, items, _):
                        return addStickerPackInteractively(postbox: context.account.postbox, info: info, items: items) |> map { info.id }
                    default:
                        return .complete()
                    }
                }
                |> deliverOnMainQueue, for: mainWindow).start(next: { [weak self] result in
                    if let `self` = self {
                        if !self.searchState.request.isEmpty {
                            self.makeSearchCommand?(.close)
                            self.position.set(.navigate(index: StickerPacksIndex.sticker(ItemCollectionViewEntryIndex.lowerBound(collectionIndex: 0, collectionId: result))))
                        }
                    }
                })
        }, navigate: { [weak self] index in
            self?.position.set(.navigate(index: .sticker(index)))
        })
        
        let specificPackData: Signal<Tuple2<PeerSpecificStickerPackData, Peer>?, NoError> = self.specificPeerId.get() |> mapToSignal { peerId -> Signal<Peer, NoError> in
            return context.account.postbox.loadedPeerWithId(peerId)
        } |> mapToSignal { peer -> Signal<Tuple2<PeerSpecificStickerPackData, Peer>?, NoError> in
            if peer.isSupergroup {
                return peerSpecificStickerPack(postbox: context.account.postbox, network: context.account.network, peerId: peer.id) |> map { data in
                    return Tuple2(data, peer)
                }
            } else {
                return .single(nil)
            }
        }
        
        let signal = combineLatest(queue: prepareQueue, self.searchValue.get(), self.position.get()) |> mapToSignal { values -> Signal<StickerPacksUpdateData, NoError> in
            
            let count = initialSize.with { size -> Int in
                return Int(round((size.height * (values.1 == .initial ? 2 : 20)) / 60 * 5))
            }
            if values.0.state == .None {
                var firstTime: Bool = true
                switch values.1 {
                case .initial:
                    return context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudSavedStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: count)
                        |> mapToSignal { view  in
                            return specificPackData |> map { specificPack in
                                let scrollToTop = firstTime
                                firstTime = false
                                return StickerPacksUpdateData(view, .generic(animated: scrollToTop, scrollToTop: scrollToTop), specificPack)
                            }
                    }
                case let .scroll(aroundIndex):
                    var firstTime = true
                    return context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudSavedStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: aroundIndex.packIndex, count: count)
                        |> mapToSignal { view in
                            return specificPackData |> map { specificPack in
                                let update: StickerPacksUpdate
                                if firstTime {
                                    firstTime = false
                                    update = .scroll(animated: false)
                                } else {
                                    update = .generic(animated: false, scrollToTop: false)
                                }
                                return StickerPacksUpdateData(view, update, specificPack)
                            }
                    }
                case let .navigate(index):
                    var firstTime = true
                    return context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudSavedStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: index.packIndex, count: count)
                        |> mapToSignal { view in
                            return specificPackData |> map { specificPack in
                                let update: StickerPacksUpdate
                                if firstTime {
                                    firstTime = false
                                    update = .navigate(index, animated: true)
                                } else {
                                    update = .generic(animated: false, scrollToTop: false)
                                }
                                return StickerPacksUpdateData(view, update, specificPack)
                            }
                    }
                }
            } else {
                let searchText = values.0.request.lowercased()
                if values.0.request.isEmpty {
                    return combineLatest(context.account.viewTracker.featuredStickerPacks(), context.account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])])) |> map { value, view in
                        var found = FoundStickerSets()
                        
                        var installedPacks = Set<ItemCollectionId>()
                        if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])] as? ItemCollectionInfosView {
                            if let packsEntries = stickerPacksView.entriesByNamespace[Namespaces.ItemCollection.CloudStickerPacks] {
                                for entry in packsEntries {
                                    installedPacks.insert(entry.id)
                                }
                            }
                        }
                        
                        for (collectionIndex, set) in value.enumerated() {
                            if !installedPacks.contains(set.info.id) {
                                var entries:[ItemCollectionViewEntry] = []

                                for item in set.topItems {
                                    entries.append(ItemCollectionViewEntry(index: ItemCollectionViewEntryIndex(collectionIndex: Int32(collectionIndex), collectionId: set.info.id, itemIndex: item.index), item: item))
                                }
                                if !entries.isEmpty {
                                    found = found.merge(with: FoundStickerSets(infos: [(set.info.id, set.info, nil, false)], entries: entries))
                                }
                            }
                        }
                        let searchData = StickerPacksSearchData(sets: found, loading: false)
                        return StickerPacksUpdateData(nil, .generic(animated: true, scrollToTop: true), nil, searchData: searchData)
                    }
                } else {
                    let searchLocal = searchStickerSets(postbox: context.account.postbox, query: searchText) |> map(Optional.init)
                    let searchRemote = searchStickerSetsRemotely(network: context.account.network, query: searchText) |> map(Optional.init)
                    
                    return combineLatest(searchLocal, searchRemote) |> delay(0.2, queue: prepareQueue) |> map { local, remote in
                        var value = FoundStickerSets()
                        if let local = local {
                            value = value.merge(with: local)
                        }
                        if let remote = remote {
                            value = value.merge(with: remote)
                        }
                        let searchData = StickerPacksSearchData(sets: value, loading: remote == nil && value.entries.isEmpty)
                        return StickerPacksUpdateData(nil, .generic(animated: true, scrollToTop: true), nil, searchData: searchData)
                    }
                }
                
            }
            
        } |> deliverOnPrepareQueue
        
        let transition = combineLatest(queue: prepareQueue, appearanceSignal, signal)
             |> map { appearance, data -> (TableUpdateTransition, TableUpdateTransition, [AppearanceWrapperEntry<PackEntry>]) in
                
                let entries = stickersEntries(view: data.view, searchData: data.searchData, specificPack: data.specificPack).map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
                let from = previous.swap(entries)
                
                let entriesPack = packEntries(view: data.view, specificPack: data.specificPack).map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
                let fromPacks = previousPacks.swap(entriesPack)
                
                let transition = prepareStickersTransition(from: from, to: entries, initialSize: initialSize.with { $0 }, arguments: arguments, update: data.update)
                let packTransition = preparePackTransition(from: fromPacks, to: entriesPack, context: context, initialSize: initialSize.with { $0 })
                
                return (transition, packTransition, entriesPack)
        } |> deliverOnMainQueue
        
        var first: Bool = true
        
        disposable.set(transition.start(next: { [weak self] (transition, packTransition, entriesPack) in
            guard let `self` = self else { return }
            
            self.genericView.tableView.removeScroll(listener: self.listener)
            CATransaction.begin()
            self.genericView.tableView.merge(with: transition)
            self.genericView.packsView.merge(with: packTransition)
            self.genericView.updateEmpties(isEmpty: self.genericView.tableView.isEmpty, animated: !first)
            
            CATransaction.commit()
            self.genericView.tableView.addScroll(listener: self.listener)
            first = false
            
            var visibleRows = self.genericView.tableView.visibleRows()
            if visibleRows.length == 0, !self.genericView.tableView.isEmpty {
                visibleRows.location = 0
                visibleRows.length = 1
            }
            if visibleRows.length > 0 {
                let item = self.genericView.tableView.item(at: visibleRows.location)
                self.genericView.packsView.changeSelection(stableId: item.stableId)
            }
            
            self.makeSearchCommand?(.normal)
            
           
            if !packTransition.isEmpty {
                var resortRange: NSRange = NSMakeRange(0, 0)
                let entries = entriesPack.map( {$0.entry })
                
                for entry in entries {
                    switch entry {
                    case .saved, .recent, .specificPack:
                        resortRange.location += 1
                    default:
                        break
                    }
                }
                if entries.count > resortRange.location {
                    resortRange.length = entries.count - resortRange.location
                }
                self.genericView.packsView.resortController = TableResortController(resortRange: resortRange, start: { _ in }, resort: { _ in }, complete: { fromIndex, toIndex in
                    
                    
                    if fromIndex == toIndex {
                        return
                    }
                    
                    let entries = entriesPack.map( {$0.entry })
                    
                    
                    let fromEntry = entries[fromIndex]
                    
                    guard case let .stickerPack(_, _, fromPackInfo, _) = fromEntry else {
                        return
                    }
                    
                    var referenceId: ItemCollectionId?
                    var beforeAll = false
                    var afterAll = false
                    if toIndex < entries.count {
                        switch entries[toIndex] {
                        case let .stickerPack(_, _, toPackInfo, _):
                            referenceId = toPackInfo.id
                        default:
                            if entries[toIndex] < fromEntry {
                                beforeAll = true
                            } else {
                                afterAll = true
                            }
                        }
                    } else {
                        afterAll = true
                    }
                    
                    
                    let _ = (context.account.postbox.transaction { transaction -> Void in
                        var infos = transaction.getItemCollectionsInfos(namespace: Namespaces.ItemCollection.CloudStickerPacks)
                        var reorderInfo: ItemCollectionInfo?
                        for i in 0 ..< infos.count {
                            if infos[i].0 == fromPackInfo.id {
                                reorderInfo = infos[i].1
                                infos.remove(at: i)
                                break
                            }
                        }
                        if let reorderInfo = reorderInfo {
                            if let referenceId = referenceId {
                                var inserted = false
                                for i in 0 ..< infos.count {
                                    if infos[i].0 == referenceId {
                                        if fromIndex < toIndex {
                                            infos.insert((fromPackInfo.id, reorderInfo), at: i + 1)
                                        } else {
                                            infos.insert((fromPackInfo.id, reorderInfo), at: i)
                                        }
                                        inserted = true
                                        break
                                    }
                                }
                                if !inserted {
                                    infos.append((fromPackInfo.id, reorderInfo))
                                }
                            } else if beforeAll {
                                infos.insert((fromPackInfo.id, reorderInfo), at: 0)
                            } else if afterAll {
                                infos.append((fromPackInfo.id, reorderInfo))
                            }
                            addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: Namespaces.ItemCollection.CloudStickerPacks, content: .sync)
                            transaction.replaceItemCollectionInfos(namespace: Namespaces.ItemCollection.CloudStickerPacks, itemCollectionInfos: infos)
                        }
                    } |> deliverOnMainQueue).start(completed: { [weak self] in
                        if let `self` = self {
                            self.genericView.tableView.removeScroll(listener: self.listener)
                        }
                    })
                })
            }
            
            self.readyOnce()
        }))
        
        self.genericView.tableView.setScrollHandler { [weak self] position in
            if let `self` = self {
                let entries = previous.with ({ $0 })
                let index:StickerPacksIndex?
                switch position.direction {
                case .bottom:
                    index = entries.last?.entry.index
                case .top:
                    index = entries.first?.entry.index
                case .none:
                    index = nil
                }
                if let index = index, self.searchState.state == .None {
                    self.position.set(.scroll(aroundIndex: index))
                }
            }
        }
        
        self.position.set(.initial)
        
    }
    override func scrollup() {
        self.position.set(.initial)
        self.genericView.packsView.scroll(to: .up(true))
      //  self.genericView.tableView.scroll(to: .up(true))
    }
    
    override var supportSwipes: Bool {
        return !self.genericView.packsView._mouseInside()
    }
    
}
