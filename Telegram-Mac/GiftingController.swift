//
//  GiftingController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04.09.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import InAppPurchaseManager



private final class HeaderTextRowItem : GeneralRowItem {
    enum HeaderTextType : Equatable {
        case premium
        case stars(selfGift: Bool)
        
        var headerText: String {
            switch self {
            case .premium:
                return strings().giftingPremiumTitle
            case let .stars(selfGift):
                return selfGift ? strings().giftOptionsGiftSelfTitle : strings().giftingStarGiftTitle
            }
        }
        func infoText(_ peer: EnginePeer) -> String {
            switch self {
            case .premium:
                return strings().giftingPremiumInfo(peer._asPeer().displayTitle)
            case let .stars(selfGift):
                return selfGift ? strings().giftOptionsGiftSelfText : strings().giftingStarGiftInfo(peer._asPeer().displayTitle)
            }
        }
    }
    fileprivate let context: AccountContext
    fileprivate let headerLayout: TextViewLayout
    fileprivate let infoLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, peer: EnginePeer, type: HeaderTextType, context: AccountContext, openPromo: @escaping(String)->Void) {
        self.context = context
        
        self.headerLayout = .init(.initialize(string: type.headerText, color: theme.colors.text, font: .medium(.header)), maximumNumberOfLines: 1, alignment: .center)
        let info = parseMarkdownIntoAttributedString(type.infoText(peer), attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.accentIcon), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, contents)
        }))
        
        self.infoLayout = .init(info, alignment: .center)
        
        var interactions = globalLinkExecutor
        interactions.processURL = { url in
            if let url = url as? String {
                openPromo(url)
            }
        }
        self.infoLayout.interactions = interactions
        
        super.init(initialSize, stableId: stableId)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.headerLayout.measure(width: width - 40)
        self.infoLayout.measure(width: width - 40)
        
        return true
    }
    
    override var height: CGFloat {
        return headerLayout.layoutSize.height + 2 + infoLayout.layoutSize.height
    }
    
    override func viewClass() -> AnyClass {
        return HeaderTextRowView.self
    }
}

private final class HeaderTextRowView : GeneralRowView {
    private let headerView = TextView()
    private let infoView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(headerView)
        addSubview(infoView)
        
        headerView.isSelectable = false
        infoView.isSelectable = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        headerView.centerX(y: 0)
        infoView.centerX(y: headerView.frame.maxY + 2)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? HeaderTextRowItem else {
            return
        }
        headerView.update(item.headerLayout)
        infoView.update(item.infoLayout)
        needsLayout = true
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
}


private final class HeaderRowItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let peers: [EnginePeer]
    init(_ initialSize: NSSize, stableId: AnyHashable, peers: [EnginePeer], context: AccountContext) {
        self.context = context
        
        self.peers = Array(peers.prefix(3))
        super.init(initialSize, stableId: stableId)
    }
    
    override var height: CGFloat {
        return 70
    }
    
    override func viewClass() -> AnyClass {
        return HeaderRowView.self
    }
}

private final class HeaderRowView : TableRowView {
    private let scene: GoldenStarSceneView = GoldenStarSceneView(frame: NSMakeRect(0, 0, 340, 180))
    private let avatars = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(scene)
        addSubview(avatars)
        avatars.frame = NSMakeRect(0, 20, 100, 100)
        scene.updateLayout(size: scene.frame.size, transition: .immediate)
        
        self.layer?.masksToBounds = false
    }
    
    override func layout() {
        super.layout()
        scene.center()
        avatars.centerX(y: -30)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? HeaderRowItem else {
            return
        }
        
        self.scene.hideStar()
        self.scene.sceneBackground = theme.colors.listBackground
        
        self.avatars.change(opacity: 1, animated: animated)

        while avatars.subviews.count > item.peers.count {
            avatars.subviews.last?.removeFromSuperview()
        }
        while avatars.subviews.count < item.peers.count {
            avatars.addSubview(AvatarControl(font: .avatar(18)))
        }
        
        var x: CGFloat = 0
        for (i, peer) in item.peers.enumerated() {
            let control = avatars.subviews[i] as! AvatarControl
            control.setFrameSize(NSMakeSize(100, 100))
            control.setPeer(account: item.context.account, peer: peer._asPeer())
            control.layer?.zPosition = CGFloat(1000 - i)
            control.setFrameOrigin(x, 0)
            control.layer?.cornerRadius = control.frame.height / 2
            control.layer?.borderWidth = 2
            control.layer?.borderColor = theme.colors.listBackground.cgColor
            x += control.frame.width / 2
        }
        avatars.setFrameSize(NSMakeSize(avatars.frame.height + (CGFloat(item.peers.count - 1) * avatars.frame.height / 2), avatars.frame.height))
        needsLayout = true
        
    }
}

private final class FilterRowItem : GeneralRowItem {
    fileprivate let item: StarGiftFilterRowItem.Item
    fileprivate let layout: TextViewLayout
    fileprivate let context: AccountContext
    fileprivate let arguments: Arguments
    init(_ initialSize: NSSize, stableId: AnyHashable, item: StarGiftFilterRowItem.Item, arguments: Arguments) {
        self.item = item
        self.layout = .init(item.text, maximumNumberOfLines: 1)
        self.layout.measure(width: .greatestFiniteMagnitude)
        self.context = arguments.context
        self.arguments = arguments
        super.init(initialSize)
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
                item.arguments.selectFilter(item.item.value)
            }
        }, for: .Click)
        
        if item.item.selected {
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
            current.backgroundColor = theme.colors.listGrayText.withAlphaComponent(0.2)
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

private final class StarGiftFilterRowItem : GeneralRowItem {
    
    struct Item : Comparable, Identifiable {
        let value: State.StarGiftFilter
        let index: Int
        let selected: Bool
        
        var stableId: AnyHashable {
            return value
        }
        static func < (lhs: Item, rhs: Item) -> Bool {
            return lhs.index < rhs.index
        }
        
        func makeItem(_ size: NSSize, arguments: Arguments) -> TableRowItem {
            switch self.value {
            case .emptyLeft, .emptyRight:
                return GeneralRowItem(size, height: 15, stableId: stableId, backgroundColor: .clear)
            default:
                return FilterRowItem(size, stableId: stableId, item: self, arguments: arguments)
            }
        }
        
        var text: NSAttributedString {
            let attr = NSMutableAttributedString()
            switch self.value {
            case .all:
                attr.append(string: strings().giftingStarGiftAll, color: selected ? theme.colors.darkGrayText : theme.colors.listGrayText, font: .normal(.text))
            case .myGifts:
                attr.append(string: strings().giftingMyGifts, color: selected ? theme.colors.darkGrayText : theme.colors.listGrayText, font: .normal(.text))
            case .limited:
                attr.append(string: strings().giftingStarGiftLimited, color: selected ? theme.colors.darkGrayText : theme.colors.listGrayText, font: .normal(.text))
            case .available:
                attr.append(string: strings().giftingStarGiftInStock, color: selected ? theme.colors.darkGrayText : theme.colors.listGrayText, font: .normal(.text))
            case .stars(let int64):
                attr.append(string: "\(clown_space)\(int64)", color: selected ? theme.colors.darkGrayText : theme.colors.listGrayText, font: .normal(.text))
                attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)
            case .resale:
                attr.append(string: strings().giftingStarGiftResale, color: selected ? theme.colors.darkGrayText : theme.colors.listGrayText, font: .normal(.text))
                attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)
            default:
                break
            }
            return attr
        }
    }
    
    fileprivate let items: [Item]
    fileprivate let selected: State.StarGiftFilter
    fileprivate let context: AccountContext
    fileprivate let arguments: Arguments
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, filters: [State.StarGiftFilter], selected: State.StarGiftFilter, arguments: Arguments) {
        var items: [Item] = []
        for (i, filter) in filters.enumerated() {
            items.append(.init(value: filter, index: i, selected: filter == selected))
        }
        self.items = items
        self.context = context
        self.selected = selected
        self.arguments = arguments
        super.init(initialSize, stableId: stableId)
    }
    
    override var height: CGFloat {
        return 40
    }
    
    override func viewClass() -> AnyClass {
        return StarGiftFilterRowView.self
    }
}

private final class StarGiftFilterRowView : GeneralRowView {
    private let tableView = HorizontalTableView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        tableView.getBackgroundColor = {
            .clear
        }
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var items: [StarGiftFilterRowItem.Item] = []
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StarGiftFilterRowItem else {
            return
        }
        let context = item.context
        let items = item.items
        let arguments = item.arguments
        
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
        tableView.frame = bounds
    }
}


private final class Arguments {
    let context: AccountContext
    let selectFilter:(State.StarGiftFilter)->Void
    let executeLink:(String)->Void
    let openGift:(PeerStarGift)->Void
    let giftPremium:(PremiumPaymentOption)->Void
    let close:()->Void
    let openPromo:(String)->Void
    let transfer:(ProfileGiftsContext.State.StarGift)->Void
    init(context: AccountContext, selectFilter:@escaping(State.StarGiftFilter)->Void, executeLink:@escaping(String)->Void, openGift:@escaping(PeerStarGift)->Void, giftPremium:@escaping(PremiumPaymentOption)->Void, close:@escaping()->Void, openPromo:@escaping(String)->Void, transfer:@escaping(ProfileGiftsContext.State.StarGift)->Void) {
        self.context = context
        self.selectFilter = selectFilter
        self.executeLink = executeLink
        self.openGift = openGift
        self.giftPremium = giftPremium
        self.close = close
        self.openPromo = openPromo
        self.transfer = transfer
    }
}



private struct State : Equatable {
    
    enum StarGiftFilter : Hashable {
        case emptyLeft
        case emptyRight
        case all
        case myGifts
        case limited
        case available
        case resale
        case stars(Int64)
    }
    
    struct DefaultPrice : Equatable {
        let intergal: Int64
        let decimal: NSDecimalNumber
    }
    var products: [PremiumGiftProduct] = []
    var defaultPrice: DefaultPrice = .init(intergal: 1, decimal: 1)
    var premiumConfiguration: PremiumPromoConfiguration = .defaultValue
    var peer: EnginePeer?
    
    var starFilters: [StarGiftFilter] = [.emptyLeft, .all, .myGifts, .limited, .available, .emptyRight]
    var selectedStarFilter: StarGiftFilter = .all
    
    var starGifts: [PeerStarGift] = []
    
    var starsState: StarsContext.State?
    
    var collectibles: [ProfileGiftsContext.State.StarGift] = []
    
    var disallowedGifts: TelegramDisallowedGifts
    
}


private let _id_header = InputDataIdentifier("_id_header")
private let _id_premium_header = InputDataIdentifier("_id_premium_header")
private let _id_star_header = InputDataIdentifier("_id_star_header")
private let _id_premium_gifts = InputDataIdentifier("_id_premium_gifts")
private let _id_star_filters = InputDataIdentifier("_id_star_filters")
private func _id_stars_gifts(_ index: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_stars_gifts_\(index)")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    if let peer = state.peer {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return HeaderRowItem(initialSize, stableId: stableId, peers: [peer], context: arguments.context)
        }))
        
        if arguments.context.peerId != peer.id, peer._asPeer().isUser, !state.disallowedGifts.contains(.premium) {
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            var paymentOptions: [PremiumPaymentOption] = []
            
            var i: Int32 = 0
            var existingMonths = Set<Int32>()
            
            var products:[PremiumGiftProduct] = []
            
            for product in state.products {
                if existingMonths.contains(product.months) {
                    continue
                }
                existingMonths.insert(product.months)
                products.append(product)
            }
            
            for product in products.reversed() {
                
                let giftTitle: String
                if product.months == 12 {
                    giftTitle = strings().giveawayPaymentOptionsYear
                } else {
                    giftTitle = strings().giveawayPaymentOptionsMonths(Int(product.months))
                }
                
                let discountValue = Int((1.0 - Float(product.priceCurrencyAndAmount.amount) / Float(product.months) / Float(state.defaultPrice.intergal)) * 100.0)
                let discount: String?
                if discountValue > 0 {
                    discount = "-\(discountValue)%"
                } else {
                    discount = nil
                }
                let subtitle = "\(product.price)"
                let label = product.multipliedPrice(count: 1)
                
                let option = PremiumPaymentOption(title: giftTitle, desc: subtitle, total: label, discount: discount, months: product.months, product: product, starProduct: state.products.first(where: { $0.giftOption.currency == XTR && $0.months == product.months}))
                paymentOptions.append(option)
            }
            
            if !paymentOptions.isEmpty {
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_premium_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                    return HeaderTextRowItem(initialSize, stableId: stableId, peer: peer, type: .premium, context: arguments.context, openPromo: arguments.openPromo)
                }))
                
                entries.append(.sectionId(sectionId, type: .normal))
                sectionId += 1
                
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_premium_gifts, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                    return GiftOptionsRowItem(initialSize, stableId: stableId, context: arguments.context, options: paymentOptions.map { .initialize($0) }, insets: .init(left: 10, right: 10), callback: { option in
                        if let option = option.nativePayment {
                            arguments.giftPremium(option)
                        }
                    })
                }))
            }
        }
        
      
        
      

        let filtered:([PeerStarGift], State.StarGiftFilter) -> ([PeerStarGift]) = { list, filter in
            switch filter {
            case .all:
                return list
            case .myGifts:
                return []
            case .limited:
                return list.filter(\.limited)
            case let .stars(stars):
                return list.filter { $0.stars == stars }
            case .available:
                return list.filter({ !$0.limited || $0.native.generic?.soldOut == nil })
            case .resale:
                return list.filter({ $0.native.generic?.availability?.minResaleStars != nil })
            default:
                return list
            }
        }
        let chunks = filtered(state.starGifts, state.selectedStarFilter).chunks(3)
        
        if !chunks.isEmpty {
            
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_star_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                return HeaderTextRowItem(initialSize, stableId: stableId, peer: peer, type: .stars(selfGift: arguments.context.peerId == peer.id), context: arguments.context, openPromo: arguments.openPromo)
            }))
            
            entries.append(.sectionId(sectionId, type: .customModern(10)))
            sectionId += 1
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_star_filters, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                return StarGiftFilterRowItem(initialSize, stableId: stableId, context: arguments.context, filters: state.starFilters, selected: state.selectedStarFilter, arguments: arguments)
            }))
            
           
            entries.append(.sectionId(sectionId, type: .customModern(10)))
            sectionId += 1
            
            for (i, chunk) in chunks.enumerated() {
                if !chunk.isEmpty {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_stars_gifts(i), equatable: .init(chunk), comparable: nil, item: { initialSize, stableId in
                        return GiftOptionsRowItem(initialSize, stableId: stableId, context: arguments.context, options: chunk.map { .initialize($0) }, insets: .init(left: 10, right: 10), callback: { option in
                            if let option = option.nativeStarGift {
                                arguments.openGift(option)
                            }
                        })
                    }))
                    
                    entries.append(.sectionId(sectionId, type: .customModern(10)))
                    sectionId += 1
                }
            }
        } else if !state.collectibles.isEmpty, state.selectedStarFilter == .myGifts {
            entries.append(.sectionId(sectionId, type: .customModern(10)))
            sectionId += 1
            
            let chunks = state.collectibles.chunks(3)
            
            for (i, chunk) in chunks.enumerated() {
                if !chunk.isEmpty {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_stars_gifts(i), equatable: .init(chunk), comparable: nil, item: { initialSize, stableId in
                        return GiftOptionsRowItem(initialSize, stableId: stableId, context: arguments.context, options: chunk.map { .initialize($0, transfrarable: true) }, insets: .init(left: 10, right: 10), callback: { option in
                            if let gift = option.nativeProfileGift {
                                arguments.transfer(gift)
                            }
                        })
                    }))
                    
                    entries.append(.sectionId(sectionId, type: .customModern(10)))
                    sectionId += 1
                }
            }
        }
        
        
    }
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
//

//  
//    // entries
//    

    
    return entries
}

func GiftingController(context: AccountContext, peerId: PeerId, isBirthday: Bool, starGiftsContext: ProfileGiftsContext? = nil) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    let paymentDisposable = MetaDisposable()
    actionsDisposable.add(paymentDisposable)
    
    let initialState = State(products: context.premiumProductsAndPrice.0, defaultPrice: .init(intergal: context.premiumProductsAndPrice.1.0, decimal: context.premiumProductsAndPrice.1.1), disallowedGifts: [])
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getController:(()->InputDataController?)? = nil
    var close:(()->Void)? = nil
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }
    
    let inAppPurchaseManager = context.inAppPurchaseManager

    
    
    let premiumPromo = context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.PremiumPromo())
    |> deliverOnMainQueue
    

    let peer = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    
    let birtday = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Birthday(id: peerId))
    
    let giftsContext = ProfileGiftsContext(account: context.account, peerId: context.peerId)
    
    giftsContext.updateFilter(.unique)
    
    let disallowedGifts: Signal<TelegramDisallowedGifts?, NoError> = context.account.viewTracker.peerView(peerId, updateData: true) |> map { view in
        if peerId == context.peerId {
            return nil
        } else {
            return (view.cachedData as? CachedUserData)?.disallowedGifts
        }
    }
    
    
    let checkAvailability:()->Void = {
        let state = stateValue.with { $0 }
        if state.disallowedGifts == .All, let peer = state.peer {
            close?()
            showModalText(for: window, text: strings().giftNotAccepting(peer._asPeer().displayTitle))
        }
    }
    
    actionsDisposable.add(combineLatest(peer, premiumPromo, context.engine.payments.cachedStarGifts(), birtday, context.starsContext.state, giftsContext.state, disallowedGifts).start(next: { peer, premiumPromo, gifts, birthday, starsState, myGifts, disallowedGifts in
        updateState { current in
            var current = current
            current.peer = peer
            current.premiumConfiguration = premiumPromo
            current.starsState = starsState
            current.disallowedGifts = disallowedGifts ?? []
            current.collectibles = myGifts.filteredGifts

            
            if let gifts {
                current.starGifts = gifts.compactMap { $0.generic }.map {
                    .init(media: $0.file, stars: $0.price, limited: $0.availability != nil && $0.availability?.minResaleStars == nil, native: .generic($0))
                }
                if birthday?.isEligble == true || isBirthday {
                    current.starGifts = current.starGifts.sorted { gift1, gift2 in
                        switch (gift1.native.generic!.flags.contains(.isBirthdayGift), gift2.native.generic!.flags.contains(.isBirthdayGift)) {
                        case (true, false): return true
                        case (false, true): return false
                        default: return false
                        }
                    }
                }
                
                if let disallowedGifts {
                    current.starGifts = current.starGifts.filter({ gift in
                        if gift.limited && disallowedGifts.contains(.limited) {
                            return false
                        }
                        if !gift.limited && disallowedGifts.contains(.unlimited) {
                            return false
                        }
                        if gift.native.unique != nil && disallowedGifts.contains(.unique) {
                            return false
                        }
                        return true
                    })
                }
                
                var customFilters: [State.StarGiftFilter] = current.starGifts.compactMap { $0.native.generic }.sorted(by: { $0.price < $1.price }).map { $0.price }.uniqueElements.map { .stars($0) }
                
                let hasResale = current.starGifts.contains(where: {
                    $0.native.generic?.availability?.minResaleStars != nil && $0.native.generic?.soldOut != nil
                })
                
                if hasResale {
                    customFilters.insert(.resale, at: 0)
                }
                
                
                current.starFilters = [.emptyLeft, .all] + (current.collectibles.isEmpty ? [] : [.myGifts]) + [.limited, .available] + customFilters + [.emptyRight]
                
                if let disallowedGifts {
                    if disallowedGifts.contains(.limited) {
                        current.starFilters.removeAll(where: { $0 == .limited})
                    }
                    if disallowedGifts.contains(.unique) {
                        current.starFilters.removeAll(where: { $0 == .myGifts })
                    }
                    
                   
                }
            }
            return current
        }
        
        checkAvailability()
    }))
    
    
    actionsDisposable.add(context.engine.payments.keepStarGiftsUpdated().startStrict())
    

    let arguments = Arguments(context: context, selectFilter: { filter in
        updateState { current in
            var current = current
            current.selectedStarFilter = filter
            return current
        }
        
        getController?()?.tableView.scroll(to: .top(id: InputDataEntryId.custom(_id_star_filters), innerId: nil, animated: true, focus: .init(focus: false), inset: -50))
        
    }, executeLink: { link in
        
    }, openGift: { option in
        
        if let gift = option.native.generic, gift.flags.contains(.requiresPremium) {
            if !context.isPremium {
                prem(with: PremiumBoardingController(context: context, source: .limitedGift(gift)), for: context.window)
                return
            } else if let limit = gift.perUserLimit {
                if limit.remains == 0 {
                    showModalText(
                        for: window,
                        text: strings().giftSendErrorLimitReached(Int(limit.total))
                    )
                }
            }
        }
        
        let state = stateValue.with { $0 }
        if let peer = state.peer {
            if let gift = option.native.generic, gift.availability?.minResaleStars != nil && gift.soldOut != nil {
                showModal(with: StarGift_MarketplaceController(context: context, peerId: peer.id, gift: gift), for: window)
            } else if option.native.generic?.availability?.remains == 0 {
                showModal(with: Star_TransactionScreen(context: context, fromPeerId: context.peerId, peer: nil, transaction: .init(flags: [.isGift], id: "", count: .init(amount: .init(value: 0, nanos: 0), currency: .stars), date: 0, peer: .unsupported, title: "", description: "", photo: nil, transactionDate: nil, transactionUrl: nil, paidMessageId: nil, giveawayMessageId: nil, media: [], subscriptionPeriod: nil, starGift: option.native, floodskipNumber: nil, starrefCommissionPermille: nil, starrefPeerId: nil, starrefAmount: nil, paidMessageCount: nil, premiumGiftMonths: nil, adsProceedsFromDate: nil, adsProceedsToDate: nil), purpose: .unavailableGift), for: context.window)
            } else {
                showModal(with: PreviewStarGiftController(context: context, option: .starGift(option: option), peer: peer, disallowedGifts: state.disallowedGifts, starGiftsProfile: starGiftsContext), for: window)
            }
        }
    }, giftPremium: { option in
        let state = stateValue.with { $0 }
        if let peer = state.peer {
            if let product = state.products.first(where: { $0.months == option.months }) {
                let starGift = state.products.first(where: { $0.months == option.months && $0.giftOption.currency == XTR })
                showModal(with: PreviewStarGiftController(context: context, option: .premium(option: product, starOption: starGift), peer: peer, disallowedGifts: state.disallowedGifts, starGiftsProfile: starGiftsContext), for: window)
            }
        }

    }, close: {
        close?()
    }, openPromo: { value in
        if value == "stars" {
            showModal(with: StarUsePromoController(context: context), for: window)
        } else {
            prem(with: PremiumBoardingController(context: context), for: window)
        }
    }, transfer: { gift in
        
        let unique = gift.gift.unique
        let state = stateValue.with { $0 }
        let peer = state.peer
        
        
        let convertStars: Int64? = gift.transferStars
        let reference: StarGiftReference? = gift.reference ?? .peer(peerId: context.peerId, id: unique!.id)
        
        let info: String
        let ok: String
        
        guard let reference = reference, let unique = unique, let peer = peer else {
            return
        }
        
        if let convertStars = convertStars, let starsState = state.starsState, starsState.balance.value < convertStars {
            showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: convertStars)), for: window)
            return
        }
        
        if let stars = convertStars, stars > 0 {
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
            _ = giftsContext.transferStarGift(prepaid: convertStars == nil, reference: reference, peerId: peerId).startStandalone()
            _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.5).start()
            close?()
        })
        
    })
    
    let signal = statePromise.get() |> filter { $0.peer != nil } |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    let controller = InputDataController(dataSignal: signal, title: context.peerId == peerId ? strings().giftOptionsGiftSelfTitle : strings().giftingTitle)
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.didLoad = { controller, _ in
        controller.genericView.layer?.masksToBounds = false
        controller.tableView.layer?.masksToBounds = false
        controller.tableView.documentView?.layer?.masksToBounds = false
        controller.tableView.clipView.layer?.masksToBounds = false
    }

    let modalController = InputDataModalController(controller, size: NSMakeSize(380, 0))
    modalController.fullSizeList = true
    
    
    modalController.getModalTheme = {
        return .init(text: theme.colors.text, grayText: theme.colors.grayText, background: .clear, border: .clear, accent: theme.colors.accent, grayForeground: .clear, activeBackground: theme.colors.background, activeBorder: theme.colors.border, hideUnactiveText: true)
    }
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.contextObject = giftsContext
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}


/*

 */



