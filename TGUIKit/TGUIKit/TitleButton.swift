//
//  TitleButton.swift
//  TGUIKit
//
//  Created by keepcoder on 05/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

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
    
    public override init() {
        super.init()
    }
    
    public func set(text:String, for state:ControlState) -> Void {
        stateText[state] = text
        apply(state: self.controlState)
        sizeToFit(NSZeroSize, self.frame.size)
    }
    
    public func set(color:NSColor, for state:ControlState) -> Void {
        stateColor[state] = color
        apply(state: self.controlState)
    }
    
    public func set(font:NSFont, for state:ControlState) -> Void {
        stateFont[state] = font
        apply(state: self.controlState)
    }
    
    override func apply(state: ControlState) {
        super.apply(state: state)
        
        if let stateText = stateText[state] {
            text.string = stateText
        } else {
            text.string = stateText[.Normal]
        }
        
        if let stateColor = stateColor[state] {
            text.foregroundColor = stateColor.cgColor
        } else if let stateColor = stateColor[.Normal] {
            text.foregroundColor = stateColor.cgColor
        } else {
            text.foregroundColor = style.foregroundColor.cgColor
        }
        
        if let stateFont = stateFont[state] {
            text.font = stateFont.fontName as! CFTypeRef
            text.fontSize = stateFont.pointSize
        } else if let stateFont = stateFont[.Normal] {
            text.font = stateFont.fontName as! CFTypeRef
            text.fontSize = stateFont.pointSize
        } else {
            text.font = style.font.fontName as! CFTypeRef
            text.fontSize = style.font.pointSize
        }
        
    }
    
    public override func sizeToFit(_ addition: NSSize = NSZeroSize, _ maxSize:NSSize = NSZeroSize, thatFit:Bool = false) {
        super.sizeToFit(addition)
        
        
        let size:NSSize = self.size(with: self.text.string as! String?, font:NSFont(name: self.text.font as! String, size: text.fontSize))
        
        var msize:NSSize = size
        
        if maxSize.width < size.width {
            if let image = imageView.image {
                msize.width += (image.backingSize.width + 12) // max size
            }
        }
       
        var maxWidth:CGFloat = maxSize.width > 0 ? maxSize.width : msize.width

        var textSize:CGFloat = maxWidth
        
        if let image = imageView.image {
            
            textSize = min(maxWidth,size.width)
            
            let iwidth:CGFloat = (image.backingSize.width + 12)
            
            if textSize == maxWidth {
                textSize -= iwidth
            } else {
                textSize = (maxWidth - size.width) >= iwidth ? size.width : maxWidth - iwidth
            }
        }
       
        self.text.frame = NSMakeRect(0, 0, textSize, size.height)
        
        self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: maxWidth, height: max(size.height,maxSize.height))

    }
    
    public override func updateLayout() {
        super.updateLayout()
        
        var textFocus:NSRect = focus(self.text.frame.size)
        if let image = imageView.image {
            var imageFocus:NSRect = focus(self.imageView.frame.size)
            
            self.text.frame = NSMakeRect(round((self.frame.width - textFocus.width - imageFocus.width)/2.0 + 6.0), textFocus.minY, textFocus.width, textFocus.height)
            self.imageView.frame = NSMakeRect(round((self.frame.width - textFocus.width - imageFocus.width)/2.0 - 6.0), imageFocus.minY, imageFocus.width, imageFocus.height)
        } else {
            self.text.frame = textFocus
        }
       
    }
    
    
     func size(with string: String?, font: NSFont?) -> NSSize {
        if font == nil || string == nil {
            return NSZeroSize
        }
        var attributedString:NSAttributedString = NSAttributedString.initialize(string: string, font: font, coreText: true)
        var size:NSSize = attributedString.CTSize(CGFloat.greatestFiniteMagnitude, framesetter: nil).1
        size.width = ceil(size.width) + 4
        size.height = ceil(size.height)
        return size
    }
    

    public override var style: ControlStyle {
        set {
            super.style = newValue
            
            self.set(color: style.foregroundColor, for: .Normal)
            self.set(color: style.highlightColor, for: .Highlight)
            self.set(font: style.font, for: .Normal)

        }
        get {
            return super.style
        }
    }
    
    override func prepare() {
        super.prepare()
        text.truncationMode = "middle";
        text.alignmentMode = "center";
        self.layer?.addSublayer(text)
       // text.actions = ["bounds":NSNull(),"position":NSNull()]
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
       
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
        if let screen = NSScreen.main() {
            self.text.contentsScale = screen.backingScaleFactor
        }
        
    }
    
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
