//
//  ChatNavigateFailed.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20.12.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox


class ChatNavigateFailed: ImageButton {
    
    private let context:AccountContext
    init(_ context: AccountContext) {
        self.context = context
        super.init()
        autohighlight = false
        set(image: theme.icons.chat_failed_scroller, for: .Normal)
        set(image: theme.icons.chat_failed_scroller_active, for: .Highlight)
        self.setFrameSize(60,60)
        
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 5
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.1)
        shadow.shadowOffset = NSMakeSize(0, 2)
        self.shadow = shadow
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        set(image: theme.icons.chat_failed_scroller, for: .Normal)
        set(image: theme.icons.chat_failed_scroller_active, for: .Highlight)
    }
    
    func updateCount(_ count: Int) {
        //needsLayout = true
    }
    
    override func scrollWheel(with event: NSEvent) {
        
    }
    
    override func layout() {
        super.layout()
    }
    
    deinit {
       
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
}
