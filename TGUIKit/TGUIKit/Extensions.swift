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
    
    public func trimRange(_ range:NSRange) -> NSRange {
        let loc:Int = min(range.location,self.length)
        let length:Int = min(range.length, self.length - loc)
        return NSMakeRange(loc, length)
    }
    
    public static func initialize(string:String?, color:NSColor? = nil, font:NSFont? = nil, coreText:Bool = true) -> NSAttributedString {
        let attr:NSMutableAttributedString = NSMutableAttributedString()
        _ = attr.append(string: string, color: color, font: font, coreText: true)
        
        return attr.copy() as! NSAttributedString
    }
    
    
}

public extension String {
    
    
    public static func prettySized(with size:Int) -> String {
        var converted:Double = Double(size)
        var factor:Int = 0
        
        let tokens:[String] = ["Bytes", "KB", "MB", "GB", "TB"]
        
        while converted >= 1024.0 {
            converted /= 1024.0
            factor += 1
        }
        
        if factor == 0 {
            //converted = 0
        }
        //factor = Swift.max(1,factor)
        
        if ceil(converted) - converted != 0.0 {
            return String(format: "%.2f %@", converted, tokens[factor])
        } else {
            return String(format: "%.0f %@", converted, tokens[factor])
        }
        
    }
    
    public var trimmed:String {
        
        var string:String = self
        while !string.isEmpty, let index = string.rangeOfCharacter(from: NSCharacterSet.whitespacesAndNewlines), index.lowerBound == string.startIndex {
            string = String(string[index.upperBound..<string.endIndex])
        }
        while !string.isEmpty, let index = string.rangeOfCharacter(from: NSCharacterSet.whitespacesAndNewlines, options: .literal, range: string.index(string.endIndex, offsetBy: -1) ..< string.endIndex) {
            string = String(string[..<index.lowerBound])
        }
        
        return string
    }
    
    public var fullTrimmed: String {
        var copy: String = self
        var index: String.Index = copy.index(after: copy.startIndex)
        
        var newLineIndexEnd: String.Index? = nil
        
        
        
        while index != copy.endIndex {
            
            if let idx = newLineIndexEnd {
                let substring = copy[index..<copy.index(after: idx)]
                let symbols = substring.filter({$0 != "\n"})
                let newLines = substring.filter({$0 == "\n"})
                if symbols.isEmpty {
                    newLineIndexEnd = copy.index(after: idx)
                } else {
                    if newLines.utf8.count > 2 {
                        copy = String(copy[..<index] + "\n\n" + copy[idx..<copy.endIndex])
                        newLineIndexEnd = nil
                        index = copy.index(after: copy.startIndex)
                    } else {
                        index = copy.index(after: idx)
                        newLineIndexEnd = nil
                    }
                }
            } else {
                let first = String(copy[index..<copy.index(after: index)])
                
                if first == "\n" {
                    newLineIndexEnd = copy.index(after: index)
                } else {
                    index = copy.index(after: index)
                }
            }
            
        }
        return copy
    }

}

public extension NSAttributedStringKey {
    public static var preformattedCode: NSAttributedStringKey {
        return NSAttributedStringKey(rawValue: "TGPreformattedCodeAttributeName")
    }
    public static var preformattedPre: NSAttributedStringKey {
        return NSAttributedStringKey(rawValue: "TGPreformattedPreAttributeName")
    }
    public static var selectedColor: NSAttributedStringKey {
        return NSAttributedStringKey(rawValue: "KSelectedColorAttributeName")
    }
}

public extension NSPasteboard.PasteboardType {
    public static var kUrl:NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(kUTTypeURL as String)
    }
    public static var kFilenames:NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType("NSFilenamesPboardType")
    }
    public static var kFileUrl: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(kUTTypeFileURL as String)
    }
}

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
        
        self.append(NSAttributedString(string: string!))
        let nlength:Int = self.length - slength
        range = NSMakeRange(self.length - nlength, nlength)
        
        if let c = color {
            self.addAttribute(NSAttributedStringKey.foregroundColor, value: c, range:range )
        }
        
        if let f = font {
            if coreText {
                 self.setCTFont(font: f, range: range)
            }
            self.setFont(font: f, range: range)
        }
        
        
        return range
        
    }
    
    public func add(link:Any, for range:NSRange, color: NSColor = presentation.colors.link)  {
        self.addAttribute(NSAttributedStringKey.link, value: link, range: range)
        self.addAttribute(NSAttributedStringKey.foregroundColor, value: color, range: range)
    }
    
    public func setCTFont(font:NSFont, range:NSRange) -> Void {
        self.addAttribute(NSAttributedStringKey(kCTFontAttributeName as String), value: CTFontCreateWithFontDescriptor(font.fontDescriptor, 0, nil), range: range)
    }
    
    public func setSelected(color:NSColor,range:NSRange) -> Void {
        self.addAttribute(.selectedColor, value: color, range: range)
    }

    
    public func setFont(font:NSFont, range:NSRange) -> Void {
        self.addAttribute(NSAttributedStringKey.font, value: font, range: range)
    }
    
}


public extension CALayer {
    
    public func disableActions() -> Void {
        
        self.actions = ["onOrderIn":NSNull(),"sublayers":NSNull(),"bounds":NSNull(),"frame":NSNull(), "background":NSNull(), "position":NSNull(),"contents":NSNull(),"backgroundColor":NSNull(),"border":NSNull(), "shadowOffset": NSNull()]
        removeAllAnimations()
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
        return self as NSString
    }
    
    public var length:Int {
        return self.nsstring.length
    }
}


public extension NSView {
    
    public var snapshot: NSImage {
        guard let bitmapRep = bitmapImageRepForCachingDisplay(in: bounds) else { return NSImage() }
        cacheDisplay(in: bounds, to: bitmapRep)
        let image = NSImage()
        image.addRepresentation(bitmapRep)
        bitmapRep.size = bounds.size
        return NSImage(data: dataWithPDF(inside: bounds))!
    }
    
    public func _mouseInside() -> Bool {
        if let window = self.window {
            var location:NSPoint = window.mouseLocationOutsideOfEventStream
            location = self.convert(location, from: nil)
            
            if let view = window.contentView!.hitTest(window.mouseLocationOutsideOfEventStream) {
                if let view = view as? View {
                    if view.isEventLess {
                        return NSPointInRect(location, self.bounds)
                    }
                }
                if view == self {
                    return NSPointInRect(location, self.bounds)
                } else {
                    var s = view.superview
                    if let view = view as? NSTableView {
                        let somePoint = view.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                        let row = view.row(at: somePoint)
                        if row >= 0 {
                            let someView = view.rowView(atRow: row, makeIfNecessary: false)
                            if let someView = someView {
                                let hit = someView.hitTest(someView.convert(window.mouseLocationOutsideOfEventStream, from: nil))
                                return hit == self
                            }
                        }
                    }
                    while let sv = s {
                        if sv == self {
                            return NSPointInRect(location, self.bounds)
                        }
                        s = sv.superview
                    }
                }
            } else {
                var bp:Int = 0
                bp += 1
            }
            
        }
        return false
    }
    
    public var backingScaleFactor: CGFloat {
        if let window = window {
            return window.backingScaleFactor
        } else {
            return System.backingScale
        }
    }
    
    public func removeAllSubviews() -> Void {
        while (self.subviews.count > 0) {
            self.subviews[0].removeFromSuperview();
        }
    }
    
    public func isInnerView(_ view:NSView?) -> Bool {
        var inner = false
        for i in 0 ..< subviews.count {
            inner = subviews[i] == view
            if !inner && !subviews[i].subviews.isEmpty {
                inner = subviews[i].isInnerView(view)
            }
            if inner {
                break
            }
        }
        return inner
    }
    
    public func setFrameSize(_ width:CGFloat, _ height:CGFloat) {
        self.setFrameSize(NSMakeSize(width, height))
    }
    
    public func setFrameOrigin(_ x:CGFloat, _ y:CGFloat) {
        self.setFrameOrigin(NSMakePoint(x, y))
    }
    
    public var background:NSColor {
        get {
            if let view = self as? View {
                return view.backgroundColor
            }
            if let backgroundColor = layer?.backgroundColor {
                return NSColor(cgColor: backgroundColor) ?? .white
            }
            return .white
        }
        set {
            if let view = self as? View {
                view.backgroundColor = newValue
            } else {
                self.layer?.backgroundColor = newValue.cgColor
            }
        }
    }
    
    public func centerX(_ superView:NSView? = nil, y:CGFloat? = nil, addition: CGFloat = 0) -> Void {
        
        var x:CGFloat = 0
        
        if let sv = superView {
            x = CGFloat(roundf(Float((sv.frame.width - frame.width)/2.0)))
        } else if let sv = self.superview {
            x = CGFloat(roundf(Float((sv.frame.width - frame.width)/2.0)))
        }
        
        self.setFrameOrigin(NSMakePoint(x + addition, y == nil ? NSMinY(self.frame) : y!))
    }
    
    public func focus(_ size:NSSize) -> NSRect {
        var x:CGFloat = 0
        var y:CGFloat = 0
        
        x = CGFloat(roundf(Float((frame.width - size.width)/2.0)))
        y = CGFloat(roundf(Float((frame.height - size.height)/2.0)))

        
        return NSMakeRect(x, y, size.width, size.height)
    }
    
    public func focus(_ size:NSSize, inset:NSEdgeInsets) -> NSRect {
        let x:CGFloat = CGFloat(roundf(Float((frame.width - size.width + (inset.left + inset.right))/2.0)))
        let y:CGFloat = CGFloat(roundf(Float((frame.height - size.height + (inset.top + inset.bottom))/2.0)))
        return NSMakeRect(x, y, size.width, size.height)
    }
    
    public func centerY(_ superView:NSView? = nil, x:CGFloat? = nil, addition: CGFloat = 0) -> Void {
        
        var y:CGFloat = 0
        
        if let sv = superView {
            y = CGFloat(roundf(Float((sv.frame.height - frame.height)/2.0)))
        } else if let sv = self.superview {
            y = CGFloat(roundf(Float((sv.frame.height - frame.height)/2.0)))
        }
        
        self.setFrameOrigin(NSMakePoint(x ?? frame.minX, y + addition))
    }

    
    public func center(_ superView:NSView? = nil) -> Void {
        
        var x:CGFloat = 0
        var y:CGFloat = 0
        
        if let sv = superView {
            x = CGFloat(roundf(Float((sv.frame.width - frame.width)/2.0)))
            y = CGFloat(roundf(Float((sv.frame.height - frame.height)/2.0)))
        } else if let sv = self.superview {
            x = CGFloat(roundf(Float((sv.frame.width - frame.width)/2.0)))
            y = CGFloat(roundf(Float((sv.frame.height - frame.height)/2.0)))
        }
        
        self.setFrameOrigin(NSMakePoint(x, y))
        
    }
    
    
    public func _change(pos position: NSPoint, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: String = kCAMediaTimingFunctionEaseOut, completion:((Bool)->Void)? = nil) -> Void {
        if animated {
            
            var presentX = NSMinX(self.frame)
            var presentY = NSMinY(self.frame)
            let presentation:CALayer? = self.layer?.presentation()
            if let presentation = presentation, self.layer?.animation(forKey:"position") != nil {
                presentY =  presentation.frame.minY
                presentX = presentation.frame.minX
            }
            
            self.layer?.animatePosition(from: NSMakePoint(presentX, presentY), to: position, duration: duration, timingFunction: timingFunction, removeOnCompletion: removeOnCompletion, completion: completion)
        } else {
            self.layer?.removeAnimation(forKey: "position")
        }
        if save {
            self.setFrameOrigin(position)
            if let completion = completion, !animated {
                completion(true)
            }
        }
      
    }
    
    public func shake() {
        let a:CGFloat = 3
        if let layer = layer {
            self.layer?.shake(0.04, from:NSMakePoint(-a + layer.position.x,layer.position.y), to:NSMakePoint(a + layer.position.x, layer.position.y))
        }
        NSSound.beep()
    }
    
    public func _change(size: NSSize, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: String = kCAMediaTimingFunctionEaseOut, completion:((Bool)->Void)? = nil) {
        if animated {
            var presentBounds:NSRect = self.layer?.bounds ?? self.bounds
            let presentation = self.layer?.presentation()
            if let presentation = presentation, self.layer?.animation(forKey:"bounds") != nil {
                presentBounds.size.width = NSWidth(presentation.bounds)
                presentBounds.size.height = NSHeight(presentation.bounds)
            }
            
            self.layer?.animateBounds(from: presentBounds, to: NSMakeRect(0, 0, size.width, size.height), duration: duration, timingFunction: timingFunction, removeOnCompletion: removeOnCompletion, completion: completion)
            
        } else {
            self.layer?.removeAnimation(forKey: "bounds")
        }
        if save {
            self.frame = NSMakeRect(NSMinX(self.frame), NSMinY(self.frame), size.width, size.height)
        }
    }
    
    public func _changeBounds(from: NSRect, to: NSRect, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: String = kCAMediaTimingFunctionEaseOut, completion:((Bool)->Void)? = nil) {
        
        if save {
            self.bounds = to
        }
        
        if animated {
            self.layer?.animateBounds(from: from, to: to, duration: duration, timingFunction: timingFunction, removeOnCompletion: removeOnCompletion, completion: completion)
            
        } else {
            self.layer?.removeAnimation(forKey: "bounds")
        }
        
        if !animated {
            completion?(true)
        }
    }
    
    public func _change(opacity to: CGFloat, animated: Bool = true, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: String = kCAMediaTimingFunctionEaseOut, completion:((Bool)->Void)? = nil) {
        if animated {
            if let layer = self.layer {
                var opacity:CGFloat = CGFloat(layer.opacity)
                if let presentation = self.layer?.presentation(), self.layer?.animation(forKey:"opacity") != nil {
                    opacity = CGFloat(presentation.opacity)
                }
                
                layer.animateAlpha(from: opacity, to: to, duration:duration, timingFunction: timingFunction, removeOnCompletion: removeOnCompletion, completion: completion)
            }
           
            
        } else {
            layer?.removeAnimation(forKey: "opacity")
        }
        if save {
            self.layer?.opacity = Float(to)
            if let completion = completion, !animated {
                completion(true)
            }
        }
    }
    
    public func disableHierarchyInteraction() -> Void {
        for sub in self.subviews {
            if let sub = sub as? Control, sub.interactionStateForRestore == nil {
                sub.interactionStateForRestore = sub.userInteractionEnabled
                sub.userInteractionEnabled = false
            }
            sub.disableHierarchyInteraction()
        }
    }
    
    public func restoreHierarchyInteraction() -> Void {
        for sub in self.subviews {
            if let sub = sub as? Control, let resporeState = sub.interactionStateForRestore {
                sub.userInteractionEnabled = resporeState
                sub.interactionStateForRestore = nil
            }
            sub.restoreHierarchyInteraction()
        }
    }

}




public extension NSTableView.AnimationOptions {
    public static var none: NSTableView.AnimationOptions { get {
            return NSTableView.AnimationOptions(rawValue: 0)
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
    
    func fit(_ maxSize: CGSize) -> CGSize {
        var size = self
        if self.width < 1.0 {
            return CGSize()
        }
        if self.height < 1.0 {
            return CGSize()
        }
    
        if size.width > maxSize.width {
            size.height = floor((size.height * maxSize.width / size.width));
            size.width = maxSize.width;
        }
        if size.height > maxSize.height {
            size.width = floor((size.width * maxSize.height / size.height));
            size.height = maxSize.height;
        }
        return size;
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
    
    func precomposed(_ color:NSColor? = nil, flipVertical:Bool = false, flipHorizontal:Bool = false) -> CGImage {
        
        let drawContext:DrawingContext = DrawingContext(size: self.size, scale: 2.0, clear: true)
        
        let image:NSImage = self
        
        let make:(CGContext) -> Void = { ctx in
            let rect = NSMakeRect(0, 0, drawContext.size.width, drawContext.size.height)
            ctx.interpolationQuality = .high
            ctx.clear(rect)
            
            var imageRect:CGRect = NSMakeRect(0, 0, image.size.width, image.size.height)

            let cimage = image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
            //CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithData(image.tiffRepresentation! as CFData, nil)!, 0, nil)
            
            if let color = color {
                ctx.clip(to: rect, mask: cimage!)
                ctx.setFillColor(color.cgColor)
                ctx.fill(rect)
            } else {
                ctx.draw(cimage!, in: imageRect)
            }

        }
        
        drawContext.withFlippedContext(horizontal: flipHorizontal, vertical: flipVertical, make)
        

        
        
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

public extension CGRect {
    public var topLeft: CGPoint {
        return self.origin
    }
    
    public var topRight: CGPoint {
        return CGPoint(x: self.maxX, y: self.minY)
    }
    
    public var bottomLeft: CGPoint {
        return CGPoint(x: self.minX, y: self.maxY)
    }
    
    public var bottomRight: CGPoint {
        return CGPoint(x: self.maxX, y: self.maxY)
    }
    
    public var center: CGPoint {
        return CGPoint(x: self.midX, y: self.midY)
    }
}

public extension CGPoint {
    public func offsetBy(dx: CGFloat, dy: CGFloat) -> CGPoint {
        return CGPoint(x: self.x + dx, y: self.y + dy)
    }
}

public extension CGImage {
    
    var backingSize:NSSize {
        return NSMakeSize(CGFloat(width) / 2.0, CGFloat(height) / 2.0)
    }
    
    var size:NSSize {
        return NSMakeSize(CGFloat(width), CGFloat(height))
    }
    
    var backingBounds: NSRect {
        return NSMakeRect(0, 0, backingSize.width, backingSize.height)
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
                let unmanagedObject: UnsafeRawPointer = CFArrayGetValueAtIndex(records, i)!
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

public extension NSScrollView {
    var contentOffset: NSPoint {
        return contentView.bounds.origin
    }
}

public extension CGContext {
    public func round(_ size:NSSize,_ corners:CGFloat = .cornerRadius) {
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
    public func indexIn(_ index: Int) -> Bool {
        return NSLocationInRange(index, self)
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


public extension NSEdgeInsets {

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
    
    var hexString: String {
        // Get the red, green, and blue components of the color
        var r :CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        let color = self.usingColorSpaceName(NSColorSpaceName.deviceRGB)!

        
        var rInt, gInt, bInt, aInt: Int
        var rHex, gHex, bHex: String
        
        var hexColor: String
        
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // println("R: \(r) G: \(g) B:\(b) A:\(a)")
        
        // Convert the components to numbers (unsigned decimal integer) between 0 and 255
        rInt = Int(round(r * 255.0))
        gInt = Int(round(g * 255.0))
        bInt = Int(round(b * 255.0))
        
        // Convert the numbers to hex strings
        rHex = rInt == 0 ? "00" : NSString(format:"%2X", rInt) as String
        gHex = gInt == 0 ? "00" : NSString(format:"%2X", gInt) as String
        bHex = bInt == 0 ? "00" : NSString(format:"%2X", bInt) as String
        
        rHex = rHex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        gHex = gHex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        bHex = bHex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        if rHex.length == 1 {
            rHex = "0\(rHex)"
        }
        if gHex.length == 1 {
            gHex = "0\(gHex)"
        }
        if bHex.length == 1 {
            bHex = "0\(bHex)"
        }
        
        hexColor = rHex + gHex + bHex
        if a < 1 {
            return "#" + hexColor + ":\(a * 100 / 100)"
        } else {
            return "#" + hexColor
        }
    }
    
}

public extension Int {
    
    func prettyFormatter(_ n: Int, iteration: Int) -> String {
        let keys = ["K", "M", "B", "T"]
        let d = Double((n / 100)) / 10.0
        let isRound:Bool = (Int(d) * 10) % 10 == 0
        if d < 1000 {
            if d == 1 {
                return "\(Int(d))\(keys[iteration])"
            } else {
                var result = "\((d > 99.9 || isRound || (!isRound && d > 9.99)) ? d * 10 / 10 : d)"
                if result.hasSuffix(".0") {
                    result = result.prefix(result.count - 2)
                }
                return result + "\(keys[iteration])"
            }
        }
        else {
            return self.prettyFormatter(Int(d), iteration: iteration + 1)
        }
    }
    
    public var prettyNumber:String {
        if self < 1000 {
            return "\(self)"
        }
        return self.prettyFormatter(self, iteration: 0)
    }
    public var separatedNumber: String {
        if self < 1000 {
            return "\(self)"
        }
        let string = "\(self)"
        
        let length: Int = string.length
        var result:String = ""
        var index:Int = 0
        while index < length {
            let modulo = length % 3
            if index == 0 && modulo != 0 {
                result = string.nsstring.substring(with: NSMakeRange(index, modulo))
                index += modulo
            } else {
                let count:Int = 3
                let value = string.nsstring.substring(with: NSMakeRange(index, count))
                if index == 0 {
                    result = value
                } else {
                    result += " " + value
                }
                index += count
            }
        }
        return result
    }
}


public extension ProgressIndicator {
    public func set(color:NSColor) {
        let color = color.usingColorSpace(NSColorSpace.sRGB)

        let colorPoly = CIFilter(name: "CIColorPolynomial")
        if let colorPoly = colorPoly, let color = color {
            colorPoly.setDefaults()
            let redVector = CIVector(x: color.redComponent, y: 0, z: 0, w: 0)
            let greenVector = CIVector(x: color.greenComponent, y: 0, z: 0, w: 0)
            let blueVector = CIVector(x: color.blueComponent, y: 0, z: 0, w: 0)
            
            colorPoly.setValue(redVector, forKey: "inputRedCoefficients")
            colorPoly.setValue(greenVector, forKey: "inputGreenCoefficients")
            colorPoly.setValue(blueVector, forKey: "inputBlueCoefficients")
            self.contentFilters = [colorPoly]
        }
    }
}

public extension String {
    public func prefix(_ by:Int) -> String {
        if let index = index(startIndex, offsetBy: by, limitedBy: endIndex) {
            return String(self[..<index])
        }
        return String(stringLiteral: self)
    }
    
    public func prefixWithDots(_ by:Int) -> String {
        if let index = index(startIndex, offsetBy: by, limitedBy: endIndex) {
            var new = String(self[..<index])
            if new.length != self.length {
                new += "..."
                return new
            }
            return new
        }
        return String(stringLiteral: self)
    }
    
    public func fromSuffix(_ by:Int) -> String {
        if let index = index(startIndex, offsetBy: by, limitedBy: endIndex) {
            return String(self[index..<self.endIndex])
        }
        return String(stringLiteral: self)
    }
    
    public static func durationTransformed(elapsed:Int) -> String {
        let h = elapsed / 3600
        let m = (elapsed / 60) % 60
        let s = elapsed % 60
        
        if h > 0 {
            return String.init(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String.init(format: "%02d:%02d", m, s)
        }
    }
    
    
}

public extension NSTextField {
    public func setSelectionRange(_ range: NSRange) {
        textView?.setSelectedRange(range)
    }
    
    public var selectedRange: NSRange {
        if let textView = textView {
            return textView.selectedRange
        }
        return NSMakeRange(0, 0)
    }
    
    public func setCursorToEnd() {
        self.setSelectionRange(NSRange(location: self.stringValue.length, length: 0))
    }
    
    public func setCursorToStart() {
        self.setSelectionRange(NSRange(location: 0, length: 0))
    }
    
    public var textView:NSTextView? {
        let textView = (self.window?.fieldEditor(true, for: self) as? NSTextView)
        textView?.backgroundColor = .clear
        textView?.drawsBackground = true
        return textView
    }
}

public extension NSTextView {
    public func selectAllText() {
        setSelectedRange(NSMakeRange(0, self.string.length))
    }
    
    public func appendText(_ text: String) -> Void {
        let inputText = self.attributedString().mutableCopy() as! NSMutableAttributedString
        
        if selectedRange.upperBound - selectedRange.lowerBound > 0 {
            inputText.replaceCharacters(in: NSMakeRange(selectedRange.lowerBound, selectedRange.upperBound - selectedRange.lowerBound), with: NSAttributedString(string: text))
        } else {
            inputText.insert(NSAttributedString(string: text), at: selectedRange.lowerBound)
        }
        self.string = inputText.string
    }
}


public extension String {
    public var emojiSkinToneModifiers: [String] {
        return [ "🏻", "🏼", "🏽", "🏾", "🏿" ]
    }
    
    public var emojiVisibleLength: Int {
        var count = 0
        enumerateSubstrings(in: startIndex..<endIndex, options: .byComposedCharacterSequences) { _,_,_,_  in
            count += 1
        }
        return count
    }
    
    public var emojiUnmodified: String {
        if self.isEmpty {
            return ""
        }
        return nsstring.substring(to: min(nsstring.length, 2))
    }
    
    public var emojiSkin: String {
        if self.length < 2 {
            return ""
        }
        
        
        let range = Range<String.Index>(uncheckedBounds: (self.index(after: self.startIndex), self.endIndex))
        return String(self[range])
    }
    
    public var canHaveSkinToneModifier: Bool {
        if self.isEmpty {
            return false
        }
        
        let modified = self.emojiUnmodified + self.emojiSkinToneModifiers[0]
        return modified.emojiVisibleLength == 1
    }
    
    public var glyphCount: Int {
        
        let richText = NSAttributedString(string: self)
        let line = CTLineCreateWithAttributedString(richText)
        return CTLineGetGlyphCount(line)
    }
    
    public var isSingleEmoji: Bool {
        return glyphCount == 1 && containsEmoji
    }
    
    public var containsEmoji: Bool {
        
        return !unicodeScalars.filter { $0.isEmoji }.isEmpty
    }
    
    public var containsOnlyEmoji: Bool {
        
        return unicodeScalars.first(where: { !$0.isEmoji && !$0.isZeroWidthJoiner }) == nil
    }
    

    public var emojiString: String {
        
        return emojiScalars.map { String($0) }.reduce("", +)
    }
    
    var emojis: [String] {
        
        var scalars: [[UnicodeScalar]] = []
        var currentScalarSet: [UnicodeScalar] = []
        var previousScalar: UnicodeScalar?
        
        for scalar in emojiScalars {
            
            if let prev = previousScalar, !prev.isZeroWidthJoiner && !scalar.isZeroWidthJoiner {
                
                scalars.append(currentScalarSet)
                currentScalarSet = []
            }
            currentScalarSet.append(scalar)
            
            previousScalar = scalar
        }
        
        scalars.append(currentScalarSet)
        
        return scalars.map { $0.map{ String($0) } .reduce("", +) }
    }
    
    fileprivate var emojiScalars: [UnicodeScalar] {
        
        var chars: [UnicodeScalar] = []
        var previous: UnicodeScalar?
        for cur in unicodeScalars {
            
            if let previous = previous, previous.isZeroWidthJoiner && cur.isEmoji {
                chars.append(previous)
                chars.append(cur)
                
            } else if cur.isEmoji {
                chars.append(cur)
            }
            
            previous = cur
        }
        
        return chars
    }

}

extension UnicodeScalar {
    
    var isEmoji: Bool {
        
        switch value {
        case 0x3030, 0x00AE, 0x00A9,
        0x1D000 ... 0x1F77F,
        0x2100 ... 0x27BF,
        0xFE00 ... 0xFE0F,
        0x1F900 ... 0x1F9FF:
        return true
            
        default: return false
        }
    }
    
    var isZeroWidthJoiner: Bool {
        return value == 8205
    }
}


extension NSResponder {
    @available(OSX 10.12.2, *)
    var touchBar: NSTouchBar? {
        return nil
    }
}

public extension Sequence where Iterator.Element: Hashable {
    var uniqueElements: [Iterator.Element] {
        return Array( Set(self) )
    }
}
public extension Sequence where Iterator.Element: Equatable {
    var uniqueElements: [Iterator.Element] {
        return self.reduce([]){
            uniqueElements, element in
            
            uniqueElements.contains(element)
                ? uniqueElements
                : uniqueElements + [element]
        }
    }
}
