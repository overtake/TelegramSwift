//
//  Style.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public struct ControlStyle: Equatable {
    public var font:NSFont = .normal(.text)
    public var foregroundColor:NSColor = .text
    public var backgroundColor:NSColor = .clear
    
    private var _highlightColor: NSColor?
    
    public var highlightColor:NSColor {
        return _highlightColor ?? presentation.colors.blueUI
    }
    
    public func highlight(image:CGImage) -> CGImage {
        
        let context = DrawingContext(size:image.backingSize, scale:2.0, clear:true)
        
        context.withContext { ctx in
            ctx.clear(NSMakeRect(0, 0, image.backingSize.width, image.backingSize.height))
            let imageRect = NSMakeRect(0, 0, image.backingSize.width, image.backingSize.height)
            ctx.setFillColor(backgroundColor.cgColor)
            ctx.fill(imageRect)
            
            
            ctx.clip(to: imageRect, mask: image)
            ctx.setFillColor(highlightColor.cgColor)
            ctx.fill(imageRect)
        }
        
        return context.generateImage() ?? image
        
    }
    
    public init(font:NSFont? = nil, foregroundColor:NSColor? = nil,backgroundColor:NSColor? = nil, highlightColor:NSColor? = nil) {
        
        if let font = font {
            self.font = font
        }
        if let foregroundColor = foregroundColor {
            self.foregroundColor = foregroundColor
        }
        if let backgroundColor = backgroundColor {
            self.backgroundColor = backgroundColor
        }
        _highlightColor = highlightColor
    }
 
    
    public func text(_ text:String, forState state:ControlState) -> NSAttributedString {
        return NSAttributedString.initialize(string: text, color: state == .Normal ? foregroundColor : highlightColor, font: font, coreText: true)
    }
    
}




public func ==(lhs:ControlStyle, rhs:ControlStyle) -> Bool {
    return lhs.font == rhs.font && lhs.foregroundColor == rhs.foregroundColor && rhs.backgroundColor == lhs.backgroundColor
}
