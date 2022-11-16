//
//  TitledBarView.swift
//  TGUIKit
//
//  Created by keepcoder on 16/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

private class TitledContainerView : View {
    
    private var statusNode:(TextNodeLayout, TextNode)?
    private var titleNode:(TextNodeLayout, TextNode)?
    var titleImage:(CGImage, TitleBarImageSide)? {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    var inset:()->CGFloat = { 0 }
    
    var text:NSAttributedString? {
        didSet {
            if text != oldValue {
                self.updateLayouts()
                self.setNeedsDisplay()
            }
        }
    }
    
    var status:NSAttributedString? {
        didSet {
            if status != oldValue {
                self.updateLayouts()
            }
        }
    }
    
    func updateLayouts() {
        var additionalInset: CGFloat = 0
        if let (image,_) = titleImage {
            additionalInset += image.backingSize.width + 5
        }
                
        self.titleNode = TextNode.layoutText(maybeNode: nil,  text, nil, 1, .end, NSMakeSize(frame.width - inset() - additionalInset, frame.height), nil,false, .left)

        self.statusNode = TextNode.layoutText(maybeNode: nil,  status, nil, 1, .end, NSMakeSize(frame.width - inset() - additionalInset, frame.height), nil,false, .left)
        self.setNeedsDisplay()
    }
    
    var hiddenStatus:Bool = false {
        didSet {
            updateLayouts()
        }
    }
    
    var textInset:CGFloat? = nil {
        didSet {
            updateLayouts()
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        backgroundColor = presentation.colors.background
    }
    
    var titleRect: NSRect? {
        if let textLayout = self.titleNode?.0, let superview = superview {
            
            var tY = focus(textLayout.size).minY
            
            if let statusLayout = self.statusNode?.0 {
                let t = textLayout.size.height + statusLayout.size.height + 2.0
                tY = floorToScreenPixels(backingScaleFactor, (frame.height - t) / 2.0)
            }
            
            let point = convert( NSMakePoint(floorToScreenPixels(backingScaleFactor, (superview.frame.width - textLayout.size.width)/2.0), tY), from: superview)
            var textRect = NSMakeRect(min(max(textInset == nil ? point.x : textInset!, 0), frame.width - textLayout.size.width), point.y, textLayout.size.width, textLayout.size.height)
            
            if let (titleImage, side) = titleImage {
                switch side {
                case .left:
                    textRect.origin.x += floorToScreenPixels(backingScaleFactor, titleImage.backingSize.width) + 4
                default:
                    break
                }
            }
            return textRect
        }
        return nil
    }
    
    override func layout() {
        super.layout()
        self.updateLayouts()
    }
    
    fileprivate override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        if let (textLayout, textApply) = titleNode, let superview = superview?.superview {
                        
            var additionalInset: CGFloat = 0
            if let (image,_) = titleImage {
                additionalInset += image.backingSize.width + 5
            }
            
            var tY = focus(textLayout.size).minY
            
            if let (statusLayout, statusApply) = statusNode {
                
                
                let t = textLayout.size.height + statusLayout.size.height + 2.0
                tY = floorToScreenPixels(backingScaleFactor, (frame.height - t) / 2.0)
                
                let sY = tY + textLayout.size.height + 2.0
                if !hiddenStatus {
                    let point = convert( NSMakePoint(floorToScreenPixels(backingScaleFactor, (superview.frame.width - statusLayout.size.width)/2.0), tY), from: superview)
                    
                    statusApply.draw(NSMakeRect(textInset == nil ? point.x : textInset!, sY, statusLayout.size.width, statusLayout.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
                }
            }
            
            let point = convert( NSMakePoint(floorToScreenPixels(backingScaleFactor, (superview.frame.width - textLayout.size.width)/2.0), tY), from: superview)
            var textRect = NSMakeRect(min(max(textInset == nil ? point.x : textInset!, 0), frame.width - textLayout.size.width), point.y, textLayout.size.width, textLayout.size.height)
            
            if let (titleImage, side) = titleImage {
                switch side {
                case let .left(topInset):
                    ctx.draw(titleImage, in: NSMakeRect(textInset == nil ? textRect.minX - titleImage.backingSize.width : textInset!, tY + 4 + topInset, titleImage.backingSize.width, titleImage.backingSize.height))
                    textRect.origin.x += floorToScreenPixels(backingScaleFactor, titleImage.backingSize.width) + 4
                case let .right(topInset):
                    ctx.draw(titleImage, in: NSMakeRect(textRect.maxX + 3, tY + 1 + topInset, titleImage.backingSize.width, titleImage.backingSize.height))
                }
            }
            
            textApply.draw(textRect, in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
        }
    }
}

public enum TitleBarImageSide {
    case left(topInset: CGFloat)
    case right(topInset: CGFloat)
}

open class TitledBarView: BarView {
    
    public var titleImage:(CGImage, TitleBarImageSide)? {
        didSet {
            _containerView.titleImage = titleImage
        }
    }
    
    open override var backgroundColor: NSColor {
        didSet {
            containerView.backgroundColor = .clear
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
    
    open var inset:CGFloat {
        return 0
    }

    public var textInset:CGFloat? {
        didSet {
            _containerView.textInset = textInset
        }
    }
    public var titleRect: NSRect? {
        return _containerView.titleRect
    }
    
    open override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        containerView.setFrameSize(newSize)
        _containerView.updateLayouts()
    }
    open func update() {
        
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
        
        _containerView.inset = { [weak self] in
            return self?.inset ?? 50
        }
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
