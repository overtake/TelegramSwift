//
//  DragController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 30/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

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
        _ = attr.append(string: title, color: presentation.colors.grayText, font: .normal(.huge))
        _ = attr.append(string: "\n")
        
        _ = attr.append(string: desc, color: presentation.colors.text, font: .medium(16.0))
        
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
        textView.backgroundColor = presentation.colors.background
        self.layer?.cornerRadius = .cornerRadius
        self.layer?.borderWidth = 2.0
        self.layer?.backgroundColor = presentation.colors.background.cgColor
        self.layer?.borderColor = presentation.colors.border.cgColor
        self.backgroundColor = presentation.colors.background
        self.set(handler: { control in
            control.layer?.borderColor = presentation.colors.blueUI.cgColor
            control.layer?.animateBorder()
        }, for: .Hover)
        
        self.set(handler: { control in
            control.layer?.borderColor = presentation.colors.border.cgColor
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
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

public class DraggingView: SplitView {
    
    var container:View = View()
    
    public weak var controller:ViewController?
    
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
      
        container.backgroundColor = .clear
        self.registerForDraggedTypes([.string, .tiff, .kUrl, .kFilenames])
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
        
        let itemSize = NSMakeSize(frame.width - 10, ceil((frame.height - 10 - (5 * (CGFloat(items.count) - 1))) / CGFloat(items.count)))
        
        var y:CGFloat = 5
        for item in items {
            let view:DragView = DragView(item:item)
            view.frame = NSMakeRect(5, y, itemSize.width, itemSize.height)
            container.addSubview(view)
            y += itemSize.height + 5
            
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
