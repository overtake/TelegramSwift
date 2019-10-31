//
//  InstantPageTextItem.swift
//  Telegram
//
//  Created by keepcoder on 10/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac


extension NSAttributedString.Key {
    static let URL: NSAttributedString.Key = NSAttributedString.Key("TelegramURL")
}

final class InstantPageUrlItem: Equatable {
    let url: String
    let webpageId: MediaId?
    
    init(url: String, webpageId: MediaId?) {
        self.url = url
        self.webpageId = webpageId
    }
    
    public static func ==(lhs: InstantPageUrlItem, rhs: InstantPageUrlItem) -> Bool {
        return lhs.url == rhs.url && lhs.webpageId == rhs.webpageId
    }
}

struct InstantPageTextMarkedItem {
    let frame: CGRect
    let color: NSColor
}

struct InstantPageTextUrlItem {
    let frame: CGRect
    let item: AnyObject
}

struct InstantPageTextStrikethroughItem {
    let frame: CGRect
}

struct InstantPageTextImageItem {
    let frame: CGRect
    let range: NSRange
    let id: MediaId
}

struct InstantPageTextAnchorItem {
    let name: String
    let empty: Bool
}

final class InstantPageTextLine {
    let line: CTLine
    let range: NSRange
    let frame: CGRect
    let strikethroughItems: [InstantPageTextStrikethroughItem]
    let markedItems: [InstantPageTextMarkedItem]
    let imageItems: [InstantPageTextImageItem]
    let anchorItems: [InstantPageTextAnchorItem]
    let isRTL: Bool
    let attributedString: NSAttributedString
    
    let separatesTiles: Bool = false

    
    var selectRect: NSRect = NSZeroRect
    
    init(line: CTLine, attributedString: NSAttributedString, range: NSRange, frame: CGRect, strikethroughItems: [InstantPageTextStrikethroughItem], markedItems: [InstantPageTextMarkedItem], imageItems: [InstantPageTextImageItem], anchorItems: [InstantPageTextAnchorItem], isRTL: Bool) {
        self.line = line
        self.attributedString = attributedString
        self.range = range
        self.frame = frame
        self.strikethroughItems = strikethroughItems
        self.markedItems = markedItems
        self.imageItems = imageItems
        self.anchorItems = anchorItems
        self.isRTL = isRTL
        
    }
    
    func linkAt(point: NSPoint) -> InstantPageUrlItem? {
        if point.x >= 0 && point.x <= frame.width {
            let index: CFIndex = CTLineGetStringIndexForPosition(line, point)
            if index >= 0 && index < attributedString.length {
                return attributedString.attribute(.URL, at: index, effectiveRange: nil) as? InstantPageUrlItem
            }
        }
        
        return nil
    }
    
    func selectText(in rect: NSRect, boundingWidth: CGFloat, alignment: NSTextAlignment) -> NSAttributedString {
        
        var rect = rect
        if isRTL {
            rect.origin.x -= (boundingWidth - frame.width)
        }
        
        let startIndex: CFIndex = CTLineGetStringIndexForPosition(line, NSMakePoint(rect.minX, 0))
        let endIndex: CFIndex = CTLineGetStringIndexForPosition(line, NSMakePoint(rect.maxX, 0))
        
        
    
        var startOffset = CTLineGetOffsetForStringIndex(line, startIndex, nil)
        var endOffset = CTLineGetOffsetForStringIndex(line, endIndex, nil)
        
        switch alignment {
        case .center:
            let additional = floorToScreenPixels(System.backingScale, (boundingWidth - frame.width) / 2)
            startOffset += additional
            endOffset += additional
        case .right:
            startOffset = boundingWidth - startOffset
            endOffset =  boundingWidth - endOffset
        default:
            break
        }
        
        var selectRect = NSMakeRect(startOffset, frame.minY - 2, endOffset - startOffset, frame.height + 6)
        
        if isRTL {
            selectRect.origin.x += (boundingWidth - frame.width)
        }
        
        self.selectRect = selectRect
        return attributedString.attributedSubstring(from: NSMakeRange(min(startIndex, endIndex), abs(endIndex - startIndex)))
    }
    
    func selectWord(in point: NSPoint, boundingWidth: CGFloat, alignment: NSTextAlignment, rect: NSRect) -> NSAttributedString {
        
        var point = point
        if isRTL {
             point.x -= (boundingWidth - frame.width)
        }
        
        let startIndex: CFIndex = CTLineGetStringIndexForPosition(line, point)
        
        
        
        var prev = startIndex
        var next = startIndex
        var range = NSMakeRange(startIndex, 1)
        let char:NSString = attributedString.string.nsstring.substring(with: range) as NSString
        var effectiveRange:NSRange = NSMakeRange(NSNotFound, 0)
        let check = attributedString.attribute(NSAttributedString.Key.link, at: range.location, effectiveRange: &effectiveRange)
        if check != nil && effectiveRange.location != NSNotFound {
            return attributedString.attributedSubstring(from: effectiveRange)
        }
        if char == "" {
            return NSAttributedString()
        }
        let valid:Bool = char.trimmingCharacters(in: NSCharacterSet.alphanumerics) == "" || char == "_"
        let string:NSString = attributedString.string.nsstring
        while valid {
            let prevChar = string.substring(with: NSMakeRange(prev, 1))
            let nextChar = string.substring(with: NSMakeRange(next, 1))
            var prevValid:Bool = prevChar.trimmingCharacters(in: NSCharacterSet.alphanumerics) == "" || prevChar == "_"
            var nextValid:Bool = nextChar.trimmingCharacters(in: NSCharacterSet.alphanumerics) == "" || nextChar == "_"
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

        
        var startOffset = CTLineGetOffsetForStringIndex(line, range.location, nil)
        var endOffset = CTLineGetOffsetForStringIndex(line, range.location + range.length, nil)

        switch alignment {
        case .center:
            let additional = floorToScreenPixels(System.backingScale, (boundingWidth - frame.width) / 2)
            startOffset += additional
            endOffset += additional
        case .right:
            startOffset = boundingWidth - startOffset
            endOffset =  boundingWidth - endOffset
        default:
            break
        }
     
        
        selectRect = NSMakeRect(startOffset, frame.minY - 2, endOffset - startOffset, frame.height + 6)
        
        
        
        if isRTL {
            selectRect.origin.x += (boundingWidth - frame.width)
        }
        
        return attributedString.attributedSubstring(from: range)
    }
    
    func removeSelection() {
        selectRect = NSZeroRect
    }
}


private func frameForLine(_ line: InstantPageTextLine, boundingWidth: CGFloat, alignment: NSTextAlignment) -> CGRect {
    var lineFrame = line.frame
    if alignment == .center {
        lineFrame.origin.x = floor((boundingWidth - lineFrame.size.width) / 2.0)
    } else if alignment == .right || (alignment == .natural && line.isRTL) {
        lineFrame.origin.x = boundingWidth - lineFrame.size.width
    }
    return lineFrame
}

final class InstantPageTextItem: InstantPageItem {
    var hasLinks: Bool = false
    
    let isInteractive: Bool = false
    
    let attributedString: NSAttributedString
    let lines: [InstantPageTextLine]
    let rtlLineIndices: Set<Int>
    var frame: CGRect
    let alignment: NSTextAlignment
    let medias: [InstantPageMedia] = []
    let anchors: [String: (Int, Bool)]
    let wantsView: Bool = false
    let separatesTiles: Bool = false
    var selectable: Bool = true
    
    var containsRTL: Bool {
        return !self.rtlLineIndices.isEmpty
    }
    
    init(frame: CGRect, attributedString: NSAttributedString, alignment: NSTextAlignment, lines: [InstantPageTextLine]) {
        self.attributedString = attributedString
        self.alignment = alignment
        self.frame = frame
        self.lines = lines
        var index = 0
        var rtlLineIndices = Set<Int>()
        var anchors: [String: (Int, Bool)] = [:]
        for line in lines {
            if line.isRTL {
                rtlLineIndices.insert(index)
            }
            for anchor in line.anchorItems {
                anchors[anchor.name] = (index, anchor.empty)
            }
            index += 1
        }
        self.rtlLineIndices = rtlLineIndices
        self.anchors = anchors
    }
    
    func linkAt(point: NSPoint) -> InstantPageUrlItem? {
        for line in lines {
            var point = NSMakePoint(point.x, point.y)
            switch alignment {
            case .center:
                point.x -= floorToScreenPixels(System.backingScale, (frame.width - line.frame.width) / 2)
            case .right:
                point.x = frame.width - point.x
            default:
                break
            }
            
            if NSPointInRect(point, line.frame) {
                return line.linkAt(point: NSMakePoint(point.x, 0))
            }
        }
        return nil
    }
    
    func drawInTile(context: CGContext) {
        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
        context.translateBy(x: self.frame.minX, y: self.frame.minY)
        
        let clipRect = context.boundingBoxOfClipPath
        
        let upperOriginBound = clipRect.minY - 10.0
        let lowerOriginBound = clipRect.maxY + 10.0
        let boundsWidth = self.frame.size.width
        
        for i in 0 ..< self.lines.count {
            let line = self.lines[i]
            let lineFrame = frameForLine(line, boundingWidth: boundsWidth, alignment: self.alignment)
            if lineFrame.maxY < upperOriginBound || lineFrame.minY > lowerOriginBound {
                continue
            }
            
            let lineOrigin = lineFrame.origin
            
            
           
            
            context.textPosition = CGPoint(x: lineOrigin.x, y: lineOrigin.y + lineFrame.size.height)
            
            
            if !line.markedItems.isEmpty {
                context.saveGState()
                for item in line.markedItems {
                    let itemFrame = item.frame.offsetBy(dx: lineFrame.minX, dy: 0.0)
                    context.setFillColor(item.color.cgColor)
                    
                    let height = floor(item.frame.size.height * 2.2)
                    let rect = CGRect(x: itemFrame.minX - 2.0, y: floor(itemFrame.minY + (itemFrame.height - height) / 2.0), width: itemFrame.width + 4.0, height: height)
                    let path = CGPath(roundedRect: rect, cornerWidth: 3, cornerHeight: 3, transform: nil) //NSBezierPath(roundedRect: rect, xRadius: 3.0, yRadius: 3.0)
                    context.addPath(path)
                    context.fillPath()
                }
                context.restoreGState()
            }
            context.setFillColor(theme.colors.selectText.cgColor)
            context.fill(line.selectRect)
            
            CTLineDraw(line.line, context)
            
            if !line.strikethroughItems.isEmpty {
                for item in line.strikethroughItems {
                    let itemFrame = item.frame.offsetBy(dx: lineFrame.minX, dy: 0.0)
                    context.fill(CGRect(x: itemFrame.minX, y: itemFrame.minY + floor((lineFrame.size.height / 2.0) + 1.0), width: itemFrame.size.width, height: 1.0))
                }
            }
            
            
        }
        
        context.restoreGState()
    }
    
    func linkSelectionViews() -> [InstantPageLinkSelectionView] {
        return []
    }
    
    func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    func view(arguments: InstantPageItemArguments, currentExpandedDetails: [Int : Bool]?) -> (InstantPageView & NSView)? {
        return nil
    }
    
    func matchesView(_ node: InstantPageView) -> Bool {
        return false
    }
    
    func distanceThresholdGroup() -> Int? {
        return nil
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 0.0
    }
    
    func lineRects() -> [CGRect] {
        let boundsWidth = self.frame.width
        var rects: [CGRect] = []
        var topLeft = CGPoint(x: CGFloat.greatestFiniteMagnitude, y: 0.0)
        var bottomRight = CGPoint()
        
        var lastLineFrame: CGRect?
        for i in 0 ..< self.lines.count {
            let line = self.lines[i]
            
            var lineFrame = line.frame
            for imageItem in line.imageItems {
                if imageItem.frame.minY < lineFrame.minY {
                    let delta = lineFrame.minY - imageItem.frame.minY - 2.0
                    lineFrame = CGRect(x: lineFrame.minX, y: lineFrame.minY - delta, width: lineFrame.width, height: lineFrame.height + delta)
                }
                if imageItem.frame.maxY > lineFrame.maxY {
                    let delta = imageItem.frame.maxY - lineFrame.maxY - 2.0
                    lineFrame = CGRect(x: lineFrame.minX, y: lineFrame.minY, width: lineFrame.width, height: lineFrame.height + delta)
                }
            }
            lineFrame = lineFrame.insetBy(dx: 0.0, dy: -4.0)
            if self.alignment == .center {
                lineFrame.origin.x = floor((boundsWidth - lineFrame.size.width) / 2.0)
            } else if self.alignment == .right {
                lineFrame.origin.x = boundsWidth - lineFrame.size.width
            } else if self.alignment == .natural && self.rtlLineIndices.contains(i) {
                lineFrame.origin.x = boundsWidth - lineFrame.size.width
            }
            
            if lineFrame.minX < topLeft.x {
                topLeft = CGPoint(x: lineFrame.minX, y: topLeft.y)
            }
            if lineFrame.maxX > bottomRight.x {
                bottomRight = CGPoint(x: lineFrame.maxX, y: bottomRight.y)
            }
            
            if self.lines.count > 1 && i == self.lines.count - 1 {
                lastLineFrame = lineFrame
            } else {
                if lineFrame.minY < topLeft.y {
                    topLeft = CGPoint(x: topLeft.x, y: lineFrame.minY)
                }
                if lineFrame.maxY > bottomRight.y {
                    bottomRight = CGPoint(x: bottomRight.x, y: lineFrame.maxY)
                }
            }
        }
        rects.append(CGRect(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y))
        if self.lines.count > 1, var lastLineFrame = lastLineFrame {
            let delta = lastLineFrame.minY - bottomRight.y
            lastLineFrame = CGRect(x: lastLineFrame.minX, y: bottomRight.y, width: lastLineFrame.width, height: lastLineFrame.height + delta)
            rects.append(lastLineFrame)
        }
        
        return rects
    }
    
    func effectiveWidth() -> CGFloat {
        var width: CGFloat = 0.0
        for line in self.lines {
            width = max(width, line.frame.width)
        }
        return ceil(width)
    }
    
    func plainText() -> String {
        if let first = self.lines.first, let last = self.lines.last {
            return self.attributedString.attributedSubstring(from: NSMakeRange(first.range.location, last.range.location + last.range.length - first.range.location)).string
        }
        return ""
    }
    
}





func attributedStringForRichText(_ text: RichText, styleStack: InstantPageTextStyleStack, url: InstantPageUrlItem? = nil, boundingWidth: CGFloat? = nil) -> NSAttributedString {
    switch text {
    case .empty:
        return NSAttributedString(string: "", attributes: styleStack.textAttributes())
    case let .plain(string):
        var attributes = styleStack.textAttributes()
        if let url = url {
            attributes[.URL] = url
        }
        return NSAttributedString(string: string, attributes: attributes)
    case let .bold(text):
        styleStack.push(.bold)
        let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
        styleStack.pop()
        return result
    case let .italic(text):
        styleStack.push(.italic)
        let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
        styleStack.pop()
        return result
    case let .underline(text):
        styleStack.push(.underline)
        let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
        styleStack.pop()
        return result
    case let .strikethrough(text):
        styleStack.push(.strikethrough)
        let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
        styleStack.pop()
        return result
    case let .fixed(text):
        styleStack.push(.fontFixed(true))
        let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
        styleStack.pop()
        return result
    case let .url(text, url, webpageId):
        styleStack.push(.link(webpageId != nil))
        let result = attributedStringForRichText(text, styleStack: styleStack, url: InstantPageUrlItem(url: url, webpageId: webpageId))
        styleStack.pop()
        return result
    case let .email(text, email):
        styleStack.push(.bold)
        styleStack.push(.underline)
        let result = attributedStringForRichText(text, styleStack: styleStack, url: InstantPageUrlItem(url: "mailto:\(email)", webpageId: nil))
        styleStack.pop()
        styleStack.pop()
        return result
    case let .concat(texts):
        let string = NSMutableAttributedString()
        for text in texts {
            let substring = attributedStringForRichText(text, styleStack: styleStack, url: url, boundingWidth: boundingWidth)
            string.append(substring)
        }
        return string
    case let .subscript(text):
        styleStack.push(.subscript)
        let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
        styleStack.pop()
        return result
    case let .superscript(text):
        styleStack.push(.superscript)
        let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
        styleStack.pop()
        return result
    case let .marked(text):
        styleStack.push(.marker)
        let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
        styleStack.pop()
        return result
    case let .phone(text, phone):
        styleStack.push(.bold)
        styleStack.push(.underline)
        let result = attributedStringForRichText(text, styleStack: styleStack, url: InstantPageUrlItem(url: "tel:\(phone)", webpageId: nil))
        styleStack.pop()
        styleStack.pop()
        return result
    case let .image(id, dimensions):
        struct RunStruct {
            let ascent: CGFloat
            let descent: CGFloat
            let width: CGFloat
        }
        
        var dimensions = dimensions
        if let boundingWidth = boundingWidth {
            dimensions = dimensions.fittedToWidthOrSmaller(boundingWidth)
        }
        let extentBuffer = UnsafeMutablePointer<RunStruct>.allocate(capacity: 1)
        extentBuffer.initialize(to: RunStruct(ascent: 0.0, descent: 0.0, width: dimensions.width))
        var callbacks = CTRunDelegateCallbacks(version: kCTRunDelegateVersion1, dealloc: { (pointer) in
        }, getAscent: { (pointer) -> CGFloat in
            let d = pointer.assumingMemoryBound(to: RunStruct.self)
            return d.pointee.ascent
        }, getDescent: { (pointer) -> CGFloat in
            let d = pointer.assumingMemoryBound(to: RunStruct.self)
            return d.pointee.descent
        }, getWidth: { (pointer) -> CGFloat in
            let d = pointer.assumingMemoryBound(to: RunStruct.self)
            return d.pointee.width
        })
        let delegate = CTRunDelegateCreate(&callbacks, extentBuffer)
        let attrDictionaryDelegate = [(kCTRunDelegateAttributeName as NSAttributedString.Key): (delegate as Any), .instantPageMediaIdAttribute : id.id, .instantPageMediaDimensionsAttribute: dimensions]
        return NSAttributedString(string: " ", attributes: attrDictionaryDelegate)
    case let .anchor(text, name):
        var empty = false
        var text = text
        if case .empty = text {
            empty = true
            text = .plain("\u{200b}")
        }
        styleStack.push(.anchor(name, empty))
        let result = attributedStringForRichText(text, styleStack: styleStack, url: url)
        styleStack.pop()
        return result
    }
}

func layoutTextItemWithString(_ string: NSAttributedString, boundingWidth: CGFloat, horizontalInset: CGFloat = 0.0, alignment: NSTextAlignment = .natural, offset: CGPoint, media: [MediaId: Media] = [:], webpage: TelegramMediaWebpage? = nil, minimizeWidth: Bool = false, maxNumberOfLines: Int = 0) -> (InstantPageTextItem?, [InstantPageItem], CGSize) {
    if string.length == 0 {
        return (nil, [], CGSize())
    }
    
    var lines: [InstantPageTextLine] = []
    var imageItems: [InstantPageTextImageItem] = []
    var font = string.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
    if font == nil {
        let range = NSMakeRange(0, string.length)
        string.enumerateAttributes(in: range, options: []) { attributes, range, _ in
            if font == nil, let furtherFont = attributes[.font] as? NSFont {
                font = furtherFont
            }
        }
    }
    let image = string.attribute(.instantPageMediaIdAttribute, at: 0, effectiveRange: nil)
    guard font != nil || image != nil else {
        return (nil, [], CGSize())
    }
    
    var lineSpacingFactor: CGFloat = 1.12
    if let lineSpacingFactorAttribute = string.attribute(.instantPageLineSpacingFactorAttribute, at: 0, effectiveRange: nil) {
        lineSpacingFactor = CGFloat((lineSpacingFactorAttribute as! NSNumber).floatValue)
    }
    
    let typesetter = CTTypesetterCreateWithAttributedString(string)
    let fontAscent = font?.ascender ?? 0.0
    let fontDescent = font?.descender ?? 0.0
    
    let fontLineHeight = floor(fontAscent + fontDescent)
    let fontLineSpacing = floor(fontLineHeight * lineSpacingFactor)
    
    var lastIndex: CFIndex = 0
    var currentLineOrigin = CGPoint()
    
    var hasAnchors = false
    var maxLineWidth: CGFloat = 0.0
    var maxImageHeight: CGFloat = 0.0
    var extraDescent: CGFloat = 0.0
    let text = string.string
    var indexOffset: CFIndex?
    while true {
        var workingLineOrigin = currentLineOrigin
        
        let currentMaxWidth = boundingWidth - workingLineOrigin.x
        let lineCharacterCount: CFIndex
        var hadIndexOffset = false
        if minimizeWidth {
            var count = 0
            for ch in text.suffix(text.count - lastIndex) {
                count += 1
                if ch == " " || ch == "\n" || ch == "\t" {
                    break
                }
            }
            lineCharacterCount = count
        } else {
            let suggestedLineBreak = CTTypesetterSuggestLineBreak(typesetter, lastIndex, Double(currentMaxWidth))
            if let offset = indexOffset {
                lineCharacterCount = suggestedLineBreak + offset
                indexOffset = nil
                hadIndexOffset = true
            } else {
                lineCharacterCount = suggestedLineBreak
            }
        }
        if lineCharacterCount > 0 {
            var line = CTTypesetterCreateLineWithOffset(typesetter, CFRangeMake(lastIndex, lineCharacterCount), 100.0)
            var lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            let lineRange = NSMakeRange(lastIndex, lineCharacterCount)
            let substring = string.attributedSubstring(from: lineRange).string
            
            var stop = false
            if maxNumberOfLines > 0 && lines.count == maxNumberOfLines - 1 && lastIndex + lineCharacterCount < string.length {
                let attributes = string.attributes(at: lastIndex + lineCharacterCount - 1, effectiveRange: nil)
                if let truncateString = CFAttributedStringCreate(nil, "\u{2026}" as CFString, attributes as CFDictionary) {
                    let truncateToken = CTLineCreateWithAttributedString(truncateString)
                    let tokenWidth = CGFloat(CTLineGetTypographicBounds(truncateToken, nil, nil, nil) + 3.0)
                    if let truncatedLine = CTLineCreateTruncatedLine(line, Double(lineWidth - tokenWidth), .end, truncateToken) {
                        lineWidth += tokenWidth
                        line = truncatedLine
                    }
                }
                stop = true
            }
            
            let hadExtraDescent = extraDescent > 0.0
            extraDescent = 0.0
            var lineImageItems: [InstantPageTextImageItem] = []
            var isRTL = false
            if let glyphRuns = CTLineGetGlyphRuns(line) as? [CTRun], !glyphRuns.isEmpty {
                if let run = glyphRuns.first, CTRunGetStatus(run).contains(CTRunStatus.rightToLeft) {
                    isRTL = true
                }
                
                var appliedLineOffset: CGFloat = 0.0
                for run in glyphRuns {
                    let cfRunRange = CTRunGetStringRange(run)
                    let runRange = NSMakeRange(cfRunRange.location == kCFNotFound ? NSNotFound : cfRunRange.location, cfRunRange.length)
                    string.enumerateAttributes(in: runRange, options: []) { attributes, range, _ in
                        if let id = attributes[.instantPageMediaIdAttribute] as? Int64, let dimensions = attributes[.instantPageMediaDimensionsAttribute] as? CGSize {
                            var imageFrame = CGRect(origin: CGPoint(), size: dimensions)
                            
                            let xOffset = CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, nil)
                            let yOffset = fontLineHeight.isZero ? 0.0 : floorToScreenPixels(System.backingScale, (fontLineHeight - imageFrame.size.height) / 2.0)
                            imageFrame.origin = imageFrame.origin.offsetBy(dx: workingLineOrigin.x + xOffset, dy: workingLineOrigin.y + yOffset)
                            
                            let minSpacing = fontLineSpacing - 4.0
                            let delta = workingLineOrigin.y - minSpacing - imageFrame.minY - appliedLineOffset
                            if !fontAscent.isZero && delta > 0.0 {
                                workingLineOrigin.y += delta
                                appliedLineOffset += delta
                                imageFrame.origin = imageFrame.origin.offsetBy(dx: 0.0, dy: delta)
                            }
                            if !fontLineHeight.isZero {
                                extraDescent = max(extraDescent, imageFrame.maxY - (workingLineOrigin.y + fontLineHeight + minSpacing))
                            }
                            maxImageHeight = max(maxImageHeight, imageFrame.height)
                            lineImageItems.append(InstantPageTextImageItem(frame: imageFrame, range: range, id: MediaId(namespace: Namespaces.Media.CloudFile, id: id)))
                        }
                    }
                }
            }
            
            if substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && lineImageItems.count > 0 {
                extraDescent += max(6.0, fontLineSpacing / 2.0)
            }
            
            if !minimizeWidth && !hadIndexOffset && lineCharacterCount > 1 && lineWidth > currentMaxWidth + 5.0, let imageItem = lineImageItems.last {
                indexOffset = -(lastIndex + lineCharacterCount - imageItem.range.lowerBound)
                continue
            }
            
            var strikethroughItems: [InstantPageTextStrikethroughItem] = []
            var markedItems: [InstantPageTextMarkedItem] = []
            var anchorItems: [InstantPageTextAnchorItem] = []
            
            string.enumerateAttributes(in: lineRange, options: []) { attributes, range, _ in
                if let _ = attributes[.strikethroughStyle] {
                    let lowerX = floor(CTLineGetOffsetForStringIndex(line, range.location, nil))
                    let upperX = ceil(CTLineGetOffsetForStringIndex(line, range.location + range.length, nil))
                    let x = lowerX < upperX ? lowerX : upperX
                    strikethroughItems.append(InstantPageTextStrikethroughItem(frame: CGRect(x: workingLineOrigin.x + x, y: workingLineOrigin.y, width: abs(upperX - lowerX), height: fontLineHeight)))
                }
                if let color = attributes[.instantPageMarkerColorAttribute] as? NSColor {
                    var lineHeight = fontLineHeight
                    var delta: CGFloat = 0.0
                    
                    if let offset = attributes[.baselineOffset] as? CGFloat {
                        lineHeight = floorToScreenPixels(System.backingScale, lineHeight * 0.85)
                        delta = offset * 0.6
                    }
                    let lowerX = floor(CTLineGetOffsetForStringIndex(line, range.location, nil))
                    let upperX = ceil(CTLineGetOffsetForStringIndex(line, range.location + range.length, nil))
                    let x = lowerX < upperX ? lowerX : upperX
                    markedItems.append(InstantPageTextMarkedItem(frame: CGRect(x: workingLineOrigin.x + x, y: workingLineOrigin.y + delta, width: abs(upperX - lowerX), height: lineHeight), color: color))
                }
                if let item = attributes[.instantPageAnchorAttribute] as? Dictionary<String, Any>, let name = item["name"] as? String, let empty = item["empty"] as? Bool {
                    anchorItems.append(InstantPageTextAnchorItem(name: name, empty: empty))
                }
            }
            
            if !anchorItems.isEmpty {
                hasAnchors = true
            }
            
            if hadExtraDescent && extraDescent > 0 {
                workingLineOrigin.y += fontLineSpacing
            }
            
            let height = !fontLineHeight.isZero ? fontLineHeight : maxImageHeight
            let textLine = InstantPageTextLine(line: line, attributedString: string, range: lineRange, frame: CGRect(x: workingLineOrigin.x, y: workingLineOrigin.y, width: lineWidth, height: height), strikethroughItems: strikethroughItems, markedItems: markedItems, imageItems: lineImageItems, anchorItems: anchorItems, isRTL: isRTL)
            
            lines.append(textLine)
            imageItems.append(contentsOf: lineImageItems)
            
            if lineWidth > maxLineWidth {
                maxLineWidth = lineWidth
            }
            
            workingLineOrigin.x = 0.0
            workingLineOrigin.y += fontLineHeight + fontLineSpacing + extraDescent
            currentLineOrigin = workingLineOrigin
            
            lastIndex += lineCharacterCount
            
            if stop {
                break
            }
        } else {
            break
        }
    }
    
    var height: CGFloat = 0.0
    if !lines.isEmpty && !(string.string == "\u{200b}" && hasAnchors) {
        height = lines.last!.frame.maxY + extraDescent
    }
    
    var textWidth = boundingWidth
    var requiresScroll = false
    if !imageItems.isEmpty && maxLineWidth > boundingWidth + 10.0 {
        textWidth = maxLineWidth
        requiresScroll = true
    }
    
    let textItem = InstantPageTextItem(frame: CGRect(x: 0.0, y: 0.0, width: textWidth, height: height), attributedString: string, alignment: alignment, lines: lines)
    if !requiresScroll {
        textItem.frame = textItem.frame.offsetBy(dx: offset.x, dy: offset.y)
    }
    var items: [InstantPageItem] = []
    if !requiresScroll && (imageItems.isEmpty || string.length > 1) {
        items.append(textItem)
    }
    
    var topInset: CGFloat = 0.0
    var bottomInset: CGFloat = 0.0
    var additionalItems: [InstantPageItem] = []
    if let webpage = webpage {
        let offset = requiresScroll ? CGPoint() : offset
        for line in textItem.lines {
            let lineFrame = frameForLine(line, boundingWidth: boundingWidth, alignment: alignment)
            for imageItem in line.imageItems {
                if let image = media[imageItem.id] as? TelegramMediaFile {
                    let item = InstantPageImageItem(frame: imageItem.frame.offsetBy(dx: lineFrame.minX + offset.x, dy: offset.y), webPage: webpage, media: InstantPageMedia(index: -1, media: image, webpage: webpage, url: nil, caption: nil, credit: nil), interactive: false, roundCorners: false, fit: false)
                    additionalItems.append(item)
                    
                    if item.frame.minY < topInset {
                        topInset = item.frame.minY
                    }
                    if item.frame.maxY > height {
                        bottomInset = max(bottomInset, item.frame.maxY - height)
                    }
                }
            }
        }
    }
    
//    if requiresScroll {
//        textItem.frame = textItem.frame.offsetBy(dx: 0.0, dy: fabs(topInset))
//        for var item in additionalItems {
//            item.frame = item.frame.offsetBy(dx: 0.0, dy: fabs(topInset))
//        }
//
//        let scrollableItem = InstantPageScrollableTextItem(frame: CGRect(x: 0.0, y: 0.0, width: boundingWidth + horizontalInset * 2.0, height: height + fabs(topInset) + bottomInset), item: textItem, additionalItems: additionalItems, totalWidth: textWidth, horizontalInset: horizontalInset, rtl: textItem.containsRTL)
//        items.append(scrollableItem)
//    } else {
        items.append(contentsOf: additionalItems)
//    }
    
    return (requiresScroll ? nil : textItem, items, textItem.frame.size)
}

