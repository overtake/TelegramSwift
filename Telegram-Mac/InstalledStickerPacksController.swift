//
//  InstalledStickerPacksController.swift
//  Telegram
//
//  Created by keepcoder on 28/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import InAppSettings

enum InstalledStickerPacksEntryTag: ItemListItemTag {
    case suggestOptions
    case loopAnimatedStickers
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? InstalledStickerPacksEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private final class InstalledStickerPacksControllerArguments {
    let context: AccountContext
    
    let openStickerPack: (StickerPackCollectionInfo) -> Void
    let removePack: (ItemCollectionId) -> Void
    let openStickersBot: () -> Void
    let openFeatured: () -> Void
    let openArchived: ([ArchivedStickerPackItem]?) -> Void
    let openSuggestionOptions: () -> Void
    let toggleLoopAnimated: (Bool)->Void
    let quickSetup:(AvailableReactions?)->Void
    init(context: AccountContext, openStickerPack: @escaping (StickerPackCollectionInfo) -> Void, removePack: @escaping (ItemCollectionId) -> Void, openStickersBot: @escaping () -> Void, openFeatured: @escaping () -> Void, openArchived: @escaping ([ArchivedStickerPackItem]?) -> Void, openSuggestionOptions: @escaping() -> Void, toggleLoopAnimated: @escaping(Bool)->Void, quickSetup:@escaping(AvailableReactions?)->Void) {
        self.context = context
        self.openStickerPack = openStickerPack
        self.removePack = removePack
        self.openStickersBot = openStickersBot
        self.openFeatured = openFeatured
        self.openArchived = openArchived
        self.openSuggestionOptions = openSuggestionOptions
        self.toggleLoopAnimated = toggleLoopAnimated
        self.quickSetup = quickSetup
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

private struct ArchivedListContainer : Equatable {
    let archived: [ArchivedStickerPackItem]?
    static func ==(lhs: ArchivedListContainer, rhs: ArchivedListContainer) -> Bool {
        if let lhsItem = lhs.archived, let rhsItem = rhs.archived {
            if lhsItem.count != rhsItem.count {
                return false
            } else {
                for i in 0 ..< lhsItem.count {
                    let lhs = lhsItem[i]
                    let rhs = rhsItem[i]
                    if lhs.info != rhs.info {
                        return false
                    }
                    if lhs.topItems != rhs.topItems {
                        return false
                    }
                }
            }
        } else if (lhs.archived != nil) != (rhs.archived != nil) {
            return false
        }
        return true
    }
}

private enum InstalledStickerPacksEntry: TableItemListNodeEntry {
    case section(sectionId:Int32)
    case suggestOptions(sectionId: Int32, String, GeneralViewType)
    case trending(sectionId:Int32, Int32, GeneralViewType)
    case archived(sectionId:Int32, ArchivedListContainer, GeneralViewType)
    case quickReaction(sectionId:Int32, AvailableReactions?, CGImage?, GeneralViewType)
    case loopAnimated(sectionId: Int32, Bool, GeneralViewType)
    case packsTitle(sectionId:Int32, String, GeneralViewType)
    case pack(sectionId:Int32, Int32, StickerPackCollectionInfo, StickerPackItem?, Int32, Bool, Bool, ItemListStickerPackItemEditing, GeneralViewType)
    case packsInfo(sectionId:Int32, String, GeneralViewType)
    
    
    var stableId: InstalledStickerPacksEntryId {
        switch self {
        case .suggestOptions:
            return .index(0)
        case .trending:
            return .index(1)
        case .archived:
            return .index(2)
        case .quickReaction:
            return .index(3)
        case .loopAnimated:
            return .index(4)
        case .packsTitle:
            return .index(5)
        case let .pack(_, _, info, _, _, _, _, _, _):
            return .pack(info.id)
        case .packsInfo:
            return .index(6)
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
        case .quickReaction:
            return 3
        case .loopAnimated:
            return 4
        case .packsTitle:
            return 5
        case .pack:
            fatalError("")
        case .packsInfo:
            return 6
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    var index:Int32 {
        switch self {
        case let .suggestOptions(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .trending(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .archived(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .quickReaction(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .loopAnimated(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .packsTitle(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .pack( sectionId, index, _, _, _, _, _, _, _):
            return (sectionId * 1000) + 100 + index
        case let .packsInfo(sectionId, _, _):
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
        case let .suggestOptions(_, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().stickersSuggestStickers, type: .context(value), viewType: viewType, action: {
                arguments.openSuggestionOptions()
            })
        case let .trending(_, count, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().installedStickersTranding, type: .context(count > 0 ? "\(count)" : ""), viewType: viewType, action: {
                arguments.openFeatured()
            })
        case let .archived(_, archived, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().installedStickersArchived, type: .next, viewType: viewType, action: {
                arguments.openArchived(archived.archived)
            })
        case let .quickReaction(_, available, image, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().installedStickersQuickReaction1, type: image != nil ? .image(image!) : .next, viewType: viewType, action: {
                arguments.quickSetup(available)
            })
        case let .loopAnimated(_, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: strings().installedStickersLoopAnimated, type: .switchable(value), viewType: viewType, action: {
                arguments.toggleLoopAnimated(!value)
            })
        case let .packsTitle(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .pack(_, _, info, topItem, count, enabled, _, editing, viewType):
            return StickerSetTableRowItem(initialSize, context: arguments.context, stableId: stableId, info: info, topItem: topItem, itemCount: count, unread: false, editing: editing, enabled: enabled, control: .none, viewType: viewType, action: {
                arguments.openStickerPack(info)
            }, addPack: {
                
            }, removePack: {
                arguments.removePack(info.id)
            })

        case let .packsInfo(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case .section:
            return GeneralRowItem(initialSize, height: 30, stableId: stableId, viewType: .separator)
        }
    }
}

private struct InstalledStickerPacksControllerState: Equatable {
    var editing: Bool
    var quickImage: CGImage?
}


private func installedStickerPacksControllerEntries(state: InstalledStickerPacksControllerState, autoplayMedia: AutoplayMediaPreferences, stickerSettings: StickerSettings, view: CombinedView, featured: [FeaturedStickerPackItem], archived: [ArchivedStickerPackItem]?, availableReactions: AvailableReactions?) -> [InstalledStickerPacksEntry] {
    var entries: [InstalledStickerPacksEntry] = []
    
    var sectionId:Int32 = 1
    
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    let suggestString: String
    switch stickerSettings.emojiStickerSuggestionMode {
    case .none:
        suggestString = strings().stickersSuggestNone
    case .all:
        suggestString = strings().stickersSuggestAll
    case .installed:
        suggestString = strings().stickersSuggestAdded
    }
    entries.append(.suggestOptions(sectionId: sectionId, suggestString, .firstItem))
    
    if featured.count != 0 {
        var unreadCount: Int32 = 0
        for item in featured {
            if item.unread {
                unreadCount += 1
            }
        }
        entries.append(.trending(sectionId: sectionId, unreadCount, .innerItem))
    }
    entries.append(.archived(sectionId: sectionId, ArchivedListContainer(archived: archived), .innerItem))
    entries.append(.quickReaction(sectionId: sectionId, availableReactions, state.quickImage, .innerItem))
    entries.append(.loopAnimated(sectionId: sectionId, autoplayMedia.loopAnimatedStickers, .lastItem))
    
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    entries.append(.packsTitle(sectionId: sectionId, strings().installedStickersPacksTitle, .textTopItem))
    
    if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])] as? ItemCollectionInfosView {
        if let packsEntries = stickerPacksView.entriesByNamespace[Namespaces.ItemCollection.CloudStickerPacks] {
            var index: Int32 = 0
            for entry in packsEntries {
                if let info = entry.info as? StickerPackCollectionInfo {
                    let viewType: GeneralViewType = bestGeneralViewType(packsEntries, for: entry)
                   
                    entries.append(.pack(sectionId: sectionId, index, info, entry.firstItem as? StickerPackItem, info.count == 0 ? entry.count : info.count, true, autoplayMedia.loopAnimatedStickers, ItemListStickerPackItemEditing(editable: true, editing: state.editing), viewType))
                    index += 1
                }
            }
        }
    }
    entries.append(.packsInfo(sectionId: sectionId, strings().installedStickersDescrpiption, .textBottomItem))
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

    private let focusOnItemTag: InstalledStickerPacksEntryTag?
    init(_ context: AccountContext, focusOnItemTag: InstalledStickerPacksEntryTag? = nil) {
        self.focusOnItemTag = focusOnItemTag
        super.init(context)
    }
    
    private let disposbale = MetaDisposable()
    private func openSuggestionOptions() {
        let postbox: Postbox = context.account.postbox
        if let view = (genericView.item(stableId: InstalledStickerPacksEntryId.index(0))?.view as? GeneralInteractedRowView)?.textView {
            if let event = NSApp.currentEvent {
                
                let menu = ContextMenu()
                
                menu.addItem(ContextMenuItem(strings().stickersSuggestAll, handler: {
                    _ = updateStickerSettingsInteractively(postbox: postbox, {$0.withUpdatedEmojiStickerSuggestionMode(.all)}).start()
                }, itemImage: MenuAnimation.menu_view_sticker_set.value))
                
                menu.addItem(ContextMenuItem(strings().stickersSuggestAdded, handler: {
                    _ = updateStickerSettingsInteractively(postbox: postbox, {$0.withUpdatedEmojiStickerSuggestionMode(.installed)}).start()
                }, itemImage: MenuAnimation.menu_open_profile.value))
                
                menu.addItem(ContextMenuItem(strings().stickersSuggestNone, handler: {
                    _ = updateStickerSettingsInteractively(postbox: postbox, {$0.withUpdatedEmojiStickerSuggestionMode(.none)}).start()
               }, itemImage: MenuAnimation.menu_clear_history.value))
                
                let value = AppMenu(menu: menu)
                
                value.show(event: event, view: view)
                
            }
         
        }
    }
    
    deinit {
        disposbale.dispose()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        let statePromise = ValuePromise(InstalledStickerPacksControllerState(editing: false), ignoreRepeated: true)
        let stateValue = Atomic(value: InstalledStickerPacksControllerState(editing: false))
        let updateState: ((InstalledStickerPacksControllerState) -> InstalledStickerPacksControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        let archivedPromise = Promise<[ArchivedStickerPackItem]?>()
        archivedPromise.set(.single(nil) |> then(context.engine.stickers.archivedStickerPacks() |> map(Optional.init)))
        

        
        let actionsDisposable = DisposableSet()
        
        let resolveDisposable = MetaDisposable()
        actionsDisposable.add(resolveDisposable)
        
        let arguments = InstalledStickerPacksControllerArguments(context: context, openStickerPack: { info in
            showModal(with: StickerPackPreviewModalController(context, peerId: nil, reference: .name(info.shortName)), for: context.window)
        }, removePack: { id in
            
            confirm(for: context.window, information: strings().installedStickersRemoveDescription, okTitle: strings().installedStickersRemoveDelete, successHandler: { result in
                switch result {
                case .basic:
                    _ = context.engine.stickers.removeStickerPackInteractively(id: id, option: .archive).start()
                case .thrid:
                    break
                }
            })
            
        }, openStickersBot: {
            resolveDisposable.set((context.engine.peers.resolvePeerByName(name: "stickers") |> deliverOnMainQueue).start(next: { peerId in
                if let peerId = peerId {
                   // navigateToChatControllerImpl?(peerId)
                }
            }))
        }, openFeatured: { [weak self] in
            self?.navigationController?.push(FeaturedStickerPacksController(context))
        }, openArchived: { [weak self] archived in
            self?.navigationController?.push(ArchivedStickerPacksController(context, archived: archived, updatedPacks: { packs in
                archivedPromise.set(.single(packs))
            }))
        }, openSuggestionOptions: { [weak self] in
            self?.openSuggestionOptions()
        }, toggleLoopAnimated: { value in
            _ = updateAutoplayMediaSettingsInteractively(postbox: context.account.postbox, {
                $0.withUpdatedLoopAnimatedStickers(value)
            }).start()
        }, quickSetup: { available in
            context.bindings.rootNavigation().push(ReactionsSettingsController(context: context, peerId: context.peerId, allowedReactions: nil, availableReactions: available, mode: .quick))
        })
        let stickerPacks = context.account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])])
        
        let featured = context.account.viewTracker.featuredStickerPacks()
        
        
        let stickerSettingsKey = ApplicationSpecificPreferencesKeys.stickerSettings
        let autoplayKey = ApplicationSpecificPreferencesKeys.autoplayMedia
        let preferencesKey: PostboxViewKey = .preferences(keys: Set([stickerSettingsKey, autoplayKey]))
        let preferencesView = context.account.postbox.combinedView(keys: [preferencesKey])
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<InstalledStickerPacksEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        
        
        let settings = context.account.postbox.preferencesView(keys: [PreferencesKeys.reactionSettings])
           |> map { preferencesView -> ReactionSettings in
               let reactionSettings: ReactionSettings
               if let entry = preferencesView.values[PreferencesKeys.reactionSettings], let value = entry.get(ReactionSettings.self) {
                   reactionSettings = value
               } else {
                   reactionSettings = .default
               }
               return reactionSettings
           }
        actionsDisposable.add(combineLatest(settings, context.reactions.stateValue).start(next: { settings, availableReactions in
            if let reactions = availableReactions {
                var reaction = reactions.reactions.first(where: { $0.value == settings.quickReaction })
                if let current = reaction, !current.isEnabled {
                    reaction = reactions.reactions.first
                } else if reaction == nil {
                    reaction = reactions.reactions.first
                }
                if let reaction = reaction {
                    let signal = chatMessageSticker(postbox: context.account.postbox, file: .standalone(media: reaction.staticIcon), small: false, scale: System.backingScale)
                    
                    let arguments = TransformImageArguments(corners: .init(), imageSize: NSMakeSize(24, 24), boundingSize: NSMakeSize(24, 24), intrinsicInsets: NSEdgeInsetsZero, emptyColor: nil)

                    actionsDisposable.add(signal.start(next: { value in
                        updateState { current in
                            var current = current
                            let image = value.execute(arguments, value.data)?.generateImage()
                            current.quickImage = image
                            return current
                        }
                    }))
                }
            }
        }))
        
        
      

        
        let signal = combineLatest(queue: prepareQueue, statePromise.get(), stickerPacks, featured, archivedPromise.get(), appearanceSignal, preferencesView, context.reactions.stateValue)
            |> map { state, view, featured, archived, appearance, preferencesView, availableReactions -> TableUpdateTransition in
                
                var stickerSettings = StickerSettings.defaultSettings
                if let view = preferencesView.views[preferencesKey] as? PreferencesView {
                    if let value = view.values[stickerSettingsKey]?.get(StickerSettings.self) {
                        stickerSettings = value
                    }
                }
                
                var autoplayMedia = AutoplayMediaPreferences.defaultSettings
                if let view = preferencesView.views[preferencesKey] as? PreferencesView {
                    if let value = view.values[autoplayKey]?.get(AutoplayMediaPreferences.self) {
                        autoplayMedia = value
                    }
                }
                
                let entries = installedStickerPacksControllerEntries(state: state, autoplayMedia: autoplayMedia, stickerSettings: stickerSettings, view: view, featured: featured, archived: archived, availableReactions: availableReactions).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify({$0}), arguments: arguments)
        } |> afterDisposed {
            actionsDisposable.dispose()
        } |> deliverOnMainQueue
        
        
        disposbale.set(signal.start(next: { [weak self] transition in
            guard let `self` = self else {return}
            
            self.genericView.merge(with: transition)
            
            self.readyOnce()

            if !transition.isEmpty {
                var start: Int? = nil
                var length: Int = 0
                self.genericView.enumerateItems(with: { item -> Bool in
                    if item is StickerSetTableRowItem {
                        if start == nil {
                            start = item.index
                        }
                        length += 1
                    } else if start != nil {
                        return false
                    }
                    return true
                })
                if let start = start {
                    self.genericView.resortController = TableResortController(resortRange: NSMakeRange(start, length), startTimeout: 0.2, start: { _ in }, resort: { _ in }, complete: { fromIndex, toIndex in
                        
                        
                        if fromIndex == toIndex {
                            return
                        }
                        
                        let entries = previousEntries.with {$0}.map( {$0.entry })
                        
                        
                        let fromEntry = entries[fromIndex]
                        guard case let .pack(_, _, fromPackInfo, _, _, _, _, _, _) = fromEntry else {
                            return
                        }
                        
                        var referenceId: ItemCollectionId?
                        var beforeAll = false
                        var afterAll = false
                        if toIndex < entries.count {
                            switch entries[toIndex] {
                            case let .pack(_, _, toPackInfo, _, _, _, _, _, _):
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
                                addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: Namespaces.ItemCollection.CloudStickerPacks, content: .sync, noDelay: false)
                                transaction.replaceItemCollectionInfos(namespace: Namespaces.ItemCollection.CloudStickerPacks, itemCollectionInfos: infos)
                            }
                        }).start()
                        
                    })
                } else {
                    self.genericView.resortController = nil
                }
            }
            
           
            
        }))
        
        
    }
    
}
