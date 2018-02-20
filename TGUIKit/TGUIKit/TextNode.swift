//
//  TextNode.swift
//  TGUIKit
//
//  Created by keepcoder on 10/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

private let defaultFont:NSFont = .normal(.text)

private final class TextNodeLine {
    let line: CTLine
    let frame: CGRect
    
    init(line: CTLine, frame: CGRect) {
        self.line = line
        self.frame = frame
    }
}

public enum TextNodeCutoutPosition {
    case TopLeft
    case TopRight
}

public struct TextNodeCutout: Equatable {
    public let position: TextNodeCutoutPosition
    public let size: NSSize
}

public func ==(lhs: TextNodeCutout, rhs: TextNodeCutout) -> Bool {
    return lhs.position == rhs.position && lhs.size == rhs.size
}

public final class TextNodeLayout: NSObject {
    fileprivate let attributedString: NSAttributedString?
    fileprivate let maximumNumberOfLines: Int
    fileprivate let truncationType: CTLineTruncationType
    fileprivate let backgroundColor: NSColor?
    fileprivate let constrainedSize: NSSize
    fileprivate let cutout: TextNodeCutout?
    fileprivate let alignment:NSTextAlignment
    public let isPerfectSized: Bool
    public let size: NSSize
    fileprivate let lines: [TextNodeLine]
    public var selected:Bool = false
    
    fileprivate init(attributedString: NSAttributedString?, maximumNumberOfLines: Int, truncationType: CTLineTruncationType, constrainedSize: NSSize, cutout: TextNodeCutout?, size: NSSize, lines: [TextNodeLine], backgroundColor: NSColor?, alignment:NSTextAlignment = .left, isPerfectSized: Bool) {
        self.attributedString = attributedString
        self.maximumNumberOfLines = maximumNumberOfLines
        self.truncationType = truncationType
        self.constrainedSize = constrainedSize
        self.cutout = cutout
        self.size = size
        self.lines = lines
        self.backgroundColor = backgroundColor
        self.alignment = alignment
        self.isPerfectSized = isPerfectSized
    }
    
    var numberOfLines: Int {
        return self.lines.count
    }
    
    var trailingLineWidth: CGFloat {
        if let lastLine = self.lines.last {
            return lastLine.frame.width
        } else {
            return 0.0
        }
    }
}

public class TextNode: NSObject {
    private var currentLayout: TextNodeLayout?
    public var backgroundColor:NSColor
    
    public override init() {
        self.backgroundColor = NSColor.red
        super.init()
    }
    
    
    private class func getlayout(attributedString: NSAttributedString?, maximumNumberOfLines: Int, truncationType: CTLineTruncationType, backgroundColor: NSColor?, constrainedSize: NSSize, cutout: TextNodeCutout?, selected:Bool, alignment:NSTextAlignment) -> TextNodeLayout {
        
        var attr = attributedString
        let isPerfectSized = false
        if let a = attr {
            if (selected && a.length > 0) {
                
                let c:NSMutableAttributedString = a.mutableCopy() as! NSMutableAttributedString
                
                if let color = c.attribute(.selectedColor, at: 0, effectiveRange: nil) {
                    c.addAttribute(NSAttributedStringKey.foregroundColor, value: color, range: c.range)
                }
                
                attr = c
                
            }

        }
        
        
        if let attributedString = attr {
            

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
            
            let fontAscent = CTFontGetAscent(font)
            let fontDescent = CTFontGetDescent(font)
            let fontLineHeight = floor(fontAscent + fontDescent)
            let fontLineSpacing = floor(fontLineHeight * 0.12)
            
            var lines: [TextNodeLine] = []
            
           
            
            var maybeTypesetter: CTTypesetter?
            maybeTypesetter = CTTypesetterCreateWithAttributedString(attributedString as CFAttributedString)
            if maybeTypesetter == nil {
                return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, cutout: cutout, size: NSSize(), lines: [], backgroundColor: backgroundColor, alignment:alignment, isPerfectSized: true)
            }
            
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
                        var truncationTokenAttributes: [NSAttributedStringKey : Any] = [:]
                        truncationTokenAttributes[NSAttributedStringKey(kCTFontAttributeName as String)] = font
                        truncationTokenAttributes[NSAttributedStringKey(kCTForegroundColorFromContextAttributeName as String)] = true as NSNumber
                        let tokenString = "\u{2026}"
                        let truncatedTokenString = NSAttributedString(string: tokenString, attributes: truncationTokenAttributes)
                        let truncationToken = CTLineCreateWithAttributedString(truncatedTokenString)
                        
                        coreTextLine = CTLineCreateTruncatedLine(originalLine, Double(constrainedSize.width), truncationType, truncationToken) ?? truncationToken
                        
                    }
                    
                    let lineWidth = ceil(CGFloat(CTLineGetTypographicBounds(coreTextLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(coreTextLine)))
                    let lineFrame = CGRect(x: lineCutoutOffset, y: lineOriginY, width: lineWidth, height: fontLineHeight)
                    layoutSize.height += fontLineHeight + fontLineSpacing
                    layoutSize.width = max(layoutSize.width, lineWidth + lineAdditionalWidth)
                    
                    lines.append(TextNodeLine(line: coreTextLine, frame: lineFrame))
                    
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
                        
                       
                        
                        lines.append(TextNodeLine(line: coreTextLine, frame: lineFrame))
                    } else {
                        if !lines.isEmpty {
                            layoutSize.height += fontLineSpacing
                        }
                        break
                    }
                }
            }
            
            return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, cutout: cutout, size: NSSize(width: ceil(layoutSize.width), height: ceil(layoutSize.height)), lines: lines, backgroundColor: backgroundColor, alignment:alignment, isPerfectSized: isPerfectSized)
        } else {
            return TextNodeLayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, constrainedSize: constrainedSize, cutout: cutout, size: NSSize(), lines: [], backgroundColor: backgroundColor, alignment:alignment, isPerfectSized: isPerfectSized)
        }
    }
    

    open func draw(_ dirtyRect: NSRect, in ctx: CGContext, backingScaleFactor: CGFloat, backgroundColor: NSColor) {
       
        
        if backingScaleFactor == 1.0 {
            ctx.setFillColor(backgroundColor.cgColor)
            ctx.fill(dirtyRect)
        }
        
        //let contextPtr = NSGraphicsContext.current()?.graphicsPort
        let context:CGContext = ctx //unsafeBitCast(contextPtr, to: CGContext.self)
        
        ctx.setAllowsAntialiasing(true)
        ctx.setAllowsFontSmoothing(backingScaleFactor == 1.0)
        ctx.setShouldSmoothFonts(backingScaleFactor == 1.0)
        

       // ctx.setAllowsFontSmoothing(true)
       // ctx.setAllowsAntialiasing(true)
//        context.setAllowsAntialiasing(true)
//        context.setShouldSmoothFonts(!System.isRetina)
//        context.setAllowsFontSmoothing(!System.isRetina)
        
        if #available(OSX 10.11, *) {
            
        } else {
            context.setBlendMode(.hardLight)
        }
        
        if let layout = self.currentLayout {
            let textMatrix = context.textMatrix
            let textPosition = context.textPosition
            context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
             for i in 0 ..< layout.lines.count {
                let line = layout.lines[i]
                
                var penFlush:CGFloat = 0.0
                if layout.alignment == .center {
                    penFlush = 0.5
                }
                
                let penOffset = CGFloat( CTLineGetPenOffsetForFlush(line.line, penFlush, Double(dirtyRect.width)))

                
                context.textPosition = CGPoint(x: penOffset + NSMinX(dirtyRect), y: line.frame.origin.y + NSMinY(dirtyRect))
                
               
                
                CTLineDraw(line.line, context)
                
            }
            
            context.textMatrix = textMatrix
            context.textPosition = CGPoint(x: textPosition.x, y: textPosition.y)
        }
        
      //  context.setBlendMode(.normal)
    }
    

    
    open class func layoutText(maybeNode:TextNode? = nil, _ attributedString: NSAttributedString?, _ backgroundColor: NSColor?, _ maximumNumberOfLines: Int, _ truncationType: CTLineTruncationType, _ constrainedSize: NSSize, _ cutout: TextNodeCutout?,_ selected:Bool, _ alignment:NSTextAlignment) -> (TextNodeLayout, TextNode) {
        
        let existingLayout: TextNodeLayout? = maybeNode?.currentLayout
        
        let layout: TextNodeLayout
        
        if let existingLayout = existingLayout, existingLayout.constrainedSize == constrainedSize && existingLayout.maximumNumberOfLines == maximumNumberOfLines && existingLayout.truncationType == truncationType && existingLayout.cutout == cutout && existingLayout.selected == selected && existingLayout.alignment == alignment {
            let stringMatch: Bool
            if let existingString = existingLayout.attributedString, let string = attributedString {
                stringMatch = existingString.isEqual(to: string)
            } else if existingLayout.attributedString == nil && attributedString == nil {
                stringMatch = true
            } else {
                stringMatch = false
            }
            
            if stringMatch {
                layout = existingLayout
            } else {
                layout = TextNode.getlayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, backgroundColor: backgroundColor, constrainedSize: constrainedSize, cutout: cutout,selected:selected, alignment:alignment)
            }
        } else {
            layout = TextNode.getlayout(attributedString: attributedString, maximumNumberOfLines: maximumNumberOfLines, truncationType: truncationType, backgroundColor: backgroundColor, constrainedSize: constrainedSize, cutout: cutout,selected:selected, alignment:alignment)
        }
        
        let node = maybeNode ?? TextNode()
        node.currentLayout = layout
        return (layout, node)
    }
}
