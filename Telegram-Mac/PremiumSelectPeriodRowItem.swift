//
//  PremiumSelectPeriodRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 10.08.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import InAppPurchaseManager
import CurrencyFormat

struct PremiumPeriod : Equatable {
    enum Period : Int32 {
        case month = 1
        case sixMonth = 6
        case year = 12
        case twoYears = 24
    }
    var period: Period
    var options: [PremiumPromoConfiguration.PremiumProductOption]
    var storeProducts: [InAppPurchaseManager.Product]
    var storeProduct: InAppPurchaseManager.Product?
    var option: PremiumPromoConfiguration.PremiumProductOption
    
    static func ==(lhs: PremiumPeriod, rhs: PremiumPeriod) -> Bool {
        return lhs.period == rhs.period
    }
    
    var titleString: String {
        switch period {
        case .month:
            return strings().premiumPeriodMonthly
        case .year:
            return strings().premiumPeriodAnnual
        case .sixMonth:
            return strings().premiumPeriodSixMonth
        case .twoYears:
            return strings().premiumPeriodTwoYears
        }
    }
    var priceString: String {
        switch period {
        case .month:
            return strings().premiumPeriodPrice(amountString)
        case .sixMonth:
            return strings().premiumPeriodPrice(amountString)
        case .year:
            return strings().premiumPeriodPriceYear(fullAmount)
        case .twoYears:
            return strings().premiumPeriodPriceTwoYear(fullAmount)
        }
    }
    var buyString: String {
        switch period {
        case .month:
            return strings().premiumBoardingSubscribeMonth(fullAmount)
        case .sixMonth:
            return strings().premiumBoardingSubscribeSixMonth(fullAmount)
        case .year:
            return strings().premiumBoardingSubscribeYear(fullAmount)
        case .twoYears:
            return strings().premiumBoardingSubscribeTwoYears(fullAmount)
        }
    }
    var renewString: String {
        switch period {
        case .month:
            return strings().premiumBoardingRenewMonth(fullAmount)
        case .sixMonth:
            return strings().premiumBoardingRenewSixMonth(fullAmount)
        case .year:
            return strings().premiumBoardingRenewYear(fullAmount)
        case .twoYears:
            return strings().premiumBoardingRenewTwoYears(fullAmount)
        }
    }
    
    
    var fullAmount: String {
        let price: String
        if let storeProduct = storeProduct {
            price = formatCurrencyAmount(storeProduct.priceCurrencyAndAmount.amount, currency: storeProduct.priceCurrencyAndAmount.currency)
        } else {
            price = formatCurrencyAmount(option.amount, currency: option.currency)
        }
        return price
    }
    var amountString: String {
        let price: String
        if let storeProduct = storeProduct {
            price = formatCurrencyAmount(storeProduct.priceCurrencyAndAmount.amount / Int64(self.option.months), currency: storeProduct.priceCurrencyAndAmount.currency)
        } else {
            price = formatCurrencyAmount(option.amount / Int64(self.option.months), currency: option.currency)
        }
        return price
    }
    var discountString: Int {
        
        let amount = storeProduct?.priceCurrencyAndAmount.amount ?? option.amount
        
        let optionMonthly:Int64 = Int64((CGFloat(amount) / CGFloat(option.months)))
        
        let highestOptionMonthly:Int64 = options.map { option in
            let store = self.storeProducts.first(where: { $0.id == option.storeProductId })
            return Int64((CGFloat(store?.priceCurrencyAndAmount.amount ?? option.amount) / CGFloat(option.months)))
        }.max()!
        
        
        let discountPercent = Int(floor((Float(highestOptionMonthly) - Float(optionMonthly)) / Float(highestOptionMonthly) * 100))
        return discountPercent
    }
    
}

final class PremiumSelectPeriodRowItem : GeneralRowItem {
    let periods: [PremiumPeriod]
    let context: AccountContext
    let selectedPeriod: PremiumPeriod
    let callback: (PremiumPeriod)->Void
    let presentation: TelegramPresentationTheme
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, presentation: TelegramPresentationTheme, periods: [PremiumPeriod], selectedPeriod: PremiumPeriod, viewType: GeneralViewType, callback:@escaping(PremiumPeriod)->Void) {
        self.periods = periods
        self.callback = callback
        self.context = context
        self.selectedPeriod = selectedPeriod
        self.presentation = presentation
        super.init(initialSize, stableId: stableId, viewType: viewType, inset: NSEdgeInsets(left: 20, right: 20))
    }
    
    override var height: CGFloat {
        return (CGFloat(periods.count) * 40)
    }
    
    override func viewClass() -> AnyClass {
        return PremiumSelectPeriodRowView.self
    }
}


private final class PremiumSelectPeriodRowView: GeneralContainableRowView {
    
    private class OptionView : Control {
        
        private let imageView = ImageView()
        private let title = TextView()
        private let commonPrice = TextView()
        private let discount = TextView()
        private let borderView = View()
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            
            layer?.cornerRadius = 10
            
            imageView.isEventLess = true
            title.userInteractionEnabled = false
            title.isSelectable = false
            
            commonPrice.userInteractionEnabled = false
            commonPrice.isSelectable = false
            
            discount.userInteractionEnabled = false
            discount.isSelectable = false
            

            commonPrice.userInteractionEnabled = false
            commonPrice.isSelectable = false

            addSubview(imageView)
            addSubview(title)
            addSubview(commonPrice)
            addSubview(discount)
            addSubview(borderView)

        }
        
        override func layout() {
            super.layout()
            
            
            imageView.centerY(x: 15)
            
            title.centerY(x: imageView.frame.maxX + 15)
            
            commonPrice.centerY(x: frame.width - commonPrice.frame.width - 15)
            discount.centerY(x: title.frame.maxX + 5)
            
            borderView.frame = NSMakeRect(title.frame.minX, frame.height - .borderSize, frame.width - title.frame.minY, .borderSize)
            
        }
        
        func update(_ option: PremiumPeriod, presentation: TelegramPresentationTheme, selected: Bool, isLast: Bool, context: AccountContext, animated: Bool, select: @escaping(PremiumPeriod)->Void) {
            
            let selected_image = generateChatGroupToggleSelected(foregroundColor: presentation.colors.premium, backgroundColor: presentation.colors.underSelectedColor)
            
            let unselected_image = generateChatGroupToggleUnselected(foregroundColor: presentation.colors.grayIcon.withAlphaComponent(0.6), backgroundColor: NSColor.black.withAlphaComponent(0.05))

            
            self.imageView.image = selected ? selected_image : unselected_image
            self.imageView.setFrameSize(20, 20)
            
            self.backgroundColor = presentation.colors.background
            
            self.borderView.backgroundColor = presentation.colors.border
            
            self.borderView.isHidden = isLast
            
            

            let titleLayout = TextViewLayout(.initialize(string: option.titleString, color: presentation.colors.text, font: .normal(.title)))
            titleLayout.measure(width: .greatestFiniteMagnitude)

            let commonPriceLayout = TextViewLayout(.initialize(string: option.priceString, color: presentation.colors.grayText, font: .normal(.title)))
            commonPriceLayout.measure(width: .greatestFiniteMagnitude)

            let discountLayout = TextViewLayout(.initialize(string: "-\(option.discountString)%", color: presentation.colors.underSelectedColor, font: .medium(.small)), alignment: .center)
            discountLayout.measure(width: .greatestFiniteMagnitude)



            self.title.update(titleLayout)
            self.commonPrice.update(commonPriceLayout)

            self.discount.update(discountLayout)
            self.discount.setFrameSize(discountLayout.layoutSize.width + 8, discountLayout.layoutSize.height + 4)
            self.discount.layer?.cornerRadius = .cornerRadius
            self.discount.backgroundColor = presentation.colors.premium


            self.discount.isHidden = option.discountString == 0
            
            self.removeAllHandlers()
            self.set(handler: { _ in
                select(option)
            }, for: .Click)

            needsLayout = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    
    private let optionsView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(optionsView)
    }

    
    
    override func layout() {
        super.layout()
        
        optionsView.frame = containerView.bounds
        
        let subviews = optionsView.subviews.compactMap { $0 as? OptionView }
        
        
        var y: CGFloat = 0
        for subview in subviews {
            subview.setFrameOrigin(NSMakePoint(0, y))
            y += subview.frame.height
        }
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? PremiumSelectPeriodRowItem else {
            return super.backdorColor
        }
        return item.presentation.colors.background
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PremiumSelectPeriodRowItem else {
            return
        }
        
        self.backgroundColor = item.presentation.colors.background

        
        while optionsView.subviews.count > item.periods.count {
            optionsView.subviews.last?.removeFromSuperview()
        }
        while optionsView.subviews.count < item.periods.count {
            let optionView = OptionView(frame: NSMakeSize(item.blockWidth, 40).bounds)
            optionsView.addSubview(optionView)
        }
        
        for (i, option) in item.periods.enumerated() {
            let subview = optionsView.subviews.compactMap { $0 as? OptionView }[i]
            subview.update(option, presentation: item.presentation, selected: option == item.selectedPeriod, isLast: i == item.periods.count - 1, context: item.context, animated: animated, select: item.callback)
        }
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

