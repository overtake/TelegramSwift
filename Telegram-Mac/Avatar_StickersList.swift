//
//  Avatar_StickersList.swift
//  Telegram
//
//  Created by Mike Renoir on 22.04.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import AppKit

final class Avatar_StickersList : View {
    private var stickersView: NSView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(view: NSView, context: AccountContext, animated: Bool) {
        self.stickersView = view
        self.addSubview(view)
        
        needsLayout = true
    }
    override func layout() {
        super.layout()
        self.stickersView?.frame = bounds
    }
}



final class Avatar_EmojiList : View {
    private var stickersView: NSView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(view: NSView, context: AccountContext, animated: Bool) {
        self.stickersView = view
        self.addSubview(view)
        
        needsLayout = true
    }
    override func layout() {
        super.layout()
        self.stickersView?.frame = bounds
    }
}
