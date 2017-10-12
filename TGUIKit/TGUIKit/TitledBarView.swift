//
//  TitledBarView.swift
//  TGUIKit
//
//  Created by keepcoder on 16/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

private class TitledContainerView : View {
    
    private var statusNode:TextNode = TextNode()
    private var titleNode:TextNode = TextNode()
    var titleImage:CGImage? {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    var inset:CGFloat = 0
    
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
    
    var textInset:CGFloat? = nil {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        backgroundColor = presentation.colors.background
    }
    
    fileprivate override func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.setFillColor(presentation.colors.background.cgColor)
        ctx.fill(bounds)
        if let text = text {
            let (textLayout, textApply) = TextNode.layoutText(maybeNode: titleNode,  text, nil, 1, .end, NSMakeSize(NSWidth(layer.bounds) - inset, NSHeight(layer.bounds)), nil,false, .left)
            var tY = NSMinY(focus(textLayout.size))
            
            if let status = status {
                
                let (statusLayout, statusApply) = TextNode.layoutText(maybeNode: statusNode,  status, nil, 1, .end, NSMakeSize(NSWidth(layer.bounds) - inset, NSHeight(layer.bounds)), nil,false, .left)
                
                let t = textLayout.size.height + statusLayout.size.height + 2.0
                tY = (NSHeight(self.frame) - t) / 2.0
                
                let sY = tY + textLayout.size.height + 2.0
                if !hiddenStatus {
                    statusApply.draw(NSMakeRect(textInset == nil ? floorToScreenPixels((layer.bounds.width - statusLayout.size.width)/2.0) : textInset!, sY, statusLayout.size.width, statusLayout.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
                }
            }
            
            var textRect = NSMakeRect(textInset == nil ? floorToScreenPixels((layer.bounds.width - textLayout.size.width)/2.0) : textInset!, tY, textLayout.size.width, textLayout.size.height)
            
            if let titleImage = titleImage {
                ctx.draw(titleImage, in: NSMakeRect(textInset == nil ? textRect.minX - titleImage.backingSize.width : textInset!, tY + 4, titleImage.backingSize.width, titleImage.backingSize.height))
                textRect.origin.x += floorToScreenPixels(titleImage.backingSize.width) + 4
            }
            
            textApply.draw(textRect, in: ctx, backingScaleFactor: backingScaleFactor)
        }
    }
}

open class TitledBarView: BarView {
    
    public var titleImage:CGImage? {
        didSet {
            _containerView.titleImage = titleImage
        }
    }
    
    open override var backgroundColor: NSColor {
        didSet {
            containerView.backgroundColor = backgroundColor
        }
    }
    
    public var text:NSAttributedString? {
        didSet {
            if text != oldValue {
                _containerView.inset = inset
                _containerView.text = text
            }
        }
    }
    
    public var status:NSAttributedString? {
        didSet {
            if status != oldValue {
                _containerView.inset = inset
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
    
    open var inset:CGFloat {
        return 0
    }

    public var textInset:CGFloat? {
        didSet {
            _containerView.textInset = textInset
        }
    }
    
    open override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        containerView.setFrameSize(newSize)
        containerView.setNeedsDisplay()
    }
    public init(controller: ViewController, _ text:NSAttributedString? = nil, _ status:NSAttributedString? = nil, textInset:CGFloat? = nil) {
        self.text = text
        self.status = status
        self.textInset = textInset
        super.init(controller: controller)
        addSubview(containerView)
        _containerView.text = text
        _containerView.status = status
        _containerView.textInset = textInset
    }
    
    open override func draw(_ dirtyRect: NSRect) {
        
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    

    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
