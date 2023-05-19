//
//  PremiumSelectPeriodRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 10.08.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

struct PremiumPeriod : Equatable {
    enum Period {
        case month
        case sixMonth
        case year
    }
    var period: Period
    var price: Int64
    var currency: String
    
    var titleString: String {
        return "text"
    }
    var priceString: String {
        return "test"
    }
    var discountString: Int {
        return 20
    }
    
}

final class PremiumSelectPeriodRowItem : GeneralRowItem {
    let periods: [PremiumPeriod]
    let context: AccountContext
    let selectedPeriod: PremiumPeriod
    let callback: (PremiumPeriod)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, periods: [PremiumPeriod], selectedPeriod: PremiumPeriod, viewType: GeneralViewType, callback:@escaping(PremiumPeriod)->Void) {
        self.periods = periods
        self.callback = callback
        self.context = context
        self.selectedPeriod = selectedPeriod
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

            self.backgroundColor = theme.colors.background
        }
        
        override func layout() {
            super.layout()
            
            
            imageView.centerY(x: 15)
            
            title.centerY(x: imageView.frame.maxX + 15)
            
            commonPrice.centerY(x: frame.width - commonPrice.frame.width - 15)
            discount.centerY(x: title.frame.maxX + 5)
            
            borderView.frame = NSMakeRect(title.frame.minX, frame.height - .borderSize, frame.width - title.frame.minY, .borderSize)
            
        }
        
        func update(_ option: PremiumPeriod, selected: Bool, isLast: Bool, context: AccountContext, animated: Bool, select: @escaping(PremiumPeriod)->Void) {
            
            let selected_image = generateChatGroupToggleSelected(foregroundColor: theme.colors.premium, backgroundColor: theme.colors.underSelectedColor)
            
            let unselected_image = generateChatGroupToggleUnselected(foregroundColor: theme.colors.grayIcon.withAlphaComponent(0.6), backgroundColor: NSColor.black.withAlphaComponent(0.05))

            
            self.imageView.image = selected ? selected_image : unselected_image
            self.imageView.setFrameSize(20, 20)
            
            self.borderView.backgroundColor = theme.colors.border
            
            self.borderView.isHidden = isLast
            
            

            let titleLayout = TextViewLayout(.initialize(string: option.titleString, color: theme.colors.text, font: .normal(.title)))
            titleLayout.measure(width: .greatestFiniteMagnitude)

            let commonPriceLayout = TextViewLayout(.initialize(string: option.priceString, color: theme.colors.grayText, font: .normal(.title)))
            commonPriceLayout.measure(width: .greatestFiniteMagnitude)

            let discountLayout = TextViewLayout(.initialize(string: "-\(option.discountString)%", color: theme.colors.underSelectedColor, font: .medium(.small)))
            discountLayout.measure(width: .greatestFiniteMagnitude)



            self.title.update(titleLayout)
            self.commonPrice.update(commonPriceLayout)

            self.discount.update(discountLayout)
            self.discount.setFrameSize(discountLayout.layoutSize.width + 8, discountLayout.layoutSize.height + 4)
            self.discount.layer?.cornerRadius = .cornerRadius
            self.discount.backgroundColor = theme.colors.premium


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
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PremiumSelectPeriodRowItem else {
            return
        }
        
        while optionsView.subviews.count > item.periods.count {
            optionsView.subviews.last?.removeFromSuperview()
        }
        while optionsView.subviews.count < item.periods.count {
            let optionView = OptionView(frame: NSMakeSize(item.blockWidth, 40).bounds)
            optionsView.addSubview(optionView)
        }
        
        for (i, option) in item.periods.enumerated() {
            let subview = optionsView.subviews.compactMap { $0 as? OptionView }[i]
            subview.update(option, selected: option == item.selectedPeriod, isLast: i == item.periods.count - 1, context: item.context, animated: animated, select: item.callback)
        }
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

