//
//  TextView.swift
//  TGUIKit
//
//  Created by keepcoder on 15/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import ColorPalette


public enum LinkType {
    case plain
    case email
    case username
    case hashtag
    case command
    case stickerPack
    case emojiPack
    case inviteLink
    case code
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

public extension NSAttributedString.Key {
    static let hexColorMark = NSAttributedString.Key("TextViewHexColorMarkAttribute")
    static let hexColorMarkDimensions = NSAttributedString.Key("TextViewHexColorMarkAttributeDimensions")
}

private final class TextViewEmbeddedItem {
    let range: NSRange
    let frame: CGRect
    let item: AnyHashable
    
    init(range: NSRange, frame: CGRect, item: AnyHashable) {
        self.range = range
        self.frame = frame
        self.item = item
    }
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

public enum LinkHoverValue {
    case entered(Any)
    case exited
}

public final class TextViewInteractions {
    public var processURL:(Any)->Void // link, isPresent
    public var copy:(()->Bool)?
    public var menuItems:((LinkType?)->Signal<[ContextMenuItem], NoError>)?
    public var isDomainLink:(Any, String?)->Bool
    public var makeLinkType:((Any, String))->LinkType
    public var localizeLinkCopy:(LinkType)-> String
    public var resolveLink:(Any)->String?
    public var copyAttributedString:(NSAttributedString)->Bool
    public var copyToClipboard:((String)->Void)?
    public var hoverOnLink: (LinkHoverValue)->Void
    public var topWindow:(()->Signal<Window?, NoError>)? = nil
    public var translate:((String, Window)->ContextMenuItem?)? = nil
    public init(processURL:@escaping (Any)->Void = {_ in}, copy:(()-> Bool)? = nil, menuItems:((LinkType?)->Signal<[ContextMenuItem], NoError>)? = nil, isDomainLink:@escaping(Any, String?)->Bool = {_, _ in return true}, makeLinkType:@escaping((Any, String)) -> LinkType = {_ in return .plain}, localizeLinkCopy:@escaping(LinkType)-> String = {_ in return localizedString("Text.Copy")}, resolveLink: @escaping(Any)->String? = { _ in return nil }, copyAttributedString: @escaping(NSAttributedString)->Bool = { _ in return false}, copyToClipboard: ((String)->Void)? = nil, hoverOnLink: @escaping(LinkHoverValue)->Void = { _ in }, topWindow:(()->Signal<Window?, NoError>)? = nil, translate:((String, Window)->ContextMenuItem?)? = nil) {
        self.processURL = processURL
        self.copy = copy
        self.menuItems = menuItems
        self.isDomainLink = isDomainLink
        self.makeLinkType = makeLinkType
        self.localizeLinkCopy = localizeLinkCopy
        self.resolveLink = resolveLink
        self.copyAttributedString = copyAttributedString
        self.copyToClipboard = copyToClipboard
        self.hoverOnLink = hoverOnLink
        self.topWindow = topWindow
        self.translate = translate
    }
}

struct TextViewStrikethrough {
    let color: NSColor
    let frame: NSRect
    init(color: NSColor, frame: NSRect) {
        self.color = color
        self.frame = frame
    }
}

public final class TextViewLine {
    public let line: CTLine
    public let frame: NSRect
    public let range: NSRange
    public var penFlush: CGFloat
    let isRTL: Bool
    let isBlocked: Bool
    let strikethrough:[TextViewStrikethrough]
    fileprivate let embeddedItems:[TextViewEmbeddedItem]
    fileprivate init(line: CTLine, frame: CGRect, range: NSRange, penFlush: CGFloat, isBlocked: Bool = false, isRTL: Bool = false, strikethrough: [TextViewStrikethrough] = [], embeddedItems:[TextViewEmbeddedItem] = []) {
        self.line = line
        self.frame = frame
        self.range = range
        self.penFlush = penFlush
        self.isBlocked = isBlocked
        self.strikethrough = strikethrough
        self.isRTL = isRTL
        self.embeddedItems = embeddedItems
    }
    
}


public enum TextViewCutoutPosition {
    case TopLeft
    case TopRight
    case BottomRight
}

public struct TextViewCutout: Equatable {
    public var topLeft: CGSize?
    public var topRight: CGSize?
    public var bottomRight: CGSize?
    
    public init(topLeft: CGSize? = nil, topRight: CGSize? = nil, bottomRight: CGSize? = nil) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
    }
}

private let defaultFont:NSFont = .normal(.text)

public final class TextViewLayout : Equatable {
    
    public final class EmbeddedItem: Equatable {
            public let range: NSRange
            public let rect: CGRect
            public let value: AnyHashable
            
            public init(range: NSRange, rect: CGRect, value: AnyHashable) {
                self.range = range
                self.rect = rect
                self.value = value
            }
            
            public static func ==(lhs: EmbeddedItem, rhs: EmbeddedItem) -> Bool {
                if lhs.range != rhs.range {
                    return false
                }
                if lhs.rect != rhs.rect {
                    return false
                }
                if lhs.value != rhs.value {
                    return false
                }
                return true
            }
        }

    
    public class Spoiler {
        public let range: NSRange
        public let color: NSColor
        public fileprivate(set) var isRevealed: Bool = false
        public init(range: NSRange, color: NSColor, isRevealed: Bool = false) {
            self.range = range
            self.color = color.withAlphaComponent(1.0)
            self.isRevealed = isRevealed
        }
    }
    
    public var mayItems: Bool = true
    public var selectWholeText: Bool = false
    public fileprivate(set) var attributedString:NSAttributedString
    public fileprivate(set) var constrainedWidth:CGFloat = 0
    public var interactions:TextViewInteractions = TextViewInteractions()
    public var selectedRange:TextSelectedRange
    public var additionalSelections:[TextSelectedRange] = []
    public var penFlush:CGFloat
    fileprivate var insets:NSSize = NSZeroSize
    public fileprivate(set) var lines:[TextViewLine] = []
    public fileprivate(set) var isPerfectSized:Bool = true
    public var maximumNumberOfLines:Int32
    public let truncationType:CTLineTruncationType
    public var cutout:TextViewCutout?
    public var mayBlocked: Bool = false
    fileprivate var blockImage:(CGPoint, CGImage?) = (CGPoint(), nil)
    
    public fileprivate(set) var lineSpacing:CGFloat?
    
    public private(set) var layoutSize:NSSize = NSZeroSize
    public private(set) var perfectSize:NSSize = NSZeroSize
    public var alwaysStaticItems: Bool
    fileprivate var selectText: NSColor
    public var strokeLinks: Bool
    fileprivate var strokeRects: [(NSRect, NSColor)] = []
    fileprivate var hexColorsRect: [(NSRect, NSColor, String)] = []
    fileprivate var toolTipRects:[NSRect] = []
    private let disableTooltips: Bool
    public fileprivate(set) var isBigEmoji: Bool = false
    fileprivate let spoilers:[Spoiler]
    private let onSpoilerReveal: ()->Void
    public private(set) var embeddedItems: [EmbeddedItem] = []
    public init(_ attributedString:NSAttributedString, constrainedWidth:CGFloat = 0, maximumNumberOfLines:Int32 = INT32_MAX, truncationType: CTLineTruncationType = .end, cutout:TextViewCutout? = nil, alignment:NSTextAlignment = .left, lineSpacing:CGFloat? = nil, selectText: NSColor = presentation.colors.selectText, strokeLinks: Bool = false, alwaysStaticItems: Bool = false, disableTooltips: Bool = true, mayItems: Bool = true, spoilers:[Spoiler] = [], onSpoilerReveal: @escaping()->Void = {}) {
        self.spoilers = spoilers
        self.truncationType = truncationType
        self.maximumNumberOfLines = maximumNumberOfLines
        self.cutout = cutout
        self.disableTooltips = disableTooltips
        self.attributedString = attributedString
        self.constrainedWidth = constrainedWidth
        self.selectText = selectText
        self.alwaysStaticItems = alwaysStaticItems
        self.selectedRange = TextSelectedRange(color: selectText)
        self.strokeLinks = strokeLinks
        self.mayItems = mayItems
        self.onSpoilerReveal = onSpoilerReveal
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
    
    func revealSpoiler() -> Void {
        for spoiler in spoilers {
            spoiler.isRevealed = true
        }
        onSpoilerReveal()
    }
    
    public func dropLayoutSize() {
        self.layoutSize = .zero
    }
    
    func calculateLayout(isBigEmoji: Bool = false) -> Void {
        self.isBigEmoji = isBigEmoji
        isPerfectSized = true
        
        self.insets = .zero
        
        let font: CTFont
        if attributedString.length != 0 {
            if let stringFont = attributedString.attribute(NSAttributedString.Key(kCTFontAttributeName as String), at: 0, effectiveRange: nil) {
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
       
        let fontLineHeight = floor(fontAscent + (isBigEmoji ? fontDescent / 2 : fontDescent)) + (lineSpacing ?? 0)
        
        var monospacedRects:[NSRect] = []
        
        var fontLineSpacing:CGFloat = floor(fontLineHeight * 0.12)

        
        
        var maybeTypesetter: CTTypesetter?
        
        let copy = attributedString.mutableCopy() as! NSMutableAttributedString
        copy.removeAttribute(.strikethroughStyle, range: copy.range)
        maybeTypesetter = CTTypesetterCreateWithAttributedString(copy as CFAttributedString)
        
        let typesetter = maybeTypesetter!
        
        var lastLineCharacterIndex: CFIndex = 0
        var layoutSize = NSSize()
        
        var cutoutEnabled = false
        var cutoutMinY: CGFloat = 0.0
        var cutoutMaxY: CGFloat = 0.0
        var cutoutWidth: CGFloat = 0.0
        var cutoutOffset: CGFloat = 0.0
        
        
        var bottomCutoutEnabled = false
        var bottomCutoutSize = CGSize()
        

        
        
        if let topLeft = cutout?.topLeft {
            cutoutMinY = -fontLineSpacing
            cutoutMaxY = topLeft.height + fontLineSpacing
            cutoutWidth = topLeft.width
            cutoutOffset = cutoutWidth
            cutoutEnabled = true
        } else if let topRight = cutout?.topRight {
            cutoutMinY = -fontLineSpacing
            cutoutMaxY = topRight.height + fontLineSpacing
            cutoutWidth = topRight.width
            cutoutEnabled = true
        }
        if let bottomRight = cutout?.bottomRight {
            bottomCutoutSize = bottomRight
            bottomCutoutEnabled = true
        }

        
        var first = true
        var breakInset: CGFloat = 0
        var isWasPreformatted: Bool = false
        while true {
            var strikethroughs: [TextViewStrikethrough] = []
            var embeddedItems: [TextViewEmbeddedItem] = []

            
            
            func addEmbeddedItem(item: AnyHashable, line: CTLine, ascent: CGFloat, descent: CGFloat, startIndex: Int, endIndex: Int, rightInset: CGFloat = 0.0) {
                var secondaryLeftOffset: CGFloat = 0.0
                let rawLeftOffset = CTLineGetOffsetForStringIndex(line, startIndex, &secondaryLeftOffset)
                var leftOffset = floor(rawLeftOffset)
                if !rawLeftOffset.isEqual(to: secondaryLeftOffset) {
                    leftOffset = floor(secondaryLeftOffset)
                }
                
                var secondaryRightOffset: CGFloat = 0.0
                let rawRightOffset = CTLineGetOffsetForStringIndex(line, endIndex, &secondaryRightOffset)
                var rightOffset = ceil(rawRightOffset)
                if !rawRightOffset.isEqual(to: secondaryRightOffset) {
                    rightOffset = ceil(secondaryRightOffset)
                }
                                        
                if rightOffset > leftOffset, abs(rightOffset - leftOffset) < 150 {
                    embeddedItems.append(TextViewEmbeddedItem(range: NSMakeRange(startIndex, endIndex - startIndex), frame: CGRect(x: floor(min(leftOffset, rightOffset)), y: floor(descent - (ascent + descent)), width: floor(abs(rightOffset - leftOffset) + rightInset), height: floor(ascent + descent)), item: item))
                }
            }
            



            var lineConstrainedWidth = constrainedWidth
            var lineOriginY: CGFloat = 0
            
            var lineCutoutOffset: CGFloat = 0.0
            var lineAdditionalWidth: CGFloat = 0.0

            var isPreformattedLine: CGFloat? = nil
            
            fontLineSpacing = isBigEmoji ? 0 : floor(fontLineHeight * 0.12)
            
            if isBigEmoji {
                lineOriginY += 2
            }
            
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
            var lineRange = CFRange(location: lastLineCharacterIndex, length: lineCharacterCount)

            
            var lineHeight = fontLineHeight
            
            let lineString = attributedString.attributedSubstring(from: NSMakeRange(lastLineCharacterIndex, lineCharacterCount))
            
            if lineString.string.containsEmoji, !isBigEmoji {
                if first {
                    lineHeight += floor(fontDescent)
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
                    var truncationTokenAttributes: [NSAttributedString.Key : Any] = [:]
                    truncationTokenAttributes[NSAttributedString.Key(kCTFontAttributeName as String)] = font
                    truncationTokenAttributes[NSAttributedString.Key(kCTForegroundColorAttributeName as String)] = attributedString.attribute(.foregroundColor, at: min(lastLineCharacterIndex, attributedString.length - 1), effectiveRange: nil) as? NSColor ?? NSColor.black
                    let tokenString = "\u{2026}"
                    let truncatedTokenString = NSAttributedString(string: tokenString, attributes: truncationTokenAttributes)
                    let truncationToken = CTLineCreateWithAttributedString(truncatedTokenString)
                    
                    
                    var lineConstrainedWidth = constrainedWidth
                    if bottomCutoutEnabled {
                        lineConstrainedWidth -= bottomCutoutSize.width
                    }

                    
                    coreTextLine = CTLineCreateTruncatedLine(originalLine, Double(lineConstrainedWidth), truncationType, truncationToken) ?? truncationToken
                    isPerfectSized = false
                }
                lineRange = CTLineGetStringRange(coreTextLine)
                
                let lineWidth = ceil(CGFloat(CTLineGetTypographicBounds(coreTextLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(coreTextLine)))
                let lineFrame = CGRect(x: lineCutoutOffset, y: lineOriginY, width: lineWidth, height: lineHeight)
                layoutSize.height += lineHeight + fontLineSpacing
                layoutSize.width = max(layoutSize.width, lineWidth + lineAdditionalWidth)
                
                
                attributedString.enumerateAttributes(in: NSMakeRange(lineRange.location, lineRange.length), options: []) { attributes, range, _ in
                    if let _ = attributes[.strikethroughStyle] {
                        let color = attributes[.foregroundColor] as? NSColor ?? presentation.colors.text
                        let lowerX = floor(CTLineGetOffsetForStringIndex(coreTextLine, range.location, nil))
                        let upperX = ceil(CTLineGetOffsetForStringIndex(coreTextLine, range.location + range.length, nil))
                        let x = lowerX < upperX ? lowerX : upperX
                        strikethroughs.append(TextViewStrikethrough(color: color, frame: CGRect(x: x, y: 0.0, width: abs(upperX - lowerX), height: fontLineHeight)))
                    } else if let embeddedItem = attributes[NSAttributedString.Key(rawValue: "Attribute__EmbeddedItem")] as? AnyHashable {
                        var ascent: CGFloat = 0.0
                        var descent: CGFloat = 0.0
                        CTLineGetTypographicBounds(coreTextLine, &ascent, &descent, nil)
                        
                        addEmbeddedItem(item: embeddedItem, line: coreTextLine, ascent: ascent, descent: descent, startIndex: range.location, endIndex: range.location + range.length)
                    }

                }

                var isRTL = false
                let glyphRuns = CTLineGetGlyphRuns(coreTextLine) as NSArray
                if glyphRuns.count != 0 {
                    let run = glyphRuns[0] as! CTRun
                    if CTRunGetStatus(run).contains(CTRunStatus.rightToLeft) {
                        isRTL = true
                    }
                }
                lines.append(TextViewLine(line: coreTextLine, frame: lineFrame, range: NSMakeRange(lineRange.location, lineRange.length), penFlush: self.penFlush, isBlocked: isWasPreformatted, isRTL: isRTL, strikethrough: strikethroughs, embeddedItems: embeddedItems))
                
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
                    let lineFrame = CGRect(x: lineCutoutOffset, y: lineOriginY - (isBigEmoji ? fontDescent / 3 : 0), width: lineWidth, height: lineHeight)
                    layoutSize.height += lineHeight
                    layoutSize.width = max(layoutSize.width, lineWidth + lineAdditionalWidth)
                    
                    if let space = lineString.attribute(.preformattedPre, at: 0, effectiveRange: nil) as? NSNumber, mayBlocked {
                        
                        layoutSize.width = self.constrainedWidth
                        let preformattedSpace = CGFloat(space.floatValue) * 2
                        
                        monospacedRects.append(NSMakeRect(0, lineFrame.minY - lineFrame.height, layoutSize.width, lineFrame.height + preformattedSpace))
                    }

                    attributedString.enumerateAttributes(in: NSMakeRange(lineRange.location, lineRange.length), options: []) { attributes, range, _ in
                        if let _ = attributes[.strikethroughStyle] {
                            let color = attributes[.foregroundColor] as? NSColor ?? presentation.colors.text
                            let lowerX = floor(CTLineGetOffsetForStringIndex(coreTextLine, range.location, nil))
                            let upperX = ceil(CTLineGetOffsetForStringIndex(coreTextLine, range.location + range.length, nil))
                            let x = lowerX < upperX ? lowerX : upperX
                            strikethroughs.append(TextViewStrikethrough(color: color, frame: CGRect(x: x, y: 0.0, width: abs(upperX - lowerX), height: fontLineHeight)))
                        } else if let embeddedItem = attributes[NSAttributedString.Key(rawValue: "Attribute__EmbeddedItem")] as? AnyHashable {
                            var ascent: CGFloat = 0.0
                            var descent: CGFloat = 0.0
                            CTLineGetTypographicBounds(coreTextLine, &ascent, &descent, nil)
                                                        
                            addEmbeddedItem(item: embeddedItem, line: coreTextLine, ascent: ascent, descent: descent, startIndex: range.location, endIndex: range.location + range.length)
                        }

                    }
                    
                    var isRTL = false
                    let glyphRuns = CTLineGetGlyphRuns(coreTextLine) as NSArray
                    if glyphRuns.count != 0 {
                        let run = glyphRuns[0] as! CTRun
                        if CTRunGetStatus(run).contains(CTRunStatus.rightToLeft) {
                            isRTL = true
                        }
                    }

                    lines.append(TextViewLine(line: coreTextLine, frame: lineFrame, range: NSMakeRange(lineRange.location, lineRange.length), penFlush: self.penFlush, isBlocked: isWasPreformatted, isRTL: isRTL, strikethrough: strikethroughs, embeddedItems: embeddedItems))
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
        
        var embeddedItems: [EmbeddedItem] = []
        for line in lines {
            for embeddedItem in line.embeddedItems {
                let penOffset = floor(CGFloat(CTLineGetPenOffsetForFlush(line.line, line.penFlush, Double(layoutSize.width))))
                embeddedItems.append(EmbeddedItem(range: embeddedItem.range, rect: embeddedItem.frame.offsetBy(dx: line.frame.minX, dy: line.frame.minY).offsetBy(dx: penOffset, dy: 0), value: embeddedItem.item))
            }
        }
        if lines.count == 1 {
            let line = lines[0]
            if !line.embeddedItems.isEmpty {
                layoutSize.height += isBigEmoji ? 8 : 2
            }
//            if isBigEmoji {
//                layoutSize.width += 5
//            }
        } else {
            if isBigEmoji, let line = lines.last {
                if !line.embeddedItems.isEmpty {
                    layoutSize.height += 4
                }
            } else if let line = lines.last, !line.embeddedItems.isEmpty {
                layoutSize.height += 1
            }
        }
        


        self.embeddedItems = embeddedItems
        
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
                let height = rects[i].size.height + 7
                rects[i] = rects[i].insetBy(dx: 0, dy: floor((rects[i].height - height) / 2.0))
                rects[i].size.height = height
                
                rects[i].origin.x = floor((layoutSize.width - rects[i].width) / 2.0)
                rects[i].size.width += 20
            }
            
            self.blockImage = generateRectsImage(color: backgroundColor, rects: rects, inset: 0, outerRadius: rects[0].height / 2, innerRadius: .cornerRadius)
            self.blockImage.0 = NSMakePoint(0, 0)
            
            layoutSize.width += 20
            lines[0] = TextViewLine(line: lines[0].line, frame: lines[0].frame.offsetBy(dx: 0, dy: 2), range: lines[0].range, penFlush: self.penFlush, strikethrough: lines[0].strikethrough, embeddedItems: lines[0].embeddedItems)
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
    
    public func measure(width: CGFloat = 0, isBigEmoji: Bool = false) -> Void {
        
        if width != 0 {
            constrainedWidth = width
        }
        
        toolTipRects.removeAll()
        
        calculateLayout(isBigEmoji: isBigEmoji)

        strokeRects.removeAll()
        
        attributedString.enumerateAttribute(NSAttributedString.Key.link, in: attributedString.range, options: NSAttributedString.EnumerationOptions(rawValue: 0), using: { value, range, stop in
            if let value = value {
                if interactions.isDomainLink(value, attributedString.attributedSubstring(from: range).string) && strokeLinks {
                    for line in lines {
                        let lineRange = NSIntersectionRange(range, line.range)
                        if lineRange.length != 0 {
                            var leftOffset: CGFloat = 0.0
                            if lineRange.location != line.range.location {
                                leftOffset = floor(CTLineGetOffsetForStringIndex(line.line, lineRange.location, nil))
                            }
                            let rightOffset: CGFloat = ceil(CTLineGetOffsetForStringIndex(line.line, lineRange.location + lineRange.length, nil))
                            
                            let color: NSColor = attributedString.attribute(NSAttributedString.Key.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor ?? presentation.colors.link
                            let rect = NSMakeRect(line.frame.minX + leftOffset, line.frame.minY + 1, rightOffset - leftOffset, 1.0)
                            strokeRects.append((rect, color))
                            if !disableTooltips, interactions.resolveLink(value) != attributedString.string.nsstring.substring(with: range) {
                                var leftOffset: CGFloat = 0.0
                                if lineRange.location != line.range.location {
                                    leftOffset = floor(CTLineGetOffsetForStringIndex(line.line, lineRange.location, nil))
                                }
                                let rightOffset: CGFloat = ceil(CTLineGetOffsetForStringIndex(line.line, lineRange.location + lineRange.length, nil))
                                
                                toolTipRects.append(NSMakeRect(line.frame.minX + leftOffset, line.frame.minY - line.frame.height, rightOffset - leftOffset, line.frame.height))
                            }
                        }
                    }
                }
                if !disableTooltips, interactions.resolveLink(value) != attributedString.string.nsstring.substring(with: range) {
                    for line in lines {
                        let lineRange = NSIntersectionRange(range, line.range)
                        if lineRange.length != 0 {
                            var leftOffset: CGFloat = 0.0
                            if lineRange.location != line.range.location {
                                leftOffset = floor(CTLineGetOffsetForStringIndex(line.line, lineRange.location, nil))
                            }
                            let rightOffset: CGFloat = ceil(CTLineGetOffsetForStringIndex(line.line, lineRange.location + lineRange.length, nil))
                            
                            toolTipRects.append(NSMakeRect(line.frame.minX + leftOffset, line.frame.minY - line.frame.height, rightOffset - leftOffset, line.frame.height))
                        }
                    }
                }
            }
            
        })
        hexColorsRect.removeAll()
        attributedString.enumerateAttribute(NSAttributedString.Key.hexColorMark, in: attributedString.range, options: NSAttributedString.EnumerationOptions(rawValue: 0), using: { value, range, stop in
            if let color = value as? NSColor, let size = attributedString.attribute(.hexColorMarkDimensions, at: range.location, effectiveRange: nil) as? NSSize {
                for line in lines {
                    let lineRange = NSIntersectionRange(range, line.range)
                    if lineRange.length != 0 {
                        var leftOffset: CGFloat = 0
                        if lineRange.location != line.range.location {
                            leftOffset += floor(CTLineGetOffsetForStringIndex(line.line, lineRange.location, nil))
                        }
                        let rect = NSMakeRect(line.frame.minX + leftOffset + 10, line.frame.minY - (size.height - 7) + 2, size.width - 8, size.height - 8)
                        hexColorsRect.append((rect, color, attributedString.attributedSubstring(from: range).string))
                    }
                }
            }
            
        })
        
        attributedString.enumerateAttribute(NSAttributedString.Key.underlineStyle, in: attributedString.range, options: NSAttributedString.EnumerationOptions(rawValue: 0), using: { value, range, stop in
            if let _ = value {
                for line in lines {
                    let lineRange = NSIntersectionRange(range, line.range)
                    if lineRange.length != 0 {
                        var leftOffset: CGFloat = 0.0
                        if lineRange.location != line.range.location {
                            leftOffset = floor(CTLineGetOffsetForStringIndex(line.line, lineRange.location, nil))
                        }
                        let rightOffset: CGFloat = ceil(CTLineGetOffsetForStringIndex(line.line, lineRange.location + lineRange.length, nil))
                        
                        
                        let color: NSColor = attributedString.attribute(NSAttributedString.Key.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor ?? presentation.colors.text
                        let rect = NSMakeRect(line.frame.minX + leftOffset, line.frame.minY + 1, rightOffset - leftOffset, 1.0)
                        strokeRects.append((rect, color))
                    }
                }
            }
            
        })
    }
    
    public func clearSelect() {
        self.selectedRange.range = NSMakeRange(NSNotFound, 0)
    }
    
    public func selectedRange(startPoint:NSPoint, currentPoint:NSPoint) -> NSRange {
        
        var selectedRange:NSRange = NSMakeRange(NSNotFound, 0)
        
        if (currentPoint.x != -1 && currentPoint.y != -1 && !lines.isEmpty && startPoint.x != -1 && startPoint.y != -1) {
            
            
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
        //var previous:NSRect = lines[0].frame
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
        
        if line.isBlocked {
            rect.size.height += 2
        }
        
        return (pos.y > rect.minY) && pos.y < rect.maxY
        
    }
    
    fileprivate func color(at point: NSPoint) -> (NSColor, String)? {
        
        for value in self.hexColorsRect {
            if NSPointInRect(point, value.0) {
                return (value.1, value.2)
            }
        }
        return nil
    }
    
    func spoiler(at point: NSPoint) -> Spoiler? {
        let index = self.findCharacterIndex(at: point)
        for spoiler in spoilers {
            if spoiler.range.contains(index) {
                if !spoiler.isRevealed {
                    return spoiler
                }
            }
        }
        return nil
    }
    
    func spoilerRects(_ checkRevealed: Bool = true) -> [CGRect] {
        var rects:[CGRect] = []
        for i in 0 ..< lines.count {
            let line = lines[i]
            for spoiler in spoilers.filter({ !$0.isRevealed || !checkRevealed }) {
                if let spoilerRange = spoiler.range.intersection(line.range) {
                    let range = spoilerRange.intersection(selectedRange.range)
                    
                    var ranges:[(NSRange, NSColor)] = []
                    if let range = range {
                        ranges.append((NSMakeRange(spoiler.range.lowerBound, range.lowerBound - spoiler.range.lowerBound), spoiler.color))
                        ranges.append((NSMakeRange(spoiler.range.upperBound, range.upperBound - spoiler.range.upperBound), spoiler.color))
                    } else {
                        ranges.append((spoilerRange, spoiler.color))
                    }
                    for range in ranges {
                        let startOffset = CTLineGetOffsetForStringIndex(line.line, range.0.lowerBound, nil);
                        let endOffset = CTLineGetOffsetForStringIndex(line.line, range.0.upperBound, nil);

                        var ascent:CGFloat = 0
                        var descent:CGFloat = 0
                        var leading:CGFloat = 0
                        
                        _ = CGFloat(CTLineGetTypographicBounds(line.line, &ascent, &descent, &leading));
                        
                        var rect:NSRect = line.frame
                        
                        rect.size.width = abs(endOffset - startOffset)
                        rect.origin.x = min(startOffset, endOffset)
                        rect.origin.y = rect.minY - rect.height + 2
                        rect.size.height += ceil(descent - leading)
                        
                        rects.append(rect)
      
                    }
                }
            }
        }
        return rects
    }

    public func link(at point:NSPoint) -> (Any, LinkType, NSRange, NSRect)? {
        
        let index = findIndex(location: point)
        
        guard index != -1, !lines.isEmpty else {
            return nil
        }
        
        let line = lines[index]
        var ascent:CGFloat = 0
        var descent:CGFloat = 0
        var leading:CGFloat = 0
        
        let width:CGFloat = CGFloat(CTLineGetTypographicBounds(line.line, &ascent, &descent, &leading));
        
        var point = point
        
         //point.x -= floorToScreenPixels(System.backingScale, (frame.width - line.frame.width) / 2)
        
        
//        var penOffset = CGFloat( CTLineGetPenOffsetForFlush(line.line, line.penFlush, Double(frame.width))) + line.frame.minX
//        if layout.penFlush == 0.5, line.penFlush != 0.5 {
//            penOffset = startPosition.x
//        } else if layout.penFlush == 0.0 {
//            penOffset = startPosition.x
//        }
        
        point.x -= ((layoutSize.width - line.frame.width) * line.penFlush)

        
        if  width > point.x, point.x >= 0 {
            var pos = CTLineGetStringIndexForPosition(line.line, point);
            pos = min(max(0,pos),attributedString.length - 1)
            var range:NSRange = NSMakeRange(NSNotFound, 0)
            let attrs = attributedString.attributes(at: pos, effectiveRange: &range)
            
            let link:Any? = attrs[NSAttributedString.Key.link]
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
    
    public func offset(for index: Int) -> CGFloat? {
        let line = self.lines.first(where: {
            $0.range.indexIn(index)
        })
        if let line = line {
            return CTLineGetOffsetForStringIndex(line.line, index, nil)
        }
        return nil
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
            var firstIndex: Int = startIndex
            var lastIndex: Int = startIndex
            
            var firstFound: Bool = false
            var lastFound: Bool = false
            
            while (firstIndex > 0 && !firstFound) || (lastIndex < self.attributedString.length - 1 && !lastFound) {
                
                let firstSymbol = self.attributedString.string.nsstring.substring(with: NSMakeRange(firstIndex, 1))
                let lastSymbol = self.attributedString.string.nsstring.substring(with: NSMakeRange(lastIndex, 1))
                
                firstFound = firstSymbol == "\n"
                lastFound = lastSymbol == "\n"
                                
                if firstIndex > 0, !firstFound {
                    firstIndex -= 1
                }
                if lastIndex < self.attributedString.length - 1, !lastFound {
                    lastIndex += 1
                }
            }
            if lastFound {
               lastIndex = max(lastIndex - 1, 0)
            }
            if firstFound {
               firstIndex = min(firstIndex + 1, self.attributedString.length - 1)
           }
            self.selectedRange = TextSelectedRange(range: NSMakeRange(firstIndex, (lastIndex + 1) - firstIndex), color: selectText, def: true)
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
        let check = attributedString.attribute(NSAttributedString.Key.link, at: range.location, effectiveRange: &effectiveRange)
        if check != nil && effectiveRange.location != NSNotFound {
            self.selectedRange = TextSelectedRange(range: effectiveRange, color: selectText, def: true)
            return
        }
        if char == "" {
            self.selectedRange = TextSelectedRange(color: selectText)
            return
        }
        let tidyChar = char.trimmingCharacters(in: NSCharacterSet.alphanumerics)
        let valid:Bool = tidyChar == "" || tidyChar == "_" || tidyChar == "\u{FFFD}"
        let string:NSString = attributedString.string.nsstring
        while valid {
            let prevChar = string.substring(with: NSMakeRange(prev, 1))
            let nextChar = string.substring(with: NSMakeRange(next, 1))
            let tidyPrev = prevChar.trimmingCharacters(in: NSCharacterSet.alphanumerics)
            let tidyNext = nextChar.trimmingCharacters(in: NSCharacterSet.alphanumerics)
            var prevValid:Bool = tidyPrev == "" || tidyPrev == "_" || tidyPrev == "\u{FFFD}"
            var nextValid:Bool = tidyNext == "" || tidyNext == "_" || tidyNext == "\u{FFFD}"
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
                let nextChar = string.substring(with: NSMakeRange(next, 1))
                let nextTidy = nextChar.trimmingCharacters(in: NSCharacterSet.alphanumerics)
                if nextTidy == "" || nextTidy == "_" || nextTidy == "\u{FFFD}" {
                    range.length += 1
                }
            }
            if !prevValid && !nextValid {
                break
            }
            if prev == 0 && !nextValid {
                break
            }
        }
        
        self.selectedRange = TextSelectedRange(range: NSMakeRange(max(range.location, 0), min(max(range.length, 0), string.length)), color: selectText, def: true)
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
    
    
    public var range:NSRange = NSMakeRange(NSNotFound, 0) {
        didSet {
            var bp:Int = 0
            bp += 1
        }
    }
    public var color:NSColor = presentation.colors.selectText
    public var def:Bool = true
    
    public init(range: NSRange = NSMakeRange(NSNotFound, 0), color: NSColor = presentation.colors.selectText, def: Bool = true, cursorAlignment: CursorSelectAlignment = .min(0)) {
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
    return lhs.def == rhs.def && lhs.range.location == rhs.range.location && lhs.range.length == rhs.range.length && lhs.color.hexString == rhs.color.hexString
}

//private extension TextView : NSMenuDelegate {
//    
//}

public class TextView: Control, NSViewToolTipOwner, ViewDisplayDelegate {
    
    
    public func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        
        guard let layout = self.textLayout else { return "" }
        
        if let link = layout.link(at: point), let resolved = layout.interactions.resolveLink(link.0)?.removingPercentEncoding {
            return resolved.prefixWithDots(70)
        }
        
        return ""

    }
    
    private class InkContainer : View {
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            isEventLess = true
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    private class EmbeddedContainer : View {
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            isEventLess = true
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private var inkViews: [InvisibleInkDustView] = []
    private let inkContainer = InkContainer(frame: .zero)
    private let embeddedContainer = InkContainer(frame: .zero)

    private var clearExceptRevealed: Bool = false
    private var inAnimation: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    private var visualEffect: VisualEffect? = nil
    private var textView: View? = nil
    private var blockMask: CALayer?
    public var blurBackground: NSColor? = nil {
        didSet {
            updateBackgroundBlur()
            if blurBackground != nil {
                self.backgroundColor = .clear
            }
        }
    }
    
    
    private let menuDisposable = MetaDisposable()
    
    private(set) public var textLayout:TextViewLayout?
    
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
        
        initialize()
//        wantsLayer = false
//        self.layer?.delegate = nil
    }

    public override var isFlipped: Bool {
        return true
    }
    
    private func initialize() {
        layer?.disableActions()
        self.style = ControlStyle(backgroundColor: .clear)
        addSubview(embeddedContainer)
        addSubview(inkContainer)
    }

    public required init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        initialize()
    }
    private var _disableBackgroundDrawing: Bool = false
    public var disableBackgroundDrawing: Bool {
        set {
            _disableBackgroundDrawing = newValue
        }
        get {
            return _disableBackgroundDrawing || blurBackground != nil
        }
    }

    public override func draw(_ layer: CALayer, in ctx: CGContext) {
        //backgroundColor = .random
        super.draw(layer, in: ctx)

        if blurBackground != nil, layer != textView?.layer {
            return
        }
        
        if let layout = textLayout {
            
            
            ctx.setAllowsFontSubpixelPositioning(true)
            ctx.setShouldSubpixelPositionFonts(true)
            
            if clearExceptRevealed {
                let path = CGMutablePath()
                
                for spoiler in layout.spoilerRects(false) {
                    path.addRect(spoiler)
                }
                ctx.addPath(path)
                ctx.clip()
            }
            
            if !System.supportsTransparentFontDrawing {
                ctx.setAllowsAntialiasing(true)
                
                ctx.setAllowsFontSmoothing(backingScaleFactor == 1.0)
                ctx.setShouldSmoothFonts(backingScaleFactor == 1.0)
                
                if backingScaleFactor == 1.0 && !disableBackgroundDrawing {
                    ctx.setFillColor(backgroundColor.cgColor)
                    for line in layout.lines {
                        ctx.fill(NSMakeRect(0, line.frame.minY - line.frame.height - 2, line.frame.width, line.frame.height + 6))
                    }
                }
            } else {
                
                ctx.setAllowsAntialiasing(true)
                ctx.setShouldAntialias(true)
                
                ctx.setAllowsFontSmoothing(backingScaleFactor == 1.0)
                ctx.setShouldSmoothFonts(backingScaleFactor == 1.0)
            }
           
            
            
            if let image = layout.blockImage.1, blurBackground == nil {
                ctx.draw(image, in: NSMakeRect(layout.blockImage.0.x, layout.blockImage.0.y, image.backingSize.width, image.backingSize.height))
            }
            
            
            var ranges:[(TextSelectedRange, Bool)] = [(layout.selectedRange, true)]
            ranges += layout.additionalSelections.map { ($0, false) }
            
            for range in ranges {
                if range.0.range.location != NSNotFound && (range.1 && isSelectable || !range.1) {
                    
                    var lessRange = range.0.range
                    
                    let lines:[TextViewLine] = layout.lines
                    
                    let beginIndex:Int = 0
                    let endIndex:Int = layout.lines.count - 1
                    
                    
                    let isReversed = endIndex < beginIndex
                    
                    var i:Int = beginIndex
                    
                    while isReversed ? i >= endIndex : i <= endIndex {
                        
                        
                        let line = lines[i].line
                        var rect:NSRect = lines[i].frame
                        let lineRange = lines[i].range
                        
                        var beginLineIndex:CFIndex = 0
                        var endLineIndex:CFIndex = 0
                        
                        if (lineRange.location + lineRange.length >= lessRange.location) && lessRange.length > 0 {
                            beginLineIndex = lessRange.location
                            let max = lineRange.length + lineRange.location
                            let maxSelect = max - beginLineIndex
                            
                            let selectLength = min(maxSelect,lessRange.length)
                            
                            lessRange.length-=selectLength
                            lessRange.location+=selectLength
                            
                            endLineIndex = min(beginLineIndex + selectLength, lineRange.max)
                            
                            var ascent:CGFloat = 0
                            var descent:CGFloat = 0
                            var leading:CGFloat = 0
                            
                            var width:CGFloat = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading));
                            
                            let startOffset = CTLineGetOffsetForStringIndex(line, beginLineIndex, nil);
                            var endOffset = CTLineGetOffsetForStringIndex(line, endLineIndex, nil);
                            
                            if beginLineIndex < endLineIndex {
                                var index = endLineIndex - 1
                                while endOffset == 0 && index > 0 {
                                    endOffset = CTLineGetOffsetForStringIndex(line, index, nil);
                                    index -= 1
                                }
                            }
                            
                            width = endOffset - startOffset;
                            
                            
                            if beginLineIndex == -1 {
                                beginLineIndex = 0
                            } else if beginLineIndex >= layout.attributedString.length {
                                beginLineIndex = layout.attributedString.length - 1
                            }
                            
                            let blockValue:CGFloat = layout.mayBlocked ? CGFloat((layout.attributedString.attribute(.preformattedPre, at: beginLineIndex, effectiveRange: nil) as? NSNumber)?.floatValue ?? 0) : 0
                            
                            
                            
                            rect.size.width = width - blockValue / 2
                            
                            rect.origin.x = startOffset + blockValue
                            rect.origin.y = rect.minY - rect.height + blockValue / 2
                            rect.size.height += ceil(descent - leading)
                            let color:NSColor = window?.isKeyWindow == true || !range.1 ? range.0.color : NSColor.lightGray
                            
                            ctx.setFillColor(color.cgColor)
                            ctx.fill(rect)
                        }
                        
                        i += isReversed ? -1 : 1
                        
                    }
                    
                }
            }
            
            
            
            let startPosition = focus(layout.layoutSize).origin
            
            
            ctx.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
            
            
//            ctx.textMatrix = textMatrix
//            ctx.textPosition = CGPoint(x: textPosition.x, y: textPosition.y)
//            
            for stroke in layout.strokeRects {
                ctx.setFillColor(stroke.1.cgColor)
                ctx.fill(stroke.0)
            }
            
            for hexColor in layout.hexColorsRect {
                ctx.setFillColor(hexColor.1.cgColor)
                ctx.fill(hexColor.0)
            }
            
            for i in 0 ..< layout.lines.count {
                let line = layout.lines[i]
                
                var penOffset = CGFloat( CTLineGetPenOffsetForFlush(line.line, line.penFlush, Double(frame.width))) + line.frame.minX
                if layout.penFlush == 0.5, line.penFlush != 0.5 {
                    penOffset = startPosition.x
                } else if layout.penFlush == 0.0 {
                    penOffset = startPosition.x
                }
                var additionY: CGFloat = 0
                if layout.isBigEmoji {
                    additionY -= 4
                }
                                
                ctx.textPosition = CGPoint(x: penOffset + line.frame.minX, y: startPosition.y + line.frame.minY + additionY)
                
                
                let glyphRuns = CTLineGetGlyphRuns(line.line) as NSArray
                if glyphRuns.count != 0 {
                    for run in glyphRuns {
                        let run = run as! CTRun
                        let glyphCount = CTRunGetGlyphCount(run)
                        let range = CTRunGetStringRange(run)
                                                
                        let under = line.embeddedItems.contains(where: { value in
                            return value.range == NSMakeRange(range.location, range.length)
                        })
                        
                        if !under {
                            CTRunDraw(run, ctx, CFRangeMake(0, glyphCount))
                        }
                    }
                }
                for strikethrough in line.strikethrough {
                    ctx.setFillColor(strikethrough.color.cgColor)
                    ctx.fill(NSMakeRect(strikethrough.frame.minX, line.frame.minY - line.frame.height / 2 + 2, strikethrough.frame.width, .borderSize))
                }
                
//                for embeddedItem in line.embeddedItems {
//                    ctx.clear(embeddedItem.frame.offsetBy(dx: ctx.textPosition.x, dy: ctx.textPosition.y).insetBy(dx: -1.5, dy: -1.5))
//                }

                // spoiler was here
            }
            for spoiler in layout.spoilerRects(!inAnimation) {
                ctx.clear(spoiler)
            }
            
        }
    }
    
    
    public override func rightMouseDown(with event: NSEvent) {
        if let layout = textLayout, userInteractionEnabled, layout.mayItems, mouseInside() {
            let location = convert(event.locationInWindow, from: nil)
            if (!layout.selectedRange.hasSelectText || !layout.inSelectedRange(location)) && (!layout.alwaysStaticItems || layout.link(at: location) != nil) {
                layout.selectWord(at : location)
            }
            self.setNeedsDisplayLayer()
            if (layout.selectedRange.hasSelectText && isSelectable) || !layout.alwaysStaticItems {
                let link = layout.link(at: convert(event.locationInWindow, from: nil))
                
                if let menuItems = layout.interactions.menuItems?(link?.1) {
                    let window = layout.interactions.topWindow?() ?? .single(nil)
                    menuDisposable.set(combineLatest(queue: .mainQueue(), menuItems, window).start(next:{ [weak self] items, topWindow in
                        if let strongSelf = self {
                            let menu = ContextMenu()
                            for item in items {
                                menu.addItem(item)
                            }
                            menu.topWindow = topWindow
                            AppMenu.show(menu: menu, event: event, for: strongSelf)
                        }
                    }))
                } else {
                    let window = (layout.interactions.topWindow?() ?? .single(nil)) |> deliverOnMainQueue
                    menuDisposable.set(window.start(next: { [weak self] topWindow in
                        let link = layout.link(at: location)
                        let resolved: String? = link != nil ? layout.interactions.resolveLink(link!.0) : nil
                        let menu = ContextMenu()
                        let copy = ContextMenuItem(link?.1 != nil ? layout.interactions.localizeLinkCopy(link!.1) : localizedString("Text.Copy"), handler: { [weak self] in
                            guard let `self` = self else {return}
                            if let resolved = resolved {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.declareTypes([.string], owner: self)
                                pb.setString(resolved, forType: .string)
                            } else {
                                self.copy(self)
                            }
                        }, itemImage: TextView.context_copy_animation)
                        
                        menu.addItem(copy)
                        
                        if resolved == nil, let window = self?.kitWindow {
                            if let text = self?.effectiveText, let translate = layout.interactions.translate?(text, window) {
                                menu.addItem(translate)
                            }
                        }
                        menu.topWindow = topWindow
                        if let strongSelf = self {
                            AppMenu.show(menu: menu, event: event, for: strongSelf)
                        }
                    }))
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
    
    public static var context_copy_animation: ((NSColor, ContextMenuItem)->AppMenuItemImageDrawable)?
    
    
    public func menuDidClose(_ menu: NSMenu) {
        
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
        NotificationCenter.default.removeObserver(self)
    }
    
    public func isEqual(to layout:TextViewLayout) -> Bool {
        return self.textLayout == layout
    }

    //
    
    private func updateInks(_ layout: TextViewLayout?, animated: Bool = false) {
        if let layout = layout {
            let spoilers = layout.spoilers
            let rects = layout.spoilerRects()
            while rects.count > self.inkViews.count {
                let inkView = InvisibleInkDustView(textView: nil)
                self.inkViews.append(inkView)
                self.addSubview(inkView)
            }
            
            if rects.count < self.inkViews.count, animated {
                let fake = TextView(frame: self.bounds)
                
                fake.update(layout)
                fake.userInteractionEnabled = false
                fake.isSelectable = false
                addSubview(fake, positioned: .below, relativeTo: self.subviews.first)
                fake.layer?.animateAlpha(from: 0, to: 1, duration: 0.2, timingFunction: .easeInEaseOut, removeOnCompletion: false, completion: { [weak fake, weak self] _ in
                    fake?.removeFromSuperview()
                    self?.inAnimation = false
                })
                self.inAnimation = true
                fake.clearExceptRevealed = true
            }
            while rects.count < self.inkViews.count {
                performSubviewRemoval(self.inkViews.removeLast(), animated: animated)
            }
            
            for (i, inkView) in inkViews.enumerated() {
                let rect = rects[i]
                let color = spoilers[0].color
                inkView.update(size: rect.size, color: color, textColor: color, rects: [rect.size.bounds], wordRects: [rect.size.bounds.insetBy(dx: 2, dy: 2)])
                inkView.frame = rect
            }
        } else {
            while !inkViews.isEmpty {
                performSubviewRemoval(inkViews.removeLast(), animated: animated)
            }
        }
        self.checkEmbeddedUnderSpoiler()
    }
    
    public func update(_ layout:TextViewLayout?, origin:NSPoint? = nil) -> Void {
        self.textLayout = layout
        
        
        self.updateInks(layout)
        
        
        if let layout = layout {
            self.set(selectedRange: layout.selectedRange.range, display: false)
            let point:NSPoint
            if let origin = origin {
                point = origin
            } else {
                point = frame.origin
            }
            self.frame = NSMakeRect(point.x, point.y, layout.layoutSize.width + layout.insets.width, layout.layoutSize.height + layout.insets.height)
            
            removeAllToolTips()
            for rect in layout.toolTipRects {
                addToolTip(rect, owner: self, userData: nil)
            }
            
        } else {
            self.set(selectedRange: NSMakeRange(NSNotFound, 0), display: false)
            self.frame = NSZeroRect
        }
        
       

        updateBackgroundBlur()

        self.setNeedsDisplayLayer()
    }
    
    public func set(layout:TextViewLayout?) {
        self.textLayout = layout
        self.setNeedsDisplayLayer()
    }
    
    public override func setNeedsDisplayLayer() {
        super.setNeedsDisplayLayer()
        self.textView?.layer?.setNeedsDisplay()
    }
    
    func set(selectedRange range:NSRange, display:Bool = true) -> Void {
        
        if let layout = textLayout {
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
        } else if let layout = textLayout {
            let point = self.convert(event.locationInWindow, from: nil)
            
            
            let index = layout.findIndex(location: point)
            if point.x > layout.lines[index].frame.maxX {
                superview?.mouseDown(with: event)
            }
        }
        
        _mouseDown(with: event)
        
    }
    
    
    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let newWindow = newWindow {
            NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: newWindow)
            NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey), name: NSWindow.didResignKeyNotification, object: newWindow)
        } else {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: window)
        }
    }
    
    
    @objc open func windowDidBecomeKey() {
        needsDisplay = true
    }
    
    @objc open func windowDidResignKey() {
        needsDisplay = true
    }
    
    private var locationInWindow:NSPoint? = nil
    
    func _mouseDown(with event: NSEvent) -> Void {
        
        self.locationInWindow = event.locationInWindow
        
        if !isSelectable || !userInteractionEnabled || event.modifierFlags.contains(.shift) {
            super.mouseDown(with: event)
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
        if let locationInWindow = self.locationInWindow {
            let old = (ceil(locationInWindow.x), ceil(locationInWindow.y))
            let new = (ceil(event.locationInWindow.x), round(event.locationInWindow.y))
            if abs(old.0 - new.0) <= 1 && abs(old.1 - new.1) <= 1 {
                return
            }
        }
        
        endSelect = self.convert(event.locationInWindow, from: nil)
        if let layout = textLayout {
            layout.selectedRange.range = layout.selectedRange(startPoint: beginSelect, currentPoint: endSelect)
            layout.selectedRange.cursorAlignment = beginSelect.x > endSelect.x ? .min(layout.selectedRange.range.max) : .max(layout.selectedRange.range.min)
        }
        self.setNeedsDisplayLayer()
    }
    
    
    public override func mouseEntered(with event: NSEvent) {
        if userInteractionEnabled {
            checkCursor(event)
        } else {
            super.mouseEntered(with: event)
        }
        
    }
    
    public override func mouseExited(with event: NSEvent) {
        if userInteractionEnabled {
            checkCursor(event)
        } else {
            super.mouseExited(with: event)
        }
    }
    
    public override func mouseMoved(with event: NSEvent) {
        if userInteractionEnabled {
            checkCursor(event)
        } else {
            super.mouseMoved(with: event)
        }
    }
    
    
    
    public override func mouseUp(with event: NSEvent) {
        
        self.locationInWindow = nil
        
        if let layout = textLayout, userInteractionEnabled {
            let point = self.convert(event.locationInWindow, from: nil)
            if let _ = layout.spoiler(at: point) {
                layout.revealSpoiler()
                needsDisplay = true
                self.updateInks(layout, animated: true)
                return
            }
            if event.clickCount == 3, isSelectable {
                layout.selectAll(at: point)
                layout.selectedRange.cursorAlignment = .max(layout.selectedRange.range.min)
            } else if isSelectable, event.clickCount == 2 || (event.type == .rightMouseUp && !layout.selectedRange.hasSelectText) {
                layout.selectWord(at : point)
                layout.selectedRange.cursorAlignment = .max(layout.selectedRange.range.min)
            } else if !layout.selectedRange.hasSelectText || !isSelectable && (event.clickCount == 1 || !isSelectable) {
                if let color = layout.color(at: point), let copyToClipboard = layout.interactions.copyToClipboard {
                    copyToClipboard(color.0.hexString.lowercased())
                } else if let (link, _, _, _) = layout.link(at: point) {
                    if event.clickCount == 1 {
                        layout.interactions.processURL(link)
                    }
                } else {
                    super.mouseUp(with: event)
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
            } else {
                super.mouseUp(with: event)
            }
            setNeedsDisplay()
        } else {
            super.mouseUp(with: event)
        }
        
        self.beginSelect = NSMakePoint(-1, -1)
    }
    public override func cursorUpdate(with event: NSEvent) {
        if userInteractionEnabled {
            checkCursor(event)
        } else {
            super.cursorUpdate(with: event)
        }
    }
    
    func checkCursor(_ event:NSEvent) -> Void {
        
        let location = self.convert(event.locationInWindow, from: nil)
        
        if self.isMousePoint(location , in: self.visibleRect) && mouseInside() && userInteractionEnabled {
            if textLayout?.spoiler(at: location) != nil {
                NSCursor.pointingHand.set()
            }  else if textLayout?.color(at: location) != nil {
                NSCursor.pointingHand.set()
                textLayout?.interactions.hoverOnLink(.exited)
            } else if let layout = textLayout, let (value, _, _, _) = layout.link(at: location) {
                NSCursor.pointingHand.set()
                layout.interactions.hoverOnLink(.entered(value))
            } else if isSelectable {
                NSCursor.iBeam.set()
                textLayout?.interactions.hoverOnLink(.exited)
            } else {
                NSCursor.arrow.set()
                textLayout?.interactions.hoverOnLink(.exited)
            }
        } else {
            NSCursor.arrow.set()
            textLayout?.interactions.hoverOnLink(.exited)
        }
    }
    
    
    private func updateBackgroundBlur() {
        if let blurBackground = blurBackground {
            if self.visualEffect == nil {
                self.visualEffect = VisualEffect(frame: self.bounds)
                addSubview(self.visualEffect!, positioned: .below, relativeTo: self.embeddedContainer)
                
                self.textView = View(frame: self.bounds)
                addSubview(self.textView!)
            }
            self.visualEffect?.bgColor = blurBackground
            self.textView?.displayDelegate = self
            
            
            if let textlayout = self.textLayout, let blockImage = textlayout.blockImage.1 {
                if blockMask == nil {
                    blockMask = CALayer()
                }
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                
                var fr = CATransform3DIdentity
                fr = CATransform3DTranslate(fr, blockImage.backingSize.width / 2, 0, 0)
                fr = CATransform3DScale(fr, 1, -1, 1)
                fr = CATransform3DTranslate(fr, -(blockImage.backingSize.width / 2), 0, 0)
                
                blockMask?.transform = fr
                blockMask?.contentsScale = 2.0
                blockMask?.contents = blockImage
                blockMask?.frame = CGRect(origin: .zero, size: blockImage.backingSize)
                self.layer?.mask = blockMask
                CATransaction.commit()
            } else {
                self.blockMask = nil
                self.layer?.mask = nil
            }
        } else {
            self.textView?.removeFromSuperview()
            self.textView = nil
            self.visualEffect?.removeFromSuperview()
            self.visualEffect = nil
            
            self.blockMask?.removeFromSuperlayer()
            self.blockMask = nil
            self.layer?.mask = nil
        }
        needsLayout = true
    }
    
    public override var needsDisplay: Bool {
        didSet {
            textView?.needsDisplay = needsDisplay
        }
    }
    
    public func addEmbeddedView(_ view: NSView) {
        embeddedContainer.addSubview(view)
    }
    
    public func addEmbeddedLayer(_ layer: CALayer) {
        embeddedContainer.layer?.addSublayer(layer)
    }
    
    public override func layout() {
        super.layout()
        self.visualEffect?.frame = bounds
        self.textView?.frame = bounds
        embeddedContainer.frame = bounds
        inkContainer.frame = bounds
        self.updateInks(self.textLayout)
    }
    
    public func resize(_ width: CGFloat, blockColor: NSColor? = nil) {
        self.textLayout?.measure(width: width)
        if let blockColor = blockColor {
            self.textLayout?.generateAutoBlock(backgroundColor: blockColor)
        }
        self.update(self.textLayout)
    }
    
    public override func becomeFirstResponder() -> Bool {
        if canBeResponder {
            if let window = self.window {
                return window.makeFirstResponder(self)
            }
        }
        
        
        return false        
    }
    
    public override func accessibilityLabel() -> String? {
        return self.textLayout?.attributedString.string
    }

//    public override var isOpaque: Bool {
//        return false
//    }
    
    public override func resignFirstResponder() -> Bool {
        _resignFirstResponder()
        return super.resignFirstResponder()
    }
    
    func _resignFirstResponder() -> Void {
        self.set(selectedRange: NSMakeRange(NSNotFound, 0))
    }
    
    public override func responds(to aSelector: Selector!) -> Bool {
        
        if NSStringFromSelector(aSelector) == "copy:" {
            return self.textLayout?.selectedRange.range.location != NSNotFound
        }
        
        return super.responds(to: aSelector)
    }
    
    private var effectiveText: String? {
        if let layout = textLayout {
            if layout.selectedRange.range.location != NSNotFound {
                return layout.attributedString.string.nsstring.substring(with: layout.selectedRange.range)
            } else {
                return layout.attributedString.string
            }
        } else {
            return nil
        }
    }
    
    @objc public func copy(_ sender:Any) -> Void {
        if let layout = textLayout {
            if let copy = layout.interactions.copy {
                if !copy() && layout.selectedRange.range.location != NSNotFound {
                    if !layout.interactions.copyAttributedString(layout.attributedString.attributedSubstring(from: layout.selectedRange.range)) {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.declareTypes([.string], owner: self)
                        pb.setString(layout.attributedString.string.nsstring.substring(with: layout.selectedRange.range), forType: .string)
                    }
                }
            } else if layout.selectedRange.range.location != NSNotFound {
                if !layout.interactions.copyAttributedString(layout.attributedString.attributedSubstring(from: layout.selectedRange.range)) {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.declareTypes([.string], owner: self)
                    pb.setString(layout.attributedString.string.nsstring.substring(with: layout.selectedRange.range), forType: .string)
                }
            }
        }
    }
    
    public func checkEmbeddedUnderSpoiler() {
        if let layout = self.textLayout {
            let rects = layout.spoilerRects()
            for subview in embeddedContainer.subviews {
                var isHidden = false
                loop: for rect in rects {
                    if NSIntersectsRect(NSMakeRect(subview.frame.midX, subview.frame.midY, 1, 1), rect) {
                        isHidden = true
                        break loop
                    }
                }
                subview.isHidden = isHidden
    //            if subview
            }
            let sublayers = embeddedContainer.layer?.sublayers ?? []
            for subview in sublayers {
                var isHidden = false
                loop: for rect in rects {
                    if NSIntersectsRect(NSMakeRect(subview.frame.midX, subview.frame.midY, 1, 1), rect) {
                        isHidden = true
                        break loop
                    }
                }
                subview.opacity = isHidden ? 0 : 1
            }
        }
    }
    
    @objc func paste(_ sender:Any) {
        
    }
    
    public override func removeFromSuperview() {
        super.removeFromSuperview()
    }
    
    
    public func updateWithNewWidth(_ width: CGFloat) {
        let layout = self.textLayout
        layout?.measure(width: width)
        self.update(layout)
    }
 
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}


/*
 for spoiler in layout.spoilers.filter({ !$0.isRevealed }) {
     if let spoilerRange = spoiler.range.intersection(line.range) {
         let range = spoilerRange.intersection(layout.selectedRange.range)
         
         var ranges:[(NSRange, NSColor)] = []
         if let range = range {
             ranges.append((NSMakeRange(spoiler.range.lowerBound, range.lowerBound - spoiler.range.lowerBound), spoiler.color))
             ranges.append((NSMakeRange(spoiler.range.upperBound, range.upperBound - spoiler.range.upperBound), spoiler.color))
         } else {
             ranges.append((spoilerRange, spoiler.color))
         }
         for range in ranges {
             let startOffset = CTLineGetOffsetForStringIndex(line.line, range.0.lowerBound, nil);
             let endOffset = CTLineGetOffsetForStringIndex(line.line, range.0.upperBound, nil);

             var ascent:CGFloat = 0
             var descent:CGFloat = 0
             var leading:CGFloat = 0
             
             _ = CGFloat(CTLineGetTypographicBounds(line.line, &ascent, &descent, &leading));
             
             var rect:NSRect = line.frame
             
             rect.size.width = endOffset - startOffset
             rect.origin.x = startOffset
             rect.origin.y = rect.minY - rect.height
             rect.size.height += ceil(descent - leading)
             
             
             ctx.setFillColor(range.1.cgColor)
             ctx.fill(rect)
         }
     }
 }
 */
