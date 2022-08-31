//
//  EStickItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
class EStickItem: TableRowItem {
    
    override var height: CGFloat {
        return 30
    }
        
    override var stableId: AnyHashable {
        return _stableId
    }
    private let _stableId: AnyHashable
    
    let layout:(TextNodeLayout, TextNode)
    fileprivate let clearCallback:(()->Void)?
    init(_ initialSize:NSSize, stableId: AnyHashable, segmentName:String, clearCallback:(()->Void)? = nil) {
        self._stableId = stableId
        self.clearCallback = clearCallback
        layout = TextNode.layoutText(maybeNode: nil,  .initialize(string: segmentName.uppercased(), color: theme.colors.grayText, font: .medium(.short)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .left)
        super.init(initialSize)
    }
    
    override func viewClass() -> AnyClass {
        return EStickView.self
    }
}


private class EStickView: TableStickView {
    private var button: ImageButton?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func layout() {
        super.layout()
        if let view = self.button {
            view.centerY(x: frame.width - view.frame.width - 20)
        }
    }

    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? EStickItem else {
            return
        }
        
        if let callback = item.clearCallback {
            let current: ImageButton
            if let view = self.button {
                current = view
            } else {
                current = ImageButton()
                current.autohighlight = false
                current.scaleOnClick = true
                current.set(image: theme.icons.recentDismiss, for: .Normal)
                current.sizeToFit()
                addSubview(current)
                self.button = current
            }
            current.removeAllHandlers()
            current.set(handler: { _ in
                callback()
            }, for: .Click)
        } else if let view = self.button {
            performSubviewRemoval(view, animated: animated)
            self.button = nil
        }
        
        needsDisplay = true
        needsLayout = true
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if header {
            ctx.setFillColor(theme.colors.border.cgColor)
            ctx.fill(NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize))
        }
        
        if let item = item as? EStickItem {
            var f = focus(item.layout.0.size)
            f.origin.x = 20
            f.origin.y -= 1
            item.layout.1.draw(f, in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backdorColor)
        }
    }
    
}
