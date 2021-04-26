//
//  PaymentsCheckoutPriceItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25.02.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation



import Foundation
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TGUIKit

final class PaymentsCheckoutPriceItem : GeneralRowItem {
    
    struct EditableTip : Equatable {
        let currency: String
        let current: Int64
        let maxValue: Int64
    }
    
    fileprivate let editableTip: EditableTip?
    
    fileprivate let titleLayout: TextViewLayout
    fileprivate let priceLayout: TextViewLayout
    
    fileprivate let updateValue:(Int64?)->Void
    
    init(_ initialSize: NSSize, stableId: AnyHashable, title: String, price: String, font: NSFont, color: NSColor, viewType: GeneralViewType, editableTip: EditableTip? = nil, updateValue: @escaping(Int64?)->Void = { _ in }) {
        self.updateValue = updateValue
        self.editableTip = editableTip
        self.titleLayout = TextViewLayout(.initialize(string: title, color: color, font: font), maximumNumberOfLines: 1)
        self.priceLayout = TextViewLayout(.initialize(string: price, color: color, font: font))

        super.init(initialSize, viewType: viewType)
    }
    
    private var contentHeight: CGFloat = 0
    fileprivate private(set) var imageSize: NSSize = .zero
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        
        priceLayout.measure(width: blockWidth / 2 - 10 - viewType.innerInset.left - viewType.innerInset.right)
        
        titleLayout.measure(width: blockWidth - 10 - viewType.innerInset.left - viewType.innerInset.right - priceLayout.layoutSize.width)

        contentHeight = max(titleLayout.layoutSize.height, priceLayout.layoutSize.height)
        
        return true
    }
    
    override var height: CGFloat {
        return  viewType.innerInset.bottom + contentHeight + viewType.innerInset.top
    }
    
    override func viewClass() -> AnyClass {
        return PaymentsCheckoutPriceView.self
    }
    
    override var hasBorder: Bool {
        return false
    }
}


private final class PaymentsCheckoutPriceView : GeneralContainableRowView, NSTextViewDelegate {
    private let title: TextView = TextView()
    private let price: TextView = TextView()
    private let input: NSTextView = NSTextView()
    
    private var formatterDelegate: CurrencyUITextFieldDelegate?


    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(title)
        addSubview(price)
        title.userInteractionEnabled = false
        title.isSelectable = false
//        input.isEditable = true
//        input.isSelectable = true
        
        
        input.font = .light(.text)
        input.wantsLayer = true
        input.isEditable = true
        input.isSelectable = true
//        input.maximumNumberOfLines = 1
        input.backgroundColor = .clear
        input.drawsBackground = false
        input.alignment = .right
        input.textColor = theme.colors.grayText
//        input.isBezeled = false
//        input.isBordered = false
        input.focusRingType = .none
        addSubview(input)
    }
    
    override var firstResponder: NSResponder? {
        if input.isHidden {
            return nil
        }
        return input
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? PaymentsCheckoutPriceItem else {
            return
        }
        title.setFrameOrigin(NSMakePoint(item.viewType.innerInset.left, item.viewType.innerInset.top))
        price.setFrameOrigin(NSMakePoint(item.blockWidth - item.viewType.innerInset.left - price.frame.width, item.viewType.innerInset.top))
        
        input.frame = containerView.bounds.insetBy(dx: item.viewType.innerInset.right - 5, dy: item.viewType.innerInset.top)
    }
    

    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        
        guard let item = item as? PaymentsCheckoutPriceItem else {
            return
        }
        

        input.isHidden = item.editableTip == nil
                
        self.price.change(opacity: !input.string.isEmpty ? 0 : 1, animated: false)

        if let editableTip = item.editableTip {
                        
            let text: String
            if editableTip.current == 0 {
                text = ""
            } else {
                text = formatCurrencyAmount(editableTip.current, currency: editableTip.currency)
            }

            if input.string != text {
                input.string = text
                self.price.change(opacity: !input.string.isEmpty ? 0 : 1, animated: false)
            }
            
            self.formatterDelegate = CurrencyUITextFieldDelegate(formatter: CurrencyFormatter(currency: editableTip.currency, { formatter in
                formatter.maxValue = currencyToFractionalAmount(value: editableTip.maxValue, currency: editableTip.currency) ?? 10000.0
                formatter.minValue = 0.0
                formatter.hasDecimals = true
            }))
            self.formatterDelegate?.passthroughDelegate = self

            self.formatterDelegate?.textUpdated = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.textDidChange(Notification(name: Notification.Name(""), object: strongSelf.input, userInfo: nil))
            }
            
//            formatterDelegate?.setFormattedText(in: self.input, inputString: "\(editableTip.current)", range: input.selectedRange())
//            self.input.string = formatterDelegate?.formatter.formattedStringWithAdjustedDecimalSeparator(from: "\(editableTip.current)") ?? ""
            
        } else {
            self.formatterDelegate = nil
        }
        
        self.input.delegate = self.formatterDelegate
        
        title.update(item.titleLayout)
        price.update(item.priceLayout)
        
        needsLayout = true
    }
    
    func textDidChange(_ notification: Notification) {
        let text = input.string
        self.price.change(opacity: !text.isEmpty ? 0 : 1, animated: false)

        guard let item = self.item as? PaymentsCheckoutPriceItem else {
            return
        }

        if text.isEmpty {
            item.updateValue(0)
            return
        }
        guard let editableTip = item.editableTip else {
            return
        }
        
        guard let unformatted = self.formatterDelegate?.formatter.unformatted(string: text) else {
            return
        }

        guard let value = Int64(unformatted) else {
            return
        }

        
        item.updateValue(value)
        if value > editableTip.maxValue {
            self.input.string = self.formatterDelegate?.formatter.formattedStringAdjustedToFitAllowedValues(from: "\(editableTip.maxValue)") ?? ""
        }
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
