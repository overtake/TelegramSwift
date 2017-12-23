//
//  ChatBubbleAccessoryForward.swift
//  Telegram
//
//  Created by keepcoder on 14/12/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class ChatBubbleAccessoryForward: View {

    private let textView: TextView = TextView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.isSelectable = false
        layer?.cornerRadius = .cornerRadius
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateText(layout: TextViewLayout) {
        textView.update(layout)
        self.background = theme.colors.bubbleBackground_incoming
        textView.backgroundColor = theme.colors.bubbleBackground_incoming
        setFrameSize(textView.frame.width + 10, textView.frame.height + 10)
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        textView.center()
    }

    
}
