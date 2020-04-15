//
//  GroupStickerSetController.swift
//  Telegram
//
//  Created by keepcoder on 24/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

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
    case input(Int32, value: String, viewType: GeneralViewType)
    case status(Int32, status:GroupStickersetLoadingStatus, viewType: GeneralViewType)
    case description(Int32, Int32, text: String, viewType: GeneralViewType)
    case pack(Int32, Int32, StickerPackCollectionInfo, StickerPackItem?, Int32, Bool, GeneralViewType)
    
    func withUpdatedViewType(_ viewType: GeneralViewType) -> GroupStickersetEntry {
        switch self {
        case .section: return self
        case let .input(sectionId, value: value, _): return .input(sectionId, value: value, viewType: viewType)
        case let .status(sectionId, status: status, _): return .status(sectionId, status: status, viewType: viewType)
        case let .description(sectionId, index, text: text, _): return .description(sectionId, index, text: text, viewType: viewType)
        case let .pack(sectionId, index, info, item, count, selected, _): return .pack(sectionId, index, info, item, count, selected, viewType)
        }
    }

    var stableId: GroupStickersetEntryId {
        switch self {
        case .section(let id):
            return .section(id)
        case .input:
            return .input
        case .status:
            return .status
        case .description(_, let id, _, _):
            return .description(id)
        case .pack(_, _, let info, _, _, _, _):
            return .pack(info.id)
        }
    }
    
    var stableIndex:Int32 {
        switch self {
        case .input:
            return 0
        case .status:
            return 1
        case .description(_, let index, _, _):
            return 2 + index
        case .pack:
            fatalError("")
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    var index:Int32 {
        switch self {
        case let .input(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .status(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .description(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .pack( sectionId, index, _, _, _, _, _):
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
            return GeneralRowItem(initialSize, height: 30, stableId: stableId, viewType: .separator)
        case let .input(_, value, viewType):
            return InputDataRowItem(initialSize, stableId: stableId, mode: .plain, error: nil, viewType: viewType, currentText: value, placeholder: nil, inputPlaceholder: "https://t.me/addstickers/", defaultText: "https://t.me/addstickers/", rightItem: .action(theme.icons.recentDismiss, .clearText), filter: { text in
                var filter = NSCharacterSet.alphanumerics
                filter.insert(charactersIn: "_")
                return text.trimmingCharacters(in: filter.inverted)
            }, updated: { updatedText in
                 arguments.textChanged(value, updatedText)
            }, pasteFilter: { value in
                if let index = value.range(of: "t.me/addstickers/") {
                    return (true, String(value[index.upperBound...]))
                }
                return (false, value)
            }, limit: 30)
            
        case let .description(_, _, text, viewType):
            let attr = NSMutableAttributedString()
            _ = attr.append(string: text, color: theme.colors.grayText, font: .normal(.text))
            
            attr.detectLinks(type: [.Mentions, .Hashtags], context: arguments.context, color: theme.colors.link, openInfo: { peerId, _, _, _ in
                arguments.openChat(peerId)
            })
            return GeneralTextRowItem(initialSize, stableId: stableId, text: attr, viewType: viewType)
        case let .status(_, status, viewType):
            switch status {
            case let .loaded(info, topItem, count):
                return StickerSetTableRowItem(initialSize, context: arguments.context, stableId: stableId, info: info, topItem: topItem, itemCount: count, unread: false, editing: ItemListStickerPackItemEditing(editable: false, editing: false), enabled: true, control: .empty, viewType: viewType, action: {})
            case .loading:
                return LoadingTableItem(initialSize, height: 50, stableId: stableId, viewType: viewType)
            case .failed:
                return EmptyGroupstickerSearchRowItem(initialSize, height: 50, stableId: stableId, viewType: viewType)
            }
        case let .pack(_, _, info, topItem, count, selected, viewType):
            return StickerSetTableRowItem(initialSize, context: arguments.context, stableId: stableId, info: info, topItem: topItem, itemCount: count, unread: false, editing: ItemListStickerPackItemEditing(editable: false, editing: false), enabled: true, control: selected ? .selected : .empty, viewType: viewType, action: {
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
    
    
    var inputBlock: [GroupStickersetEntry] = []
    func applyBlock(_ block:[GroupStickersetEntry]) {
        var block = block
        for (i, item) in block.enumerated() {
            block[i] = item.withUpdatedViewType(bestGeneralViewType(block, for: i))
        }
        entries.append(contentsOf: block)
    }
    
    inputBlock.append(.input(sectionId, value: value, viewType: .singleItem))
    
    if state.loading {
        inputBlock.append(.status(sectionId, status: .loading, viewType: .singleItem))
    } else {
        if state.failed {
            inputBlock.append(.status(sectionId, status: .failed, viewType: .singleItem))
        } else if let loadedPack = state.loadedPack {
            inputBlock.append(.status(sectionId, status: .loaded(loadedPack.0, loadedPack.1.first as? StickerPackItem, loadedPack.2), viewType: .singleItem))
        } else {
            if let specificPack = specificPack, !value.isEmpty {
                inputBlock.append(.status(sectionId, status: .loaded(specificPack.0, specificPack.1.first as? StickerPackItem, Int32(specificPack.1.count)), viewType: .singleItem))
            }
        }
    }
    
    applyBlock(inputBlock)
    
    entries.append(.description(sectionId, descriptionId, text: L10n.groupStickersCreateDescription, viewType: .textBottomItem))
    descriptionId += 1

    
    entries.append(.section(sectionId))
    sectionId += 1
    
    
    
    entries.append(.description(sectionId, descriptionId, text: L10n.groupStickersChooseHeader, viewType: .textTopItem))
    descriptionId += 1
    if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])] as? ItemCollectionInfosView {
        if let packsEntries = stickerPacksView.entriesByNamespace[Namespaces.ItemCollection.CloudStickerPacks] {
            var index: Int32 = 0
            for (i, entry) in packsEntries.enumerated() {
                if let info = entry.info as? StickerPackCollectionInfo {
                    var selected: Bool
                    if let loadedPack = state.loadedPack {
                        selected = info == loadedPack.0
                    } else {
                        selected = info == specificPack?.0
                    }
                    entries.append(.pack(sectionId, index, info, entry.firstItem as? StickerPackItem, info.count == 0 ? entry.count : info.count, selected, bestGeneralViewType(packsEntries, for: i)))
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
    private let disposable = MetaDisposable()
    private var saveGroupStickerSet:(()->Void)? = nil
    init(_ context: AccountContext, peerId:PeerId) {
        self.peerId = peerId
        super.init(context)
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override func firstResponder() -> NSResponder? {
        var responder: NSResponder?
        genericView.enumerateViews { view -> Bool in
            if responder == nil, let firstResponder = view.firstResponder {
                responder = firstResponder
                return false
            }
            return true
        }
        return responder
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
        
        let signal = combineLatest(queue: prepareQueue,statePromise.get(), stickerPacks.get(), peerSpecificStickerPack(postbox: context.account.postbox, network: context.account.network, peerId: peerId), appearanceSignal)
            |> map { state, view, specificPack, appearance -> TableUpdateTransition in
                let entries = groupStickersEntries(state: state, view: view, peerId: peerId, specificPack: specificPack.packInfo).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                return prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify({$0}), arguments: arguments)
            } |> afterDisposed {
                actionsDisposable.dispose()
        } |> deliverOnMainQueue
        
        self.disposable.set(signal.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
        
       
        
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
