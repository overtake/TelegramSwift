//
//  GeneralTextRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 05/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
class GeneralTextRowItem: GeneralRowItem {

    fileprivate var layout:TextViewLayout
    private let text:NSAttributedString
    private let alignment:NSTextAlignment
    fileprivate let centerViewAlignment: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable = arc4random(), height: CGFloat = 0, text:NSAttributedString, alignment:NSTextAlignment = .left, drawCustomSeparator:Bool = false, border:BorderType = [], inset:NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:2), action: @escaping ()->Void = {}, centerViewAlignment: Bool = false) {
        self.text = text
        self.alignment = alignment
        self.centerViewAlignment = centerViewAlignment
        layout = TextViewLayout(text, truncationType: .end, alignment: alignment)
        layout.interactions = globalLinkExecutor
        super.init(initialSize, height: height, stableId: stableId, type: .none, action: action, drawCustomSeparator: drawCustomSeparator, border: border, inset: inset)
    }
    
    init(_ initialSize: NSSize, stableId: AnyHashable = arc4random(), height: CGFloat = 0, text:String, alignment:NSTextAlignment = .left, drawCustomSeparator:Bool = false, border:BorderType = [], inset:NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:2), centerViewAlignment: Bool = false) {
        let attr = NSAttributedString.initialize(string: text, color: theme.colors.grayText, font: .normal(.custom(11.5))).mutableCopy() as! NSMutableAttributedString
        attr.detectBoldColorInString(with: .medium(.text))
        self.text = attr
        self.alignment = alignment
        self.centerViewAlignment = centerViewAlignment
        layout = TextViewLayout(self.text, truncationType: .end, alignment: alignment)
        layout.interactions = globalLinkExecutor
        super.init(initialSize, height: height, stableId: stableId, type: .none, drawCustomSeparator: drawCustomSeparator, border: border, inset: inset)
    }
    
    override var height: CGFloat {
        if _height > 0 {
            return _height
        }
        return layout.layoutSize.height + inset.top + inset.bottom
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        
        layout.measure(width: width - inset.left - inset.right)

        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return GeneralTextRowView.self
    }
    
}


class GeneralTextRowView : GeneralRowView {
    private let textView:TextView = TextView()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.isSelectable = false
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        if let item = item as? GeneralTextRowItem, item.drawCustomSeparator {
            ctx.setFillColor(theme.colors.border.cgColor)
            ctx.fill(NSMakeRect(item.inset.left, frame.height - .borderSize, frame.width - item.inset.left - item.inset.right, .borderSize))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        textView.backgroundColor = theme.colors.background
        
        needsLayout = true
    }
    
    override func mouseUp(with event: NSEvent) {
        if let item = item as? GeneralTextRowItem, mouseInside() {
           item.action()
        } else {
            super.mouseUp(with: event)
        }
    }
    
    override func layout() {
        super.layout()
        if let item = item as? GeneralTextRowItem {
            textView.update(item.layout, origin:NSMakePoint(item.inset.left, item.inset.top))
            if item.centerViewAlignment {
                textView.center()
            }
        }
    }
}
