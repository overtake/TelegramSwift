//
//  PeerMediaGiftsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 05.09.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import TGUIKit
import SwiftSignalKit



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
        return .single(arguments.collectionContextMenu(item.value))
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
        textView.scaleOnClick = true
        textView.userInteractionEnabled = true
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
        
        self.textView.setSingle(handler: { [weak item] _ in
            if let item = item {
                item.arguments.collection(item.item.value, nil)
            }
        }, for: .Click)
        
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
                attr.append(string: "All Gifts", color: selected ? theme.colors.darkGrayText : theme.colors.listGrayText, font: .normal(.text))
            case let .collection(value):
                if let file = value.icon {
                    attr.append(string: "\(clown_space)\(value.title)", color: selected ? theme.colors.darkGrayText : theme.colors.listGrayText, font: .normal(.text))
                    attr.insertEmbedded(.embeddedAnimated(file, playPolicy: .framesCount(1)), for: clown)
                } else {
                    attr.append(string: value.title, color: selected ? theme.colors.darkGrayText : theme.colors.listGrayText, font: .normal(.text))
                }
            case .add:
                attr.append(string: "\(clown_space)Add Collection", color: selected ? theme.colors.darkGrayText : theme.colors.listGrayText, font: .normal(.text))
                attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.menu_add.file, color: theme.colors.listGrayText, playPolicy: .framesCount(1)), for: clown)
            }
            return attr
        }
    }
    
    fileprivate let items: [Item]
    fileprivate let selected: Int32?
    fileprivate let context: AccountContext?
    fileprivate let arguments: Arguments?
    fileprivate let _stableId: AnyHashable
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, filters: [State.Collection], selected: Int32, arguments: Arguments) {
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
        return 40
    }
    
    override func viewClass() -> AnyClass {
        return CollectionFilterRowView.self
    }
}

private final class CollectionFilterRowView : TableStickView {
    private let tableView = HorizontalTableView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        tableView.getBackgroundColor = {
            .clear
        }
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
        
        
    }
    
    override func layout() {
        super.layout()
        if tableView.listHeight < bounds.width {
            tableView.frame = focus(NSMakeSize(tableView.listHeight, bounds.height))
        } else {
            tableView.frame = bounds
        }
    }
}


private final class Arguments {
    let context: AccountContext
    let open:(ProfileGiftsContext.State.StarGift)->Void
    let togglePin:(ProfileGiftsContext.State.StarGift)->Void
    let toggleWear:(ProfileGiftsContext.State.StarGift)->Void
    let transfer:(ProfileGiftsContext.State.StarGift)->Void
    let toggleVisibility:(ProfileGiftsContext.State.StarGift)->Void
    let copy:(ProfileGiftsContext.State.StarGift)->Void
    let collection:(State.Collection, ProfileGiftsContext.State.StarGift?)->Void
    let addToCollection:(State.Collection, ProfileGiftsContext.State.StarGift?)->Void
    let collectionContextMenu:(State.Collection)->[ContextMenuItem]
    init(context: AccountContext, open:@escaping(ProfileGiftsContext.State.StarGift)->Void, togglePin:@escaping(ProfileGiftsContext.State.StarGift)->Void, toggleWear:@escaping(ProfileGiftsContext.State.StarGift)->Void, transfer:@escaping(ProfileGiftsContext.State.StarGift)->Void, toggleVisibility:@escaping(ProfileGiftsContext.State.StarGift)->Void, copy:@escaping(ProfileGiftsContext.State.StarGift)->Void, collection:@escaping(State.Collection, ProfileGiftsContext.State.StarGift?)->Void, addToCollection: @escaping(State.Collection, ProfileGiftsContext.State.StarGift?)->Void, collectionContextMenu:@escaping(State.Collection)->[ContextMenuItem]) {
        self.context = context
        self.open = open
        self.togglePin = togglePin
        self.toggleWear = toggleWear
        self.transfer = transfer
        self.toggleVisibility = toggleVisibility
        self.copy = copy
        self.collection = collection
        self.addToCollection = addToCollection
        self.collectionContextMenu = collectionContextMenu
    }
}

private struct State : Equatable {
    
    enum Collection : Equatable {
        case all
        case collection(value: StarGiftCollection)
        case add
        
        
        var stableId: Int32 {
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
    
    var gifts: [ProfileGiftsContext.State.StarGift] {
        let collection = collections.first(where: { $0.stableId == selectedCollection }) ?? .all

        switch collection {
        case .all:
            return collectionsState[Collection.all.stableId]?.filteredGifts ?? []
        case let .collection(value):
            return collectionsState[value.id]?.filteredGifts ?? []
        default:
            return []
        }
    }
    
    var state: ProfileGiftsContext.State? {
        return collectionsState[Collection.all.stableId]
    }
    
    mutating func notificationsEnabled(_ value: Bool) {
        collectionsState[Collection.all.stableId]?.notificationsEnabled = value
    }
    
    func contains(collectionId: Int32, gift: ProfileGiftsContext.State.StarGift) -> Bool {
        return collectionsState[collectionId]?.gifts.contains(where: { $0.reference == gift.reference }) == true
    }
    
    var perRowCount: Int = 3
    var peer: EnginePeer?
    var starsState: StarsContext.State?
    var collectionsState:[Int32: ProfileGiftsContext.State] = [:]

    var collections:[Collection] = []
    var selectedCollection: Int32 = Collection.all.stableId
}

private func _id_stars_gifts(_ index: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_stars_gifts_\(index)")
}
private let _id_collections = InputDataIdentifier("_id_collections")
private let _id_empty = InputDataIdentifier("_id_empty")
private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    
    
    if state.collections.isEmpty {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    } else {
        
        entries.append(.sectionId(sectionId, type: .customModern(10)))
        sectionId += 1
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_collections, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return CollectionRowItem(initialSize, stableId: stableId, context: arguments.context, filters: state.collections, selected: state.selectedCollection, arguments: arguments)
        }))
        
        entries.append(.sectionId(sectionId, type: .customModern(10)))
        sectionId += 1
    }
    
    let collectionGiftsLimit = arguments.context.appConfiguration.getGeneralValue("stargifts_collection_gifts_limit", orElse: 500)
  
    let chunks: [[GiftOptionsRowItem.Option]]
    let collection = state.collections.first(where: { $0.stableId == state.selectedCollection }) ?? .all
    var list = state.gifts.map { GiftOptionsRowItem.Option.initialize($0) }
    switch collection {
    case .collection:
        if let peer = state.peer?._asPeer(), peer.id == arguments.context.peerId || peer.groupAccess.isCreator, !list.isEmpty {
            //TODOLANG
            if list.count < collectionGiftsLimit {
                list.append(.initialize(NSImage(resource: .iconCollectionAddGifts).precomposed(theme.colors.grayText), text: .initialize(string: "Add Gifts", color: theme.colors.grayText, font: .normal(.text))))
            }
        }
    default:
        break
    }
    chunks = list.chunks(state.perRowCount)

    
    if !chunks.isEmpty {
        for (i, chunk) in chunks.enumerated() {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_stars_gifts(i), equatable: .init(chunk), comparable: nil, item: { initialSize, stableId in
                return GiftOptionsRowItem(initialSize, stableId: stableId, context: arguments.context, options: chunk, perRowCount: state.perRowCount, fitToSize: false, insets: NSEdgeInsets(), callback: { option in
                    if let value = option.nativeProfileGift {
                        arguments.open(value)
                    } else {
                        arguments.addToCollection(collection, nil)
                    }
                }, contextMenu: { option in
                    if let profile = option.nativeProfileGift, let _ = profile.reference {
                        var items: [ContextMenuItem] = []
                        
                        //TODOLANG
                        let addItem = ContextMenuItem("Add to Collection", handler: {
                        }, itemImage: MenuAnimation.menu_add_to_folder.value)
                        
                        let addMenu = ContextMenu()
                        addMenu.addItem(ContextMenuItem("New Collection", handler: {
                            arguments.collection(.add, profile)
                        }, itemImage: MenuAnimation.menu_folder_add.value))
                        
                        addMenu.addItem(ContextSeparatorItem())
                        
                        for collection in state.collections {
                            switch collection {
                            case let .collection(value):
                                
                                let contains = state.contains(collectionId: value.id, gift: profile)
                                
                                let item = ContextMenuItem(value.title, handler: {
                                    arguments.addToCollection(collection, profile)
                                }, state: contains ? .on : nil)
                                
                                if let file = value.icon {
                                    ContextMenuItem.makeEmoji(item, context: arguments.context, file: file)
                                }
                                addMenu.addItem(item)
                                
                            default:
                                break
                            }
                        }
                        
                        addItem.submenu = addMenu
                        
                        items.append(addItem)
                        items.append(ContextSeparatorItem())
                        
                        if let unique = profile.gift.unique {
                            items.append(ContextMenuItem(!profile.pinnedToTop ? strings().chatListContextPin : strings().chatListContextUnpin, handler: {
                                arguments.togglePin(profile)
                            }, itemImage: !profile.pinnedToTop ? MenuAnimation.menu_pin.value : MenuAnimation.menu_unpin.value))
                            
                            let weared = unique.file?.fileId.id == state.peer?.emojiStatus?.fileId
                            
                            items.append(ContextMenuItem(weared ? strings().giftContextTakeOff : strings().giftContextWear, handler: {
                                arguments.toggleWear(profile)
                            }, itemImage: !weared ? MenuAnimation.menu_wear.value : MenuAnimation.menu_wearoff.value))
                            
                            items.append(ContextMenuItem(strings().modalCopyLink, handler: {
                                arguments.copy(profile)
                            }, itemImage: MenuAnimation.menu_copy.value))
                        }
                                           
                        items.append(ContextMenuItem(profile.savedToProfile ? strings().giftContextHide : strings().giftContextShow, handler: {
                            arguments.toggleVisibility(profile)
                        }, itemImage: profile.savedToProfile ? MenuAnimation.menu_show.value : MenuAnimation.menu_hide.value))
                        
                        
                        if let _ = profile.gift.unique {
                            items.append(ContextMenuItem(strings().giftContextTransfer, handler: {
                                arguments.transfer(profile)
                            }, itemImage: MenuAnimation.menu_transfer.value))
                        }
                        
                        
                        return items
                    }
                    return []
                })
            }))
            
            entries.append(.sectionId(sectionId, type: .customModern(10)))
            sectionId += 1
        }
    } else {
        switch collection {
        case .collection:
            //TODOLANG
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_empty, equatable: .init(state.selectedCollection), comparable: nil, item: { initialSize, stableId in
                return SearchEmptyRowItem(initialSize, stableId: stableId, header: "Organize Your Gifts", text: "Add some gifts to this collection.", action: .init(click: {
                    arguments.addToCollection(collection, nil)
                }, title: "Add to Collection"))
            }))
        default:
            break
        }
    }
   
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

private struct GiftReferenceEntry : Comparable, Identifiable {
    var index: Int
    var reference: StarGiftReference
    
    var stableId: AnyHashable {
        return reference
    }
    static func <(lhs: GiftReferenceEntry, rhs: GiftReferenceEntry) -> Bool {
        return lhs.index < rhs.index
    }
}

func PeerMediaGiftsController(context: AccountContext, peerId: PeerId, starGiftsProfile: ProfileGiftsContext? = nil) -> InputDataController {

    let actionsDisposable = DisposableSet()

    
    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }
    
    var collectionsContexts:[Int32: ProfileGiftsContext] = [:]

    let giftsContext = starGiftsProfile ?? ProfileGiftsContext(account: context.account, peerId: peerId)
    
    let collectionsContext = StarGiftCollectionsContext(account: context.account, peerId: peerId)
        
    let peer = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    
    let collectionsLimit = context.appConfiguration.getGeneralValue("stargifts_collections_limit", orElse: 10)
    
    actionsDisposable.add(combineLatest(queue: .mainQueue(), giftsContext.state, peer, context.starsContext.state, collectionsContext.state).startStrict(next: { [weak actionsDisposable] gifts, peer, starsState, collectionsState in
        updateState { current in
            var current = current
            current.collectionsState[State.Collection.all.stableId] = gifts
            current.peer = peer
            current.starsState = starsState
            
            if !collectionsState.collections.isEmpty {
                current.collections = [.all] + collectionsState.collections.map { .collection(value: $0) }
            }
            let access = peer?.id == context.peerId || peer?._asPeer().groupAccess.isCreator == true
            
            if access, !collectionsState.collections.isEmpty, collectionsLimit > collectionsState.collections.count {
                current.collections += [.add]
            }
            if !current.collections.contains(where: { $0.stableId == current.selectedCollection }) {
                current.selectedCollection = State.Collection.all.stableId
            }
            return current
        }
        
        for collection in collectionsState.collections {
            if collectionsContexts[collection.id] == nil {
                let value = ProfileGiftsContext(account: context.account, peerId: peerId, collectionId: collection.id)
                collectionsContexts[collection.id] = value
                actionsDisposable?.add(value.state.start(next: { state in
                    updateState { current in
                        var current = current
                        current.collectionsState[collection.id] = state
                        return current
                    }
                }))
            }
        }
    }))
    
    let renameCollection:(State.Collection)->Void = { [weak collectionsContext] collection in
        guard let collectionsContext else {
            return
        }
        
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
            
            let data = ModalAlertData(title: "Update Name", info: "Update a name for your collection.", description: nil, ok: "Update", options: [], mode: .confirm(text: strings().modalCancel, isThird: false), footer: footer)
            
            showModalAlert(for: window, data: data, completion: { result in
                actionsDisposable.add(collectionsContext.renameCollection(id: value.id, title: text).start())
            })
        default:
            break
        }
        
    }
    
    let addToCollection:(State.Collection, ProfileGiftsContext.State.StarGift?)->Void = { [weak collectionsContext] collection, gift in
        
        guard let collectionsContext else {
            return
        }
        
        switch collection {
        case let .collection(value):
            if let gift, let reference = gift.reference {
                
                let state = stateValue.with { $0 }
                let contains = state.contains(collectionId: value.id, gift: gift)
                //TODOLANG
                if contains {
                    actionsDisposable.add(collectionsContext.removeGifts(id: value.id, gifts: [reference]).start())
                    showModalText(for: window, text: "Gift removed from **\(value.title)**")
                } else {
                    actionsDisposable.add(collectionsContext.addGifts(id: value.id, gifts: [reference]).start())
                    showModalText(for: window, text: "Gift added to **\(value.title)**")
                    
                }
                
                
//                updateState { current in
//                    var current = current
//                    if let index = current.collections.firstIndex(where: { $0.stableId == id }) {
//                        current.collections[index] = .collection(name: name, id: id, giftIds: Array(giftIds + [giftId]).uniqueElements)
//                    }
//                    return current
//                }
            } else {
                
                let collectionGifts = stateValue.with { $0.collectionsState[value.id]?.gifts ?? [] }.compactMap(\.reference)
                
                
                var previous: [GiftReferenceEntry] = []
                for i in 0 ..< collectionGifts.count {
                    previous.append(.init(index: i, reference: collectionGifts[i]))
                }
                
                showModal(with: SelectGiftsModalController(context: context, peerId: peerId, selected: collectionGifts, callback: { result in
                    
                    var current: [GiftReferenceEntry] = []
                    for i in 0 ..< result.count {
                        current.append(.init(index: i, reference: result[i]))
                    }
                    
                    let (deleteIndices, indicesAndItems) = mergeListsStable(leftList: previous, rightList: current)
                    
                    var actions: [StarGiftCollectionsContext.UpdateAction] = []
                    
                    if !indicesAndItems.isEmpty {
                        actions.append(.addGifts(indicesAndItems.map(\.1.reference)))
                    }
                    if !deleteIndices.isEmpty {
                        let removeValue = deleteIndices.map { previous[$0] }
                        actions.append(.removeGifts(removeValue.map(\.reference)))
                    }
                    
                    actionsDisposable.add(collectionsContext.updateCollection(id: value.id, actions: actions).start())

//                    if temporary, !result.isEmpty, let collectionsContext {
//                       
//                    }
                    
                }), for: context.window)
            }
            
        default:
            break
        }
    }

    let arguments = Arguments(context: context, open: { [weak giftsContext] option in
        
        let toPeer = stateValue.with { $0.peer }
        let fromPeer = option.fromPeer
        
        guard let toPeer else {
            return
        }
        
        let transaction = StarsContext.State.Transaction(flags: [], id: "", count: .init(amount: .init(value: option.gift.generic?.price ?? 0, nanos: 0), currency: .stars), date: option.date, peer: .peer(toPeer), title: "", description: nil, photo: nil, transactionDate: nil, transactionUrl: nil, paidMessageId: nil, giveawayMessageId: nil, media: [], subscriptionPeriod: nil, starGift: option.gift, floodskipNumber: nil, starrefCommissionPermille: nil, starrefPeerId: nil, starrefAmount: nil, paidMessageCount: nil, premiumGiftMonths: nil, adsProceedsFromDate: nil, adsProceedsToDate: nil)
        
        
        let purpose: Star_TransactionPurpose = .starGift(gift: option.gift, convertStars: option.convertStars ?? 0, text: option.text, entities: option.entities, nameHidden: option.fromPeer != nil, savedToProfile: option.savedToProfile, converted: option.convertStars == nil, fromProfile: true, upgraded: false, transferStars: option.convertStars, canExportDate: option.canExportDate, reference: option.reference, sender: nil, saverId: nil, canTransferDate: nil, canResaleDate: nil)
        
        switch option.gift {
        case let .unique(gift):
            showModal(with: StarGift_Nft_Controller(context: context, gift: option.gift, source: .quickLook(toPeer, gift), transaction: transaction, purpose: .starGift(gift: option.gift, convertStars: option.convertStars, text: option.text, entities: option.entities, nameHidden: option.nameHidden, savedToProfile: option.savedToProfile, converted: false, fromProfile: true, upgraded: false, transferStars: option.transferStars, canExportDate: option.canExportDate, reference: option.reference, sender: option.fromPeer, saverId: nil, canTransferDate: option.canTransferDate, canResaleDate: option.canResaleDate), giftsContext: giftsContext, pinnedInfo: option.reference.flatMap { .init(pinnedInfo: option.pinnedToTop, reference: $0) } ), for: context.window)
        default:
            showModal(with: Star_TransactionScreen(context: context, fromPeerId: peerId, peer: fromPeer, transaction: transaction, purpose: purpose, reference: option.reference, profileContext: giftsContext), for: context.window)
        }
        

    }, togglePin: { [weak giftsContext] option in
        if let reference = option.reference {
            giftsContext?.updateStarGiftPinnedToTop(reference: reference, pinnedToTop: !option.pinnedToTop)
        }
    }, toggleWear: { option in
        let peer = stateValue.with({ $0.peer?._asPeer() })
        if let peer {
            context.reactions.setStatus(option.gift.unique!.file!, peer: peer, timestamp: context.timestamp, timeout: nil, fromRect: nil, starGift: option.gift.unique)
        }
    }, transfer: { option in
        let state = stateValue.with { $0 }
        
        var additionalItem: SelectPeers_AdditionTopItem?
        
        
        var canExportDate: Int32? = option.canExportDate
        let transferStars: Int64? = option.transferStars
        let convertStars: Int64? = option.convertStars
        let reference: StarGiftReference? = option.reference
        
        
        if let canExportDate = canExportDate {
            additionalItem = .init(title: strings().giftTransferSendViaBlockchain, color: theme.colors.text, icon: NSImage(resource: .iconSendViaTon).precomposed(flipVertical: true), callback: {
                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                
                if currentTime > canExportDate, let unique = option.gift.unique, let reference {
                    
                    let data = ModalAlertData(title: nil, info: strings().giftWithdrawText(unique.title + " #\(unique.number)"), description: nil, ok: strings().giftWithdrawProceed, options: [], mode: .confirm(text: strings().modalCancel, isThird: false), header: .init(value: { initialSize, stableId, presentation in
                        return TransferUniqueGiftHeaderItem(initialSize, stableId: stableId, gift: unique, toPeer: .init(context.myPeer!), context: context)
                    }))
                    
                    showModalAlert(for: window, data: data, completion: { result in
                        showModal(with: InputPasswordController(context: context, title: strings().giftWithdrawTitle, desc: strings().monetizationWithdrawEnterPasswordText, checker: { value in
                            return context.engine.payments.requestStarGiftWithdrawalUrl(reference: reference, password: value)
                            |> deliverOnMainQueue
                            |> afterNext { url in
                                execute(inapp: .external(link: url, false))
                            }
                            |> ignoreValues
                            |> mapError { error in
                                switch error {
                                case .invalidPassword:
                                    return .wrong
                                case .limitExceeded:
                                    return .custom(strings().loginFloodWait)
                                case .generic:
                                    return .generic
                                default:
                                    return .custom(strings().monetizationWithdrawErrorText)
                                }
                            }
                        }), for: context.window)
                    })
                    
                } else {
                    let delta = canExportDate - currentTime
                    let days: Int32 = Int32(ceil(Float(delta) / 86400.0))
                    alert(for: window, header: strings().giftTransferUnlockPendingTitle, info: strings().giftTransferUnlockPendingText(strings().timerDaysCountable(Int(days))))
                }
            })
        }
        
        _ = selectModalPeers(window: window, context: context, title: strings().giftTransferTitle, behavior: SelectChatsBehavior(settings: [.excludeBots, .contacts, .remote, .channels], limit: 1, additionTopItem: additionalItem)).start(next: { peerIds in
            if let peerId = peerIds.first {
                let peer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)) |> deliverOnMainQueue
                
                _ = peer.startStandalone(next: { peer in
                    if let peer {
                                                
                        let info: String
                        let ok: String
                        
                        guard let reference = reference, let unique = option.gift.unique else {
                            return
                        }
                        
                        if let transferStars = transferStars, let starsState = state.starsState, starsState.balance.value < transferStars {
                            showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: transferStars)), for: window)
                            return
                        }
                        
                        if let stars = transferStars, stars > 0 {
                            info = strings().giftTransferConfirmationText("\(unique.title) #\(unique.number)", peer._asPeer().displayTitle, strings().starListItemCountCountable(Int(stars)))
                            ok = strings().giftTransferConfirmationTransfer + " " + strings().starListItemCountCountable(Int(stars))
                        } else {
                            info = strings().giftTransferConfirmationTextFree("\(unique.title) #\(unique.number)", peer._asPeer().displayTitle)
                            ok = strings().giftTransferConfirmationTransferFree
                        }
                
                        let data = ModalAlertData(title: nil, info: info, description: nil, ok: ok, options: [], mode: .confirm(text: strings().modalCancel, isThird: false), header: .init(value: { initialSize, stableId, presentation in
                            return TransferUniqueGiftHeaderItem(initialSize, stableId: stableId, gift: unique, toPeer: peer, context: context)
                        }))
                        
                        showModalAlert(for: window, data: data, completion: { result in
                            _ = giftsContext.transferStarGift(prepaid: transferStars == nil, reference: reference, peerId: peerId).startStandalone()
                            _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.5).start()
                        })
                    }
                })
            }
        })
    }, toggleVisibility: { [weak giftsContext] option in
        if let reference = option.reference {
            giftsContext?.updateStarGiftAddedToProfile(reference: reference, added: !option.savedToProfile)
        }
    }, copy: { option in
        copyToClipboard(option.gift.unique!.link)
        showModalText(for: window, text: strings().contextAlertCopied)
    }, collection: { collection, gift in
        if collection == .add {
            
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
            
            let data = ModalAlertData(title: "Create a New Collection", info: "Choose a name for your collection and start adding your gifts there.", description: nil, ok: "Create", options: [], mode: .confirm(text: strings().modalCancel, isThird: false), footer: footer)
            
            showModalAlert(for: window, data: data, completion: { result in
                actionsDisposable.add(collectionsContext.createCollection(title: text, starGifts: gift?.reference.flatMap({ [$0] }) ?? []).start(next: { collection in
                    
                    updateState { current in
                        var current = current
                        if let id = collection?.id {
                            current.selectedCollection = id
                        }
                        return current
                    }
                }))
            })
        } else {
            updateState { current in
                var current = current
                current.selectedCollection = collection.stableId
                return current
            }
        }
    }, addToCollection: { collection, gift in
//        let state = stateValue.with { $0 }
//        let collection = state.collections.first(where: { $0.stableId == state.selectedCollection }) ?? .all
        addToCollection(collection, gift)
    }, collectionContextMenu: { [weak collectionsContext] collection in
        switch collection {
        case .add:
           return []
        case .all:
            return []
        case let .collection(value):
            //TODOLANG
            var items: [ContextMenuItem] = []
            
            items.append(ContextMenuItem("Add Gifts", handler: {
                addToCollection(collection, nil)
            }, itemImage: MenuAnimation.menu_add.value))
            
            items.append(ContextMenuItem("Rename", handler: {
                renameCollection(collection)
            }, itemImage: MenuAnimation.menu_edit.value))
            
            items.append(ContextSeparatorItem())
            
            //TODOLANG
            items.append(ContextMenuItem("Delete", handler: {
                verifyAlert(for: window, information: "Are you sure you want to delete **\(value.title)**?", successHandler: { _ in
                    if let collectionsContext {
                        actionsDisposable.add(collectionsContext.deleteCollection(id: collection.stableId).start())
                    }
                })
            }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
            
            return items
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    controller._menuItems = { [weak giftsContext] in
        var items: [ContextMenuItem] = []
        
        let state = stateValue.with { $0 }
        
        if let peer = state.peer?._asPeer(), peer.id == context.peerId || peer.groupAccess.isCreator {
            //TODOLANG
            items.append(ContextMenuItem("Add Collection", handler: {
                arguments.collection(.add, nil)
            }, itemImage: MenuAnimation.menu_add.value))
            
            items.append(ContextSeparatorItem())
        }
        
        
        if let peer = state.peer?._asPeer(), peer.isChannel, let notificationsEnabled = state.state?.notificationsEnabled {
            items.append(ContextMenuItem(strings().peerInfoGiftsChannelNotify, handler: {
                _ = context.engine.payments.toggleStarGiftsNotifications(peerId: peer.id, enabled: !notificationsEnabled).start()
                updateState { current in
                    var current = current
                    current.notificationsEnabled(!notificationsEnabled)
                    return current
                }
                showModalText(for: context.window, text: !notificationsEnabled ? strings().peerInfoGiftsChannelNotifyTooltip : strings().peerInfoGiftsChannelNotifyDisabledTooltip)
            }, state: notificationsEnabled ? .on : nil))
            
            items.append(ContextSeparatorItem())
        }
        if let peer = state.peer?._asPeer(), let giftState = state.state {
            
            let toggleFilter: (ProfileGiftsContext.Filters) -> Void = { [weak giftsContext] value in
                var updatedFilter = giftState.filter
                if updatedFilter.contains(value) {
                    updatedFilter.remove(value)
                } else {
                    updatedFilter.insert(value)
                }
                if !updatedFilter.contains(.unlimited) && !updatedFilter.contains(.limited) && !updatedFilter.contains(.unique) {
                    updatedFilter.insert(.unlimited)
                }
                if !updatedFilter.contains(.displayed) && !updatedFilter.contains(.hidden) {
                    if value == .displayed {
                        updatedFilter.insert(.hidden)
                    } else {
                        updatedFilter.insert(.displayed)
                    }
                }
                giftsContext?.updateFilter(updatedFilter)
            }

            
            items.append(ContextMenuItem(giftState.sorting == .value ? strings().peerInfoGiftsSortByDate : strings().peerInfoGiftsSortByValue, handler: {
                giftsContext?.updateSorting(giftState.sorting == .value ? .date : .value)
            }))
            
            items.append(ContextSeparatorItem())
            
            items.append(ContextMenuItem(strings().peerInfoGiftsUnlimited, handler: {
                toggleFilter(.unlimited)
            }, state: giftState.filter.contains(.unlimited) ? .on : nil))
            
            items.append(ContextMenuItem(strings().peerInfoGiftsLimited, handler: {
                toggleFilter(.limited)
            }, state: giftState.filter.contains(.limited) ? .on : nil))
            
            items.append(ContextMenuItem(strings().peerInfoGiftsUnique, handler: {
                toggleFilter(.unique)
            }, state: giftState.filter.contains(.unique) ? .on : nil))
            
            if peer.groupAccess.canManageGifts || peer.id == context.peerId {
                items.append(ContextSeparatorItem())
                
                items.append(ContextMenuItem(strings().peerInfoGiftsDisplayed, handler: {
                    toggleFilter(.displayed)
                }, state: giftState.filter.contains(.displayed) ? .on : nil))
                
                items.append(ContextMenuItem(strings().peerInfoGiftsHidden, handler: {
                    toggleFilter(.hidden)
                }, state: giftState.filter.contains(.hidden) ? .on : nil))
            }
           
        }
       
        
        return items
    }
    
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
        collectionsContexts = [:]
    }
    
    controller.didResize = { controller in
        var rowCount:Int = 4
        var perWidth: CGFloat = 0
        let blockWidth = max(380, min(600, controller.atomicSize.with { $0.width }))
        while true {
            let maximum = blockWidth - CGFloat(rowCount * 2)
            perWidth = maximum / CGFloat(rowCount)
            if perWidth >= 110 {
                break
            } else {
                rowCount -= 1
            }
        }
        updateState { current in
            var current = current
            current.perRowCount = rowCount
            return current
        }
    }
    
    controller.didLoad = { [weak giftsContext] controller, _ in
        
        controller.tableView.set(stickClass: CollectionRowItem.self, handler: { _ in
            
        })
        
        controller.tableView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                giftsContext?.loadMore()
            default:
                break
            }
        }
    }
    
    controller.contextObject = (giftsContext, collectionsContext, collectionsContexts)

    return controller
    
}




