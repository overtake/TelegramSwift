//
//  EmojiesController.swift
//  Telegram
//
//  Created by Mike Renoir on 30.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import InAppSettings
import Postbox

private final class Arguments {
    let context: AccountContext
    let send:(StickerPackItem, StickerPackReference)->Void
    let sendEmoji:(String)->Void
    let selectEmojiSegment:(EmojiSegment)->Void
    let viewSet:(StickerPackCollectionInfo)->Void
    init(context: AccountContext, send:@escaping(StickerPackItem, StickerPackReference)->Void, sendEmoji:@escaping(String)->Void, selectEmojiSegment:@escaping(EmojiSegment)->Void, viewSet:@escaping(StickerPackCollectionInfo)->Void) {
        self.context = context
        self.send = send
        self.sendEmoji = sendEmoji
        self.selectEmojiSegment = selectEmojiSegment
        self.viewSet = viewSet
    }
}

private struct State : Equatable {

    struct EmojiState : Equatable {
        var selected: EmojiSegment?
    }
    
    struct Section : Equatable {
        var info: StickerPackCollectionInfo
        var items:[StickerPackItem]
    }
    var sections:[Section]
    var peer: PeerEquatable?
    var emojiState: EmojiState = .init(selected: nil)
}

private func _id_section(_ id:Int64) -> InputDataIdentifier {
    return .init("_id_section_\(id)")
}
private func _id_pack(_ id: Int64) -> InputDataIdentifier {
    return .init("_id_pack_\(id)")
}
private func _id_emoji_segment(_ segment:Int64) -> InputDataIdentifier {
    return .init("_id_emoji_segment_\(segment)")
}
private func _id_aemoji_block(_ segment:Int64) -> InputDataIdentifier {
    return .init("_id_aemoji_block\(segment)")
}
private func _id_emoji_block(_ segment: Int64) -> InputDataIdentifier {
    return .init("_id_emoji_block_\(segment)")
}
private let _id_segments_pack = InputDataIdentifier("_id_segments_pack")
private let _id_recent_pack = InputDataIdentifier("_id_recent_pack")

private func packEntries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var index: Int32 = 0
    var sectionId:Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("left"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 6, stableId: stableId, backgroundColor: .clear)
    }))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_recent_pack, equatable: nil, comparable: nil, item: { initialSize, stableId in
        return ETabRowItem(initialSize, stableId: stableId, icon: theme.icons.emojiRecentTab, iconSelected: theme.icons.emojiRecentTabActive)
    }))
    index += 1
   

    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_segments_pack, equatable: InputDataEquatable(state.emojiState), comparable: nil, item: { initialSize, stableId in
        return EmojiTabsItem(initialSize, stableId: stableId, segments: EmojiSegment.all, selected: state.emojiState.selected, select: arguments.selectEmojiSegment)
    }))
    index += 1

    
    for section in state.sections {
        
        let isPremium = section.items.contains(where: { $0.file.isPremiumEmoji })
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_pack(section.info.id.id), equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
            return StickerPackRowItem(initialSize, stableId: stableId, packIndex: 0, isPremium: isPremium, context: arguments.context, info: section.info, topItem: section.items.first)
        }))
        index += 1
        
        
    }
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("right"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 6, stableId: stableId, backgroundColor: .clear)
    }))
    index += 1
    
    return entries
}



private func entries(_ state: State, recent: RecentUsedEmoji, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .custom(10)))
    sectionId += 1
    
    var e = emojiesInstance
    e[EmojiSegment.Recent] = recent.emojies
    let seg = segments(e, skinModifiers: recent.skinModifiers)
    let seglist = seg.map { (key,_) -> EmojiSegment in
        return key
    }.sorted(by: <)
    
    
    for key in seglist {
        if key != .Recent {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_emoji_segment(key.rawValue), equatable: InputDataEquatable(key), comparable: nil, item: { initialSize, stableId in
                return EStickItem(initialSize, stableId: stableId, segmentName:key.localizedString)
            }))
            index += 1
        }
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_emoji_block(key.rawValue), equatable: InputDataEquatable(key), comparable: nil, item: { initialSize, stableId in
            return EBlockItem(initialSize, stableId: stableId, attrLines: seg[key]!, segment: key, account: arguments.context.account, selectHandler: arguments.sendEmoji)
        }))
        index += 1
        
    }
    
    for section in state.sections {
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_aemoji_block(section.info.id.id), equatable: InputDataEquatable(section.info), comparable: nil, item: { initialSize, stableId in
            return GeneralRowItem(initialSize, height: 10, stableId: stableId)
        }))
        index += 1
        
        
        struct Tuple : Equatable {
            let section: State.Section
            let isPremium: Bool
        }
        
        let tuple = Tuple(section: section, isPremium: state.peer?.peer.isPremium ?? false)
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_section(section.info.id.id), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
            return EmojiesSectionRowItem(initialSize, stableId: stableId, context: arguments.context, info: section.info, items: section.items, callback: { item in
                arguments.send(item, .name(section.info.shortName))
            }, viewSet: { info in
                arguments.viewSet(info)
            })
        }))
        index += 1
    }
  
    entries.append(.sectionId(sectionId, type: .custom(10)))
    sectionId += 1
    
    // entries
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    return entries
}

final class AnimatedEmojiesView : View {
    let tableView = TableView()
    let packsView = HorizontalTableView(frame: NSZeroRect)
    private let borderView = View()
    private let tabs = View()
    private let selectionView: View = View(frame: NSMakeRect(0, 0, 36, 36))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        self.packsView.getBackgroundColor = {
            .clear
        }
        
        tabs.addSubview(selectionView)
        tabs.addSubview(self.packsView)
        addSubview(self.tableView)
        addSubview(self.borderView)
        addSubview(tabs)
        
        self.packsView.addScroll(listener: .init(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            self?.updateSelectionState(animated: false)
        }))
        
    }
    
    override func layout() {
        super.layout()
        tabs.frame = NSMakeRect(0, 0, frame.width, 46)
        packsView.frame = tabs.focus(NSMakeSize(frame.width, 36))
        borderView.frame = NSMakeRect(0, tabs.frame.height, frame.width, .borderSize)
        tableView.frame = NSMakeRect(0, tabs.frame.maxY, frame.width, frame.height - tabs.frame.maxY)
        updateSelectionState(animated: false)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        borderView.backgroundColor = theme.colors.border
        tabs.backgroundColor = theme.colors.background
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(sections: TableUpdateTransition, packs: TableUpdateTransition) {
        self.tableView.merge(with: sections)
        self.packsView.merge(with: packs)
        
        updateSelectionState(animated: packs.animated)
    }
    
    func updateSelectionState(animated: Bool) {
        
        let item = packsView.selectedItem() ?? packsView.firstItem

        
        guard let item = item, let view = item.view else {
            return
        }
        
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }

        let point = packsView.clipView.destination ?? packsView.contentOffset
        
        let rect = NSMakeRect(view.frame.origin.y - point.y, 5, item.height, packsView.frame.height)
        
        selectionView.layer?.cornerRadius = item.height == item.width && item.index != 1 ? .cornerRadius : item.width / 2
        selectionView.background = theme.colors.grayBackground.withAlphaComponent(item.height == item.width ? 1 : 0.9)
        if animated {
            selectionView.layer?.animateCornerRadius()
        }
        transition.updateFrame(view: selectionView, frame: rect)
    }
    
    
    func scroll(to segment: EmojiSegment, animated: Bool) {
        if let item = packsView.item(stableId: InputDataEntryId.custom(_id_segments_pack)) {
            _ = self.packsView.select(item: item)
        }
        let stableId = InputDataEntryId.custom(_id_emoji_segment(segment.rawValue))
        tableView.scroll(to: .top(id: stableId, innerId: nil, animated: animated, focus: .init(focus: false), inset: 0))
        
        updateSelectionState(animated: animated)
    }
    
    func findSegmentAndScroll(selected: TableRowItem, animated: Bool) -> EmojiSegment? {
        let stableId = selected.stableId as? InputDataEntryId
        var segment: EmojiSegment?
        if let identifier = stableId?.identifier {
            if identifier == _id_recent_pack {
                tableView.scroll(to: .up(animated))
            } else if identifier == _id_segments_pack {
                segment = EmojiSegment.People
                let stableId = InputDataEntryId.custom(_id_emoji_segment(EmojiSegment.People.rawValue))
                tableView.scroll(to: .top(id: stableId, innerId: nil, animated: animated, focus: .init(focus: false), inset: 0))
            } else if identifier.identifier.hasPrefix("_id_pack_") {
                let collectionId = identifier.identifier.trimmingCharacters(in: CharacterSet(charactersIn: "1234567890").inverted)
                if let collectionId = Int64(collectionId) {
                    let stableId = InputDataEntryId.custom(_id_aemoji_block(collectionId))
                    tableView.scroll(to: .top(id: stableId, innerId: nil, animated: animated, focus: .init(focus: false), inset: 0))
                }
            }
        }
        updateSelectionState(animated: true)
        return segment
    }
    
    func selectBestPack() -> EmojiSegment? {
        let stableId = tableView.item(at: max(1, tableView.visibleRows().location)).stableId
        var _stableId: AnyHashable?
        var _segment: EmojiSegment?

        if let stableId = stableId as? InputDataEntryId, let identifier = stableId.identifier {
            let identifier = identifier.identifier
            
            if identifier.hasPrefix("_id_emoji_segment_") || identifier.hasPrefix("_id_emoji_block_") {
                if let segmentId = Int64(identifier.suffix(1)), let segment = EmojiSegment(rawValue: segmentId) {
                    switch segment {
                    case .Recent:
                        _stableId = InputDataEntryId.custom(_id_recent_pack)
                    default:
                        _stableId = InputDataEntryId.custom(_id_segments_pack)
                    }
                    _segment = segment
                }
            } else if identifier.hasPrefix("_id_section_") {
                let collectionId = identifier.trimmingCharacters(in: CharacterSet(charactersIn: "1234567890").inverted)
                if let collectionId = Int64(collectionId) {
                    _stableId = InputDataEntryId.custom(_id_pack(collectionId))
                }
            }
        }
        if let stableId = _stableId, let item = packsView.item(stableId: stableId) {
            _ = self.packsView.select(item: item)
            self.packsView.scroll(to: .center(id: stableId, innerId: nil, animated: true, focus: .init(focus: false), inset: 0))
        }
        updateSelectionState(animated: true)
        return _segment
    }
}

final class EmojiesController : TelegramGenericViewController<AnimatedEmojiesView>, TableViewDelegate {
    private let disposable = MetaDisposable()
    
    private var interactions: EntertainmentInteractions?
    private weak var chatInteraction: ChatInteraction?
    
    private var updateState: (((State) -> State) -> Void)? = nil

    
    
    override init(_ context: AccountContext) {
        super.init(context)
        _frameRect = NSMakeRect(0, 0, 350, 300)
        self.bar = .init(height: 0)

    }
    
    deinit {
        disposable.dispose()
    }
    
    private func updatePackReorder(_ sections: [State.Section]) {
        var resortRange: NSRange = NSMakeRange(3, genericView.packsView.count - 4)
        
        let context = self.context
        
        if resortRange.length > 0 {
            self.genericView.packsView.resortController = TableResortController(resortRange: resortRange, start: { _ in }, resort: { _ in }, complete: { fromIndex, toIndex in
                
                if fromIndex == toIndex {
                    return
                }
                
                let fromSection = sections[fromIndex - resortRange.location]
                let toSection = sections[toIndex - resortRange.location]

                let referenceId: ItemCollectionId = toSection.info.id
                
                let _ = (context.account.postbox.transaction { transaction -> Void in
                    var infos = transaction.getItemCollectionsInfos(namespace: Namespaces.ItemCollection.CloudEmojiPacks)
                    var reorderInfo: ItemCollectionInfo?
                    for i in 0 ..< infos.count {
                        if infos[i].0 == fromSection.info.id {
                            reorderInfo = infos[i].1
                            infos.remove(at: i)
                            break
                        }
                    }
                    if let reorderInfo = reorderInfo {
                        var inserted = false
                        for i in 0 ..< infos.count {
                            if infos[i].0 == referenceId {
                                if fromIndex < toIndex {
                                    infos.insert((fromSection.info.id, reorderInfo), at: i + 1)
                                } else {
                                    infos.insert((fromSection.info.id, reorderInfo), at: i)
                                }
                                inserted = true
                                break
                            }
                        }
                        if !inserted {
                            infos.append((fromSection.info.id, reorderInfo))
                        }
                        addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: Namespaces.ItemCollection.CloudEmojiPacks, content: .sync, noDelay: false)
                        transaction.replaceItemCollectionInfos(namespace: Namespaces.ItemCollection.CloudEmojiPacks, itemCollectionInfos: infos)
                    }
                 } |> deliverOnMainQueue).start(completed: { })
                
            })
        } else {
            self.genericView.packsView.resortController = nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        genericView.packsView.delegate = self
        
        
        let context = self.context
        let actionsDisposable = DisposableSet()
        
        let initialState = State(sections: [])
        
        let statePromise = ValuePromise<State>(ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }

        self.updateState = { f in
            updateState(f)
        }
        
        let arguments = Arguments(context: context, send: { [weak self] item, reference in
            if !context.isPremium && item.file.isPremiumEmoji {
                showModalText(for: context.window, text: strings().emojiPackPremiumAlert, callback: { _ in
                    showModal(with: PremiumBoardingController(context: context, source: .premium_stickers), for: context.window)
                })
            } else {
                self?.interactions?.sendAnimatedEmoji(item)
            }
        }, sendEmoji: { [weak self] emoji in
            self?.interactions?.sendEmoji(emoji)
        }, selectEmojiSegment: { [weak self] segment in
            self?.genericView.scroll(to: segment, animated: true)
            
            updateState { current in
                var current = current
                current.emojiState.selected = segment
                return current
            }
        }, viewSet: { info in
            showModal(with: StickerPackPreviewModalController(context, peerId: nil, reference: .emoji(.name(info.shortName))), for: context.window)
        })
        
        let selectUpdater = { [weak self] in
            if self?.genericView.tableView.clipView.isAnimateScrolling == true {
                return
            }
            
            let innerSegment = self?.genericView.selectBestPack()
            
            updateState { current in
                var current = current
                current.emojiState.selected = innerSegment
                return current
            }
        }
        
        genericView.tableView.addScroll(listener: .init(dispatchWhenVisibleRangeUpdated: true, { position in
            selectUpdater()
        }))
        
        let combined = combineLatest(recentUsedEmoji(postbox: context.account.postbox), statePromise.get())
        
        let signal:Signal<(sections: InputDataSignalValue, packs: InputDataSignalValue, state: State), NoError> = combined |> deliverOnPrepareQueue |> map { recent, state in
            let sections = InputDataSignalValue(entries: entries(state, recent: recent, arguments: arguments))
            let packs = InputDataSignalValue(entries: packEntries(state, arguments: arguments))
            return (sections: sections, packs: packs, state: state)
        }
        
        
        let previousSections: Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let previousPacks: Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])

        let initialSize = self.atomicSize
        
        let onMainQueue: Atomic<Bool> = Atomic(value: false)
        
        let inputArguments = InputDataArguments(select: { _, _ in
            
        }, dataUpdated: {
            
        })
        
        let transition: Signal<(sections: TableUpdateTransition, packs: TableUpdateTransition, state: State), NoError> = combineLatest(queue: .mainQueue(), appearanceSignal, signal) |> mapToQueue { appearance, state in
            let sectionEntries = state.sections.entries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            let packEntries = state.packs.entries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})

            let onMain = onMainQueue.swap(false)
            
            
            
            let sectionsTransition = prepareInputDataTransition(left: previousSections.swap(sectionEntries), right: sectionEntries, animated: state.sections.animated, searchState: state.sections.searchState, initialSize: initialSize.modify{$0}, arguments: inputArguments, onMainQueue: onMain)
            
            
            let packsTransition = prepareInputDataTransition(left: previousPacks.swap(packEntries), right: packEntries, animated: state.packs.animated, searchState: state.packs.searchState, initialSize: initialSize.modify{$0}, arguments: inputArguments, onMainQueue: onMain)

            return combineLatest(sectionsTransition, packsTransition) |> map { values in
                return (sections: values.0, packs: values.1, state: state.state)
            }
            
        } |> deliverOnMainQueue
        
        disposable.set(transition.start(next: { [weak self] values in
            self?.genericView.update(sections: values.sections, packs: values.packs)
            self?.readyOnce()
            selectUpdater()
            
            self?.updatePackReorder(values.state.sections)
            
        }))
 
        let emojies = context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 2000000)

        
        actionsDisposable.add(emojies.start(next: { view in
            updateState { current in
                var current = current
                var sections: [State.Section] = []
                
                for (_, info, _) in view.collectionInfos {
                    var files: [StickerPackItem] = []
                    if let info = info as? StickerPackCollectionInfo {
                        let items = view.entries
                        for (i, entry) in items.enumerated() {
                            if entry.index.collectionId == info.id {
                                if let item = view.entries[i].item as? StickerPackItem {
                                    files.append(item)
                                }
                            }
                        }
                        if !files.isEmpty {
                            sections.append(.init(info: info, items: files))
                        }
                    }
                }
                
                current.sections = sections
                return current
            }
        }))
        
        actionsDisposable.add(context.account.postbox.peerView(id: context.peerId).start(next: { view in
            updateState { current in
                var current = current
                if let peer = view.peers[view.peerId] {
                    current.peer = .init(peer)
                }
                return current
            }
        }))
            
         self.onDeinit = {
             actionsDisposable.dispose()
             _ = previousSections.swap([])
             _ = previousPacks.swap([])
         }
        
    }
    
    func update(with interactions:EntertainmentInteractions?, chatInteraction: ChatInteraction) {
        self.interactions = interactions
        self.chatInteraction = chatInteraction
    }
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return true
    }
    
    func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        return !(item is GeneralRowItem)
    }
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) {
        
        if byClick {
            let segment = genericView.findSegmentAndScroll(selected: item, animated: true)
            
            updateState? { current in
                var current = current
                current.emojiState.selected = segment
                return current
            }
        }
    }
    
    override func scrollup(force: Bool = false) {
        genericView.tableView.scroll(to: .up(true))
    }
    
    override var supportSwipes: Bool {
        return !genericView.packsView._mouseInside()
    }
}
