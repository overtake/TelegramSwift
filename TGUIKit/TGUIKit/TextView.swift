//
//  TextView.swift
//  TGUIKit
//
//  Created by keepcoder on 15/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public final class TextViewInteractions {
    var processURL:(String, Bool)->Void = {_ in} // link, isPresent
}

private final class TextViewLine {
    let line: CTLine
    let frame: NSRect
    
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
}

public func ==(lhs: TextViewCutout, rhs: TextViewCutout) -> Bool {
    return lhs.position == rhs.position && lhs.size == rhs.size
}

private let defaultFont:NSFont = systemFont(TGFont.textSize)

public final class TextViewLayout : Equatable {
    
    public var attributedString:NSAttributedString
    public var constrainedSize:NSSize = NSZeroSize
    public var interactions:TextViewInteractions = TextViewInteractions()
    public var selectedRange:TextSelectedRange = TextSelectedRange()
    
    
    fileprivate var lines:[TextViewLine] = []
    
    private var maximumNumberOfLines:Int32
    private var truncationType:CTLineTruncationType
    private var cutout:TextViewCutout?
    
    public private(set) var layoutSize:NSSize = NSZeroSize
    
    public init(_ attributedString:NSAttributedString, constrainedSize:NSSize = NSZeroSize, maximumNumberOfLines:Int32 = INT32_MAX, truncationType: CTLineTruncationType = .end, cutout:TextViewCutout? = nil) {
        self.truncationType = truncationType
        self.maximumNumberOfLines = maximumNumberOfLines
        self.cutout = cutout
        self.attributedString = attributedString
        self.constrainedSize = constrainedSize
    }
    
    func calculateLayout() -> Void {
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
        let fontLineSpacing = floor(fontLineHeight * 0.12)
        
        
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
            var lineConstrainedWidth = constrainedSize.width
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
                
                if CTLineGetTypographicBounds(originalLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(originalLine) < Double(constrainedSize.width) {
                    coreTextLine = originalLine
                } else {
                    var truncationTokenAttributes: [String : AnyObject] = [:]
                    truncationTokenAttributes[kCTFontAttributeName as String] = font
                    truncationTokenAttributes[kCTForegroundColorFromContextAttributeName as String] = true as NSNumber
                    let tokenString = "\u{2026}"
                    let truncatedTokenString = NSAttributedString(string: tokenString, attributes: truncationTokenAttributes)
                    let truncationToken = CTLineCreateWithAttributedString(truncatedTokenString)
                    
                    coreTextLine = CTLineCreateTruncatedLine(originalLine, Double(constrainedSize.width), truncationType, truncationToken) ?? truncationToken
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
    
    public func measure(size: NSSize) -> Void {
        
        if constrainedSize != size {
            self.constrainedSize = size
             calculateLayout()
        }

    }
    
    public func selectedRange(startPoint:NSPoint, currentPoint:NSPoint) -> NSRange {
        
        var selectedRange:NSRange = NSMakeRange(NSNotFound, 0)
        
        if (currentPoint.x != -1 && currentPoint.y != -1) {
            
            
            var startSelectLineIndex = findIndex(location: startPoint)
            var currentSelectLineIndex = findIndex(location: currentPoint)
            var dif = abs(startSelectLineIndex - currentSelectLineIndex)
            var isReversed = currentSelectLineIndex < startSelectLineIndex
            var i = startSelectLineIndex
            while isReversed ? i >= currentSelectLineIndex : i <= currentSelectLineIndex {
                var line = lines[i].line
                var lineRange = CTLineGetStringRange(line)
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
        
        for idx in 0 ..< lines.count {
            if  isCurrentLine(pos: location, index: idx) {
                return idx
            }
        }
        
        return location.y <= layoutSize.height ? 0 : (lines.count - 1)
        
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

    public func link(at point:NSPoint) -> (String, Bool, NSRect)? {
        
        let index = findIndex(location: point)
        let line = lines[index]
        var ascent:CGFloat = 0
        var descent:CGFloat = 0
        var leading:CGFloat = 0
        
        var width:CGFloat = CGFloat(CTLineGetTypographicBounds(line.line, &ascent, &descent, &leading));
        
        if  width > point.x {
            var pos = CTLineGetStringIndexForPosition(line.line, point);
            pos = min(max(0,pos),attributedString.length - 1)
            var range:NSRange = NSMakeRange(NSNotFound, 0)
            let attrs = attributedString.attributes(at: pos, effectiveRange: &range)
            
            let link:String? = attrs[NSLinkAttributeName] as? String
            
            if let link = link, !link.isEmpty {
                let present = attributedString.string.nsstring.substring(with: range)
                
                let startOffset = CTLineGetOffsetForStringIndex(line.line, range.location, nil);
                let endOffset = CTLineGetOffsetForStringIndex(line.line, range.location + range.length, nil);
                return (link, present == link, NSMakeRect(startOffset, line.frame.minY, endOffset - startOffset, ceil(ascent + ceil(descent) + leading)))
            }
        }
        return nil
    }

}

public func ==(lhs:TextViewLayout, rhs:TextViewLayout) -> Bool {
    return lhs.constrainedSize == rhs.constrainedSize && lhs.attributedString.isEqual(to: rhs.attributedString) && lhs.selectedRange != rhs.selectedRange
}

public struct TextSelectedRange: Equatable {
    var range:NSRange = NSMakeRange(NSNotFound, 0)
    var color:NSColor = TGColor.selectText
    var def:Bool = true
}

public func ==(lhs:TextSelectedRange, rhs:TextSelectedRange) -> Bool {
    return lhs.def == rhs.def && lhs.range.location == rhs.range.location && lhs.range.length == rhs.range.length
}


public class TextView: View {
    
    private var layout:TextViewLayout?
    
    private var beginSelect:NSPoint = NSZeroPoint
    private var endSelect:NSPoint = NSZeroPoint

    
    public var isSelectable:Bool = true {
        didSet {
            if oldValue != isSelectable {
                self.setNeedsDisplayLayer()
            }
        }
    }
    
    private var trackingArea:NSTrackingArea?
    
    public override init() {
        super.init();
    }

    public override var isFlipped: Bool {
        return true
    }

    public required init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        self.layer?.isOpaque = true
        self.layer?.drawsAsynchronously = System.drawAsync
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas();
        
        if let trackingArea = trackingArea {
            self.removeTrackingArea(trackingArea)
        }
        
        let options:NSTrackingAreaOptions = [NSTrackingAreaOptions.mouseEnteredAndExited, NSTrackingAreaOptions.mouseMoved, NSTrackingAreaOptions.activeInKeyWindow,NSTrackingAreaOptions.inVisibleRect]
        self.trackingArea = NSTrackingArea.init(rect: self.bounds, options: options, owner: self, userInfo: nil)
        
        self.addTrackingArea(self.trackingArea!)
    }
    
    public override func draw(_ layer: CALayer, in ctx: CGContext) {
        if let layout = layout {
            
        
            super.draw(layer, in: ctx)
            
            ctx.setAllowsAntialiasing(true)
            ctx.setShouldSmoothFonts(!System.isRetina)
            ctx.setAllowsFontSmoothing(!System.isRetina)
            
            
            if !isSelectable {
                return
            }
            
            
            if layout.selectedRange.range.location != NSNotFound {
                
                var lessRange = layout.selectedRange.range
                
                var lines:[TextViewLine] = layout.lines

                var beginIndex:Int = 0
                var endIndex:Int = layout.lines.count - 1
                var dif:Int = 0

                
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
                        let color = TGColor.selectText
                        
                        ctx.setFillColor(color.cgColor)
                        ctx.fill(rect)
                    }


                  
                    
                    i +=  isReversed ? -1 : 1
                    
                }
                
            }
            
            let textMatrix = ctx.textMatrix
            let textPosition = ctx.textPosition
            
            ctx.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
            
            for i in 0 ..< layout.lines.count {
                let line = layout.lines[i]
                ctx.textPosition = CGPoint(x: line.frame.minX, y: line.frame.minY)
                CTLineDraw(line.line, ctx)
                
            }
            
            ctx.textMatrix = textMatrix
            ctx.textPosition = CGPoint(x: textPosition.x, y: textPosition.y)
            
        }
        
    }
    

    
    public func update(_ layout:TextViewLayout, origin:NSPoint = NSZeroPoint) -> Void {
        self.layout = layout
        
        self.set(selectedRange: NSMakeRange(NSNotFound, 0))
        
        self.frame = NSMakeRect(origin.x, origin.y, layout.layoutSize.width, layout.layoutSize.height)
        self.setNeedsDisplayLayer()
    }
    
    
    
    func set(selectedRange range:NSRange, display:Bool = true) -> Void {
        
        
        layout?.selectedRange = TextSelectedRange(range:range, color:TGColor.selectText, def:true)
        
        beginSelect = NSMakePoint(-1, -1)
        endSelect = NSMakePoint(-1, -1)
        
        
        if display {
            self.setNeedsDisplayLayer()
        }
        
    }
    
    public override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        _mouseDown(with: event)
    }
    
    func _mouseDown(with event: NSEvent) -> Void {
        
        if !isSelectable {
            return
        }
        
        self.becomeFirstResponder()
        
        set(selectedRange: NSMakeRange(NSNotFound, 0), display: false)
        self.beginSelect = self.convert(event.locationInWindow, from: nil)
        
        self.setNeedsDisplayLayer()
        
    }
    
    public override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        NSCursor.iBeam().set()
        _mouseDragged(with: event)
    }
    
    func _mouseDragged(with event: NSEvent) -> Void {
        if !isSelectable {
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
        
        if let layout = layout {
            if layout.selectedRange.range.location == NSNotFound || !isSelectable {
                let point = self.convert(event.locationInWindow, from: nil)
                if let (link,isPresent,_) = layout.link(at: point) {
                    layout.interactions.processURL(link,isPresent)
                }
            }
        }
    }
    
    func checkCursor(_ event:NSEvent) -> Void {
        let location = self.convert(event.locationInWindow, from: nil)
        
        if self.mouse(location , in: self.visibleRect) && !hasVisibleModal {
            
            if let layout = layout, let (_, _, _) = layout.link(at: location) {
                NSCursor.pointingHand().set()
            } else {
                NSCursor.iBeam().set()
            }
        } else {
            NSCursor.arrow().set()
        }
    }
    
    
    
    
    public override func becomeFirstResponder() -> Bool {
        if let window = self.window {
            return window.makeFirstResponder(self)
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
    
    
    override required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
