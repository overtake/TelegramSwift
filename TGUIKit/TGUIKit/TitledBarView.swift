//
//  TitledBarView.swift
//  TGUIKit
//
//  Created by keepcoder on 16/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

private class TitledContainerView : View {
    var titleImage:CGImage? {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    var text:NSAttributedString? {
        didSet {
            if text != oldValue {
                self.setNeedsDisplay()
            }
        }
    }
    
    var status:NSAttributedString? {
        didSet {
            if status != oldValue {
                self.setNeedsDisplay()
            }
        }
    }
    
    var hiddenStatus:Bool = false {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    fileprivate override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if let text = text {
            let (textLayout, textApply) = TextNode.layoutText(nil)(text, nil, 1, .end, NSMakeSize(NSWidth(layer.bounds) - 50, NSHeight(layer.bounds)), nil,false, .left)
            var tY = NSMinY(focus(textLayout.size))
            
            if let status = status {
                
                let (statusLayout, statusApply) = TextNode.layoutText(nil)(status, nil, 1, .end, NSMakeSize(NSWidth(layer.bounds) - 50, NSHeight(layer.bounds)), nil,false, .left)
                
                let t = textLayout.size.height + statusLayout.size.height + 2.0
                tY = (NSHeight(self.frame) - t) / 2.0
                
                let sY = tY + textLayout.size.height + 2.0
                if !hiddenStatus {
                    statusApply().draw(NSMakeRect(floorToScreenPixels((layer.bounds.width - statusLayout.size.width)/2.0), sY, statusLayout.size.width, statusLayout.size.height), in: ctx)
                }
            }
            
            var textRect = NSMakeRect(floorToScreenPixels((layer.bounds.width - textLayout.size.width)/2.0), tY, textLayout.size.width, textLayout.size.height)
            
            if let titleImage = titleImage {
                ctx.draw(titleImage, in: NSMakeRect(textRect.minX - titleImage.backingSize.width, tY + 4, titleImage.backingSize.width, titleImage.backingSize.height))
                textRect.origin.x += floorToScreenPixels(titleImage.backingSize.width/2)
            }
            
            textApply().draw(textRect, in: ctx)
        }
    }
}

open class TitledBarView: BarView {
    
    public var titleImage:CGImage? {
        didSet {
            _containerView.titleImage = titleImage
        }
    }
    
    public var text:NSAttributedString? {
        didSet {
            if text != oldValue {
                _containerView.text = text
            }
        }
    }
    
    public var status:NSAttributedString? {
        didSet {
            if status != oldValue {
                _containerView.status = status
            }
        }
    }
    
    private let _containerView:TitledContainerView = TitledContainerView()
    public var containerView:View {
        return _containerView
    }
    
    public var hiddenStatus:Bool = false {
        didSet {
            _containerView.hiddenStatus = hiddenStatus
        }
    }
    

    
    open override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        containerView.setFrameSize(newSize)
        containerView.setNeedsDisplay()
    }
    public init(_ text:NSAttributedString?, _ status:NSAttributedString? = nil) {
        self.text = text
        self.status = status
        super.init()
        addSubview(containerView)
        _containerView.text = text
        _containerView.status = status
    }
    
    open override func draw(_ dirtyRect: NSRect) {
        
    }
    
    
    public override init() {
        super.init()
        addSubview(containerView)
    }
    
    override required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
