//
//  DragController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 30/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

public class DragItem {
    let title:String
    let desc:String
    let handler:()->Void
    
    let attr:NSAttributedString
    
    public init(title:String, desc:String,handler:@escaping()->Void) {
        self.title = title
        self.desc = desc
        self.handler = handler
        
        let attr:NSMutableAttributedString = NSMutableAttributedString()
        attr.append(string: title, color: .grayText, font: .normal(.title))
        attr.append(string: "\n")
        
        attr.append(string: desc, color: .textColor, font: .medium(.header))
        
        self.attr = attr.copy() as! NSAttributedString
    }
}

class DragView : OverlayControl {
    var item:DragItem
   
    var textView:TextView = TextView()
    
    init(item:DragItem) {
        self.item = item
        super.init(frame: NSZeroRect)
        
        addSubview(textView)
        self.layer?.cornerRadius = .cornerRadius
        self.layer?.borderWidth = 2.0
        self.layer?.backgroundColor = NSColor.white.cgColor
        self.layer?.borderColor = NSColor.border.cgColor
        self.backgroundColor = .white
        self.set(handler: { control in
            control.layer?.borderColor = NSColor.blueUI.cgColor
            control.layer?.animateBorder()
        }, for: .Hover)
        
        self.set(handler: { control in
            control.layer?.borderColor = NSColor.border.cgColor
            control.layer?.animateBorder()
        }, for: .Normal)
        
        
    }
    
  
    
    override func layout() {
        super.layout()
        let layout:TextViewLayout = TextViewLayout(item.attr, maximumNumberOfLines: 2, truncationType: .middle, alignment:.center)
        layout.measure(width: frame.width - 20)
        
        textView.update(layout)
        textView.center()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

public class DraggingView: SplitView {
    
    var container:View = View()
    
    public weak var controller:ViewController?
    
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
      
        container.backgroundColor = .clear
        self.register(forDraggedTypes: [NSFilenamesPboardType,NSStringPboardType,NSTIFFPboardType,NSURLPboardType])
    }
    
    override public func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        
        for itemView in container.subviews as! [DragView] {
            if itemView.mouseInside() {
                itemView.item.handler()
                return true
            }
        }
        
        return false
    }
    
    func layoutItems(with items:[DragItem]) {
        container.removeAllSubviews()
        
        let itemSize = NSMakeSize(frame.width - 20.0, ceil((frame.height - 20 - (10 * (CGFloat(items.count) - 1))) / CGFloat(items.count)))
        
        var y:CGFloat = 10.0
        for item in items {
            let view:DragView = DragView(item:item)
            view.frame = NSMakeRect(10, y, itemSize.width, itemSize.height)
            container.addSubview(view)
            y += itemSize.height + 10
            
        }
        
        
    }
    
    override public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        
        if let items = controller?.draggingItems(for: sender.draggingPasteboard()), items.count > 0, !sender.draggingSourceOperationMask().isEmpty {
            
            container.frame = bounds
            
            if container.superview == nil {
                layoutItems(with: items)
                addSubview(container)
            }
            container.layer?.removeAllAnimations()
            container.layer?.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
        }
        
        
       
        return sender.draggingSourceOperationMask()
    }
    
    override public func draggingExited(_ sender: NSDraggingInfo?) {
        container.layer?.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion:false, completion:{[weak self] (completed) in
            if completed {
                self?.container.removeFromSuperview()
            }
        })
    }
    
    public override func draggingEnded(_ sender: NSDraggingInfo?) {
        draggingExited(sender)
    }
    
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
