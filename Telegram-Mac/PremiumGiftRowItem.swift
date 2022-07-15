//
//  PremiumGiftRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 28.06.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit



final class PremiumGiftRowItem : GeneralRowItem {
    
    let select: (PremiumGiftOption)->Void
    let context: AccountContext
    let selectedOption: PremiumGiftOption
    let options: [PremiumGiftOption]
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, context: AccountContext, selectedOption: PremiumGiftOption, options: [PremiumGiftOption], select:@escaping(PremiumGiftOption)->Void) {
        self.select = select
        self.context = context
        self.options = options
        self.selectedOption = selectedOption
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        
        
        return true
    }
    
    override func viewClass() -> AnyClass {
        return PremiumGiftRowView.self
    }
    
    override var height: CGFloat {
        return CGFloat(options.count) * 50 + (CGFloat(options.count - 1) * 10)
    }
}


private final class PremiumGiftRowView: GeneralContainableRowView {
    
    private class OptionView : Control {
        
        private let imageView = ImageView()
        private let title = TextView()
        private let commonPrice = TextView()
        private let discount = TextView()
        private let discountText = TextView()
        private let selected = View()
        
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
            
            discountText.userInteractionEnabled = false
            discountText.isSelectable = false


            commonPrice.userInteractionEnabled = false
            commonPrice.isSelectable = false

            addSubview(imageView)
            addSubview(title)
            addSubview(commonPrice)
            addSubview(discount)
            addSubview(discountText)
            addSubview(selected)

            self.backgroundColor = theme.colors.background
        }
        
        override func layout() {
            super.layout()
            
            imageView.centerY(x: 15)
            
            title.setFrameOrigin(NSMakePoint(imageView.frame.maxX + 15, 7))
            
            commonPrice.centerY(x: frame.width - commonPrice.frame.width - 15)
            discount.setFrameOrigin(NSMakePoint(title.frame.minX, frame.height - discount.frame.height - 7))
            discountText.setFrameOrigin(NSMakePoint(discount.frame.maxX + 8, frame.height - discountText.frame.height - 8))

            selected.frame = bounds
            
        }
        
        func update(_ option: PremiumGiftOption, selected: Bool, context: AccountContext, animated: Bool, select: @escaping(PremiumGiftOption)->Void) {
            
            let selected_image = generateChatGroupToggleSelected(foregroundColor: theme.colors.premium, backgroundColor: theme.colors.underSelectedColor)
            
            let unselected_image = generateChatGroupToggleUnselected(foregroundColor: theme.colors.grayIcon.withAlphaComponent(0.6), backgroundColor: NSColor.black.withAlphaComponent(0.05))

            
            self.imageView.image = selected ? selected_image : unselected_image
            self.imageView.setFrameSize(20, 20)
            
            self.selected.layer?.borderColor = theme.colors.premium.cgColor
            self.selected.layer?.cornerRadius = 10
            self.selected.layer?.borderWidth = 1.5
            
            self.selected.change(opacity: selected ? 1.0 : 0.0, animated: animated)
            
            
            let titleLayout = TextViewLayout(.initialize(string: option.titleString, color: theme.colors.text, font: .normal(.title)))
            titleLayout.measure(width: .greatestFiniteMagnitude)
            
            let commonPriceLayout = TextViewLayout(.initialize(string: option.priceString, color: theme.colors.grayText, font: .normal(.title)))
            commonPriceLayout.measure(width: .greatestFiniteMagnitude)
            
            let discountLayout = TextViewLayout(.initialize(string: option.discountString, color: theme.colors.underSelectedColor, font: .medium(.small)))
            discountLayout.measure(width: .greatestFiniteMagnitude)

            
            let discountPriceLayout = TextViewLayout(.initialize(string: option.priceDiscountString, color: theme.colors.grayText, font: .normal(.small)))
            discountPriceLayout.measure(width: .greatestFiniteMagnitude)
            
            self.title.update(titleLayout)
            self.commonPrice.update(commonPriceLayout)
            self.discountText.update(discountPriceLayout)
            
            self.discount.update(discountLayout)
            self.discount.setFrameSize(discountLayout.layoutSize.width + 8, discountLayout.layoutSize.height + 4)
            self.discount.layer?.cornerRadius = .cornerRadius
            self.discount.backgroundColor = theme.colors.premium

            
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
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func layout() {
        super.layout()
        
        optionsView.frame = containerView.bounds
        
        let subviews = optionsView.subviews.compactMap { $0 as? OptionView }
        
        
        var y: CGFloat = 0
        for subview in subviews {
            subview.setFrameOrigin(NSMakePoint(0, y))
            y += subview.frame.height + 10
        }
    }
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PremiumGiftRowItem else {
            return
        }
        
        while optionsView.subviews.count > item.options.count {
            optionsView.subviews.last?.removeFromSuperview()
        }
        while optionsView.subviews.count < item.options.count {
            let optionView = OptionView(frame: NSMakeSize(item.blockWidth, 50).bounds)
            optionsView.addSubview(optionView)
        }
        
        for (i, option) in item.options.enumerated() {
            let subview = optionsView.subviews.compactMap { $0 as? OptionView }[i]
            subview.update(option, selected: option == item.selectedOption, context: item.context, animated: animated, select: item.select)
        }
        
        needsLayout = true
    }
}
