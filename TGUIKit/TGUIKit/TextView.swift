//
//  TextView.swift
//  TGUIKit
//
//  Created by keepcoder on 15/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public final class TextViewInteractions {
    public var processURL:(Any!)->Void // link, isPresent
    
    public init(processURL:@escaping (Any!)->Void = {_ in}) {
        self.processURL = processURL
    }
}

public final class TextViewLine {
    public let line: CTLine
    public let frame: NSRect
    
    init(line: CTLine, frame: CGRect) {
        self.line = line
        self.frame = frame
    }
    
}

public enum TextViewCutoutPosition {
    case TopLeft
    case TopRight
}

public struct TextViewCutout: Equatable {
    public let position: TextViewCutoutPosition
    public let size: NSSize
    public init(position:TextViewCutoutPosition, size:NSSize) {
        self.position = position
        self.size = size
    }
}

public func ==(lhs: TextViewCutout, rhs: TextViewCutout) -> Bool {
    return lhs.position == rhs.position && lhs.size == rhs.size
}

private let defaultFont:NSFont = .normal(.text)

public final class TextViewLayout : Equatable {
    
    
    public fileprivate(set) var attributedString:NSAttributedString
    public fileprivate(set) var constrainedWidth:CGFloat = 0
    public var interactions:TextViewInteractions = TextViewInteractions()
    public var selectedRange:TextSelectedRange = TextSelectedRange()
    public var penFlush:CGFloat
    public var insets:NSSize = NSZeroSize
    public fileprivate(set) var lines:[TextViewLine] = []
    public fileprivate(set) var isPerfectSized:Bool = true
    public let maximumNumberOfLines:Int32
    public let truncationType:CTLineTruncationType
    public var cutout:TextViewCutout?
    
    public fileprivate(set) var lineSpacing:CGFloat?
    
    public private(set) var layoutSize:NSSize = NSZeroSize
    public private(set) var perfectSize:NSSize = NSZeroSize
    public init(_ attributedString:NSAttributedString, constrainedWidth:CGFloat = 0, maximumNumberOfLines:Int32 = INT32_MAX, truncationType: CTLineTruncationType = .end, cutout:TextViewCutout? = nil, alignment:NSTextAlignment = .left, lineSpacing:CGFloat? = nil) {
        self.truncationType = truncationType
        self.maximumNumberOfLines = maximumNumberOfLines
        self.cutout = cutout
        self.attributedString = attributedString
        self.constrainedWidth = constrainedWidth
        
        switch alignment {
        case .center:
            penFlush = 0.5
        case .right:
            penFlush = 1.0
        default:
            penFlush = 0.0
        }
        self.lineSpacing = lineSpacing
    }
    
    func calculateLayout() -> Void {
        
        isPerfectSized = true
        
        let font: CTFont
        if attributedString.length != 0 {
            if let stringFont = attributedString.attribute(kCTFontAttributeName as String, at: 0, effectiveRange: nil) {
                font = stringFont as! CTFont
            } else {
                font = defaultFont
            }
        } else {
            font = defaultFont
        }
        
        self.lines.removeAll()
        
        let fontAscent = CTFontGetAscent(font)
        let fontDescent = CTFontGetDescent(font)
        let fontLineHeight = floor(fontAscent + fontDescent)
        
        let fontLineSpacing:CGFloat
        if let lineSpacing = lineSpacing {
            fontLineSpacing = lineSpacing
        } else {
            fontLineSpacing = floor(fontLineHeight * 0.12)
        }
        
        var maybeTypesetter: CTTypesetter?
        maybeTypesetter = CTTypesetterCreateWithAttributedString(attributedString as CFAttributedString)
        
        let typesetter = maybeTypesetter!
        
        var lastLineCharacterIndex: CFIndex = 0
        var layoutSize = NSSize()
        
        var cutoutEnabled = false
        var cutoutMinY: CGFloat = 0.0
        var cutoutMaxY: CGFloat = 0.0
        var cutoutWidth: CGFloat = 0.0
        var cutoutOffset: CGFloat = 0.0
        if let cutout = cutout {
            cutoutMinY = -fontLineSpacing
            cutoutMaxY = cutout.size.height + fontLineSpacing
            cutoutWidth = cutout.size.width
            if case .TopLeft = cutout.position {
                cutoutOffset = cutoutWidth
            }
            cutoutEnabled = true
        }
        
        var first = true
        while true {
            var lineConstrainedWidth = constrainedWidth
            var lineOriginY = floor(layoutSize.height + fontLineHeight - fontLineSpacing * 2.0)
            if !first {
                lineOriginY += fontLineSpacing
            }
            var lineCutoutOffset: CGFloat = 0.0
            var lineAdditionalWidth: CGFloat = 0.0
            
            if cutoutEnabled {
                if lineOriginY < cutoutMaxY && lineOriginY + fontLineHeight > cutoutMinY {
                    lineConstrainedWidth = max(1.0, lineConstrainedWidth - cutoutWidth)
                    lineCutoutOffset = cutoutOffset
                    lineAdditionalWidth = cutoutWidth
                }
            }
            
            let lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, lastLineCharacterIndex, Double(lineConstrainedWidth))
            
            if maximumNumberOfLines != 0 && lines.count == maximumNumberOfLines - 1 && lineCharacterCount > 0 {
                if first {
                    first = false
                } else {
                    layoutSize.height += fontLineSpacing
                }
                
                let coreTextLine: CTLine
                
                let originalLine = CTTypesetterCreateLineWithOffset(typesetter, CFRange(location: lastLineCharacterIndex, length: attributedString.length - lastLineCharacterIndex), 0.0)
                
                if CTLineGetTypographicBounds(originalLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(originalLine) < Double(constrainedWidth) {
                    coreTextLine = originalLine
                } else {
                    var truncationTokenAttributes: [String : AnyObject] = [:]
                    truncationTokenAttributes[kCTFontAttributeName as String] = font
                    truncationTokenAttributes[kCTForegroundColorFromContextAttributeName as String] = true as NSNumber
                    let tokenString = "\u{2026}"
                    let truncatedTokenString = NSAttributedString(string: tokenString, attributes: truncationTokenAttributes)
                    let truncationToken = CTLineCreateWithAttributedString(truncatedTokenString)
                    
                    coreTextLine = CTLineCreateTruncatedLine(originalLine, Double(constrainedWidth), truncationType, truncationToken) ?? truncationToken
                    isPerfectSized = false
                }
                
                let lineWidth = ceil(CGFloat(CTLineGetTypographicBounds(coreTextLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(coreTextLine)))
                let lineFrame = CGRect(x: lineCutoutOffset, y: lineOriginY, width: lineWidth, height: fontLineHeight)
                layoutSize.height += fontLineHeight + fontLineSpacing
                layoutSize.width = max(layoutSize.width, lineWidth + lineAdditionalWidth)
                
                lines.append(TextViewLine(line: coreTextLine, frame: lineFrame))
                
                break
            } else {
                if lineCharacterCount > 0 {
                    if first {
                        first = false
                    } else {
                        layoutSize.height += fontLineSpacing
                    }
                    
                    let coreTextLine = CTTypesetterCreateLineWithOffset(typesetter, CFRangeMake(lastLineCharacterIndex, lineCharacterCount), 100.0)
                    lastLineCharacterIndex += lineCharacterCount
                    
                    let lineWidth = ceil(CGFloat(CTLineGetTypographicBounds(coreTextLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(coreTextLine)))
                    let lineFrame = CGRect(x: lineCutoutOffset, y: lineOriginY, width: lineWidth, height: fontLineHeight)
                    layoutSize.height += fontLineHeight
                    layoutSize.width = max(layoutSize.width, lineWidth + lineAdditionalWidth)
                    
                    
                    lines.append(TextViewLine(line: coreTextLine, frame: lineFrame))
                } else {
                    if !lines.isEmpty {
                        layoutSize.height += fontLineSpacing
                    }
                    break
                }
            }
            
        }
        
        self.layoutSize = layoutSize
    }
    
    public func measure(width: CGFloat = 0) -> Void {
        
        if width != 0 {
            constrainedWidth = width
        }
        calculateLayout()

    }
    
    public func clearSelect() {
        self.selectedRange.range = NSMakeRange(NSNotFound, 0)
    }
    
    public func selectedRange(startPoint:NSPoint, currentPoint:NSPoint) -> NSRange {
        
        var selectedRange:NSRange = NSMakeRange(NSNotFound, 0)
        
        if (currentPoint.x != -1 && currentPoint.y != -1 && !lines.isEmpty) {
            
            
            let startSelectLineIndex = findIndex(location: startPoint)
            let currentSelectLineIndex = findIndex(location: currentPoint)
            let dif = abs(startSelectLineIndex - currentSelectLineIndex)
            let isReversed = currentSelectLineIndex < startSelectLineIndex
            var i = startSelectLineIndex
            while isReversed ? i >= currentSelectLineIndex : i <= currentSelectLineIndex {
                let line = lines[i].line
                let lineRange = CTLineGetStringRange(line)
                var startIndex: CFIndex = CTLineGetStringIndexForPosition(line, startPoint)
                var endIndex: CFIndex = CTLineGetStringIndexForPosition(line, currentPoint)
                if dif > 0 {
                    if i != currentSelectLineIndex {
                        endIndex = (lineRange.length + lineRange.location)
                    }
                    if i != startSelectLineIndex {
                        startIndex = lineRange.location
                    }
                    if isReversed {
                        if i == startSelectLineIndex {
                            endIndex = startIndex
                            startIndex = lineRange.location
                        }
                        if i == currentSelectLineIndex {
                            startIndex = endIndex
                            endIndex = (lineRange.length + lineRange.location)
                        }
                    }
                }
                if startIndex > endIndex {
                    startIndex = endIndex + startIndex
                    endIndex = startIndex - endIndex
                    startIndex = startIndex - endIndex
                }
                if abs(Int(startIndex) - Int(endIndex)) > 0 && (selectedRange.location == NSNotFound || selectedRange.location > startIndex) {
                    selectedRange.location = startIndex
                }
                selectedRange.length += (endIndex - startIndex)
                i +=  isReversed ? -1 : 1
            }
        }
        return selectedRange
    }
    
    
    public func findIndex(location:NSPoint) -> Int {
        
        if location.y == .greatestFiniteMagnitude {
            return lines.count - 1
        } else if location.y == 0 {
            return 0
        }
        
        for idx in 0 ..< lines.count {
            if  isCurrentLine(pos: location, index: idx) {
                return idx
            }
        }
        
        return location.y <= layoutSize.height ? 0 : (lines.count - 1)
        
    }
    
    public func inSelectedRange(_ location:NSPoint) -> Bool {
        let index = findCharacterIndex(at: location)
        return selectedRange.range.location < index && selectedRange.range.location + selectedRange.range.length > index
    }
    
    public func isCurrentLine(pos:NSPoint, index:Int) -> Bool {
        
        let line = lines[index]
        var rect = line.frame
        
        var ascent:CGFloat = 0
        var descent:CGFloat = 0
        var leading:CGFloat = 0
        
        CTLineGetTypographicBounds(line.line, &ascent, &descent, &leading)
        
        rect.origin.y = rect.minY - rect.height + ceil(descent - leading)
        rect.size.height += ceil(descent - leading)
        
        return (pos.y > rect.minY) && pos.y < rect.maxY
        
    }

    public func link(at point:NSPoint) -> (Any, NSRect)? {
        
        let index = findIndex(location: point)
        
        guard index != -1 else {
            return nil
        }
        
        let line = lines[index]
        var ascent:CGFloat = 0
        var descent:CGFloat = 0
        var leading:CGFloat = 0
        
        let width:CGFloat = CGFloat(CTLineGetTypographicBounds(line.line, &ascent, &descent, &leading));
        
        if  width > point.x {
            var pos = CTLineGetStringIndexForPosition(line.line, point);
            pos = min(max(0,pos),attributedString.length - 1)
            var range:NSRange = NSMakeRange(NSNotFound, 0)
            let attrs = attributedString.attributes(at: pos, effectiveRange: &range)
            
            let link:Any? = attrs[NSLinkAttributeName]
            
            if let link = link {
                let startOffset = CTLineGetOffsetForStringIndex(line.line, range.location, nil);
                let endOffset = CTLineGetOffsetForStringIndex(line.line, range.location + range.length, nil);
                return (link, NSMakeRect(startOffset, line.frame.minY, endOffset - startOffset, ceil(ascent + ceil(descent) + leading)))
            }
        }
        return nil
    }
    
    func findCharacterIndex(at point:NSPoint) -> Int {
        let index = findIndex(location: point)
        
        guard index != -1 else {
            return -1
        }
        
        let line = lines[index]
        let width:CGFloat = CGFloat(CTLineGetTypographicBounds(line.line, nil, nil, nil));
        if width > point.x {
            let charIndex = Int(CTLineGetStringIndexForPosition(line.line, point))
            return charIndex == attributedString.length ? charIndex - 1 : charIndex
        }
        return -1
    }
    
    public func selectWord(at point:NSPoint) -> Void {
        let startIndex = findCharacterIndex(at: point)
        if startIndex == -1 {
            return
        }
        var prev = startIndex
        var next = startIndex
        var range = NSMakeRange(startIndex, 1)
        let char:NSString = attributedString.string.nsstring.substring(with: range) as NSString
        var effectiveRange:NSRange = NSMakeRange(NSNotFound, 0)
        let check = attributedString.attribute(NSLinkAttributeName, at: range.location, effectiveRange: &effectiveRange)
        if check != nil && effectiveRange.location != NSNotFound {
            self.selectedRange = TextSelectedRange(range: effectiveRange, color: .selectText, def: true)
            return
        }
        if char == "" {
            self.selectedRange = TextSelectedRange()
            return
        }
        let valid:Bool = char.trimmingCharacters(in: NSCharacterSet.alphanumerics) == ""
        let string:NSString = attributedString.string.nsstring
        while valid {
            let prevChar = string.substring(with: NSMakeRange(prev, 1))
            let nextChar = string.substring(with: NSMakeRange(next, 1))
            var prevValid:Bool = prevChar.trimmingCharacters(in: NSCharacterSet.alphanumerics) == ""
            var nextValid:Bool = nextChar.trimmingCharacters(in: NSCharacterSet.alphanumerics) == ""
            if (prevValid && prev > 0) {
                prev -= 1
            }
            if(nextValid && next < string.length - 1) {
                next += 1
            }
            range.location = prevValid ? prev : prev + 1;
            range.length =  next - range.location;
            if prev == 0 {
                prevValid = false
            }
            if(next == string.length - 1) {
                nextValid = false
                range.length += 1
            }
            if !prevValid && !nextValid {
                break
            }
            if prev == 0 && !nextValid {
                break
            }
        }
        
        self.selectedRange = TextSelectedRange(range: range, color: .selectText, def: true)
    }
    

}

public func ==(lhs:TextViewLayout, rhs:TextViewLayout) -> Bool {
    return lhs.constrainedWidth == rhs.constrainedWidth && lhs.attributedString.isEqual(to: rhs.attributedString) && lhs.selectedRange == rhs.selectedRange && lhs.maximumNumberOfLines == rhs.maximumNumberOfLines && lhs.cutout == rhs.cutout && lhs.truncationType == rhs.truncationType && lhs.constrainedWidth == rhs.constrainedWidth
}

public struct TextSelectedRange: Equatable {
    public var range:NSRange = NSMakeRange(NSNotFound, 0)
    public var color:NSColor = .selectText
    public var def:Bool = true
    
    public var hasSelectText:Bool {
        return range.location != NSNotFound
    }
}

public func ==(lhs:TextSelectedRange, rhs:TextSelectedRange) -> Bool {
    return lhs.def == rhs.def && lhs.range.location == rhs.range.location && lhs.range.length == rhs.range.length
}


public class TextView: Control {
    
    private(set) public var layout:TextViewLayout?
    
    private var beginSelect:NSPoint = NSZeroPoint
    private var endSelect:NSPoint = NSZeroPoint
    
    public var canBeResponder:Bool = true
    
    public var isSelectable:Bool = true {
        didSet {
            if oldValue != isSelectable {
                self.setNeedsDisplayLayer()
            }
        }
    }
    
    
    public override init() {
        super.init();
        self.style = ControlStyle(backgroundColor:.white)
//        wantsLayer = false
//        self.layer?.delegate = nil
    }

    public override var isFlipped: Bool {
        return true
    }

    public required init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        self.style = ControlStyle(backgroundColor:.white)
//        wantsLayer = false
//        self.layer?.delegate = nil
       // self.layer?.drawsAsynchronously = System.drawAsync
    }
    


    public override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        super.draw(layer, in: ctx)

        if let layout = layout {
            
            
            
            ctx.setAllowsAntialiasing(true)
           // ctx.setShouldAntialias(true)
           // ctx.setShouldSmoothFonts(true)
            ctx.setAllowsFontSmoothing(true)
            
           
            
            if layout.selectedRange.range.location != NSNotFound && isSelectable {
                
                var lessRange = layout.selectedRange.range
                
                var lines:[TextViewLine] = layout.lines

                let beginIndex:Int = 0
                let endIndex:Int = layout.lines.count - 1

                
                let isReversed = endIndex < beginIndex
                
                var i:Int = beginIndex
                
                
                while isReversed ? i >= endIndex : i <= endIndex {
                    
                    
                    let line = lines[i].line
                    var rect:NSRect = lines[i].frame
                    let lineRange = CTLineGetStringRange(line)
                    
                    var beginLineIndex:CFIndex = 0
                    var endLineIndex:CFIndex = 0
                    
                    if (lineRange.location + lineRange.length >= lessRange.location) && lessRange.length > 0 {
                        beginLineIndex = lessRange.location
                        let max = lineRange.length + lineRange.location
                        let maxSelect = max - beginLineIndex
                        
                        let selectLength = min(maxSelect,lessRange.length)
                        
                        lessRange.length-=selectLength
                        lessRange.location+=selectLength
                        
                        endLineIndex = beginLineIndex + selectLength
                        
                        var ascent:CGFloat = 0
                        var descent:CGFloat = 0
                        var leading:CGFloat = 0
                        
                        var width:CGFloat = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading));
                        
                        let startOffset = CTLineGetOffsetForStringIndex(line, beginLineIndex, nil);
                        let endOffset = CTLineGetOffsetForStringIndex(line, endLineIndex, nil);
                        
                        width = endOffset - startOffset;
                        
                        

                        rect.size.width = width

                        rect.origin.x = startOffset
                        rect.origin.y = rect.minY - rect.height
                        rect.size.height += ceil(descent - leading)
                        let color:NSColor = .selectText
                        
                        ctx.setFillColor(color.cgColor)
                        ctx.fill(rect)
                    }

                    i +=  isReversed ? -1 : 1
                    
                }
                
            }
            
            let textMatrix = ctx.textMatrix
            let textPosition = ctx.textPosition
            let startPosition = focus(layout.layoutSize).origin
            
     
            
            ctx.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
            
            for i in 0 ..< layout.lines.count {
                let line = layout.lines[i]
                
                let penOffset = CGFloat( CTLineGetPenOffsetForFlush(line.line, layout.penFlush, Double(frame.width)))
                
                ctx.textPosition = CGPoint(x: penOffset, y: startPosition.y + line.frame.minY)
                CTLineDraw(line.line, ctx)
                
            }
            
            ctx.textMatrix = textMatrix
            ctx.textPosition = CGPoint(x: textPosition.x, y: textPosition.y)
            
        }
        
    }
    
    private var contextMenu:ContextMenu?

    public override func menu(for event: NSEvent) -> NSMenu? {
        if let layout = layout, self.isSelectable {
            if !layout.selectedRange.hasSelectText || !layout.inSelectedRange(convert(event.locationInWindow, from: nil)) {
                layout.selectWord(at : self.convert(event.locationInWindow, from: nil))
            }
            self.setNeedsDisplayLayer()
            if layout.selectedRange.hasSelectText {
                 contextMenu = ContextMenu()
                 let text = localizedString("Text.Copy")
                 contextMenu?.addItem(ContextMenuItem(text.isEmpty ? "Copy" : text, handler: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.copy(strongSelf)
                    }
                }))
                return contextMenu
            }
            
        }
        return nil
    }
    
    public func isEqual(to layout:TextViewLayout) -> Bool {
        return self.layout == layout
    }
    
    public func update(_ layout:TextViewLayout?, origin:NSPoint = NSZeroPoint) -> Void {
        self.layout = layout
        
        self.set(selectedRange: NSMakeRange(NSNotFound, 0))
        if let layout = layout {
            self.frame = NSMakeRect(origin.x, origin.y, layout.layoutSize.width + layout.insets.width, layout.layoutSize.height + layout.insets.height)
        }
        self.setNeedsDisplayLayer()
    }
    
    public func set(layout:TextViewLayout?) {
        self.layout = layout
        self.setNeedsDisplayLayer()
    }
    
    func set(selectedRange range:NSRange, display:Bool = true) -> Void {
        
        
        layout?.selectedRange = TextSelectedRange(range:range, color:.selectText, def:true)
        
        beginSelect = NSMakePoint(-1, -1)
        endSelect = NSMakePoint(-1, -1)
        
        
        if display {
            self.setNeedsDisplayLayer()
        }
        
    }
    
    public override func mouseDown(with event: NSEvent) {
        self.window?.makeFirstResponder(nil)
        super.mouseDown(with: event)
        _mouseDown(with: event)
    }
    
    func _mouseDown(with event: NSEvent) -> Void {
        
        if !isSelectable || !userInteractionEnabled {
            return
        }
        
        _ = self.becomeFirstResponder()
        
        set(selectedRange: NSMakeRange(NSNotFound, 0), display: false)
        self.beginSelect = self.convert(event.locationInWindow, from: nil)
        
        self.setNeedsDisplayLayer()
        
    }
    
    public override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        checkCursor(event)
        _mouseDragged(with: event)
    }
    
    func _mouseDragged(with event: NSEvent) -> Void {
        if !isSelectable || !userInteractionEnabled {
            return
        }
        
        endSelect = self.convert(event.locationInWindow, from: nil)
        if let layout = layout {
            layout.selectedRange.range = layout.selectedRange(startPoint: beginSelect, currentPoint: endSelect)
        }
        self.setNeedsDisplayLayer()
    }
    
    
    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        checkCursor(event)
    }
    
    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        checkCursor(event)
    }
    
    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        checkCursor(event)
    }
    
    public override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        if let layout = layout, userInteractionEnabled {
            let point = self.convert(event.locationInWindow, from: nil)
            if event.clickCount == 3 {
                layout.selectedRange = TextSelectedRange(range: NSMakeRange(0,layout.attributedString.length), color: .selectText, def: true)
            } else if event.clickCount == 2 || (event.type == .rightMouseUp  && !layout.selectedRange.hasSelectText) {
                layout.selectWord(at : point)
            } else if !layout.selectedRange.hasSelectText || !isSelectable && event.clickCount == 1 {
                if let (link,_) = layout.link(at: point) {
                    layout.interactions.processURL(link)
                }
            }
            setNeedsDisplay()
        }
    }
    

    
    func checkCursor(_ event:NSEvent) -> Void {
        let location = self.convert(event.locationInWindow, from: nil)
        
        if self.mouse(location , in: self.visibleRect) && mouseInside() && userInteractionEnabled {
            
            if let layout = layout, let (_, _) = layout.link(at: location) {
                NSCursor.pointingHand().set()
            } else if isSelectable {
                NSCursor.iBeam().set()
            } else {
                NSCursor.arrow().set()
            }
        } else {
            NSCursor.arrow().set()
        }
    }
    
    
    
    
    public override func becomeFirstResponder() -> Bool {
        if canBeResponder {
            if let window = self.window {
                return window.makeFirstResponder(self)
            }
        }
        
        
        return false        
    }

    
    public override func resignFirstResponder() -> Bool {
        _resignFirstResponder()
        return super.resignFirstResponder()
    }
    
    func _resignFirstResponder() -> Void {
        self.set(selectedRange: NSMakeRange(NSNotFound, 0))
    }
    
    public override func responds(to aSelector: Selector!) -> Bool {
        
        if NSStringFromSelector(aSelector) == "copy:" {
            return self.layout?.selectedRange.range.location != NSNotFound
        }
        
        return super.responds(to: aSelector)
    }
    
    @objc public func copy(_ sender:Any) -> Void {
        if let layout = layout, layout.selectedRange.range.location != NSNotFound {
            let pb = NSPasteboard.general()
            
            pb.declareTypes([NSStringPboardType], owner: self)
            
            pb.setString(layout.attributedString.string.nsstring.substring(with: layout.selectedRange.range), forType: NSStringPboardType)
        }
    }
    
    @objc func paste(_ sender:Any) {
        
    }
    
 
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
