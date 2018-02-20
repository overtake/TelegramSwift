//
//  ChatMessageAccessoryView.swift
//  Telegram
//
//  Created by keepcoder on 05/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


class ChatMessageAccessoryView: View {

    private var text:(TextNodeLayout, TextNode)?
    private var textNode:TextNode?
    private var maxWidth: CGFloat = 0
    private var stringValue: String = ""
    var isUnread: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    override func draw(_ layer: CALayer, in ctx: CGContext) {

        ctx.round(frame.size, frame.height / 2)

        ctx.setFillColor(NSColor.blackTransparent.cgColor)
        ctx.fill(bounds)
        
        if let text = text {
            var rect = focus(text.0.size)
            rect.origin.x = 6
            text.1.draw(rect, in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
            
            if isUnread {
                ctx.setFillColor(.white)
                ctx.fillEllipse(in: NSMakeRect(rect.maxX + 3, floorToScreenPixels(scaleFactor: backingScaleFactor, (frame.height - 5)/2), 5, 5))
            }
        }
        
    }
    
    func updateText(_ text: String, maxWidth: CGFloat) -> Void {
        let updatedText = TextNode.layoutText(maybeNode: textNode, .initialize(string: text, color: .white, font: .normal(11.0)), nil, 1, .end, NSMakeSize(maxWidth, 20), nil, false, .left)
        self.text = updatedText
        self.stringValue = text
        self.maxWidth = maxWidth
        setFrameSize(NSMakeSize(updatedText.0.size.width + 12 + (isUnread ? 8 : 0), updatedText.0.size.height + 4))
        needsDisplay = true
    }
    
    override func copy() -> Any {
        let view = ChatMessageAccessoryView(frame: frame)
        view.updateText(self.stringValue, maxWidth: self.maxWidth)
        return view
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
