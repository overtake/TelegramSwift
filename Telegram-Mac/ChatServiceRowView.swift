//
//  ChatServiceRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 06/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
class ChatServiceRowView: TableRowView {
    
    private var textView:TextView
    private var imageView:TransformImageView?
    required init(frame frameRect: NSRect) {
        textView = TextView()
        textView.isSelectable = false
        super.init(frame: frameRect)
        addSubview(textView)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        if let item = item as? ChatServiceItem {
            textView.update(item.text)
            textView.centerX(y:6)
            if let imageArguments = item.imageArguments {
                imageView?.setFrameSize(imageArguments.imageSize)
                imageView?.centerX(y:textView.frame.maxY + 6)
                self.imageView?.set(arguments: imageArguments)
            }
            
        }
    }
    
    override func doubleClick(in location: NSPoint) {
        if let item = self.item as? ChatRowItem, item.chatInteraction.presentation.state == .normal {
            if self.hitTest(location) == nil || self.hitTest(location) == self {
                item.chatInteraction.setupReplyMessage(item.message?.id)
            }
        }
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated:animated)
        
        if let item = item as? ChatServiceItem {
            if let image = item.image {
                if imageView == nil {
                    self.imageView = TransformImageView()
                    self.addSubview(imageView!)
                }
                imageView?.setSignal( chatMessagePhoto(account: item.account, photo: image, toRepresentationSize:NSMakeSize(100,100), scale: backingScaleFactor))
            } else {
                imageView?.removeFromSuperview()
                imageView = nil
            }
            textView.backgroundColor = backdorColor
            self.needsLayout = true
        }
    }
    
}
