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

    override func draw(_ layer: CALayer, in ctx: CGContext) {

        ctx.round(frame.size, frame.height / 2)

        ctx.setFillColor(NSColor.blackTransparent.cgColor)
        ctx.fill(bounds)
        
        if let text = text {
            text.1.draw(focus(text.0.size), in: ctx, backingScaleFactor: backingScaleFactor)
        }
    }
    
    func updateText(_ text: String, maxWidth: CGFloat) -> Void {
        let updatedText = TextNode.layoutText(maybeNode: textNode, .initialize(string: text, color: .white, font: .normal(.custom(11))), nil, 1, .end, NSMakeSize(maxWidth, 20), nil, false, .left)
        self.text = updatedText
        setFrameSize(NSMakeSize(updatedText.0.size.width + 12, updatedText.0.size.height + 4))
        needsDisplay = true
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
