//
//  ChatHoleRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 13/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac

class ChatHoleRowItem: ChatRowItem {

    override var canBeAnchor: Bool {
        return false
    }

    override var height: CGFloat {
        return 0
    }
    
    override open var animatable:Bool {
        return false
    }
    
    override init(_ initialSize:NSSize, _ chatInteraction:ChatInteraction, _ account:Account, _ entry:ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings) {
        super.init(initialSize, chatInteraction, entry, downloadSettings)
    }
    
    
    override func viewClass() -> AnyClass {
        return ChatHoleRowView.self
    }
}


class ChatHoleRowView: TableRowView {
    
   // private let progress: ProgressIndicator = ProgressIndicator()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
      //  addSubview(progress)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
      //  progress.center()
    }
    
}
