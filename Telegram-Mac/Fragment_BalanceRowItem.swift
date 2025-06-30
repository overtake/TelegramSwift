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
import SwiftSignalKit

final class Fragment_BalanceRowItem : GeneralRowItem {
    
    
    struct Balance : Equatable {
        var amount: Double
        var usd: String
        var currency: LocalTelegramCurrency
        
        var apxSymbol: String {
            switch currency {
            case .xtr:
                return "≈"
            case .ton:
                return "≈"
            }
        }
    }
    
    let context: AccountContext
    let tonBalance: TextViewLayout
    let usdBalance: TextViewLayout
    let balance: Balance
        
    fileprivate let transfer:()->Void
    
    let canWithdraw: Bool
    let nextWithdrawalTimestamp: Int32?
    let buyAds: (()->Void)?
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, balance: Balance, canWithdraw: Bool, buyAds: (()->Void)? = nil, nextWithdrawalTimestamp: Int32? = nil, viewType: GeneralViewType, transfer:@escaping()->Void) {
        self.context = context
        self.balance = balance
        self.transfer = transfer
        self.buyAds = buyAds
        var canWithdraw = canWithdraw
        if let nextWithdrawalTimestamp, nextWithdrawalTimestamp - context.timestamp >= 0 {
            canWithdraw = false
        }
        self.canWithdraw = canWithdraw
        self.nextWithdrawalTimestamp = nextWithdrawalTimestamp
        let tonBalance = NSAttributedString.initialize(string: formatCurrencyAmount(Int64(balance.amount), currency: balance.currency.rawValue).prettyCurrencyNumber, color: theme.colors.text, font: .medium(40)).smallDecemial
        let usdBalance = NSAttributedString.initialize(string: balance.apxSymbol + balance.usd, color: theme.colors.grayText, font: .normal(.text)).smallDecemial

        self.tonBalance = .init(tonBalance)
        self.usdBalance = .init(usdBalance)

        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    var withdrawText: String {
        switch balance.currency {
        case .xtr:
            return strings().monetizationBalanceWithdrawStars
        case .ton:
            return strings().monetizationBalanceWithdrawTon
        }
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
        
       // if balance.amount > 0 {
            height += viewType.innerInset.top
            height += 40
            height += 10
       // }
        
        height += viewType.innerInset.left
        return height
    }
}

private final class BalanceRowView : GeneralContainableRowView {
    

    
    private let tonBalanceView = TextView()
    private let tonBalanceContainer = View()
    private let tonView = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 46, 46))
    private let usdBalanceView = TextView()
    
    
    private final class WithdrawAction: Control {
        
        final class LockView : View {
            let textView = TextView()
            let imageView = ImageView()
            required init(frame frameRect: NSRect) {
                super.init(frame: frameRect)
                addSubview(textView)
                addSubview(imageView)
                
                textView.userInteractionEnabled = false
                textView.isSelectable = false
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            func set(targetTime: Int32, context: AccountContext) {
                
                
                imageView.image = NSImage(resource: .iconFragmentLock).precomposed(theme.colors.underSelectedColor)
                imageView.setFrameSize(NSMakeSize(12, 12))
                
                let string = stringForDuration(targetTime - context.timestamp)
                
                let layout = TextViewLayout(.initialize(string: string, color: theme.colors.underSelectedColor, font: .normal(.small)))
                layout.measure(width: .greatestFiniteMagnitude)
                
                textView.update(layout)
                
                self.setFrameSize(NSMakeSize(textView.frame.width + imageView.frame.width + 2, textView.frame.height))
            }
            
            override func layout() {
                super.layout()
                imageView.centerY(x: 0)
                textView.centerY(x: imageView.frame.width + 2)
            }
        }
        
        private let textView = TextView()
        private var lockView: LockView?
        private var timer: SwiftSignalKit.Timer?
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(textView)
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func set(targetTime: Int32?, text: String, width: CGFloat, context: AccountContext, animated: Bool) {
            
            let textLayout: TextViewLayout = .init(.initialize(string: text, color: theme.colors.underSelectedColor, font: .normal(.text)), maximumNumberOfLines: 1)
            textLayout.measure(width: width)
            self.layer?.cornerRadius = 10
            
            self.textView.update(textLayout)
            self.backgroundColor = theme.colors.accent
            
            if let targetTime, targetTime - context.timestamp >= 0 {
                let current: LockView
                let new: Bool
                if let view = self.lockView {
                    current = view
                    new = false
                } else {
                    current = LockView(frame: .zero)
                    self.addSubview(current)
                    self.lockView = current
                    new = true
                }
                current.set(targetTime: targetTime, context: context)
                
                if new {
                    current.centerX(y: frame.height - current.frame.height - 5)
                }
            
                self.timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: false, completion: { [weak self] in
                    self?.set(targetTime: targetTime, text: text, width: width, context: context, animated: true)
                }, queue: .mainQueue())

                
                self.timer?.start()
                
            } else {
                if let view = self.lockView {
                    performSubviewRemoval(view, animated: animated)
                    self.lockView = nil
                }
                self.timer?.invalidate()
                self.timer = nil
            }
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
            updateLayout(size: self.frame.size, transition: transition)
        }
        
        override func layout() {
            super.layout()
            self.updateLayout(size: self.frame.size, transition: .immediate)
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            if let lockView {
                transition.updateFrame(view: textView, frame: textView.centerFrameX(y: 5))
                transition.updateFrame(view: lockView, frame: lockView.centerFrameX(y: size.height - lockView.frame.height - 5))
            } else {
                transition.updateFrame(view: textView, frame: textView.centerFrame())
            }
        }
    }
    
    private var withdrawAction: WithdrawAction?
    private var adsAction: WithdrawAction?

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
        
        var actionX: CGFloat = item.viewType.innerInset.left
        
        if let withdrawAction {
            withdrawY -= withdrawAction.frame.height
            transition.updateFrame(view: withdrawAction, frame: CGRect(origin: NSMakePoint(actionX, withdrawY), size: withdrawAction.frame.size))
            
            actionX += withdrawAction.frame.width + 10
        }
        
        if let adsAction {
            transition.updateFrame(view: adsAction, frame: CGRect(origin: NSMakePoint(actionX, withdrawY), size: adsAction.frame.size))
        }
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? Fragment_BalanceRowItem else {
            return
        }
        
        usdBalanceView.update(item.usdBalance)
        tonBalanceView.update(item.tonBalance)
        
        let parameters = item.balance.currency.logo.parameters
        parameters.colors = item.balance.currency.colored(theme.colors.accent)
        
        tonView.update(with: item.balance.currency.logo.file, size: tonView.frame.size, context: item.context, table: item.table, parameters: parameters, animated: animated)
        
        tonBalanceContainer.setFrameSize(tonBalanceContainer.subviewsWidthSize)

        let currentAction: WithdrawAction
        if let withdrawAction {
            currentAction = withdrawAction
        } else {
            currentAction = WithdrawAction(frame: .zero)
            currentAction.scaleOnClick = true
            addSubview(currentAction)
            self.withdrawAction = currentAction
        }
        
        if item.buyAds != nil {
            let currentAction: WithdrawAction
            if let adsAction {
                currentAction = adsAction
            } else {
                currentAction = WithdrawAction(frame: .zero)
                currentAction.scaleOnClick = true
                addSubview(currentAction)
                self.adsAction = currentAction
            }
        } else if let view = self.adsAction {
            performSubviewRemoval(view, animated: animated)
            self.adsAction = nil
        }
        
        var blockWidth = item.blockWidth - item.viewType.innerInset.left - item.viewType.innerInset.right
        
        if adsAction != nil {
            blockWidth = (blockWidth - 10) / 2
        }
        
        currentAction.setFrameSize(NSMakeSize(blockWidth, 40))
        adsAction?.setFrameSize(NSMakeSize(blockWidth, 40))

        currentAction.set(targetTime: item.nextWithdrawalTimestamp, text: item.withdrawText, width: blockWidth, context: item.context, animated: animated)
        currentAction.isEnabled = item.canWithdraw && item.balance.amount > 0
        
        
        if let adsAction {
            adsAction.set(targetTime: nil, text: strings().starsBalanceBuyAds, width: blockWidth, context: item.context, animated: animated)
        }

        currentAction.removeAllHandlers()
        currentAction.set(handler: { [weak item] _ in
            item?.transfer()
        }, for: .Click)
        
        adsAction?.removeAllHandlers()
        adsAction?.set(handler: { [weak item] _ in
            item?.buyAds?()
        }, for: .Click)
        
        updateLayout(size: self.frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
    
}
