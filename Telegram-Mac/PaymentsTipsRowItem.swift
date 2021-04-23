//
//  PaymentsTipsRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04.04.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import SwiftSignalKit

final class PaymentsTipsRowItem : GeneralRowItem {
    
    struct Tip {
        fileprivate var text: TextViewLayout
        fileprivate var value: Int64
        fileprivate var size: NSSize
    }
    
    fileprivate let tips:BotPaymentInvoice.Tip
    fileprivate let current: Int64?
    fileprivate let currency: String
    private(set) var rendered: [[Tip]] = []
    let layouts: [(TextViewLayout, Int64)]
    let select:(Int64?)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, currency: String, tips: BotPaymentInvoice.Tip, current: Int64?, select: @escaping(Int64?)->Void) {
        self.tips = tips
        self.current = current
        self.currency = currency
        self.select = select
        var layouts:[(TextViewLayout, Int64)] = []
        
        for amount in tips.suggested {
            
            let layout = TextViewLayout(.initialize(string: formatCurrencyAmount(amount, currency: self.currency), color: current == amount ? .white : theme.colors.greenUI, font: .medium(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            layouts.append((layout, amount))
        }
        
        self.layouts = layouts
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
        
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        let width = self.blockWidth - viewType.innerInset.left - viewType.innerInset.right
                
        var rendered:[[Tip]] = []
        
        let insets: NSEdgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        let insetBetween = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        
        
        var row:[Tip] = []
        
        let layoutRow:()->Void = {
            if !row.isEmpty {
                let w = (width - row.reduce(0, { $0 + $1.size.width }) - (insetBetween.right * CGFloat(row.count - 1)))
                
                if w > 0 {
                    let rest = w / CGFloat(row.count)
                    for i in 0 ..< row.count {
                        row[i].size.width += floor(rest)
                    }
                }
                rendered.append(row)
                row.removeAll()
            }
        }

        
        for tip in layouts {
            let minSize = NSMakeSize(tip.0.layoutSize.width + insets.left + insets.right, tip.0.layoutSize.height + insets.bottom + insets.top)
            
            let tip = Tip(text: tip.0, value: tip.1, size: minSize)
            
            var i: Int = 0
            
            row.append(tip)
            
            let row_w: CGFloat = row.reduce(0, { current, value in
                var current = current
                current += tip.size.width + insetBetween.right
                if i == row.count - 1 {
                    current -= insetBetween.right
                }
                i += 1
                return current
            })
            if row_w > width {
                row.removeLast()
                layoutRow()
                row.append(tip)
            }
        }
        layoutRow()
        
        self.rendered = rendered
        
        return true
    }
    
    override var height: CGFloat {
        return rendered.reduce(0, { current, value in
            let height = value.max(by: { $0.size.height < $1.size.height})!.size.height
            if current == viewType.innerInset.top || rendered.count == 1 {
                return current + height
            } else {
                return current + height + viewType.innerInset.top
            }
        })
    }
    
    var frames:[NSRect] {
        var x: CGFloat = viewType.innerInset.left
        var y: CGFloat = 0
        var rects:[NSRect] = []
        for row in rendered {
            for col in row {
                let rect = NSMakeRect(x, y, col.size.width, col.size.height)
                rects.append(rect)
                x += rect.width + 5
            }
            x = viewType.innerInset.left
            y += rects.last!.height + viewType.innerInset.top
        }
        return rects
    }
    
    var count: Int {
        return rendered.reduce(0, { current, value in
            return current + value.count
        })
    }
    
    var list: [Tip] {
        return rendered.reduce([], { current, value in
            return current + value
        })
    }
    
    override var hasBorder: Bool {
        return false
    }
    
    override func viewClass() -> AnyClass {
        return PaymentsTipRowView.self
    }
}

private final class PaymentsTipView : Control {
    private let textView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.cornerRadius = .cornerRadius
        addSubview(textView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
    }
    
    func update(_ text: PaymentsTipsRowItem.Tip, selected: Bool, animated: Bool, select: @escaping(Int64?)->Void) {
        backgroundColor = selected ? theme.colors.greenUI : theme.colors.greenUI.withAlphaComponent(0.4)
        if animated {
            layer?.animateBackground()
        }
        textView.update(text.text)
        
        self.removeAllHandlers()
        self.set(handler: { _ in
            if selected {
                select(nil)
            } else {
                select(text.value)
            }
        }, for: .Click)
        
        textView.center()
    }
    override func layout() {
        super.layout()
        textView.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


private final class PaymentsTipRowView : GeneralContainableRowView {
    private var contentView:[WeakReference<PaymentsTipView>] = []
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? PaymentsTipsRowItem else {
            return
        }
        for (i, frame) in item.frames.enumerated() {
            let view = contentView[i].value
            view?.frame = frame
        }
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PaymentsTipsRowItem else {
            return
        }
        
        while contentView.count > item.count {
            contentView.last?.value?.removeFromSuperview()
            contentView.removeLast()
        }
        while contentView.count < item.count {
            let view = PaymentsTipView(frame: .zero)
            addSubview(view)
            contentView.append(WeakReference(value: view))
        }
        
        for (i, frame) in item.frames.enumerated() {
            let view = contentView[i].value
            view?.frame = frame
            view?.update(item.list[i], selected: item.current == item.list[i].value, animated: animated, select: item.select)
        }
    }
}
