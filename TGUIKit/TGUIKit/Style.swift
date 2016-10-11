//
//  Style.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public struct ControlStyle: Equatable {
    public var font:NSFont = systemFont(TGFont.textSize)
    public var foregroundColor:NSColor = TGColor.textColor
    public var backgroundColor:NSColor = TGColor.clear
    public var highlightColor:NSColor = NSColor.textColor
    
    public func highlight(image:CGImage) -> CGImage {
        
        var img:NSImage = NSImage.init(cgImage: image, size: image.size)
        img.lockFocus()
        highlightColor.set()
        var imageRect = NSMakeRect(0, 0, image.size.width , image.size.height)
        NSRectFillUsingOperation(imageRect, NSCompositeSourceAtop)
        img.unlockFocus()
        
        return roundImage(img.tiffRepresentation!, image.backingSize, cornerRadius: 0)!

//        
//        let context = DrawingContext(size:image.backingSize, scale:2.0)
//        
//        context.withContext { (ctx) in
//            let imageRect = NSMakeRect(0, 0, image.backingSize.width, image.backingSize.height)
//            ctx.setFillColor(backgroundColor.cgColor)
//            ctx.fill(imageRect)
//
//            
//            ctx.clip(to: imageRect, mask: image)
//            ctx.setFillColor(highlightColor.cgColor)
//            ctx.fill(imageRect)
//        }
        
//        let img = context.generateImage() ?? image
//        
//
//        
//        return img
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
        if let highlightColor = highlightColor {
            self.highlightColor = highlightColor
        }
    }
 
    
    public func text(_ text:String, forState state:ControlState) -> NSAttributedString {
        return NSAttributedString.initialize(string: text, color: state == .Normal ? foregroundColor : highlightColor, font: font, coreText: true)
    }
    
}


public let navigationButtonStyle = ControlStyle(font:systemMediumFont(TGFont.titleSize), foregroundColor:TGColor.link, highlightColor:TGColor.textColor)

public let headerTextStyle = ControlStyle(font:systemFont(TGFont.headerSize), highlightColor:TGColor.white)
public let titleTextStyle = ControlStyle(font:systemFont(TGFont.titleSize), highlightColor:TGColor.white)
public let textStyle = ControlStyle(font:systemFont(TGFont.textSize), highlightColor:TGColor.white)
public let shortTextStyle = ControlStyle(font:systemFont(TGFont.shortSize), highlightColor:TGColor.white)

public let headerTextGrayStyle = ControlStyle(font:systemFont(TGFont.headerSize), foregroundColor:TGColor.grayText, highlightColor:TGColor.white)
public let titleTextGrayStyle = ControlStyle(font:systemFont(TGFont.titleSize), foregroundColor:TGColor.grayText, highlightColor:TGColor.white)
public let textGrayStyle = ControlStyle(font:systemFont(TGFont.textSize), foregroundColor:TGColor.grayText, highlightColor:TGColor.white)
public let shortGrayStyle = ControlStyle(font:systemFont(TGFont.shortSize), foregroundColor:TGColor.grayText, highlightColor:TGColor.white)

public func ==(lhs:ControlStyle, rhs:ControlStyle) -> Bool {
    return lhs.font == rhs.font && lhs.foregroundColor == rhs.foregroundColor && rhs.backgroundColor == lhs.backgroundColor
}
