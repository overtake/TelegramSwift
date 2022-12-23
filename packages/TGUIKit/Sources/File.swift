//
//  File.swift
//  
//
//  Created by Mike Renoir on 20.12.2022.
//

import Foundation
import CoreText
import AppKit


private let defaultFont:NSFont = NSFont.systemFont(ofSize: 14)

extension NSAttributedString {
    var size: CGSize {
        return textSize(with: self.string, font: self.attribute(.font, at: 0, effectiveRange: nil) as? NSFont ?? defaultFont)
    }
}

private func textSize(with string: String, font: NSFont) -> CGSize {
    
    let attributedString:NSAttributedString = NSAttributedString(string: string, attributes: [.font : font])
    let layout = TextLabelNode.layoutText(attributedString, CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
    var size:CGSize = layout.0.size
    size.width = ceil(size.width)
    size.height = ceil(size.height)
    
    return size
}



private final class TextLabelNodeLine {
    let line: CTLine
    let frame: CGRect
    
    init(line: CTLine, frame: CGRect) {
        self.line = line
        self.frame = frame
    }
}


public final class TextLabelNodeLayout: NSObject {
    fileprivate let attributedString: NSAttributedString?
    fileprivate let truncationType: CTLineTruncationType
    fileprivate let constrainedSize: CGSize
    fileprivate let lines: [TextLabelNodeLine]
    
    let size: CGSize
    
    fileprivate init(attributedString: NSAttributedString?, truncationType: CTLineTruncationType, constrainedSize: CGSize, size: CGSize, lines: [TextLabelNodeLine]) {
        self.attributedString = attributedString
        self.truncationType = truncationType
        self.constrainedSize = constrainedSize
        self.size = size
        self.lines = lines
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

class TextLabelNode: NSObject {
    private var currentLayout: TextLabelNodeLayout?
    
    private class func getlayout(attributedString: NSAttributedString?, truncationType: CTLineTruncationType, constrainedSize: CGSize) -> TextLabelNodeLayout {
        
        if let attributedString = attributedString {
            let font: CTFont
            if attributedString.length != 0 {
                if let stringFont = attributedString.attribute(NSAttributedString.Key(kCTFontAttributeName as String), at: 0, effectiveRange: nil) {
                    font = stringFont as! CTFont
                } else if let f = attributedString.attribute(.font, at: 0, effectiveRange: nil) as? NSFont {
                    font = f
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
            
            var lines: [TextLabelNodeLine] = []
            
            
            
            var maybeTypesetter: CTTypesetter?
            maybeTypesetter = CTTypesetterCreateWithAttributedString(attributedString as CFAttributedString)
            if maybeTypesetter == nil {
                return TextLabelNodeLayout(attributedString: attributedString, truncationType: truncationType, constrainedSize: constrainedSize, size: CGSize(), lines: [])
            }
            
            let typesetter = maybeTypesetter!
            var layoutSize = CGSize()

            let lineOriginY = floor(layoutSize.height + fontLineHeight - fontLineSpacing * 2.0)

            let lastLineCharacterIndex: CFIndex = 0
            
            let coreTextLine: CTLine
            
            let originalLine = CTTypesetterCreateLineWithOffset(typesetter, CFRange(location: lastLineCharacterIndex, length: attributedString.length - lastLineCharacterIndex), 0.0)
            
            if CTLineGetTypographicBounds(originalLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(originalLine) < Double(constrainedSize.width) {
                coreTextLine = originalLine
            } else {
                var truncationTokenAttributes: [NSAttributedString.Key : Any] = [:]
                truncationTokenAttributes[NSAttributedString.Key(kCTFontAttributeName as String)] = font
                truncationTokenAttributes[NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String)] = true as NSNumber
                let tokenString = "\u{2026}"
                let truncatedTokenString = NSAttributedString(string: tokenString, attributes: truncationTokenAttributes)
                let truncationToken = CTLineCreateWithAttributedString(truncatedTokenString)
                
                coreTextLine = CTLineCreateTruncatedLine(originalLine, Double(constrainedSize.width), truncationType, truncationToken) ?? truncationToken
                
            }
            
            let lineWidth = ceil(CGFloat(CTLineGetTypographicBounds(coreTextLine, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(coreTextLine)))
            let lineFrame = CGRect(x: 0, y: lineOriginY, width: lineWidth, height: fontLineHeight)
            layoutSize.height += fontLineHeight + fontLineSpacing
            layoutSize.width = max(layoutSize.width, lineWidth)
            
            lines.append(TextLabelNodeLine(line: coreTextLine, frame: lineFrame))
            
            return TextLabelNodeLayout(attributedString: attributedString, truncationType: truncationType, constrainedSize: constrainedSize, size: CGSize(width: ceil(layoutSize.width), height: ceil(layoutSize.height)), lines: lines)
        } else {
            return TextLabelNodeLayout(attributedString: attributedString, truncationType: truncationType, constrainedSize: constrainedSize, size: CGSize(), lines: [])
        }
    }
    
    
    func draw(_ dirtyRect: CGRect, in ctx: CGContext, backingScaleFactor: CGFloat) {
        
        ctx.saveGState()
        
        ctx.setAllowsFontSubpixelPositioning(true)
        ctx.setShouldSubpixelPositionFonts(true)
        
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        
        ctx.setAllowsFontSmoothing(backingScaleFactor == 1.0)
        ctx.setShouldSmoothFonts(backingScaleFactor == 1.0)
        
        let context:CGContext = ctx
        
        if let layout = self.currentLayout {
            let textMatrix = context.textMatrix
            let textPosition = context.textPosition
            context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
            for i in 0 ..< layout.lines.count {
                let line = layout.lines[i]
                context.textPosition = CGPoint(x: dirtyRect.minX, y: line.frame.origin.y + dirtyRect.minY)
                CTLineDraw(line.line, context)
            }
            
            context.textMatrix = textMatrix
            context.textPosition = CGPoint(x: textPosition.x, y: textPosition.y)
        }
        ctx.restoreGState()
    }
    
    
    
    class func layoutText(_ attributedString: NSAttributedString?, _ constrainedSize: CGSize, _ truncationType: CTLineTruncationType = .end) -> (TextLabelNodeLayout, TextLabelNode) {
        let layout: TextLabelNodeLayout
        layout = TextLabelNode.getlayout(attributedString: attributedString, truncationType: truncationType, constrainedSize: constrainedSize)
        let node = TextLabelNode()
        node.currentLayout = layout
        return (layout, node)
    }
}
