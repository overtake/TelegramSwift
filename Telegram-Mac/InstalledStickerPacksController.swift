//
//  InstalledStickerPacksController.swift
//  Telegram
//
//  Created by keepcoder on 28/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac

private final class InstalledStickerPacksControllerArguments {
    let account: Account
    
    let openStickerPack: (StickerPackCollectionInfo) -> Void
    let removePack: (ItemCollectionId) -> Void
    let openStickersBot: () -> Void
    let openFeatured: () -> Void
    let openArchived: () -> Void
    let openSuggestionOptions: () -> Void
    init(account: Account, openStickerPack: @escaping (StickerPackCollectionInfo) -> Void, removePack: @escaping (ItemCollectionId) -> Void, openStickersBot: @escaping () -> Void, openFeatured: @escaping () -> Void, openArchived: @escaping () -> Void, openSuggestionOptions: @escaping() -> Void) {
        self.account = account
        self.openStickerPack = openStickerPack
        self.removePack = removePack
        self.openStickersBot = openStickersBot
        self.openFeatured = openFeatured
        self.openArchived = openArchived
        self.openSuggestionOptions = openSuggestionOptions
    }
}

struct ItemListStickerPackItemEditing: Equatable {
    let editable: Bool
    let editing: Bool
    
    static func ==(lhs: ItemListStickerPackItemEditing, rhs: ItemListStickerPackItemEditing) -> Bool {
        if lhs.editable != rhs.editable {
            return false
        }
        if lhs.editing != rhs.editing {
            return false
        }
        return true
    }
}


private enum InstalledStickerPacksEntryId: Hashable {
    case index(Int32)
    case pack(ItemCollectionId)
    
    var hashValue: Int {
        switch self {
        case let .index(index):
            return index.hashValue
        case let .pack(id):
            return id.hashValue
        }
    }
    
    static func ==(lhs: InstalledStickerPacksEntryId, rhs: InstalledStickerPacksEntryId) -> Bool {
        switch lhs {
        case let .index(index):
            if case .index(index) = rhs {
                return true
            } else {
                return false
            }
        case let .pack(id):
            if case .pack(id) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

private enum InstalledStickerPacksEntry: TableItemListNodeEntry {
    case section(sectionId:Int32)
    case suggestOptions(sectionId: Int32, String)
    case trending(sectionId:Int32, Int32)
    case archived(sectionId:Int32)
    case packsTitle(sectionId:Int32, String)
    case pack(sectionId:Int32, Int32, StickerPackCollectionInfo, StickerPackItem?, Int32, Bool, ItemListStickerPackItemEditing)
    case packsInfo(sectionId:Int32, String)
    
    
    var stableId: InstalledStickerPacksEntryId {
        switch self {
        case .suggestOptions:
            return .index(0)
        case .trending:
            return .index(1)
        case .archived:
            return .index(2)
        case .packsTitle:
            return .index(3)
        case let .pack(_, _, info, _, _, _, _):
            return .pack(info.id)
        case .packsInfo:
            return .index(4)
        case let .section(sectionId):
            return .index((sectionId + 1) * 1000 - sectionId)
        }
    }
    
    
    var stableIndex:Int32 {
        switch self {
        case .suggestOptions:
            return 0
        case .trending:
            return 1
        case .archived:
            return 2
        case .packsTitle:
            return 3
        case .pack:
            fatalError("")
        case .packsInfo:
            return 4
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    var index:Int32 {
        switch self {
        case let .suggestOptions(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .trending(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .archived(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .packsTitle(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .pack( sectionId, index, _, _, _, _, _):
            return (sectionId * 1000) + 100 + index
        case let .packsInfo(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func <(lhs: InstalledStickerPacksEntry, rhs: InstalledStickerPacksEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: InstalledStickerPacksControllerArguments, initialSize:NSSize) -> TableRowItem {
        switch self {
        case let .suggestOptions(_, value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.stickersSuggestStickers, type: .context(value), action: {
                arguments.openSuggestionOptions()
            })
        case let .trending(_, count):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.installedStickersTranding), type: .context(count > 0 ? "\(count)" : ""), action: {
                arguments.openFeatured()
            })
           
        case .archived:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.installedStickersArchived), type: .next, action: {
                arguments.openArchived()
            })
        case let .packsTitle(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case let .pack(_, _, info, topItem, count, enabled, editing):
            return StickerSetTableRowItem(initialSize, account: arguments.account, stableId: stableId, info: info, topItem: topItem, itemCount: count, unread: false, editing: editing, enabled: enabled, control: .none, action: {
                arguments.openStickerPack(info)
            }, addPack: {
                
            }, removePack: {
                arguments.removePack(info.id)
            })

        case let .packsInfo(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        }
    }
}

private struct InstalledStickerPacksControllerState: Equatable {
    let editing: Bool
    
    init() {
        self.editing = false
    }
    
    init(editing: Bool) {
        self.editing = editing
    }
    
    static func ==(lhs: InstalledStickerPacksControllerState, rhs: InstalledStickerPacksControllerState) -> Bool {
        
        if lhs.editing != rhs.editing {
            return false
        }
        
        return true
    }
    
    func withUpdatedEditing(_ editing: Bool) -> InstalledStickerPacksControllerState {
        return InstalledStickerPacksControllerState(editing: editing)
    }
    
    func withUpdatedPackIdWithRevealedOptions(_ packIdWithRevealedOptions: ItemCollectionId?) -> InstalledStickerPacksControllerState {
        return InstalledStickerPacksControllerState(editing: self.editing)
    }
}


private func installedStickerPacksControllerEntries(state: InstalledStickerPacksControllerState, stickerSettings: StickerSettings, view: CombinedView, featured: [FeaturedStickerPackItem]) -> [InstalledStickerPacksEntry] {
    var entries: [InstalledStickerPacksEntry] = []
    
    var sectionId:Int32 = 1
    
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    let suggestString: String
    switch stickerSettings.emojiStickerSuggestionMode {
    case .none:
        suggestString = L10n.stickersSuggestNone
    case .all:
        suggestString = L10n.stickersSuggestAll
    case .installed:
        suggestString = L10n.stickersSuggestAdded
    }
    entries.append(.suggestOptions(sectionId: sectionId, suggestString))
    
    if featured.count != 0 {
        var unreadCount: Int32 = 0
        for item in featured {
            if item.unread {
                unreadCount += 1
            }
        }
        entries.append(.trending(sectionId: sectionId, unreadCount))
    }
    entries.append(.archived(sectionId: sectionId))
    
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    entries.append(.packsTitle(sectionId: sectionId, tr(L10n.installedStickersPacksTitle)))
    
    if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])] as? ItemCollectionInfosView {
        if let packsEntries = stickerPacksView.entriesByNamespace[Namespaces.ItemCollection.CloudStickerPacks] {
            var index: Int32 = 0
            for entry in packsEntries {
                if let info = entry.info as? StickerPackCollectionInfo {
                    entries.append(.pack(sectionId: sectionId, index, info, entry.firstItem as? StickerPackItem, info.count == 0 ? entry.count : info.count, true, ItemListStickerPackItemEditing(editable: true, editing: state.editing)))
                    index += 1
                }
            }
        }
    }
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    entries.append(.packsInfo(sectionId: sectionId, tr(L10n.installedStickersDescrpiption)))
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    return entries
}

private func prepareTransition(left:[AppearanceWrapperEntry<InstalledStickerPacksEntry>], right: [AppearanceWrapperEntry<InstalledStickerPacksEntry>], initialSize: NSSize, arguments: InstalledStickerPacksControllerArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class InstalledStickerPacksController: TableViewController {

    
    private func openSuggestionOptions() {
        let postbox: Postbox = account.postbox
        if let view = (genericView.item(stableId: InstalledStickerPacksEntryId.index(0))?.view as? GeneralInteractedRowView)?.textView {
            showPopover(for: view, with: SPopoverViewController(items: [SPopoverItem(L10n.stickersSuggestAll, {
                _ = updateStickerSettingsInteractively(postbox: postbox, {$0.withUpdatedEmojiStickerSuggestionMode(.all)}).start()
            }), SPopoverItem(L10n.stickersSuggestAdded, {
                 _ = updateStickerSettingsInteractively(postbox: postbox, {$0.withUpdatedEmojiStickerSuggestionMode(.installed)}).start()
            }), SPopoverItem(L10n.stickersSuggestNone, {
                 _ = updateStickerSettingsInteractively(postbox: postbox, {$0.withUpdatedEmojiStickerSuggestionMode(.none)}).start()
            })]), edge: .minX, inset: NSMakePoint(0,-30))
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let account = self.account
        let statePromise = ValuePromise(InstalledStickerPacksControllerState(), ignoreRepeated: true)
        let stateValue = Atomic(value: InstalledStickerPacksControllerState())
        let updateState: ((InstalledStickerPacksControllerState) -> InstalledStickerPacksControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        
        let actionsDisposable = DisposableSet()
        
        let resolveDisposable = MetaDisposable()
        actionsDisposable.add(resolveDisposable)
        
        let arguments = InstalledStickerPacksControllerArguments(account: account, openStickerPack: { info in
            showModal(with: StickersPackPreviewModalController(account, peerId: nil, reference: .name(info.shortName)), for: mainWindow)
        }, removePack: { id in
            
            confirm(for: mainWindow, information: tr(L10n.installedStickersRemoveDescription), okTitle: tr(L10n.installedStickersRemoveDelete), successHandler: { result in
                switch result {
                case .basic:
                    _ = removeStickerPackInteractively(postbox: account.postbox, id: id, option: RemoveStickerPackOption.archive).start()
                case .thrid:
                    break
                }
            })
            
        }, openStickersBot: {
            resolveDisposable.set((resolvePeerByName(account: account, name: "stickers") |> deliverOnMainQueue).start(next: { peerId in
                if let peerId = peerId {
                   // navigateToChatControllerImpl?(peerId)
                }
            }))
        }, openFeatured: { [weak self] in
            self?.navigationController?.push(FeaturedStickerPacksController(account))
        }, openArchived: { [weak self] in
            self?.navigationController?.push(ArchivedStickerPacksController(account))
        }, openSuggestionOptions: { [weak self] in
            self?.openSuggestionOptions()
        })
        let stickerPacks = Promise<CombinedView>()
        stickerPacks.set(account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])]))
        
        let featured = Promise<[FeaturedStickerPackItem]>()
       featured.set(account.viewTracker.featuredStickerPacks())
        
        
        let stickerSettingsKey = ApplicationSpecificPreferencesKeys.stickerSettings
        let preferencesKey: PostboxViewKey = .preferences(keys: Set([stickerSettingsKey]))
        let preferencesView = account.postbox.combinedView(keys: [preferencesKey])
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<InstalledStickerPacksEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        genericView.merge(with: combineLatest(statePromise.get() |> deliverOnMainQueue, stickerPacks.get() |> deliverOnMainQueue, featured.get() |> deliverOnMainQueue, appearanceSignal, preferencesView)
            |> map { state, view, featured, appearance, preferencesView -> TableUpdateTransition in
                
                var stickerSettings = StickerSettings.defaultSettings
                if let view = preferencesView.views[preferencesKey] as? PreferencesView {
                    if let value = view.values[stickerSettingsKey] as? StickerSettings {
                        stickerSettings = value
                    }
                }
                
                let entries = installedStickerPacksControllerEntries(state: state, stickerSettings: stickerSettings, view: view, featured: featured).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify({$0}), arguments: arguments)
            } |> afterDisposed {
                actionsDisposable.dispose()
        } )
        readyOnce()
    }
    
}
