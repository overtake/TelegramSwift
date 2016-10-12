//
//  TextView.swift
//  TGUIKit
//
//  Created by keepcoder on 15/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public final class TextViewLayout {
    public var attributedString:NSAttributedString
    public var framesetter:CTFramesetter
    public var frame:CTFrame!
    public var size:NSSize = NSZeroSize
    
    public init(_ attributedString:NSAttributedString, size:NSSize = NSZeroSize) {
        
        self.attributedString = attributedString
        self.framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        self.size = size
        
    }
    
    public func measure(width:CGFloat) -> Void {
        self.size = attributedString.CTSize(width,framesetter:framesetter).1
        let path:CGMutablePath = CGMutablePath()
        path.addRect(NSMakeRect(0, 0, size.width , size.height))
        frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
    }
    
    public func selectedRange(startPoint:NSPoint, currentPoint:NSPoint) -> NSRange {
        
        var selectedRange:NSRange = NSMakeRange(NSNotFound, 0)
        
        if (currentPoint.x != -1 && currentPoint.y != -1) {
            let lines:Array<CTLine> = Array.fromCFArray(records: CTFrameGetLines(frame))!
            var origins = [CGPoint] (repeating: .zero, count: lines.count)
            CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &origins)
            
            var startSelectLineIndex = findIndex(origins: origins, location: startPoint)
            var currentSelectLineIndex = findIndex( origins: origins, location: currentPoint)
            var dif = abs(startSelectLineIndex - currentSelectLineIndex)
            var isReversed = currentSelectLineIndex < startSelectLineIndex
            var i = startSelectLineIndex
            while isReversed ? i >= currentSelectLineIndex : i <= currentSelectLineIndex {
                var line = lines[i]
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
    
    
    public func findIndex(origins:[CGPoint], location:NSPoint) -> Int {
        
        var idx:Int = 0
        for point in origins {
            if  isCurrentLine(pos: location, linePos: point, index: idx) {
                return idx
            }
            idx += 1
        }
        
        return location.y >= size.height ? 0 : (origins.count - 1)
        
    }
    
    public func isCurrentLine(pos:NSPoint, linePos:NSPoint, index:Int) -> Bool {
        let lines:Array<CTLine> = Array.fromCFArray(records: CTFrameGetLines(frame))!
        
        let line = lines[index]
        
        var ascent:CGFloat = 0
        var descent:CGFloat = 0
        var leading:CGFloat = 0
        
        CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        
        let height = ceil(ascent + ceil(descent) + leading)
        
        return (pos.y > linePos.y) && pos.y < (linePos.y + height)
        
    }

    public func link(at point:NSPoint) -> (String, Bool, NSRect)? {
        
        let lines:Array<CTLine> = Array.fromCFArray(records: CTFrameGetLines(frame))!
        var origins = [CGPoint] (repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &origins)
        let index = findIndex(origins: origins, location: point)
        let line = lines[index]
        var ascent:CGFloat = 0
        var descent:CGFloat = 0
        var leading:CGFloat = 0
        
        var width:CGFloat = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading));
        
        if  width > point.x {
            var pos = CTLineGetStringIndexForPosition(line, point);
            pos = min(max(0,pos),attributedString.length - 1)
            var range:NSRange = NSMakeRange(NSNotFound, 0)
            let attrs = attributedString.attributes(at: pos, effectiveRange: &range)
            
            let link:String? = attrs[NSLinkAttributeName] as? String
            
            if let link = link, !link.isEmpty {
                let present = attributedString.string.nsstring.substring(with: range)
                
                let startOffset = CTLineGetOffsetForStringIndex(line, range.location, nil);
                let endOffset = CTLineGetOffsetForStringIndex(line, range.location + range.length, nil);
                return (link, present == link, NSMakeRect(startOffset, origins[index].y, endOffset - startOffset, ceil(ascent + ceil(descent) + leading)))
            }
        }
        return nil
    }

    
    
}

public struct TextSelectedRange: Equatable {
    let range:NSRange
    let color:NSColor
    let def:Bool
}

public func ==(lhs:TextSelectedRange, rhs:TextSelectedRange) -> Bool {
    return lhs.def == rhs.def && lhs.range.location == rhs.range.location && lhs.range.length == rhs.range.length
}

public protocol TextViewDelegate : class {
    func textViewDid(click url:String, isPresent:Bool)
}


public class TextView: View {
    
    private var layout:TextViewLayout?
    
    private var _selectedTextRanges:[TextSelectedRange] = []
    private var _selectedTextRange:TextSelectedRange?
    
    public private(set) var selectedRange:NSRange = NSMakeRange(NSNotFound, 0)
    
    private var beginSelect:NSPoint = NSZeroPoint
    private var endSelect:NSPoint = NSZeroPoint
    

    
    public weak var delegate:TextViewDelegate?
    
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
        return false
    }

    public required init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
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
            
            
            
            ctx.textPosition = NSMakePoint(0, 0)
            
            let path:CGMutablePath = CGMutablePath()
            path.addRect(NSMakeRect(0, 0, NSWidth(self.bounds) , NSHeight(self.bounds)))
            
            
            if !isSelectable {
                return
            }
            
            selectedRange = layout.selectedRange(startPoint: beginSelect, currentPoint: endSelect)
            
            if selectedRange.location != NSNotFound {
                
                var lessRange = selectedRange
                
                let lines:Array<CTLine> = Array.fromCFArray(records: CTFrameGetLines(layout.frame))!
                var origins = [CGPoint] (repeating: .zero, count: lines.count)
                CTFrameGetLineOrigins(layout.frame, CFRangeMake(0, 0), &origins)
                
                var beginIndex:Int = 0
                var endIndex:Int = origins.count - 1
                var dif:Int = 0

                
                let isReversed = endIndex < beginIndex
                
                var i:Int = beginIndex
                
                
                while isReversed ? i >= endIndex : i <= endIndex {
                    
                    
                    let line = lines[i]
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
                        
                        
                        var rect = NSZeroRect
                        
                        rect.size.width = width
                        rect.size.height = ceil(ascent + ceil(descent) + leading);
                        
                        rect.origin.x = startOffset
                        rect.origin.y = origins[i].y - ceil(descent - leading)
                        
                        let color = TGColor.selectText
                        
                        ctx.setFillColor(color.cgColor)
                        ctx.fill(rect)
                    }


                  
                    
                    i +=  isReversed ? -1 : 1
                    
                }
                
            }
            

            CTFrameDraw(layout.frame, ctx);
            
        }
        
    }
    

    
    public func update(_ layout:TextViewLayout, origin:NSPoint = NSZeroPoint) -> Void {
        self.layout = layout
        _selectedTextRanges.removeAll()
        _selectedTextRange = nil
        
    
        self.set(selectedRange: NSMakeRange(NSNotFound, 0))
        
        self.frame = NSMakeRect(origin.x, origin.y, layout.size.width, layout.size.height)
        self.setNeedsDisplayLayer()
    }
    
    func add(selectRange range:TextSelectedRange) -> Void {
        for select in _selectedTextRanges {
            if select == range {
                return
            }
        }
        _selectedTextRanges.append(range)
        self.setNeedsDisplayLayer()
    }
    
    
    
    func set(selectedRange range:NSRange, display:Bool = true) -> Void {
        
        if let _ = _selectedTextRange {
            _selectedTextRanges.removeFirst()
        }
        
        _selectedTextRange = TextSelectedRange(range:range, color:TGColor.selectText, def:true)
        
        beginSelect = NSMakePoint(-1, -1)
        endSelect = NSMakePoint(-1, -1)
        
        _selectedTextRanges.append(_selectedTextRange!)
        
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
        
        self.endSelect = NSMakePoint(-1, -1)
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
        
        if let delegate = delegate {
            if selectedRange.location == NSNotFound || !isSelectable {
                if let layout = layout {
                    let point = self.convert(event.locationInWindow, from: nil)
                    
                    if let (link,isPresent,_) = layout.link(at: point) {
                        delegate.textViewDid(click: link, isPresent:isPresent)
                    }
                }
                
                
            }
        }
    }
    
    func checkCursor(_ event:NSEvent) -> Void {
        let location = self.convert(event.locationInWindow, from: nil)
        
        if self.mouse(location , in: self.bounds) {
            
            if let layout = layout, let (_, _, _) = layout.link(at: location) {
                NSCursor.pointingHand().set()
            } else {
                NSCursor.iBeam().set()
            }
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
            return self.selectedRange.location != NSNotFound
        }
        
        return super.responds(to: aSelector)
    }
    
    @objc public func copy(_ sender:Any) -> Void {
        if selectedRange.location != NSNotFound, let layout = layout {
            let pb = NSPasteboard.general()
            
            pb.declareTypes([NSStringPboardType], owner: self)
            
            pb.setString(layout.attributedString.string.nsstring.substring(with: selectedRange), forType: NSStringPboardType)
        }
    }
    
    
    override required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
