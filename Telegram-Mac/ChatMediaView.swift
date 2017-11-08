//
//  ChatMediaView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
class ChatMediaView: ChatRowView {
    
    var contentNode:ChatMediaContentView?
    
    override var needsDisplay: Bool {
        get {
            return super.needsDisplay
        }
        set {
            super.needsDisplay = true
            contentNode?.needsDisplay = true
        }
    }
    override var backgroundColor: NSColor {
        didSet {
            contentNode?.backgroundColor = backdorColor
        }
    }
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            self.contentNode?.willRemove()
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
    }

    override func set(item:TableRowItem, animated:Bool = false) {
        if let item:ChatMediaItem = item as? ChatMediaItem {
            if contentNode == nil || !contentNode!.isKind(of: item.contentNode())  {
                self.contentNode?.removeFromSuperview()
                let node = item.contentNode()
                self.contentNode = node.init(frame:NSZeroRect)
                self.addSubview(self.contentNode!)
            }
            
            self.contentNode?.update(with: item.media, size: item.contentSize, account: item.account!, parent:item.message, table:item.table, parameters:item.parameters, animated: animated)
        }
        super.set(item: item, animated: animated)
    }
    
    open override func interactionContentView(for innerId: AnyHashable ) -> NSView {
        if let content = self.contentNode?.interactionContentView(for: innerId) {
            return content
        }
       return self
    }
    
    
  
    
}


class ChatMediaGameView: ChatRowView {
    
    var contentNode:ChatMediaContentView?
    private let title:TextView = TextView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        let layout = TextViewLayout(.initialize(string: "supergame", color: .blueUI, font: .normal(.text)))
        layout.measure(width: 1000)
        title.update(layout)
        title.userInteractionEnabled = false
        addSubview(title)
    }
    
 
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
    }
    
    override func layout() {
        super.layout()
        
        if let item = item as? ChatMediaItem {
            title.update(item.gameTitleLayout)
        }
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        if let item:ChatMediaItem = item as? ChatMediaItem {
            if contentNode == nil || !contentNode!.isKind(of: item.contentNode())  {
                self.contentNode?.removeFromSuperview()
                let node = item.contentNode()
                self.contentNode = node.init(frame:NSZeroRect)
                self.addSubview(self.contentNode!)
            }
            self.contentNode?.userInteractionEnabled = false
            self.contentNode?.update(with: item.media, size: NSMakeSize(item.contentSize.width, item.contentSize.height - item.gameTitleLayout!.layoutSize.height - 6), account: item.account!, parent:item.message, table:item.table, parameters:item.parameters)
            
            title.update(item.gameTitleLayout)
            
            self.contentNode?.setFrameOrigin(0, item.gameTitleLayout!.layoutSize.height + 6)
        }
        super.set(item: item, animated: animated)
    }
    
    
    override var backgroundColor: NSColor {
        didSet {
            contentNode?.backgroundColor = backgroundColor
        }
    }
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            self.contentNode?.willRemove()
        }
    }
    
}



