//
//  GeneralRowView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
class GeneralRowView: TableRowView,ViewDisplayDelegate {
    

     private var errorTextView: TextView? = nil
    
    var general:GeneralRowItem? {
        return self.item as? GeneralRowItem
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        if let item = item as? GeneralRowItem {
            self.border = item.border
            
            if let errorLayout = item.errorLayout {
                if errorTextView == nil {
                    errorTextView = TextView()
                    errorTextView?.isSelectable = false
                    addSubview(errorTextView!)
                }
                errorTextView!.update(errorLayout)
                errorTextView!.change(pos: NSMakePoint(item.inset.left, frame.height - 6 - errorTextView!.frame.height), animated: animated)

            } else {
                errorTextView?.removeFromSuperview()
                errorTextView = nil
            }
        }
        self.needsDisplay = true
        self.needsLayout = true
    }

    override func draw(_ layer: CALayer, in ctx: CGContext) {
        if backingScaleFactor == 1.0 {
            ctx.setFillColor(backdorColor.cgColor)
            ctx.fill(layer.bounds)
        }
        super.draw(layer, in: ctx)
    }
    


    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        
     //   let inset = general?.inset ?? NSEdgeInsets()
      //  overlay.frame = NSMakeRect(inset.left, 0, newSize.width - (inset.left + inset.right), newSize.height)
    }
    
    override func layout() {
        
        guard let item = item as? GeneralRowItem else {return}

        
        if let errorTextView = errorTextView {
            errorTextView.setFrameOrigin(item.inset.left, frame.height - 6 - errorTextView.frame.height)
        }
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? GeneralRowItem else {return theme.colors.background}
        return item.backgroundColor//theme.colors.background
    }
    
}
