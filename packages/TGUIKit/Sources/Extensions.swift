//
//  Extensions.swift
//  TGUIKit
//
//  Created by keepcoder on 08/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Foundation
import CoreText
import AppKit
import ObjcUtils

public typealias UIImage = NSImage

public extension NSAttributedString {
    
    func sizeFittingWidth(_ w: CGFloat) -> CGSize {
        let textStorage = NSTextStorage(attributedString: self)
        let size = CGSize(width: w, height: CGFloat.greatestFiniteMagnitude)
        let boundingRect = CGRect(origin: .zero, size: size)

        let textContainer = NSTextContainer(size: size)
//        textContainer.lineFragmentPadding = 0

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        textStorage.addLayoutManager(layoutManager)

        layoutManager.glyphRange(forBoundingRect: boundingRect, in: textContainer)

        let rect = layoutManager.usedRect(for: textContainer)

        return rect.size
    }
    
    
    func containsAttribute(attributeName: NSAttributedString.Key) -> Any? {
        let range = NSRange(location: 0, length: self.length)
        
        var containsAttribute: Any? = nil
        
        self.enumerateAttribute(attributeName, in: range, options: []) { (value, _, _) in
            if value != nil {
                containsAttribute = value
            }
        }
        
        return containsAttribute
    }
    
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
    
    var trimmed: NSAttributedString {
        
        let string:NSMutableAttributedString = self.mutableCopy() as! NSMutableAttributedString
        
        while true {
            let range = string.string.nsstring.range(of: "\u{2028}")
            if range.location != NSNotFound {
                string.replaceCharacters(in: range, with: "\n")
            } else {
                break
            }
        }
        while true {
            let range = string.string.nsstring.range(of: "\u{fffc}", options: .literal)
            if range.location != NSNotFound {
                string.replaceCharacters(in: range, with: "\n")
            } else {
                break
            }
        }
        var range = string.string.nsstring.rangeOfCharacter(from: NSCharacterSet.whitespacesAndNewlines)
        while !string.string.isEmpty, range.location == 0 {
            string.replaceCharacters(in: NSMakeRange(0, 1), with: "")
            range = string.string.nsstring.rangeOfCharacter(from: NSCharacterSet.whitespacesAndNewlines)
        }
        while !string.string.isEmpty, string.string.rangeOfCharacter(from: NSCharacterSet.whitespacesAndNewlines, options: [], range: string.string.index(string.string.endIndex, offsetBy: -1) ..< string.string.endIndex) != nil {
            string.replaceCharacters(in: NSMakeRange(string.string.length - 1, 1), with: "")
        }
        
        return string
    }
    
    var trimNewLines: NSAttributedString {
        
        let string:NSMutableAttributedString = self.mutableCopy() as! NSMutableAttributedString
        
       
        var range = string.string.nsstring.rangeOfCharacter(from: NSCharacterSet.newlines)
        while !string.string.isEmpty, range.location == 0 {
            string.replaceCharacters(in: NSMakeRange(0, 1), with: "")
            range = string.string.nsstring.rangeOfCharacter(from: NSCharacterSet.newlines)
        }
        while !string.string.isEmpty, string.string.rangeOfCharacter(from: NSCharacterSet.newlines, options: [], range: string.string.index(string.string.endIndex, offsetBy: -1) ..< string.string.endIndex) != nil {
            string.replaceCharacters(in: NSMakeRange(string.string.length - 1, 1), with: "")
        }
        
        return string
    }
    var trimNewLinesToSpace: NSAttributedString {
        return replaceNewlinesWithSpaces(in: self)
    }
    
    func replaceNewlinesWithSpaces(in attributedString: NSAttributedString) -> NSAttributedString {
        // Create a mutable copy of the input attributed string
        let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
        
        // Replace all occurrences of newline characters with space characters
        let range = NSRange(location: 0, length: mutableAttributedString.length)
        let newlineRegex = try! NSRegularExpression(pattern: "\\n")
        newlineRegex.replaceMatches(in: mutableAttributedString.mutableString, options: [], range: range, withTemplate: " ")
        
        // Return the modified attributed string
        return mutableAttributedString
    }
    
    var range:NSRange {
        return NSMakeRange(0, self.length)
    }
    
    func trimRange(_ range:NSRange) -> NSRange {
        let loc:Int = min(range.location,self.length)
        let length:Int = min(range.length, self.length - loc)
        return NSMakeRange(loc, length)
    }
    
    static func initialize(string:String?, color:NSColor? = nil, font:NSFont? = .normal(.text)) -> NSAttributedString {
        let attr:NSMutableAttributedString = NSMutableAttributedString()
        _ = attr.append(string: string, color: color, font: font)
        
        return attr.copy() as! NSAttributedString
    }
    public convenience init(string: String, font: NSFont? = nil, textColor: NSColor = NSColor.black, paragraphAlignment: NSTextAlignment? = nil) {
        var attributes: [NSAttributedString.Key: AnyObject] = [:]
        if let font = font {
            attributes[.font] = font
        }
        attributes[.foregroundColor] = textColor
        if let paragraphAlignment = paragraphAlignment {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = paragraphAlignment
            attributes[.paragraphStyle] = paragraphStyle
        }
        self.init(string: string, attributes: attributes)
    }

    
}

public extension String {
    
    static func prettySized(with size:Int64, afterDot: Int8 = 1, removeToken: Bool = false, round: Bool = false) -> String {
        return prettySized(with: Int(size), afterDot: afterDot, removeToken: removeToken, round: round)
    }
    
    static func prettySized(with size:Int, afterDot: Int8 = 1, removeToken: Bool = false, round: Bool = false) -> String {
        var converted:Double = Double(size)
        var factor:Int = 0
        
        let tokens:[String] = ["B", "KB", "MB", "GB", "TB"]
        
        if round {
            while converted >= 1000 {
                converted /= 1000
                factor += 1
            }
        } else {
            while converted >= 1024.0 {
                converted /= 1024.0
                factor += 1
            }
        }
        
        
        if factor == 0 {
            //converted = 0
        }
        //factor = Swift.max(1,factor)
        
        if ceil(converted) - converted != 0.0 || removeToken {
            if removeToken {
                return String(format: "%.\(afterDot)f", converted)
            } else {
                return String(format: "%.\(afterDot)f %@", converted, tokens[factor])
            }
        } else {
            if removeToken {
                return String(format: "%.0f", converted)
            } else {
                return String(format: "%.0f %@", converted, tokens[factor])
            }
        }
        
    }
    
    var trimmed:String {
        
        var string:String = self
        string = string.replacingOccurrences(of: "\u{2028}", with: "\n")
        while !string.isEmpty, let index = string.rangeOfCharacter(from: NSCharacterSet.whitespacesAndNewlines), index.lowerBound == string.startIndex {
            string = String(string[index.upperBound..<string.endIndex])
        }
        while !string.isEmpty, let index = string.rangeOfCharacter(from: NSCharacterSet.whitespacesAndNewlines, options: .literal, range: string.index(string.endIndex, offsetBy: -1) ..< string.endIndex) {
            string = String(string[..<index.lowerBound])
        }

        return string
    }
    
    var fullTrimmed: String {
        var copy: String = self
        
        if copy.isEmpty {
            return copy
        }
        
        var index: String.Index = copy.index(after: copy.startIndex)
        
        var newLineIndexEnd: String.Index? = nil
        
        
        
//        while index != copy.endIndex {
//
//            if let idx = newLineIndexEnd {
//                let substring = copy[index..<copy.index(after: idx)]
//                let symbols = substring.filter({$0 != "\n"})
//                let newLines = substring.filter({$0 == "\n"})
//                if symbols.isEmpty {
//                    newLineIndexEnd = copy.index(after: idx)
//                } else {
//                    if newLines.utf8.count > 2 {
//                        copy = String(copy[..<index] + "\n\n" + copy[idx..<copy.endIndex])
//                        newLineIndexEnd = nil
//                        index = copy.index(after: copy.startIndex)
//                    } else {
//                        index = copy.index(after: idx)
//                        newLineIndexEnd = nil
//                    }
//                }
//            } else {
//                let first = String(copy[index..<copy.index(after: index)])
//
//                if first == "\n" {
//                    newLineIndexEnd = copy.index(after: index)
//                } else {
//                    index = copy.index(after: index)
//                }
//            }
//
//        }
        
        while let _ = copy.range(of: "\n\n\n") {
            copy = copy.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return copy
    }

}

public extension NSAttributedString.Key {
    static var preformattedCode: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "TGPreformattedCodeAttributeName")
    }
    static var preformattedPre: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "TGPreformattedPreAttributeName")
    }
    static var selectedColor: NSAttributedString.Key {
        return NSAttributedString.Key(rawValue: "KSelectedColorAttributeName")
    }
}

public extension NSPasteboard.PasteboardType {
    static var kUrl:NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(kUTTypeURL as String)
    }
    static var kInApp:NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType("TelegramTextPboardType" as String)
    }
    static var kFilenames:NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType("NSFilenamesPboardType")
    }
    static var kFileUrl: NSPasteboard.PasteboardType {
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
    public static let Ton = ParsingType(rawValue: 16)
}

public extension NSAttributedString {
    func detectBold(with font: NSFont) -> NSAttributedString {
        let copy = self.mutableCopy() as! NSMutableAttributedString
        copy.detectBoldColorInString(with: font, string: copy.string)
        return copy
    }
}

public extension NSMutableAttributedString {
    
    func detectBoldColorInString(with font: NSFont, color: NSColor? = nil) {
        detectBoldColorInString(with: font, string: self.string, color: color)
    }

    func detectBoldColorInString(with font: NSFont, string: String, color: NSColor? = nil) {
        var offset: Int = 0
        
        let nsString = string.nsstring
        
        while (offset < nsString.length) {
            let startRange = nsString.range(of: "**", options: [], range: NSRange(location: offset, length: nsString.length - offset))
            if startRange.location != NSNotFound {
                offset = startRange.upperBound
                
                let endOffset = min(offset, nsString.length)
                
                let endRange = nsString.range(of: "**", options: [], range: NSRange(location: endOffset, length: nsString.length - endOffset))
                if endRange.location != NSNotFound {
                    let startIndex = offset
                    let endIndex = endRange.lowerBound
                    let attributeRange = NSRange(location: startIndex, length: endIndex - startIndex)
                    
                    addAttribute(NSAttributedString.Key.font, value: font, range: attributeRange)
                    if let color = color {
                        addAttribute(.foregroundColor, value: color, range: attributeRange)
                    }
                    offset = endRange.upperBound
                }
            } else {
                break
            }
        }
        
        while let startRange = self.string.range(of: "**") {
            self.replaceCharacters(in: NSRange(startRange, in: self.string), with: "")
        }
    }
    
    
    func mergeIntersectingAttributes(keepBest: Bool = true) {
        let mergedAttributedString = self
        let fullRange = NSRange(location: 0, length: self.length)

        for attributeName in self.attributes(at: 0, effectiveRange: nil).keys {
            var intersectionRanges = [NSRange]()

            var location = 0
            while location < fullRange.length {
                var effectiveRange = NSRange()
                let attributeValue = self.attribute(attributeName, at: location, effectiveRange: &effectiveRange)
                if effectiveRange.length > 0 {
                    intersectionRanges.append(effectiveRange)
                }
                location = NSMaxRange(effectiveRange)
            }

            if intersectionRanges.count > 1 {
                if keepBest {
                    // Find the best attribute value (e.g., the one with the largest range)
                    var bestRange = NSRange()
                    var bestValue: Any?

                    for range in intersectionRanges {
                        if range.length > bestRange.length {
                            bestRange = range
                            bestValue = self.attribute(attributeName, at: range.location, effectiveRange: nil)
                        }
                    }

                    // Remove all intersecting ranges except the best one
                    for range in intersectionRanges {
                        if range != bestRange {
                            mergedAttributedString.removeAttribute(attributeName, range: range)
                        }
                    }
                } else {
                    // Keep only the first attribute and remove the rest
                    let firstRange = intersectionRanges.first!
                    for i in 1..<intersectionRanges.count {
                        let intersectionRange = intersectionRanges[i]
                        mergedAttributedString.removeAttribute(attributeName, range: intersectionRange)
                    }
                }
            }
        }
    }
    
    func removeWhitespaceFromQuoteAttribute() {
        let mutableAttributedString = self
        var fullRange = NSRange(location: 0, length: mutableAttributedString.length)

        mutableAttributedString.enumerateAttribute(TextInputAttributes.quote, in: fullRange, options: []) { value, range, _ in
            if let _ = value as? TextViewBlockQuoteData {
                var rangeToModify = range

                // Remove leading whitespace
                while rangeToModify.length > 0 {
                    let rangeString = mutableAttributedString.attributedSubstring(from: rangeToModify).string
                    if let firstChar = rangeString.first, firstChar.isNewline {
                        rangeToModify.location += 1
                        rangeToModify.length -= 1
                    } else {
                        break
                    }
                }

                // Remove trailing whitespace
                while rangeToModify.length > 0 {
                    let rangeString = mutableAttributedString.attributedSubstring(from: rangeToModify).string
                    if let lastChar = rangeString.last, lastChar.isNewline {
                        rangeToModify.length -= 1
                    } else {
                        break
                    }
                }
                if range != rangeToModify {
                    mutableAttributedString.replaceCharacters(in: range, with: mutableAttributedString.attributedSubstring(from: rangeToModify))
                }
            }
        }
        
        fullRange = NSRange(location: 0, length: mutableAttributedString.length)

        mutableAttributedString.enumerateAttribute(TextInputAttributes.quote, in: fullRange, options: []) { value, range, _ in
            if let _ = value as? TextViewBlockQuoteData {
                var rangeToModify = range
                if rangeToModify.min > 0 {
                    if let char = mutableAttributedString.attributedSubstring(from: NSMakeRange(rangeToModify.min - 1, 1)).string.first {
                        if !char.isNewline {
                            mutableAttributedString.insert(.initialize(string: "\n"), at: rangeToModify.min)
                            rangeToModify.location += 1
                        }
                    }
                }
                if rangeToModify.max < mutableAttributedString.length {
                    if let char = mutableAttributedString.attributedSubstring(from: NSMakeRange(rangeToModify.max, 1)).string.first {
                        if !char.isNewline {
                            mutableAttributedString.insert(.initialize(string: "\n"), at: rangeToModify.max)
                            rangeToModify.location -= 1
                        }
                    }
                }
            }
        }
    }

    
    @discardableResult func append(string:String?, color:NSColor? = nil, font:NSFont? = nil) -> NSRange {
        
        if(string == nil) {
            return NSMakeRange(0, 0)
        }
        
        let slength:Int = self.length


        var range:NSRange
        
        
        self.append(NSAttributedString(string: string!))
        let nlength:Int = self.length - slength
        range = NSMakeRange(self.length - nlength, nlength)
        
        if let c = color {
            self.addAttribute(NSAttributedString.Key.foregroundColor, value: c, range:range )
        }
        
        if let f = font {
            self.setFont(font: f, range: range)
        }
        
        
        return range
        
    }
    
    func fixEmojiesFont(_ fontSize: CGFloat) {
//        let nsString = self.string.nsstring
//        for i in 0 ..< min(nsString.length, 300) {
//            let sub = nsString.substring(with: NSMakeRange(i, 1))
//            if sub.containsOnlyEmoji, let font = NSFont(name: "AppleColorEmoji", size: fontSize) {
//                self.addAttribute(.font, value: font, range: NSMakeRange(i, 1))
//            }
//        }
    }
    
    func add(link:Any, for range:NSRange, color: NSColor = presentation.colors.link)  {
        self.addAttribute(NSAttributedString.Key.link, value: link, range: range)
        self.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: range)
    }
    
    
    func setSelected(color:NSColor,range:NSRange) -> Void {
        self.addAttribute(.selectedColor, value: color, range: range)
    }

    
    func setFont(font:NSFont, range:NSRange) -> Void {
        self.addAttribute(NSAttributedString.Key.font, value: font, range: range)
    }
    
}


public extension CALayer {
    
    var layerTintColor: CGColor? {
        get {
            if let value = self.value(forKey: "contentsMultiplyColor"), CFGetTypeID(value as CFTypeRef) == CGColor.typeID {
                let result = value as! CGColor
                return result
            } else {
                return nil
            }
        } set(value) {
            self.setValue(value, forKey: "contentsMultiplyColor")
        }
    }

    
    func disableActions() -> Void {
        
        self.actions = ["onOrderIn":NSNull(),"sublayers":NSNull(),"bounds":NSNull(),"frame":NSNull(), "background":NSNull(), "position":NSNull(),"contents":NSNull(),"backgroundColor":NSNull(),"border":NSNull(), "shadowOffset": NSNull()]
        removeAllAnimations()
    }
    
    
    func animateBackground(duration: Double = 0.2, function: CAMediaTimingFunctionName = .easeOut) ->Void {
        let animation: CABasicAnimation
        if function == .spring {
            animation = makeSpringAnimation("backgroundColor")
        } else {
            animation = CABasicAnimation(keyPath: "backgroundColor")
            animation.timingFunction = .init(name: function)
        }
        self.add(animation, forKey: "backgroundColor")
    }
    func animateTransform() ->Void {
        let animation = CABasicAnimation(keyPath: "transform")
        animation.duration = 0.2
        self.add(animation, forKey: "transform")
    }
    
    func animatePath(duration: Double = 0.2, function: CAMediaTimingFunctionName = .easeOut) {
        let animation: CABasicAnimation
        if function == .spring {
            animation = makeSpringAnimation("path")
        } else {
            animation = CABasicAnimation(keyPath: "path")
            animation.timingFunction = .init(name: function)
        }
        animation.duration = duration
        self.add(animation, forKey: "path")
    }
    func animateShadow() {
        let animation = CABasicAnimation(keyPath: "shadowPath")
        animation.duration = 0.2
        self.add(animation, forKey: "shadowPath")
    }
    func animateFrameFast() {
        let animation = CABasicAnimation(keyPath: "frame")
        animation.duration = 0.2
        self.add(animation, forKey: "frame")
    }
    
    func animateBorder() ->Void {
        let animation = CABasicAnimation(keyPath: "borderWidth")
        animation.duration = 0.2
        self.add(animation, forKey: "borderWidth")
    }
    func animateOpacity() ->Void {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.duration = 0.2
        self.add(animation, forKey: "opacity")
    }
    
    func animateBorderColor() ->Void {
        let animation = CABasicAnimation(keyPath: "borderColor")
        animation.duration = 0.2
        self.add(animation, forKey: "borderColor")
    }
    func animateGradientColors() ->Void {
        let animation = CABasicAnimation(keyPath: "colors")
        animation.duration = 0.2
        self.add(animation, forKey: "colors")
    }
    func animateCornerRadius(duration: Double = 0.2, timingFunction: CAMediaTimingFunctionName = .easeOut) ->Void {
        let animation: CABasicAnimation
        if timingFunction == .spring {
            animation = makeSpringAnimation("cornerRadius")
        } else {
            animation = CABasicAnimation(keyPath: "cornerRadius")
            animation.timingFunction = .init(name: timingFunction)
        }
        animation.duration = duration
        self.add(animation, forKey: "cornerRadius")
    }
    
    func animateContents() ->Void {
        let animation = CABasicAnimation(keyPath: "contents")
        animation.duration = 0.2
        self.add(animation, forKey: "contents")
    }
    
}




public extension NSView {
    
    var snapshot: NSImage {
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return NSImage() }
        self.cacheDisplay(in: bounds, to: rep)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }
    
    func setCenterScale(_ scale: CGFloat) {
        let rect = self.bounds
        var fr = CATransform3DIdentity
        fr = CATransform3DTranslate(fr, rect.width / 2, rect.height / 2, 0)
        fr = CATransform3DScale(fr, scale, scale, 1)
        fr = CATransform3DTranslate(fr, -(rect.width / 2), -(rect.height / 2), 0)
        self.layer?.transform = fr
    }
    
    var subviewsSize: NSSize {
        var size: NSSize = NSZeroSize
        for subview in subviews {
            size.width += subview.frame.width
            size.height += subview.frame.height
        }
        return size
    }
    var subviewsWidthSize: NSSize {
        var size: NSSize = NSZeroSize
        for subview in subviews {
            size.width += subview.frame.width
            size.height = max(subview.frame.height, size.height)
        }
        return size
    }
    private func isInSuperclassView(_ superclass: AnyClass, view: NSView) -> Bool {
        if view.isKind(of: superclass) {
            return true
        } else if let view = view.superview {
            return isInSuperclassView(superclass, view: view)
        } else {
            return false
        }
    }
    func isInSuperclassView(_ superclass: AnyClass) -> Bool {
        return isInSuperclassView(superclass, view: self)
    }
    
    
    func findSubview(at point: CGPoint) -> NSView? {
        for subview in subviews.reversed() {
            let convertedPoint = subview.convert(point, from: self)
            if subview.bounds.contains(convertedPoint) {
                return subview
            }
        }
        return nil
    }
    
    func _mouseInside() -> Bool {
        if let window = self.window {
       
            var location:NSPoint = window.mouseLocationOutsideOfEventStream

            location = self.convert(location, from: nil)
            
            
            if let view = window.contentView!.hitTest(window.mouseLocationOutsideOfEventStream) {
                if let view = view as? View {
                    if view.isEventLess {
                        return NSPointInRect(location, self.bounds)
                    }
                } else if let view = view as? ImageView, view.isEventLess {
                    return NSPointInRect(location, self.bounds)
                } else if let view = view as? LayerBackedView, view.isEventLess {
                    return NSPointInRect(location, self.bounds)
                } else if let view = view as? EventLessView, view.isEventLess {
                    return NSPointInRect(location, self.bounds)
                } else if let _ = view as? VisualEffect {
                    return NSPointInRect(location, self.bounds)
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
    
    var backingScaleFactor: CGFloat {
        if let window = window {
            return window.backingScaleFactor
        } else {
            return System.backingScale
        }
    }
    var bsc: CGFloat {
        return backingScaleFactor
    }
    
    func removeAllSubviews() -> Void {
        var filtered = self.subviews.filter { view -> Bool in
            if let view = view as? View {
                return !view.noWayToRemoveFromSuperview
            } else {
                return true
            }
        }
        while (filtered.count > 0) {
            filtered.removeFirst().removeFromSuperview()
        }
    }
    
    func isInnerView(_ view:NSView?) -> Bool {
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
    
    func setFrameSize(_ width:CGFloat, _ height:CGFloat) {
        self.setFrameSize(NSMakeSize(width, height))
    }
    
    func setFrameOrigin(_ x:CGFloat, _ y:CGFloat) {
        self.setFrameOrigin(NSMakePoint(x, y))
    }
    
    var background:NSColor {
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
    
    func centerX(_ superView:NSView? = nil, y:CGFloat? = nil, addition: CGFloat = 0) -> Void {
        
        var x:CGFloat = 0
        
        if let sv = superView {
            x = CGFloat(roundf(Float((sv.frame.width - frame.width)/2.0)))
        } else if let sv = self.superview {
            x = CGFloat(roundf(Float((sv.frame.width - frame.width)/2.0)))
        }
        
        
        self.setFrameOrigin(NSMakePoint(x + addition, y == nil ? NSMinY(self.frame) : y!))
    }
    
    func centerFrameX(y:CGFloat? = nil, addition: CGFloat = 0) -> CGRect {
        var x:CGFloat = 0
        if let sv = self.superview {
            x = CGFloat(roundf(Float((sv.frame.width - frame.width)/2.0)))
        }
        return CGRect(origin: NSMakePoint(x + addition, y == nil ? NSMinY(self.frame) : y!), size: frame.size)
    }
    
    func focus(_ size:NSSize) -> NSRect {
        var x:CGFloat = 0
        var y:CGFloat = 0
        
        x = CGFloat(round((frame.width - size.width)/2.0))
        y = CGFloat(round((frame.height - size.height)/2.0))
        
        
        return NSMakeRect(x, y, size.width, size.height)
    }
    
    func focus(_ size:NSSize, inset:NSEdgeInsets) -> NSRect {
        let x:CGFloat = CGFloat(round((frame.width - size.width + (inset.left + inset.right))/2.0))
        let y:CGFloat = CGFloat(round((frame.height - size.height + (inset.top + inset.bottom))/2.0))
        return NSMakeRect(x, y, size.width, size.height).offsetBy(dx: 0, dy: -inset.top)
    }
    
    func centerY(_ superView:NSView? = nil, x:CGFloat? = nil, addition: CGFloat = 0) -> Void {
        
        var y:CGFloat = 0
        
        if let sv = superView {
            y = CGFloat(round((sv.frame.height - frame.height)/2.0))
        } else if let sv = self.superview {
            y = CGFloat(round((sv.frame.height - frame.height)/2.0))
        }
        
        self.setFrameOrigin(NSMakePoint(x ?? frame.minX, y + addition))
    }
    
    func centerFrameY(x:CGFloat? = nil, addition: CGFloat = 0) -> CGRect {
        
        var y:CGFloat = 0
        
        if let sv = self.superview {
            y = CGFloat(round((sv.frame.height - frame.height)/2.0))
        }
        
        return CGRect(origin: NSMakePoint(x ?? frame.minX, y + addition), size: frame.size)
    }
    
    
    func center(_ superView:NSView? = nil) -> Void {
        
        var x:CGFloat = 0
        var y:CGFloat = 0
        
        if let sv = superView {
            x = CGFloat(round((sv.frame.width - frame.width)/2.0))
            y = CGFloat(round((sv.frame.height - frame.height)/2.0))
        } else if let sv = self.superview {
            x = CGFloat(round((sv.frame.width - frame.width)/2.0))
            y = CGFloat(round((sv.frame.height - frame.height)/2.0))
        }
        
        self.setFrameOrigin(NSMakePoint(x, y))
        
    }
    
    func centerPoint() -> CGPoint {
        var x:CGFloat = 0
        var y:CGFloat = 0
        
        if let sv = self.superview {
            x = CGFloat(round((sv.frame.width - frame.width)/2.0))
            y = CGFloat(round((sv.frame.height - frame.height)/2.0))
        }
        return NSMakePoint(x, y)
    }
    
    func centerFrame() -> CGRect {
        var x:CGFloat = 0
        var y:CGFloat = 0
        
        if let sv = self.superview {
            x = CGFloat(round((sv.frame.width - frame.width)/2.0))
            y = CGFloat(round((sv.frame.height - frame.height)/2.0))
        }
        return CGRect(origin: NSMakePoint(x, y), size: frame.size)
    }


    func rect(_ point:NSPoint) -> NSRect {
        return NSMakeRect(point.x, point.y, frame.width, frame.height)
    }
    
    func _change(pos position: NSPoint, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, additive: Bool = false, forceAnimateIfHasAnimation: Bool = false, completion:((Bool)->Void)? = nil) -> Void {
        
        
        if position == frame.origin && !additive {
            completion?(true)
            return
        }
        
        if self is NSVisualEffectView {
            let sub = self.layer?.sublayers ?? []
            for layer in sub {
                if animated || (forceAnimateIfHasAnimation && layer.animation(forKey:"position") != nil) {
                    
                    var presentX = NSMinX(self.frame)
                    var presentY = NSMinY(self.frame)
                    let presentation:CALayer? = layer.presentation()
                    if let presentation = presentation, let _ = layer.animation(forKey:"position") {
                        presentY =  presentation.frame.minY
                        presentX = presentation.frame.minX
                    }
                    layer.animatePosition(from: NSMakePoint(presentX, presentY), to: position, duration: duration, timingFunction: timingFunction, removeOnCompletion: removeOnCompletion, additive: additive, completion: completion)

                } else {
                    layer.removeAnimation(forKey: "position")
                }
            }
        }
        
        if animated || (forceAnimateIfHasAnimation && self.layer?.animation(forKey:"position") != nil) {
            
            var presentX = NSMinX(self.frame)
            var presentY = NSMinY(self.frame)
            let presentation:CALayer? = self.layer?.presentation()
            if let presentation = presentation, let _ = self.layer?.animation(forKey:"position") {
                presentY =  presentation.frame.minY
                presentX = presentation.frame.minX
            }
            self.layer?.animatePosition(from: NSMakePoint(presentX, presentY), to: position, duration: duration, timingFunction: timingFunction, removeOnCompletion: removeOnCompletion, additive: additive, completion: completion)

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
    
    func shake(beep: Bool = true) {
        let a:CGFloat = 3
        if let layer = layer {
            self.layer?.shake(0.04, from:NSMakePoint(-a + layer.position.x,layer.position.y), to:NSMakePoint(a + layer.position.x, layer.position.y))
        }
        if beep {
            NSSound.beep()
        }
    }
    
    func _change(size: NSSize, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion:((Bool)->Void)? = nil) {
        
        if size == frame.size {
            completion?(true)
            return
        }
        
        func animate(_ layer: CALayer, main: Bool) -> Void {
            if animated {
                var presentBounds:NSRect = layer.bounds
                let presentation = layer.presentation()
                if let presentation = presentation, layer.animation(forKey:"bounds") != nil {
                    presentBounds.size.width = NSWidth(presentation.bounds)
                    presentBounds.size.height = NSHeight(presentation.bounds)
                }
                layer.animateBounds(from: presentBounds, to: NSMakeRect(0, 0, size.width, size.height), duration: duration, timingFunction: timingFunction, removeOnCompletion: removeOnCompletion, completion: main ? completion : nil)
            } else {
                layer.removeAnimation(forKey: "bounds")
            }
        }
        
        if let layer = self.layer {
            animate(layer, main: true)
        }

        
        if save {
            self.frame = NSMakeRect(NSMinX(self.frame), NSMinY(self.frame), size.width, size.height)
        }
    }
    
    func _changeBounds(from: NSRect, to: NSRect, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion:((Bool)->Void)? = nil) {
        
       
        if save {
            self.bounds = to
        }
        
        if from == to {
            completion?(true)
            return
        }
        
        if self is NSVisualEffectView {
            let sub = self.layer?.sublayers ?? []
            for layer in sub {
                if animated {
                    layer.animateBounds(from: from, to: to, duration: duration, timingFunction: timingFunction, removeOnCompletion: removeOnCompletion, completion: completion)
                    
                } else {
                    layer.removeAnimation(forKey: "bounds")
                }
            }
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
    
    func _change(opacity to: CGFloat, animated: Bool = true, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion:((Bool)->Void)? = nil) {
        
        if Float(to) == self.layer?.opacity {
            completion?(true)
            return
        }
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
    
    func disableHierarchyInteraction() -> Void {
        for sub in self.subviews {
            if let sub = sub as? View, sub.interactionStateForRestore == nil {
                sub.interactionStateForRestore = sub.userInteractionEnabled
                sub.userInteractionEnabled = false
            }
            sub.disableHierarchyInteraction()
        }
    }
    func restoreHierarchyInteraction() -> Void {
        for sub in self.subviews {
            if let sub = sub as? View, let resporeState = sub.interactionStateForRestore {
                sub.userInteractionEnabled = resporeState
                sub.interactionStateForRestore = nil
            } else if let sub = sub as? TableRowView, let resporeState = sub.interactionStateForRestore {
                sub.userInteractionEnabled = resporeState
                sub.interactionStateForRestore = nil
            }
            sub.restoreHierarchyInteraction()
        }
    }
    
    func restoreHierarchyDynamicContent() -> Void {
        for sub in self.subviews {
            if let sub = sub as? View, let resporeState = sub.dynamicContentStateForRestore {
                sub.isDynamicContentLocked = resporeState
                sub.dynamicContentStateForRestore = nil
            } else if let sub = sub as? TableRowView, let resporeState = sub.dynamicContentStateForRestore {
                sub.isDynamicContentLocked = resporeState
                sub.dynamicContentStateForRestore = nil
            }
            sub.restoreHierarchyDynamicContent()
        }
    }
    
    func disableHierarchyDynamicContent() -> Void {
        for sub in self.subviews {
            if let sub = sub as? View, sub.interactionStateForRestore == nil {
                sub.dynamicContentStateForRestore = sub.isDynamicContentLocked
                sub.isDynamicContentLocked = true
            } else if let sub = sub as? TableRowView, sub.interactionStateForRestore == nil {
                sub.dynamicContentStateForRestore = sub.isDynamicContentLocked
                sub.isDynamicContentLocked = true
            }
            sub.disableHierarchyDynamicContent()
        }
    }
    
    

}




public extension NSTableView.AnimationOptions {
    static var none: NSTableView.AnimationOptions { get {
            return NSTableView.AnimationOptions(rawValue: 0)
        }
    }

}

public extension CGSize {
    func fitted(_ size: CGSize) -> CGSize {
        var fittedSize = self
        if fittedSize.width > size.width {
            fittedSize = CGSize(width: size.width, height: ceil((fittedSize.height * size.width / max(fittedSize.width, 1.0))))
        }
        if fittedSize.height > size.height {
            fittedSize = CGSize(width: ceil((fittedSize.width * size.height / max(fittedSize.height, 1.0))), height: size.height)
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
    
    func cropped(_ size: CGSize) -> CGSize {
        return CGSize(width: min(size.width, self.width), height: min(size.height, self.height))
    }
    
    func fittedToArea(_ area: CGFloat) -> CGSize {
        if self.height < 1.0 || self.width < 1.0 {
            return CGSize()
        }
        let aspect = self.width / self.height
        let height = sqrt(area / aspect)
        let width = aspect * height
        return CGSize(width: ceil(width), height: ceil(height))
    }
    
    func aspectFilled(_ size: CGSize) -> CGSize {
        let scale = max(size.width / max(1.0, self.width), size.height / max(1.0, self.height))
        return CGSize(width: ceil(self.width * scale), height: ceil(self.height * scale))
    }
    func fittedToWidthOrSmaller(_ width: CGFloat) -> CGSize {
        let scale = min(1.0, width / max(1.0, self.width))
        return CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
    }
    
    func aspectFitted(_ size: CGSize) -> CGSize {
        let scale = min(size.width / max(1.0, self.width), size.height / max(1.0, self.height))
        return CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
    }
    
    func multipliedByScreenScale() -> CGSize {
        let scale:CGFloat = System.backingScale
        return CGSize(width: self.width * scale, height: self.height * scale)
    }
    
    var integralFloor: CGSize {
        return CGSize(width: floor(self.width), height: floor(self.height))
    }

    
    func dividedByScreenScale() -> CGSize {
        let scale:CGFloat = System.backingScale
        return CGSize(width: self.width / scale, height: self.height / scale)
    }
    var bounds: CGRect {
        return NSMakeRect(0, 0, width, height)
    }
}

public extension NSImage {
    
    func precomposed(_ colors:[NSColor], flipVertical:Bool = false, flipHorizontal:Bool = false, scale: CGFloat = System.backingScale) -> CGImage {
        
        let drawContext:DrawingContext = DrawingContext(size: NSMakeSize(self.size.width, self.size.height), scale: scale, clear: true)
        
        
        let make:(CGContext) -> Void = { [weak self] ctx in
            
            guard let image = self else { return }
            
            let rect = NSMakeRect(0, 0, drawContext.size.width, drawContext.size.height)
            ctx.interpolationQuality = .high
            ctx.clear(rect)
            
            var imageRect:CGRect = NSMakeRect(0, 0, image.size.width, image.size.height)

            let cimage = image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
            
            if !colors.isEmpty {
                ctx.clip(to: rect, mask: cimage!)
                if colors.count > 2 {
                    let preview = AnimatedGradientBackgroundView.generatePreview(size: NSMakeSize(32, 32), colors: colors)
                    ctx.draw(preview, in: rect.focus(preview.size.aspectFilled(rect.size)))
                } else if colors.count > 1 {
                    let rect = NSMakeRect(0, 0, rect.width, rect.height)
                    let gradientColors = colors.reversed().map { $0.cgColor } as CFArray
                    let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                    
                    var locations: [CGFloat] = []
                    for i in 0 ..< colors.count {
                        locations.append(delta * CGFloat(i))
                    }
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: rect.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                } else if let color = colors.first {
                    ctx.setFillColor(color.cgColor)
                    ctx.fill(rect)
                }
            } else {
                ctx.draw(cimage!, in: imageRect)
            }
            

        }
        
        drawContext.withFlippedContext(horizontal: flipHorizontal, vertical: flipVertical, make)

        return drawContext.generateImage()!
    }
    
    
    func precomposed(_ color:NSColor? = nil, bottomColor: NSColor? = nil, flipVertical:Bool = false, flipHorizontal:Bool = false, scale: CGFloat = System.backingScale, zoom: CGFloat = 1) -> CGImage {
        
        let drawContext:DrawingContext = DrawingContext(size: NSMakeSize(size.width * zoom, size.height * zoom), scale: scale, clear: true)
        
        
        let make:(CGContext) -> Void = { [weak self] ctx in
            
            guard let image = self else { return }
            
            let rect = NSMakeRect(0, 0, drawContext.size.width * zoom, drawContext.size.height * zoom)
            ctx.interpolationQuality = .high
            ctx.clear(rect)
            
            var imageRect:CGRect = NSMakeRect(0, 0, image.size.width * zoom, image.size.height * zoom)

            let cimage = image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
            
            if let color = color {
                ctx.clip(to: rect, mask: cimage!)
                if let bottomColor = bottomColor {
                    let colors = [color, bottomColor]
                    let rect = NSMakeRect(0, 0, rect.width, rect.height)
                    let gradientColors = colors.reversed().map { $0.cgColor } as CFArray
                    let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                    
                    var locations: [CGFloat] = []
                    for i in 0 ..< colors.count {
                        locations.append(delta * CGFloat(i))
                    }
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: rect.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                } else {
                    ctx.setFillColor(color.cgColor)
                    ctx.fill(rect)
                }
             
            } else {
                ctx.draw(cimage!, in: imageRect)
            }

        }
        
        drawContext.withFlippedContext(horizontal: flipHorizontal, vertical: flipVertical, make)

        return drawContext.generateImage()!
    }
    
}

public extension CGRect {
    var topLeft: CGPoint {
        return self.origin
    }
    
    var topRight: CGPoint {
        return CGPoint(x: self.maxX, y: self.minY)
    }
    
    var bottomLeft: CGPoint {
        return CGPoint(x: self.minX, y: self.maxY)
    }
    
    var bottomRight: CGPoint {
        return CGPoint(x: self.maxX, y: self.maxY)
    }
    
    func makeSize(_ size: NSSize) -> CGRect {
        var rect = self
        rect.size = size
        return rect
    }
    
    var center: CGPoint {
        return CGPoint(x: self.midX, y: self.midY)
    }
    func focus(_ size:NSSize) -> NSRect {
        var x:CGFloat = 0
        var y:CGFloat = 0
        
        x = CGFloat(round((self.width - size.width)/2.0))
        y = CGFloat(round((self.height - size.height)/2.0))
        
        
        return NSMakeRect(x, y, size.width, size.height)
    }
    
    func focusX(_ size:NSSize, y: CGFloat) -> NSRect {
        var x:CGFloat = 0
        
        x = CGFloat(round((self.width - size.width)/2.0))
        
        return NSMakeRect(x, y, size.width, size.height)
    }
    
    func focusY(_ size:NSSize, x: CGFloat) -> NSRect {
        var y:CGFloat = 0
        
        y = CGFloat(round((self.height - size.height)/2.0))
        
        
        return NSMakeRect(x, y, size.width, size.height)
    }
}

public extension CGPoint {
    func offsetBy(dx: CGFloat, dy: CGFloat) -> CGPoint {
        return CGPoint(x: self.x + dx, y: self.y + dy)
    }
    func distance(p2: CGPoint) -> CGFloat {
        let xdst = self.x - p2.x
        let ydst = self.y - p2.y
        return sqrt((xdst * xdst) + (ydst * ydst))
    }
    
    var toScreenPixel: CGPoint {
        return CGPoint(x: floorToScreenPixels(x),
                      y: floorToScreenPixels(y))
    }
}


public enum ImageOrientation {
    case up
    case down
    case left
    case right
    case upMirrored
    case downMirrored
    case leftMirrored
    case rightMirrored
}


public extension CGImage {
    
    var backingSize:NSSize {
        return systemSize// NSMakeSize(CGFloat(width) * 0.5, CGFloat(height) * 0.5)
    }
    
    var halfSize:NSSize {
        return  NSMakeSize(CGFloat(width) * 0.5, CGFloat(height) * 0.5)
    }
    
    var size:NSSize {
        return NSMakeSize(CGFloat(width), CGFloat(height))
    }
    
    var systemSize:NSSize {
        return NSMakeSize(CGFloat(width) / scale, CGFloat(height) / scale)
    }
    
    var backingBounds: NSRect {
        return NSMakeRect(0, 0, backingSize.width, backingSize.height)
    }
    
    var scale:CGFloat {
        return System.backingScale
    }
    
    var _NSImage: NSImage {
        return NSImage(cgImage: self, size: backingSize)
    }

    func highlight(color: NSColor) -> CGImage {
        let image = self
        let context = DrawingContext(size:image.backingSize, scale: System.backingScale, clear:true)
        context.withContext { ctx in
            ctx.clear(NSMakeRect(0, 0, image.backingSize.width, image.backingSize.height))
            let imageRect = NSMakeRect(0, 0, image.backingSize.width, image.backingSize.height)
            
            ctx.clip(to: imageRect, mask: image)
            ctx.setFillColor(color.cgColor)
            ctx.fill(imageRect)
        }
        return context.generateImage() ?? image
    }
    
    func createMatchingBackingDataWithImage(orienation: ImageOrientation) -> CGImage?
    {
        var orientedImage: CGImage?
        let imageRef = self
        let originalWidth = imageRef.width
        let originalHeight = imageRef.height
        
        
        
        
        var degreesToRotate: Double
        var swapWidthHeight: Bool
        var mirrored: Bool
        switch orienation {
        case .up:
            degreesToRotate = 0.0
            swapWidthHeight = false
            mirrored = false
            break
        case .upMirrored:
            degreesToRotate = 0.0
            swapWidthHeight = false
            mirrored = true
            break
        case .right:
            degreesToRotate = 90.0
            swapWidthHeight = true
            mirrored = false
            break
        case .rightMirrored:
            degreesToRotate = 90.0
            swapWidthHeight = true
            mirrored = true
            break
        case .down:
            degreesToRotate = 180.0
            swapWidthHeight = false
            mirrored = false
            break
        case .downMirrored:
            degreesToRotate = 180.0
            swapWidthHeight = false
            mirrored = true
            break
        case .left:
            degreesToRotate = -90.0
            swapWidthHeight = true
            mirrored = false
            break
        case .leftMirrored:
            degreesToRotate = -90.0
            swapWidthHeight = true
            mirrored = true
            break
        }
        let radians = degreesToRotate * Double.pi / 180.0
        
        var width: Int
        var height: Int
        if swapWidthHeight {
            width = originalHeight
            height = originalWidth
        } else {
            width = originalWidth
            height = originalHeight
        }
        
        let bytesPerRow = (4 * Int(swapWidthHeight ? imageRef.height : imageRef.width) + 15) & (~15)
        let bitsPerComponent = 8
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)

        
        let contextRef = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: bitmapInfo.rawValue)
        contextRef?.translateBy(x: CGFloat(width) / 2.0, y: CGFloat(height) / 2.0)
        if mirrored {
            contextRef?.scaleBy(x: -1.0, y: 1.0)
        }
        contextRef?.rotate(by: CGFloat(radians))
        if swapWidthHeight {
            contextRef?.translateBy(x: -CGFloat(height) / 2.0, y: -CGFloat(width) / 2.0)
        } else {
            contextRef?.translateBy(x: -CGFloat(width) / 2.0, y: -CGFloat(height) / 2.0)
        }
        contextRef?.draw(imageRef, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(originalWidth), height: CGFloat(originalHeight)))
        orientedImage = contextRef?.makeImage()
        
        return orientedImage
    }
}

public extension Array {
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
    func randomElements(_ count: Int) -> [Element] {
        var indexes:[Int] = []
        if self.count <= count {
            return self.shuffled()
        }
        for _ in 0 ..< count {
            var finding = true
            while finding {
                let index = Int.random(in: 0 ..< self.count)
                if !indexes.contains(index) {
                    indexes.append(index)
                    finding = false
                }
            }
        }
        
        return indexes.reduce([], { current, index in
            var current = current
            current.append(self[index])
            return current
        })
    }
}

public extension NSScrollView {
    var contentOffset: NSPoint {
        return contentView.bounds.origin
    }
}

public struct LayoutPositionFlags : OptionSet {
    
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public init(_ flags: LayoutPositionFlags) {
        var rawValue: UInt32 = 0
        
        if flags.contains(LayoutPositionFlags.none) {
            rawValue |= LayoutPositionFlags.none.rawValue
        }
        
        if flags.contains(LayoutPositionFlags.top) {
            rawValue |= LayoutPositionFlags.top.rawValue
        }
        
        if flags.contains(LayoutPositionFlags.bottom) {
            rawValue |= LayoutPositionFlags.bottom.rawValue
        }
        
        if flags.contains(LayoutPositionFlags.left) {
            rawValue |= LayoutPositionFlags.left.rawValue
        }
        if flags.contains(LayoutPositionFlags.right) {
            rawValue |= LayoutPositionFlags.right.rawValue
        }
        if flags.contains(LayoutPositionFlags.inside) {
            rawValue |= LayoutPositionFlags.inside.rawValue
        }
        
        self.rawValue = rawValue
    }
    
    public static let none = LayoutPositionFlags(rawValue: 0)
    public static let top = LayoutPositionFlags(rawValue: 1 << 0)
    public static let bottom = LayoutPositionFlags(rawValue: 1 << 1)
    public static let left = LayoutPositionFlags(rawValue: 1 << 2)
    public static let right = LayoutPositionFlags(rawValue: 1 << 3)
    public static let inside = LayoutPositionFlags(rawValue: 1 << 4)
}

public struct NSRectCorner: OptionSet {
    public let rawValue: UInt
    
    public static let none = NSRectCorner(rawValue: 0)
    public static let topLeft = NSRectCorner(rawValue: 1 << 0)
    public static let topRight = NSRectCorner(rawValue: 1 << 1)
    public static let bottomLeft = NSRectCorner(rawValue: 1 << 2)
    public static let bottomRight = NSRectCorner(rawValue: 1 << 3)
    public static var all: NSRectCorner {
        return [.topLeft, .topRight, .bottomLeft, .bottomRight]
    }
    
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
}

public extension CGContext {
    func round(_ size:NSSize,_ corners:CGFloat = .cornerRadius) {
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
    
    
    func drawRoundedRect(rect: CGRect, topLeftRadius: CGFloat = 0, topRightRadius: CGFloat = 0, bottomLeftRadius: CGFloat = 0, bottomRightRadius: CGFloat = 0) {
        let context = self
        context.beginPath()
        
        let topLeft = rect.origin
        let topRight = CGPoint(x: rect.origin.x + rect.size.width, y: rect.origin.y)
        let bottomRight = CGPoint(x: rect.origin.x + rect.size.width, y: rect.origin.y + rect.size.height)
        let bottomLeft = CGPoint(x: rect.origin.x, y: rect.origin.y + rect.size.height)
        
        context.move(to: CGPoint(x: topLeft.x + topLeftRadius, y: topLeft.y))
        context.addLine(to: CGPoint(x: topRight.x - topRightRadius, y: topRight.y))
        context.addArc(tangent1End: topRight, tangent2End: bottomRight, radius: topRightRadius)
        context.addLine(to: CGPoint(x: bottomRight.x, y: bottomRight.y - bottomRightRadius))
        context.addArc(tangent1End: bottomRight, tangent2End: bottomLeft, radius: bottomRightRadius)
        context.addLine(to: CGPoint(x: bottomLeft.x + bottomLeftRadius, y: bottomLeft.y))
        context.addArc(tangent1End: bottomLeft, tangent2End: topLeft, radius: bottomLeftRadius)
        context.addLine(to: CGPoint(x: topLeft.x, y: topLeft.y + topLeftRadius))
        context.addArc(tangent1End: topLeft, tangent2End: topRight, radius: topLeftRadius)
        
        context.closePath()
        
        context.fillPath()
    }
    
    func round(_ frame: NSRect, flags: LayoutPositionFlags) {
        var topLeftRadius: CGFloat = 0
        var bottomLeftRadius: CGFloat = 0
        var topRightRadius: CGFloat = 0
        var bottomRightRadius: CGFloat = 0
        
        let minx:CGFloat = frame.minX, midx = frame.midX, maxx = frame.width
        let miny:CGFloat = frame.minY, midy = frame.midY, maxy = frame.height
        
        self.move(to: NSMakePoint(minx, midy))
        
        
        if flags.contains(.top) && flags.contains(.left) {
            topLeftRadius = .cornerRadius
        }
        if flags.contains(.top) && flags.contains(.right) {
            topRightRadius = .cornerRadius
        }
        if flags.contains(.bottom) && flags.contains(.left) {
            bottomLeftRadius = .cornerRadius
        }
        if flags.contains(.bottom) && flags.contains(.right) {
            bottomRightRadius = .cornerRadius
        }
        
        self.addArc(tangent1End: NSMakePoint(minx, miny), tangent2End: NSMakePoint(midx, miny), radius: bottomLeftRadius)
        self.addArc(tangent1End: NSMakePoint(maxx, miny), tangent2End: NSMakePoint(maxx, midy), radius: bottomRightRadius)
        self.addArc(tangent1End: NSMakePoint(maxx, maxy), tangent2End: NSMakePoint(midx, maxy), radius: topRightRadius)
        self.addArc(tangent1End: NSMakePoint(minx, maxy), tangent2End: NSMakePoint(minx, midy), radius: topLeftRadius)
        
        self.closePath()
        self.clip()
    }
    
    
    static func round(frame: NSRect, cornerRadius: CGFloat, rectCorner: NSRectCorner) -> CGPath {
        
        let path = CGMutablePath()
        
        let minx:CGFloat = 0, midx = frame.width/2.0, maxx = frame.width
        let miny:CGFloat = frame.height, midy = frame.height/2.0, maxy: CGFloat = 0
        
        path.move(to: NSMakePoint(minx, midy))
        
        var topLeftRadius: CGFloat = 0
        var bottomLeftRadius: CGFloat = 0
        var topRightRadius: CGFloat = 0
        var bottomRightRadius: CGFloat = 0
        
        
        if rectCorner.contains(.topLeft) {
            topLeftRadius = cornerRadius
        }
        if rectCorner.contains(.topRight) {
            topRightRadius = cornerRadius
        }
        if rectCorner.contains(.bottomLeft) {
            bottomLeftRadius = cornerRadius
        }
        if rectCorner.contains(.bottomRight) {
            bottomRightRadius = cornerRadius
        }
        
        
        
        path.addArc(tangent1End: NSMakePoint(minx, miny), tangent2End: NSMakePoint(midx, miny), radius: bottomLeftRadius)
        path.addArc(tangent1End: NSMakePoint(maxx, miny), tangent2End: NSMakePoint(maxx, midy), radius: bottomRightRadius)
        path.addArc(tangent1End: NSMakePoint(maxx, maxy), tangent2End: NSMakePoint(midx, maxy), radius: topRightRadius)
        path.addArc(tangent1End: NSMakePoint(minx, maxy), tangent2End: NSMakePoint(minx, midy), radius: topLeftRadius)
        
        if rectCorner.contains(.topLeft) {
             path.move(to: NSMakePoint(minx, cornerRadius))
        } else {
             path.move(to: NSMakePoint(minx, maxy))
        }
       
        
        path.addLine(to: NSMakePoint(minx, midy))
        
        //cgPath.closePath()
        return path
        //cgPath.clip()
    }
}



public extension NSRange {
    var min:Int {
        return self.location
    }
    var max:Int {
        return self.location + self.length
    }
    var isEmpty: Bool {
        return self.length == 0
    }
    func indexIn(_ index: Int) -> Bool {
        return NSLocationInRange(index, self)
    }
    init(string: String, range: Range<String.Index>) {
        let utf8 = string.utf16

        let location = utf8.distance(from: utf8.startIndex, to: range.lowerBound)
        let length = utf8.distance(from: range.lowerBound, to: range.upperBound)

        self.init(location: location, length: length)
    }
}

public extension NSBezierPath {
    var _cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)

        for i in 0..<self.elementCount {
            switch self.element(at: i, associatedPoints: &points) {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        return path
    }

}


public extension NSRect {
    
    func apply(multiplier: NSSize) -> NSRect {
        return NSMakeRect(round(minX * multiplier.width), round(minY * multiplier.height), round(width * multiplier.width), round(height * multiplier.height))
    }
    
    func scaleLinear(amount: Double) -> CGRect {
        guard amount != 1.0, amount > 0.0 else { return self }
        let ratio = ((1.0 - amount) / 2.0)
        return insetBy(dx: width * ratio, dy: height * ratio)
    }

    func scaleArea(amount: Double) -> CGRect {
        return scaleLinear(percent: sqrt(amount))
    }

    func scaleLinear(percent: Double) -> CGRect {
        return scaleLinear(amount: percent / 100)
    }

    func scaleArea(percent: Double) -> CGRect {
        return scaleArea(amount: percent / 100)
    }
    
    func rotate90Degress(parentSize: NSSize) -> NSRect {

       
        
        let width: CGFloat = parentSize.width
        let height: CGFloat = parentSize.height
        
        
        let transform = NSAffineTransform()
        
     //   transform.translateX(by: 0, yBy: height)
        
        transform.rotate(byDegrees: 90)
        transform.translateX(by: 0, yBy: -height)

        
        //transform.scaleX(by: 1, yBy: -1)

        let path = NSBezierPath()
        path.appendRect(NSMakeRect(0, 0, width, height))
        path.appendRect(self)
        
        let newPath = transform.transform(path)
        
        var rect = NSMakeRect(0, 0, self.height, self.width)
        for i in 5 ..< newPath.elementCount - 2 {
            var points = [NSPoint](repeating: NSZeroPoint, count: 1)
            
            switch newPath.element(at: i, associatedPoints: &points) {
            case .moveTo:
                let point = points[0]
                rect.origin.x = (height - point.x)
                rect.origin.y = (width - point.y - self.width)
            default:
                break
            }
        }
        
        
        
        return rect
    }
}

public extension NSEdgeInsets {

    public init(left:CGFloat = 0, right:CGFloat = 0, top:CGFloat = 0, bottom:CGFloat = 0) {
        self.init(top: top, left: left, bottom: bottom, right: right)
    }
}


public extension Int32 {
    var isFuture: Bool {
        return self > Int32(Date().timeIntervalSince1970)
    }
    var decemial: Double {
        return Double(self) / 10
    }
}

public extension Double {
    var string: String {
        return self.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : String(self)
    }
}

public extension Int64 {
    
    func prettyFormatter(_ n: Int64, iteration: Int, rounded: Bool = false) -> String {
        let keys = ["K", "M", "B", "T"]
        var d = Double((n / 100)) / 10.0
        if rounded {
            d = floor(d)
        }
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
            return self.prettyFormatter(Int64(d), iteration: iteration + 1, rounded: rounded)
        }
    }
    
    var prettyRounded: String {
        if self < 1000 {
            return "\(self)"
        }
        return self.prettyFormatter(self, iteration: 0, rounded: true).replacingOccurrences(of: ".", with: Locale.current.decimalSeparator ?? ".")
    }
    
    var prettyNumber:String {
        if self < 1000 {
            return "\(self)"
        }
        
        return self.prettyFormatter(self, iteration: 0).replacingOccurrences(of: ".", with: Locale.current.decimalSeparator ?? ".")
    }
    var separatedNumber: String {
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




public extension Int {
    
    func prettyFormatter(_ n: Int, iteration: Int, rounded: Bool = false) -> String {
        let keys = ["K", "M", "B", "T"]
        var d = Double((n / 100)) / 10.0
        if rounded {
            d = floor(d)
        }
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
            return self.prettyFormatter(Int(d), iteration: iteration + 1, rounded: rounded)
        }
    }
    
    var prettyRounded: String {
        if self < 1000 {
            return "\(self)"
        }
        return self.prettyFormatter(self, iteration: 0, rounded: true).replacingOccurrences(of: ".", with: Locale.current.decimalSeparator ?? ".")
    }
    
    var prettyNumber:String {
        if self < 1000 {
            return "\(self)"
        }
        
        return self.prettyFormatter(self, iteration: 0).replacingOccurrences(of: ".", with: Locale.current.decimalSeparator ?? ".")
    }
    var separatedNumber: String {
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


public extension NSProgressIndicator {
    func set(color:NSColor) {
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


public extension NSTextField {
    func setSelectionRange(_ range: NSRange) {
        textView?.setSelectedRange(range)
    }
    
    var selectedRange: NSRange {
        if let textView = textView {
            return textView.selectedRange
        }
        return NSMakeRange(0, 0)
    }
    
    func setCursorToEnd() {
        self.setSelectionRange(NSRange(location: self.stringValue.length, length: 0))
    }
    
    func setCursorToStart() {
        self.setSelectionRange(NSRange(location: 0, length: 0))
    }
    
    var textView:NSTextView? {
        let textView = (self.window?.fieldEditor(true, for: self) as? NSTextView)
        textView?.backgroundColor = .clear
        textView?.drawsBackground = true
        return textView
    }
}

public extension NSTextView {
    func selectAllText() {
        setSelectedRange(NSMakeRange(0, self.string.length))
    }
    
    func appendText(_ text: String) -> Void {
        let inputText = self.attributedString().mutableCopy() as! NSMutableAttributedString
        
        if selectedRange.upperBound - selectedRange.lowerBound > 0 {
            inputText.replaceCharacters(in: NSMakeRange(selectedRange.lowerBound, selectedRange.upperBound - selectedRange.lowerBound), with: NSAttributedString(string: text))
        } else {
            inputText.insert(NSAttributedString(string: text), at: selectedRange.lowerBound)
        }
        self.string = inputText.string
    }
}





public extension Sequence where Iterator.Element: Hashable {
    var uniqueElements: [Iterator.Element] {
        return self.reduce([], { current, value in
            if current.contains(value) {
                return current
            } else {
                return current + [value]
            }
        })
    }
}
public extension Sequence where Iterator.Element: Equatable {
    var uniqueElements: [Iterator.Element] {
        return self.reduce([], { current, value in
            if current.contains(value) {
                return current
            } else {
                return current + [value]
            }
        })
//        return self.reduce([]){
//            uniqueElements, element in
//
//            uniqueElements.contains(element)
//                ? uniqueElements
//                : uniqueElements + [element]
//        }
    }
}
public extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).uppercased() + dropFirst()
    }
    
    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}



class GestureUtils{
    /**
     * To avoid duplicate code we could extract the content of this method into an GestureUtils method. Return nil if there isn't 2 touches and set the array only if != nil
     */
    static func twoFingersTouches(_ view:NSView, _ event:NSEvent)->[String:NSTouch]?{
        var twoFingersTouches:[String:NSTouch]? = nil//NSMutualDictionary was used before and didn't require casting id to string, revert if side-effects manifest
        let touches:Set<NSTouch> = event.touches(matching:NSTouch.Phase.any, in: view)//touchesMatchingPhase:NSTouchPhaseAny inView:self
        if(touches.count == 2){
            twoFingersTouches = [String:NSTouch]()
            for touch in touches {
                twoFingersTouches!["\((touch).identity)"] = touch/*assigns each touch to the identity of the same touch*///was [ setObject: forKey:];
            }
        }
        return twoFingersTouches
    }
    /**
     * Detects 2 finger (left/right) swipe gesture
     * NOTE: either of 3 enums is returned: .leftSwipe, .rightSwipe .none
     * TODO: also make up and down swipe detectors, and do more research into how this could be done easier. Maybe you even have some clues in the notes about gestures etc.
     * Conceptually:
     * 1. Record 2 .began touchEvents
     * 2. Record 2 .ended touchEvents
     * 3. Measure the distance between .began and .ended and assert if it is within threshold
     */
    static func swipe(_ view:NSView, _ event:NSEvent, _ beginningTouches:[String:NSTouch]) -> SwipeType{
        let endingTouches:Set<NSTouch> = event.touches(matching: NSTouch.Phase.ended, in: view)
        if endingTouches.count == 2 {
            var magnitudesX:[CGFloat] = []/*magnitude definition: the great size or extent of something.*/
            var magnitudesY:[CGFloat] = []/*magnitude definition: the great size or extent of something.*/
            for endingTouch in endingTouches {
                guard let beginningTouch:NSTouch = beginningTouches["\(endingTouch.identity)"] else {continue}
                
                let magnitudeX:CGFloat = endingTouch.normalizedPosition.x - beginningTouch.normalizedPosition.x
                magnitudesX.append(magnitudeX)
                
                let magnitudeY:CGFloat = endingTouch.normalizedPosition.y - beginningTouch.normalizedPosition.y
                magnitudesX.append(magnitudeY)
            }
            
            let kSwipeMinimumLength:CGFloat = 0.1

            
            var sumX:CGFloat = 0
            for magnitudeX in magnitudesX {
                sumX += magnitudeX
            }
            
            var sumY:CGFloat = 0
            for magnitudeY in magnitudesY {
                sumY += magnitudeY
            }
            
            let absoluteSumY:CGFloat = abs(sumY)
            if (absoluteSumY > kSwipeMinimumLength) {return .none}
            
            let absoluteSumX:CGFloat = abs(sumX)/*force value to be positive*/
            if (absoluteSumX < kSwipeMinimumLength) {return .none}/*Assert if the absolute sum is long enough to be considered a complete gesture*/
            if (sumX > 0){
                return .right
            }else /*if(sum < 0)*/{
                return .left
            }
        }
        return .none/*no swipe direction detected*/
    }
}
public extension NSView {
    
    func widthConstraint(relation: NSLayoutConstraint.Relation,
                         size: CGFloat) -> NSLayoutConstraint {
        return NSLayoutConstraint(item: self,
                                  attribute: .width,
                                  relatedBy: relation,
                                  toItem: nil,
                                  attribute: .width,
                                  multiplier: 1.0,
                                  constant: size)
    }
    
    func addWidthConstraint(relation: NSLayoutConstraint.Relation = .equal,
                            size: CGFloat) {
        addConstraint(widthConstraint(relation: relation,
                                      size: size))
    }
    var effectiveVisibleRect: NSRect {
        var visibleRect = self.visibleRect
        if let tableView = self.enclosingScrollView as? TableView {
            if tableView.contentInsets.top > 0 {
                let rect = self.convert(self.bounds, to: tableView.documentView)
                let visible = NSMakeRect(0, tableView.documentOffset.y, tableView.frame.width, tableView.frame.height)
                if rect.minY < visible.minY {
                    visibleRect = CGRect(origin: CGPoint(x: 0, y: 0), size: NSMakeSize(rect.width, rect.minY - visible.minY + rect.height))
                } else {
                    let height = visible.maxY - rect.minY - tableView.contentInsets.top
                    visibleRect = CGRect(origin: CGPoint(x: 0, y: rect.height - height), size: NSMakeSize(rect.width, height))
                }
            }
        }
        return visibleRect
    }
    
    func setAnchorPoint(anchorPoint: CGPoint) {
        guard let layer = self.layer else {
            return
        }
        
        var newPoint = CGPoint(x: bounds.size.width * anchorPoint.x, y: bounds.size.height * anchorPoint.y)
        var oldPoint = CGPoint(x: bounds.size.width * layer.anchorPoint.x, y: bounds.size.height * layer.anchorPoint.y)

        newPoint = newPoint.applying(layer.affineTransform())
        oldPoint = oldPoint.applying(layer.affineTransform())

        var position = layer.position

        position.x -= oldPoint.x
        position.x += newPoint.x

        position.y -= oldPoint.y
        position.y += newPoint.y
        
        layer.position = position
        layer.anchorPoint = anchorPoint
    }
    
}

public extension NSWindow {
    var bounds: NSRect {
        return NSMakeRect(0, 0, frame.width, frame.height)
    }
}



public extension String {
    var isDirectory: Bool {
        var isDir: ObjCBool = false
        _ = FileManager.default.fileExists(atPath: self, isDirectory: &isDir)
        return isDir.boolValue
    }
}



public extension Formatter {
    static let withSeparator: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = NSLocale.current
        formatter.numberStyle = .decimal
        return formatter
    }()
}

public extension BinaryInteger {
    var formattedWithSeparator: String {
        return Formatter.withSeparator.string(for: self) ?? ""
    }
}


public extension String {
    var persistentHashValue: UInt64 {
        var result = UInt64 (5381)
        let buf = [UInt8](self.utf8)
        for b in buf {
            result = 127 * (result & 0x00ffffffffffffff) + UInt64(b)
        }
        return result
    }
}
extension NSEdgeInsets : Equatable {
    public static func ==(lhs: NSEdgeInsets, rhs: NSEdgeInsets) -> Bool {
        return lhs.left == rhs.left && lhs.right == rhs.right && lhs.bottom == rhs.bottom && lhs.top == rhs.top
    }
    public var isEmpty: Bool {
        return self.left == 0 && self.right == 0 && self.top == 0 && self.bottom == 0
    }
}


public func arc4random64() -> Int64 {
    return Int64.random(in: Int64.min ... Int64.max)
}


public func performSubviewRemoval(_ view: NSView, animated: Bool, duration: Double = 0.2, timingFunction: CAMediaTimingFunctionName = .easeOut, checkCompletion: Bool = false, scale: Bool = false, scaleTo: CGFloat? = nil, completed:((Bool)->Void)? = nil) {
    if animated {
        let from = view.layer?.presentation()?.opacity ?? view.layer?.opacity ?? 1
        view.layer?.animateAlpha(from: CGFloat(from), to: 0, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak view] finish in
            completed?(finish)
            if checkCompletion {
                if finish {
                    view?.removeFromSuperview()
                }
            } else {
                view?.removeFromSuperview()
            }
        })
        if scale {
            view.layer?.animateScaleCenter(from: 1, to: 0.01, duration: duration, removeOnCompletion: false, timingFunction: timingFunction)
        } else if let scaleTo = scaleTo {
            view.layer?.animateScaleCenter(from: 1, to: scaleTo, duration: duration, removeOnCompletion: false, timingFunction: timingFunction)
        }
    } else {
        view.removeFromSuperview()
    }
}

public func performSublayerRemoval(_ view: CALayer, animated: Bool, duration: Double = 0.2, timingFunction: CAMediaTimingFunctionName = .easeOut, checkCompletion: Bool = false, scale: Bool = false, scaleTo: CGFloat? = nil, completed:((Bool)->Void)? = nil) {
    if animated {
        view.animateAlpha(from: CGFloat(view.opacity), to: 0, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak view] finish in
            completed?(finish)
            if checkCompletion {
                if finish {
                    view?.removeFromSuperlayer()
                }
            } else {
                view?.removeFromSuperlayer()
            }
        })
        if scale {
            view.animateScale(from: 1, to: 0.01, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
        } else if let scaleTo = scaleTo {
            view.animateScale(from: 1, to: scaleTo, duration: duration, timingFunction: timingFunction, removeOnCompletion: false)
        }
    } else {
        view.removeFromSuperlayer()
    }
}

public func performSubviewPosRemoval(_ view: NSView, pos: NSPoint, animated: Bool, duration: Double = 0.2, timingFunction: CAMediaTimingFunctionName = .easeInEaseOut) {
    if animated {
        view.layer?.animatePosition(from: view.frame.origin, to: pos, duration: duration, timingFunction: timingFunction, removeOnCompletion: false, completion: { [weak view] _ in
            view?.removeFromSuperview()
        })
    } else {
        view.removeFromSuperview()
    }
}

public extension NSView {
    override class func accessibilityFocusedUIElement() -> Any? {
        return nil
    }
}



extension CGPoint {
    public init(vector: CGVector) {
        self.init(x: vector.dx, y: vector.dy)
    }
    
    
    public init(angle: CGFloat) {
        self.init(x: cos(angle), y: sin(angle))
    }
    
    
    public mutating func offset(dx: CGFloat, dy: CGFloat) -> CGPoint {
        x += dx
        y += dy
        return self
    }
    
    public func length() -> CGFloat {
        return sqrt(x*x + y*y)
    }
    
    public func lengthSquared() -> CGFloat {
        return x*x + y*y
    }
    
    func normalized() -> CGPoint {
        let len = length()
        return len>0 ? self / len : CGPoint.zero
    }
    
    public mutating func normalize() -> CGPoint {
        self = normalized()
        return self
    }
    
    public func distanceTo(_ point: CGPoint) -> CGFloat {
        return (self - point).length()
    }
    
    public var angle: CGFloat {
        return atan2(y, x)
    }
    
    public var cgSize: CGSize {
        return CGSize(width: x, height: y)
    }
    
    func rotate(origin: CGPoint, angle: CGFloat) -> CGPoint {
        let point = self - origin
        let s = sin(angle)
        let c = cos(angle)
        return CGPoint(x: c * point.x - s * point.y,
                       y: s * point.x + c * point.y) + origin
    }
}

public extension CGSize {
    var cgPoint: CGPoint {
        return CGPoint(x: width, y: height)
    }
    
    init(point: CGPoint) {
        self.init(width: point.x, height: point.y)
    }
    
    func centered(around position: CGPoint) -> CGRect {
        return CGRect(origin: CGPoint(x: position.x - self.width / 2.0, y: position.y - self.height / 2.0), size: self)
    }
    
    func centered(in rect: CGRect) -> CGRect {
        let origin = CGPoint(
            x: rect.origin.x + (rect.width - self.width) / 2,
            y: rect.origin.y + (rect.height - self.height) / 2
        )
        return CGRect(origin: origin, size: self)
    }

}

public func + (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

public func += (left: inout CGPoint, right: CGPoint) {
    left = left + right
}

public func + (left: CGPoint, right: CGVector) -> CGPoint {
    return CGPoint(x: left.x + right.dx, y: left.y + right.dy)
}

public func += (left: inout CGPoint, right: CGVector) {
    left = left + right
}

public func - (left: CGPoint, right: CGPoint) -> CGPoint { return CGPoint(x: left.x - right.x, y: left.y - right.y) }
public func - (left: CGSize, right: CGSize) -> CGSize { return CGSize(width: left.width - right.width, height: left.height - right.height) }
public func - (left: CGSize, right: CGPoint) -> CGSize { return CGSize(width: left.width - right.x, height: left.height - right.x) }
public func - (left: CGPoint, right: CGSize) -> CGPoint { return CGPoint(x: left.x - right.width, y: left.y - right.height) }

public func -= (left: inout CGPoint, right: CGPoint) {
    left = left - right
}

public func - (left: CGPoint, right: CGVector) -> CGPoint {
    return CGPoint(x: left.x - right.dx, y: left.y - right.dy)
}

public func -= (left: inout CGPoint, right: CGVector) {
    left = left - right
}

public func *= (left: inout CGPoint, right: CGPoint) {
    left = left * right
}

public func * (point: CGPoint, scalar: CGFloat) -> CGPoint { return CGPoint(x: point.x * scalar, y: point.y * scalar) }
public func * (point: CGSize, scalar: CGFloat) -> CGSize { return CGSize(width: point.width * scalar, height: point.height * scalar) }

public func *= (point: inout CGPoint, scalar: CGFloat) { point = point * scalar }

public func * (left: CGPoint, right: CGVector) -> CGPoint {
    return CGPoint(x: left.x * right.dx, y: left.y * right.dy)
}

public func *= (left: inout CGPoint, right: CGVector) {
    left = left * right
}

public func / (left: CGPoint, right: CGPoint) -> CGPoint { return CGPoint(x: left.x / right.x, y: left.y / right.y) }
public func / (left: CGSize, right: CGSize) -> CGSize { return CGSize(width: left.width / right.width, height: left.height / right.height) }
public func / (left: CGPoint, right: CGSize) -> CGPoint { return CGPoint(x: left.x / right.width, y: left.y / right.height) }
public func / (left: CGSize, right: CGPoint) -> CGSize { return CGSize(width: left.width / right.x, height: left.height / right.y) }
public func /= (left: inout CGPoint, right: CGPoint) { left = left / right }
public func /= (left: inout CGSize, right: CGSize) { left = left / right }
public func /= (left: inout CGSize, right: CGPoint) { left = left / right }
public func /= (left: inout CGPoint, right: CGSize) { left = left / right }


public func / (point: CGPoint, scalar: CGFloat) -> CGPoint { return CGPoint(x: point.x / scalar, y: point.y / scalar) }
public func / (point: CGSize, scalar: CGFloat) -> CGSize { return CGSize(width: point.width / scalar, height: point.height / scalar) }

public func /= (point: inout CGPoint, scalar: CGFloat) {
    point = point / scalar
}

public func / (left: CGPoint, right: CGVector) -> CGPoint {
    return CGPoint(x: left.x / right.dx, y: left.y / right.dy)
}

public func / (left: CGSize, right: CGVector) -> CGSize {
    return CGSize(width: left.width / right.dx, height: left.height / right.dy)
}

public func /= (left: inout CGPoint, right: CGVector) {
    left = left / right
}

public func * (left: CGPoint, right: CGPoint) -> CGPoint { return CGPoint(x: left.x * right.x, y: left.y * right.y) }
public func * (left: CGPoint, right: CGSize) -> CGPoint { return CGPoint(x: left.x * right.width, y: left.y * right.height) }
public func *= (left: inout CGPoint, right: CGSize) { left = left * right }
public func * (left: CGSize, right: CGSize) -> CGSize { return CGSize(width: left.width * right.width, height: left.height * right.height) }
public func *= (left: inout CGSize, right: CGSize) { left = left * right }
public func * (left: CGSize, right: CGPoint) -> CGSize { return CGSize(width: left.width * right.x, height: left.height * right.y) }
public func *= (left: inout CGSize, right: CGPoint) { left = left * right }


public func lerp(start: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
    return start + (end - start) * t
}

public func abs(_ point: CGPoint) -> CGPoint {
    return CGPoint(x: abs(point.x), y: abs(point.y))
}

extension CGSize {
    var isValid: Bool {
        return width > 0 && height > 0 && width != .infinity && height != .infinity && width != .nan && height != .nan
    }
    
    var ratio: CGFloat {
        return width / height
    }
}


public extension CGRect {
    static var identity: CGRect {
        return CGRect(x: 0, y: 0, width: 1, height: 1)
    }
    
    var rounded: CGRect {
        return CGRect(x: origin.x.rounded(),
                      y: origin.y.rounded(),
                      width: width.rounded(.up),
                      height: height.rounded(.up))
    }
    
    var toScreenPixel: CGRect {
        return CGRect(x: floorToScreenPixels(origin.x),
                      y: floorToScreenPixels(origin.y),
                      width: floorToScreenPixels(width),
                      height: floorToScreenPixels(height))
    }
    
    var mirroredVertically: CGRect {
        return CGRect(x: origin.x,
                      y: 1.0 - (origin.y + height),
                      width: width,
                      height: height)
    }
}

extension CGAffineTransform {
    func inverted(with size: CGSize) -> CGAffineTransform {
        var transform = self
        let transformedSize = CGRect(origin: .zero, size: size).applying(transform).size
        transform.tx /= transformedSize.width;
        transform.ty /= transformedSize.height;
        transform = transform.inverted()
        transform.tx *= transformedSize.width;
        transform.ty *= transformedSize.height;
        return transform
    }
}


public extension CGFloat {
    func rounded(toPlaces places:Int) -> CGFloat {
        let divisor = pow(10.0, CGFloat(places))
        return (self * divisor).rounded() / divisor
    }
}



public func generateRoundedRectWithTailPath(rectSize: CGSize, cornerRadius: CGFloat? = nil, tailSize: CGSize = CGSize(width: 20.0, height: 9.0), tailRadius: CGFloat = 4.0, tailPosition: CGFloat? = 0.5, transformTail: Bool = true) -> CGPath {
    let cornerRadius: CGFloat = cornerRadius ?? rectSize.height / 2.0
    let tailWidth: CGFloat = tailSize.width
    let tailHeight: CGFloat = tailSize.height

    let rect = CGRect(origin: CGPoint(x: 0.0, y: tailHeight), size: rectSize)
    
    guard let tailPosition = tailPosition else {
        return CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    }

    let cutoff: CGFloat = 0.27
    
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))

    var leftArcEndAngle: CGFloat = .pi / 2.0
    var leftConnectionArcRadius = tailRadius
    var tailLeftHalfWidth: CGFloat = tailWidth / 2.0
    var tailLeftArcStartAngle: CGFloat = -.pi / 4.0
    var tailLeftHalfRadius = tailRadius
    
    var rightArcStartAngle: CGFloat = -.pi / 2.0
    var rightConnectionArcRadius = tailRadius
    var tailRightHalfWidth: CGFloat = tailWidth / 2.0
    var tailRightArcStartAngle: CGFloat = .pi / 4.0
    var tailRightHalfRadius = tailRadius
    
    if transformTail {
        if tailPosition < 0.5 {
            let fraction = max(0.0, tailPosition - 0.15) / 0.35
            leftArcEndAngle *= fraction
            
            let connectionFraction = max(0.0, tailPosition - 0.35) / 0.15
            leftConnectionArcRadius *= connectionFraction
            
            if tailPosition < cutoff {
                let fraction = tailPosition / cutoff
                tailLeftHalfWidth *= fraction
                tailLeftArcStartAngle *= fraction
                tailLeftHalfRadius *= fraction
            }
        } else if tailPosition > 0.5 {
            let tailPosition = 1.0 - tailPosition
            let fraction = max(0.0, tailPosition - 0.15) / 0.35
            rightArcStartAngle *= fraction
            
            let connectionFraction = max(0.0, tailPosition - 0.35) / 0.15
            rightConnectionArcRadius *= connectionFraction
            
            if tailPosition < cutoff {
                let fraction = tailPosition / cutoff
                tailRightHalfWidth *= fraction
                tailRightArcStartAngle *= fraction
                tailRightHalfRadius *= fraction
            }
        }
    }
    
    path.addArc(
        center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
        radius: cornerRadius,
        startAngle: .pi,
        endAngle: .pi + max(0.0001, leftArcEndAngle),
        clockwise: true
    )

    let leftArrowStart = max(rect.minX, rect.minX + rectSize.width * tailPosition - tailLeftHalfWidth - leftConnectionArcRadius)
    path.addArc(
        center: CGPoint(x: leftArrowStart, y: rect.minY - leftConnectionArcRadius),
        radius: leftConnectionArcRadius,
        startAngle: .pi / 2.0,
        endAngle: .pi / 4.0,
        clockwise: false
    )

    path.addLine(to: CGPoint(x: max(rect.minX, rect.minX + rectSize.width * tailPosition - tailLeftHalfRadius), y: rect.minY - tailHeight))

    path.addArc(
        center: CGPoint(x: rect.minX + rectSize.width * tailPosition, y: rect.minY - tailHeight + tailRadius / 2.0),
        radius: tailRadius,
        startAngle: -.pi / 2.0 + tailLeftArcStartAngle,
        endAngle: -.pi / 2.0 + tailRightArcStartAngle,
        clockwise: true
    )
    
    path.addLine(to: CGPoint(x: min(rect.maxX, rect.minX + rectSize.width * tailPosition + tailRightHalfRadius), y: rect.minY - tailHeight))

    let rightArrowStart = min(rect.maxX, rect.minX + rectSize.width * tailPosition + tailRightHalfWidth + rightConnectionArcRadius)
    path.addArc(
        center: CGPoint(x: rightArrowStart, y: rect.minY - rightConnectionArcRadius),
        radius: rightConnectionArcRadius,
        startAngle: .pi - .pi / 4.0,
        endAngle: .pi / 2.0,
        clockwise: false
    )

    path.addArc(
        center: CGPoint(x: rect.minX + rectSize.width - cornerRadius, y: rect.minY + cornerRadius),
        radius: cornerRadius,
        startAngle: min(-0.0001, rightArcStartAngle),
        endAngle: 0.0,
        clockwise: true
    )

    path.addLine(to: CGPoint(x: rect.minX + rectSize.width, y: rect.minY + rectSize.height - cornerRadius))

    path.addArc(
        center: CGPoint(x: rect.minX + rectSize.width - cornerRadius, y: rect.minY + rectSize.height - cornerRadius),
        radius: cornerRadius,
        startAngle: 0.0,
        endAngle: .pi / 2.0,
        clockwise: true
    )

    path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + rectSize.height))

    path.addArc(
        center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + rectSize.height - cornerRadius),
        radius: cornerRadius,
        startAngle: .pi / 2.0,
        endAngle: .pi,
        clockwise: true
    )
    
    return path
}


public extension FileManager {
    
    func modificationDateForFileAtPath(path:String) -> NSDate? {
        guard let attributes = try? self.attributesOfItem(atPath: path) else { return nil }
        return attributes[.modificationDate] as? NSDate
    }
    
    func creationDateForFileAtPath(path:String) -> NSDate? {
        guard let attributes = try? self.attributesOfItem(atPath: path) else { return nil }
        return attributes[.creationDate] as? NSDate
    }
    
    
}




public extension NSCursor  {
    static var set_windowResizeNorthWestSouthEastCursor: NSCursor? {
        return ObjcUtils.windowResizeNorthWestSouthEastCursor()
    }
    static var set_windowResizeNorthEastSouthWestCursor: NSCursor? {
        return ObjcUtils.windowResizeNorthEastSouthWestCursor()
    }
}

public extension NSImage {
    var _cgImage: CGImage? {
        return self.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
    
    var jpegCGImage: CGImage? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImageRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        let compressionFactor: CGFloat = 1.0
        
        guard let jpegData = bitmapImageRep.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor]),
              let dataProvider = CGDataProvider(data: jpegData as CFData),
              let cgImage = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
            return nil
        }
        
        return cgImage
    }
}


public func truncate(double: Double, places : Int)-> Double
{
    return Double(floor(pow(10.0, Double(places)) * double)/pow(10.0, Double(places)))
}


public extension NSImage {
    
    enum Orientation {
        case up
        case down
    }
    
    convenience init(cgImage: CGImage, scale: CGFloat, orientation: UIImage.Orientation) {
        self.init(cgImage: cgImage, size: cgImage.systemSize)
    }
}



public extension CGImage {
    var cvPixelBuffer: CVPixelBuffer? {
        let cgImage = self

        var maybePixelBuffer: CVPixelBuffer? = nil
        let ioSurfaceProperties = NSMutableDictionary()
        let options = NSMutableDictionary()
        options.setObject(ioSurfaceProperties, forKey: kCVPixelBufferIOSurfacePropertiesKey as NSString)

        let _ = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width * self.scale), Int(size.height * self.scale), kCVPixelFormatType_32ARGB, options as CFDictionary, &maybePixelBuffer)
        guard let pixelBuffer = maybePixelBuffer else {
            return nil
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        }

        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)

        let context = CGContext(
            data: baseAddress,
            width: Int(self.size.width * self.scale),
            height: Int(self.size.height * self.scale),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue,
            releaseCallback: nil,
            releaseInfo: nil
        )!
        context.clear(CGRect(origin: .zero, size: CGSize(width: self.size.width * self.scale, height: self.size.height * self.scale)))
        context.draw(cgImage, in: CGRect(origin: .zero, size: CGSize(width: self.size.width * self.scale, height: self.size.height * self.scale)))

        return pixelBuffer
    }

    
    var cmSampleBuffer: CMSampleBuffer? {
           guard let pixelBuffer = self.cvPixelBuffer else {
               return nil
           }
           var newSampleBuffer: CMSampleBuffer? = nil

           var timingInfo = CMSampleTimingInfo(
               duration: CMTimeMake(value: 1, timescale: 30),
               presentationTimeStamp: CMTimeMake(value: 0, timescale: 30),
               decodeTimeStamp: CMTimeMake(value: 0, timescale: 30)
           )

           var videoInfo: CMVideoFormatDescription? = nil
           CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &videoInfo)
           guard let videoInfo = videoInfo else {
               return nil
           }
           CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: videoInfo, sampleTiming: &timingInfo, sampleBufferOut: &newSampleBuffer)

           if let newSampleBuffer = newSampleBuffer {
               let attachments = CMSampleBufferGetSampleAttachmentsArray(newSampleBuffer, createIfNecessary: true)! as NSArray
               let dict = attachments[0] as! NSMutableDictionary

               dict.setValue(kCFBooleanTrue as AnyObject, forKey: kCMSampleAttachmentKey_DisplayImmediately as NSString as String)
           }

           return newSampleBuffer
       }

}


public func mapRange(_ x: Double, inMin: Double, inMax: Double, outMin: Double, outMax: Double) -> Double {
    let slope = (outMax - outMin) / (inMax - inMin)
    return outMin + slope * (x - inMin)
}



public final class TransformImageResult {
    public let image: CGImage?
    public let highQuality: Bool
    public let sampleBuffer: CMSampleBuffer?
    public init(_ image: CGImage?, _ highQuality: Bool, _ sampleBuffer: CMSampleBuffer? = nil) {
        self.image = image
        self.sampleBuffer = sampleBuffer
        self.highQuality = highQuality
    }
    deinit {
        
    }
}

public func deg2rad(_ number: Float) -> Float {
    return number * .pi / 180
}

public func rad2deg(_ number: Float) -> Float {
    return number * 180.0 / .pi
}


public extension NSAttributedString {
    var smallDecemial: NSAttributedString {
        let range = self.string.nsstring.range(of: ".")
        if range.location != NSNotFound {
            let attr = self.mutableCopy() as! NSMutableAttributedString
            
            let font = attr.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
            if let font = font, let updated = NSFont(name: font.fontName, size: font.pointSize / 1.5) {
                attr.addAttribute(.font, value: updated, range: NSMakeRange(range.location, attr.range.length - range.lowerBound))
            }
            return attr

        } else {
            return self
        }
    }
}


public extension CGPath {
    
    static func rounded(frame: NSRect, cornerRadius: CGFloat, rectCorner: NSRectCorner) -> CGPath {
        
        let path = CGMutablePath()
        
        let minx:CGFloat = frame.minX, midx = frame.maxX/2.0, maxx = frame.maxX
        let miny:CGFloat = frame.maxY, midy = frame.maxY/2.0, maxy: CGFloat = 0
        
        path.move(to: NSMakePoint(minx, midy))
        
        var topLeftRadius: CGFloat = 0
        var bottomLeftRadius: CGFloat = 0
        var topRightRadius: CGFloat = 0
        var bottomRightRadius: CGFloat = 0
        
        
        if rectCorner.contains(.topLeft) {
            topLeftRadius = cornerRadius
        }
        if rectCorner.contains(.topRight) {
            topRightRadius = cornerRadius
        }
        if rectCorner.contains(.bottomLeft) {
            bottomLeftRadius = cornerRadius
        }
        if rectCorner.contains(.bottomRight) {
            bottomRightRadius = cornerRadius
        }
        
        
        path.addArc(tangent1End: NSMakePoint(minx, miny), tangent2End: NSMakePoint(midx, miny), radius: bottomLeftRadius)
        path.addArc(tangent1End: NSMakePoint(maxx, miny), tangent2End: NSMakePoint(maxx, midy), radius: bottomRightRadius)
        path.addArc(tangent1End: NSMakePoint(maxx, maxy), tangent2End: NSMakePoint(midx, maxy), radius: topRightRadius)
        path.addArc(tangent1End: NSMakePoint(minx, maxy), tangent2End: NSMakePoint(minx, midy), radius: topLeftRadius)
        
        if rectCorner.contains(.topLeft) {
             path.move(to: NSMakePoint(minx, cornerRadius))
        } else {
             path.move(to: NSMakePoint(minx, maxy))
        }
       
        path.addLine(to: NSMakePoint(minx, midy))
        
        return path
    }
    
}


public func fontSizeThatFits(text: String, in rect: CGRect, initialFont: NSFont, minFontSize: CGFloat = 5.0) -> NSFont {
    var fontSize = initialFont.pointSize
    var currentFont = initialFont

    // Create an attributed string to measure
    let attributedText = NSMutableAttributedString(string: text, attributes: [.font: currentFont])

    // Measure the text size with the current font
    var textSize = attributedText.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: rect.height), options: .usesLineFragmentOrigin, context: nil)

    // Reduce the font size until it fits within the rect's width or reaches the minimum size
    while textSize.width > rect.width && fontSize > minFontSize {
        fontSize -= 1
        currentFont = NSFont(name: initialFont.fontName, size: fontSize) ?? initialFont
        attributedText.addAttribute(.font, value: currentFont, range: NSRange(location: 0, length: attributedText.length))
        textSize = attributedText.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: rect.height), options: .usesLineFragmentOrigin, context: nil)
    }

    return currentFont
}


public func extractHashtagAndUsername(from query: String) -> (hashtag: String, username: String)? {
    // Regular expression to match hashtag followed by username
    let pattern = "^([#$])([a-zA-Z0-9_]+)@([a-zA-Z0-9_]+)$"
       
       // Create regular expression object
       guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
       
       // Search for matches
       let matches = regex.matches(in: query, range: NSRange(query.startIndex..., in: query))
       
       // Ensure we have a match
       guard let match = matches.first, match.numberOfRanges == 4 else { return nil }
       
       // Extract symbol (# or $), tag, and username from the match
       if let symbolRange = Range(match.range(at: 1), in: query),
          let tagRange = Range(match.range(at: 2), in: query),
          let usernameRange = Range(match.range(at: 3), in: query) {
           
           let symbol = String(query[symbolRange])
           let tag = String(query[tagRange])
           let fullTag = symbol + tag
           let username = String(query[usernameRange])
           
           return (fullTag, username)
       }
       
       return nil
}
public func extractAnchor(from text: String, matching url: String) -> String? {
    // Escape the URL to safely use it in a regex
    let escapedURL = NSRegularExpression.escapedPattern(for: url)
    
    // Regular expression pattern to match the given URL with optional anchor (#)
    let pattern = "\(escapedURL)(#[a-zA-Z0-9_-]+)?"
    
    // Create regular expression object
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    
    // Search for matches in the text
    let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
    
    // Ensure there is at least one match
    guard let match = matches.first else { return nil }
    
    // Extract the anchor if it exists (the part after #)
    if match.numberOfRanges > 1, let anchorRange = Range(match.range(at: 1), in: text) {
        return String(text[anchorRange].dropFirst()) // Drop the # symbol
    }
    
    // If no anchor is found, return nil
    return nil
}


public func formatMonthYear(_ dateString: String, locale: Locale = .current) -> String? {
    // Create date formatter for parsing input
    let inputFormatter = DateFormatter()
    inputFormatter.dateFormat = "MM.yyyy"
    
    // Try to parse the input string to date
    guard let date = inputFormatter.date(from: dateString) else {
        return nil
    }
    
    // Create formatter for output
    let outputFormatter = DateFormatter()
    outputFormatter.locale = locale
    outputFormatter.setLocalizedDateFormatFromTemplate("MMM yyyy")
    
    return outputFormatter.string(from: date)
}


public func escapeMarkdownSpecialCharacters(in text: String) -> String {
    return text
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "[", with: "\\[")
        .replacingOccurrences(of: "]", with: "\\]")
        .replacingOccurrences(of: "(", with: "\\(")
        .replacingOccurrences(of: ")", with: "\\)")
}


public extension CGMutablePath {
    func addRoundedRect(in rect: CGRect, topLeft: Bool, topRight: Bool, bottomLeft: Bool, bottomRight: Bool, radius: CGFloat) {
        let maxRadius = min(radius, min(rect.width, rect.height) / 2)

        let tl = topLeft ? maxRadius : 0
        let tr = topRight ? maxRadius : 0
        let bl = bottomLeft ? maxRadius : 0
        let br = bottomRight ? maxRadius : 0

        self.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))

        // Bottom line
        self.addLine(to: CGPoint(x: rect.maxX - bl, y: rect.minY))
        if bl > 0 {
            self.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + bl),
                              control: CGPoint(x: rect.maxX, y: rect.minY))
        }

        // Right line
        self.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - tr))
        if tr > 0 {
            self.addQuadCurve(to: CGPoint(x: rect.maxX - tr, y: rect.maxY),
                              control: CGPoint(x: rect.maxX, y: rect.maxY))
        }

        // Top line
        self.addLine(to: CGPoint(x: rect.minX + tl, y: rect.maxY))
        if tl > 0 {
            self.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - tl),
                              control: CGPoint(x: rect.minX, y: rect.maxY))
        }

        // Left line
        self.addLine(to: CGPoint(x: rect.minX, y: rect.minY + bl))
        if bl > 0 {
            self.addQuadCurve(to: CGPoint(x: rect.minX + bl, y: rect.minY),
                              control: CGPoint(x: rect.minX, y: rect.minY))
        }

        self.closeSubpath()
    }
}
