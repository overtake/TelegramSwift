//
//  TouchBarStickerHeaderItemView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14/09/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

@available(OSX 10.12.2, *)
class TouchBarScrubberHeaderItemView: NSScrubberItemView {
    private let textView: TextView = TextView()
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.backgroundColor = .clear
    }
    
    func update(_ layout: TextViewLayout) {
        textView.update(layout)
    }
    
    override func layout() {
        super.layout()
        textView.centerX()
        textView.centerY(addition: -1)
    }
    
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
