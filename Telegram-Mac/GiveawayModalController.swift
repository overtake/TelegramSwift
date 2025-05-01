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

extension PrepaidGiveaway {
    var purpose: LaunchGiveawayPurpose {
        switch self.prize {
        case let .stars(stars, _):
            return .stars(stars: stars, users: quantity)
        case .premium:
            return .premium
        }
    }
}


private final class StarsToDistributeRowItem : GeneralRowItem {
    let context: AccountContext
    let option: State.StarOption
    
    let starsCount: Int64
    let quantity: Int64
    
    fileprivate let price: TextViewLayout
    fileprivate let textLayout: TextViewLayout
    fileprivate let amountLayout: TextViewLayout
    
    fileprivate let select: (State.StarOption)->Void
    fileprivate let selected: Bool

    init(_ initialSize: NSSize, stableId: AnyHashable, option: State.StarOption, quantity: Int64, selected: Bool, context: AccountContext, viewType: GeneralViewType, select: @escaping(State.StarOption)->Void) {
        self.context = context
        self.option = option
        self.quantity = quantity
        self.select = select
        self.selected = selected
        
        self.price = .init(.initialize(string: option.formattedPrice, color: theme.colors.grayText, font: .normal(.text)))
        self.textLayout = .init(.initialize(string: strings().starListItemCountCountable(Int(option.amount)).replacingOccurrences(of: "\(option.amount)", with: option.amount.formattedWithSeparator), color: theme.colors.text, font: .medium(.text)))
        
        self.amountLayout = .init(.initialize(string: strings().giveawayStarAmountPerCountable(Int(quantity)), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        
        self.starsCount = min(5, (Int64(option.id) ?? 0) + 1)
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
        
        price.measure(width: .greatestFiniteMagnitude)
        textLayout.measure(width: .greatestFiniteMagnitude)
        amountLayout.measure(width: .greatestFiniteMagnitude)

    }
    
    override func viewClass() -> AnyClass {
        return StarsToDistributeRowView.self
    }
    
    override var height: CGFloat {
        return 50
    }
}


private final class StarsToDistributeRowView : GeneralContainableRowView {
    private let stars = View()
    private let textView = TextView()
    private let price = TextView()
    private let amount = TextView()
    private let toggleView = SelectingControl(unselectedImage: theme.icons.chatToggleUnselected, selectedImage: theme.icons.chatToggleSelected)
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(stars)
        addSubview(textView)
        addSubview(price)
        addSubview(toggleView)
        addSubview(amount)
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        price.userInteractionEnabled = false
        price.isSelectable = false
        
        amount.userInteractionEnabled = false
        amount.isSelectable = false
        
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Highlight)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Normal)
        containerView.set(handler: { [weak self] _ in
            self?.updateColors()
        }, for: .Hover)
        
        containerView.scaleOnClick = true
        
        containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? StarsToDistributeRowItem {
                item.select(item.option)
            }
        }, for: .Click)

        stars.layer?.masksToBounds = false
        
    }
    
    override var additionBorderInset: CGFloat {
        return 8 + toggleView.frame.width
    }
    
    override func updateColors() {
        super.updateColors()
        if let item = item as? GeneralRowItem {
            self.background = item.viewType.rowBackground
            let highlighted = isSelect ? self.backdorColor : theme.colors.grayHighlight
            containerView.set(background: self.backdorColor, for: .Normal)
            containerView.set(background: highlighted, for: .Highlight)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StarsToDistributeRowItem else {
            return
        }
        
        textView.update(item.textLayout)
        price.update(item.price)
        amount.update(item.amountLayout)
        
        self.toggleView.set(selected: item.selected)
        
        while stars.subviews.count > item.starsCount {
            stars.subviews.last?.removeFromSuperview()
        }
        
        for i in Int64(stars.subviews.count) ..< item.starsCount {
            if i == 0 {
                let view = InlineStickerView(account: item.context.account, file: LocalAnimatedSticker.star_currency_new.file, size: NSMakeSize(20, 20))
                stars.addSubview(view)
            } else {
                let view = InlineStickerView(account: item.context.account, file: LocalAnimatedSticker.star_currency_part_new.file, size: NSMakeSize(20, 20))
                stars.addSubview(view)
            }
        }
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        toggleView.centerY(x: 10)
        stars.frame = NSMakeRect(toggleView.frame.maxX + 10, 7, 20, 20)

        
        for (i, star) in stars.subviews.enumerated() {
            if i == 0 {
                star.centerY(x: 0)
            } else {
                star.centerY(x: CGFloat(i) * 3)
            }
        }
        
        textView.setFrameOrigin(NSMakePoint(stars.frame.minX + 20 + CGFloat(stars.subviews.count * 3) + 5, 7))
        amount.setFrameOrigin(NSMakePoint(stars.frame.minX, frame.height - amount.frame.height - 7))

        
        price.centerY(x: containerView.frame.width - price.frame.width - 10)
    }
}



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
    let selectStarOption:(State.StarOption)->Void
    let revealStarOptions:()->Void
    let updateStarWinners:(StarsGiveawayOption.Winners)->Void
    init(context: AccountContext, updateQuantity:@escaping(Int32)->Void, updateReceiver:@escaping(State.GiveawayReceiver)->Void, updateType:@escaping(State.GiveawayType)->Void, selectDate:@escaping()->Void, execute:@escaping(String)->Void, toggleOption:@escaping(State.PaymentOption)->Void, addChannel:@escaping()->Void, deleteChannel:@escaping(PeerId)->Void, toggleShowWinners:@escaping(Bool)->Void, toggleAdditionalPrizes:@escaping(Bool)->Void, selectStarOption:@escaping(State.StarOption)->Void, revealStarOptions:@escaping()->Void, updateStarWinners:@escaping(StarsGiveawayOption.Winners)->Void) {
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
        self.selectStarOption = selectStarOption
        self.revealStarOptions = revealStarOptions
        self.updateStarWinners = updateStarWinners
    }
}




private struct State : Equatable {
    
    struct StarOption : Equatable {
        let amount: Int64
        let price: Int64
        let currency: String
        let id: String
        
        let storeProduct: InAppPurchaseManager.Product?
        let native: StarsGiveawayOption
        
        
        var formattedPrice: String {
            if let storeProduct {
                return formatCurrencyAmount(storeProduct.priceCurrencyAndAmount.amount, currency: storeProduct.priceCurrencyAndAmount.currency)
            } else {
                return formatCurrencyAmount(price, currency: currency)
            }
        }
    }
    
    enum GiveawayType : Equatable {
        case random
        case specific
        case prepaid(PrepaidGiveaway)
        case stars
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
    
    var starOptions: [StarOption] = []
    var selectedStarOption: StarOption? = nil
    var selectedWinner: StarsGiveawayOption.Winners?
    var revealStarOptions: Bool = false
    
    var defaultPrice: DefaultPrice = .init(intergal: 1, decimal: 1)
    
    var canMakePayment: Bool = true
    
    var countries: [Country] = []
    
    var isGroup: Bool
    
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
private let _id_show_more = InputDataIdentifier("_id_show_more")

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
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(state.isGroup ? strings().giveawayHeaderTextGroup : strings().giveawayHeaderText), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .modern(position: .inner, insets: .init()), fontSize: 13, centerViewAlignment: true, alignment: .center)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if state.type == .random || state.type == .specific || state.type == .stars {
        let premium_icon = NSImage(resource: .iconGiveawayPremium).precomposed(flipVertical: true)
        let stars_icon = NSImage(resource: .iconGiveawayStars).precomposed(flipVertical: true)

        
        let selectText: String
        if state.selectedPeers.isEmpty {
            selectText = strings().giveawayTypePremiumRandomText
        } else {
            selectText = state.selectedPeers.map { $0.peer.displayTitle }.joined(separator: ", ")
        }
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_giveaway, data: .init(name: strings().giveawayTypePremiumTitle, color: theme.colors.text, icon: premium_icon, type: .selectableLeft(state.type == .random || state.type == .specific), viewType: .firstItem, enabled: true, description: selectText, descTextColor: theme.colors.accent, action: {
            arguments.updateType(.random)
        })))
        index += 1
                
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_giveaway_specific, data: .init(name: strings().giveawayTypeStarsTitle, color: theme.colors.text, icon: stars_icon, type: .selectableLeft(state.type == .stars), viewType: .lastItem, enabled: true, description: strings().giveawayTypeStarsText, descTextColor: theme.colors.grayText, action: {
            arguments.updateType(.stars)
        })))
    } else if case let .prepaid(prepaid) = state.type {
        let title: String
        let info: String
        let icon: CGImage
        let countIcon: CGImage
        switch prepaid.prize {
        case let .premium(months):
            countIcon = generalPrepaidGiveawayIcon(theme.colors.accent, count: .initialize(string: "\(prepaid.quantity)", color: theme.colors.accent, font: .avatar(.text)))
            icon = generateGiveawayTypeImage(NSImage(named: "Icon_Giveaway_Random")!, colorIndex: Int(months) % 7)
            title = strings().giveawayTypePrepaidTitle(Int(prepaid.quantity))
            info = strings().giveawayTypePrepaidDesc(Int(months))
        case let .stars(stars, boosts):
            countIcon = generalPrepaidGiveawayIcon(theme.colors.accent, count: .initialize(string: "\(boosts)", color: theme.colors.accent, font: .avatar(.text)))
            icon = NSImage.init(resource: .iconGiveawayStars).precomposed(flipVertical: true)
            title = strings().giveawayStarsPrepaidTitle(Int(stars))
            info = strings().giveawayStarsPrepaidDescCountable(Int(prepaid.quantity))
        }
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_prepaid, data: .init(name: title, color: theme.colors.text, icon: icon, type: .imageContext(countIcon, ""), viewType: .singleItem, description: info, descTextColor: theme.colors.grayText)))
    }
    
   
    if state.type == .stars, let selected = state.selectedStarOption, let selectedWinner = state.selectedWinner {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().giveawayStarOptionsHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem, rightItem: .init(isLoading: false, text: .initialize(string: strings().giveawayQuantityRightCountable(Int(selected.native.yearlyBoosts)), color: theme.colors.listGrayText, font: .normal(.small))))))
        index += 1
        
        struct Tuple: Equatable {
            let option: State.StarOption
            let quantity: Int64
            let viewType: GeneralViewType
            let selected: Bool
        }
        var items: [Tuple] = []
        
        let revealed = state.revealStarOptions ? state.starOptions : state.starOptions.filter({ !$0.native.isExtended })
        let concealed = state.revealStarOptions ? [] : state.starOptions.filter({ $0.native.isExtended })
        
        for (i, starOption) in revealed.enumerated() {
            var viewType: GeneralViewType = bestGeneralViewType(revealed, for: i)
            if !state.revealStarOptions, !concealed.isEmpty, i == revealed.count - 1 {
                viewType = .innerItem
            }
            let isSelected = state.selectedStarOption == starOption
            let quantity: Int64
            if isSelected {
                quantity = Int64(selectedWinner.starsPerUser)
            } else {
                quantity = starOption.native.winners.first(where: { $0.isDefault })?.starsPerUser ?? starOption.native.winners.first?.starsPerUser ?? starOption.amount
            }
            items.append(.init(option: starOption, quantity: quantity, viewType: viewType, selected: isSelected))
            
        }
        
        for item in items {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_option(item.option.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                return StarsToDistributeRowItem(initialSize, stableId: stableId, option: item.option, quantity: item.quantity, selected: item.selected, context: arguments.context, viewType: item.viewType, select: arguments.selectStarOption)
            }))
        }
        
        if !state.revealStarOptions, !concealed.isEmpty {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_show_more, data: .init(name: strings().fragmentStarsShowMore, color: theme.colors.accent,icon: theme.icons.chatSearchUp, type: .none, viewType: .lastItem, action: arguments.revealStarOptions, iconTextInset: 30, iconInset: -5)))
        }
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().giveawayStarOptionsInfo), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1
    }
  
    // entries
       
    switch state.type {
    case .random, .prepaid, .stars:
        
        if state.type == .random || state.type == .stars {
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            let item:(NSSize, InputDataEntryId)->TableRowItem
            let title: String
            let info: String
            
            let rightItem: InputDataGeneralTextRightData
            
            if state.type == .stars, let starOptions = state.selectedStarOption, let selectedWinner = state.selectedWinner {
                item = { initialSize, stableId in
                    var sizes: [Int32] = starOptions.native.winners.map { $0.users }
                    return SelectSizeRowItem(initialSize, stableId: stableId, current: selectedWinner.users, sizes: sizes, hasMarkers: false, titles: sizes.map { "\($0)" }, viewType: .singleItem, selectAction: { index in
                        arguments.updateStarWinners(starOptions.native.winners[index])
                    })
                }
                title = strings().giveawayStarQuantityHeader
                info = strings().giveawayStarQuantityInfo
                rightItem = .init(isLoading: false, text: nil)
            } else {
                item = { initialSize, stableId in
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
                }
                title = strings().giveawayQuantityHeader
                info = strings().giveawayQuantityInfo
                
                rightItem = .init(isLoading: false, text: .initialize(string: strings().giveawayQuantityRightCountable(Int(state.quantity)), color: theme.colors.listGrayText, font: .normal(.small)))
            }
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(title), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem, rightItem: rightItem)))
            index += 1
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_size, equatable: .init(state), comparable: nil, item: item))
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(info), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
            index += 1

        }
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(state.isGroup ? strings().giveawayChannelsHeaderGroup : strings().giveawayChannelsHeader), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
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
        
        let perSentGift = arguments.context.appConfiguration.getGeneralValue("boosts_per_sent_gift", orElse: 4)
        
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
            var quantity = state.quantity
            switch state.type {
            case .prepaid(let prepaidGiveaway):
                switch prepaidGiveaway.prize {
                case .premium:
                    quantity = quantity * perSentGift
                case let .stars(_, boosts):
                    quantity = boosts
                }
            case .stars:
                quantity = state.quantity
            default:
                quantity = quantity * perSentGift
            }
            channelItems.append(.init(peer: channel, quantity: quantity, viewType: viewType, deletable: i != 0))
        }

        
        for item in channelItems {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                
                let status: String?
                if item.peer.peer.id == state.channels[0].peer.id {
                    
                    if state.isGroup {
                        status = strings().giveawayChannelsBoostReceiveGroupCountable(Int(item.quantity))
                    } else {
                        status = strings().giveawayChannelsBoostReceiveCountable(Int(item.quantity))
                    }
                } else {
                    status = nil
                }
                return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: nil, status: status, inset: NSEdgeInsets(left: 20, right: 20), viewType: item.viewType, contextMenuItems: {
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
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_channel, data: .init(name: state.isGroup ? strings().giveawayChannelsAddGroup : strings().giveawayChannelsAdd, color: theme.colors.accent, icon: theme.icons.proxyAddProxy, viewType: .lastItem, action: arguments.addChannel)))
        }
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(state.isGroup ? strings().givewayChannelsInfoGroup : strings().givewayChannelsInfo), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
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
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(state.isGroup ? strings().giveawayDateInfoGroup : strings().giveawayDateInfo), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
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
        case .random, .prepaid, .stars:
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

func GiveawayModalController(context: AccountContext, peerId: PeerId, prepaid: PrepaidGiveaway?, isGroup: Bool) -> InputDataModalController {

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
    let initialState = State(type: type, channels: [], canMakePayment: canMakePayment, isGroup: isGroup)
    
    var close: (()->Void)? = nil
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let addSpecificUsers:()->Void = {
        let behaviour = SelectChannelMembersBehavior(peerId: peerId, peerChannelMemberContextsManager: context.peerChannelMemberCategoriesContextsManager, limit: 10, settings: [.remote, .excludeBots])
        
        let state = stateValue.with { $0 }
        if state.selectedPeers.count != 0 {
            behaviour.additionTopItem = .init(title: strings().giveawayStarChooseRandomly, color: theme.colors.accent, icon: NSImage(resource: .iconGiveawayRandomResult).precomposed(theme.colors.accent), callback: {
                updateState { current in
                    var current = current
                    current.selectedPeers = []
                    return current
                }
                closeModal(SelectPeersModalController.self)
            })
        }
        
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
        let oldValue = stateValue.with { $0.type }
        updateState { current in
            var current = current
            current.type = value
            return current
        }
        if value == .specific {
            addSpecificUsers()
        } else if value == .random, oldValue == .random {
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
            prem(with: PremiumBoardingController(context: context), for: context.window)
        }
    }, toggleOption: { value in
        updateState { current in
            var current = current
            current.selectedMonths = value.months
            return current
        }
    }, addChannel: {
        
        var settings: SelectPeerSettings = [.channels]
        if isGroup {
            settings = [.channels, .groups]
        }
        
        _ = selectModalPeers(window: context.window, context: context, title: strings().giveawayChannelsAddSelectChannel, behavior: SelectChatsBehavior(settings: settings, excludePeerIds: stateValue.with { $0.channels.map { $0.peer.id } }, limit: 1), confirmation: { peerIds in
            if let peerId = peerIds.first {
                return context.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue |> mapToSignal { peer in
                    
                    let isGroup = peer.isGroup || peer.isSupergroup
                    if peer.addressName == nil {
                        let header: String = isGroup ? strings().giveawayChannelsAddPrivateHeaderGroup : strings().giveawayChannelsAddPrivateHeader
                        let info = isGroup ? strings().giveawayChannelsAddPrivateTextGroup : strings().giveawayChannelsAddPrivateText
                        let ok = isGroup ? strings().giveawayChannelsAddPrivateOkGroup : strings().giveawayChannelsAddPrivateOk
                        return verifyAlertSignal(for: context.window, header: header, information: info, ok: ok) |> map { $0 == .basic }
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
    }, selectStarOption: { option in
        updateState { current in
            var current = current
            current.selectedStarOption = option
            current.selectedWinner = option.native.winners.first(where: { $0.isDefault }) ?? option.native.winners.first
            return current
        }
    }, revealStarOptions: {
        updateState { current in
            var current = current
            current.revealStarOptions = true
            return current
        }
    }, updateStarWinners: { winners in
        updateState { current in
            var current = current
            current.selectedWinner = winners
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
        
        let additionalPeerIds = state.channels.map { $0.peer.id }.filter { $0 != peerId }
        let countries = state.countries.map { $0.id }
        
        let source: BotPaymentInvoiceSource?
        switch state.type {
        case .stars:
            if let selected = state.selectedStarOption, let winners = state.selectedWinner {
                source = .starsGiveaway(stars: selected.amount, boostPeer: peerId, additionalPeerIds: state.channels.map { $0.peer.id }.filter { $0 != peerId }, countries: state.countries.map { $0.id }, onlyNewSubscribers: state.receiver == .new, showWinners: state.showWinners, prizeDescription: state.prizeDescription, randomId: Int64.random(in: .min ..< .max), untilDate: Int32(state.date.timeIntervalSince1970), currency: selected.currency, amount: selected.price, users: winners.users)
            } else {
                source = nil
            }
        default:
            let selectedMonths = state.selectedMonths
            if let product = state.products.first(where: { $0.months == selectedMonths && $0.giftOption.users == state.quantity }) {
                source = BotPaymentInvoiceSource.premiumGiveaway(boostPeer: peerId, additionalPeerIds: additionalPeerIds, countries: countries, onlyNewSubscribers: state.receiver == .new, showWinners: state.showWinners, prizeDescription: state.prizeDescription, randomId: Int64.random(in: .min ..< .max), untilDate: Int32(state.date.timeIntervalSince1970), currency: product.priceCurrencyAndAmount.currency, amount: product.priceCurrencyAndAmount.amount, option: product.giftOption)
            } else {
                source = nil
            }
           
        }
        
        guard let source else {
            return
        }
        
        
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
        
        var selectedProduct: InAppPurchaseManager.Product?
        let selectedMonths = state.selectedMonths
        let storeQuantity: Int32
        if state.type == .stars {
            if let product = state.selectedStarOption?.storeProduct {
                selectedProduct = product
            }
            storeQuantity = 1
        } else {
            if let product = state.products.first(where: { $0.months == selectedMonths && $0.giftOption.users == state.quantity }) {
                selectedProduct = product.storeProduct
                storeQuantity = product.giftOption.storeQuantity
            } else {
                verifyAlert(for: context.window, header: strings().giveawayPaymentOptionsReduceTitle, information: strings().giveawayPaymentOptionsReduceText("\(state.quantity)", "\(selectedMonths)"), ok: strings().giveawayPaymentOptionsReduceOK, successHandler: { _ in
                    updateState { state in
                        var updatedState = state
                        updatedState.quantity = 25
                        return updatedState
                    }
                })
                return
            }
        }
        
    
        guard let premiumProduct = selectedProduct else {
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
        
        
        let purpose: AppStoreTransactionPurpose
        switch state.type {
        case .stars:
            if let selected = state.selectedStarOption, let winners = state.selectedWinner {
                purpose = .starsGiveaway(stars: selected.amount, boostPeer: peerId, additionalPeerIds: state.channels.map { $0.peer.id }.filter { $0 != peerId }, countries: state.countries.map { $0.id }, onlyNewSubscribers: state.receiver == .new, showWinners: state.showWinners, prizeDescription: state.prizeDescription, randomId: Int64.random(in: .min ..< .max), untilDate: Int32(state.date.timeIntervalSince1970), currency: premiumProduct.priceCurrencyAndAmount.currency, amount: premiumProduct.priceCurrencyAndAmount.amount, users: winners.users)
            } else {
                fatalError()
            }
        default:
            purpose = .giveaway(boostPeer: peerId, additionalPeerIds: state.channels.map { $0.peer.id }.filter { $0 != peerId }, countries: state.countries.map { $0.id }, onlyNewSubscribers: state.receiver == .new, showWinners: state.showWinners, prizeDescription: state.prizeDescription, randomId: Int64.random(in: .min ..< .max), untilDate: Int32(state.date.timeIntervalSince1970), currency: premiumProduct.priceCurrencyAndAmount.currency, amount: premiumProduct.priceCurrencyAndAmount.amount)
        }
        
                
        let _ = (context.engine.payments.canPurchasePremium(purpose: purpose)
        |> deliverOnMainQueue).start(next: { [weak lockModal] available in
            if available {
                paymentDisposable.set((inAppPurchaseManager.buyProduct(premiumProduct, quantity: storeQuantity, purpose: purpose)
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
    
    
    
    actionsDisposable.add(combineLatest(context.engine.payments.starsGiveawayOptions(), products).startStrict(next: { value, products in
        let options:[State.StarOption] = value.compactMap { value in
            let product = products.first(where: { $0.id == value.storeProductId })
            return .init(amount: value.count, price: value.amount, currency: value.currency, id: "\(value.count)", storeProduct: product, native: value)
        }
        updateState { current in
            var current = current
            current.starOptions = options
            current.selectedStarOption = options.first(where: { $0.native.isDefault }) ?? options.first
            current.selectedWinner = options.first?.native.winners.first(where: { $0.isDefault }) ?? options.first?.native.winners.first
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
                let signal = context.engine.payments.launchPrepaidGiveaway(peerId: peerId, id: prepaid.id, purpose: prepaid.purpose, additionalPeerIds: additionalPeerIds, countries: countries, onlyNewSubscribers: state.receiver == .new, showWinners: state.showWinners, prizeDescription: state.prizeDescription, randomId: Int64.random(in: .min ..< .max), untilDate: Int32(state.date.timeIntervalSince1970))
                _ = showModalProgress(signal: signal, for: context.window).start(completed: {
                    PlayConfetti(for: context.window)
                    showModalText(for: context.window, text: strings().giveawayAlertCreated)
                    close?()
                })
            } else {
                #if APP_STORE
                buyAppStore()
                #endif
                buyNonStore()
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
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, size: NSMakeSize(420, 300))
    
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



