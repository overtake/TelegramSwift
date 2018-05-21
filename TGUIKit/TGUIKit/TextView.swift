//
//  TextView.swift
//  TGUIKit
//
//  Created by keepcoder on 15/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac


public enum LinkType {
    case plain
    case email
    case username
    case hashtag
    case command
    case stickerPack
    case inviteLink
}

public func isValidEmail(_ checkString:String) -> Bool {
    let emailRegex = ".+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2}[A-Za-z]*"
    let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    return emailTest.evaluate(with: checkString)
}

private enum CornerType {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

private func drawFullCorner(context: CGContext, color: NSColor, at point: CGPoint, type: CornerType, radius: CGFloat) {
    context.setFillColor(color.cgColor)
    switch type {
    case .topLeft:
        context.clear(CGRect(origin: point, size: CGSize(width: radius, height: radius)))
        context.fillEllipse(in: CGRect(origin: point, size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    case .topRight:
        context.clear(CGRect(origin: CGPoint(x: point.x - radius, y: point.y), size: CGSize(width: radius, height: radius)))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x - radius * 2.0, y: point.y), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    case .bottomLeft:
        context.clear(CGRect(origin: CGPoint(x: point.x, y: point.y - radius), size: CGSize(width: radius, height: radius)))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x, y: point.y - radius * 2.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    case .bottomRight:
        context.clear(CGRect(origin: CGPoint(x: point.x - radius, y: point.y - radius), size: CGSize(width: radius, height: radius)))
        context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x - radius * 2.0, y: point.y - radius * 2.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    }
}

private func drawConnectingCorner(context: CGContext, color: NSColor, at point: CGPoint, type: CornerType, radius: CGFloat) {
    context.setFillColor(color.cgColor)
    switch type {
    case .topLeft:
        context.fill(CGRect(origin: CGPoint(x: point.x - radius, y: point.y), size: CGSize(width: radius, height: radius)))
        context.setFillColor(NSColor.clear.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x - radius * 2.0, y: point.y), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    case .topRight:
        context.fill(CGRect(origin: CGPoint(x: point.x, y: point.y), size: CGSize(width: radius, height: radius)))
        context.setFillColor(NSColor.clear.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x, y: point.y), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    case .bottomLeft:
        context.fill(CGRect(origin: CGPoint(x: point.x - radius, y: point.y - radius), size: CGSize(width: radius, height: radius)))
        context.setFillColor(NSColor.clear.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x - radius * 2.0, y: point.y - radius * 2.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    case .bottomRight:
        context.fill(CGRect(origin: CGPoint(x: point.x, y: point.y - radius), size: CGSize(width: radius, height: radius)))
        context.setFillColor(NSColor.clear.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: point.x, y: point.y - radius * 2.0), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    }
}

private func generateRectsImage(color: NSColor, rects: [CGRect], inset: CGFloat, outerRadius: CGFloat, innerRadius: CGFloat) -> (CGPoint, CGImage?) {
    if rects.isEmpty {
        return (CGPoint(), nil)
    }
    
    var topLeft = rects[0].origin
    var bottomRight = CGPoint(x: rects[0].maxX, y: rects[0].maxY)
    for i in 1 ..< rects.count {
        topLeft.x = min(topLeft.x, rects[i].origin.x)
        topLeft.y = min(topLeft.y, rects[i].origin.y)
        bottomRight.x = max(bottomRight.x, rects[i].maxX)
        bottomRight.y = max(bottomRight.y, rects[i].maxY)
    }
    
    topLeft.x -= inset
    topLeft.y -= inset
    bottomRight.x += inset
    bottomRight.y += inset 
    
    return (topLeft, generateImage(CGSize(width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        
        context.setBlendMode(.copy)
        
        for i in 0 ..< rects.count {
            let rect = rects[i].insetBy(dx: -inset, dy: -inset)
            context.fill(rect.offsetBy(dx: -topLeft.x, dy: -topLeft.y))
        }
        
        for i in 0 ..< rects.count {
            let rect = rects[i].insetBy(dx: -inset, dy: -inset).offsetBy(dx: -topLeft.x, dy: -topLeft.y)
            
            var previous: CGRect?
            if i != 0 {
                previous = rects[i - 1].insetBy(dx: -inset, dy: -inset).offsetBy(dx: -topLeft.x, dy: -topLeft.y)
            }
            
            var next: CGRect?
            if i != rects.count - 1 {
                next = rects[i + 1].insetBy(dx: -inset, dy: -inset).offsetBy(dx: -topLeft.x, dy: -topLeft.y)
            }
            
            if let previous = previous {
                if previous.contains(rect.topLeft) {
                    if abs(rect.topLeft.x - previous.minX) >= innerRadius {
                        var radius = innerRadius
                        if let next = next {
                            radius = min(radius, floor((next.minY - previous.maxY) / 2.0))
                        }
                        drawConnectingCorner(context: context, color: color, at: CGPoint(x: rect.topLeft.x, y: previous.maxY), type: .topLeft, radius: radius)
                    }
                } else {
                    drawFullCorner(context: context, color: color, at: rect.topLeft, type: .topLeft, radius: outerRadius)
                }
                if previous.contains(rect.topRight.offsetBy(dx: -1.0, dy: 0.0)) {
                    if abs(rect.topRight.x - previous.maxX) >= innerRadius {
                        var radius = innerRadius
                        if let next = next {
                            radius = min(radius, floor((next.minY - previous.maxY) / 2.0))
                        }
                        drawConnectingCorner(context: context, color: color, at: CGPoint(x: rect.topRight.x, y: previous.maxY), type: .topRight, radius: radius)
                    }
                } else {
                    drawFullCorner(context: context, color: color, at: rect.topRight, type: .topRight, radius: outerRadius)
                }
            } else {
                drawFullCorner(context: context, color: color, at: rect.topLeft, type: .topLeft, radius: outerRadius)
                drawFullCorner(context: context, color: color, at: rect.topRight, type: .topRight, radius: outerRadius)
            }
            
            if let next = next {
                if next.contains(rect.bottomLeft) {
                    if abs(rect.bottomRight.x - next.maxX) >= innerRadius {
                        var radius = innerRadius
                        if let previous = previous {
                            radius = min(radius, floor((next.minY - previous.maxY) / 2.0))
                        }
                        drawConnectingCorner(context: context, color: color, at: CGPoint(x: rect.bottomLeft.x, y: next.minY), type: .bottomLeft, radius: radius)
                    }
                } else {
                    drawFullCorner(context: context, color: color, at: rect.bottomLeft, type: .bottomLeft, radius: outerRadius)
                }
                if next.contains(rect.bottomRight.offsetBy(dx: -1.0, dy: 0.0)) {
                    if abs(rect.bottomRight.x - next.maxX) >= innerRadius {
                        var radius = innerRadius
                        if let previous = previous {
                            radius = min(radius, floor((next.minY - previous.maxY) / 2.0))
                        }
                        drawConnectingCorner(context: context, color: color, at: CGPoint(x: rect.bottomRight.x, y: next.minY), type: .bottomRight, radius: radius)
                    }
                } else {
                    drawFullCorner(context: context, color: color, at: rect.bottomRight, type: .bottomRight, radius: outerRadius)
                }
            } else {
                drawFullCorner(context: context, color: color, at: rect.bottomLeft, type: .bottomLeft, radius: outerRadius)
                drawFullCorner(context: context, color: color, at: rect.bottomRight, type: .bottomRight, radius: outerRadius)
            }
        }
    }))
    
}



public final class TextViewInteractions {
    public var processURL:(Any)->Void // link, isPresent
    public var copy:(()->Bool)?
    public var menuItems:((LinkType?)->Signal<[ContextMenuItem], Void>)?
    public var isDomainLink:(String)->Bool
    public var makeLinkType:((Any, String))->LinkType
    public var localizeLinkCopy:(LinkType)-> String
    public init(processURL:@escaping (Any)->Void = {_ in}, copy:(()-> Bool)? = nil, menuItems:((LinkType?)->Signal<[ContextMenuItem], Void>)? = nil, isDomainLink:@escaping(String)->Bool = {_ in return true}, makeLinkType:@escaping((Any, String)) -> LinkType = {_ in return .plain}, localizeLinkCopy:@escaping(LinkType)-> String = {_ in return localizedString("Text.Copy")}) {
        self.processURL = processURL
        self.copy = copy
        self.menuItems = menuItems
        self.isDomainLink = isDomainLink
        self.makeLinkType = makeLinkType
        self.localizeLinkCopy = localizeLinkCopy
    }
}

public final class TextViewLine {
    public let line: CTLine
    public let frame: NSRect
    public let range: NSRange
    init(line: CTLine, frame: CGRect, range: NSRange) {
        self.line = line
        self.frame = frame
        self.range = range
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
    public var mayItems: Bool = true
    public var selectWholeText: Bool = false
    public fileprivate(set) var attributedString:NSAttributedString
    public fileprivate(set) var constrainedWidth:CGFloat = 0
    public var interactions:TextViewInteractions = TextViewInteractions()
    public var selectedRange:TextSelectedRange
    public var penFlush:CGFloat
    public var insets:NSSize = NSZeroSize
    public fileprivate(set) var lines:[TextViewLine] = []
    public fileprivate(set) var isPerfectSized:Bool = true
    public let maximumNumberOfLines:Int32
    public let truncationType:CTLineTruncationType
    public var cutout:TextViewCutout?
    public var mayBlocked: Bool = true
    fileprivate var blockImage:(CGPoint, CGImage?) = (CGPoint(), nil)

    public fileprivate(set) var lineSpacing:CGFloat?
    
    public private(set) var layoutSize:NSSize = NSZeroSize
    public private(set) var perfectSize:NSSize = NSZeroSize
    public var alwaysStaticItems: Bool
    fileprivate var selectText: NSColor
    public var strokeLinks: Bool
    fileprivate var strokeRects: [(NSRect, NSColor)] = []
    public init(_ attributedString:NSAttributedString, constrainedWidth:CGFloat = 0, maximumNumberOfLines:Int32 = INT32_MAX, truncationType: CTLineTruncationType = .end, cutout:TextViewCutout? = nil, alignment:NSTextAlignment = .left, lineSpacing:CGFloat? = nil, selectText: NSColor = presentation.colors.selectText, strokeLinks: Bool = false, alwaysStaticItems: Bool = false) {
        self.truncationType = truncationType
        self.maximumNumberOfLines = maximumNumberOfLines
        self.cutout = cutout
        self.attributedString = attributedString
        self.constrainedWidth = constrainedWidth
        self.selectText = selectText
        self.alwaysStaticItems = alwaysStaticItems
        self.selectedRange = TextSelectedRange(color: selectText)
        self.strokeLinks = strokeLinks
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
            if let stringFont = attributedString.attribute(NSAttributedStringKey(kCTFontAttributeName as String), at: 0, effectiveRange: nil) {
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
        
        var monospacedRects:[NSRect] = []
        
        var fontLineSpacing:CGFloat = floor(fontLineHeight * 0.12)

        
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
        var breakInset: CGFloat = 0
        var isWasPreformatted: Bool = false
        while true {
            var lineConstrainedWidth = constrainedWidth
            var lineOriginY: CGFloat = 0
            
            var lineCutoutOffset: CGFloat = 0.0
            var lineAdditionalWidth: CGFloat = 0.0

            var isPreformattedLine: CGFloat? = nil
            
            fontLineSpacing = floor(fontLineHeight * 0.12)
            
            
            

            
            
            if attributedString.length > 0, let space = (attributedString.attribute(.preformattedPre, at: min(lastLineCharacterIndex, attributedString.length - 1), effectiveRange: nil) as? NSNumber), mayBlocked {
                
                
                
                
                breakInset = CGFloat(space.floatValue * 2)
                lineCutoutOffset += CGFloat(space.floatValue)
                lineAdditionalWidth += breakInset
                
                lineOriginY += CGFloat(space.floatValue/2)

                if !isWasPreformatted && !first {
                    lineOriginY += CGFloat(space.floatValue)
                    fontLineSpacing = CGFloat(space.floatValue) - fontLineSpacing
                } else {
                    if isWasPreformatted || first {
                        fontLineSpacing = -CGFloat(space.floatValue/2)
                        lineOriginY -= (CGFloat(space.floatValue + space.floatValue/2))
                    }
                }

                isPreformattedLine = CGFloat(space.floatValue)
                isWasPreformatted = true
            } else {
                
                if isWasPreformatted && !first {
                    lineOriginY -= (2 - fontLineSpacing)
                }
                
                isWasPreformatted = false
            }
            
            lineOriginY += floor(layoutSize.height + fontLineHeight - fontLineSpacing * 2.0)
            
            if !first {
                lineOriginY += fontLineSpacing
            }
            
            if cutoutEnabled {
                if lineOriginY < cutoutMaxY && lineOriginY + fontLineHeight > cutoutMinY {
                    lineConstrainedWidth = max(1.0, lineConstrainedWidth - cutoutWidth)
                    lineCutoutOffset = cutoutOffset
                    lineAdditionalWidth = cutoutWidth
                }
            }
            
            
            
            let lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, lastLineCharacterIndex, Double(lineConstrainedWidth - breakInset))
            let lineRange = CFRange(location: lastLineCharacterIndex, length: lineCharacterCount)

            
            var lineHeight = fontLineHeight
            
            let lineString = attributedString.attributedSubstring(from: NSMakeRange(lastLineCharacterIndex, lineCharacterCount))
            if !lineString.string.emojiString.isEmpty {
                lineHeight += floor(fontDescent)
                if first {
                    lineOriginY += floor(fontDescent)
                }
            }
            
            if maximumNumberOfLines != 0 && lines.count == (Int(maximumNumberOfLines) - 1) && lineCharacterCount > 0 {
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
                    var truncationTokenAttributes: [NSAttributedStringKey : Any] = [:]
                    truncationTokenAttributes[NSAttributedStringKey(kCTFontAttributeName as String)] = font
                    truncationTokenAttributes[NSAttributedStringKey(kCTForegroundColorFromContextAttributeName as String)] = true as NSNumber
                    let tokenString = "\u{2026}"
                    let truncatedTokenString = NSAttributedString(string: tokenString, attributes: truncationTokenAttributes)
                    let truncationToken = CTLineCreateWithAttributedString(truncatedTokenString)
                    
                    coreTextLine = CTLineCreateTruncatedLine(originalLine, Double(constrainedWidth), truncationType, truncationToken) ?? truncationToken
                    isPerfectSized = false
                }
                
                
                let lineWidth = ceil(CGFloat(CTLineGetTypographicBounds(coreTextLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(coreTextLine)))
                let lineFrame = CGRect(x: lineCutoutOffset, y: lineOriginY, width: lineWidth, height: lineHeight)
                layoutSize.height += lineHeight + fontLineSpacing
                layoutSize.width = max(layoutSize.width, lineWidth + lineAdditionalWidth)
                
                lines.append(TextViewLine(line: coreTextLine, frame: lineFrame, range: NSMakeRange(lineRange.location, lineRange.length)))
                
                break
            } else {
                if lineCharacterCount > 0 {
                    
                    
                    if first {
                        first = false
                    } else {
                        layoutSize.height += fontLineSpacing
                    }
                    
                    let coreTextLine = CTTypesetterCreateLineWithOffset(typesetter, CFRangeMake(lastLineCharacterIndex, lineCharacterCount), 100.0)
                    
                  
                    let lineWidth = ceil(CGFloat(CTLineGetTypographicBounds(coreTextLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(coreTextLine)))
                    let lineFrame = CGRect(x: lineCutoutOffset, y: lineOriginY, width: lineWidth, height: lineHeight)
                    layoutSize.height += lineHeight
                    layoutSize.width = max(layoutSize.width, lineWidth + lineAdditionalWidth)
                    
                    if let space = lineString.attribute(.preformattedPre, at: 0, effectiveRange: nil) as? NSNumber, mayBlocked {
                        
                        layoutSize.width = self.constrainedWidth
                        let preformattedSpace = CGFloat(space.floatValue) * 2
                        
                        monospacedRects.append(NSMakeRect(0, lineFrame.minY - lineFrame.height, layoutSize.width, lineFrame.height + preformattedSpace))
                    }

                    lines.append(TextViewLine(line: coreTextLine, frame: lineFrame, range: NSMakeRange(lineRange.location, lineRange.length)))
                    lastLineCharacterIndex += lineCharacterCount
                } else {
                    if !lines.isEmpty {
                        layoutSize.height += fontLineSpacing
                    }
                    break
                }
            }
            
            if mayBlocked {
                if let isPreformattedLine = isPreformattedLine {
                    layoutSize.height += isPreformattedLine * 2
                    if lastLineCharacterIndex == attributedString.length {
                        layoutSize.height += isPreformattedLine/2
                    }
                    // fontLineSpacing = isPreformattedLine
                }
            }
            
        }
        
        if mayBlocked {
            let sortedIndices = (0 ..< monospacedRects.count).sorted(by: { monospacedRects[$0].width > monospacedRects[$1].width })
            for i in 0 ..< sortedIndices.count {
                let index = sortedIndices[i]
                for j in -1 ... 1 {
                    if j != 0 && index + j >= 0 && index + j < sortedIndices.count {
                        if abs(monospacedRects[index + j].width - monospacedRects[index].width) < 40.0 {
                            monospacedRects[index + j].size.width = max(monospacedRects[index + j].width, monospacedRects[index].width)
                        }
                    }
                }
            }
            
            self.blockImage = generateRectsImage(color: presentation.colors.grayBackground, rects: monospacedRects, inset: 0, outerRadius: .cornerRadius, innerRadius: .cornerRadius)
        }
        
        
        
        //self.monospacedStrokeImage = generateRectsImage(color: presentation.colors.border, rects: monospacedRects, inset: 0, outerRadius: .cornerRadius, innerRadius: .cornerRadius)

        
        self.layoutSize = layoutSize
    }
    
    public func generateAutoBlock(backgroundColor: NSColor) {
        
        var rects = self.lines.map({$0.frame})
        
        if !rects.isEmpty {
            let sortedIndices = (0 ..< rects.count).sorted(by: { rects[$0].width > rects[$1].width })
            for i in 0 ..< sortedIndices.count {
                let index = sortedIndices[i]
                for j in -1 ... 1 {
                    if j != 0 && index + j >= 0 && index + j < sortedIndices.count {
                        if abs(rects[index + j].width - rects[index].width) < 40.0 {
                            rects[index + j].size.width = max(rects[index + j].width, rects[index].width)
                        }
                    }
                }
            }
            
            for i in 0 ..< rects.count {
                rects[i] = rects[i].insetBy(dx: 0, dy: floor((rects[i].height - 20.0) / 2.0))
                rects[i].size.height = 22
                rects[i].origin.x = floor((layoutSize.width - rects[i].width) / 2.0)
                rects[i].size.width += 20
            }
            
            self.blockImage = generateRectsImage(color: backgroundColor, rects: rects, inset: 0, outerRadius: rects[0].height / 2, innerRadius: .cornerRadius)
            self.blockImage.0 = NSMakePoint(0, 0)
            
            layoutSize.width += 20
            lines[0] = TextViewLine(line: lines[0].line, frame: lines[0].frame.offsetBy(dx: 0, dy: 2), range: lines[0].range)
            layoutSize.height = rects.last!.maxY
        }
        
    }
    
    public func selectNextChar() {
        var range = selectedRange.range
        
        switch selectedRange.cursorAlignment {
        case let .min(cursorAlignment), let .max(cursorAlignment):
            if range.min >= cursorAlignment {
                range.length += 1
            } else {
                range.location += 1
                if range.length > 1 {
                    range.length -= 1
                }
            }
        }
        let location = min(max(0, range.location), attributedString.length)
        let length = max(min(range.length, attributedString.length - location), 0)
        selectedRange.range = NSMakeRange(location, length)
    }
    
    public func selectPrevChar() {
        var range = selectedRange.range
        
        switch selectedRange.cursorAlignment {
            case let .min(cursorAlignment), let .max(cursorAlignment):
            if range.location >= cursorAlignment {
                if range.length > 1 {
                    range.length -= 1
                } else {
                    range.location -= 1
                }
            } else {
                if range.location > 0 {
                    range.location -= 1
                    range.length += 1
                }
            }
        }
        let location = min(max(0, range.location), attributedString.length)
        let length = max(min(range.length, attributedString.length - location), 0)
        selectedRange.range = NSMakeRange(location, length)
    }
    
    public func measure(width: CGFloat = 0) -> Void {
        
        if width != 0 {
            constrainedWidth = width
        }
        calculateLayout()

        strokeRects.removeAll()
        if strokeLinks {
            attributedString.enumerateAttribute(NSAttributedStringKey.link, in: attributedString.range, options: NSAttributedString.EnumerationOptions(rawValue: 0), using: { value, range, stop in
                if let _ = value, self.interactions.isDomainLink(attributedString.string.nsstring.substring(with: range)) {
                    
                    for line in self.lines {
                        let lineRange = NSIntersectionRange(range, line.range)
                        if lineRange.length != 0 {
                            var leftOffset: CGFloat = 0.0
                            if lineRange.location != line.range.location {
                                leftOffset = floor(CTLineGetOffsetForStringIndex(line.line, lineRange.location, nil))
                            }
                            let rightOffset: CGFloat = ceil(CTLineGetOffsetForStringIndex(line.line, lineRange.location + lineRange.length, nil))
                            
                            
                            let color: NSColor = self.attributedString.attribute(NSAttributedStringKey.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor ?? presentation.colors.link
                            let rect = NSMakeRect(line.frame.minX + leftOffset, line.frame.minY + 1, rightOffset - leftOffset, 1.0)
                            
                            self.strokeRects.append((rect, color))
                        }
                    }
                }
    
            })
        }
        
        
        
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
        return selectedRange.range.indexIn(index)
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

    public func link(at point:NSPoint) -> (Any, LinkType, NSRange, NSRect)? {
        
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
            
            let link:Any? = attrs[NSAttributedStringKey.link]
            if let link = link {
                let startOffset = CTLineGetOffsetForStringIndex(line.line, range.location, nil);
                let endOffset = CTLineGetOffsetForStringIndex(line.line, range.location + range.length, nil);
                
                return (link, interactions.makeLinkType((link, attributedString.attributedSubstring(from: range).string)), range, NSMakeRect(startOffset, line.frame.minY, endOffset - startOffset, ceil(ascent + ceil(descent) + leading)))
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
    
    public func selectAll(at point:NSPoint) -> Void {
        
        let startIndex = findCharacterIndex(at: point)
        if startIndex == -1 {
            return
        }
        
        var blockRange: NSRange = NSMakeRange(NSNotFound, 0)
        if let _ = attributedString.attribute(.preformattedPre, at: startIndex, effectiveRange: &blockRange) {
            self.selectedRange = TextSelectedRange(range: blockRange, color: selectText, def: true)
        } else {
            self.selectedRange = TextSelectedRange(range: NSMakeRange(0,attributedString.length), color: selectText, def: true)
        }
        
    }
    
    public func selectWord(at point:NSPoint) -> Void {
        
        if selectWholeText {
            self.selectedRange = TextSelectedRange(range: attributedString.range, color: selectText, def: true)
            return
        }
        
        let startIndex = findCharacterIndex(at: point)
        if startIndex == -1 {
            return
        }
        var prev = startIndex
        var next = startIndex
        var range = NSMakeRange(startIndex, 1)
        let char:NSString = attributedString.string.nsstring.substring(with: range) as NSString
        var effectiveRange:NSRange = NSMakeRange(NSNotFound, 0)
        let check = attributedString.attribute(NSAttributedStringKey.link, at: range.location, effectiveRange: &effectiveRange)
        if check != nil && effectiveRange.location != NSNotFound {
            self.selectedRange = TextSelectedRange(range: effectiveRange, color: selectText, def: true)
            return
        }
        if char == "" {
            self.selectedRange = TextSelectedRange(color: selectText)
            return
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
        
        self.selectedRange = TextSelectedRange(range: range, color: selectText, def: true)
    }
    

}

public func ==(lhs:TextViewLayout, rhs:TextViewLayout) -> Bool {
    return lhs.constrainedWidth == rhs.constrainedWidth && lhs.attributedString.isEqual(to: rhs.attributedString) && lhs.selectedRange == rhs.selectedRange && lhs.maximumNumberOfLines == rhs.maximumNumberOfLines && lhs.cutout == rhs.cutout && lhs.truncationType == rhs.truncationType && lhs.constrainedWidth == rhs.constrainedWidth
}

public enum CursorSelectAlignment {
    case min(Int)
    case max(Int)
}

public struct TextSelectedRange: Equatable {
    
    
    public var range:NSRange = NSMakeRange(NSNotFound, 0)
    public var color:NSColor = presentation.colors.selectText
    public var def:Bool = true
    
    init(range: NSRange = NSMakeRange(NSNotFound, 0), color: NSColor = presentation.colors.selectText, def: Bool = true, cursorAlignment: CursorSelectAlignment = .min(0)) {
        self.range = range
        self.color = color
        self.def = def
        self.cursorAlignment = cursorAlignment
    }
    
    public var cursorAlignment: CursorSelectAlignment = .min(0)
    
    public var hasSelectText:Bool {
        return range.location != NSNotFound
    }
}

public func ==(lhs:TextSelectedRange, rhs:TextSelectedRange) -> Bool {
    return lhs.def == rhs.def && lhs.range.location == rhs.range.location && lhs.range.length == rhs.range.length
}


public class TextView: Control {
    
    private let menuDisposable = MetaDisposable()
    
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
        layer?.disableActions()
        self.style = ControlStyle(backgroundColor: presentation.colors.background)
//        wantsLayer = false
//        self.layer?.delegate = nil
    }

    public override var isFlipped: Bool {
        return true
    }

    public required init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        layer?.disableActions()
        self.style = ControlStyle(backgroundColor: presentation.colors.background)
//        wantsLayer = false
//        self.layer?.delegate = nil
       // self.layer?.drawsAsynchronously = System.drawAsync
    }

    public var disableBackgroundDrawing: Bool = false

    public override func draw(_ layer: CALayer, in ctx: CGContext) {
        //backgroundColor = .random
        super.draw(layer, in: ctx)

        if let layout = layout {
            
           
            ctx.setAllowsAntialiasing(true)
            
            ctx.setAllowsFontSmoothing(backingScaleFactor == 1.0)
            ctx.setShouldSmoothFonts(backingScaleFactor == 1.0)
            
            if backingScaleFactor == 1.0 && !disableBackgroundDrawing {
                ctx.setFillColor(backgroundColor.cgColor)
                for line in layout.lines {
                    ctx.fill(NSMakeRect(0, line.frame.minY - line.frame.height - 2, line.frame.width, line.frame.height + 6))
                }
            }
            
            
            if let image = layout.blockImage.1 {
                ctx.draw(image, in: NSMakeRect(layout.blockImage.0.x, layout.blockImage.0.y, image.backingSize.width, image.backingSize.height))
            }
            
            
            
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
                        
                        let blockValue:CGFloat = layout.mayBlocked ? CGFloat((layout.attributedString.attribute(.preformattedPre, at: beginLineIndex, effectiveRange: nil) as? NSNumber)?.floatValue ?? 0) : 0
                        
                        

                        rect.size.width = width - blockValue / 2

                        rect.origin.x = startOffset + blockValue
                        rect.origin.y = rect.minY - rect.height + blockValue / 2
                        rect.size.height += ceil(descent - leading)
                        let color:NSColor = layout.selectText
                        
                        ctx.setFillColor(color.cgColor)
                        ctx.fill(rect)
                    }

                    i += isReversed ? -1 : 1
                    
                }
                
            }
            
            let textMatrix = ctx.textMatrix
            let textPosition = ctx.textPosition
            let startPosition = focus(layout.layoutSize).origin
            
     
            
            ctx.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
            
            
            for i in 0 ..< layout.lines.count {
                let line = layout.lines[i]
                
                let penOffset = CGFloat( CTLineGetPenOffsetForFlush(line.line, layout.penFlush, Double(frame.width))) + line.frame.minX
                
                ctx.textPosition = CGPoint(x: penOffset, y: startPosition.y + line.frame.minY)
                
               
                
                CTLineDraw(line.line, ctx)
                
            }
            
            ctx.textMatrix = textMatrix
            ctx.textPosition = CGPoint(x: textPosition.x, y: textPosition.y)
            
            for stroke in layout.strokeRects {
                ctx.setFillColor(stroke.1.cgColor)
                ctx.fill(stroke.0)
            }
            
        }
        
    }
    
    
    public override func rightMouseDown(with event: NSEvent) {
        if let layout = layout, userInteractionEnabled, layout.mayItems {
            let location = convert(event.locationInWindow, from: nil)
            if (!layout.selectedRange.hasSelectText || !layout.inSelectedRange(location)) && (!layout.alwaysStaticItems || layout.link(at: location) != nil) {
                layout.selectWord(at : location)
            }
            self.setNeedsDisplayLayer()
            if layout.selectedRange.hasSelectText || !layout.alwaysStaticItems {
                let link = layout.link(at: convert(event.locationInWindow, from: nil))
                
                
                if let menuItems = layout.interactions.menuItems?(link?.1) {
                    menuDisposable.set((menuItems |> deliverOnMainQueue).start(next:{ [weak self] items in
                        if let strongSelf = self {
                            let menu = NSMenu()
                            for item in items {
                                menu.addItem(item)
                            }
                            NSMenu.popUpContextMenu(menu, with: event, for: strongSelf)
                        }
                    }))
                } else {
                    let link = layout.link(at: location)
                    let menu = NSMenu()
                    let copy = ContextMenuItem(link?.1 != nil ? layout.interactions.localizeLinkCopy(link!.1) : localizedString("Text.Copy"), handler: { [weak self] in
                        guard let `self` = self else {return}
                        self.copy(self)
                    })
                   // let copy = NSMenuItem(title: , action: #selector(copy(_:)), keyEquivalent: "")
                    menu.addItem(copy)
                    NSMenu.popUpContextMenu(menu, with: event, for: self)
                }
            } else {
                layout.selectedRange.range = NSMakeRange(NSNotFound, 0)
                needsDisplay = true
                super.rightMouseDown(with: event)
            }
        } else {
            super.rightMouseDown(with: event)
        }
    }
    
    /*
     var view: NSTextView? = (self.window?.fieldEditor(true, forObject: self) as? NSTextView)
     view?.isEditable = false
     view?.isSelectable = true
     view?.string = layout.attributedString.string
     view?.selectedRange = NSRange(location: 0, length: view?.string?.length)
     NSMenu.popUpContextMenu(view?.menu(for: event), with: event, for: view)
 */
    
    public override func menu(for event: NSEvent) -> NSMenu? {
        
        return nil
    }
    
    deinit {
        menuDisposable.dispose()
    }
    
    public func isEqual(to layout:TextViewLayout) -> Bool {
        return self.layout == layout
    }
    
    public func update(_ layout:TextViewLayout?, origin:NSPoint? = nil) -> Void {
        self.layout = layout
        
        if let layout = layout {
            self.set(selectedRange: layout.selectedRange.range, display: false)
            let point:NSPoint
            if let origin = origin {
                point = origin
            } else {
                point = frame.origin
            }
            self.frame = NSMakeRect(point.x, point.y, layout.layoutSize.width + layout.insets.width, layout.layoutSize.height + layout.insets.height)
        } else {
            self.set(selectedRange: NSMakeRange(NSNotFound, 0), display: false)
            self.frame = NSZeroRect
        }
        self.setNeedsDisplayLayer()
    }
    
    public func set(layout:TextViewLayout?) {
        self.layout = layout
        self.setNeedsDisplayLayer()
    }
    
    func set(selectedRange range:NSRange, display:Bool = true) -> Void {
        
        if let layout = layout {
            layout.selectedRange = TextSelectedRange(range:range, color: layout.selectText, def:true)
        }
        
        beginSelect = NSMakePoint(-1, -1)
        endSelect = NSMakePoint(-1, -1)
        
        
        if display {
            self.setNeedsDisplayLayer()
        }
        
    }
    
    public override func mouseDown(with event: NSEvent) {
        
        if event.modifierFlags.contains(.control) {
            rightMouseDown(with: event)
            return
        }
        
        if isSelectable && !event.modifierFlags.contains(.shift)  {
            self.window?.makeFirstResponder(nil)
        }
        if !userInteractionEnabled {
            super.mouseDown(with: event)
        } else if let layout = layout {
            let point = self.convert(event.locationInWindow, from: nil)
            let index = layout.findIndex(location: point)
            if point.x > layout.lines[index].frame.maxX {
                superview?.mouseDown(with: event)
            }
        }
        
        _mouseDown(with: event)
        
    }
    
    func _mouseDown(with event: NSEvent) -> Void {
        
        if !isSelectable || !userInteractionEnabled || event.modifierFlags.contains(.shift) {
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
            layout.selectedRange.cursorAlignment = beginSelect.x > endSelect.x ? .min(layout.selectedRange.range.max) : .max(layout.selectedRange.range.min)
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
                layout.selectAll(at: point)
                layout.selectedRange.cursorAlignment = .max(layout.selectedRange.range.min)
            } else if event.clickCount == 2 || (event.type == .rightMouseUp  && !layout.selectedRange.hasSelectText) {
                layout.selectWord(at : point)
                layout.selectedRange.cursorAlignment = .max(layout.selectedRange.range.min)
            } else if !layout.selectedRange.hasSelectText || !isSelectable && event.clickCount == 1 {
                if let (link, _, _, _) = layout.link(at: point) {
                    layout.interactions.processURL(link)
                }
            } else if layout.selectedRange.hasSelectText && event.clickCount == 1 && event.modifierFlags.contains(.shift) {
                var range = layout.selectedRange.range
                let index = layout.findCharacterIndex(at: point)
                if index < range.min {
                    range.length += (range.location - index)
                    range.location = index
                } else if index > range.max {
                    range.length = (index - range.location)
                }
                layout.selectedRange.range = range
            }
            setNeedsDisplay()
        }
    }
    

    
    func checkCursor(_ event:NSEvent) -> Void {
        let location = self.convert(event.locationInWindow, from: nil)
        
        if self.mouse(location , in: self.visibleRect) && mouseInside() && userInteractionEnabled {
            
            if let layout = layout, let (_, _, _, _) = layout.link(at: location) {
                NSCursor.pointingHand.set()
            } else if isSelectable {
                NSCursor.iBeam.set()
            } else {
                NSCursor.arrow.set()
            }
        } else {
            NSCursor.arrow.set()
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
        if let layout = layout {
            if let copy = layout.interactions.copy {
                if !copy() && layout.selectedRange.range.location != NSNotFound {
                    let pb = NSPasteboard.general
                    pb.declareTypes([.string], owner: self)
                    pb.setString(layout.attributedString.string.nsstring.substring(with: layout.selectedRange.range), forType: .string)
                }
            } else if layout.selectedRange.range.location != NSNotFound {
                let pb = NSPasteboard.general
                pb.declareTypes([.string], owner: self)
                pb.setString(layout.attributedString.string.nsstring.substring(with: layout.selectedRange.range), forType: .string)
            }
        }
    }
    
    @objc func paste(_ sender:Any) {
        
    }
    
    public override func removeFromSuperview() {
        super.removeFromSuperview()
    }
    
 
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
