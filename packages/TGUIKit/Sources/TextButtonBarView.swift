//
//  TextButtonBarView.swift
//  TGUIKit
//
//  Created by keepcoder on 05/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public enum TextBarAligment {
    case Left
    case Right
    case Center
}

open class TextButtonBarView: BarView {

    private let button:TitleButton = TitleButton()
    private let progressIndicator: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 25, 25))
    public var alignment:TextBarAligment = .Center
    private var _isFitted: Bool
    private let canBeEmpty: Bool
    public init(controller: ViewController, text:String, style:ControlStyle = navigationButtonStyle, alignment:TextBarAligment = .Center, canBeEmpty: Bool = false) {
    
        self.canBeEmpty = canBeEmpty
        
        button.userInteractionEnabled = false
        button.set(font: navigationButtonStyle.font, for: .Normal)
        button.set(color: navigationButtonStyle.foregroundColor, for: .Normal)
        button.set(text: text, for: .Normal)
        button.disableActions()
        
        
        
        _isFitted = false
        super.init(controller: controller)
        
        self.alignment = alignment
        button.style = style

        progressIndicator.isHidden = true
        
        self.addSubview(button)
        self.addSubview(progressIndicator)
        
    }
    
    public var direction: TitleButtonImageDirection = .left {
        didSet {
            button.direction = direction
        }
    }
    
    public func set(image:CGImage, for state:ControlState) -> Void {
        button.set(image: image, for: state)
        _isFitted = false
        (superview as? NavigationBarView)?.viewFrameChanged(Notification(name: NSView.frameDidChangeNotification))
    }
    
    public func set(color:NSColor, for state:ControlState) -> Void {
        button.set(color: color, for: state)
    }
    
    public func set(font:NSFont, for state:ControlState) -> Void {
        button.set(font: font, for: state)
        _isFitted = false
        (superview as? NavigationBarView)?.viewFrameChanged(Notification(name: NSView.frameDidChangeNotification))
    }
    
    public func set(text:String, for state:ControlState) -> Void {
        button.set(text: text, for: state)
        _isFitted = false
        (superview as? NavigationBarView)?.viewFrameChanged(Notification(name: NSView.frameDidChangeNotification))
    }
    
    public func removeImage(for state:ControlState) {
        button.removeImage(for: state)
    }
    
    override var isFitted: Bool {
        return _isFitted
    }
    
    
    
    override func fit(to maxWidth: CGFloat) -> CGFloat {
        if button.isEmpty && canBeEmpty {
            _isFitted = true
            return self.minWidth
        } else {
            var width: CGFloat = 20
            switch alignment {
            case .Center:
                _isFitted = button.sizeToFit(NSZeroSize,NSMakeSize(maxWidth, frame.height), thatFit: false)
                width += button.frame.width + 16
            //button.center()
            case .Left:
                _isFitted = button.sizeToFit(NSZeroSize,NSMakeSize(maxWidth, frame.height))
                 width += button.frame.width
            case .Right:
                _isFitted = button.sizeToFit(NSZeroSize,NSMakeSize(maxWidth - 20, frame.height), thatFit: false)
                width += max(button.frame.width + 16, minWidth)
                let f = focus(button.frame.size)
                button.setFrameOrigin(NSMakePoint(frame.width - button.frame.width - 16, f.minY))
            }
            return width
        }
        
        
    }
    public override var style: ControlStyle {
        didSet {
            //button.set(color: style.foregroundColor, for: .Normal)

            button.set(font: style.font, for: .Normal)
            button.style = style
        }
    }
    
    open override var isEnabled: Bool {
        didSet {
            button.isEnabled = isEnabled
        }
    }
    
    
    open var isLoading: Bool = false {
        didSet {
            button.isHidden = isLoading
            progressIndicator.isHidden = !isLoading
            needsLayout = true
        }
    }
    
    override open func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        button.set(color: navigationButtonStyle.foregroundColor, for: .Normal)
        button.set(background: presentation.colors.background, for: .Normal)
    }
    
    open override func layout() {
        super.layout()
        if button.isEmpty && canBeEmpty {
            button.frame = bounds
            button.updateLayout()
        } else {
            switch alignment {
            case .Center:
                button.center()
                progressIndicator.center()
            case .Left:
                let f = focus(button.frame.size)
                button.setFrameOrigin(16, floorToScreenPixels(backingScaleFactor, f.minY))
                progressIndicator.center()
            case .Right:
                let f = focus(button.frame.size)
                button.setFrameOrigin(NSMakePoint(frame.width - button.frame.width - 16, floorToScreenPixels(backingScaleFactor, f.minY)))
                progressIndicator.center()
            }
        }
       
    }
    
    
    
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
}
