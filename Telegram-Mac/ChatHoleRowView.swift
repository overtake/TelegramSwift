//
//  ChatHoleRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 13/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
class ChatHoleRowView: TableRowView {
    
    private let progress: ProgressIndicator = ProgressIndicator()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(progress)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        progress.center()
    }
    
}
