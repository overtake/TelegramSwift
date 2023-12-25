//
//  GiveawayModalController.swift
//  Telegram
//
//  Created by Mike Renoir on 25.09.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import InAppPurchaseManager
import CurrencyFormat

func generateGiveawayTypeImage(_ image: NSImage, colorIndex: Int) -> CGImage {
    
   let random_colors = theme.colors.peerColors(colorIndex)
   return generateImage(NSMakeSize(35, 35), contextGenerator: { (size, ctx) in
       ctx.clear(NSMakeRect(0, 0, size.width, size.height))
       
       ctx.round(size, size.height / 2)
       
       var locations: [CGFloat] = [1.0, 0.2];
       let colorSpace = deviceColorSpace
       let gradient = CGGradient(colorsSpace: colorSpace, colors: NSArray(array: [random_colors.top.cgColor, random_colors.bottom.cgColor]), locations: &locations)!
       
       ctx.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
       
       ctx.setBlendMode(.normal)
       
       let icon = image.precomposed(.white, flipVertical: true)
       let iconSize = icon.backingSize
       let rect = NSMakeRect((size.width - iconSize.width)/2, (size.height - iconSize.height)/2, iconSize.width, iconSize.height)
       ctx.draw(icon, in: rect)
       
   })!
}



private final class GiveawayDurationOptionItem : GeneralRowItem {
    
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
            if let item = self?.item as? GiveawayDurationOptionItem {
                item.toggleOption(item.option)
            }
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GiveawayDurationOptionItem else {
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

private final class GiveawayStarRowItem : GeneralRowItem {
    
    init(_ initialSize: NSSize, stableId: AnyHashable) {
        super.init(initialSize, height: 100, stableId: stableId)
    }
    override func viewClass() -> AnyClass {
        return GiveawayStarRowItemView.self
    }
}

private final class GiveawayStarRowItemView : TableRowView {
    private let scene: PremiumStarSceneView = PremiumStarSceneView(frame: NSMakeRect(0, 0, 340, 180))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(scene)
        scene.updateLayout(size: scene.frame.size, transition: .immediate)
        
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


private final class Arguments {
    let context: AccountContext
    let updateQuantity:(Int32)->Void
    let updateReceiver:(State.GiveawayReceiver)->Void
    let updateType:(State.GiveawayType)->Void
    let selectDate:()->Void
    let execute:(String)->Void
    let toggleOption:(State.PaymentOption)->Void
    let addChannel:()->Void
    let deleteChannel:(PeerId)->Void
    let toggleShowWinners:(Bool)->Void
    let toggleAdditionalPrizes:(Bool)->Void
    init(context: AccountContext, updateQuantity:@escaping(Int32)->Void, updateReceiver:@escaping(State.GiveawayReceiver)->Void, updateType:@escaping(State.GiveawayType)->Void, selectDate:@escaping()->Void, execute:@escaping(String)->Void, toggleOption:@escaping(State.PaymentOption)->Void, addChannel:@escaping()->Void, deleteChannel:@escaping(PeerId)->Void, toggleShowWinners:@escaping(Bool)->Void, toggleAdditionalPrizes:@escaping(Bool)->Void) {
        self.context = context
        self.updateQuantity = updateQuantity
        self.updateReceiver = updateReceiver
        self.updateType = updateType
        self.selectDate = selectDate
        self.execute = execute
        self.toggleOption = toggleOption
        self.addChannel = addChannel
        self.deleteChannel = deleteChannel
        self.toggleShowWinners = toggleShowWinners
        self.toggleAdditionalPrizes = toggleAdditionalPrizes
    }
}


struct PremiumGiftProduct: Equatable {
    let giftOption: PremiumGiftCodeOption
    let storeProduct: InAppPurchaseManager.Product?
    
    var id: String {
        return self.storeProduct?.id ?? ""
    }
    
    var months: Int32 {
        return self.giftOption.months
    }
    
    var price: String {
        if let storeProduct = storeProduct {
            return formatCurrencyAmount(storeProduct.priceCurrencyAndAmount.amount, currency: storeProduct.priceCurrencyAndAmount.currency)
        }
        return formatCurrencyAmount(giftOption.amount, currency: giftOption.currency)
    }
    
    var pricePerMonth: String {
        if let storeProduct = storeProduct {
            return storeProduct.pricePerMonth(Int(self.months))
        } else {
            return formatCurrencyAmount(giftOption.amount / Int64(giftOption.months), currency: giftOption.currency)
        }
    }
    var priceCurrencyAndAmount:(currency: String, amount: Int64) {
        if let storeProduct = storeProduct {
            return storeProduct.priceCurrencyAndAmount
        } else {
            return (currency: giftOption.currency, amount: giftOption.amount)
        }
    }
    
    func multipliedPrice(count: Int) -> String {
        if let storeProduct = storeProduct {
            return storeProduct.multipliedPrice(count: count)
        } else {
            return formatCurrencyAmount(giftOption.amount * Int64(count), currency: giftOption.currency)
        }
    }
}


private struct State : Equatable {
    enum GiveawayType : Equatable {
        case random
        case specific
        case prepaid(PrepaidGiveaway)
    }
    enum GiveawayReceiver : Equatable {
        case all
        case new
    }
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
    var receiver: GiveawayReceiver = .all
    var type: GiveawayType = .random
    var quantity: Int32 = 10
    
    var showWinners: Bool = false
    var additionalPrizes: Bool = false
    var prizeDescription: String?
    
    var selectedMonths: Int32 = 12
    
    var date: Date = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + (60 * 60 * 24 * 3))
    var channels: [PeerEquatable]
    var selectedPeers:[PeerEquatable] = []
    
    var products: [PremiumGiftProduct] = []
    
    var defaultPrice: DefaultPrice = .init(intergal: 1, decimal: 1)
    
    var canMakePayment: Bool = true
    
    var countries: [Country] = []
    
    var prizeDescriptionValue: String? {
        if let prizeDescription = prizeDescription, additionalPrizes {
            return prizeDescription
        } else {
            return nil
        }
    }
}

private let _id_star = InputDataIdentifier("_id_star")
private let _id_giveaway = InputDataIdentifier("_id_giveaway")
private let _id_giveaway_specific = InputDataIdentifier("_id_giveaway_specific")
private let _id_size = InputDataIdentifier("_id_size")
private let _id_size_header = InputDataIdentifier("_id_size_header")
private let _id_add_channel = InputDataIdentifier("_id_add_channel")
private let _id_receiver_all = InputDataIdentifier("_id_receiver_all")
private let _id_receiver_new = InputDataIdentifier("_id_receiver_new")
private let _id_show_winners = InputDataIdentifier("_id_show_winners")
private let _id_prize_description = InputDataIdentifier("_id_prize_description")
private let _id_additional_prizes = InputDataIdentifier("_id_additional_prizes")

private let _id_select_date = InputDataIdentifier("_id_select_date")
private let _id_prepaid = InputDataIdentifier("_id_prepaid")

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
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_star, equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GiveawayStarRowItem(initialSize, stableId: stableId)
    }))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().giveawayHeaderTitle), data: .init(color: theme.colors.text, detectBold: true, viewType: .modern(position: .inner, insets: .init()), fontSize: 18, centerViewAlignment: true, alignment: .center)))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().giveawayHeaderText), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .modern(position: .inner, insets: .init()), fontSize: 13, centerViewAlignment: true, alignment: .center)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if state.type == .random || state.type == .specific {
        let random_icon = generateGiveawayTypeImage(NSImage(named: "Icon_Giveaway_Random")!, colorIndex: 5)
        let specific_icon = generateGiveawayTypeImage(NSImage(named: "Icon_Giveaway_Specific")!, colorIndex: 6)

        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_giveaway, data: .init(name: strings().giveawayTypeRandomTitle, color: theme.colors.text, icon: random_icon, type: .selectableLeft(state.type == .random), viewType: .firstItem, enabled: true, description: strings().giveawayTypeRandomText, action: {
            arguments.updateType(.random)
        })))
        index += 1
        
        let selectText: String
        if state.selectedPeers.isEmpty {
            selectText = strings().giveawayTypeSpecificText
        } else {
            selectText = state.selectedPeers.map { $0.peer.displayTitle }.joined(separator: ", ")
        }
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_giveaway_specific, data: .init(name: strings().giveawayTypeSpecificTitle, color: theme.colors.text, icon: specific_icon, type: .selectableLeft(state.type == .specific), viewType: .lastItem, enabled: true, description: selectText, descTextColor: theme.colors.accent, action: {
            arguments.updateType(.specific)
        })))
    } else if case let .prepaid(prepaid) = state.type {
        let countIcon = generalPrepaidGiveawayIcon(theme.colors.accent, count: .initialize(string: "\(prepaid.quantity)", color: theme.colors.accent, font: .avatar(.text)))
        let icon = generateGiveawayTypeImage(NSImage(named: "Icon_Giveaway_Random")!, colorIndex: Int(prepaid.months) % 7)
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_prepaid, data: .init(name: strings().giveawayTypePrepaidTitle(Int(prepaid.quantity)), color: theme.colors.text, icon: icon, type: .imageContext(countIcon, ""), viewType: .singleItem, description: strings().giveawayTypePrepaidDesc(Int(prepaid.months)), descTextColor: theme.colors.grayText)))
    }
    
   
  
    // entries
       
    switch state.type {
    case .random, .prepaid:
        
        if state.type == .random {
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().giveawayQuantityHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem, rightItem: .init(isLoading: false, text: .initialize(string: strings().giveawayQuantityRightCountable(Int(state.quantity)), color: theme.colors.listGrayText, font: .normal(.small))))))
            index += 1
            
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_size, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
                var sizes: [Int32] = [1, 3, 5, 7, 10, 25, 50]
                switch state.type {
                case let .prepaid(giveaway):
                    if !sizes.contains(giveaway.quantity) {
                        sizes.append(giveaway.quantity)
                    }
                default:
                    break
                }
                return SelectSizeRowItem(initialSize, stableId: stableId, current: state.quantity, sizes: sizes, hasMarkers: false, titles: sizes.map { "\($0)" }, viewType: .singleItem, selectAction: { index in
                    arguments.updateQuantity(sizes[index])
                })
            }))
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().giveawayQuantityInfo), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
            index += 1

        }
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().giveawayChannelsHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
        index += 1
        
        var channels: [PeerEquatable] = state.channels
        
        struct ChannelTuple: Equatable {
            let peer: PeerEquatable
            let quantity: Int32
            let viewType: GeneralViewType
            let deletable: Bool
        }
        
        var channelItems: [ChannelTuple] = []
        
        let maximumReached = arguments.context.appConfiguration.getGeneralValue("giveaway_add_peers_max", orElse: 10) == channels.count
        
        for (i, channel) in channels.enumerated() {
            var viewType = bestGeneralViewType(channels, for: i)
            if !maximumReached {
                if i == channels.count - 1 {
                    if channels.count == 1 {
                        viewType = .firstItem
                    } else {
                        viewType = .innerItem
                    }
                }
            }
            
            
            channelItems.append(.init(peer: channel, quantity: state.quantity, viewType: viewType, deletable: i != 0))
        }
        let perSentGift = arguments.context.appConfiguration.getGeneralValue("boosts_per_sent_gift", orElse: 4)

        
        for item in channelItems {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                
                return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: nil, status: item.peer.peer.id == state.channels[0].peer.id ? strings().giveawayChannelsBoostReceiveCountable(Int(item.quantity * perSentGift)) : nil, inset: NSEdgeInsets(left: 20, right: 20), viewType: item.viewType, contextMenuItems: {
                    var items: [ContextMenuItem] = []
                    if item.deletable {
                        items.append(ContextMenuItem(strings().giveawayChannelsContextRemove, handler: {
                            arguments.deleteChannel(item.peer.peer.id)
                        }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                    }
                    return .single(items)
                }, menuOnAction: true)
            }))
        }
        if !maximumReached {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_channel, data: .init(name: strings().giveawayChannelsAdd, color: theme.colors.accent, icon: theme.icons.proxyAddProxy, viewType: .lastItem, action: arguments.addChannel)))
        }
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().givewayChannelsInfo), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().giveawayReceiverTypeTitle), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
        index += 1
        
        let countryText: String = strings().giveawayReceiverTypeCountriesCountable(state.countries.count)

        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_receiver_all, data: .init(name: strings().giveawayReceiverTypeAll, color: theme.colors.text, type: .selectableLeft(state.receiver == .all), viewType: .firstItem, description: countryText, descTextColor: theme.colors.accent, action: {
            arguments.updateReceiver(.all)
        })))
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_receiver_new, data: .init(name: strings().giveawayReceiverTypeNew, color: theme.colors.text, type: .selectableLeft(state.receiver == .new), viewType: .lastItem, description: countryText, descTextColor: theme.colors.accent, action: {
            arguments.updateReceiver(.new)
        })))

        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().giveawayReceiverTypeInfo), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1
        

        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().giveawayDateTitle), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
        index += 1
        

        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_select_date, data: .init(name: strings().giveawayDateEnds, color: theme.colors.text, type: .nextContext(stringForFullDate(timestamp: Int32(state.date.timeIntervalSince1970))), viewType: .singleItem, action: arguments.selectDate)))
        
        if state.quantity > 0 {
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().giveawayDateInfo), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
            index += 1
        }
    case .specific:
        break
    }
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    //WINNERS
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_show_winners, data: .init(name: strings().boostGiftWinners, color: theme.colors.text, type: .switchable(state.showWinners), viewType: .singleItem, action: {
        arguments.toggleShowWinners(state.showWinners)
    })))
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().boostGiftWinnersInfo), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().boostGiftAdditionalPrizes.uppercased()), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_additional_prizes, data: .init(name: strings().boostGiftAdditionalPrizes, color: theme.colors.text, type: .switchable(state.additionalPrizes), viewType: state.additionalPrizes ? .firstItem : .singleItem, action: {
        arguments.toggleAdditionalPrizes(state.additionalPrizes)
    })))
    
    if state.additionalPrizes {
        entries.append(.input(sectionId: sectionId, index: index, value: .string(state.prizeDescription), error: nil, identifier: _id_prize_description, mode: .plain, data: .init(viewType: .lastItem), placeholder: .init("\(state.quantity)"), inputPlaceholder: strings().boostGiftAdditionalPrizesPlaceholder, filter: { $0 }, limit: 128))
        
        
        let prizeDescription = state.prizeDescription ?? ""
        let prizeDescriptionInfoText: String
        let monthsString = strings().boostGiftAdditionalPrizesInfoForMonthsCountable(Int(state.selectedMonths))
        if prizeDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let subscriptionsString = strings().boostGiftAdditionalPrizesInfoSubscriptionsCountable(Int(state.quantity)).replacingOccurrences(of: "\(state.quantity) ", with: "")
            prizeDescriptionInfoText = strings().boostGiftAdditionalPrizesInfoOn("\(state.quantity)", subscriptionsString, monthsString)
        } else {
            let subscriptionsString = strings().boostGiftAdditionalPrizesInfoWithSubscriptionsCountable(Int(state.quantity)).replacingOccurrences(of: "\(state.quantity) ", with: "")
            let description = "\(prizeDescription) \(subscriptionsString)"
            prizeDescriptionInfoText = strings().boostGiftAdditionalPrizesInfoOn("\(state.quantity)", description, monthsString)
        }
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(prizeDescriptionInfoText), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1
    } else {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().boostGiftAdditionalPrizesInfoOff), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1
        
    }
    

    if state.type == .random || state.type == .specific {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().giveawayPaymentOptionsTitle), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
        index += 1
        
        let recipientCount: Int
        switch state.type {
        case .random, .prepaid:
            recipientCount = Int(state.quantity)
        case .specific:
            recipientCount = state.selectedPeers.count
        }
        
        
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
                return GiveawayDurationOptionItem(initialSize, stableId: stableId, option: option.option, selected: option.selected, viewType: option.viewType, toggleOption: arguments.toggleOption)
            }))
        }
        
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().giveawayPaymentOptionsInfo, linkHandler: arguments.execute), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1

    }
        
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

enum GiveawaySubject {
    case general
    case prepaid(count: Int32, month: Int32)
}

func GiveawayModalController(context: AccountContext, peerId: PeerId, prepaid: PrepaidGiveaway?) -> InputDataModalController {

    let actionsDisposable = DisposableSet()
    
    let paymentDisposable = MetaDisposable()
    actionsDisposable.add(paymentDisposable)
    
    let activationDisposable = MetaDisposable()
    actionsDisposable.add(activationDisposable)
    
    let inAppPurchaseManager = context.inAppPurchaseManager
    
    
    
    var canMakePayment: Bool = true
    #if APP_STORE || DEBUG
    canMakePayment = inAppPurchaseManager.canMakePayments
    #endif

    let type: State.GiveawayType
    if let prepaid = prepaid {
        type = .prepaid(prepaid)
    } else {
        type = .random
    }
    let initialState = State(type: type, channels: [], canMakePayment: canMakePayment)
    
    var close: (()->Void)? = nil
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let addSpecificUsers:()->Void = {
        let behaviour = SelectChannelMembersBehavior(peerId: peerId, peerChannelMemberContextsManager: context.peerChannelMemberCategoriesContextsManager, limit: 10, settings: [.remote, .excludeBots])
        _ = selectModalPeers(window: context.window, context: context, title: strings().giveawayTypeSpecificModalSelectUsers, behavior: behaviour, selectedPeerIds: Set(stateValue.with { $0.selectedPeers.map { $0.peer.id } })).start(next: { peerIds in
            let peers: Signal<[PeerEquatable], NoError> = context.account.postbox.transaction { transaction in
                var peers:[PeerEquatable] = []
                for peerId in peerIds {
                    if let peer = PeerEquatable(transaction.getPeer(peerId)) {
                        peers.append(peer)
                    }
                }
                return peers
            } |> deliverOnMainQueue
            
            _ = peers.start(next: { value in
                updateState { current in
                    var current = current
                    current.selectedPeers = value
                    return current
                }
            })
        })
    }

    let arguments = Arguments(context: context, updateQuantity: { value in
        updateState { current in
            var current = current
            current.quantity = value
            return current
        }
    }, updateReceiver: { value in
        let equal = value == stateValue.with { $0.receiver }
        if equal {
            showModal(with: SelectCountries(context: context, selected: stateValue.with { $0.countries }, complete: { list in
                updateState { current in
                    var current = current
                    current.countries = list
                    return current
                }
            }), for: context.window)
        } else {
            updateState { current in
                var current = current
                current.receiver = value
                return current
            }
        }
    }, updateType: { value in
        updateState { current in
            var current = current
            current.type = value
            return current
        }
        if value == .specific {
            addSpecificUsers()
        }
    }, selectDate: {
        
        let seven_days: TimeInterval = 60 * 60 * 24 * 7
        
        let maximum_period = context.appConfiguration.getGeneralValue("giveaway_period_max", orElse: Int32(Date().timeIntervalSince1970 + seven_days))
        
        let maximumDate = Date().timeIntervalSince1970 + TimeInterval(maximum_period)
        
        showModal(with: DateSelectorModalController(context: context, defaultDate: stateValue.with { $0.date }, mode: .date(title: strings().giveawayDateSelectDate, doneTitle: strings().giveawayDateSelectDateOK), selectedAt: { value in
            if value.timeIntervalSince1970 > maximumDate {
                updateState { current in
                    var current = current
                    current.date = Date(timeIntervalSince1970: maximumDate)
                    return current
                }
                showModalText(for: context.window, text: strings().giveawayTooLongDate)
            } else {
                updateState { current in
                    var current = current
                    current.date = value
                    return current
                }
            }
            
        }), for: context.window)
    }, execute: { link in
        if link == "premium" {
            showModal(with: PremiumBoardingController(context: context), for: context.window)
        }
    }, toggleOption: { value in
        updateState { current in
            var current = current
            current.selectedMonths = value.months
            return current
        }
    }, addChannel: {
        _ = selectModalPeers(window: context.window, context: context, title: strings().giveawayChannelsAddSelectChannel, behavior: SelectChatsBehavior(settings: [.channels], excludePeerIds: stateValue.with { $0.channels.map { $0.peer.id } }, limit: 1), confirmation: { peerIds in
            if let peerId = peerIds.first {
                return context.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue |> mapToSignal { peer in
                    if peer.addressName == nil {
                        return verifyAlertSignal(for: context.window, header: strings().giveawayChannelsAddPrivateHeader, information: strings().giveawayChannelsAddPrivateText, ok: strings().giveawayChannelsAddPrivateOk) |> map { $0 == .basic }
                    } else {
                        return .single(true)
                    }
                }
            } else {
                return .single(true)
            }
        }).start(next: { peerIds in
            let signal = context.account.postbox.loadedPeerWithId(peerIds[0]) |> deliverOnMainQueue
            _ = signal.start(next: { peer in
                updateState { current in
                    var current = current
                    current.channels.append(.init(peer))
                    return current
                }
            })
        })
    }, deleteChannel: { peerId in
        updateState { current in
            var current = current
            current.channels.removeAll(where: { $0.peer.id == peerId })
            return current
        }
    }, toggleShowWinners: { value in
        updateState { current in
            var current = current
            current.showWinners = !value
            return current
        }
    }, toggleAdditionalPrizes: { value in
        updateState { current in
            var current = current
            current.additionalPrizes = !value
            return current
        }
    })
    
    let products: Signal<[InAppPurchaseManager.Product], NoError>
    #if APP_STORE || DEBUG
    products = inAppPurchaseManager.availableProducts |> map {
        $0
    }
    #else
    products = .single([])
    #endif
    
    let productsAndDefaultPrice: Signal<([PremiumGiftProduct], (Int64, NSDecimalNumber)), NoError> = combineLatest(
        context.engine.payments.premiumGiftCodeOptions(peerId: peerId),
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
    

    let buyNonStore:()->Void = {
        let state = stateValue.with { $0 }
        
        var selectedProduct: PremiumGiftProduct?
        let selectedMonths = state.selectedMonths
        if let product = state.products.first(where: { $0.months == selectedMonths && $0.giftOption.users == state.quantity }) {
            selectedProduct = product
        }
        
        guard let premiumProduct = selectedProduct else {
            return
        }
        
        let additionalPeerIds = state.channels.map { $0.peer.id }.filter { $0 != peerId }
        let countries = state.countries.map { $0.id }
        
        let source = BotPaymentInvoiceSource.premiumGiveaway(boostPeer: peerId, additionalPeerIds: additionalPeerIds, countries: countries, onlyNewSubscribers: state.receiver == .new, showWinners: state.showWinners, prizeDescription: state.prizeDescription, randomId: Int64.random(in: .min ..< .max), untilDate: Int32(state.date.timeIntervalSince1970), currency: premiumProduct.priceCurrencyAndAmount.currency, amount: premiumProduct.priceCurrencyAndAmount.amount, option: premiumProduct.giftOption)
        
        let invoice = showModalProgress(signal: context.engine.payments.fetchBotPaymentInvoice(source: source), for: context.window)

        actionsDisposable.add(invoice.start(next: { invoice in
            showModal(with: PaymentsCheckoutController(context: context, source: source, invoice: invoice, completion: { status in
            
                switch status {
                case .paid:
                    PlayConfetti(for: context.window)
                    showModalText(for: context.window, text: strings().giveawayAlertCreated)
                    close?()
                default:
                    break
                }
                
            }), for: context.window)
        }, error: { error in
            showModalText(for: context.window, text: strings().paymentsInvoiceNotExists)
        }))
        
    }
    
    let buyAppStore = {
        
        let state = stateValue.with { $0 }
        
        var selectedProduct: PremiumGiftProduct?
        let selectedMonths = state.selectedMonths
        if let product = state.products.first(where: { $0.months == selectedMonths && $0.giftOption.users == state.quantity }) {
            selectedProduct = product
        }
        
        guard let premiumProduct = selectedProduct else {
            
            verifyAlert(for: context.window, header: strings().giveawayPaymentOptionsReduceTitle, information: strings().giveawayPaymentOptionsReduceText("\(state.quantity)", "\(selectedMonths)"), ok: strings().giveawayPaymentOptionsReduceOK, successHandler: { _ in
                updateState { state in
                    var updatedState = state
                    updatedState.quantity = 25
                    return updatedState
                }
            })
            return
        }

        guard let storeProduct = premiumProduct.storeProduct else {
            buyNonStore()
            return
        }
        
        let lockModal = PremiumLockModalController()
        
        var needToShow = true
        delay(0.2, closure: {
            if needToShow {
                showModal(with: lockModal, for: context.window)
            }
        })
        let purpose: AppStoreTransactionPurpose = .giveaway(boostPeer: peerId, additionalPeerIds: stateValue.with { $0.channels.map { $0.peer.id }.filter { $0 != peerId } }, countries: stateValue.with { $0.countries.map { $0.id } }, onlyNewSubscribers: stateValue.with { $0.receiver == .new }, showWinners: state.showWinners, prizeDescription: state.prizeDescription, randomId: Int64.random(in: .min ..< .max), untilDate: stateValue.with { Int32($0.date.timeIntervalSince1970) }, currency: premiumProduct.priceCurrencyAndAmount.currency, amount: premiumProduct.priceCurrencyAndAmount.amount)
        
                
        let _ = (context.engine.payments.canPurchasePremium(purpose: purpose)
        |> deliverOnMainQueue).start(next: { [weak lockModal] available in
            if available {
                paymentDisposable.set((inAppPurchaseManager.buyProduct(storeProduct, quantity: premiumProduct.giftOption.storeQuantity, purpose: purpose)
                |> deliverOnMainQueue).start(next: { [weak lockModal] status in
    
                    lockModal?.close()
                    needToShow = false
                    
                    close?()
                    inAppPurchaseManager.finishAllTransactions()
                    delay(0.2, closure: {
                        PlayConfetti(for: context.window)
                        showModalText(for: context.window, text: strings().giveawayAlertCreated)
                        let _ = updatePremiumPromoConfigurationOnce(account: context.account).start()
                    })
                    
                }, error: { [weak lockModal] error in
                    let errorText: String
                    switch error {
                        case .generic:
                            errorText = strings().premiumPurchaseErrorUnknown
                        case .network:
                            errorText =  strings().premiumPurchaseErrorNetwork
                        case .notAllowed:
                            errorText =  strings().premiumPurchaseErrorNotAllowed
                        case .cantMakePayments:
                            errorText =  strings().premiumPurchaseErrorCantMakePayments
                        case .assignFailed:
                            errorText =  strings().premiumPurchaseErrorUnknown
                        case .cancelled:
                            errorText = strings().premiumBoardingAppStoreCancelled
                    }
                    lockModal?.close()
                    showModalText(for: context.window, text: errorText)
                    inAppPurchaseManager.finishAllTransactions()
                }))
            } else {
                lockModal?.close()
                needToShow = false
            }
        })
    }
    
    
    actionsDisposable.add((context.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue).start(next: { channel in
        updateState { current in
            var current = current
            current.channels.append(.init(channel))
            return current
        }
    }))
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().giveawayTitle)
    
    controller.didLoad = { controller, _ in
        controller.genericView.layer?.masksToBounds = false
        controller.tableView.layer?.masksToBounds = false
        controller.tableView.documentView?.layer?.masksToBounds = false
        controller.tableView.clipView.layer?.masksToBounds = false
    }
    
    controller.updateDatas = { data in
        updateState { current in
            var current = current
            current.prizeDescription = data[_id_prize_description]?.stringValue
            return current
        }
        return .none
    }
    
    controller.validateData = { _ in
        let state = stateValue.with { $0 }
        if state.additionalPrizes {
            if state.prizeDescription == nil || state.prizeDescription == "" {
                return .fail(.fields([_id_prize_description : .shake]))
            }
        }
        
        let buy:()->Void = {
            if let prepaid = prepaid {
                let state = stateValue.with { $0 }
                let additionalPeerIds = state.channels.map { $0.peer.id }.filter { $0 != peerId }
                let countries = state.countries.map { $0.id }
                let signal = context.engine.payments.launchPrepaidGiveaway(peerId: peerId, id: prepaid.id, additionalPeerIds: additionalPeerIds, countries: countries, onlyNewSubscribers: state.receiver == .new, showWinners: state.showWinners, prizeDescription: state.prizeDescription, randomId: Int64.random(in: .min ..< .max), untilDate: Int32(state.date.timeIntervalSince1970))
                _ = showModalProgress(signal: signal, for: context.window).start(completed: {
                    PlayConfetti(for: context.window)
                    showModalText(for: context.window, text: strings().giveawayAlertCreated)
                    close?()
                })
            } else {
                buyAppStore()
            }
        }
        if let _ = prepaid {
            verifyAlert(for: context.window, header: strings().boostGiftStartConfirmationTitle, information: strings().boostGiftStartConfirmationText, ok: strings().boostGiftStartConfirmationStart, successHandler: { _ in
                buy()
            })
        } else {
            buy()
        }
       
        return .none
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().giveawayStartGiveaway, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, size: NSMakeSize(360, 300))
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}


/*
 
 */



