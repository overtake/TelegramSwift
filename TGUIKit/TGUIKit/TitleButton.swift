//
//  TitleButton.swift
//  TGUIKit
//
//  Created by keepcoder on 05/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public enum TitleButtonImageDirection {
    case left
    case right
}

class TextLayerExt: CATextLayer {
    
    override func draw(in ctx: CGContext) {
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.setShouldSmoothFonts(false)
        ctx.setAllowsFontSmoothing(false)
        super.draw(in: ctx)
    }
    
}


public class TitleButton: ImageButton {

    private var text:TextLayerExt = TextLayerExt()
    
    private var stateText:[ControlState:String] = [:]
    private var stateColor:[ControlState:NSColor] = [:]
    private var stateFont:[ControlState:NSFont] = [:]
    
    public var direction: TitleButtonImageDirection = .left {
        didSet {
            if direction != oldValue {
                updateLayout()
            }
        }
    }
    
    public override init() {
        super.init()
    }
    
    public func set(text:String, for state:ControlState) -> Void {
        stateText[state] = text
        apply(state: self.controlState)
        _ = sizeToFit(NSZeroSize, self.frame.size, thatFit: _thatFit)

    }
    
    public func set(color:NSColor, for state:ControlState) -> Void {
        stateColor[state] = color
        apply(state: self.controlState)
    }
    
    public func set(font:NSFont, for state:ControlState) -> Void {
        stateFont[state] = font
        apply(state: self.controlState)
    }
    
    override public func apply(state: ControlState) {
        let state:ControlState = self.isSelected ? .Highlight : state
        super.apply(state: state)
        
        if let stateText = stateText[state] {
            text.string = stateText
        } else {
            text.string = stateText[.Normal]
        }
        
        if isEnabled {
            if let stateColor = stateColor[state] {
                text.foregroundColor = stateColor.cgColor
            } else if let stateColor = stateColor[.Normal] {
                text.foregroundColor = stateColor.cgColor
            } else {
                text.foregroundColor = style.foregroundColor.cgColor
            }
        } else {
            text.foregroundColor = presentation.colors.grayText.cgColor
        }
        
        
        if let stateFont = stateFont[state] {
            text.font = stateFont.fontName as CFTypeRef
            text.fontSize = stateFont.pointSize
        } else if let stateFont = stateFont[.Normal] {
            text.font = stateFont.fontName as CFTypeRef
            text.fontSize = stateFont.pointSize
        } else {
            text.font = style.font.fontName as CFTypeRef
            text.fontSize = style.font.pointSize
        }
        
    }
    
    public override func sizeToFit(_ addition: NSSize = NSZeroSize, _ maxSize:NSSize = NSZeroSize, thatFit:Bool = false) -> Bool {
        _ = super.sizeToFit(addition, maxSize, thatFit: thatFit)
        
        
        let size:NSSize = self.size(with: self.text.string as! String?, font:NSFont(name: self.text.font as! String, size: text.fontSize))
        
        var msize:NSSize = size
        
        if maxSize.width < size.width {
            if let image = imageView.image {
                msize.width += (image.backingSize.width + 12) // max size
            }
        }
       
        var maxWidth:CGFloat = !thatFit ? ( maxSize.width > 0 ? maxSize.width : msize.width ) : maxSize.width

        
        
        var textSize:CGFloat = maxWidth
        
        if let image = imageView.image {
            
            textSize = min(maxWidth,size.width)
            let iwidth:CGFloat = (image.backingSize.width + 12)
            
            if textSize == maxWidth {
                textSize -= iwidth
            } else {
                textSize = (maxWidth - size.width) >= iwidth ? size.width : maxWidth - iwidth
                maxWidth = textSize + iwidth
            }
        } else {
            maxWidth = min(size.width, textSize)
            textSize =  min(size.width, textSize)
        }
       
        if thatFit {
            maxWidth = maxSize.width
        } else {
            maxWidth += addition.width
        }


        self.text.frame = NSMakeRect(0, 0, textSize, size.height)
        
        
        self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: maxWidth, height: max(size.height,maxSize.height) + addition.height)
        return frame.width >= maxWidth
    }
    
    public override func updateLayout() {
        super.updateLayout()
        
        let textFocus:NSRect = focus(self.text.frame.size)
        if let _ = imageView.image {
            let imageFocus:NSRect = focus(self.imageView.frame.size)
            switch direction {
            case .left:
                self.imageView.frame = NSMakeRect(round((self.frame.width - textFocus.width - imageFocus.width)/2.0 - 6.0), imageFocus.minY, imageFocus.width, imageFocus.height)
                self.text.frame = NSMakeRect(imageView.frame.maxX + 6.0, textFocus.minY, textFocus.width, textFocus.height)
            case .right:
                self.imageView.frame = NSMakeRect(round(frame.width - imageFocus.width - 6.0), imageFocus.minY, imageFocus.width, imageFocus.height)
                self.text.frame = NSMakeRect(0, textFocus.minY, textFocus.width, textFocus.height)
            }
            
        } else {
            self.text.frame = textFocus
        }
       
    }
    
    
     func size(with string: String?, font: NSFont?) -> NSSize {
        if font == nil || string == nil {
            return NSZeroSize
        }
        let attributedString:NSAttributedString = NSAttributedString.initialize(string: string, font: font, coreText: true)
        var size:NSSize = attributedString.CTSize(CGFloat.greatestFiniteMagnitude, framesetter: nil).1
        size.width = ceil(size.width) + 10
        size.height = ceil(size.height)
        return size
    }
    

    public override var style: ControlStyle {
        set {
            super.style = newValue
//            
//            self.set(color: style.foregroundColor, for: .Normal)
//            self.set(color: style.highlightColor, for: .Highlight)
//            self.set(font: style.font, for: .Normal)
//            self.backgroundColor = style.backgroundColor
        }
        get {
            return super.style
        }
    }
    
    override func prepare() {
        super.prepare()
        text.truncationMode = "end";
        text.alignmentMode = "center";
        self.layer?.addSublayer(text)
        
        text.actions = ["bounds":NSNull(),"position":NSNull()]
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        disableActions()
    }
    
    public override var backgroundColor: NSColor {
        set {
            super.backgroundColor = newValue
            self.text.backgroundColor = newValue.cgColor
        }
        get {
            return super.backgroundColor
        }
    }
    
    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        if let screen = NSScreen.main {
            self.text.contentsScale = screen.backingScaleFactor
        }
        
    }
    
    public override func disableActions() {
        super.disableActions()
        
        self.text.disableActions()
        self.layer?.disableActions()
    }
    
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
