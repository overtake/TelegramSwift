//
//  PremiumGiftingController.swift
//  Telegram
//
//  Created by Mike Renoir on 12.12.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import InAppPurchaseManager


private final class HeaderStarRowItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let peers: [EnginePeer]
    init(_ initialSize: NSSize, stableId: AnyHashable, peers: [EnginePeer], context: AccountContext) {
        self.context = context
        self.peers = peers
        super.init(initialSize, height: 100, stableId: stableId)
    }
    override func viewClass() -> AnyClass {
        return HeaderStarRowItemView.self
    }
}

private final class HeaderStarRowItemView : TableRowView {
    
    private let scene: PremiumStarSceneView = PremiumStarSceneView(frame: NSMakeRect(0, 0, 340, 180))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(scene)
        scene.updateLayout(size: scene.frame.size, transition: .immediate)
        
        scene.hideStar()
        self.layer?.masksToBounds = false
    }
    
    override func layout() {
        super.layout()
        scene.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
}

private final class DurationOptionItem : GeneralRowItem {
    
    fileprivate let title: TextViewLayout
    fileprivate let desc: TextViewLayout
    fileprivate let total: TextViewLayout
    fileprivate let discount: TextViewLayout?
    fileprivate let selected: Bool
    fileprivate let option: State.PaymentOption
    fileprivate let toggleOption: (State.PaymentOption)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, option: State.PaymentOption, selected: Bool, viewType: GeneralViewType, toggleOption: @escaping(State.PaymentOption)->Void) {
        self.selected = selected
        self.option = option
        self.toggleOption = toggleOption
        self.title = .init(.initialize(string: option.title, color: theme.colors.text, font: .medium(.text)))
        self.desc = .init(.initialize(string: option.desc, color: theme.colors.grayText, font: .normal(.short)))
        self.total = .init(.initialize(string: option.total, color: theme.colors.grayText, font: .normal(.text)))
        if let discount = option.discount {
            self.discount = .init(.initialize(string: discount, color: theme.colors.underSelectedColor, font: .normal(.small)))
        } else {
            self.discount = nil
        }
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.total.measure(width: .greatestFiniteMagnitude)
        
        self.title.measure(width: self.blockWidth - viewType.innerInset.left - viewType.innerInset.right - total.layoutSize.width - viewType.innerInset.right - viewType.innerInset.right)
        
        self.desc.measure(width: self.blockWidth - viewType.innerInset.left - viewType.innerInset.right - total.layoutSize.width - viewType.innerInset.right - viewType.innerInset.right)

        self.discount?.measure(width: .greatestFiniteMagnitude)
        
        return true
    }
    
    override var height: CGFloat {
        return 42
    }
    
    override func viewClass() -> AnyClass {
        return GiveawayDurationOptionItemView.self
    }
}

private final class GiveawayDurationOptionItemView : GeneralContainableRowView {
    
    
    private final class DiscountView : View {
        private let textView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(textView)
            textView.userInteractionEnabled = false
            textView.isSelectable = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(_ text: TextViewLayout) {
            textView.update(text)
            self.setFrameSize(NSMakeSize(text.layoutSize.width + 4, text.layoutSize.height + 2))
        }
        
        override func layout() {
            super.layout()
            textView.center()
        }
    }
    
    private let titleView = TextView()
    private let descView = TextView()
    private let totalView = TextView()
    private var discountView: DiscountView?
    private var selectingControl = SelectingControl(unselectedImage: theme.icons.chatToggleUnselected, selectedImage: theme.icons.chatToggleSelected)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(selectingControl)
        addSubview(titleView)
        addSubview(descView)
        addSubview(totalView)
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        descView.userInteractionEnabled = false
        descView.isSelectable = false
        
        totalView.userInteractionEnabled = false
        totalView.isSelectable = false
        
        containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? DurationOptionItem {
                item.toggleOption(item.option)
            }
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? DurationOptionItem else {
            return
        }
        self.titleView.update(item.title)
        self.descView.update(item.desc)
        self.totalView.update(item.total)
        
        if let discount = item.discount {
            let current: DiscountView
            if let view = self.discountView {
                current = view
            } else {
                current = DiscountView(frame: .zero)
                self.discountView = current
                self.addSubview(current)
            }
            current.backgroundColor = theme.colors.accent
            current.layer?.cornerRadius = 3
            current.update(discount)
        } else if let view = self.discountView {
            performSubviewRemoval(view, animated: animated)
            self.discountView = nil
        }
        
        selectingControl.set(selected: item.selected, animated: animated)
        
        needsLayout = true

    }
    
    override func layout() {
        super.layout()
        guard let item = item as? GeneralRowItem else {
            return
        }
        selectingControl.centerY(x: item.viewType.innerInset.left)
        totalView.centerY(x: containerView.frame.width - totalView.frame.width - item.viewType.innerInset.right)
        titleView.setFrameOrigin(NSMakePoint(selectingControl.frame.maxX + item.viewType.innerInset.left, 4))
        
        if let discount = discountView {
            discount.setFrameOrigin(NSMakePoint(selectingControl.frame.maxX + item.viewType.innerInset.left, containerView.frame.height - discount.frame.height - 4))
            descView.setFrameOrigin(NSMakePoint(discount.frame.maxX + 4, containerView.frame.height - descView.frame.height - 4))
        } else {
            descView.setFrameOrigin(NSMakePoint(selectingControl.frame.maxX + item.viewType.innerInset.left, containerView.frame.height - descView.frame.height - 4))
        }
    }
}




private final class Arguments {
    let context: AccountContext
    let execute:(String)->Void
    let toggleOption:(State.PaymentOption)->Void

    init(context: AccountContext, execute:@escaping(String)->Void, toggleOption:@escaping(State.PaymentOption)->Void) {
        self.context = context
        self.execute = execute
        self.toggleOption = toggleOption
    }
}

private struct State : Equatable {
    var peers: [EnginePeer] = []
    struct PaymentOption : Equatable {
        var title: String
        var desc: String
        var total: String
        var discount: String?
        var months: Int32
    }
    struct DefaultPrice : Equatable {
        let intergal: Int64
        let decimal: NSDecimalNumber
    }
    var products: [PremiumGiftProduct] = []
    var defaultPrice: DefaultPrice = .init(intergal: 1, decimal: 1)
    var selectedMonths: Int32 = 12
    var newPerks: [String] = []

    var values:[PremiumValue] = [.double_limits, .stories, .more_upload, .faster_download, .voice_to_text, .no_ads, .infinite_reactions, .emoji_status, .premium_stickers, .animated_emoji, .advanced_chat_management, .profile_badge, .animated_userpics, .translations]

}


private let _id_header: InputDataIdentifier = .init("_id_header")
private func _id_peer(_ id: PeerId) -> InputDataIdentifier {
    return .init("_id_peer_\(id.toInt64())")
}
private func _id_option(_ id: String) -> InputDataIdentifier {
    return .init("_id_duration_\(id)")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: nil, comparable: nil, item: { initialSize, stableId in
        return HeaderStarRowItem(initialSize, stableId: stableId, peers: state.peers, context: arguments.context)
    }))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Gift Telegram Premium"), data: .init(color: theme.colors.text, detectBold: true, viewType: .modern(position: .inner, insets: .init()), fontSize: 18, centerViewAlignment: true, alignment: .center)))
    index += 1
    
    let names: String
    if state.peers.count > 3 {
        let displayNames = state.peers.prefix(3).map { $0._asPeer().compactDisplayTitle }.joined(separator: ", ")
        names = "Get **\(displayNames)** and \(state.peers.count - 3) more access to exclusive features with **Telegram Premium**."
    } else {
        let displayNames = state.peers.map { $0._asPeer().compactDisplayTitle }.joined(separator: ", ")
        names = "Get **\(displayNames)** access to exclusive features with **Telegram Premium**."
    }
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(names), data: .init(color: theme.colors.text, detectBold: true, viewType: .modern(position: .inner, insets: .init()), fontSize: 13, centerViewAlignment: true, alignment: .center)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    struct PaymentTuple : Equatable {
        var option: State.PaymentOption
        var selected: Bool
        var viewType: GeneralViewType
    }
    var paymentOptions: [PaymentTuple] = []
    
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
    
    let recipientCount = state.peers.count
    
    for (i, product) in products.enumerated() {
        
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
        let subtitle = "\(product.price) x \(recipientCount)"
        let label = product.multipliedPrice(count: recipientCount)
        
        let selectedMonths = state.selectedMonths
        let isSelected = product.months == selectedMonths
        let option = State.PaymentOption(title: giftTitle, desc: subtitle, total: label, discount: discount, months: product.months)
        
        paymentOptions.append(.init(option: option, selected: isSelected, viewType: bestGeneralViewType(products, for: i)))

    }
    
    for option in paymentOptions {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_option(option.option.title), equatable: .init(option), comparable: nil, item: { initialSize, stableId in
            return DurationOptionItem(initialSize, stableId: stableId, option: option.option, selected: option.selected, viewType: option.viewType, toggleOption: arguments.toggleOption)
        }))
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("WHAT'S INCLUDED"), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    for (i, value) in state.values.enumerated() {
        let viewType = bestGeneralViewType(state.values, for: i)
        
        struct Tuple : Equatable {
            let value: PremiumValue
            let isNew: Bool
        }
        let tuple = Tuple(value: value, isNew: state.newPerks.contains(value.rawValue))
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init(value.rawValue), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
            return PremiumBoardingRowItem(initialSize, stableId: stableId, viewType: viewType, presentation: theme, index: i, value: value, limits: arguments.context.premiumLimits, isLast: false, isNew: tuple.isNew, callback: { value in
                //arguments.openFeature(value, true)
            })
        }))
        index += 1
    }
          
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func PremiumGiftingController(context: AccountContext, peerIds: [PeerId]) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(values: context.premiumOrder.premiumValues)
    
    var close:(()->Void)? = nil
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let peers: Signal<[EnginePeer], NoError> = context.account.postbox.transaction { transaction in
        var peers:[EnginePeer] = []
        for peerId in peerIds {
            if let peer = transaction.getPeer(peerId) {
                peers.append(.init(peer))
            }
        }
        return peers
    }
    
    actionsDisposable.add(peers.start(next: { peers in
        updateState { current in
            var current = current
            current.peers = peers
            return current
        }
    }))
    let inAppPurchaseManager = context.inAppPurchaseManager

    
    let products: Signal<[InAppPurchaseManager.Product], NoError>
    #if APP_STORE || DEBUG
    products = inAppPurchaseManager.availableProducts |> map {
        $0
    }
    #else
    products = .single([])
    #endif
    
    let productsAndDefaultPrice: Signal<([PremiumGiftProduct], (Int64, NSDecimalNumber)), NoError> = combineLatest(
        context.engine.payments.premiumGiftCodeOptions(peerId: context.peerId),
        products
    )
    |> map { options, products in
        var gifts: [PremiumGiftProduct] = []
        for option in options {
            let product = products.first(where: { $0.id == option.storeProductId })
            gifts.append(PremiumGiftProduct(giftOption: option, storeProduct: product))
        }
        let defaultPrice: (Int64, NSDecimalNumber)
        if let defaultProduct = products.first(where: { $0.id == "org.telegram.telegramPremium.monthly" }) {
            defaultPrice = (defaultProduct.priceCurrencyAndAmount.amount, defaultProduct.priceValue)
        } else if let defaultProduct = options.first(where: { $0.storeProductId == "org.telegram.telegramPremium.threeMonths.code_x1" }) {
            defaultPrice = (defaultProduct.amount / Int64(defaultProduct.months), NSDecimalNumber(value: 1))
        } else {
            defaultPrice = (1, NSDecimalNumber(value: 1))
        }
        return (gifts, defaultPrice)
    }
    
    
    actionsDisposable.add(productsAndDefaultPrice.start(next: { products in
            updateState { current in
                var current = current
                current.products = products.0
                current.defaultPrice = .init(intergal: products.1.0, decimal: products.1.1)
                return current
            }
    }))

    let arguments = Arguments(context: context, execute: { link in
        
    }, toggleOption: { value in
        updateState { current in
            var current = current
            current.selectedMonths = value.months
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    controller.didLoaded = { controller, _ in
        controller.genericView.layer?.masksToBounds = false
        controller.tableView.layer?.masksToBounds = false
        controller.tableView.documentView?.layer?.masksToBounds = false
        controller.tableView.clipView.layer?.masksToBounds = false
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: "OK", accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, size: NSMakeSize(380, 350))
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}




