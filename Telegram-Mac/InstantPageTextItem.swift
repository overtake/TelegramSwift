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

struct InstantPageTextUrlItem {
    let frame: CGRect
    let item: AnyObject
}

struct InstantPageTextStrikethroughItem {
    let frame: CGRect
}

final class InstantPageTextLine {
    let line: CTLine
    let frame: CGRect
    let urlItems: [InstantPageTextUrlItem]
    let strikethroughItems: [InstantPageTextStrikethroughItem]
    let attributedString: NSAttributedString
    var selectRect: NSRect = NSZeroRect
    init(line: CTLine, attributedString: NSAttributedString, frame: CGRect, urlItems: [InstantPageTextUrlItem], strikethroughItems: [InstantPageTextStrikethroughItem]) {
        self.line = line
        self.frame = frame
        self.attributedString = attributedString
        self.urlItems = urlItems
        self.strikethroughItems = strikethroughItems
    }
    
    func linkAt(point: NSPoint) -> RichText? {
        let index: CFIndex = CTLineGetStringIndexForPosition(line, point)
        if index >= 0 && index < attributedString.length {
            return attributedString.attribute(NSAttributedStringKey.link, at: index, effectiveRange: nil) as? RichText
        }
        return nil
    }
    
    func selectText(in rect: NSRect, boundingWidth: CGFloat, alignment: NSTextAlignment) -> NSAttributedString {
        
        
        let startIndex: CFIndex = CTLineGetStringIndexForPosition(line, NSMakePoint(rect.minX, 0))
        let endIndex: CFIndex = CTLineGetStringIndexForPosition(line, NSMakePoint(rect.maxX, 0))
        
        var startOffset = CTLineGetOffsetForStringIndex(line, startIndex, nil)
        var endOffset = CTLineGetOffsetForStringIndex(line, endIndex, nil)

        switch alignment {
        case .center:
            let additional = floorToScreenPixels(scaleFactor: System.backingScale, (boundingWidth - frame.width) / 2)
            startOffset += additional
            endOffset += additional
        default:
            break
        }
        
        selectRect = NSMakeRect(startOffset, frame.minY - 2, endOffset - startOffset, frame.height + 6)
        return attributedString.attributedSubstring(from: NSMakeRange(startIndex, endIndex - startIndex))
    }
    
    func selectWord(in point: NSPoint, boundingWidth: CGFloat, alignment: NSTextAlignment, rect: NSRect) -> NSAttributedString {
        
        
        let startIndex: CFIndex = CTLineGetStringIndexForPosition(line, point)
        
        
        
        var prev = startIndex
        var next = startIndex
        var range = NSMakeRange(startIndex, 1)
        let char:NSString = attributedString.string.nsstring.substring(with: range) as NSString
        var effectiveRange:NSRange = NSMakeRange(NSNotFound, 0)
        let check = attributedString.attribute(NSAttributedStringKey.link, at: range.location, effectiveRange: &effectiveRange)
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
            let additional = floorToScreenPixels(scaleFactor: System.backingScale, (boundingWidth - frame.width) / 2)
            startOffset += additional
            endOffset += additional
        default:
            break
        }
        
        selectRect = NSMakeRect(startOffset, frame.minY - 2, endOffset - startOffset, frame.height + 6)
        return attributedString.attributedSubstring(from: range)
    }
    
    func removeSelection() {
        selectRect = NSZeroRect
    }
}

final class InstantPageTextItem: InstantPageItem {
    let lines: [InstantPageTextLine]
    let hasLinks: Bool
    var frame: CGRect
    var alignment: NSTextAlignment = .left
    let medias: [InstantPageMedia] = []
    let wantsNode: Bool = false
    
    let isInteractive: Bool = false
    
    init(frame: CGRect, lines: [InstantPageTextLine]) {
        self.frame = frame
        self.lines = lines
        var hasLinks = false
        for line in lines {
            if !line.urlItems.isEmpty {
                hasLinks = true
            }
        }
        self.hasLinks = hasLinks
    }
    
    func linkAt(point: NSPoint) -> RichText? {
        for line in lines {
            var point = NSMakePoint(min(max(point.x, 0), frame.width), point.y)
            switch alignment {
            case .center:
                point.x -= floorToScreenPixels(scaleFactor: System.backingScale, (frame.width - line.frame.width) / 2)
            default:
                break
            }
            
            if line.frame.minY < point.y && line.frame.maxY > point.y {
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
        
        for line in self.lines {
            let lineFrame = line.frame
            if lineFrame.maxY < upperOriginBound || lineFrame.minY > lowerOriginBound {
                continue
            }
            
            var lineOrigin = lineFrame.origin
            if self.alignment == .center {
                lineOrigin.x = floor((boundsWidth - lineFrame.size.width) / 2.0)
            }
            
            context.setFillColor(theme.colors.selectText.cgColor)
            context.fill(line.selectRect)
            
            
            context.textPosition = CGPoint(x: lineOrigin.x, y: lineOrigin.y + lineFrame.size.height)
            CTLineDraw(line.line, context)
            
            if !line.strikethroughItems.isEmpty {
                for item in line.strikethroughItems {
                    context.fill(CGRect(x: item.frame.minX, y: item.frame.minY + floor((lineFrame.size.height / 2.0) + 1.0), width: item.frame.size.width, height: 1.0))
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
    
    func node(account: Account) -> InstantPageView? {
        return nil
    }
    
    func matchesNode(_ node: InstantPageView) -> Bool {
        return false
    }
    
    func distanceThresholdGroup() -> Int? {
        return nil
    }
    
    func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        return 0.0
    }
}


func attributedStringForRichText(_ text: RichText, styleStack: InstantPageTextStyleStack) -> NSAttributedString {
    switch text {
    case .empty:
        return NSAttributedString(string: "", attributes: styleStack.textAttributes())
    case let .plain(string):
        return NSAttributedString(string: string, attributes: styleStack.textAttributes())
    case let .bold(text):
        styleStack.push(.bold)
        let result = attributedStringForRichText(text, styleStack: styleStack)
        styleStack.pop()
        return result
    case let .italic(text):
        styleStack.push(.italic)
        let result = attributedStringForRichText(text, styleStack: styleStack)
        styleStack.pop()
        return result
    case let .underline(text):
        styleStack.push(.underline)
        let result = attributedStringForRichText(text, styleStack: styleStack)
        styleStack.pop()
        return result
    case let .strikethrough(text):
        styleStack.push(.strikethrough)
        let result = attributedStringForRichText(text, styleStack: styleStack)
        styleStack.pop()
        return result
    case let .fixed(text):
        styleStack.push(.fontFixed(true))
        let result = attributedStringForRichText(text, styleStack: styleStack)
        styleStack.pop()
        return result
    case let .url(text, url, webpageId):
        styleStack.push(.link(.url(text: text, url: url, webpageId: webpageId)))
        styleStack.push(.underline)
        let result = attributedStringForRichText(text, styleStack: styleStack)
        styleStack.pop()
        styleStack.pop()
        return result
    case let .email(text, email):
        styleStack.push(.bold)
        styleStack.push(.link(.url(text: text, url: email, webpageId: nil)))
        styleStack.push(.underline)
        let result = attributedStringForRichText(text, styleStack: styleStack)
        styleStack.pop()
        styleStack.pop()
        styleStack.pop()
        return result
    case let .concat(texts):
        let string = NSMutableAttributedString()
        for text in texts {
            let substring = attributedStringForRichText(text, styleStack: styleStack)
            string.append(substring)
        }
        return string
    }
}

func layoutTextItemWithString(_ string: NSAttributedString, boundingWidth: CGFloat) -> InstantPageTextItem {
    if string.length == 0 {
        return InstantPageTextItem(frame: CGRect(), lines: [])
    }
    
    var lines: [InstantPageTextLine] = []
    guard let font = string.attribute(NSAttributedStringKey.font, at: 0, effectiveRange: nil) as? NSFont else {
        return InstantPageTextItem(frame: CGRect(), lines: [])
    }
    
    var lineSpacingFactor: CGFloat = 1.12
    if let lineSpacingFactorAttribute = string.attribute(.instantPageLineSpacingFactor, at: 0, effectiveRange: nil) {
        lineSpacingFactor = CGFloat((lineSpacingFactorAttribute as! NSNumber).floatValue)
    }
    
    let typesetter = CTTypesetterCreateWithAttributedString(string)
    let fontAscent = font.ascender
    let fontDescent = font.descender
    
    let fontLineHeight = floor(fontAscent + fontDescent)
    let fontLineSpacing = floor(fontLineHeight * lineSpacingFactor)
    
    var lastIndex: CFIndex = 0
    var currentLineOrigin = CGPoint()
    
    while true {
        let currentMaxWidth = boundingWidth - currentLineOrigin.x
        let currentLineInset: CGFloat = 0.0
        let lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, lastIndex, Double(currentMaxWidth))
        
        if lineCharacterCount > 0 {
            let line = CTTypesetterCreateLineWithOffset(typesetter, CFRangeMake(lastIndex, lineCharacterCount), 100.0)
            
            let trailingWhitespace = CGFloat(CTLineGetTrailingWhitespaceWidth(line))
            let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil) + Double(currentLineInset))
            
            var urlItems: [InstantPageTextUrlItem] = []
            var strikethroughItems: [InstantPageTextStrikethroughItem] = []
            
            string.enumerateAttribute(.strikethroughStyle, in: NSMakeRange(lastIndex, lineCharacterCount), options: [], using: { item, range, _ in
                if let _ = item {
                    let lowerX = floor(CTLineGetOffsetForStringIndex(line, range.location, nil))
                    let upperX = ceil(CTLineGetOffsetForStringIndex(line, range.location + range.length, nil))
                    
                    strikethroughItems.append(InstantPageTextStrikethroughItem(frame: CGRect(x: currentLineOrigin.x + lowerX, y: currentLineOrigin.y, width: upperX - lowerX, height: fontLineHeight)))
                }
            })
            
            let textLine = InstantPageTextLine(line: line, attributedString: string, frame: CGRect(x: currentLineOrigin.x, y: currentLineOrigin.y, width: lineWidth, height: fontLineHeight), urlItems: urlItems, strikethroughItems: strikethroughItems)
            
            lines.append(textLine)
            
            var rightAligned = false
            
            /*let glyphRuns = CTLineGetGlyphRuns(line)
             if CFArrayGetCount(glyphRuns) != 0 {
             if (CTRunGetStatus(CFArrayGetValueAtIndex(glyphRuns, 0) as! CTRun).rawValue & CTRunStatus.rightToLeft.rawValue) != 0 {
             rightAligned = true
             }
             }*/
            
            //hadRTL |= rightAligned;
            
            currentLineOrigin.x = 0.0;
            currentLineOrigin.y += fontLineHeight + fontLineSpacing
            
            lastIndex += lineCharacterCount
            
        } else {
            break;
        }
    }
    
    var height: CGFloat = 0.0
    if !lines.isEmpty {
        height = lines.last!.frame.maxY
    }
    
    return InstantPageTextItem(frame: CGRect(x: 0.0, y: 0.0, width: boundingWidth, height: height), lines: lines)
}
