//
//  SeparatorRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 29/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

enum SeparatorBlockState  {
    case short
    case all
    case none
    case clear
}



class SeparatorRowItem: TableRowItem {
    public var text:NSAttributedString;
    
    private let h:CGFloat
    let rightText:NSAttributedString?
    let border:BorderType
    let state:SeparatorBlockState
    let action: (()->Void)?
    override var height: CGFloat {
        return h
    }
    private let _stableId:AnyHashable
    override var stableId: AnyHashable {
        return _stableId
    }
    
    let backgroundColor: NSColor?
    let leftInset: CGFloat?
    
    init(_ initialSize:NSSize, _ stableId:AnyHashable, string:String, right:String? = nil, state: SeparatorBlockState = .none, height:CGFloat = 20.0, action: (()->Void)? = nil, backgroundColor: NSColor? = nil, leftInset: CGFloat? = nil, border:BorderType = [.Right]) {
        self._stableId = stableId
        self.h = height
        self.backgroundColor = backgroundColor
        self.leftInset = leftInset
        self.action = action
        self.state = state
        self.border = border
        text = .initialize(string: string, color: theme.colors.grayText, font:.normal(.short))
        if let right = right {
            self.rightText = .initialize(string: right, color: theme.colors.grayText, font:.normal(.short))
        } else {
            rightText = nil
        }
        
        
        super.init(initialSize)
    }
    override var instantlyResize: Bool {
        return true
    }
    
    
    override func viewClass() -> AnyClass {
        return SeparatorRowView.self
    }
}


class SeparatorRowView: TableRowView {
    
    private var text:TextNode = TextNode()
    private var stateText:TextNode = TextNode()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }
    
    override var backdorColor: NSColor {
        if let backgroundColor = (item as? SeparatorRowItem)?.backgroundColor {
            return backgroundColor
        }
        return theme.colors.grayBackground
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        guard let item = item as? SeparatorRowItem else {return}
        let point = convert(event.locationInWindow, from: nil)
        
        if let text = item.rightText {
            let (layout, _) = TextNode.layoutText(maybeNode: stateText, text, nil, 1, .end, NSMakeSize(frame.width, frame.height), nil, false, .left)

            let rect = NSMakeRect(frame.width - 10 - layout.size.width, round((frame.height - layout.size.height)/2.0), layout.size.width, frame.height)
            if NSPointInRect(point, rect) {
                if let action = item.action {
                    action()
                } else {
                    super.mouseDown(with: event)
                }
            }
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        
        super.draw(layer, in: ctx)
        
        if backingScaleFactor == 1.0 {
            ctx.setFillColor(backdorColor.cgColor)
            ctx.fill(layer.bounds)
        }
        
        if let item = self.item as? SeparatorRowItem {
            let (layout, apply) = TextNode.layoutText(maybeNode: text, item.text, nil, 1, .end, NSMakeSize(frame.width, frame.height), nil,false, .left)
            let textPoint:NSPoint
            if let text = item.rightText {
                textPoint = NSMakePoint(item.leftInset ?? 10, round((frame.height - layout.size.height)/2.0) - 1)
                let (layout, apply) = TextNode.layoutText(maybeNode: stateText, text, nil, 1, .end, NSMakeSize(frame.width, frame.height), nil, false, .left)
                apply.draw(NSMakeRect(frame.width - 10 - layout.size.width, round((frame.height - layout.size.height)/2.0) - 1, layout.size.width, layout.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                
            } else {
                textPoint = NSMakePoint(item.leftInset ?? 10, round((frame.height - layout.size.height)/2.0) - 1)
                
            }
            apply.draw(NSMakeRect(textPoint.x, textPoint.y, layout.size.width, layout.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
        }
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        super.set(item: item, animated: animated)
        if let item = item as? SeparatorRowItem {
            self.border = item.border
        }
        needsDisplay = true
    }
}

