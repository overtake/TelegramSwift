//
//  TouchBarEmojiItemView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14/09/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa

@available(OSX 10.12.2, *)
class TouchBarEmojiItemView: NSScrubberItemView {
    private let textView: NSTextField = NSTextField()
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.backgroundColor = .clear
        textView.font = .normal(30)
    }
    
    func update(_ emoji: String) {
        textView.stringValue = emoji
    }
    
    override func layout() {
        super.layout()
        textView.setFrameSize(38, 40)
        textView.center()
    }
    
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
