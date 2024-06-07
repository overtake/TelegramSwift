//
//  Fragment_BalanceRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.06.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import CurrencyFormat


final class Fragment_BalanceRowItem : GeneralRowItem {
    
    
    struct Balance : Equatable {
        var amount: Int64
        var usd: String
        var currency: TelegramCurrency
    }
    
    let context: AccountContext
    let tonBalance: TextViewLayout
    let usdBalance: TextViewLayout
    let balance: Balance
        
    fileprivate let transfer:()->Void
    
    let canWithdraw: Bool

    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, balance: Balance, canWithdraw: Bool, viewType: GeneralViewType, transfer:@escaping()->Void) {
        self.context = context
        self.balance = balance
        self.transfer = transfer
        self.canWithdraw = canWithdraw
        
        let tonBalance = NSAttributedString.initialize(string: formatCurrencyAmount(balance.amount, currency: balance.currency.rawValue).prettyCurrencyNumber, color: theme.colors.text, font: .medium(40)).smallDecemial
        let usdBalance = NSAttributedString.initialize(string: "≈" + balance.usd, color: theme.colors.grayText, font: .normal(.text)).smallDecemial

        self.tonBalance = .init(tonBalance)
        self.usdBalance = .init(usdBalance)

        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    var withdrawText: String {
        return strings().monetizationBalanceWithdraw
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.tonBalance.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)
        self.usdBalance.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)

        return true
    }
    
    override func viewClass() -> AnyClass {
        return BalanceRowView.self
    }
    
    
    override var height: CGFloat {
        var height: CGFloat = 0
        height += viewType.innerInset.top
        
        height += 46
        height -= 3
        height += usdBalance.layoutSize.height
        
        if balance.amount > 0 {
            height += viewType.innerInset.top
            height += 40
            height += 10
        }
        
        height += viewType.innerInset.left
        return height
    }
}

private final class BalanceRowView : GeneralContainableRowView {
    

    
    private let tonBalanceView = TextView()
    private let tonBalanceContainer = View()
    private let tonView = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 46, 46))
    private let usdBalanceView = TextView()
    
    private var withdrawAction: TextButton?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        tonBalanceContainer.addSubview(tonView)
        tonBalanceContainer.addSubview(tonBalanceView)
        addSubview(tonBalanceContainer)
        addSubview(usdBalanceView)
                
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? Fragment_BalanceRowItem else {
            return
        }
        
        transition.updateFrame(view: tonBalanceContainer, frame: tonBalanceContainer.centerFrameX(y: item.viewType.innerInset.top))
        transition.updateFrame(view: tonView, frame: tonView.centerFrameY(x: 0, addition: -3))
        transition.updateFrame(view: tonBalanceView, frame: tonBalanceView.centerFrameY(x: tonView.frame.maxX))

        
        transition.updateFrame(view: usdBalanceView, frame: usdBalanceView.centerFrameX(y: tonBalanceContainer.frame.maxY - 4))
        
        var withdrawY: CGFloat = containerView.frame.height - item.viewType.innerInset.left
        
        if let withdrawAction {
            withdrawY -= withdrawAction.frame.height
            transition.updateFrame(view: withdrawAction, frame: CGRect(origin: NSMakePoint(item.viewType.innerInset.left, withdrawY), size: withdrawAction.frame.size))
            withdrawY -= item.viewType.innerInset.left
        }
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? Fragment_BalanceRowItem else {
            return
        }
        
        usdBalanceView.update(item.usdBalance)
        tonBalanceView.update(item.tonBalance)
        
        var parameters = item.balance.currency.logo.parameters
        parameters.colors = item.balance.currency.colored(theme.colors.accent)
        
        tonView.update(with: item.balance.currency.logo.file, size: tonView.frame.size, context: item.context, table: item.table, parameters: parameters, animated: animated)
        
        tonBalanceContainer.setFrameSize(tonBalanceContainer.subviewsWidthSize)

        if item.balance.amount > 0 {
            let currentAction: TextButton
            if let withdrawAction {
                currentAction = withdrawAction
            } else {
                currentAction = TextButton()
                currentAction.scaleOnClick = true
                currentAction.autohighlight = false
                currentAction.set(font: .medium(.text), for: .Normal)
                addSubview(currentAction)
                self.withdrawAction = currentAction
            }
            
            let blockWidth = item.blockWidth - item.viewType.innerInset.left - item.viewType.innerInset.right
            
            currentAction.set(color: theme.colors.underSelectedColor, for: .Normal)
            currentAction.set(background: theme.colors.accent, for: .Normal)
            currentAction.layer?.cornerRadius = 10
            currentAction.set(text: item.withdrawText, for: .Normal)
            currentAction.sizeToFit(.zero, NSMakeSize(blockWidth, 40), thatFit: true)
            
            currentAction.removeAllHandlers()
            
            currentAction.isEnabled = item.canWithdraw
            
            currentAction.set(handler: { [weak item] _ in
                item?.transfer()
            }, for: .Click)
            
        } else {
            if let withdrawAction {
                performSubviewRemoval(withdrawAction, animated: animated)
                self.withdrawAction = nil
            }
        }
        
        updateLayout(size: self.frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
    
}
