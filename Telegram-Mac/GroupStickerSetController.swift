//
//  GroupStickerSetController.swift
//  Telegram
//
//  Created by keepcoder on 24/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

private final class GroupStickersArguments {
    let context: AccountContext
    let textChanged:(String, String)->Void
    let installStickerset:((StickerPackCollectionInfo, [ItemCollectionItem], Int32))->Void
    let openChat:(PeerId)->Void
    init(context: AccountContext, textChanged:@escaping(String, String)->Void, installStickerset:@escaping((StickerPackCollectionInfo, [ItemCollectionItem], Int32))->Void, openChat:@escaping(PeerId)->Void) {
        self.context = context
        self.textChanged = textChanged
        self.installStickerset = installStickerset
        self.openChat = openChat
    }
}

private enum GroupStickersetEntryId: Hashable {
    case section(Int32)
    case input
    case status
    case description(Int32)
    case pack(ItemCollectionId)
    
    var hashValue: Int {
        return 0
    }
}

private enum GroupStickersetLoadingStatus : Equatable {
    case loaded(StickerPackCollectionInfo, StickerPackItem?, Int32)
    case loading
    case failed
}

private enum GroupStickersetEntry : TableItemListNodeEntry {
    case section(Int32)
    case input(Int32, value: String)
    case status(Int32, status:GroupStickersetLoadingStatus)
    case description(Int32, Int32, text: String)
    case pack(Int32, Int32, StickerPackCollectionInfo, StickerPackItem?, Int32, Bool)

    var stableId: GroupStickersetEntryId {
        switch self {
        case .section(let id):
            return .section(id)
        case .input:
            return .input
        case .status:
            return .status
        case .description(_, let id, _):
            return .description(id)
        case .pack(_, _, let info, _, _, _):
            return .pack(info.id)
        }
    }
    
    var stableIndex:Int32 {
        switch self {
        case .input:
            return 0
        case .status:
            return 1
        case .description(_, let index, _):
            return 2 + index
        case .pack:
            fatalError("")
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    var index:Int32 {
        switch self {
        case let .input(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .status(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .description(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .pack( sectionId, index, _, _, _, _):
            return (sectionId * 1000) + 100 + index
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func <(lhs: GroupStickersetEntry, rhs: GroupStickersetEntry) -> Bool {
        return lhs.index < rhs.index
    }
    func item(_ arguments: GroupStickersArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case let .input(_, value):
            return GeneralInputRowItem(initialSize, stableId: stableId, placeholder: "t.me/addstickers/", text: value, limit: 30, insets: NSEdgeInsets(left: 30, right: 30, top: 2, bottom: 3), textChangeHandler: { updatedText in
                arguments.textChanged(value, updatedText)
            }, textFilter: { text -> String in
                var filter = NSCharacterSet.alphanumerics
                filter.insert(charactersIn: "_")
                return text.trimmingCharacters(in: filter.inverted)
            }, holdText:true, pasteFilter: { value in
                if let index = value.range(of: "t.me/addstickers/") {
                    return (true, value.substring(from: index.upperBound))
                }
                return (false, value)
            }, canFastClean: true)
        case let .description(_, _, text):
            let attr = NSMutableAttributedString()
            _ = attr.append(string: text, color: theme.colors.grayText, font: .normal(.text))
            
            attr.detectLinks(type: [.Mentions, .Hashtags], context: arguments.context, color: theme.colors.link, openInfo: { peerId, _, _, _ in
                arguments.openChat(peerId)
            })
            return GeneralTextRowItem(initialSize, stableId: stableId, text: attr)
        case let .status(_, status):
            switch status {
            case let .loaded(info, topItem, count):
                return StickerSetTableRowItem(initialSize, account: arguments.context.account, stableId: stableId, info: info, topItem: topItem, itemCount: count, unread: false, editing: ItemListStickerPackItemEditing(editable: false, editing: false), enabled: true, control: .empty, action: {})
            case .loading:
                return LoadingTableItem(initialSize, height: 50, stableId: stableId)
            case .failed:
                return EmptyGroupstickerSearchRowItem(initialSize, height: 50, stableId: stableId)
            }
        case let .pack(_, _, info, topItem, count, selected):
            return StickerSetTableRowItem(initialSize, account: arguments.context.account, stableId: stableId, info: info, topItem: topItem, itemCount: count, unread: false, editing: ItemListStickerPackItemEditing(editable: false, editing: false), enabled: true, control: selected ? .selected : .empty, action: {
                if let topItem = topItem {
                    arguments.installStickerset((info, [topItem], count))
                }
            })
        }
    }
    
}

private func groupStickersEntries(state: GroupStickerSetControllerState, view: CombinedView, peerId: PeerId, specificPack: (StickerPackCollectionInfo, [ItemCollectionItem])?) -> [GroupStickersetEntry] {
    var entries: [GroupStickersetEntry] = []
    
    var sectionId:Int32 = 1
    
    var descriptionId:Int32 = 1
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    let value: String
    if let updatedText = state.updatedText {
        value = updatedText
    } else {
        if let specificPack = specificPack {
            value = specificPack.0.shortName
        } else {
            value = ""
        }
    }
    
    entries.append(.input(sectionId, value: value))
    
    
    
    if state.loading {
        entries.append(.status(sectionId, status: .loading))
    } else {
        if state.failed {
            entries.append(.status(sectionId, status: .failed))
        } else if let loadedPack = state.loadedPack {
            entries.append(.status(sectionId, status: .loaded(loadedPack.0, loadedPack.1.first as? StickerPackItem, loadedPack.2)))
        } else {
            if let specificPack = specificPack, !value.isEmpty {
                entries.append(.status(sectionId, status: .loaded(specificPack.0, specificPack.1.first as? StickerPackItem, Int32(specificPack.1.count))))
            }
        }
    }
    
    entries.append(.description(sectionId, descriptionId, text: tr(L10n.groupStickersCreateDescription)))
    descriptionId += 1

    
    entries.append(.section(sectionId))
    sectionId += 1
    
    
    
    entries.append(.description(sectionId, descriptionId, text: tr(L10n.groupStickersChooseHeader)))
    descriptionId += 1
    if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])] as? ItemCollectionInfosView {
        if let packsEntries = stickerPacksView.entriesByNamespace[Namespaces.ItemCollection.CloudStickerPacks] {
            var index: Int32 = 0
            for entry in packsEntries {
                if let info = entry.info as? StickerPackCollectionInfo {
                    var selected: Bool
                    if let loadedPack = state.loadedPack {
                        selected = info == loadedPack.0
                    } else {
                        selected = info == specificPack?.0
                    }
                    entries.append(.pack(sectionId, index, info, entry.firstItem as? StickerPackItem, info.count == 0 ? entry.count : info.count, selected))
                    index += 1
                }
            }
        }
    }
    entries.append(.section( sectionId))
    sectionId += 1
    
    
    return entries
}

private func prepareTransition(left:[AppearanceWrapperEntry<GroupStickersetEntry>], right: [AppearanceWrapperEntry<GroupStickersetEntry>], initialSize: NSSize, arguments: GroupStickersArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


private struct GroupStickerSetControllerState: Equatable {
    let loading: Bool
    let updatedText:String?
    let failed: Bool
    let loadedPack:(StickerPackCollectionInfo, [ItemCollectionItem], Int32)?
    init(loading: Bool = false, updatedText: String? = nil, failed: Bool = false, loadedPack:(StickerPackCollectionInfo, [ItemCollectionItem], Int32)? = nil) {
        self.loading = loading
        self.failed = failed
        self.loadedPack = loadedPack
        self.updatedText = updatedText
    }
    static func ==(lhs: GroupStickerSetControllerState, rhs: GroupStickerSetControllerState) -> Bool {
        return lhs.loading == rhs.loading && lhs.updatedText == rhs.updatedText && lhs.failed == rhs.failed && lhs.loadedPack?.0 == rhs.loadedPack?.0
    }
    
    func withUpdatedText(_ updatedText:String?) -> GroupStickerSetControllerState {
        return GroupStickerSetControllerState(loading: self.loading, updatedText: updatedText, failed: self.failed, loadedPack: self.loadedPack)
    }
    func withUpdatedLoading(_ loading:Bool) -> GroupStickerSetControllerState {
        return GroupStickerSetControllerState(loading: loading, updatedText: self.updatedText, failed: self.failed, loadedPack: self.loadedPack)
    }
    func withUpdatedFailed(_ failed:Bool) -> GroupStickerSetControllerState {
        return GroupStickerSetControllerState(loading: self.loading, updatedText: self.updatedText, failed: failed, loadedPack: self.loadedPack)
    }
    func withUpdatedLoadedPack(_ loadedPack:(StickerPackCollectionInfo, [ItemCollectionItem], Int32)?) -> GroupStickerSetControllerState {
        return GroupStickerSetControllerState(loading: self.loading, updatedText: self.updatedText, failed: self.failed, loadedPack: loadedPack)
    }
}

class GroupStickerSetController: TableViewController {
    private let peerId: PeerId
    private var saveGroupStickerSet:(()->Void)? = nil
    init(_ context: AccountContext, peerId:PeerId) {
        self.peerId = peerId
        super.init(context)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        let peerId = self.peerId
        
        let statePromise = ValuePromise(GroupStickerSetControllerState(), ignoreRepeated: true)
        let stateValue = Atomic(value: GroupStickerSetControllerState())
        let updateState: ((GroupStickerSetControllerState) -> GroupStickerSetControllerState) -> Void = { f in
            statePromise.set(stateValue.modify { f($0) })
        }
        
        
        
        let actionsDisposable = DisposableSet()
        
        let resolveDisposable = MetaDisposable()
        actionsDisposable.add(resolveDisposable)
        
        let arguments = GroupStickersArguments(context: context, textChanged: { current, updated in
            updateState({$0.withUpdatedLoadedPack(nil).withUpdatedFailed(false).withUpdatedText(updated)})
            if updated.isEmpty {
                resolveDisposable.set(nil)
            } else {
                resolveDisposable.set((loadedStickerPack(postbox: context.account.postbox, network: context.account.network, reference: .name(updated), forceActualized: false) |> deliverOnMainQueue).start(next: { result in
                    switch result {
                    case .fetching:
                        updateState({$0.withUpdatedLoadedPack(nil).withUpdatedLoading(true)})
                    case .none:
                        updateState({$0.withUpdatedLoadedPack(nil).withUpdatedLoading(false).withUpdatedFailed(true)})
                    case let .result(info, items, _):
                        updateState({$0.withUpdatedLoadedPack((info, items, Int32(items.count))).withUpdatedLoading(false).withUpdatedFailed(false)})
                    }
                }))
            }
        }, installStickerset: { info in
            updateState({$0.withUpdatedLoadedPack(info).withUpdatedText(info.0.shortName)})
        }, openChat: { [weak self] peerId in
            self?.navigationController?.push(ChatController(context: context, chatLocation: .peer(peerId)))
        })
        
        saveGroupStickerSet = { [weak self] in
            if let strongSelf = self {
                actionsDisposable.add(showModalProgress(signal: updateGroupSpecificStickerset(postbox: context.account.postbox, network: context.account.network, peerId: peerId, info: stateValue.modify{$0}.loadedPack?.0), for: mainWindow).start(next: { [weak strongSelf] _ in
                    strongSelf?.navigationController?.back()
                }, error: { [weak strongSelf] _ in
                    strongSelf?.navigationController?.back()
                }))
                self?.doneButton?.isEnabled = false
            }
        }
        
        let stickerPacks = Promise<CombinedView>()
        stickerPacks.set(context.account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])]))
        
        let featured = Promise<[FeaturedStickerPackItem]>()
        featured.set(context.account.viewTracker.featuredStickerPacks())
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<GroupStickersetEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        genericView.merge(with: combineLatest(statePromise.get() |> deliverOnMainQueue, stickerPacks.get() |> deliverOnMainQueue, peerSpecificStickerPack(postbox: context.account.postbox, network: context.account.network, peerId: peerId) |> deliverOnMainQueue, appearanceSignal)
            |> map { state, view, specificPack, appearance -> TableUpdateTransition in
                let entries = groupStickersEntries(state: state, view: view, peerId: peerId, specificPack: specificPack.packInfo).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify({$0}), arguments: arguments)
            } |> afterDisposed {
                actionsDisposable.dispose()
            } )
        readyOnce()
        
        actionsDisposable.add((statePromise.get() |> deliverOnMainQueue).start(next: { [weak self] state in
            var enabled = !state.failed
            if state.loadedPack != nil {
                enabled = true
            } else if let text = state.updatedText {
                enabled = text.isEmpty
            } else {
                enabled = false
            }
            self?.doneButton?.isEnabled = enabled
        }))
    }

    var doneButton:Control? {
        return rightBarView
    }
    
    override func getRightBarViewOnce() -> BarView {
        let button = TextButtonBarView(controller: self, text: tr(L10n.navigationDone))
        
        button.set(handler: { [weak self] _ in
            self?.saveGroupStickerSet?()
        }, for: .Click)
        
        return button
    }
    
}
