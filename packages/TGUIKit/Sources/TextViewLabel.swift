//
//  TextViewLabel.swift
//  TGUIKit
//
//  Created by keepcoder on 20/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public protocol TextDelegate: AnyObject {
    
}

private final class DrawLayer: SimpleLayer {
    
    var text:(TextNodeLayout,TextNode)? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    override init() {
        super.init()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(in ctx: CGContext) {
        super.draw(in: ctx)
        if let text = text {
            let focus = frame.size.bounds.focus(text.0.size)
            text.1.draw(focus, in: ctx, backingScaleFactor: contentsScale, backgroundColor: .clear)
        }
    }
}

open class TextViewLabel: View {
    
    private var node:TextNode = TextNode()
    
    var text:(TextNodeLayout,TextNode)? {
        didSet {
            self.drawLayer.text = text
        }
    }
    
    public weak var delegate:TextDelegate?
    
    var needSizeToFit:Bool = false
    public var linesCount:Int = 1
    public var autosize:Bool = false
    public var inset:NSEdgeInsets = NSEdgeInsets()
    public var alignment: NSTextAlignment = .left
    public var attributedString:NSAttributedString? {
        didSet {
            self.update(attr: self.attributedString, size: NSMakeSize(frame.width, frame.height))
        }
    }
    
    private let drawLayer: DrawLayer = DrawLayer()

    
    public func sizeToFit() -> Void {
        self.update(attr: self.attributedString, size: NSMakeSize(CGFloat.greatestFiniteMagnitude,  CGFloat.greatestFiniteMagnitude))
        if let text = text {
            self.frame = NSMakeRect(frame.minX, frame.minY, text.0.size.width + 4, text.0.size.height)
        }
        
    }
    
    public func sizeTo() -> Void {
        if let text = text {
            self.frame = NSMakeRect(NSMinX(self.bounds), NSMinY(self.bounds), text.0.size.width, text.0.size.height)
        }
    }
    
    func update(attr:NSAttributedString?, size:NSSize) -> Void {
        if let attr = attr {
            text = TextNode.layoutText(maybeNode: nil, attr, nil, linesCount, .end, size, nil,false, alignment)
        } else {
            text = nil
        }
        self.setNeedsDisplay()
    }
    
    open override func layout() {
        super.layout()
        drawLayer.frame = bounds
        if autosize {
            text = TextNode.layoutText(maybeNode: node, attributedString, nil, linesCount, .end, NSMakeSize(frame.width - inset.left - inset.right, frame.height), nil,false, alignment)
        }
    }

    
    override open var frame: CGRect {
        get {
            return super.frame
        } set(value) {
            let redraw = value.size != self.frame.size
            super.frame = value
            if redraw {
                let attr = attributedString
                attributedString = attr
            }
            needsDisplay = true
        }
    }
    
    
    open override func mouseDown(with event: NSEvent) {
        
    }
    
    public override init() {
        super.init()
        self.layer?.addSublayer(drawLayer)
    }
    
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer?.addSublayer(drawLayer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
