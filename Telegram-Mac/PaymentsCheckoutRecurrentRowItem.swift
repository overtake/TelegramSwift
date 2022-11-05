//
//  PaymentsCheckoutRecurrentRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 31.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class PaymentsCheckoutRecurrentRowItem : GeneralRowItem {
    let accept: Bool
    let termsUrl: String
    let botName: String
    let layout: TextViewLayout
    let toggle: ()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, termsUrl: String, botName: String, accept: Bool, toggle:@escaping()->Void) {
        self.accept = accept
        self.termsUrl = termsUrl
        self.toggle = toggle
        self.botName = botName
        
        let attr = parseMarkdownIntoAttributedString(strings().paymentsRecurrentAccept(botName), attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.link), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, contents)
        })).mutableCopy() as! NSMutableAttributedString
        
        attr.detectBoldColorInString(with: .medium(.text))

        self.layout = .init(attr)
        
        self.layout.interactions = .init(processURL: { _ in
            execute(inapp: inApp(for: termsUrl.nsstring))
        })
        
        super.init(initialSize, stableId: stableId, viewType: .singleItem)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.layout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right - 30)
        
        return true
    }
    
    override var height: CGFloat {
        return viewType.innerInset.top + max(20, layout.layoutSize.height) + viewType.innerInset.bottom
    }
    
    override func viewClass() -> AnyClass {
        return PaymentsCheckoutRecurrentRowView.self
    }
}


private final class PaymentsCheckoutRecurrentRowView : GeneralContainableRowView {
    private var checkBox: ImageView?
    private let textView = TextView()
    private let control = Control()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(control)
        
        textView.isSelectable = false
        
        control.set(handler: { [weak self] _ in
            guard let item = self?.item as? PaymentsCheckoutRecurrentRowItem else {
                return
            }
            item.toggle()
        }, for: .Click)
    }
    
    override func shakeView() {
        checkBox?.shake()
        textView.shake(beep: true)
    }
    
    private var accepted: Bool? = nil
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PaymentsCheckoutRecurrentRowItem else {
            return
        }
        
        textView.update(item.layout)
        
        if accepted != item.accept {
            let view = ImageView()
            view.image = item.accept ? theme.chat_toggle_selected : theme.chat_toggle_unselected
            view.sizeToFit()
            addSubview(view, positioned: .below, relativeTo: self.control)
            if let view = self.checkBox {
                performSubviewRemoval(view, animated: animated, scale: true)
            }
            self.checkBox = view
            view.centerY(x: item.viewType.innerInset.left)
            if animated {
                view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                view.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
            }

        }
        self.accepted = item.accept
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? PaymentsCheckoutRecurrentRowItem else {
            return
        }
        
        checkBox?.centerY(x: item.viewType.innerInset.left)
        textView.centerY(x: 30 + item.viewType.innerInset.left)
        control.frame = NSMakeRect(0, 0, textView.frame.minX, containerView.frame.height)
    }
    

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
