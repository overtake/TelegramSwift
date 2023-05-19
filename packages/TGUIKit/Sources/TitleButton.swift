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
    case top
}

public class TextLayerExt: CATextLayer {
    
    public override func draw(in ctx: CGContext) {
        ctx.setAllowsFontSubpixelPositioning(true)
        ctx.setShouldSubpixelPositionFonts(true)
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.setAllowsFontSmoothing(System.backingScale == 1.0)
        ctx.setShouldSmoothFonts(System.backingScale == 1.0)
        
        super.draw(in: ctx)
    }
    
}


open class TitleButton: ImageButton {

    private var text:TextLayerExt = TextLayerExt()
    
    private var stateText:[ControlState:String] = [:]
    private var stateColor:[ControlState:NSColor] = [:]
    private var stateFont:[ControlState:NSFont] = [:]
    
    private var currentTextSize: NSSize?
    
    public var autoSizeToFit: Bool = true
    
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
        if autoSizeToFit {
            _ = sizeToFit(NSZeroSize, self.frame.size, thatFit: _thatFit)
        }

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
        
        text.backgroundColor = .clear
        
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
    
    public var isEmpty: Bool {
        if let string = text.string as? String {
            return string.isEmpty
        } else {
            return true
        }
    }
    
    @discardableResult public override func sizeToFit(_ addition: NSSize = NSZeroSize, _ maxSize:NSSize = NSZeroSize, thatFit:Bool = false) -> Bool {
        _ = super.sizeToFit(addition, maxSize, thatFit: thatFit)
        
        var font:NSFont?
        if let fontName = self.text.font as? String {
            font = NSFont(name: fontName, size: text.fontSize)
        } else if let _font = self.text.font as? NSFont {
            font = NSFont(name: _font.fontName, size: text.fontSize)
        }
        font = font ?? .normal(text.fontSize)
        let size:NSSize = TitleButton.size(with: self.text.string as! String?, font: font)
        self.currentTextSize = size
        var msize:NSSize = size
        
        if maxSize.width < size.width {
            if let image = imageView.image, direction != .top {
                msize.width += (image.backingSize.width + (12)) // max size
            }
        }
       
        var maxWidth:CGFloat = !thatFit || maxSize.width == 0 ? ( maxSize.width > 0 ? maxSize.width : msize.width ) : maxSize.width

        
        
        var textSize:CGFloat = maxWidth
        
        if let image = imageView.image, direction != .top {
            
            textSize = min(maxWidth,size.width)
            let iwidth:CGFloat = (image.backingSize.width + (12))
            
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
       
        if thatFit && maxSize.width > 0 {
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
        
        var textFocus:NSRect = focus(currentTextSize ?? self.text.frame.size)
//        textFocus.origin.y -= 1
        if let _ = imageView.image {
            if let string = self.text.string as? String, !string.isEmpty {
                let imageFocus:NSRect = focus(self.imageView.frame.size)
                switch direction {
                case .left:
                    self.imageView.frame = NSMakeRect(round((self.frame.width - textFocus.width - imageFocus.width)/2.0 - 4), imageFocus.minY, imageFocus.width, imageFocus.height)
                    self.text.frame = NSMakeRect(imageView.frame.maxX + 4, textFocus.minY, textFocus.width, textFocus.height)
                case .right:
                    self.imageView.frame = NSMakeRect(round(frame.width - imageFocus.width - 4), imageFocus.minY, imageFocus.width, imageFocus.height)
                    self.text.frame = NSMakeRect(0, textFocus.minY, textFocus.width, textFocus.height)
                case .top:
                    self.imageView.frame = NSMakeRect(imageFocus.minX, imageFocus.minY - textFocus.height / 2 - 2, imageFocus.width, imageFocus.height)
                    self.text.frame = NSMakeRect(textFocus.minX, self.imageView.frame.maxY, textFocus.width, textFocus.height)
                }
            } else {
                self.imageView.center()
            }
            
            
        } else {
            self.text.frame = textFocus
        }
       
    }
    
    
     public static func size(with string: String?, font: NSFont?) -> NSSize {
         guard let font = font, let string = string else {
             return .zero
         }
         let attributedString:NSAttributedString = NSAttributedString.initialize(string: string, font: font, coreText: true)
        let layout = TextViewLayout(attributedString)
        layout.measure(width: .greatestFiniteMagnitude)
        var size:NSSize = layout.layoutSize
        size.width = ceil(size.width) + (size.width == 0 ? 0 : 10)
        size.height = ceil(size.height)
        return size
    }
    

    public override var style: ControlStyle {
        set {
            super.style = newValue
            apply(state: self.controlState)
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
        text.truncationMode = .end;
        text.alignmentMode = .center;
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
    
    public var textSize: NSSize {
        return self.text.frame.size
    }
    
}
