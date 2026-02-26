//
//  Fragment_OverviewRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.06.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import CurrencyFormat
import TelegramCore

final class Fragment_OverviewRowItem : GeneralRowItem {
    
    struct Overview: Equatable {
        
        struct Stars : Equatable {
            let amount: StarsAmount
            let usdRate: Double
                        
            var fractional: Double {
                return currencyToFractionalAmount(value: amount.totalValue, currency: XTR) ?? 0
            }
            var usdAmount: String {
                return "$" + "\(self.fractional * self.usdRate)".prettyCurrencyNumberUsd
            }
        }
        
        let amount: Int64
        let usdAmount: String
        let info: String
        
        let stars: Stars?
    }
    
    let context: AccountContext
    
    let overview: Overview
    
    let amount: TextViewLayout
    let info: TextViewLayout
    
    let currency: LocalTelegramCurrency
    
    let starsAmount: TextViewLayout?
    
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, overview: Overview, currency: LocalTelegramCurrency, viewType: GeneralViewType) {
        self.context = context
        self.overview = overview
        self.currency = currency
        
                
        let amountAttr = NSMutableAttributedString()
        let justAmount = NSAttributedString.initialize(string: formatCurrencyAmount(overview.amount, currency: currency.rawValue).prettyCurrencyNumber, color: theme.colors.text, font: .medium(.header)).smallDecemial
        amountAttr.append(justAmount)
        amountAttr.append(string: " ≈", color: theme.colors.grayText, font: .normal(.text))
        
        let justAmount2 = NSAttributedString.initialize(string: overview.usdAmount, color: theme.colors.grayText, font: .normal(.text)).smallDecemial
        amountAttr.append(justAmount2)

        self.amount = .init(amountAttr)
        
        self.info = .init(.initialize(string: overview.info, color: theme.colors.grayText, font: .normal(.text)))
        
        if let starsAmount = overview.stars {
            let attr = NSMutableAttributedString()
            attr.append(string: "\(clown) \(starsAmount.amount)", color: theme.colors.text, font: .medium(.text))
            attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)
            attr.append(string: " =", color: theme.colors.grayText, font: .normal(.text))
            let usdAmount = NSAttributedString.initialize(string: starsAmount.usdAmount, color: theme.colors.grayText, font: .normal(.text)).smallDecemial
            attr.append(usdAmount)
            self.starsAmount = .init(attr)
        } else {
            self.starsAmount = nil
        }
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        amount.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right - 22)
        info.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)
        starsAmount?.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right - 22)
        return true
    }
    
    override func viewClass() -> AnyClass {
        return OverviewRowView.self
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
        height += viewType.innerInset.top
        height += amount.layoutSize.height
        height += 2
        height += info.layoutSize.height
        
        height += viewType.innerInset.bottom
        return height
    }
}

private final class OverviewRowView : GeneralContainableRowView {
    private let amountView = TextView()
    private let infoView = TextView()
    private let icon = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 20, 20))

    private var starsAmount: InteractiveTextView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(amountView)
        addSubview(infoView)
        addSubview(icon)
        
        amountView.userInteractionEnabled = false
        amountView.isSelectable = false
        
        infoView.userInteractionEnabled = false
        infoView.isSelectable = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func layout() {
        super.layout()
        guard let item = item as? Fragment_OverviewRowItem else {
            return
        }
        icon.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, item.viewType.innerInset.top - 3))
        amountView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left + 22, item.viewType.innerInset.top))
        infoView.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, amountView.frame.maxY + 2))
        
        if let starsAmount {
            starsAmount.setFrameOrigin(NSMakePoint(amountView.frame.maxX + 20, amountView.frame.minY))
        }
        
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? Fragment_OverviewRowItem else {
            return
        }
        
        let parameters = item.currency.logo.parameters
        parameters.colors = item.currency.colored(theme.colors.accent)
        
        icon.update(with: item.currency.logo.file, size: icon.frame.size, context: item.context, table: item.table, parameters: parameters, animated: animated)
        
        
        if let starsAmount = item.starsAmount {
            let current: InteractiveTextView
            if let view = self.starsAmount {
                current = view
            } else {
                current = InteractiveTextView(frame: starsAmount.layoutSize.bounds)
                self.starsAmount = current
                addSubview(current)
            }
            current.set(text: starsAmount, context: item.context)
        } else if let view = self.starsAmount {
            performSubviewRemoval(view, animated: animated)
            self.starsAmount = nil
        }
        
        amountView.update(item.amount)
        infoView.update(item.info)
        
        needsLayout = true
    }
}
