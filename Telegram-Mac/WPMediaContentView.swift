//
//  WPMediaContentView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 19/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
class WPMediaContentView: WPContentView {
    
    private(set) var contentNode:ChatMediaContentView?
    
    override func draw(_ dirtyRect: NSRect) {
        
        // Drawing code here.
    }
    
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            self.contentNode?.willRemove()
        }
    }

    
    override func update(with layout: WPLayout) {
        super.update(with: layout)
        
        if let layout = layout as? WPMediaLayout {
            if contentNode == nil || !contentNode!.isKind(of: layout.contentNode())  {
                self.contentNode?.removeFromSuperview()
                let node = layout.contentNode()
                self.contentNode = node.init(frame:NSZeroRect)
                self.addSubview(self.contentNode!)
            }
            
            self.contentNode?.update(with: layout.media, size: layout.mediaSize, account: layout.account, parent:layout.parent, table:layout.table, parameters: layout.parameters)
        }
    }
    
    override func layout() {
        super.layout()
        if let content = content as? WPMediaLayout {
            self.contentNode?.setFrameOrigin(NSMakePoint(0, containerView.frame.height - content.mediaSize.height))
        }
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return contentNode?.interactionContentView(for: innerId, animateIn: animateIn) ?? self
    }
    
}
