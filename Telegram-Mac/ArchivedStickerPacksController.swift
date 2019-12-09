//
//  ArchivedStickerPacksController.swift
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
import SyncCore

private final class ArchivedStickerPacksControllerArguments {
    let context: AccountContext
    
    let openStickerPack: (StickerPackCollectionInfo) -> Void
    let removePack: (StickerPackCollectionInfo) -> Void
    
    init(context: AccountContext, openStickerPack: @escaping (StickerPackCollectionInfo) -> Void, removePack: @escaping (StickerPackCollectionInfo) -> Void) {
        self.context = context
        self.openStickerPack = openStickerPack
        self.removePack = removePack
    }
}



private enum ArchivedStickerPacksEntryId: Hashable {
    case index(Int32)
    case pack(ItemCollectionId)
    case loading
    var hashValue: Int {
        switch self {
        case let .index(index):
            return index.hashValue
        case let .pack(id):
            return id.hashValue
        case .loading:
            return -100
        }
    }
}

private enum ArchivedStickerPacksEntry: TableItemListNodeEntry {
    case section(sectionId:Int32)
    case info(sectionId:Int32, String, GeneralViewType)
    case pack(sectionId:Int32, Int32, StickerPackCollectionInfo, StickerPackItem?, Int32, Bool, ItemListStickerPackItemEditing, GeneralViewType)
    case loading(Bool)
    
    var stableId: ArchivedStickerPacksEntryId {
        switch self {
        case .info:
            return .index(0)
        case .loading:
            return .loading
        case let .pack(_, _, info, _, _, _, _, _):
            return .pack(info.id)
        case let .section(sectionId):
            return .index((sectionId + 1) * 1000 - sectionId)
        }
    }
    

    
    var stableIndex:Int32 {
        switch self {
        case .info:
            return 0
        case .loading:
            return -1
        case .pack:
            fatalError("")
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    var index:Int32 {
        switch self {
        case .loading:
            return 0
        case let .info(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .pack( sectionId, index, _, _, _, _, _, _):
            return (sectionId * 1000) + 100 + index
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func <(lhs: ArchivedStickerPacksEntry, rhs: ArchivedStickerPacksEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: ArchivedStickerPacksControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .info(_, text, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: viewType)
        case let .pack(_, _, info, topItem, count, enabled, editing, viewType):
            return StickerSetTableRowItem(initialSize, context: arguments.context, stableId: stableId, info: info, topItem: topItem, itemCount: count, unread: false, editing: editing, enabled: enabled, control: .remove, viewType: viewType, action: {
                arguments.openStickerPack(info)
            }, addPack: {
                
            }, removePack: {
                arguments.removePack(info)
            })
        case .section:
            return GeneralRowItem(initialSize, height: 30, stableId: stableId, viewType: .separator)
        case .loading(let loading):
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: loading, text: L10n.archivedStickersEmpty)
        }
    }
}

private struct ArchivedStickerPacksControllerState: Equatable {
    let editing: Bool
    let removingPackIds: Set<ItemCollectionId>
    
    init() {
        self.editing = false
        self.removingPackIds = Set()
    }
    
    init(editing: Bool, removingPackIds: Set<ItemCollectionId>) {
        self.editing = editing
        self.removingPackIds = removingPackIds
    }
    
    static func ==(lhs: ArchivedStickerPacksControllerState, rhs: ArchivedStickerPacksControllerState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.removingPackIds != rhs.removingPackIds {
            return false
        }
        
        return true
    }
    
    func withUpdatedEditing(_ editing: Bool) -> ArchivedStickerPacksControllerState {
        return ArchivedStickerPacksControllerState(editing: editing, removingPackIds: self.removingPackIds)
    }
    
    func withUpdatedRemovingPackIds(_ removingPackIds: Set<ItemCollectionId>) -> ArchivedStickerPacksControllerState {
        return ArchivedStickerPacksControllerState(editing: editing, removingPackIds: removingPackIds)
    }
}

private func archivedStickerPacksControllerEntries(state: ArchivedStickerPacksControllerState, packs: [ArchivedStickerPackItem]?, installedView: CombinedView) -> [ArchivedStickerPacksEntry] {
    var entries: [ArchivedStickerPacksEntry] = []
    
   
    
    if let packs = packs {
        
        
        if packs.isEmpty {
            entries.append(.loading(false))
        } else {
            var sectionId:Int32 = 1
            
            entries.append(.section(sectionId: sectionId))
            sectionId += 1
            
            entries.append(.info(sectionId: sectionId, L10n.archivedStickersDescription, .textTopItem))
                        
            var installedIds = Set<ItemCollectionId>()
            if let view = installedView.views[.itemCollectionIds(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])] as? ItemCollectionIdsView, let ids = view.idsByNamespace[Namespaces.ItemCollection.CloudStickerPacks] {
                installedIds = ids
            }
            
            let packs = packs.filter { item in
                return !installedIds.contains(item.info.id)
            }
            
            var index: Int32 = 0
            for item in packs {
                entries.append(.pack(sectionId: sectionId, index, item.info, item.topItems.first, item.info.count, !state.removingPackIds.contains(item.info.id), ItemListStickerPackItemEditing(editable: true, editing: state.editing), bestGeneralViewType(packs, for: item)))
                index += 1
            }
            entries.append(.section(sectionId: sectionId))
            sectionId += 1
        }
    } else {
        entries.append(.loading(true))
    }
    
    return entries
}


private func prepareTransition(left:[AppearanceWrapperEntry<ArchivedStickerPacksEntry>], right: [AppearanceWrapperEntry<ArchivedStickerPacksEntry>], initialSize: NSSize, arguments: ArchivedStickerPacksControllerArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


class ArchivedStickerPacksController: TableViewController {
    private let disposable = MetaDisposable()
    
    deinit {
        disposable.dispose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        let statePromise = ValuePromise(ArchivedStickerPacksControllerState(), ignoreRepeated: true)
        let stateValue = Atomic(value: ArchivedStickerPacksControllerState())
        let updateState: ((ArchivedStickerPacksControllerState) -> ArchivedStickerPacksControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        let actionsDisposable = DisposableSet()
        
        let resolveDisposable = MetaDisposable()
        actionsDisposable.add(resolveDisposable)
        
        let removePackDisposables = DisposableDict<ItemCollectionId>()
        actionsDisposable.add(removePackDisposables)
        
        let stickerPacks = Promise<[ArchivedStickerPackItem]?>()
        stickerPacks.set(.single(nil) |> then(archivedStickerPacks(account: context.account) |> map { Optional($0) }))
        
        let installedStickerPacks = Promise<CombinedView>()
        installedStickerPacks.set(context.account.postbox.combinedView(keys: [.itemCollectionIds(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])]))
        
        let arguments = ArchivedStickerPacksControllerArguments(context: context, openStickerPack: { info in
          showModal(with: StickerPackPreviewModalController(context, peerId: nil, reference: .name(info.shortName)), for: mainWindow)
        }, removePack: { info in
            confirm(for: mainWindow, information: tr(L10n.chatConfirmActionUndonable), successHandler: { _ in
                var remove = false
                updateState { state in
                    var removingPackIds = state.removingPackIds
                    if !removingPackIds.contains(info.id) {
                        removingPackIds.insert(info.id)
                        remove = true
                    }
                    return state.withUpdatedRemovingPackIds(removingPackIds)
                }
                if remove {
                    let applyPacks: Signal<Void, NoError> = stickerPacks.get()
                        |> filter { $0 != nil }
                        |> take(1)
                        |> deliverOnMainQueue
                        |> mapToSignal { packs -> Signal<Void, NoError> in
                            if let packs = packs {
                                var updatedPacks = packs
                                for i in 0 ..< updatedPacks.count {
                                    if updatedPacks[i].info.id == info.id {
                                        updatedPacks.remove(at: i)
                                        break
                                    }
                                }
                                stickerPacks.set(.single(updatedPacks))
                            }
                            
                            return .complete()
                    }
                    removePackDisposables.set((removeArchivedStickerPack(account: context.account, info: info) |> then(applyPacks) |> deliverOnMainQueue).start(completed: {
                        updateState { state in
                            var removingPackIds = state.removingPackIds
                            removingPackIds.remove(info.id)
                            return state.withUpdatedRemovingPackIds(removingPackIds)
                        }
                    }), forKey: info.id)
                }

            })
        })
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<ArchivedStickerPacksEntry>]> = Atomic(value: [])
        let initialSize = atomicSize
        
        let signal = combineLatest(queue: prepareQueue, statePromise.get(), stickerPacks.get(), installedStickerPacks.get(), appearanceSignal)
            |> map { state, packs, installedView, appearance -> TableUpdateTransition in
                
                let entries = archivedStickerPacksControllerEntries(state: state, packs: packs, installedView: installedView).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify({$0}), arguments: arguments)
        } |> afterDisposed {
                actionsDisposable.dispose()
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
        
        
    }
}
