//
//  InviteLinkMonthlyFeeRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08.07.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import InputView
import CurrencyFormat

final class InviteLinkMonthlyFeeRowItem : GeneralRowItem {
    fileprivate let inputState: Updated_ChatTextInputState
    fileprivate let usdRate: Double
    fileprivate let amount: Int64
    fileprivate let context: AccountContext
    fileprivate let priceLayout: TextViewLayout
    fileprivate let interactions: TextView_Interactions
    fileprivate let updateState:(Updated_ChatTextInputState?)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, interactions: TextView_Interactions, enabled: Bool, state: Updated_ChatTextInputState, usdRate: Double, viewType: GeneralViewType, updateState:@escaping(Updated_ChatTextInputState?)->Void) {
        self.inputState = state
        self.usdRate = usdRate
        self.amount = Int64(state.string) ?? 0
        self.context = context
        self.interactions = interactions
        self.updateState = updateState
        let amountString = "~$" + "\(Double(amount) * self.usdRate)".prettyCurrencyNumberUsd + "/month"

        
        self.priceLayout = .init(.initialize(string: amountString, color: theme.colors.grayText, font: .normal(.text)))
        self.priceLayout.measure(width: .greatestFiniteMagnitude)
        
        super.init(initialSize, height: 40, stableId: stableId, viewType: viewType, enabled: enabled)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        return true
    }
    
    override var height: CGFloat {
        return 42
    }
    
    override func viewClass() -> AnyClass {
        return InviteLinkMonthlyFeeRowView.self
    }
}


private final class InviteLinkMonthlyFeeRowView : GeneralContainableRowView {
    private var starView: InlineStickerView?
    private let priceView = TextView()
    let inputView: UITextView = UITextView(frame: NSMakeRect(0, 0, 100, 20))

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(priceView)
        addSubview(inputView)
        
        priceView.userInteractionEnabled = false
        priceView.isSelectable = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func shakeView() {
        super.shakeView()
        containerView.shake(beep: true)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? InviteLinkMonthlyFeeRowItem else {
            return
        }
        
        priceView.update(item.priceLayout)
        
        if starView == nil {
            let view = InlineStickerView(account: item.context.account, file: LocalAnimatedSticker.star_currency_new.file, size: NSMakeSize(24, 24), playPolicy: .framesCount(1))
            self.starView = view
            addSubview(view)
        }
        
        
        inputView.placeholder = strings().inviteLinkSubAmountPlaceholder
        
        inputView.inputTheme = inputView.inputTheme.withUpdatedTextColor(item.enabled ? theme.colors.text : theme.colors.grayText)
        
        inputView.context = item.context
        inputView.interactions.max_height = 500
        inputView.interactions.min_height = 13
        inputView.interactions.emojiPlayPolicy = .onceEnd
        inputView.interactions.canTransform = false
        inputView.interactions.inputIsEnabled = item.enabled

        item.interactions.min_height = 13
        item.interactions.max_height = 500
        item.interactions.emojiPlayPolicy = .onceEnd
        item.interactions.canTransform = false
        
        item.interactions.inputIsEnabled = item.enabled
        
        
        self.inputView.alphaValue = item.enabled ? 1 : 0.8
        self.starView?.alphaValue = item.enabled ? 1 : 0.8
        self.priceView.alphaValue = item.enabled ? 1 : 0.8

        let value = item.amount
        
        let max_limit = 10000
        
        inputView.inputTheme = inputView.inputTheme.withUpdatedTextColor(value > max_limit ? theme.colors.redUI : theme.colors.text)
        
        
        item.interactions.filterEvent = { event in
            if let chars = event.characters {
                return chars.trimmingCharacters(in: CharacterSet(charactersIn: "1234567890\u{7f}")).isEmpty
            } else {
                return false
            }
        }

        self.inputView.set(item.interactions.presentation.textInputState())

        self.inputView.interactions = item.interactions
        
        item.interactions.inputDidUpdate = { [weak self] state in
            guard let `self` = self else {
                return
            }
            self.set(state)
            self.inputDidUpdateLayout(animated: true)
        }
        
        
        needsLayout = true
    }
    
    
    var textWidth: CGFloat {
        return containerView.frame.width - priceView.frame.width - 20 - 10
    }
    
    func textViewSize() -> (NSSize, CGFloat) {
        let w = textWidth
        let height = inputView.height(for: w)
        return (NSMakeSize(w, min(max(height, inputView.min_height), inputView.max_height)), height)
    }
    
    private func inputDidUpdateLayout(animated: Bool) {
        self.updateLayout(size: frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        super.updateLayout(size: size, transition: transition)
        
        let (textSize, textHeight) = textViewSize()
        
        if let starView {
            transition.updateFrame(view: starView, frame: starView.centerFrameY(x: 10))
            
            transition.updateFrame(view: inputView, frame: CGRect(origin: CGPoint(x: starView.frame.maxX + 5, y: 7), size: textSize))
            inputView.updateLayout(size: textSize, textHeight: textHeight, transition: transition)
        }
        priceView.centerY(x: containerView.frame.width - priceView.frame.width - 10)

    }
    
    private func set(_ state: Updated_ChatTextInputState) {
        guard let item = item as? InviteLinkMonthlyFeeRowItem else {
            return
        }
        item.updateState(state)
        
        item.redraw(animated: true)
    }
    
}

