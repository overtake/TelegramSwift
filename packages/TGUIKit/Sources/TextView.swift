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

private func combineIntersectingRectangles(_ rectangles: [TextViewBlockQuote]) -> [TextViewBlockQuote] {
    
    if rectangles.isEmpty {
        return []
    } else if rectangles.count == 1 {
        return rectangles
    }
    var result: [TextViewBlockQuote] = []
    var big: TextViewBlockQuote = rectangles[0]
    
    var max_w: CGFloat = big.frame.width
    
    for i in 1 ..< rectangles.count {
        let current: TextViewBlockQuote = rectangles[i]
        if current.frame.intersects(big.frame) {
            big.frame = big.frame.union(current.frame)
            if i == rectangles.count - 1 {
                result.append(big)
            }
        } else {
            result.append(big)
            if i == rectangles.count - 1 {
                result.append(rectangles[i])
            } else {
                big = rectangles[i]
            }
        }
        max_w = max(max_w, current.frame.width)
    }

    for value in result {
        value.frame = CGRect(origin: value.frame.origin, size: NSMakeSize(max_w, value.frame.height))
    }
    
    return result
}






public struct TextInputAttributes {
    public static let bold = NSAttributedString.Key(rawValue: "Attribute__Bold")
    public static let italic = NSAttributedString.Key(rawValue: "Attribute__Italic")
    public static let monospace = NSAttributedString.Key(rawValue: "Attribute__Monospace")
    public static let strikethrough = NSAttributedString.Key(rawValue: "Attribute__Strikethrough")
    public static let underline = NSAttributedString.Key(rawValue: "Attribute__Underline")
    public static let textMention = NSAttributedString.Key(rawValue: "Attribute__TextMention")
    public static let textUrl = NSAttributedString.Key(rawValue: "Attribute__TextUrl")
    public static let spoiler = NSAttributedString.Key(rawValue: "Attribute__Spoiler")
    public static let customEmoji = NSAttributedString.Key(rawValue: "Attribute__CustomEmoji")
    public static let code = NSAttributedString.Key(rawValue: "Attribute__Code")
    public static let quote = NSAttributedString.Key(rawValue: "Attribute__Blockquote")
    
    public static let embedded = NSAttributedString.Key(rawValue: "Attribute__EmbeddedItem")

    public static let allAttributes = [TextInputAttributes.bold, TextInputAttributes.italic, TextInputAttributes.monospace, TextInputAttributes.strikethrough, TextInputAttributes.underline, TextInputAttributes.textMention, TextInputAttributes.textUrl, TextInputAttributes.spoiler, TextInputAttributes.customEmoji, TextInputAttributes.code, TextInputAttributes.quote]
}



func findClosestRect(rectangles: [CGRect], point: CGPoint) -> CGRect? {
    var closestRect: CGRect?
    var closestYDistance = CGFloat.greatestFiniteMagnitude
    let point = point.offsetBy(dx: 0, dy: 5.0)
    for rect in rectangles {
        
        let point = NSMakePoint(point.x, point.y + rect.height / 2)
        if rect.contains(point) {
            return rect
        }
        
        let rectCenterY = rect.midY
        let yDistance = abs(point.y - rectCenterY)
        
        if yDistance < closestYDistance {
            closestYDistance = yDistance
            closestRect = rect
        }
    }
    
    return closestRect
}

private let quoteIcon: CGImage = {
    return NSImage(named: "Icon_Quote")!.precomposed(flipVertical: false)
}()


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

public func isValidEmail(_ email: String) -> Bool {
    // Create a regular expression pattern to match an email address
    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    
    // Create a regular expression object from the pattern
    guard let regex = try? NSRegularExpression(pattern: emailRegex) else {
        return false
    }
    if let url = URL(string: email) {
        if url.host != nil || url.scheme != nil {
            return false
        }
    }
    
    // Check if the email string matches the pattern
    let range = NSRange(location: 0, length: email.utf16.count)
    return regex.firstMatch(in: email, options: [], range: range) != nil
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


public final class TextViewBlockQuote {
    public var range: NSRange
    public var frame: CGRect
    public var colors: PeerNameColors.Colors
    public var isCode: Bool
    public var header: (TextNodeLayout, TextNode)?
    init(frame: CGRect, range: NSRange, colors: PeerNameColors.Colors, isCode: Bool, header: (TextNodeLayout, TextNode)?) {
        self.frame = frame
        self.range = range
        self.colors = colors
        self.isCode = isCode
        self.header = header
    }
    
    public var headerInset: CGFloat {
        if header != nil {
            return 20
        } else {
            return 0
        }
    }
}


public final class TextViewBlockQuoteData: NSObject {
    public let id: Int
    public let colors: PeerNameColors.Colors
    public let space: CGFloat
    public let isCode: Bool
    public let header: (TextNodeLayout, TextNode)?
    public let collapsable: Bool
    public init(id: Int, colors: PeerNameColors.Colors, isCode: Bool = false, space: CGFloat = 4, header: (TextNodeLayout, TextNode)? = nil, collapsable: Bool = false) {
        self.id = id
        self.colors = colors
        self.isCode = isCode
        self.space = space
        self.header = header
        self.collapsable = collapsable
        super.init()
    }
    
    var headerInset: CGFloat {
        if header != nil {
            return 20
        } else {
            return 0
        }
    }
    
    var minimumHeaderSize: CGFloat {
        if let header = header {
            return header.0.size.width
        } else {
            return 0
        }
    }

    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? TextViewBlockQuoteData else {
            return false
        }
        if self.id != other.id {
            return false
        }
        if self.colors != other.colors {
            return false
        }
        if self.isCode != other.isCode {
            return false
        }
        if self.space != other.space {
            return false
        }
        return true
    }
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



public func generateRectsImage(color: NSColor, rects: [CGRect], inset: CGFloat, outerRadius: CGFloat, innerRadius: CGFloat, stroke: Bool = false, strokeWidth: CGFloat = 2.0, useModernPathCalculation: Bool) -> (CGPoint, CGImage?) {
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
    
    var drawingInset = inset
    if stroke {
        drawingInset += 2.0
    }
    
    topLeft.x -= drawingInset
    topLeft.y -= drawingInset
    bottomRight.x += drawingInset * 2.0
    bottomRight.y += drawingInset * 2.0
    
    return (topLeft, generateImage(CGSize(width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        
        context.setBlendMode(.copy)
        
        if useModernPathCalculation {
            if rects.count == 1 {
                let path = CGPath(roundedRect: rects[0].offsetBy(dx: -topLeft.x, dy: -topLeft.y), cornerWidth: outerRadius, cornerHeight: outerRadius, transform: nil)
                context.addPath(path)
                
                if stroke {
                    context.setStrokeColor(color.cgColor)
                    context.setLineWidth(strokeWidth)
                    context.strokePath()
                } else {
                    context.fillPath()
                }
                return
            }
            
            var combinedRects: [[CGRect]] = []
            var currentRects: [CGRect] = []
            for rect in rects {
                if rect.width.isZero {
                    if !currentRects.isEmpty {
                        combinedRects.append(currentRects)
                    }
                    currentRects.removeAll()
                } else {
                    currentRects.append(rect)
                }
            }
            if !currentRects.isEmpty {
                combinedRects.append(currentRects)
            }
            
            for rects in combinedRects {
                var rects = rects.map { $0.insetBy(dx: -inset, dy: -inset).offsetBy(dx: -topLeft.x, dy: -topLeft.y) }
                
                let minRadius: CGFloat = 2.0
                
                for _ in 0 ..< rects.count * rects.count {
                    var hadChanges = false
                    for i in 0 ..< rects.count - 1 {
                        if rects[i].maxY > rects[i + 1].minY {
                            let midY = floor((rects[i].maxY + rects[i + 1].minY) * 0.5)
                            rects[i].size.height = midY - rects[i].minY
                            rects[i + 1].origin.y = midY
                            rects[i + 1].size.height = rects[i + 1].maxY - midY
                            hadChanges = true
                        }
                        if rects[i].maxY >= rects[i + 1].minY && rects[i].insetBy(dx: 0.0, dy: 1.0).intersects(rects[i + 1]) {
                            if abs(rects[i].minX - rects[i + 1].minX) < minRadius {
                                let commonMinX = min(rects[i].origin.x, rects[i + 1].origin.x)
                                if rects[i].origin.x != commonMinX {
                                    rects[i].origin.x = commonMinX
                                    hadChanges = true
                                }
                                if rects[i + 1].origin.x != commonMinX {
                                    rects[i + 1].origin.x = commonMinX
                                    hadChanges = true
                                }
                            }
                            if abs(rects[i].maxX - rects[i + 1].maxX) < minRadius {
                                let commonMaxX = max(rects[i].maxX, rects[i + 1].maxX)
                                if rects[i].maxX != commonMaxX {
                                    rects[i].size.width = commonMaxX - rects[i].minX
                                    hadChanges = true
                                }
                                if rects[i + 1].maxX != commonMaxX {
                                    rects[i + 1].size.width = commonMaxX - rects[i + 1].minX
                                    hadChanges = true
                                }
                            }
                        }
                    }
                    if !hadChanges {
                        break
                    }
                }
                
                context.move(to: CGPoint(x: rects[0].midX, y: rects[0].minY))
                context.addLine(to: CGPoint(x: rects[0].maxX - outerRadius, y: rects[0].minY))
                context.addArc(tangent1End: rects[0].topRight, tangent2End: CGPoint(x: rects[0].maxX, y: rects[0].minY + outerRadius), radius: outerRadius)
                context.addLine(to: CGPoint(x: rects[0].maxX, y: rects[0].midY))
                
                for i in 0 ..< rects.count - 1 {
                    let rect = rects[i]
                    let next = rects[i + 1]
                    
                    if rect.maxX == next.maxX {
                        context.addLine(to: CGPoint(x: next.maxX, y: next.midY))
                    } else {
                        let nextRadius = min(outerRadius, floor(abs(rect.maxX - next.maxX) * 0.5))
                        context.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - nextRadius))
                        if next.maxX > rect.maxX {
                            context.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX + nextRadius, y: rect.maxY), radius: nextRadius)
                            context.addLine(to: CGPoint(x: next.maxX - nextRadius, y: next.minY))
                        } else {
                            context.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - nextRadius, y: rect.maxY), radius: nextRadius)
                            context.addLine(to: CGPoint(x: next.maxX + nextRadius, y: next.minY))
                        }
                        context.addArc(tangent1End: next.topRight, tangent2End: CGPoint(x: next.maxX, y: next.minY + nextRadius), radius: nextRadius)
                        context.addLine(to: CGPoint(x: next.maxX, y: next.midY))
                    }
                }
                
                let last = rects[rects.count - 1]
                context.addLine(to: CGPoint(x: last.maxX, y: last.maxY - outerRadius))
                context.addArc(tangent1End: last.bottomRight, tangent2End: CGPoint(x: last.maxX - outerRadius, y: last.maxY), radius: outerRadius)
                context.addLine(to: CGPoint(x: last.minX + outerRadius, y: last.maxY))
                context.addArc(tangent1End: last.bottomLeft, tangent2End: CGPoint(x: last.minX, y: last.maxY - outerRadius), radius: outerRadius)
                
                for i in (1 ..< rects.count).reversed() {
                    let rect = rects[i]
                    let prev = rects[i - 1]
                    
                    if rect.minX == prev.minX {
                        context.addLine(to: CGPoint(x: prev.minX, y: prev.midY))
                    } else {
                        let prevRadius = min(outerRadius, floor(abs(rect.minX - prev.minX) * 0.5))
                        context.addLine(to: CGPoint(x: rect.minX, y: rect.minY + prevRadius))
                        if rect.minX < prev.minX {
                            context.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + prevRadius, y: rect.minY), radius: prevRadius)
                            context.addLine(to: CGPoint(x: prev.minX - prevRadius, y: prev.maxY))
                        } else {
                            context.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX - prevRadius, y: rect.minY), radius: prevRadius)
                            context.addLine(to: CGPoint(x: prev.minX + prevRadius, y: prev.maxY))
                        }
                        context.addArc(tangent1End: prev.bottomLeft, tangent2End: CGPoint(x: prev.minX, y: prev.maxY - prevRadius), radius: prevRadius)
                        context.addLine(to: CGPoint(x: prev.minX, y: prev.midY))
                    }
                }
                
                context.addLine(to: CGPoint(x: rects[0].minX, y: rects[0].minY + outerRadius))
                context.addArc(tangent1End: rects[0].topLeft, tangent2End: CGPoint(x: rects[0].minX + outerRadius, y: rects[0].minY), radius: outerRadius)
                context.addLine(to: CGPoint(x: rects[0].midX, y: rects[0].minY))
                
                if stroke {
                    context.setStrokeColor(color.cgColor)
                    context.setLineWidth(strokeWidth)
                    context.strokePath()
                } else {
                    context.fillPath()
                }
            }
            return
        }
        
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
    bottomRight.x += inset * 2
    bottomRight.y += inset * 2
    
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
    public var frame: NSRect
    public let range: NSRange
    fileprivate let lineRange: NSRange
    public var penFlush: CGFloat
    public let isRTL: Bool
    let isBlocked: Bool
    let strikethrough:[TextViewStrikethrough]
    fileprivate let embeddedItems:[TextViewEmbeddedItem]
    fileprivate init(line: CTLine, frame: CGRect, range: NSRange, lineRange: NSRange, penFlush: CGFloat, isBlocked: Bool = false, isRTL: Bool = false, strikethrough: [TextViewStrikethrough] = [], embeddedItems:[TextViewEmbeddedItem] = []) {
        self.line = line
        self.frame = frame
        self.range = range
        self.penFlush = penFlush
        self.isBlocked = isBlocked
        self.strikethrough = strikethrough
        self.isRTL = isRTL
        self.embeddedItems = embeddedItems
        self.lineRange = lineRange
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
                self.rect = rect.toScreenPixel
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
    public var lines:[TextViewLine] = []
    public private(set) var blockQuotes: [TextViewBlockQuote] = []
    public fileprivate(set) var isPerfectSized:Bool = true
    public var maximumNumberOfLines:Int32
    public let truncationType:CTLineTruncationType
    public var cutout:TextViewCutout?
    public var mayBlocked: Bool = false
    fileprivate var blockImage:(CGPoint, CGImage?) = (CGPoint(), nil)
    
    public var maskBlockImage:(CGPoint, CGImage?) = (CGPoint(), nil)
        
    public fileprivate(set) var lineSpacing:CGFloat?
    
    public var hasBlock: Bool {
        return blockImage.1 != nil
    }
    
    public var hasBlockQuotes: Bool {
        return self.attributedString.containsAttribute(attributeName: TextInputAttributes.quote) is TextViewBlockQuoteData
    }
    
    public var lastLineIsQuote: Bool {
        if let lineRange = self.lines.last?.lineRange {
            return self.attributedString.attributedSubstring(from: lineRange).containsAttribute(attributeName: TextInputAttributes.quote) is TextViewBlockQuoteData
        } else {
            return false
        }
    }
    
    public var blockCollapsable: Bool {
        return (self.attributedString.containsAttribute(attributeName: TextInputAttributes.quote) as? TextViewBlockQuoteData)?.collapsable ?? false
    }
    
    public var string: String {
        return self.attributedString.string
    }
    
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
    public var truncatingColor: NSColor? = nil
    
    public init(_ attributedString:NSAttributedString, constrainedWidth:CGFloat = 0, maximumNumberOfLines:Int32 = INT32_MAX, truncationType: CTLineTruncationType = .end, cutout:TextViewCutout? = nil, alignment:NSTextAlignment = .left, lineSpacing:CGFloat? = nil, selectText: NSColor = presentation.colors.selectText, strokeLinks: Bool = false, alwaysStaticItems: Bool = false, disableTooltips: Bool = true, mayItems: Bool = true, spoilerColor:NSColor = presentation.colors.text, isSpoilerRevealed: Bool = false, onSpoilerReveal: @escaping()->Void = {}, truncatingColor: NSColor? = nil) {
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
        self.truncatingColor = truncatingColor
        switch alignment {
        case .center:
            penFlush = 0.5
        case .right:
            penFlush = 1.0
        default:
            penFlush = 0.0
        }
        self.lineSpacing = lineSpacing
        var spoilers: [Spoiler] = []
        attributedString.enumerateAttribute(TextInputAttributes.spoiler, in: attributedString.range, options: .init(), using: { value, range, stop in
            if let _ = value {
                spoilers.append(.init(range: range, color: spoilerColor, isRevealed: isSpoilerRevealed))
            }
        })
        self.spoilers = spoilers
        
    }
    
    func revealSpoiler() -> Void {
        for spoiler in spoilers {
            spoiler.isRevealed = true
        }
        onSpoilerReveal()
    }
    public var selectedString: NSAttributedString {
        if selectedRange.range.isEmpty {
            return self.attributedString
        } else {
            return self.attributedString.attributedSubstring(from: selectedRange.range)
        }
    }
    
    public func dropLayoutSize() {
        self.layoutSize = .zero
    }
    
    public var numberOfLines: Int {
        return lines.count
    }
    public var lastLineIsRtl: Bool {
        return lines.last?.isRTL ?? false
    }
    
    public var lastLineIsBlock: Bool {
        return blockQuotes.contains(where: { blockQuote in
            if let line = lines.last {
                if blockQuote.frame.intersects(line.frame) {
                    return true
                }
            }
            return false
        })
    }
    
    public var isWholeRTL: Bool {
        return lines.allSatisfy({ $0.isRTL })
    }
    public func isFirstRTL(count: Int) -> Bool {
        for i in 0 ..< count {
            if i < lines.count {
                if !lines[i].isRTL {
                    return false
                }
            } else {
                break
            }
        }
        return true
    }
    public var firstLineWidth: CGFloat {
        return lines[0].frame.width
    }
    public var lastLineWidth: CGFloat {
        return lines[lines.count - 1].frame.width
    }
    public var firstLineHeight: CGFloat {
        return lines[0].frame.height
    }
    public var lastLineHeight: CGFloat {
        return lines[lines.count - 1].frame.height
    }
    
    
    func calculateLayout(isBigEmoji: Bool = false, lineSpacing: CGFloat? = nil, saveRTL: Bool = false) -> Void {
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
        self.blockQuotes.removeAll()
        
        let fontAscent = CTFontGetAscent(font)
        let fontDescent = CTFontGetDescent(font)
       
        let fontLineHeight = floor(fontAscent + fontDescent)
                
        var fontLineSpacing:CGFloat = lineSpacing ?? floor(fontLineHeight * 0.12)

        
        let attributedString = self.attributedString.mutableCopy() as! NSMutableAttributedString
        
        attributedString.enumerateAttributes(in: attributedString.range, options: []) { attributes, range, _ in
            if let _ = attributes[TextInputAttributes.embedded] as? AnyHashable {
                attributedString.addAttribute(.foregroundColor, value: NSColor.clear, range: range)
            }
        }
        
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

        let blockQuote:(Int)-> TextViewBlockQuoteData? = { index in
            return (attributedString.attribute(TextInputAttributes.quote, at: min(lastLineCharacterIndex, attributedString.length - 1), effectiveRange: nil) as? TextViewBlockQuoteData)
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
                
                let lineRange = NSMakeRange(CTLineGetStringRange(line).location, CTLineGetStringRange(line).length)
                let range = NSMakeRange(startIndex, endIndex - startIndex)
                                
                if lineRange.intersection(range) != range {
                    return
                }
                if lineRange.location != startIndex, rawLeftOffset == 0 {
                    return
                }
               // return;
                                        
                if abs(rightOffset - leftOffset) < 200 {
                    let x = floor(min(leftOffset, rightOffset)) + 1
                    var width = floor(abs(rightOffset - leftOffset) + rightInset)
                    if Int(width) % 2 != 0 {
                        width += 1
                    }
                    let height = ceil(ascent + descent)
                    let size = NSMakeSize(width, height)
                    let rect = CGRect(x: x, y: floor(descent - (ascent + descent)), width: size.width, height: size.height)
                    embeddedItems.append(TextViewEmbeddedItem(range: NSMakeRange(startIndex, endIndex - startIndex), frame: rect.insetBy(dx: -2, dy: -2), item: item))
                }
            }
            



            var lineConstrainedWidth = constrainedWidth
            var lineOriginY: CGFloat = 0
            
            var lineCutoutOffset: CGFloat = 0.0
            var lineAdditionalWidth: CGFloat = 0.0

            var isPreformattedLine: CGFloat? = nil
            
            fontLineSpacing = lineSpacing ?? floor(fontLineHeight * 0.12)
            
            if isBigEmoji {
                lineOriginY += 2
            }
            
            var isFirstFormattedLine: Bool = false
            
            if attributedString.length > 0, let blockQuote = blockQuote(lastLineCharacterIndex) {
                
                
                breakInset = CGFloat(blockQuote.space * 2 + 20)
                lineCutoutOffset += CGFloat(blockQuote.space * 2)
                lineAdditionalWidth += max(breakInset, blockQuote.minimumHeaderSize)
                
                if !isWasPreformatted {
                    layoutSize.height += CGFloat(blockQuote.space) + fontLineSpacing
                    
                    layoutSize.height += blockQuote.headerInset
                    
                    isFirstFormattedLine = true
                } else {
                    
                    if isWasPreformatted {
                        
                    } else if first {
                        layoutSize.height += CGFloat(blockQuote.space)
                    }
                    
                }

                isPreformattedLine = CGFloat(blockQuote.space)
                isWasPreformatted = true
            } else {
                
//                if isWasPreformatted && !first {
//                    lineOriginY -= (2 - fontLineSpacing)
//                }
//                if let isPreformattedLine = isPreformattedLine {
//                    fontLineSpacing += isPreformattedLine
//                }
                
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
            
            
            
//            if lineString.string.containsEmoji, !isBigEmoji {
//                if first {
//                    lineHeight += floor(fontDescent)
//                    lineOriginY += floor(fontDescent)
//                }
//            }
            
            
            if maximumNumberOfLines != 0 && lines.count == (Int(maximumNumberOfLines) - 1) && lineCharacterCount > 0 {
                
                
                if first {
                    first = false
                } else {
                    layoutSize.height += fontLineSpacing
                }
                
                var brokenLineRange = CFRange(location: lastLineCharacterIndex, length: lineCharacterCount)
                if brokenLineRange.location + brokenLineRange.length > attributedString.length {
                    brokenLineRange.length = attributedString.length - brokenLineRange.location
                }

                
                let coreTextLine: CTLine
                
                let originalLine = CTTypesetterCreateLineWithOffset(typesetter, CFRange(location: lastLineCharacterIndex, length: attributedString.length - lastLineCharacterIndex), 0.0)
                
               
                
                if CTLineGetTypographicBounds(originalLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(originalLine) < Double(constrainedWidth) {
                    coreTextLine = originalLine
                } else {
                    var truncationTokenAttributes: [NSAttributedString.Key : Any] = [:]
                    truncationTokenAttributes[NSAttributedString.Key(kCTFontAttributeName as String)] = font
                    truncationTokenAttributes[NSAttributedString.Key(kCTForegroundColorAttributeName as String)] = truncatingColor ?? attributedString.attribute(.foregroundColor, at: min(lastLineCharacterIndex, attributedString.length - 1), effectiveRange: nil) as? NSColor ?? NSColor.black
                    
                    let tokenString = "\u{2026}"
                    let truncatedTokenString = NSAttributedString(string: tokenString, attributes: truncationTokenAttributes)
                    let truncationToken = CTLineCreateWithAttributedString(truncatedTokenString)
                    
                    
                    var lineConstrainedWidth = constrainedWidth
                    if bottomCutoutEnabled {
                        lineConstrainedWidth -= bottomCutoutSize.width
                    }

                    
                    coreTextLine = CTLineCreateTruncatedLine(originalLine, Double(lineConstrainedWidth), truncationType, truncationToken) ?? truncationToken
                    
                    let runs = (CTLineGetGlyphRuns(coreTextLine) as [AnyObject]) as! [CTRun]
                    for run in runs {
                        let runAttributes: NSDictionary = CTRunGetAttributes(run)
                        if let _ = runAttributes["CTForegroundColorFromContext"] {
                            brokenLineRange.length = CTRunGetStringRange(run).location - brokenLineRange.location
                            break
                        }
                    }
                    if brokenLineRange.location + brokenLineRange.length > attributedString.length {
                        brokenLineRange.length = attributedString.length - brokenLineRange.location
                    }

                    
                    isPerfectSized = false
                }
                lineRange = CTLineGetStringRange(coreTextLine)
                
                var isRTL = false
                let glyphRuns = CTLineGetGlyphRuns(coreTextLine) as NSArray
                if glyphRuns.count != 0 {
                    for glyphRun in glyphRuns {
                        if CTRunGetStatus(glyphRun as! CTRun).contains(CTRunStatus.rightToLeft) {
                            isRTL = true
                            break
                        }
                    }
                    
                }
                
                if isRTL {
                    lineAdditionalWidth = 0
                }
                
                let lineWidth = ceil(CGFloat(CTLineGetTypographicBounds(coreTextLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(coreTextLine)))
                let lineFrame = CGRect(x: lineCutoutOffset, y: lineOriginY, width: lineWidth, height: lineHeight)
                layoutSize.height += lineHeight + fontLineSpacing
                layoutSize.width = max(layoutSize.width, lineWidth + lineAdditionalWidth)
                
                if brokenLineRange.location >= 0 && brokenLineRange.length > 0 && brokenLineRange.location + brokenLineRange.length <= attributedString.length {
                    attributedString.enumerateAttributes(in: NSMakeRange(lineRange.location, lineRange.length), options: []) { attributes, range, _ in
                        if let embeddedItem = attributes[TextInputAttributes.embedded] as? AnyHashable {
                            var ascent: CGFloat = 0.0
                            var descent: CGFloat = 0.0
                            CTLineGetTypographicBounds(coreTextLine, &ascent, &descent, nil)
                            
                            addEmbeddedItem(item: embeddedItem, line: coreTextLine, ascent: ascent, descent: descent, startIndex: range.min, endIndex: range.max)
                        } else if let _ = attributes[.strikethroughStyle] {
                            let color = attributes[.foregroundColor] as? NSColor ?? presentation.colors.text
                            
                            
                            
                            let lowerX = floor(CTLineGetOffsetForStringIndex(coreTextLine, range.location, nil))
                            var upperX = ceil(CTLineGetOffsetForStringIndex(coreTextLine, min(range.location + range.length, lineRange.location + lineRange.length), nil))
                            
                            let lineStartIndex = CTLineGetStringIndexForPosition(coreTextLine, NSMakePoint(lowerX, lineFrame.minY))

                            
                            if lowerX > 0 && upperX == 0 {
                                upperX = lineWidth
                            }
                            
                            if lowerX == 0, !range.contains(lineStartIndex) {
                                
                            } else {
                                let x = lowerX < upperX ? lowerX : upperX
                                strikethroughs.append(TextViewStrikethrough(color: color, frame: CGRect(x: x, y: 0.0, width: abs(upperX - lowerX), height: fontLineHeight)))
                            }
                            
                        }

                    }
                    
                }
                

                
                var penFlush = self.penFlush
                if penFlush == 0 {
                    if isRTL {
                        penFlush = 1
                    }
                } else if isRTL, penFlush == 1 {
                    penFlush = 0
                }
                let range = NSMakeRange(lineRange.location, lineRange.length)
                lines.append(TextViewLine(line: coreTextLine, frame: lineFrame, range: range, lineRange: range, penFlush: penFlush, isBlocked: isWasPreformatted, isRTL: isRTL, strikethrough: strikethroughs, embeddedItems: embeddedItems))
                
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
                    
                    if let blockQuote = lineString.containsAttribute(attributeName: TextInputAttributes.quote) as? TextViewBlockQuoteData {
                        
                        let preformattedSpace = CGFloat(blockQuote.space) * 2
                        
                        var frame = NSMakeRect(0, lineFrame.minY - lineFrame.height, lineWidth + max(preformattedSpace + 20, lineAdditionalWidth), lineFrame.height + preformattedSpace)
                        
                        if isFirstFormattedLine {
                            frame.origin.y -= blockQuote.headerInset
                            frame.size.height += blockQuote.headerInset
                        }
                        blockQuotes.append(.init(frame: frame, range: NSMakeRange(lineRange.location, lineRange.length), colors: blockQuote.colors, isCode: blockQuote.isCode, header: blockQuote.header))
                    }

                    attributedString.enumerateAttributes(in: NSMakeRange(lineRange.location, lineRange.length), options: []) { attributes, range, _ in
                        if let embeddedItem = attributes[TextInputAttributes.embedded] as? AnyHashable {
                            var ascent: CGFloat = 0.0
                            var descent: CGFloat = 0.0
                            CTLineGetTypographicBounds(coreTextLine, &ascent, &descent, nil)
                                                        
                            addEmbeddedItem(item: embeddedItem, line: coreTextLine, ascent: ascent, descent: descent, startIndex: range.location, endIndex: range.location + range.length)
                        } else if let _ = attributes[.strikethroughStyle] {
                            let color = attributes[.foregroundColor] as? NSColor ?? presentation.colors.text
                            let lowerX = floor(CTLineGetOffsetForStringIndex(coreTextLine, range.location, nil))
                            let upperX = ceil(CTLineGetOffsetForStringIndex(coreTextLine, range.location + range.length, nil))
                            let x = lowerX < upperX ? lowerX : upperX
                            let value = attributes.contains(where: { $0.key == TextInputAttributes.customEmoji })
                            if !value {
                                strikethroughs.append(TextViewStrikethrough(color: color, frame: CGRect(x: x, y: 0.0, width: abs(upperX - lowerX), height: fontLineHeight)))
                            }
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
                    var penFlush = self.penFlush
                    if penFlush == 0 {
                        if isRTL {
                            penFlush = 1
                        }
                    } else if isRTL, penFlush == 1 {
                        penFlush = 0
                    }
                    let range = NSMakeRange(lineRange.location, lineRange.length)
                    lines.append(TextViewLine(line: coreTextLine, frame: lineFrame, range: range, lineRange: range, penFlush: penFlush, isBlocked: isWasPreformatted, isRTL: isRTL, strikethrough: strikethroughs, embeddedItems: embeddedItems))
                    lastLineCharacterIndex += lineCharacterCount
                } else {
                    if !lines.isEmpty {
                        layoutSize.height += fontLineSpacing
                    }
                    break
                }
            }
            
            if let isPreformattedLine = isPreformattedLine {
                if lastLineCharacterIndex == attributedString.length || blockQuote(lastLineCharacterIndex) == nil {
                    layoutSize.height += isPreformattedLine + isPreformattedLine / 2
                }
            }
            
        }
        
        self.blockQuotes = combineIntersectingRectangles(self.blockQuotes)
       
        
//        if mayBlocked {
            
        
//
//            self.blockImage = generateRectsImage(color: presentation.colors.grayBackground, rects: monospacedRects, inset: 0, outerRadius: .cornerRadius, innerRadius: .cornerRadius)
//        }
        
        var embeddedItems: [EmbeddedItem] = []
        for line in lines {
            for embeddedItem in line.embeddedItems {
                let penOffset = floor(CGFloat(CTLineGetPenOffsetForFlush(line.line, line.penFlush, Double(layoutSize.width))))
                embeddedItems.append(EmbeddedItem(range: embeddedItem.range, rect: embeddedItem.frame.offsetBy(dx: line.frame.minX, dy: line.frame.minY).offsetBy(dx: penOffset, dy: 0), value: embeddedItem.item))
            }
        }


        self.embeddedItems = embeddedItems
        
        if saveRTL {
            layoutSize.width = max(layoutSize.width, constrainedWidth)
        }
        
        self.layoutSize = layoutSize
    }
    
    
    public func rects(_ fromRange: NSRange) -> [(CGRect, TextViewLine)] {
        var rects:[(CGRect, TextViewLine)] = []
        for i in 0 ..< lines.count {
            let line = lines[i]
            if let intersection = fromRange.intersection(line.range) {
                let range = intersection.intersection(selectedRange.range)
                
                var ranges:[(NSRange, TextViewLine)] = []
                if let range = range {
                    ranges.append((NSMakeRange(fromRange.lowerBound, range.lowerBound - fromRange.lowerBound), line))
                    ranges.append((NSMakeRange(fromRange.lowerBound, range.lowerBound - fromRange.lowerBound), line))
                } else {
                    ranges.append((intersection, line))
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
                    rect.origin.x = min(startOffset, endOffset) + line.frame.origin.x
                    rect.origin.y = rect.minY - rect.height + 2
                    rect.size.height += ceil(descent - leading)
                    
                    rects.append((rect, line))
  
                }
            }
        }
        return rects
    }
    
    public func generateBlock(for range: NSRange, backgroundColor: NSColor) -> (CGPoint, CGImage?) {
        
        let rectsAndLines = rects(range)
        var rects = rectsAndLines.map { $0.0 }
        let lines = rectsAndLines.map { $0.1 }
        
        if !rects.isEmpty {
            let sortedIndices = (0 ..< rects.count).sorted(by: { rects[$0].width > rects[$1].width })
            for i in 0 ..< sortedIndices.count {
                let index = sortedIndices[i]
                for j in -1 ... 1 {
                    if j != 0 && index + j >= 0 && index + j < sortedIndices.count {
                        if abs(rects[index + j].width - rects[index].width) < 10 {
                            rects[index + j].size.width = max(rects[index + j].width, rects[index].width)
                        }
                    }
                }
            }
            
            for i in 0 ..< rects.count {
                let height = rects[i].size.height
                rects[i] = rects[i].insetBy(dx: 0, dy: floor((rects[i].height - height) / 2.0))
                rects[i].size.height = height
                
                if lines[i].penFlush == 1.0 {
                    rects[i].origin.x = layoutSize.width - rects[i].width
                } else if lines[i].penFlush == 0.5 {
                    rects[i].origin.x = floor((layoutSize.width - rects[i].width) / 2.0)
                }
                
            }
            
            return generateRectsImage(color: backgroundColor, rects: rects, inset: 0, outerRadius: 4, innerRadius: 4, useModernPathCalculation: false)
            
//            var image = generateRectsImage(color: backgroundColor, rects: rects, inset: 0, outerRadius: rects[0].height / 2 , innerRadius: 10)
//            image.0 = rects[0].origin
//            
//            return image
        } else {
            return (.zero, nil)
        }
        
    }
    
    public func generateBlock(backgroundColor: NSColor) -> (CGPoint, CGImage?) {
        
        let lines = self.lines.filter { self.attributedString.attributedSubstring(from: $0.range).string != "\n" }
        var rects = lines.map({ $0.frame })
        
        
        if !rects.isEmpty {
            let sortedIndices = (0 ..< rects.count).sorted(by: { rects[$0].width > rects[$1].width })
            for i in 0 ..< sortedIndices.count {
                let index = sortedIndices[i]
                for j in -1 ... 1 {
                    if j != 0 && index + j >= 0 && index + j < sortedIndices.count {
                        if abs(rects[index + j].width - rects[index].width) < 10 {
                            rects[index + j].size.width = max(rects[index + j].width, rects[index].width)
                        }
                    }
                }
            }
            
            for i in 0 ..< rects.count {
                let height = rects[i].size.height + 5
                rects[i] = rects[i].insetBy(dx: 0, dy: floor((rects[i].height - height) / 2.0))
                rects[i].size.height = height
                
                if lines[i].penFlush == 1.0 {
                    rects[i].origin.x = layoutSize.width - rects[i].width - 5
                    rects[i].size.width += 10
                } else if lines[i].penFlush == 0.5 {
                    rects[i].origin.x = floor((layoutSize.width - rects[i].width) / 2.0)
                    rects[i].size.width += 20
                } else {
                    rects[i].size.width += 10
                    rects[i].origin.x -= 5
                }
                
            }
            
            var image = generateRectsImage(color: backgroundColor, rects: rects, inset: 0, outerRadius: lines.count == 1 ? rects[0].height / 2 : 10, innerRadius: .cornerRadius)
            image.0 = NSMakePoint(0, 0)
            
            return image
        } else {
            return (.zero, nil)
        }
    }
    
    public func generateAutoBlock(backgroundColor: NSColor, minusHeight: CGFloat = 0, yInset: CGFloat = 0) {
        
        var rects = self.lines.map({ $0.frame })
        
        if !rects.isEmpty {
            let sortedIndices = (0 ..< rects.count).sorted(by: { rects[$0].width > rects[$1].width })
            for i in 0 ..< sortedIndices.count {
                let index = sortedIndices[i]
                for j in -1 ... 1 {
                    if j != 0 && index + j >= 0 && index + j < sortedIndices.count {
                        let dif = minusHeight != 0 ? 10 : 40.0
                        if abs(rects[index + j].width - rects[index].width) < dif {
                            rects[index + j].size.width = max(rects[index + j].width, rects[index].width)
                        }
                    }
                }
            }
            
            for i in 0 ..< rects.count {
                let height = rects[i].size.height + 5
                rects[i] = rects[i].insetBy(dx: 0, dy: floor((rects[i].height - height) / 2.0))
                rects[i].size.height = height
                if self.penFlush == 0.5 {
                    rects[i].origin.x = floor((layoutSize.width - rects[i].width) / 2.0)
                    rects[i].size.width += 20
                } else {
                    rects[i].size.width += 10
                    rects[i].origin.x -= 5
                }
            }
            
            self.blockImage = generateRectsImage(color: backgroundColor, rects: rects, inset: 0, outerRadius: lines.count == 1 ? rects[0].height / 2 : 10, innerRadius: .cornerRadius)
            self.blockImage.0 = NSMakePoint(0, 0)
            
            var offset: NSPoint = NSPoint(x: 0, y: 0)
            if self.penFlush == 0.5 {
                offset.y = 2
                layoutSize.width += 20
            } else {
                layoutSize.width += 10
                offset.x = 5
            }
            for i in 0 ..< lines.count {
                let line = lines[i]
                lines[i] = TextViewLine(line: line.line, frame: line.frame.offsetBy(dx: offset.x, dy: offset.y + yInset), range: line.range, lineRange: line.range, penFlush: self.penFlush, strikethrough: line.strikethrough, embeddedItems: line.embeddedItems)
            }
            layoutSize.height = rects.last!.maxY - minusHeight
        } else {
            self.blockImage = (.zero, nil)
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
    public func fitToLines(_ count: Int) {
        if lines.count > count {
            let lines = Array(lines.prefix(count))
            self.layoutSize = NSMakeSize(self.layoutSize.width, lines[lines.count - 1].frame.minY + 2)
        }
    }
    public func measure(width: CGFloat = 0, isBigEmoji: Bool = false, lineSpacing: CGFloat? = nil, saveRTL: Bool = false) -> Void {
        
        if width != 0 {
            constrainedWidth = width
        }

        toolTipRects.removeAll()
        
        calculateLayout(isBigEmoji: isBigEmoji, lineSpacing: lineSpacing, saveRTL: saveRTL)

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
                            let rect = NSMakeRect(line.frame.minX + leftOffset + (line.isRTL ? layoutSize.width - line.frame.width : 0), line.frame.minY + 1, rightOffset - leftOffset, 1.0)
                            strokeRects.append((rect, color))
                            if !disableTooltips, interactions.resolveLink(value) != attributedString.string.nsstring.substring(with: range) {
                                var leftOffset: CGFloat = 0.0
                                if lineRange.location != line.range.location {
                                    leftOffset = floor(CTLineGetOffsetForStringIndex(line.line, lineRange.location, nil))
                                }
                                let rightOffset: CGFloat = ceil(CTLineGetOffsetForStringIndex(line.line, lineRange.location + lineRange.length, nil))
                                
                                toolTipRects.append(NSMakeRect(rect.minX, line.frame.minY - line.frame.height, rightOffset - leftOffset, line.frame.height))
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
        
    }
    
    public func clearSelect() {
        self.selectedRange.range = NSMakeRange(NSNotFound, 0)
    }
    
    private func map(_ index: Int, byWord: Bool, forward: Bool) -> Int {
        if byWord {
            let range = self.attributedString.doubleClick(at: min(max(0, index), self.attributedString.string.length - 1))
            if forward {
                return range.max
            } else {
                return range.min
            }
        } else {
            return index
        }
    }
    

    public func selectedRange(startPoint:NSPoint, currentPoint:NSPoint, byWord: Bool = false) -> NSRange {

        
        var selectedRange:NSRange = NSMakeRange(NSNotFound, 0)
        
        if (currentPoint.x != -1 && currentPoint.y != -1 && !lines.isEmpty && startPoint.x != -1 && startPoint.y != -1) {
            
            
            let startSelectLineIndex = findIndex(location: startPoint)
            let currentSelectLineIndex = findIndex(location: currentPoint)
            
            
            let dif = abs(startSelectLineIndex - currentSelectLineIndex)
            let isReversed = currentSelectLineIndex < startSelectLineIndex
            var i = startSelectLineIndex
            while isReversed ? i >= currentSelectLineIndex : i <= currentSelectLineIndex {
                let line = lines[i].line
                
                let penOffset = CGFloat( CTLineGetPenOffsetForFlush(lines[i].line, lines[i].penFlush, Double(layoutSize.width)))
                
                let lineRange = CTLineGetStringRange(line)
                
                let sp = startPoint.offsetBy(dx: -penOffset - lines[i].frame.minX, dy: 0)
                let cp = currentPoint.offsetBy(dx: -penOffset - lines[i].frame.minX, dy: 0)
                
                var startIndex: CFIndex = CTLineGetStringIndexForPosition(line, sp)
                var endIndex: CFIndex = CTLineGetStringIndexForPosition(line, cp)
                
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
        if selectedRange.location != NSNotFound, selectedRange.length > 0 {
            let start = selectedRange.min
            let end = selectedRange.max
            selectedRange.location = map(start, byWord: byWord, forward: false)
            selectedRange.length = map(end, byWord: byWord, forward: true) - selectedRange.location
        }
        
        return selectedRange
    }

    
    public func findIndex(location:NSPoint) -> Int {
        
        if location.y == .greatestFiniteMagnitude {
            return lines.count - 1
        } else if location.y == 0 {
            return 0
        }
        
        let rect = findClosestRect(rectangles: self.lines.map { $0.frame }, point: location)
        return lines.firstIndex(where: { $0.frame == rect }) ?? 0
        //var previous:NSRect = lines[0].frame
//        var index: Int = 0
//        for idx in 0 ..< lines.count {
//            if isCurrentLine(pos: location, index: idx) {
//                return idx
//            }
//        }
        
//        return location.y <= layoutSize.height ? 0 : (lines.count - 1)
        
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
        let rects = spoilerRects()
        for rect in rects {
            if rect.0.contains(point) {
                if !rect.1.isRevealed {
                    return rect.1
                }
            }
        }
        return nil
    }
    
    func spoilerRects(_ checkRevealed: Bool = true) -> [(CGRect, Spoiler)] {
        var rects:[(CGRect, Spoiler)] = []
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
                        rect.origin.x = min(startOffset, endOffset) + line.frame.origin.x
                        rect.origin.y = rect.minY - rect.height + 2
                        rect.size.height += ceil(descent - leading)
                        
                        if line.isRTL {
                            rect.origin.x += layoutSize.width - line.frame.width
                        }
                        
                        rects.append((rect, spoiler))
      
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
    
    public func block(at point:NSPoint) -> NSRange? {
        
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
            
            if let _ =  attrs[TextInputAttributes.code] {
                return range
            }
        }
        return nil
    }
    
    func findCharacterIndex(at point:NSPoint) -> Int {
        let index = findIndex(location: point)
        
        guard index != -1 else {
            return index
        }
        
        let line = lines[index]
        let width:CGFloat = CGFloat(CTLineGetTypographicBounds(line.line, nil, nil, nil));
        if width > point.x {
            var charIndex = Int(CTLineGetStringIndexForPosition(line.line, point))
            
            let ctRange = CTLineGetStringRange(line.line)
            charIndex = (charIndex - ctRange.location) + line.range.location
            
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
        var firstIndex: Int = startIndex
        var lastIndex: Int = startIndex
        
        var firstFound: Bool = false
        var lastFound: Bool = false
        
        let block = attributedString.attribute(TextInputAttributes.quote, at: firstIndex, effectiveRange: &blockRange) as? TextViewBlockQuoteData
        
        attributedString.enumerateAttribute(TextInputAttributes.quote, in: attributedString.range, using: { value, range, _ in
            if value as? TextViewBlockQuoteData === block {
                blockRange.location = min(range.location, blockRange.location)
                blockRange.length += range.length
            }
        })

        if blockRange.location != NSNotFound, block != nil {
            firstIndex = blockRange.min - 1
            lastIndex = blockRange.max + 1
            firstFound = true
            lastFound = true
        }
        
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
           lastIndex = max(min(lastIndex, self.attributedString.length - 1) - 1, 0)
        }
        if firstFound {
           firstIndex = min(firstIndex + 1, self.attributedString.length - 1)
       }
        self.selectedRange = TextSelectedRange(range: NSMakeRange(firstIndex, (lastIndex + 1) - firstIndex), color: selectText, def: true)
        
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
        let string:NSString = attributedString.string.nsstring
        let tidyChar = char.trimmingCharacters(in: NSCharacterSet.alphanumerics)
        let valid:Bool = tidyChar == "" || tidyChar == "_" || tidyChar == "\u{FFFD}"
        
        var inBlockRange: NSRange = NSMakeRange(0, 0)
        let inBlock = attributedString.attribute(TextInputAttributes.quote, at: startIndex, effectiveRange: &inBlockRange) as? TextViewBlockQuoteData
        
        attributedString.enumerateAttribute(TextInputAttributes.quote, in: attributedString.range, using: { value, range, _ in
            if value as? TextViewBlockQuoteData === inBlock {
                inBlockRange.location = min(range.location, inBlockRange.location)
                inBlockRange.length += range.length
            }
        })
        
        
        if let _ = inBlock {
            range = inBlockRange
        } else {
            while valid {
                let prevChar = string.substring(with: NSMakeRange(prev, 1))
                let nextChar = string.substring(with: NSMakeRange(next, 1))
                
                
                let prevBlock = attributedString.attribute(.init("Attribute__Blockquote"), at: prev, effectiveRange: nil)
                let nextBlock = attributedString.attribute(.init("Attribute__Blockquote"), at: next, effectiveRange: nil)
                
               
                
                let tidyPrev = prevChar.trimmingCharacters(in: NSCharacterSet.alphanumerics)
                let tidyNext = nextChar.trimmingCharacters(in: NSCharacterSet.alphanumerics)
                var prevValid:Bool = (tidyPrev == "" || tidyPrev == "_" || tidyPrev == "\u{FFFD}") && prevBlock == nil
                var nextValid:Bool = (tidyNext == "" || tidyNext == "_" || tidyNext == "\u{FFFD}") && nextBlock == nil
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
    
    
    public var range:NSRange = NSMakeRange(NSNotFound, 0)
        
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

private final class TextDrawLayer : SimpleLayer {
    
    var drawer:((CGContext)->Void)? = nil
    
    override func draw(in ctx: CGContext) {
        drawer?(ctx)
    }
}

public class TextView: Control, NSViewToolTipOwner, ViewDisplayDelegate {
    
    
    public func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        
        guard let layout = self.textLayout else { return "" }
        
        if let link = layout.link(at: point), let resolved = layout.interactions.resolveLink(link.0)?.removingPercentEncoding {
            return resolved.prefixWithDots(70)
        }
        
        return ""

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
    public let embeddedContainer = SimpleLayer()
    
    private var blockHeaderRects: [(NSRect, NSRange)] = []
    
    private var shimmerEffect: ShimmerView?
    private var shimmerMask: SimpleLayer?
    
    public var selectionWasCleared: Bool = false

    private var clearExceptRevealed: Bool = false
    private var inAnimation: Bool = false {
        didSet {
            setNeedsDisplayLayer()
        }
    }
    
    private var visualEffect: VisualEffect? = nil

    private var textView: View? = nil
    private let drawLayer: TextDrawLayer = TextDrawLayer()
    private var blockMask: SimpleLayer?
    
    public var lockDrawingLayer: Bool = false
    
    
    var hasBackground: Bool {
        return blurBackground != nil
    }
    
    public var blurBackground: NSColor? = nil {
        didSet {
            updateBackgroundBlur()
            if hasBackground {
                self.backgroundColor = .clear
            }
        }
    }
    
    public var canDrawBlocks: Bool = true {
        didSet {
            drawLayer.needsDisplay()
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
    public var onlyTextIsInteractive: Bool = false

    
    
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
        
        self.layer?.addSublayer(drawLayer)
        self.drawLayer.drawer = { [weak self] ctx in
            guard let `self` = self else {
                return
            }
            self.draw(self.drawLayer, in: ctx)
        }
        
        embeddedContainer.masksToBounds = false
        self.layer?.addSublayer(embeddedContainer)
        self.layer?.masksToBounds = false

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
            return _disableBackgroundDrawing || hasBackground
        }
    }


    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    public var drawingLayer: CALayer {
        return drawLayer
    }
    
    public func set(mask: CALayer?) {
        self.drawLayer.mask = mask
        
        if let mask {
            let copy = SimpleLayer()
            copy.contentsGravity = mask.contentsGravity
            copy.frame = mask.frame
            copy.contents = mask.contents
            self.embeddedContainer.mask = copy
        } else {
            self.embeddedContainer.mask = nil
        }
    }
    
    public override func draw(_ layer: CALayer, in ctx: CGContext) {
        //backgroundColor = .random
       // super.draw(layer, in: ctx)

//        if hasBackground, layer != textView?.layer {
//            return
//        }
        
        var blockHeaderRects: [(NSRect, NSRange)] = []

        if let layout = textLayout, drawingLayer == layer {
            
            ctx.setAllowsFontSubpixelPositioning(true)
            ctx.setShouldSubpixelPositionFonts(true)
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
                      

                    
            
            if clearExceptRevealed {
                let path = CGMutablePath()
                
                for spoiler in layout.spoilerRects(false) {
                    path.addRect(spoiler.0)
                }
                ctx.addPath(path)
                ctx.clip()
            }
            
            
            
//            if !System.supportsTransparentFontDrawing {
//                ctx.setAllowsAntialiasing(true)
//                
//                ctx.setAllowsFontSmoothing(backingScaleFactor == 1.0)
//                ctx.setShouldSmoothFonts(backingScaleFactor == 1.0)
//                
//                if backingScaleFactor == 1.0 && !disableBackgroundDrawing {
//                    ctx.setFillColor(backgroundColor.cgColor)
//                    for line in layout.lines {
//                        ctx.fill(NSMakeRect(0, line.frame.minY - line.frame.height - 2, line.frame.width, line.frame.height + 6))
//                    }
//                }
//            } 
//           
            
            
            if let image = layout.blockImage.1, !hasBackground {
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
                 
                        let penOffset = CGFloat(CTLineGetPenOffsetForFlush(lines[i].line, lines[i].penFlush, Double(frame.width)))
                        
                        var rect:NSRect = lines[i].frame
                        let lineRange = lines[i].lineRange
                        
                        var beginLineIndex:CFIndex = 0
                        var endLineIndex:CFIndex = 0
                        
                        
                        if let _ = lineRange.intersection(lessRange){
                            
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
                            
                           
                            rect.size.width = width
                            
                            rect.origin.x = penOffset + startOffset
                            
                            rect.origin.y = rect.minY - rect.height + rect.height * 0.12
                            let insideBlock = layout.blockQuotes.first(where: { block in
                                if block.frame.contains(rect.origin) {
                                    return true
                                } else {
                                    return false
                                }
                            })
                            if let _ = insideBlock {
                                rect.origin.x += 4 * 2
                            }
                            if let _ = insideBlock, lines[i].isRTL {
                                rect.origin.x -= 20 + 4 * 2
                            }
                            
                            
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
            
            if canDrawBlocks {
                for blockQuote in layout.blockQuotes {
                    let radius: CGFloat = 3.0
                    let lineWidth: CGFloat = 3.0
                    
                    
                    let blockFrame = blockQuote.frame
                    let blockColor = blockQuote.isCode ? blockQuote.colors.tertiary ?? blockQuote.colors.main : blockQuote.colors.main
                    let tintColor = blockQuote.colors.main
                    let secondaryTintColor = blockQuote.colors.secondary
                    let tertiaryTintColor = blockQuote.colors.tertiary
                    
                    
                    ctx.setFillColor(blockColor.withAlphaComponent(blockQuote.isCode ? 0.25 : 0.1).cgColor)
                    ctx.addPath(CGPath(roundedRect: blockFrame, cornerWidth: radius, cornerHeight: radius, transform: nil))
                    ctx.fillPath()
                    
                    ctx.setFillColor(tintColor.cgColor)
                    
                    if !blockQuote.isCode {
                        let iconSize = quoteIcon.backingSize
                        let quoteRect = CGRect(origin: CGPoint(x: blockFrame.maxX - 4.0 - iconSize.width, y: blockFrame.minY + 4.0), size: iconSize)
                        ctx.saveGState()
                        ctx.translateBy(x: quoteRect.midX, y: quoteRect.midY)
                        ctx.scaleBy(x: 1.0, y: -1.0)
                        ctx.translateBy(x: -quoteRect.midX, y: -quoteRect.midY)
                        ctx.clip(to: quoteRect, mask: quoteIcon)
                        ctx.fill(quoteRect)
                        ctx.restoreGState()
                        ctx.resetClip()
                    }
                    
                    
                    let lineFrame = CGRect(origin: CGPoint(x: blockFrame.minX, y: blockFrame.minY), size: CGSize(width: lineWidth, height: blockFrame.height))
                    ctx.move(to: CGPoint(x: lineFrame.minX, y: lineFrame.minY + radius))
                    ctx.addArc(tangent1End: CGPoint(x: lineFrame.minX, y: lineFrame.minY), tangent2End: CGPoint(x: lineFrame.minX + radius, y: lineFrame.minY), radius: radius)
                    ctx.addLine(to: CGPoint(x: lineFrame.minX + radius, y: lineFrame.maxY))
                    ctx.addArc(tangent1End: CGPoint(x: lineFrame.minX, y: lineFrame.maxY), tangent2End: CGPoint(x: lineFrame.minX, y: lineFrame.maxY - radius), radius: radius)
                    ctx.closePath()
                    ctx.clip()
                    
                   
                    
                    if let secondaryTintColor = secondaryTintColor {
                        let isMonochrome = secondaryTintColor.alpha == 0.2

                        do {
                            ctx.saveGState()
                            
                            let dashHeight: CGFloat = tertiaryTintColor != nil ? 6.0 : 9.0
                            let dashOffset: CGFloat
                            if let _ = tertiaryTintColor {
                                dashOffset = isMonochrome ? -2.0 : 0.0
                            } else {
                                dashOffset = isMonochrome ? -4.0 : 5.0
                            }
                        
                            if isMonochrome {
                                ctx.setFillColor(tintColor.withMultipliedAlpha(0.2).cgColor)
                                ctx.fill(lineFrame)
                                ctx.setFillColor(tintColor.cgColor)
                            } else {
                                ctx.setFillColor(tintColor.cgColor)
                                ctx.fill(lineFrame)
                                ctx.setFillColor(secondaryTintColor.cgColor)
                            }
                            
                            func drawDashes() {
                                ctx.translateBy(x: blockFrame.minX, y: blockFrame.minY + dashOffset)
                                
                                var offset = 0.0
                                while offset < blockFrame.height {
                                    ctx.move(to: CGPoint(x: 0.0, y: 3.0))
                                    ctx.addLine(to: CGPoint(x: lineWidth, y: 0.0))
                                    ctx.addLine(to: CGPoint(x: lineWidth, y: dashHeight))
                                    ctx.addLine(to: CGPoint(x: 0.0, y: dashHeight + 3.0))
                                    ctx.closePath()
                                    ctx.fillPath()
                                    
                                    ctx.translateBy(x: 0.0, y: 18.0)
                                    offset += 18.0
                                }
                            }
                            
                            drawDashes()
                            ctx.restoreGState()
                            
                            if let tertiaryTintColor = tertiaryTintColor{
                                ctx.saveGState()
                                ctx.translateBy(x: 0.0, y: dashHeight)
                                if isMonochrome {
                                    ctx.setFillColor(tintColor.withAlphaComponent(0.4).cgColor)
                                } else {
                                    ctx.setFillColor(tertiaryTintColor.cgColor)
                                }
                                drawDashes()
                                ctx.restoreGState()
                            }
                        }
                    } else {
                        ctx.setFillColor(tintColor.cgColor)
                        ctx.fill(lineFrame)
                    }
                    
                    ctx.resetClip()
                    
                    if let header = blockQuote.header {
                        
                        let headerHeight = blockQuote.headerInset + 2
                        
                        ctx.setFillColor(blockQuote.colors.main.withAlphaComponent(0.2).cgColor)
                        let rect = NSMakeRect(blockFrame.minX, blockFrame.minY, blockFrame.width, headerHeight)
                        blockHeaderRects.append((rect, blockQuote.range))
                        ctx.drawRoundedRect(rect: rect, topLeftRadius: radius, topRightRadius: radius)

                        header.1.draw(CGRect(x: blockFrame.minX + 8, y: blockFrame.minY + (headerHeight - header.0.size.height) / 2 - 1, width: header.0.size.width, height: header.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: .clear)
                        if let image = NSImage(named: "Icon_CopyCode")?.precomposed(blockQuote.colors.main, flipVertical: true) {
                            ctx.draw(image, in: CGRect(origin: NSMakePoint(blockFrame.width - image.backingSize.width - 3, blockFrame.minY + (headerHeight - image.backingSize.height) / 2), size: image.backingSize))
                        }
                    }
                }
            }
            
            
            
            
            let spoilerRects = layout.spoilerRects(!inAnimation).map { $0.0 }
            if !spoilerRects.isEmpty {
                ctx.beginPath()
                ctx.addRects(spoilerRects)
                ctx.closePath()
                ctx.addRect(CGRect(x: 0, y: 0, width: layer.frame.width, height: layer.frame.height))
                ctx.clip(using: .evenOdd)
            }
            
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
                
                var penOffset = CGFloat( CTLineGetPenOffsetForFlush(line.line, line.penFlush, Double(frame.width)))
                if layout.penFlush == 0.5, line.penFlush != 0.5 {
                    penOffset = startPosition.x
                }
                if line.penFlush == 1.0 {
                    if let size = layout.cutout?.topRight {
                        if line.frame.maxY <= size.height {
                            penOffset -= size.width
                        }
                    }
                }
                
                var additionY: CGFloat = 0
                if layout.isBigEmoji {
                    additionY -= 4
                }
                
                let insideBlock = layout.blockQuotes.first(where: { block in
                    if block.frame.contains(line.frame.origin) {
                        return true
                    } else {
                        return false
                    }
                })
                if let _ = insideBlock, line.isRTL {
                    penOffset -= 20 + 4 * 2
                }
                                
//                if line.isRTL {
//                    if let _ = insideBlock {
//                        rect.origin.x -= 4 * 2 * 2
//                    }
//                }
                
                let textPosition = CGPoint(x: penOffset + line.frame.minX, y: startPosition.y + line.frame.minY + additionY)
                
                let glyphRuns = CTLineGetGlyphRuns(line.line) as NSArray
                if glyphRuns.count != 0 {
                    for run in glyphRuns {
                        let run = run as! CTRun
                        let glyphCount = CTRunGetGlyphCount(run)
                        let range = CTRunGetStringRange(run)
                                                
//                        let under = layout.embeddedItems.contains(where: { value in
//                            return value.range.intersection(NSMakeRange(range.location, range.length)) != nil
//                        })
                        
                        
                        ctx.textPosition = textPosition
                        
                     //   if !under {
                            CTRunDraw(run, ctx, CFRangeMake(0, glyphCount))
                      //  }
                    }
                }
                for strikethrough in line.strikethrough {
                    ctx.setFillColor(strikethrough.color.cgColor)
                    ctx.fill(NSMakeRect(strikethrough.frame.minX, line.frame.minY - line.frame.height / 2 + 2, strikethrough.frame.width, .borderSize))
                }
                
            }
//            for spoiler in layout.spoilerRects(!inAnimation) {
//                ctx.clear(spoiler)
//            }
            
        }
        self.blockHeaderRects = blockHeaderRects
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
                        
                        if resolved == nil, let window = self?._window {
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
                setNeedsDisplayLayer()
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
    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        self.drawLayer.contentsScale = backingScaleFactor
        self.embeddedContainer.contentsScale = backingScaleFactor
        setNeedsDisplayLayer()
    }

    //
    
    private func updateInks(_ layout: TextViewLayout?, animated: Bool = false) {
        if let layout = layout {
            let spoilers = layout.spoilers
            let rects = layout.spoilerRects().map { $0.0 }
            while rects.count > self.inkViews.count {
                let inkView = InvisibleInkDustView()
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
        self.selectionWasCleared = false
    }
    
    public func update(_ layout:TextViewLayout?, origin:NSPoint? = nil, transition: ContainedViewLayoutTransition = .immediate) -> Void {
        
        if let current = self.textLayout, current.attributedString.string == layout?.attributedString.string {
            if layout?.selectedRange.range == NSMakeRange(NSNotFound, 0) {
                layout?.selectedRange = current.selectedRange
            }
        } else {
            self.animatedView?.removeFromSuperlayer()
            self.animatedView = nil
        }
        
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
            let rect = NSMakeRect(point.x, point.y, layout.layoutSize.width + layout.insets.width, layout.layoutSize.height + layout.insets.height)
            transition.updateFrame(view: self, frame: rect)
            
            removeAllToolTips()
            for rect in layout.toolTipRects {
                addToolTip(rect, owner: self, userData: nil)
            }
            
        } else {
            self.set(selectedRange: NSMakeRange(NSNotFound, 0), display: false)
            transition.updateFrame(view: self, frame: NSZeroRect)

        }
        
       

        updateBackgroundBlur()

        self.setNeedsDisplayLayer()
    }
    
    public func set(layout:TextViewLayout?) {
        self.textLayout = layout
        self.setNeedsDisplayLayer()
    }
    
    public override func setNeedsDisplayLayer() {
        self.layer?.setNeedsDisplay()
        self.drawingLayer.setNeedsDisplay()
       // self.drawLayer.displayIfNeeded()
    }
    
    public override func setNeedsDisplay() {
        self.layer?.setNeedsDisplay()
        self.drawingLayer.setNeedsDisplay()
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
        if let layout = textLayout, userInteractionEnabled {
            let point = self.convert(event.locationInWindow, from: nil)
            let index = layout.findIndex(location: point)
            if point.x > layout.lines[index].frame.maxX, isSelectable {
                superview?.mouseDown(with: event)
                if sendDownAnyway {
                    super.mouseDown(with: event)
                }
            } else {
                _mouseDown(with: event)
            }
        } else if !userInteractionEnabled {
            _mouseDown(with: event)
        }
        
        selectionWasCleared = false
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
        setNeedsDisplayLayer()
    }
    
    @objc open func windowDidResignKey() {
        setNeedsDisplayLayer()
    }
    
    private var locationInWindow:NSPoint? = nil
    
    public var sendDownAnyway: Bool = false
    
    func _mouseDown(with event: NSEvent) -> Void {
        
        self.locationInWindow = event.locationInWindow
        
        if !isSelectable || !userInteractionEnabled || event.modifierFlags.contains(.shift) {
            super.mouseDown(with: event)
            return
        } else if sendDownAnyway {
            super.mouseDown(with: event)
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
            layout.selectedRange.range = layout.selectedRange(startPoint: beginSelect, currentPoint: endSelect, byWord: event.clickCount == 2)
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
        
        if let layout = textLayout, userInteractionEnabled, let window = _window {
            let point = self.convert(event.locationInWindow, from: nil)
            if let _ = layout.spoiler(at: point) {
                layout.revealSpoiler()
                setNeedsDisplayLayer()
                self.updateInks(layout, animated: true)
                return
            }
            if let blockHeader = blockHeaderRects.first(where: { $0.0.contains(point) }) {
                var quoteRange = blockHeader.1
                
                for i in blockHeader.1.max ..< layout.attributedString.length {
                    let value = layout.attributedString.attribute(TextInputAttributes.quote, at: i, effectiveRange: nil)
                    if value != nil {
                        quoteRange.length += 1
                    } else {
                        break
                    }
                }
                
                
                let string = layout.attributedString.attributedSubstring(from: quoteRange)
                _ = layout.interactions.copyToClipboard?(string.string)
                showModalText(for: window, text: localizedString("Share.Link.Copied"))
            } else if event.clickCount == 3, isSelectable {
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
                    if layout.findCharacterIndex(at: point) == -1, onlyTextIsInteractive {
                        moveNextEventDeep = true
                    }
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
            setNeedsDisplayLayer()
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
            let inBlockHeader = blockHeaderRects.contains(where: { $0.0.contains(location) })
            if inBlockHeader {
                NSCursor.pointingHand.set()
            } else if textLayout?.spoiler(at: location) != nil {
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
        
        if lockDrawingLayer {
            return
        }
        
        self.layer?.masksToBounds = blurBackground != nil
        if let blurBackground = blurBackground {

            if self.visualEffect == nil {
                self.visualEffect = VisualEffect(frame: self.bounds)
                addSubview(self.visualEffect!, positioned: .below, relativeTo: nil)
                if let textView = self.textView {
                    self.visualEffect?.addSubview(textView)
                } else {
                    self.visualEffect?.layer?.addSublayer(drawLayer)
                }
                self.visualEffect?.layer?.addSublayer(embeddedContainer)
            }
            self.visualEffect?.bgColor = blurBackground
            
            
            if let textlayout = self.textLayout, let blockImage = textlayout.blockImage.1 {
                if blockMask == nil {
                    blockMask = SimpleLayer()
                }
                var fr = CATransform3DIdentity
                fr = CATransform3DTranslate(fr, blockImage.backingSize.width / 2, 0, 0)
                fr = CATransform3DScale(fr, 1, -1, 1)
                fr = CATransform3DTranslate(fr, -(blockImage.backingSize.width / 2), 0, 0)
                
                blockMask?.transform = fr
                blockMask?.contentsScale = backingScaleFactor
                blockMask?.contents = blockImage
                blockMask?.frame = CGRect(origin: .zero, size: blockImage.backingSize)
                self.layer?.mask = blockMask
            } else {
                self.blockMask = nil
                self.layer?.mask = nil
            }
        }  else {
            if let textView = textView {
                self.addSubview(textView, positioned: .below, relativeTo: nil)
            } else {
                if let animatedView = animatedView, animatedView.superlayer != nil {
                    self.layer?.insertSublayer(drawLayer, at: 1)
                } else {
                    self.layer?.insertSublayer(drawLayer, at: 0)
                }
            }
            self.layer?.insertSublayer(embeddedContainer, at: 1)
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
            setNeedsDisplayLayer()
        }
    }
    

    public func addEmbeddedLayer(_ layer: CALayer) {
        embeddedContainer.addSublayer(layer)
    }
    
    public override func layout() {
        super.layout()
        self.visualEffect?.frame = bounds
        self.textView?.frame = bounds
        self.embeddedContainer.frame = bounds
        self.drawLayer.frame = bounds
        self.drawLayer.bounds = bounds.insetBy(dx: -2, dy: -3)
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
            let rects = layout.spoilerRects().map { $0.0 }
            let sublayers = embeddedContainer.sublayers ?? []
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
    
    private var animatedView: SimpleLayer?
    
    public func highlight(text: String, color: NSColor) {
        guard let textLayout = self.textLayout else {
            return
        }
        
        
        self.animatedView?.removeFromSuperlayer()
        
        let range = textLayout.attributedString.string.nsstring.range(of: text)
        if range.location != NSNotFound {
            let image = textLayout.generateBlock(for: range, backgroundColor: color)
            
            let imageView = SimpleLayer(frame: CGRect(origin: image.0, size: image.1!.backingSize))
            imageView.contents = image.1
            imageView.opacity = 0.5
            
            self.layer?.insertSublayer(imageView, at: 0)
            
            self.animatedView = imageView
            
            _ = delaySignal(3.0).start(completed: { [weak self] in
                if let view = self?.animatedView {
                    performSublayerRemoval(view, animated: true)
                    self?.animatedView = nil
                }
            })
            
        }
    }
}


public extension TextView {
    func setIsShimmering(_ value: Bool, animated: Bool) {
        if value, let blockImage = textLayout?.maskBlockImage.1 {
            let size = blockImage.size
            let current: ShimmerView
            if let view = self.shimmerEffect {
                current = view
            } else {
                current = ShimmerView()
                self.shimmerEffect = current
                self.addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.update(backgroundColor: .blackTransparent, data: nil, size: size, imageSize: size)
            current.updateAbsoluteRect(size.bounds, within: size)
            
            let frame = self.bounds
            current.frame = blockImage.backingSize.bounds.offsetBy(dx: frame.minX - 5, dy: frame.minY - 1)
            
            if let blockImage = textLayout?.maskBlockImage.1 {
                if shimmerMask == nil {
                    shimmerMask = SimpleLayer()
                }
                var fr = CATransform3DIdentity
                fr = CATransform3DTranslate(fr, blockImage.backingSize.width / 2, 0, 0)
                fr = CATransform3DScale(fr, 1, -1, 1)
                fr = CATransform3DTranslate(fr, -(blockImage.backingSize.width / 2), 0, 0)
                
                shimmerMask?.transform = fr
                shimmerMask?.contentsScale = 2.0
                shimmerMask?.contents = blockImage
                shimmerMask?.frame = CGRect(origin: .zero, size: blockImage.backingSize)
                current.layer?.mask = shimmerMask
            } else {
                self.shimmerMask = nil
                current.layer?.mask = nil
            }
        } else {
            if let view = self.shimmerEffect {
                let shimmerMask = self.shimmerMask
                performSubviewRemoval(view, animated: animated, completed: { [weak shimmerMask] _ in
                    shimmerMask?.removeFromSuperlayer()
                })
                self.shimmerEffect = nil
                self.shimmerMask = nil
            }
        }
    }
    func reloadAnimation() {
        self.shimmerEffect?.reloadAnimation()
    }
}
