//
//  Extensions.swift
//  TGUIKit
//
//  Created by keepcoder on 08/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Foundation


public extension NSAttributedString {
    
    func CTSize(_ width:CGFloat, framesetter:CTFramesetter?) -> (CTFramesetter,NSSize) {
        
        var fs = framesetter
        
        if fs == nil {
            fs = CTFramesetterCreateWithAttributedString(self);
        }
        
        var textSize:CGSize  = CTFramesetterSuggestFrameSizeWithConstraints(fs!, CFRangeMake(0,self.length), nil, NSMakeSize(width, CGFloat.greatestFiniteMagnitude), nil);
        
        textSize.width =  ceil(textSize.width)
        textSize.height = ceil(textSize.height)
        
        return (fs!,textSize);

    }
    
    public var range:NSRange {
        return NSMakeRange(0, self.length)
    }
    
 
    
    public static func initialize(string:String?, color:NSColor? = nil, font:NSFont? = nil, coreText:Bool = true) -> NSAttributedString {
        var attr:NSMutableAttributedString = NSMutableAttributedString()
        attr.append(string: string, color: color, font: font, coreText: true)
        
        return attr.copy() as! NSAttributedString
    }
    
    
}

public extension String {
    
    
    public static func prettySized(with size:Int) -> String {
        var converted:Double = Double(size)
        var factor:Int = 0
        
        let tokens:[String] = ["Bytes", "KB", "MB", "GB", "TB"]
        
        while converted > 1024.0 {
            converted /= 1024.0
            factor += 1
        }
        
        if factor == 0 {
            converted = 1.0
        }
        factor = max(1,factor)
        
        if ceil(converted) - converted != 0.0 {
            return String(format: "%.2f %@", converted, tokens[factor])
        } else {
            return String(format: "%.0f %@", converted, tokens[factor])
        }
        
    }

}

public let kSelectedColorAttribute:String = "kFontSelectedColorAttribute"


public struct ParsingType: OptionSet {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public init(_ flags: ParsingType) {
        var rawValue: UInt32 = 0
        
        if flags.contains(ParsingType.Links) {
            rawValue |= ParsingType.Links.rawValue
        }
        
        if flags.contains(ParsingType.Mentions) {
            rawValue |= ParsingType.Mentions.rawValue
        }
        
        if flags.contains(ParsingType.Commands) {
            rawValue |= ParsingType.Commands.rawValue
        }
        
        if flags.contains(ParsingType.Hashtags) {
            rawValue |= ParsingType.Hashtags.rawValue
        }
        
        self.rawValue = rawValue
    }
    
    public static let Links = ParsingType(rawValue: 1)
    public static let Mentions = ParsingType(rawValue: 2)
    public static let Commands = ParsingType(rawValue: 4)
    public static let Hashtags = ParsingType(rawValue: 8)
}

public extension NSMutableAttributedString {
    
    public func append(string:String?, color:NSColor? = nil, font:NSFont? = nil, coreText:Bool = true) -> NSRange {
        
        if(string == nil) {
            return NSMakeRange(0, 0)
        }
        
        let slength:Int = self.length


        var range:NSRange
        
        self.append(NSAttributedString.init(string: string!))
        let nlength:Int = self.length - slength
        range = NSMakeRange(self.length - nlength, nlength)
        
        if let c = color {
            self.addAttribute(NSForegroundColorAttributeName, value: c, range:range )
        }
        
        if let f = font {
            if coreText {
                 self.setCTFont(font: f, range: range)
            } else {
                 self.setFont(font: f, range: range)
            }
        }
        
        
        return range
        
    }
    
    
    
    public func setCTFont(font:NSFont, range:NSRange) -> Void {
        self.addAttribute(kCTFontAttributeName as String, value: CTFontCreateWithFontDescriptor(font.fontDescriptor, 0, nil), range: range)
    }
    
    public func setSelected(color:NSColor,range:NSRange) -> Void {
        self.addAttribute(kSelectedColorAttribute, value: color, range: range)
    }

    
    public func setFont(font:NSFont, range:NSRange) -> Void {
        self.addAttribute(NSFontAttributeName, value: font, range: range)
    }
    
}


public extension CALayer {
    
    public func disableActions() -> Void {
        
        self.actions = ["onOrderIn":NSNull(),"sublayers":NSNull(),"bounds":NSNull(),"frame":NSNull(),"position":NSNull(),"contents":NSNull()]

    }
    
    public func animateBackground() ->Void {
        let animation = CABasicAnimation(keyPath: "backgroundColor")
        animation.duration = 0.2
        self.add(animation, forKey: "backgroundColor")
    }
    
    public func animateBorder() ->Void {
        let animation = CABasicAnimation(keyPath: "borderWidth")
        animation.duration = 0.2
        self.add(animation, forKey: "borderWidth")
    }
    
    public func animateContents() ->Void {
        let animation = CABasicAnimation(keyPath: "contents")
        animation.duration = 0.2
        self.add(animation, forKey: "contents")
    }
    
}

public extension String {
    
    public var nsstring:NSString {
        return self as! NSString
    }
    
    public var length:Int {
        return self.nsstring.length
    }
}

public extension NSView {
    
    public func setFrameSize(_ width:CGFloat, _ height:CGFloat) {
        self.setFrameSize(NSMakeSize(width, height))
    }
    
    public func setFrameOrigin(_ x:CGFloat, _ y:CGFloat) {
        self.setFrameOrigin(NSMakePoint(x, y))
    }
    
    public func centerX(_ superView:NSView? = nil, y:CGFloat? = nil) -> Void {
        
        var x:CGFloat = 0
        
        if let sv = superView {
            x = CGFloat(roundf(Float(NSWidth(sv.frame) - NSWidth(self.frame))/2.0))
        } else if let sv = self.superview {
            x = CGFloat(roundf(Float(NSWidth(sv.frame) - NSWidth(self.frame))/2.0))
        }
        
        self.setFrameOrigin(NSMakePoint(x, y == nil ? NSMinY(self.frame) : y!))
    }
    
    public func focus(_ size:NSSize) -> NSRect {
        var x:CGFloat = 0
        var y:CGFloat = 0
        
        x = CGFloat(roundf(Float(NSWidth(self.frame) - size.width)/2.0))
        y = CGFloat(roundf(Float(NSHeight(self.frame) - size.height)/2.0))

        
        return NSMakeRect(x, y, size.width, size.height)
    }
    
    public func centerY(_ superView:NSView? = nil, x:CGFloat? = nil) -> Void {
        
        var y:CGFloat = 0
        
        if let sv = superView {
            y = CGFloat(roundf(Float(NSHeight(sv.frame) - NSHeight(self.frame))/2.0))
        } else if let sv = self.superview {
            y = CGFloat(roundf(Float(NSHeight(sv.frame) - NSHeight(self.frame))/2.0))
        }
        
        self.setFrameOrigin(NSMakePoint(x ?? frame.minX, y))
    }

    
    public func center(_ superView:NSView? = nil) -> Void {
        
        var x:CGFloat = 0
        var y:CGFloat = 0
        
        if let sv = superView {
            x = CGFloat(roundf(Float(NSWidth(sv.frame) - NSWidth(self.frame))/2.0))
            y = CGFloat(roundf(Float(NSHeight(sv.frame) - NSHeight(self.frame))/2.0))
        } else if let sv = self.superview {
            x = CGFloat(roundf(Float(NSWidth(sv.frame) - NSWidth(self.frame))/2.0))
            y = CGFloat(roundf(Float(NSHeight(sv.frame) - NSHeight(self.frame))/2.0))
        }
        
        self.setFrameOrigin(NSMakePoint(x, y))
        
    }
    
    
    public func change(pos position: NSPoint, animated: Bool, _ save:Bool = true) -> Void {
        if animated {
            
            var presentX = NSMinX(self.frame)
            var presentY = NSMinY(self.frame)
            var presentation:CALayer? = self.layer?.presentation()
            if let presentation = presentation, self.layer?.animation(forKey:"position") != nil {
                presentY =  NSMinY(presentation.frame)
                presentX = NSMinX(presentation.frame)
            }
            
            self.layer?.animatePosition(from: NSMakePoint(presentX, presentY), to: position, duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseOut, removeOnCompletion: true)
        } else {
            self.layer?.removeAnimation(forKey: "position")
        }
        if save {
            self.setFrameOrigin(position)
        }
      
    }
    
    public func change(size size: NSSize, animated: Bool, _ save:Bool = true) {
        if animated {
            var presentBounds:NSRect = self.layer?.bounds ?? self.bounds
            let presentation = self.layer?.presentation()
            if let presentation = presentation, self.layer?.animation(forKey:"bounds") != nil {
                presentBounds.size.width = NSWidth(presentation.bounds)
                presentBounds.size.height = NSHeight(presentation.bounds)
            }
            
            self.layer?.animateBounds(from: presentBounds, to: NSMakeRect(0, 0, size.width, size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseOut)
            
        } else {
            self.layer?.removeAnimation(forKey: "bounds")
        }
        if save {
            self.frame = NSMakeRect(NSMinX(self.frame), NSMinY(self.frame), size.width, size.height)
        }
    }
    

    public func change(opacity to: CGFloat, animated: Bool, _ save:Bool = true) {
        if animated {
            if let layer = self.layer {
                var opacity:CGFloat = CGFloat(layer.opacity) ?? 0.0
                if let presentation = self.layer?.presentation(), self.layer?.animation(forKey:"opacity") != nil {
                    opacity = CGFloat(presentation.opacity)
                }
                
                layer.animateAlpha(from: opacity, to: to, duration:0.2)
            }
           
            
        } else {
            layer?.removeAnimation(forKey: "opacity")
        }
        if save {
            self.layer?.opacity = Float(to)
        }
    }

}


public extension NSTableViewAnimationOptions {
    public static var none: NSTableViewAnimationOptions { get {
            return NSTableViewAnimationOptions(rawValue:0)
        }
    }

}

public extension CGSize {
    public func fitted(_ size: CGSize) -> CGSize {
        var fittedSize = self
        if fittedSize.width > size.width {
            fittedSize = CGSize(width: size.width, height: floor((fittedSize.height * size.width / max(fittedSize.width, 1.0))))
        }
        if fittedSize.height > size.height {
            fittedSize = CGSize(width: floor((fittedSize.width * size.height / max(fittedSize.height, 1.0))), height: size.height)
        }
        return fittedSize
    }
    
    public func fittedToArea(_ area: CGFloat) -> CGSize {
        if self.height < 1.0 || self.width < 1.0 {
            return CGSize()
        }
        let aspect = self.width / self.height
        let height = sqrt(area / aspect)
        let width = aspect * height
        return CGSize(width: floor(width), height: floor(height))
    }
    
    public func aspectFilled(_ size: CGSize) -> CGSize {
        let scale = max(size.width / max(1.0, self.width), size.height / max(1.0, self.height))
        return CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
    }
    
    public func aspectFitted(_ size: CGSize) -> CGSize {
        let scale = min(size.width / max(1.0, self.width), size.height / max(1.0, self.height))
        return CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
    }
    
    public func multipliedByScreenScale() -> CGSize {
        let scale:CGFloat = 2.0
        return CGSize(width: self.width * scale, height: self.height * scale)
    }
    
    public func dividedByScreenScale() -> CGSize {
        let scale:CGFloat = 2.0
        return CGSize(width: self.width / scale, height: self.height / scale)
    }
}

public extension NSImage {
    
    func precomposed(_ color:NSColor? = nil, reversed:Bool = false) -> CGImage {
        
        let drawContext:DrawingContext = DrawingContext.init(size: self.size, scale: 2.0, clear: true)
        
        let image:NSImage = self
        
        let make:(CGContext) -> Void = { (ctx) in
            let rect = NSMakeRect(0, 0, drawContext.size.width, drawContext.size.height)
            
            let cimage = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithData(image.tiffRepresentation! as CFData, nil)!, 0, nil)
            ctx.clip(to: rect, mask: cimage!)
            
            if let color = color {
                ctx.setFillColor(color.cgColor)
                ctx.fill(rect)
            } else {
                ctx.draw(cimage!, in: rect)
            }

        }
        
        if reversed {
            drawContext.withFlippedContext(make)
        } else {
            drawContext.withContext(make)
        }
        
        
        
        return drawContext.generateImage()!
        
//        var image:NSImage = self.copy() as! NSImage
//        if let color = color {
//            image.lockFocus()
//            color.set()
//            var imageRect = NSMakeRect(0, 0, image.size.width * 2.0, image.size.height * 2.0)
//            NSRectFillUsingOperation(imageRect, NSCompositeSourceAtop)
//            image.unlockFocus()
//        }

    //    return roundImage(image.tiffRepresentation!, self.size, cornerRadius: 0, reversed:reversed)!
    }
    
}

public extension CGImage {
    
    var backingSize:NSSize {
        return NSMakeSize(CGFloat(width) / 2.0, CGFloat(height) / 2.0)
    }
    
    var size:NSSize {
        return NSMakeSize(CGFloat(width), CGFloat(height))
    }
    
    var scale:CGFloat {
        return 2.0
    }
    
}

extension Array {
    static func fromCFArray(records : CFArray?) -> Array<Element>? {
        var result: [Element]?
        if let records = records {
            for i in 0..<CFArrayGetCount(records) {
                let unmanagedObject: UnsafeRawPointer = CFArrayGetValueAtIndex(records, i) as! UnsafeRawPointer
                let rec: Element = unsafeBitCast(unmanagedObject, to: Element.self)
                if (result == nil){
                    result = [Element]()
                }
                result!.append(rec)
            }
        }
        return result
    }
}

public extension CGContext {
    public func round(_ size:NSSize,_ corners:CGFloat = 4) {
        let minx:CGFloat = 0, midx = size.width/2.0, maxx = size.width
        let miny:CGFloat = 0, midy = size.height/2.0, maxy = size.height
        
        self.move(to: NSMakePoint(minx, midy))
        self.addArc(tangent1End: NSMakePoint(minx, miny), tangent2End: NSMakePoint(midx, miny), radius: corners)
        self.addArc(tangent1End: NSMakePoint(maxx, miny), tangent2End: NSMakePoint(maxx, midy), radius: corners)
        self.addArc(tangent1End: NSMakePoint(maxx, maxy), tangent2End: NSMakePoint(midx, maxy), radius: corners)
        self.addArc(tangent1End: NSMakePoint(minx, maxy), tangent2End: NSMakePoint(minx, midy), radius: corners)
        
        self.closePath()
        self.clip()

    }
}

public extension NSRange {
    public var min:Int {
        return self.location
    }
    public var max:Int {
        return self.location + self.length
    }
}

public extension NSBezierPath {
    public var cgPath:CGPath? {
        if self.elementCount == 0 {
            return nil
        }
        
        let path = CGMutablePath()
        var didClosePath = false
        
        for i in 0 ..< self.elementCount {
            var points = [NSPoint](repeating: NSZeroPoint, count: 3)
            
            switch self.element(at: i, associatedPoints: &points) {
            case .moveToBezierPathElement:
                path.move(to: points[0])
            case .lineToBezierPathElement:
                path.addLine(to: points[0])
                didClosePath = false
            case .curveToBezierPathElement:
                path.addCurve(to: points[0], control1: points[1], control2: points[2])
                didClosePath = false
            case .closePathBezierPathElement:
                path.closeSubpath()
                didClosePath = true;
            }
        }
        
        if !didClosePath {
            path.closeSubpath()
        }
        
        return path
    }
}


public extension EdgeInsets {

    public init(left:CGFloat = 0, right:CGFloat = 0, top:CGFloat = 0, bottom:CGFloat = 0) {
        self.left = left
        self.right = right
        self.top = top
        self.bottom = bottom
    }
}

public extension NSColor {
    public convenience init(_ rgbValue:UInt32, _ alpha:CGFloat = 1.0) {
        self.init(deviceRed: ((CGFloat)((rgbValue & 0xFF0000) >> 16))/255.0, green: ((CGFloat)((rgbValue & 0xFF00) >> 8))/255.0, blue: ((CGFloat)(rgbValue & 0xFF))/255.0, alpha: alpha)
    }
}
