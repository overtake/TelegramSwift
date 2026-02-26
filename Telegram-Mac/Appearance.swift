//
//  Appearance.swift
//  Telegram
//
//  Created by keepcoder on 22/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import InAppSettings
import SwiftSignalKit
import Postbox
import TelegramIconsTheme
import GZIP
import Svg
import ColorPalette
import ThemeSettings
#if !SHARE
import InputView
import CodeSyntax
#endif

let premiumGradient = [NSColor(rgb: 0x6B93FF), NSColor(rgb: 0x976FFF), NSColor(rgb: 0xE46ACE)]


func generateContextMenuInstantView(color: NSColor, size: NSSize = NSMakeSize(20, 20)) -> NSImage {
    let icon = NSImage(resource: .iconInstantViewFavicon).precomposed(theme.colors.darkGrayText, flipVertical: true)
    return generateImage(size, rotatedContext: { size, ctx in
        ctx.clear(size.bounds)
        ctx.round(size, 4)
        ctx.setFillColor(color.cgColor)
        ctx.fill(size.bounds)
        
        ctx.draw(icon, in: size.bounds.focus(icon.backingSize))
    }).flatMap {
        NSImage(cgImage: $0, size: size)
    }!
}

#if !SHARE
func generateContextMenuUrl(color: NSColor, state: WebpageModalState?, size: NSSize = NSMakeSize(20, 20)) -> NSImage {
    
    let text: String
    if state?.error != nil {
        text = "!"
    } else if let url = state?.url, let parsedUrl = URL(string: url) {
        text = parsedUrl.host?.first.flatMap(String.init) ?? "!"
    } else {
        text = "!"
    }
    
    let textNode = TextNode.layoutText(.initialize(string: text.uppercased(), color: theme.colors.darkGrayText, font: .medium(.text)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .center)
    
    return generateImage(size, rotatedContext: { size, ctx in
        ctx.clear(size.bounds)
        ctx.round(size, 4)
        ctx.setFillColor(color.cgColor)
        ctx.fill(size.bounds)
        
        textNode.1.draw(size.bounds.focus(textNode.0.size), in: ctx, backingScaleFactor: System.backingScale, backgroundColor: .clear)
    }).flatMap {
        NSImage(cgImage: $0, size: size)
    }!
}
#endif

func generateContextMenuSubsCount(_ count: Int32?) -> CGImage? {
    
    guard let count else {
        return nil
    }
    
    let presentation = AppMenu.Presentation.current(theme.colors)
    let membersImage = NSImage(resource: .iconMiniAppMembers).precomposed(presentation.disabledTextColor, flipVertical: true)

    let textNode = TextNode.layoutText(.initialize(string: Int64(count).prettyNumber, color: presentation.disabledTextColor, font: .normal(.text)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .center)
    var size = textNode.0.size
    size.width += membersImage.backingSize.width
    return generateImage(size, rotatedContext: { size, ctx in
        ctx.clear(size.bounds)
        ctx.draw(membersImage, in: size.bounds.focusY(membersImage.backingSize, x: 0))
        textNode.1.draw(size.bounds.focusY(textNode.0.size, x: membersImage.backingSize.width), in: ctx, backingScaleFactor: System.backingScale, backgroundColor: .clear)
    })
}

func generalPrepaidGiveawayIcon(_ bgColor: NSColor, count: NSAttributedString) -> CGImage {
    let layout = TextNode.layoutText(count, nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .center)
    let image = NSImage(resource: .iconBoostPrepaid).precomposed(bgColor, flipVertical: true)

    return generateImage(NSMakeSize(layout.0.size.width + 10 + image.backingSize.width + 5, 24), rotatedContext: { size, ctx in
        ctx.clear(size.bounds)
        ctx.round(size, size.height / 2)
        ctx.setFillColor(bgColor.withAlphaComponent(0.2).cgColor)
        ctx.fill(size.bounds)
        
        var rect = size.bounds.focus(layout.0.size)
        rect.origin.x = size.width - rect.size.width - 5
        layout.1.draw(rect, in: ctx, backingScaleFactor: 2, backgroundColor: .clear)
        
        var imageRect = size.bounds.focus(image.backingSize)
        imageRect.origin.x = 5
        ctx.draw(image, in: imageRect)
    })!
}


func generalSendPaidMessage(bgColor: NSColor, outerColor: NSColor, imageColor: NSColor, count: NSAttributedString) -> CGImage {
    let layout = TextNode.layoutText(count, nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .center)
    let image = NSImage(resource: .starSmall).precomposed(imageColor, flipVertical: true)

    return generateImage(NSMakeSize(layout.0.size.width + 8 + image.backingSize.width, 18), rotatedContext: { size, ctx in
        ctx.clear(size.bounds)
        ctx.round(size, size.height / 2)
        
        ctx.setFillColor(outerColor.cgColor)
        ctx.fill(size.bounds)
        
        let path = CGMutablePath()
        let inner = size.bounds.insetBy(dx: 1, dy: 1)
        path.addRoundedRect(in: inner, cornerWidth: inner.height / 2, cornerHeight: inner.height / 2)
        ctx.addPath(path)
        ctx.setFillColor(bgColor.cgColor)
        ctx.fillPath()

        var rect = size.bounds.focus(layout.0.size)
        rect.origin.x = size.width - rect.size.width - 4
        layout.1.draw(rect, in: ctx, backingScaleFactor: 2, backgroundColor: .clear)
        
        var imageRect = size.bounds.focus(image.backingSize)
        imageRect.origin.x = 3
        ctx.draw(image, in: imageRect)
    })!
}


func generateGiftBadgeBackground(background: CGImage, text: String, textColor: NSColor = NSColor.white) -> CGImage {
    
    let textNode = TextNode.layoutText(.initialize(string: text, color: textColor, font: .bold(.small)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .center)

    let textImage = generateImage(background.systemSize, rotatedContext: { size, ctx in
        ctx.clear(CGRect(origin: .zero, size: size))

        ctx.saveGState()
        ctx.translateBy(x: size.width / 2, y: size.height / 2)
        ctx.rotate(by: CGFloat.pi / 4)
        ctx.translateBy(x: -size.width / 2, y: -size.height / 2)
        //-9
        textNode.1.draw(size.bounds.focus(textNode.0.size).offsetBy(dx: 0, dy: -10), in: ctx, backingScaleFactor: System.backingScale, backgroundColor: .clear)

        ctx.restoreGState()

    })!
    
    return generateImage(background.systemSize, contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: .zero, size: size))
        ctx.draw(background, in: size.bounds)
        ctx.draw(textImage, in: size.bounds)
    })!
}


#if !SHARE
public func generateDisclosureActionBoostLevelBadgeImage(text: String) -> CGImage {
    let attributedText = NSAttributedString(string: text, attributes: [
        .font: NSFont.medium(12.0),
        .foregroundColor: NSColor.white
    ])
    let bounds = attributedText.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
    let leftInset: CGFloat = 16.0
    let rightInset: CGFloat = 4.0
    let size = CGSize(width: leftInset + rightInset + ceil(bounds.width), height: 20.0)
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        let path = CGMutablePath()
        path.addRoundedRect(in: CGRect(origin: CGPoint(), size: size), cornerWidth: 4, cornerHeight: 4)
        context.addPath(path)
        context.clip()
        
        var locations: [CGFloat] = [0.0, 1.0]
        let colors: [CGColor] = [NSColor(rgb: 0x9076FF).cgColor, NSColor(rgb: 0xB86DEA).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
        
        context.resetClip()
        
        let image = NSImage(named: "Icon_EmojiLock")?.precomposed(flipVertical: true)
        
        if let image = generateTintedImage(image: image, color: .white) {
            let imageFit: CGFloat = 14.0
            let imageSize = image.size.aspectFitted(CGSize(width: imageFit, height: imageFit))
            let imageRect = CGRect(origin: CGPoint(x: 2.0, y: floorToScreenPixels((size.height - imageSize.height) * 0.5)), size: imageSize)
            context.draw(image, in: imageRect)
        }
        
        let layout = TextViewLayout(attributedText, maximumNumberOfLines: 1, truncationType: .middle)
        layout.measure(width: size.width)
        let line = layout.lines[0]
        
        context.textMatrix = CGAffineTransform(scaleX: 1.0, y: 1.0)
        context.textPosition = CGPoint(x: leftInset, y: floorToScreenPixels((size.height - bounds.height) * 0.5) + 4.0)
        CTLineDraw(line.line, context)
        
    })!
}
#endif

public enum GradientImageDirection {
    case vertical
    case horizontal
    case diagonal
    case mirroredDiagonal
}


func generateGradientTintedImage(image: CGImage?, colors: [NSColor], direction: GradientImageDirection = .vertical) -> CGImage? {
    guard let image = image else {
        return nil
    }
    
    let imageSize = image.systemSize
    
    return generateImage(imageSize, rotatedContext: { size, context in
        context.clear(size.bounds)
        
        let imageRect = CGRect(origin: CGPoint(), size: imageSize)
        context.saveGState()
        context.translateBy(x: imageRect.midX, y: imageRect.midY)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
        context.clip(to: imageRect, mask: image)

        if colors.count >= 2 {
            let gradientColors = colors.map { $0.cgColor } as CFArray

            var locations: [CGFloat] = []
            for i in 0 ..< colors.count {
                let t = CGFloat(i) / CGFloat(colors.count - 1)
                locations.append(t)
            }
            let colorSpace = DeviceGraphicsContextSettings.shared.colorSpace
            let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!

            let start: CGPoint
            let end: CGPoint
            switch direction {
            case .horizontal:
                start = .zero
                end = CGPoint(x: imageRect.width, y: 0.0)
            case .vertical:
                start = CGPoint(x: 0.0, y: imageRect.height)
                end = .zero
            case .diagonal:
                start = CGPoint(x: 0.0, y: 0.0)
                end = CGPoint(x: imageRect.width, y: imageRect.height)
            case .mirroredDiagonal:
                start = CGPoint(x: imageRect.width, y: 0.0)
                end = CGPoint(x: 0.0, y: imageRect.height)
            }
            
            context.drawLinearGradient(gradient, start: start, end: end, options: CGGradientDrawingOptions())
        } else if !colors.isEmpty {
            context.setFillColor(colors[0].cgColor)
            context.fill(imageRect)
        }
        
        context.restoreGState()
            
    })

}




private func generateAvatarStarBadge(color: NSColor) -> CGImage {
    let image = NSImage(resource: .iconStarCurrency).precomposed()
    let bigImage = NSImage(resource: .iconStarOutline).precomposed()
    return generateImage(bigImage.systemSize, contextGenerator: { size, ctx in
        ctx.clear(size.bounds)
        
        
        ctx.clip(to: size.bounds, mask: bigImage)
        ctx.clear(size.bounds)
        
        ctx.setFillColor(color.cgColor)
        ctx.fill(size.bounds)

        ctx.draw(image, in: size.bounds.focus(image.backingSize))
    })!
}

private func generateAvatarStarBadgeLarge(color: NSColor) -> CGImage {
    let image = NSImage(resource: .iconStarCurrencyBigSize).precomposed()
    let bigImage = NSImage(resource: .iconStarOutlineBigSize).precomposed()
    return generateImage(bigImage.backingSize, contextGenerator: { size, ctx in
        ctx.clear(size.bounds)
        
        
        ctx.clip(to: size.bounds, mask: bigImage)
        ctx.clear(size.bounds)
        
        ctx.setFillColor(color.cgColor)
        ctx.fill(size.bounds)

        ctx.draw(image, in: size.bounds.focus(image.backingSize))
    })!
}



func generateRoundedRectWithTailPath(rectSize: CGSize, cornerRadius: CGFloat? = nil, tailSize: CGSize = CGSize(width: 20.0, height: 9.0), tailRadius: CGFloat = 4.0, tailPosition: CGFloat? = 0.5, transformTail: Bool = true) -> NSBezierPath {
    let cornerRadius: CGFloat = cornerRadius ?? rectSize.height / 2.0
    let tailWidth: CGFloat = tailSize.width
    let tailHeight: CGFloat = tailSize.height

    let rect = CGRect(origin: CGPoint(x: 0.0, y: tailHeight), size: rectSize)
    
    guard let tailPosition else {
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        return path
    }

    let cutoff: CGFloat = 0.27
    
    let path = NSBezierPath()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))

    var leftArcEndAngle: CGFloat = .pi / 2.0
    var leftConnectionArcRadius = tailRadius
    var tailLeftHalfWidth: CGFloat = tailWidth / 2.0
    var tailLeftArcStartAngle: CGFloat = -.pi / 4.0
    var tailLeftHalfRadius = tailRadius
    
    var rightArcStartAngle: CGFloat = -.pi / 2.0
    var rightConnectionArcRadius = tailRadius
    var tailRightHalfWidth: CGFloat = tailWidth / 2.0
    var tailRightArcStartAngle: CGFloat = .pi / 4.0
    var tailRightHalfRadius = tailRadius
    
    if transformTail {
        if tailPosition < 0.5 {
            let fraction = max(0.0, tailPosition - 0.15) / 0.35
            leftArcEndAngle *= fraction
            
            let connectionFraction = max(0.0, tailPosition - 0.35) / 0.15
            leftConnectionArcRadius *= connectionFraction
            
            if tailPosition < cutoff {
                let fraction = tailPosition / cutoff
                tailLeftHalfWidth *= fraction
                tailLeftArcStartAngle *= fraction
                tailLeftHalfRadius *= fraction
            }
        } else if tailPosition > 0.5 {
            let tailPosition = 1.0 - tailPosition
            let fraction = max(0.0, tailPosition - 0.15) / 0.35
            rightArcStartAngle *= fraction
            
            let connectionFraction = max(0.0, tailPosition - 0.35) / 0.15
            rightConnectionArcRadius *= connectionFraction
            
            if tailPosition < cutoff {
                let fraction = tailPosition / cutoff
                tailRightHalfWidth *= fraction
                tailRightArcStartAngle *= fraction
                tailRightHalfRadius *= fraction
            }
        }
    }
    
    path.appendArc(withCenter: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                   radius: cornerRadius,
                   startAngle: 180,
                   endAngle: 180 + max(0.0001, leftArcEndAngle * 180 / .pi),
                   clockwise: false)

    let leftArrowStart = max(rect.minX, rect.minX + rectSize.width * tailPosition - tailLeftHalfWidth - leftConnectionArcRadius)
    path.appendArc(withCenter: CGPoint(x: leftArrowStart, y: rect.minY - leftConnectionArcRadius),
                   radius: leftConnectionArcRadius,
                   startAngle: 90,
                   endAngle: 45,
                   clockwise: true)

    path.line(to: CGPoint(x: max(rect.minX, rect.minX + rectSize.width * tailPosition - tailLeftHalfRadius), y: rect.minY - tailHeight))

    path.appendArc(withCenter: CGPoint(x: rect.minX + rectSize.width * tailPosition, y: rect.minY - tailHeight + tailRadius / 2.0),
                   radius: tailRadius,
                   startAngle: -90 + tailLeftArcStartAngle * 180 / .pi,
                   endAngle: -90 + tailRightArcStartAngle * 180 / .pi,
                   clockwise: false)
    
    path.line(to: CGPoint(x: min(rect.maxX, rect.minX + rectSize.width * tailPosition + tailRightHalfRadius), y: rect.minY - tailHeight))

    let rightArrowStart = min(rect.maxX, rect.minX + rectSize.width * tailPosition + tailRightHalfWidth + rightConnectionArcRadius)
    path.appendArc(withCenter: CGPoint(x: rightArrowStart, y: rect.minY - rightConnectionArcRadius),
                   radius: rightConnectionArcRadius,
                   startAngle: 180 - 45,
                   endAngle: 90,
                   clockwise: true)

    path.appendArc(withCenter: CGPoint(x: rect.minX + rectSize.width - cornerRadius, y: rect.minY + cornerRadius),
                   radius: cornerRadius,
                   startAngle: min(-0.0001, rightArcStartAngle * 180 / .pi),
                   endAngle: 0,
                   clockwise: false)

    path.line(to: CGPoint(x: rect.minX + rectSize.width, y: rect.minY + rectSize.height - cornerRadius))

    path.appendArc(withCenter: CGPoint(x: rect.minX + rectSize.width - cornerRadius, y: rect.minY + rectSize.height - cornerRadius),
                   radius: cornerRadius,
                   startAngle: 0,
                   endAngle: 90,
                   clockwise: false)

    path.line(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + rectSize.height))

    path.appendArc(withCenter: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + rectSize.height - cornerRadius),
                   radius: cornerRadius,
                   startAngle: 90,
                   endAngle: 180,
                   clockwise: false)
    
    return path
}




func chatReplyLineDashTemplateImage(_ colors: PeerNameColors.Colors, flipped: Bool) -> CGImage? {
    let radius: CGFloat = 3.0
    var offset: CGFloat = 5.0
        

 
    let generator:(NSSize, CGContext) -> Void = { size, context in
        context.clear(size.bounds)
                        
        context.setFillColor(colors.main.cgColor)
        context.fill(size.bounds)
        
        if let color = colors.secondary {
            
            let path = CGMutablePath()
            path.move(to: CGPoint(x: size.width, y: offset))
            path.addLine(to: CGPoint(x: size.width, y: offset + radius * 3.0))
            path.addLine(to: CGPoint(x: 0.0, y: offset + radius * 4.0))
            path.addLine(to: CGPoint(x: 0.0, y: offset + radius))

            context.addPath(path)
            context.closePath()

            context.setBlendMode(.clear)
            context.fillPath()
            
            context.addPath(path)
            context.setBlendMode(.normal)
            context.setFillColor(color.cgColor)
            context.fillPath()
        }
        
    }
    if flipped {
        return generateImage(CGSize(width: radius, height: radius * 6.0), contextGenerator: generator)
    } else {
        return generateImage(CGSize(width: radius, height: radius * 6.0), rotatedContext: generator)
    }
}



func generateFilledCircleImage(diameter: CGFloat, color: NSColor?, strokeColor: NSColor? = nil, strokeWidth: CGFloat? = nil, backgroundColor: NSColor? = nil) -> CGImage {
    return generateImage(CGSize(width: diameter, height: diameter), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        if let backgroundColor = backgroundColor {
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
        }
        
        if let strokeColor = strokeColor, let strokeWidth = strokeWidth {
            context.setFillColor(strokeColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            
            if let color = color {
                context.setFillColor(color.cgColor)
            } else {
                context.setFillColor(NSColor.clear.cgColor)
                context.setBlendMode(.copy)
            }
            context.fillEllipse(in: CGRect(origin: CGPoint(x: strokeWidth, y: strokeWidth), size: CGSize(width: size.width - strokeWidth * 2.0, height: size.height - strokeWidth * 2.0)))
        } else {
            if let color = color {
                context.setFillColor(color.cgColor)
            } else {
                context.setFillColor(NSColor.clear.cgColor)
                context.setBlendMode(.copy)
            }
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        }
    })!
}


func generateTextIcon(_ text: NSAttributedString, minSize: Bool = true) -> CGImage {
    
    let textNode = TextNode.layoutText(text, nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .center)
    var size = textNode.0.size
    if minSize {
        size.width = max(size.width, 24)
        size.width = max(size.height, 23)
    }
    return generateImage(textNode.0.size, rotatedContext: { size, ctx in
        let rect = NSMakeRect(0, 0, size.width, size.height)
        ctx.clear(rect)
        
        textNode.1.draw(rect.focus(textNode.0.size), in: ctx, backingScaleFactor: System.backingScale, backgroundColor: .clear)
    })!
}


func generateStarBalanceIcon(_ text: String) -> CGImage {
    return generateBalanceIcon(text: text, icon: NSImage(resource: .iconStarCurrency).precomposed(flipVertical: true, zoom: 0.75))
}


func generateTonBalanceIcon(_ text: String) -> CGImage {
    return generateBalanceIcon(text: text, icon: NSImage(resource: .iconTonCurrency).precomposed(flipVertical: true, zoom: 0.75))
}

private func generateBalanceIcon(text: String, icon: CGImage) -> CGImage {
    let textNode = TextNode.layoutText(.initialize(string: text, color: theme.colors.grayText, font: .normal(.text)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .center)
    let icon = icon
    var size = textNode.0.size
    
    size.width += icon.backingSize.width + 1
    size.height = max(size.height, icon.backingSize.height)
    return generateImage(size, rotatedContext: { size, ctx in
        ctx.clear(size.bounds)
        
        let iconRect = size.bounds.focusY(icon.backingSize, x: 0)
        let textRect = size.bounds.focusY(textNode.0.size, x: iconRect.maxX + 1)
        ctx.draw(icon, in: iconRect)
        
        textNode.1.draw(textRect, in: ctx, backingScaleFactor: System.backingScale, backgroundColor: .clear)
    })!
}

func generateTonAndStarBalanceIcon(ton: String?, stars: String?) -> CGImage {
    
    
    let starsIcon: CGImage?
    let tonIcon: CGImage?
    if let stars {
        starsIcon = generateBalanceIcon(text: stars, icon: NSImage(resource: .iconStarCurrency).precomposed(flipVertical: true, zoom: 0.75))
    } else {
        starsIcon = nil
    }
    if let ton = ton {
        tonIcon = generateBalanceIcon(text: ton, icon: NSImage(resource: .iconTonCurrency).precomposed(flipVertical: true, zoom: 0.75))
    } else {
        tonIcon = nil
    }

    var size = NSMakeSize(0, 0)
    if let tonIcon {
        size.width += tonIcon.backingSize.width
        size.height = tonIcon.backingSize.height
    }
    if let starsIcon {
        size.width += starsIcon.backingSize.width
        size.height = max(size.height, starsIcon.backingSize.height)
    }
    if starsIcon != nil, tonIcon != nil {
        size.width += 2
    }
    
    return generateImage(size, contextGenerator: { size, ctx in
        ctx.clear(size.bounds)
        
        if let tonIcon, let starsIcon {
            let tonRect = size.bounds.focusY(tonIcon.backingSize, x: 0)
            let starsRect = size.bounds.focusY(starsIcon.backingSize, x: tonRect.maxX + 2)
            
            ctx.draw(tonIcon, in: tonRect)
            ctx.draw(starsIcon, in: starsRect)

        } else if let tonIcon {
            let tonRect = size.bounds.focusY(tonIcon.backingSize, x: 0)
            ctx.draw(tonIcon, in: tonRect)
        } else if let starsIcon {
            let starsRect = size.bounds.focusY(starsIcon.backingSize, x: 0)
            ctx.draw(starsIcon, in: starsRect)
        }
    })!
}

func generateTextIcon_NewBadge(bgColor: NSColor, textColor: NSColor) -> CGImage {
    return generateTextIcon_AccentBadge(text: strings().badgeNew, bgColor: bgColor, textColor: textColor)
}

func generateTextIcon_NewBadge_Flipped(bgColor: NSColor, textColor: NSColor) -> CGImage {
    let image = generateTextIcon_AccentBadge(text: strings().badgeNew, bgColor: bgColor, textColor: textColor)
    return generateImage(image.systemSize, rotatedContext: { size, ctx in
        ctx.clear(size.bounds)
        ctx.draw(image, in: image.systemSize.bounds)
    })!
}

func generateTextIcon_AccentBadge(text: String, bgColor: NSColor, textColor: NSColor) -> CGImage {
    
    let textNode = TextNode.layoutText(.initialize(string: text, color: textColor, font: .avatar(.small)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .center)
    var size = textNode.0.size
    size.width += 6
    size.height += 4
    return generateImage(size, rotatedContext: { size, ctx in
        let rect = NSMakeRect(0, 0, size.width, size.height)
        ctx.clear(rect)
        ctx.round(size, .cornerRadius)
        ctx.setFillColor(bgColor.cgColor)
        ctx.fill(rect)
        textNode.1.draw(rect.focus(textNode.0.size), in: ctx, backingScaleFactor: System.backingScale, backgroundColor: .clear)
    })!
}

private func generateGradientBubble(_ colors: [NSColor]) -> CGImage {
    var colors = colors
    if !System.supportsTransparentFontDrawing {
        let blended = colors.reduce(colors.first!, {
            $0.blended(withFraction: 0.5, of: $1)!
        })
        for (i, _) in colors.enumerated() {
            colors[i] = blended
        }
    }
    
    return generateImage(CGSize(width: 32, height: 32), opaque: true, scale: 1.0, rotatedContext: { size, context in
        
        if colors.count > 1 {
            if colors.count == 2 {
                let colors = colors.map { $0.cgColor } as NSArray
                
                let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                
                var locations: [CGFloat] = []
                for i in 0 ..< colors.count {
                    locations.append(delta * CGFloat(i))
                }

                let gradient = CGGradient(colorsSpace: DeviceGraphicsContextSettings.shared.colorSpace, colors: colors, locations: &locations)!
                
                context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
            } else {
                let preview = AnimatedGradientBackgroundView.generatePreview(size: NSMakeSize(32, 32), colors: colors)
                context.draw(preview, in: size.bounds)
            }
           
        } else if let color = colors.first {
            context.setFillColor(color.cgColor)
            context.fill(size.bounds)
        }
    })!
}

private func generateProfileIcon(_ image: CGImage, backgroundColor: NSColor) -> CGImage {
    return generateImage(image.backingSize, contextGenerator: { size, ctx in
        let rect = CGRect(origin: CGPoint(), size: size)
        ctx.clear(rect)
        

        
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fillEllipse(in: NSMakeRect(2, 2, rect.width - 4, rect.height - 4))
        
        ctx.clip(to: CGRect(origin: CGPoint(), size: size), mask: image)
        
        ctx.clear(rect)
     
        
 //      ctx.clip(to: rect)
//
//        ctx.setFillColor(NSColor.red.cgColor)
//        ctx.fillEllipse(in: NSMakeRect(2, 2, rect.width - 4, rect.height - 4))

        
    })!
}

private func generateChatTabFiltersIcon(_ image: CGImage) -> CGImage {
    return generateImage(image.backingSize, contextGenerator: { size, ctx in
        let rect = CGRect(origin: CGPoint(), size: size)
        ctx.clear(rect)
        
        ctx.draw(image, in: CGRect(origin: CGPoint(), size: size))
        
        ctx.setBlendMode(.clear)
        
        var x: CGFloat = 14
        ctx.fillEllipse(in: NSMakeRect(x, 17, 3, 3))
        x += (3 + 2)
        ctx.fillEllipse(in: NSMakeRect(x, 17, 3, 3))
        x += (3 + 2)
        ctx.fillEllipse(in: NSMakeRect(x, 17, 3, 3))

    })!
}

private func generateChatAction(_ image: CGImage, background: NSColor) -> CGImage {
    return generateImage(NSMakeSize(36, 36), contextGenerator: { size, ctx in
        let rect = CGRect(origin: CGPoint(), size: size)
        ctx.clear(rect)
        
        ctx.setFillColor(NSColor.clear.cgColor)
        ctx.fillEllipse(in: rect)
        ctx.draw(image, in: rect.focus(image.backingSize))
        
    })!
}

private func generateTodoSelection(color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(19, 19), rotatedContext: { size, ctx in
        ctx.clear(size.bounds)
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: size.bounds.focus(NSMakeSize(6, 6)))
    })!
}
private func generateTodoSelected(color: NSColor) -> CGImage {
    let image = NSImage(resource: .iconTodoOtherCheck).precomposed(color)
    return generateImage(NSMakeSize(19, 19), contextGenerator: { size, ctx in
        ctx.clear(size.bounds)
        ctx.draw(image, in: size.bounds.focus(image.backingSize))
    })!
}

private func generatePollIcon(_ image: NSImage, backgound: NSColor) -> CGImage {
    return generateImage(NSMakeSize(19, 19), contextGenerator: { size, ctx in
        let rect = NSMakeRect(0, 0, size.width, size.height)
        ctx.clear(rect)
        
        ctx.setBlendMode(.copy)
        ctx.round(size, size.height / 2)
        
        
        if backgound != NSColor(0xffffff) {
            ctx.setFillColor(NSColor(0xffffff).cgColor)
            ctx.fillEllipse(in: rect)
        }
        
        ctx.setFillColor(backgound.cgColor)
        ctx.fillEllipse(in: rect.insetBy(dx: 1, dy: 1))
        
        
        ctx.setBlendMode(.normal)
        let image = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        if backgound == NSColor(0xffffff) {
            ctx.clip(to: rect, mask: image)
            ctx.clear(rect)
        } else {
            
         
            ctx.draw(image, in: rect.focus(image.backingSize))
        }
    })!
}

private func generateSecretThumbSmall(_ image: CGImage) -> CGImage {
    return generateImage(NSMakeSize(floor(image.size.width * 0.7), floor(image.size.height * 0.7)), contextGenerator: { size, ctx in
        let rect = NSMakeRect(0, 0, size.width, size.height)
        ctx.clear(rect)
        ctx.clip(to: rect, mask: image)
        ctx.setBlendMode(.difference)
        ctx.setFillColor(.white)
        ctx.fill(rect)
        ctx.draw(image, in: rect)
    }, scale: 1.0)!
}

private func generateSecretThumb(_ image: CGImage) -> CGImage {
    return generateImage(image.size, contextGenerator: { size, ctx in
        let rect = NSMakeRect(0, 0, size.width, size.height)
        ctx.clear(rect)
        ctx.clip(to: rect, mask: image)
        ctx.setBlendMode(.difference)
        ctx.setFillColor(.white)
        ctx.fill(rect)
        ctx.draw(image, in: rect)
    }, scale: 1.0)!
}

private func generateLoginQrEmptyCap() -> CGImage {
    return generateImage(NSMakeSize(60, 60), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
    })!
}

private func generateSendIcon(_ image: NSImage, _ color: NSColor) -> CGImage {
    let image = image.precomposed(color)
    if color.lightness > 0.7 {
        return image
    } else {
        return generateImage(image.backingSize, contextGenerator: { size, ctx in
            let rect = CGRect(origin: CGPoint(), size: size)
            ctx.clear(rect)
            
            ctx.setFillColor(.white)
            ctx.fillEllipse(in: rect.focus(NSMakeSize(rect.width - 8, rect.height - 8)))
            
            ctx.draw(image, in: CGRect(origin: CGPoint(), size: size))
        })!
    }
}

private func generateUnslectedCap(_ color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(22, 22), contextGenerator: { size, ctx in
        let rect = CGRect(origin: CGPoint(), size: size)
        ctx.clear(rect)
        
        ctx.setStrokeColor(color.withAlphaComponent(0.7).cgColor)
        ctx.setLineWidth(1.0)
        ctx.strokeEllipse(in: NSMakeRect(1, 1, size.width - 2, size.height - 2))
    })!
}

private func generatePollAddOption(_ color: NSColor) -> CGImage {
    let image = NSImage(named: "Icon_PollAddOption")!.precomposed(color)
    return generateImage(image.backingSize, contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        
        ctx.setFillColor(.white)
        ctx.fillEllipse(in: NSMakeRect(0, 0, size.width, size.height))
        
        ctx.draw(image, in: CGRect(origin: CGPoint(), size: size))
    })!
}

func generateThemePreview(for palette: ColorPalette, wallpaper: Wallpaper, backgroundMode: TableBackgroundMode) -> CGImage {
    return generateImage(NSMakeSize(320, 320), rotatedContext: { size, ctx in
        let rect = NSMakeRect(0, 0, size.width, size.height)
        ctx.clear(rect)
        
        //background
        ctx.setFillColor(palette.chatBackground.cgColor)
        ctx.fill(rect)
        
        #if !SHARE
        switch wallpaper {
        case .builtin, .file, .color, .gradient:
            ctx.saveGState()
            ctx.translateBy(x: size.width / 2.0, y: size.height / 2.0)
            ctx.scaleBy(x: 1.0, y: -1.0)
            ctx.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            drawBg(backgroundMode, palette: palette, bubbled: true, rect: rect, in: ctx)
            ctx.restoreGState()
        default:
            break
        }
        #endif
        
        
        //top and bottom
        ctx.setFillColor(palette.background.cgColor)
        ctx.fill(NSMakeRect(0, 0, rect.width, 50))
        ctx.setFillColor(palette.background.cgColor)
        ctx.fill(NSMakeRect(0, rect.height - 50, rect.width, 50))
        
        
        
        //top border
        ctx.setFillColor(palette.border.cgColor)
        ctx.fill(NSMakeRect(0, 50, rect.width, .borderSize))
        
        //bottom border
        ctx.setFillColor(palette.border.cgColor)
        ctx.fill(NSMakeRect(0, rect.height - 50, rect.width, .borderSize))
        
        
        //fill avatar
        ctx.setFillColor(palette.grayForeground.cgColor)
        ctx.fillEllipse(in: NSMakeRect(20, (50 - 36) / 2, 36, 36))
        
        //fill chat actions
        let chatAction = NSImage(named: "Icon_ChatActions")!.precomposed(palette.accentIcon)
        ctx.draw(chatAction, in: NSMakeRect(rect.width - 20 - chatAction.backingSize.width, (50 - chatAction.backingSize.height) / 2, chatAction.backingSize.width, chatAction.backingSize.height))
        
        //fill attach icon
        let inputAttach = NSImage(named: "Icon_ChatAttach")!.precomposed(palette.grayIcon, flipVertical: true)
        ctx.draw(inputAttach, in: NSMakeRect(20, rect.height - 50 + ((50 - inputAttach.backingSize.height) / 2), inputAttach.backingSize.width, inputAttach.backingSize.height))
        
        //fill micro icon
        let micro = NSImage(named: "Icon_RecordVoice")!.precomposed(palette.grayIcon, flipVertical: true)
        ctx.draw(micro, in: NSMakeRect(rect.width - 20 - inputAttach.backingSize.width, (rect.height - 50 + (50 - micro.backingSize.height) / 2), micro.backingSize.width, micro.backingSize.height))
        
        let chatServiceItemColor: NSColor
        
        
        switch wallpaper {
        case .builtin, .file, .color, .gradient:
            switch backgroundMode {
            case let .background(image, _, colors, _):
                if let colors = colors, let first = colors.first {
                    let blended = colors.reduce(first, { color, with in
                        return color.blended(withFraction: 0.5, of: with)!
                    })
                    chatServiceItemColor = getAverageColor(blended)
                } else {
                    chatServiceItemColor = getAverageColor(image)
                }
            case let .color(color):
                if color != palette.background {
                    chatServiceItemColor = getAverageColor(color)
                } else {
                    chatServiceItemColor = color
                }
            case let .gradient(colors, _):
                let blended = colors.reduce(colors.first!, { color, with in
                    return color.blended(withFraction: 0.5, of: with)!
                })
                chatServiceItemColor = getAverageColor(blended)
            case let .tiled(image):
                chatServiceItemColor = getAverageColor(image)
            case .plain:
                chatServiceItemColor = palette.chatBackground
            }
        default:
            chatServiceItemColor = getAverageColor(palette.chatBackground)
        }
        
        
        
        //fill date
        ctx.setFillColor(chatServiceItemColor.cgColor)
        let path = CGMutablePath()
        path.addRoundedRect(in: NSMakeRect(rect.width / 2 - 30, rect.height - 50 - 10 - 60 - 5 - 20 - 5, 60, 20), cornerWidth: 10, cornerHeight: 10)
        
        ctx.addPath(path)
        ctx.closePath()
        ctx.fillPath()
        
        
        //fill outgoing bubble
        CATransaction.begin()
        if true {
            
            let image = generateImage(NSMakeSize(150, 30), rotatedContext: { size, ctx in
                ctx.clear(NSMakeRect(0, 0, size.width, size.height))
                let data = messageBubbleImageModern(incoming: false, fillColor: palette.blendedOutgoingColors, strokeColor: palette.bubbleBorder_outgoing, neighbors: .none)
                
                let layer = CALayer()
                layer.frame = NSMakeRect(0, 0, 150, 30)
                layer.contentsScale = 2.0
                let imageSize = data.0.backingSize
                let insets = data.1
                let halfPixelFudge: CGFloat = 0.49
                let otherPixelFudge: CGFloat = 0.02
                var contentsCenter: CGRect  = NSMakeRect(0.0, 0.0, 1.0, 1.0);
                if (insets.left > 0 || insets.right > 0) {
                    contentsCenter.origin.x = ((insets.left + halfPixelFudge) / imageSize.width);
                    contentsCenter.size.width = (imageSize.width - (insets.left + insets.right + 1.0) + otherPixelFudge) / imageSize.width;
                }
                if (insets.top > 0 || insets.bottom > 0) {
                    contentsCenter.origin.y = ((insets.top + halfPixelFudge) / imageSize.height);
                    contentsCenter.size.height = (imageSize.height - (insets.top + insets.bottom + 1.0) + otherPixelFudge) / imageSize.height;
                }
                layer.contentsGravity = .resize;
                layer.contentsCenter = contentsCenter;
                layer.contents = data.0
                
                layer.render(in: ctx)
            })!
            
            var bubble = image
            bubble = generateImage(NSMakeSize(150, 30), contextGenerator: { size, ctx in
                let colors = palette.bubbleBackground_outgoing.map { $0.withAlphaComponent(1.0) }
                let rect = NSMakeRect(0, 0, size.width, size.height)
                ctx.clear(rect)
                ctx.clip(to: rect, mask: image)
                
                if colors.count > 1 {
                    let gradientColors = colors.map { $0.cgColor } as CFArray
                    let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                    
                    var locations: [CGFloat] = []
                    for i in 0 ..< colors.count {
                        locations.append(delta * CGFloat(i))
                    }
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: rect.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                } else if colors.count == 1 {
                    ctx.setFillColor(colors[0].cgColor)
                    ctx.fill(rect)
                }
                
            })!
            ctx.draw(bubble, in: NSMakeRect(160, 230, 150, 30))
           
        }
        
        //fill incoming bubble
        if true {
            let image = generateImage(NSMakeSize(150, 30), rotatedContext: { size, ctx in
                ctx.clear(NSMakeRect(0, 0, size.width, size.height))
                let data = messageBubbleImageModern(incoming: true, fillColor: palette.bubbleBackground_incoming, strokeColor: palette.bubbleBorder_incoming, neighbors: .none)
                
                let layer = CALayer()
                layer.frame = NSMakeRect(0, 0, 150, 30)
                layer.contentsScale = 2.0
                let imageSize = data.0.backingSize
                let insets = data.1
                let halfPixelFudge: CGFloat = 0.49
                let otherPixelFudge: CGFloat = 0.02
                var contentsCenter: CGRect  = NSMakeRect(0.0, 0.0, 1.0, 1.0);
                if (insets.left > 0 || insets.right > 0) {
                    contentsCenter.origin.x = ((insets.left + halfPixelFudge) / imageSize.width);
                    contentsCenter.size.width = (imageSize.width - (insets.left + insets.right + 1.0) + otherPixelFudge) / imageSize.width;
                }
                if (insets.top > 0 || insets.bottom > 0) {
                    contentsCenter.origin.y = ((insets.top + halfPixelFudge) / imageSize.height);
                    contentsCenter.size.height = (imageSize.height - (insets.top + insets.bottom + 1.0) + otherPixelFudge) / imageSize.height;
                }
                layer.contentsGravity = .resize;
                layer.contentsCenter = contentsCenter;
                layer.contents = data.0
                
                layer.render(in: ctx)
            })!
            
            ctx.draw(image, in: NSMakeRect(10, 200, 150, 30))

        }
        CATransaction.commit()
        
    })!
}

func generateLockPremium(_ palette: ColorPalette) -> CGImage {
    let image = NSImage(named: "Icon_Premium_Lock")!.precomposed(palette.accent)
    return generateImage(image.backingSize, contextGenerator: { size, ctx in
        ctx.clear(size.bounds)
        
//        ctx.setFillColor(palette.background.cgColor)
//        ctx.fillEllipse(in: size.bounds.insetBy(dx: 2, dy: 2))
//
//        ctx.fill(NSMakeRect(size.width - 9, 1, 8, 8))

        
        ctx.clip(to: size.bounds, mask: image)

        let colors = [NSColor(hexString: "#ffffff")!, NSColor(hexString: "#ffffff")!].map { $0.cgColor } as NSArray
        let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
        
        var locations: [CGFloat] = []
        for i in 0 ..< colors.count {
            locations.append(delta * CGFloat(i))
        }

        let colorSpace = deviceColorSpace
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations)!
        
        ctx.drawLinearGradient(gradient, start: CGPoint(x: size.width, y: 0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    })!
}

func generateLockPremiumReaction(_ palette: ColorPalette) -> CGImage {
    let image = NSImage(named: "Icon_Premium_Lock")!.precomposed(palette.accent)
    return generateImage(image.backingSize, contextGenerator: { size, ctx in
        ctx.clear(size.bounds)
        
        ctx.setFillColor(palette.background.cgColor)
        ctx.fillEllipse(in: size.bounds.insetBy(dx: 2, dy: 2))
        
        ctx.fill(NSMakeRect(size.width - 9, 1, 8, 8))

        
        ctx.clip(to: size.bounds, mask: image)

        let colors = [NSColor(hexString: "#1391FF")!, NSColor(hexString: "#F977CC")!].map { $0.cgColor } as NSArray
        let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
        
        var locations: [CGFloat] = []
        for i in 0 ..< colors.count {
            locations.append(delta * CGFloat(i))
        }

        let colorSpace = deviceColorSpace
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations)!
        
        ctx.drawLinearGradient(gradient, start: CGPoint(x: size.width, y: 0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    })!
}

func generatePremium(_ reversed: Bool = false, color: NSColor? = nil, small: Bool = false) -> CGImage {
    
    let draw: (NSSize, CGContext)->Void = { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))

        let image: CGImage
        if small {
            image = NSImage(named: "Icon_Peer_Premium")!.precomposed()
        } else {
            image = NSImage(named: "Icon_Premium_StickerPack")!.precomposed()
        }
        ctx.clip(to: size.bounds, mask: image)

        if let color = color {
            ctx.setFillColor(color.cgColor)
            ctx.fill(size.bounds)
        } else {
            let colors = [NSColor(hexString: "#1391FF")!, NSColor(hexString: "#F977CC")!].map { $0.cgColor } as NSArray
            let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
            
            var locations: [CGFloat] = []
            for i in 0 ..< colors.count {
                locations.append(delta * CGFloat(i))
            }

            let colorSpace = deviceColorSpace
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations)!
            
            ctx.drawLinearGradient(gradient, start: CGPoint(x: size.width, y: 0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        }
        
    }
    
    let size: NSSize
    if small {
        size = NSMakeSize(16, 16)
    } else {
        size = NSMakeSize(24, 24)
    }
    if reversed {
        return generateImage(size, rotatedContext: { size, ctx in
            draw(size, ctx)
        })!
    } else {
        return generateImage(size, contextGenerator: { size, ctx in
            draw(size, ctx)
        })!
    }

}


func generateStickerPackPremium() -> CGImage {
    
    let draw: (NSSize, CGContext)->Void = { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))

        let image = NSImage(named: "Icon_Premium_StickerPack")!.precomposed()
        ctx.clip(to: size.bounds, mask: image)

        let colors = premiumGradient.compactMap { $0.cgColor } as NSArray
        let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
        
        var locations: [CGFloat] = []
        for i in 0 ..< colors.count {
            locations.append(delta * CGFloat(i))
        }

        let colorSpace = deviceColorSpace
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations)!
        
        ctx.drawLinearGradient(gradient, start: CGPoint(x: size.width, y: 0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        
    }
    return generateImage(NSMakeSize(24, 24), contextGenerator: { size, ctx in
        draw(size, ctx)
    })!
}

func generateDialogVerify(background: NSColor, foreground: NSColor, reversed: Bool = false) -> CGImage {
    if reversed {
        return generateImage(NSMakeSize(16, 16), contextGenerator: { size, ctx in
            ctx.clear(CGRect(origin: CGPoint(), size: size))

            let image = NSImage(named: "Icon_VerifyDialog")!.precomposed(foreground)
            
            ctx.setFillColor(background.cgColor)
            ctx.fillEllipse(in: NSMakeRect(4, 4, size.width - 8, size.height - 8))
            
            ctx.draw(image, in: CGRect(origin: CGPoint(), size: size))
        })!
    } else {
        return generateImage(NSMakeSize(16, 16), rotatedContext: { size, ctx in
            ctx.clear(CGRect(origin: CGPoint(), size: size))

            let image = NSImage(named: "Icon_VerifyDialog")!.precomposed(foreground)
            
            ctx.setFillColor(background.cgColor)
            ctx.fillEllipse(in: NSMakeRect(4, 4, size.width - 8, size.height - 8))
            
            ctx.draw(image, in: CGRect(origin: CGPoint(), size: size))
        })!
    }
}


func generateDialogVerifyLeft(background: NSColor, foreground: NSColor, reversed: Bool = false) -> CGImage {
    if reversed {
        return generateImage(NSMakeSize(16, 16), contextGenerator: { size, ctx in
            ctx.clear(CGRect(origin: CGPoint(), size: size))

            let image = NSImage(named: "Icon_Verified_Telegram")!.precomposed(foreground)
            
            ctx.setFillColor(background.cgColor)
            ctx.fillEllipse(in: NSMakeRect(4, 4, size.width - 8, size.height - 8))
            
            ctx.draw(image, in: CGRect(origin: CGPoint(), size: size))
        })!
    } else {
        return generateImage(NSMakeSize(16, 16), rotatedContext: { size, ctx in
            ctx.clear(CGRect(origin: CGPoint(), size: size))

            let image = NSImage(named: "Icon_Verified_Telegram")!.precomposed(foreground)
            
            ctx.setFillColor(background.cgColor)
            ctx.fillEllipse(in: NSMakeRect(4, 4, size.width - 8, size.height - 8))
            
            ctx.draw(image, in: CGRect(origin: CGPoint(), size: size))
        })!
    }
}


private func generatePollDeleteOption(_ color: NSColor) -> CGImage {
    let image = NSImage(named: "Icon_PollDeleteOption")!.precomposed(color)
    return generateImage(image.backingSize, contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        
        ctx.setFillColor(.white)
        ctx.fillEllipse(in: NSMakeRect(0, 0, size.width, size.height))
        
        ctx.draw(image, in: CGRect(origin: CGPoint(), size: size))
    })!
}

private func generateStickerPackSelection(_ color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(30, 30), contextGenerator: { size, ctx in
        ctx.interpolationQuality = .low
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.round(size, .cornerRadius)
        ctx.setFillColor(color.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
    })!
}

private func generateHitActiveIcon(activeColor: NSColor, backgroundColor: NSColor) -> CGImage {
    return generateImage(NSMakeSize(12, 12), contextGenerator: { size, ctx in
        ctx.interpolationQuality = .high
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.round(size, size.width / 2)
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fillEllipse(in: NSMakeRect(0, 0, size.width, size.height))
        
        ctx.setFillColor(activeColor.cgColor)
        ctx.fillEllipse(in: NSMakeRect(2, 2, 8, 8))
    })!
}

func generateScamIcon(foregroundColor: NSColor, backgroundColor: NSColor, text: String = strings().markScam, isReversed: Bool = false) -> CGImage {
    let textNode = TextNode.layoutText(.initialize(string: text, color: foregroundColor, font: .medium(9)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .center)
    
    let draw: (CGSize, CGContext) -> Void = { size, ctx in
        ctx.interpolationQuality = .high
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        
        
        let borderPath = CGMutablePath()
        borderPath.addRoundedRect(in: NSMakeRect(1, 1, size.width - 2, size.height - 2), cornerWidth: 2, cornerHeight: 2)
        
        ctx.setStrokeColor(foregroundColor.cgColor)
        ctx.addPath(borderPath)
        ctx.closePath()
        ctx.strokePath()
        
        let textRect = NSMakeRect((size.width - textNode.0.size.width) / 2, (size.height - textNode.0.size.height) / 2 + 1, textNode.0.size.width, textNode.0.size.height)
        textNode.1.draw(textRect, in: ctx, backingScaleFactor: System.backingScale, backgroundColor: backgroundColor)
    }
    if !isReversed {
        return generateImage(NSMakeSize(textNode.0.size.width + 8, 16), contextGenerator: draw)!
    } else {
        return generateImage(NSMakeSize(textNode.0.size.width + 8, 16), rotatedContext: draw)!
    }
}

func generateScamIconReversed(foregroundColor: NSColor, backgroundColor: NSColor) -> CGImage {
    return generateScamIcon(foregroundColor: foregroundColor, backgroundColor: backgroundColor, isReversed: true)
}

func generateFakeIcon(foregroundColor: NSColor, backgroundColor: NSColor, isReversed: Bool = false) -> CGImage {
    return generateScamIcon(foregroundColor: foregroundColor, backgroundColor: backgroundColor, text: strings().markFake, isReversed: isReversed)
}
func generateFakeIconReversed(foregroundColor: NSColor, backgroundColor: NSColor) -> CGImage {
    return generateScamIcon(foregroundColor: foregroundColor, backgroundColor: backgroundColor, text: strings().markFake, isReversed: true)
}

private func generateVideoMessageChatCap(backgroundColor: NSColor) -> CGImage {
    return generateImage(NSMakeSize(200, 200), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
        
        ctx.setFillColor(.clear)
        ctx.setBlendMode(.clear)
        
        let radius = size.width / 2
        
        let center = NSMakePoint(100, 100)

        ctx.addArc(center: center, radius: radius - 0.54, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: false)
        ctx.drawPath(using: .fill)
        ctx.setBlendMode(.normal)
//        CGContextAddArc(context, center.x, center.y, radius - 0.54, 0, 2 * M_PI, 0);
//        CGContextDrawPath(context, kCGPathFill);
//        CGContextSetBlendMode(context, kCGBlendModeNormal);

        
    })!
}

private func generateEditMessageMediaIcon(_ icon: CGImage, background: NSColor) -> CGImage {
    return generateImage(NSMakeSize(icon.backingSize.width + 1, icon.backingSize.height + 1), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.round(size, size.width / 2)
        
        ctx.setFillColor(background.cgColor)
        ctx.fillEllipse(in: NSMakeRect(0, 0, size.width, size.height))
        
        let imageRect = NSMakeRect(floorToScreenPixels(System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height)
        ctx.draw(icon, in: imageRect)
        
    })!
}

private func generateUnreadFeaturedStickers(_ icon: CGImage, _ color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(icon.systemSize.width, icon.systemSize.height), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))

        let imageRect = size.bounds
        ctx.draw(icon, in: imageRect)

//        ctx.setFillColor(color.cgColor)
//        ctx.fillEllipse(in: NSMakeRect(size.width - 10, size.height - 10, 6, 6))

    }, scale: System.backingScale)!
}


private func generatePlayerListAlbumPlaceholder(_ icon: CGImage?, background: NSColor, radius: CGFloat) -> CGImage {
    return generateImage(NSMakeSize(40, 40), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.round(size, radius)
        
        ctx.setFillColor(background.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
        
        if let icon = icon {
            let imageRect = NSMakeRect(floorToScreenPixels(System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height)
            ctx.draw(icon, in: imageRect)
        }
       
    })!
}

private func generateFolderLinkIcon(palette: ColorPalette, revoked: Bool) -> CGImage {
    return generateImage(NSMakeSize(35, 35), contextGenerator: { size, ctx in
        ctx.clear(size.bounds)
        ctx.setFillColor(revoked ? palette.redUI.cgColor : palette.accent.cgColor)
        ctx.fillEllipse(in: size.bounds)
        
        let image = NSImage(named: "Icon_InviteViaLink")!.precomposed(palette.underSelectedColor)
        ctx.draw(image, in: size.bounds.focus(NSMakeSize(25, 25)))
    })!
}

private func generateLocationPinIcon(_ background: NSColor) -> CGImage {
    return generateImage(NSMakeSize(40, 40), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.round(size, size.width / 2)
        
        ctx.setFillColor(background.cgColor)
        ctx.fillEllipse(in: NSMakeRect(0, 0, size.width, size.height))
        
        let icon = #imageLiteral(resourceName: "Icon_LocationPin").precomposed(.white)
        let imageRect = NSMakeRect(floorToScreenPixels(System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height)
        ctx.draw(icon, in: imageRect)

    })!
}

private func generateChatTabSelected(_ color: NSColor, _ icon: CGImage) -> CGImage {
    let main = #imageLiteral(resourceName: "Icon_TabChatList_Highlighted").precomposed(color)
    return generateImage(main.backingSize, contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.draw(main, in: NSMakeRect(0, 0, size.width, size.height))
        
        
        let imageRect = NSMakeRect(floorToScreenPixels(System.backingScale, (size.width - icon.backingSize.width) / 2) - 2, floorToScreenPixels(System.backingScale, (size.height - icon.backingSize.height) / 2) + 2, icon.backingSize.width, icon.backingSize.height)
        ctx.draw(icon, in: imageRect)
        
    })!
}


private func generateTriangle(_ size: NSSize, color: NSColor) -> CGImage {
    return generateImage(size, contextGenerator: { size, ctx in
        let rect = CGRect(origin: CGPoint(), size: size)
        ctx.clear(rect)
        
        ctx.beginPath()
        ctx.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        ctx.addLine(to: CGPoint(x: (rect.midX), y: rect.minY))
        ctx.closePath()
        
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
    })!
}

private func generateStoryState(_ color: NSColor, bgColor: NSColor, size: NSSize, wide: CGFloat) -> CGImage {
    return generateImage(size, contextGenerator: { size, ctx in
        let rect = CGRect(origin: CGPoint(), size: size)
        ctx.clear(rect)
        
        
        let startAngle = -CGFloat.pi / 2.0
        let endAngle = CGFloat(1.0) * 2.0 * CGFloat.pi + startAngle
        
        let path = CGMutablePath()
        
        path.addArc(center: CGPoint(x: size.width / 2.0, y: size.height / 2.0), radius: size.width / 2 - 1, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(wide)
        ctx.setLineCap(.round)
        ctx.addPath(path)
        ctx.strokePath()
        
    })!
}


private func generateStoryStateWithOnline(_ color: NSColor, size: NSSize, wide: CGFloat) -> CGImage {
    return generateImage(size, contextGenerator: { size, ctx in
        let rect = CGRect(origin: CGPoint(), size: size)
        ctx.clear(rect)
        
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: size.bounds)
        
        ctx.setBlendMode(.clear)
        ctx.fillEllipse(in: size.bounds.insetBy(dx: wide, dy: wide))
    })!
}




private func generateLocationMapPinIcon(_ background: NSColor) -> CGImage {
    return generateImage(NSMakeSize(40, 46), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        
        ctx.setFillColor(background.cgColor)
        ctx.fillEllipse(in: NSMakeRect(0, 6, size.width, size.height - 6))
        
        let icon = #imageLiteral(resourceName: "Icon_LocationPin").precomposed(.white)
        let imageRect = NSMakeRect(floorToScreenPixels(System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(System.backingScale, (size.height - icon.backingSize.height) / 2) + 3, icon.backingSize.width, icon.backingSize.height)
        ctx.draw(icon, in: imageRect)
        
        let triangle = generateTriangle(NSMakeSize(12, 10), color: background)
        let triangleRect = NSMakeRect(floorToScreenPixels(System.backingScale, (size.width - triangle.backingSize.width) / 2), 0, triangle.backingSize.width, triangle.backingSize.height)
        
        ctx.draw(triangle, in: triangleRect)

    })!
}

private func generateLockerBody(_ color: NSColor, backgroundColor: NSColor) -> CGImage {
    return generateImage(NSMakeSize(12.5, 12.5), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fillEllipse(in: NSMakeRect(0, 0, size.width, size.height))
        
        ctx.setFillColor(color.cgColor)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(1.0)
        ctx.strokeEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2.0, height: size.height - 2.0)))
        ctx.fillEllipse(in: NSMakeRect(floorToScreenPixels(System.backingScale, (size.width - 2)/2), floorToScreenPixels(System.backingScale, (size.height - 2)/2), 2, 2))
       
    })!
}
private func generateLockerHead(_ color: NSColor, backgroundColor: NSColor) -> CGImage {
    return generateImage(NSMakeSize(10, 20), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.round(size, size.width / 2)

        ctx.setFillColor(color.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
        
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fillEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2, height: size.width - 2)))
        ctx.fillEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: size.height - size.width + 1), size: CGSize(width: size.width - 2, height: size.width - 2)))
        ctx.fill(NSMakeRect(1.0, 0, size.width - 1, 14))

        ctx.clear(NSMakeRect(0, 0, size.width, 3))

        

    })!
}

private func generateChatMention(image: NSImage, backgroundColor: NSColor, border: NSColor, foregroundColor: NSColor) -> CGImage {
    return generateImage(NSMakeSize(38, 38), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fillEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2.0, height: size.height - 2.0)))
        ctx.setLineWidth(1.0)
        
        if border != .clear {
            ctx.setStrokeColor(border.withAlphaComponent(0.7).cgColor)
            ctx.strokeEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2.0, height: size.height - 2.0)))
        }
        
//        ctx.setStrokeColor(border.withAlphaComponent(0.7).cgColor)
      //  ctx.strokeEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2.0, height: size.height - 2.0)))

        let icon = image.precomposed(foregroundColor)
        let imageRect = NSMakeRect(floorToScreenPixels(System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height)
        
        ctx.draw(icon, in: imageRect)
    })!
}

private func generateChatFailed(backgroundColor: NSColor, border: NSColor, foregroundColor: NSColor) -> CGImage {
    return generateImage(NSMakeSize(38, 38), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fillEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2.0, height: size.height - 2.0)))
        ctx.setLineWidth(1.0)
        ctx.setStrokeColor(border.withAlphaComponent(0.7).cgColor)
        //ctx.strokeEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2.0, height: size.height - 2.0)))
        
        let icon = NSImage(named: "Icon_DialogSendingError")!.precomposed(foregroundColor)
        let imageRect = NSMakeRect(floorToScreenPixels(System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height)
        
        ctx.draw(icon, in: imageRect)
    })!
}


func generateSettingsIcon(_ icon: CGImage) -> CGImage {
    return generateImage(NSMakeSize(24, 24), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.setFillColor(.white)
        ctx.fill(size.bounds.insetBy(dx: 3, dy: 3))
        ctx.draw(icon, in: CGRect(origin: CGPoint(), size: size))
    }, scale: System.backingScale)!
}

func generateEmptySettingsIcon() -> CGImage {
    return generateImage(NSMakeSize(24, 24), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
    })!
}


private func generateSettingsActiveIcon(_ icon: CGImage, background: NSColor) -> CGImage {
    return generateImage(NSMakeSize(24, 24), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.setFillColor(background.cgColor)
        ctx.fill(size.bounds.insetBy(dx: 3, dy: 3))
        ctx.draw(icon, in: CGRect(origin: CGPoint(), size: size))
    }, scale: System.backingScale)!
}

private func generatePremiumIcon(_ icon: CGImage) -> CGImage {
    return generateImage(NSMakeSize(24, 24), contextGenerator: { size, ctx in
        ctx.clear(size.bounds)
        ctx.round(size, 5)
        
        let colors = premiumGradient.compactMap { $0.cgColor } as NSArray
        
        let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
        
        var locations: [CGFloat] = []
        for i in 0 ..< colors.count {
            locations.append(delta * CGFloat(i))
        }
        let colorSpace = deviceColorSpace
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations)!
        
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: size.width, y: size.height), options: CGGradientDrawingOptions())

        let icon = generateImage(icon.backingSize, contextGenerator: { size, ctx in
            ctx.clear(size.bounds)
            ctx.clip(to: size.bounds, mask: icon)
            ctx.setFillColor(.white)
            ctx.fill(size.bounds)
        })!
        
        ctx.draw(icon, in: size.bounds.focus(icon.backingSize))
        
    })!
}


private func generateStickersEmptySearch(color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(100, 100), contextGenerator: { size, ctx in
        let rect = CGRect(origin: CGPoint(), size: size)
        ctx.clear(rect)
        
        let icon = #imageLiteral(resourceName: "Icon_EmptySearchResults").precomposed(color)
        let imageSize = icon.backingSize.fitted(size)
        ctx.draw(icon, in: rect.focus(imageSize))
    }, scale: 1.0)!
}

private func generateAlertCheckBoxSelected(backgroundColor: NSColor) -> CGImage {
    return generateImage(NSMakeSize(14, 14), contextGenerator: { size, ctx in
        let rect = NSMakeRect(0, 0, size.width, size.height)
        ctx.clear(rect)
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.round(size, 2)
        ctx.fill(rect)

        let icon = #imageLiteral(resourceName: "Icon_AlertCheckBoxMark").precomposed()
        ctx.draw(icon, in: NSMakeRect((rect.width - icon.backingSize.width) / 2, (rect.height - icon.backingSize.height) / 2, icon.backingSize.width, icon.backingSize.height))
        
    })!
}
private func generateAlertCheckBoxUnselected(border: NSColor) -> CGImage {
    return generateImage(NSMakeSize(14, 14), contextGenerator: { size, ctx in
        let rect = NSMakeRect(0, 0, size.width, size.height)
        ctx.clear(rect)
        ctx.setStrokeColor(border.cgColor)
        ctx.setLineWidth(3.0)
        ctx.round(size, 2)
        ctx.stroke(rect)
    })!
}


private func generateTransparentBackground() -> CGImage {
    return generateImage(NSMakeSize(20, 20), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.setFillColor(NSColor(0xcbcbcb).cgColor)
        ctx.fill(NSMakeRect(0, 0, 10, 10))
        ctx.setFillColor(NSColor(0xfdfdfd).cgColor)
        ctx.fill(NSMakeRect(10, 0, 10, 10))
        
        ctx.setFillColor(NSColor(0xfdfdfd).cgColor)
        ctx.fill(NSMakeRect(0, 10, 10, 10))
        ctx.setFillColor(NSColor(0xcbcbcb).cgColor)
        ctx.fill(NSMakeRect(10, 10, 10, 10))

    })!
}

private func generateLottieTransparentBackground() -> CGImage {
    return generateImage(NSMakeSize(10, 10), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.setFillColor(.black)
        ctx.fill(NSMakeRect(0, 0, 5, 5))
        ctx.setFillColor(NSColor.lightGray.cgColor)
        ctx.fill(NSMakeRect(5, 0, 5, 5))
        
        ctx.setFillColor(NSColor.lightGray.cgColor)
        ctx.fill(NSMakeRect(0, 5, 5, 5))
        ctx.setFillColor(.black)
        ctx.fill(NSMakeRect(5, 5, 5, 5))
        
    })!
}

private func generateIVAudioPlay(color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(40, 40), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(3)
        ctx.strokeEllipse(in: NSMakeRect(2, 2, size.width - 4, size.height - 4))
        let icon = #imageLiteral(resourceName: "Icon_ChatMusicPlay").precomposed(color)
        
        ctx.draw(icon, in: NSMakeRect(floorToScreenPixels(System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height))
        
    })!
}

private func generateIVAudioPause(color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(40, 40), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(3)
        ctx.strokeEllipse(in: NSMakeRect(2, 2, size.width - 4, size.height - 4))
        let icon = #imageLiteral(resourceName: "Icon_ChatMusicPause").precomposed(color)
        ctx.draw(icon, in: NSMakeRect(floorToScreenPixels(System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height))
    })!
}

private func generateBadgeMention(image: NSImage, backgroundColor: NSColor, foregroundColor: NSColor) -> CGImage {
    return generateImage(NSMakeSize(20, 20), rotatedContext: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.round(size, size.width/2)
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
        let icon = image.precomposed(foregroundColor, flipVertical: true)
        let imageRect = NSMakeRect(floorToScreenPixels(System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height)
        ctx.draw(icon, in: imageRect)
    })!
}

func generateChatGroupToggleSelected(foregroundColor: NSColor, backgroundColor: NSColor) -> CGImage {
    let icon = #imageLiteral(resourceName: "Icon_Check").precomposed(foregroundColor)
    return generateImage(NSMakeSize(icon.backingSize.width + 2, icon.backingSize.height + 2), contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.round(size, size.width/2)
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
        let imageRect = NSMakeRect((size.width - icon.backingSize.width) / 2, (size.height - icon.backingSize.height) / 2, icon.backingSize.width, icon.backingSize.height)
        ctx.draw(icon, in: imageRect)
    })!
}

func generateCheckSelected(foregroundColor: NSColor, backgroundColor: NSColor) -> CGImage {
    let icon = #imageLiteral(resourceName: "Icon_Check").precomposed(foregroundColor)
    return generateImage(NSMakeSize(icon.backingSize.width, icon.backingSize.height), contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fillEllipse(in: NSMakeRect(2, 2, size.width - 4, size.height - 4))
        ctx.draw(icon, in: size.bounds)
    })!
}


private func generateChatGroupToggleSelectionForeground(foregroundColor: NSColor, backgroundColor: NSColor) -> CGImage {
    let icon = #imageLiteral(resourceName: "Icon_SelectionUncheck").precomposed(foregroundColor)
    return generateImage(NSMakeSize(icon.backingSize.width + 4, icon.backingSize.height + 4), contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.round(size, size.width/2)
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
        let imageRect = NSMakeRect((size.width - icon.backingSize.width) / 2, (size.height - icon.backingSize.height) / 2, icon.backingSize.width, icon.backingSize.height)
        ctx.draw(icon, in: imageRect)
    })!
}

func generateChatGroupToggleUnselected(foregroundColor: NSColor, backgroundColor: NSColor) -> CGImage {
    let icon = #imageLiteral(resourceName: "Icon_SelectionUncheck").precomposed(foregroundColor)
    return generateImage(NSMakeSize(icon.backingSize.width, icon.backingSize.height), contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.round(size, size.width/2)
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
        let imageRect = NSMakeRect((size.width - icon.backingSize.width) / 2, (size.height - icon.backingSize.height) / 2, icon.backingSize.width, icon.backingSize.height)
        ctx.draw(icon, in: imageRect)
    })!
}

func generateAvatarPlaceholder(foregroundColor: NSColor, size: NSSize, cornerRadius: CGFloat = -1, bubble: Bool = false) -> CGImage {
    return generateImage(size, contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        if bubble {
            let rect = CGRect(origin: CGPoint(), size: size)
            ctx.translateBy(x: rect.midX, y: rect.midY)
            ctx.scaleBy(x: 1.0, y: -1.0)
            ctx.translateBy(x: -rect.midX, y: -rect.midY)
            addAvatarBubblePath(context: ctx, rect: rect)
            ctx.translateBy(x: rect.midX, y: rect.midY)
            ctx.scaleBy(x: 1.0, y: -1.0)
            ctx.translateBy(x: -rect.midX, y: -rect.midY)
            ctx.clip()
        } else {
            if cornerRadius == -1 {
                ctx.round(size, size.width/2)
            } else {
                ctx.round(size, min(cornerRadius, size.width / 2))
            }
        }
        
        ctx.setFillColor(foregroundColor.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
    })!
}

private func deleteItemIcon(_ color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(24,24), contextGenerator: { (size, ctx) in
        ctx.clear(NSMakeRect(0,0,size.width,size.height))
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: NSMakeRect(0,0,size.width,size.height))
        ctx.setFillColor(.white)
        ctx.fill(NSMakeRect(6,11,12,2))
    })!
}
private func generateStickerBackground(_ size: NSSize, _ color: NSColor) -> CGImage {
    return generateImage(size, contextGenerator: { size,ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.round(size)
        ctx.setFillColor(color.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
    })!
}


private func downloadFilePauseIcon(_ color: NSColor) -> CGImage {
    return generateImage(CGSize(width: 11.0, height: 11.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 2.0, y: 0.0, width: 2.0, height: 11.0 - 1.0))
        context.fill(CGRect(x: 2.0 + 2.0 + 2.0, y: 0.0, width: 2.0, height: 11.0 - 1.0))
    })!
}


private func generateSendingFrame(_ color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(12, 12), contextGenerator: {(size,ctx) in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(1.0)
        ctx.strokeEllipse(in: NSMakeRect(1.0, 1.0,size.width - 2,size.height - 2))
    })!
}
private func generateClockMinImage(_ color: NSColor) -> CGImage {
    return generateImage(CGSize(width: 10, height: 10), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        let strokeWidth: CGFloat = 1
        context.fill(CGRect(x: (10 - strokeWidth) / 2.0, y: (10 - strokeWidth) / 2.0, width: 10 / 2.0 - strokeWidth, height: strokeWidth))
    })!
}


private func  generateChatScrolldownImage(backgroundColor: NSColor, borderColor: NSColor, arrowColor: NSColor, reversed: Bool = false) -> CGImage {
    
    let generator:(NSSize, CGContext)->Void = { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2.0, height: size.height - 2.0)))
        context.setLineWidth(1.0)
        if borderColor != .clear {
            context.setStrokeColor(borderColor.withAlphaComponent(0.7).cgColor)
            context.strokeEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2.0, height: size.height - 2.0)))
        }
        context.setStrokeColor(arrowColor.cgColor)
        context.setLineWidth(1.0)
        
        context.setStrokeColor(arrowColor.cgColor)
        let position = CGPoint(x: 9.0 - 0.5, y: 23.0)
        context.move(to: CGPoint(x: position.x + 1.0, y: position.y - 1.0))
        context.addLine(to: CGPoint(x: position.x + 10.0, y: position.y - 10.0))
        context.addLine(to: CGPoint(x: position.x + 19.0, y: position.y - 1.0))
        context.strokePath()
    }
    if !reversed {
        return generateImage(CGSize(width: 38.0, height: 38.0), contextGenerator: generator)!
    } else {
        return generateImage(CGSize(width: 38.0, height: 38.0), rotatedContext: generator)!
    }
}

private func generateConfirmDeleteMessagesAccessory(backgroundColor: NSColor) -> CGImage {
    return generateImage(NSMakeSize(50, 50), contextGenerator: { size, ctx in
        let rect = NSMakeRect(0, 0, size.width, size.height)
        ctx.clear(rect)
        ctx.round(size, size.height / 2)
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(rect)
        let icon = #imageLiteral(resourceName: "Icon_ConfirmDeleteMessagesAccessory").precomposed()
        let point = NSMakePoint((rect.width - icon.backingSize.width) / 2, (rect.height - icon.backingSize.height) / 2)
        ctx.draw(icon, in: NSMakeRect(point.x, point.y, icon.backingSize.width, icon.backingSize.height))
    })!
}

private func generateConfirmPinAccessory(backgroundColor: NSColor) -> CGImage {
    return generateImage(NSMakeSize(50, 50), contextGenerator: { size, ctx in
        let rect = NSMakeRect(0, 0, size.width, size.height)
        ctx.clear(rect)
        ctx.round(size, size.height / 2)
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(rect)
        let icon = #imageLiteral(resourceName: "Icon_ConfirmPinAccessory").precomposed()
        let point = NSMakePoint((rect.width - icon.backingSize.width) / 2, (rect.height - icon.backingSize.height) / 2)
        ctx.draw(icon, in: NSMakeRect(point.x, point.y, icon.backingSize.width, icon.backingSize.height))
    })!
}

private func generateConfirmDeleteChatAccessory(backgroundColor: NSColor, foregroundColor: NSColor) -> CGImage {
    return generateImage(NSMakeSize(34, 34), contextGenerator: { size, ctx in
        let rect = NSMakeRect(0, 0, size.width, size.height)
        ctx.clear(rect)
        ctx.round(size, size.height / 2)
        
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(rect)
        
        ctx.setFillColor(foregroundColor.cgColor)
        ctx.fillEllipse(in: NSMakeRect(2, 2, size.width - 4, size.height - 4))
        let icon = #imageLiteral(resourceName: "Icon_ConfirmDeleteChatAccessory").precomposed()
        let point = NSMakePoint((rect.width - icon.backingSize.width) / 2, (rect.height - icon.backingSize.height) / 2)
        ctx.draw(icon, in: NSMakeRect(point.x, point.y, icon.backingSize.width, icon.backingSize.height))
    })!
}



/*

 */

private func generateRecentActionsTriangle(_ color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(10, 8), contextGenerator: { (size, ctx) in
        let bounds = NSMakeRect(0, 0, size.width, size.height)
        ctx.clear(bounds)
        ctx.beginPath()
        ctx.move(to: NSMakePoint(bounds.minX, bounds.minY))
        ctx.addLine(to: NSMakePoint(bounds.midX, bounds.maxY))
        ctx.addLine(to: NSMakePoint(bounds.maxX, bounds.minY))
        ctx.closePath()
        
        ctx.setFillColor(color.cgColor);
        ctx.fillPath();
        
    }, opaque: false)!
}

var blueActionButton:ControlStyle {
    return ControlStyle(font: NSFont.normal(.title), foregroundColor: theme.colors.accent)
}
var redActionButton:ControlStyle {
    return ControlStyle(font: .normal(.title), foregroundColor: theme.colors.redUI)
}



struct ActivitiesTheme : Equatable {
    let text:[CGImage]
    let uploading:[CGImage]
    let recording:[CGImage]
    let choosingSticker:[CGImage]
    let textColor:NSColor
    let backgroundColor:NSColor
    init(text:[CGImage], uploading:[CGImage], recording:[CGImage], choosingSticker: [CGImage], textColor:NSColor, backgroundColor:NSColor) {
        self.text = text
        self.uploading = uploading
        self.recording = recording
        self.choosingSticker = choosingSticker
        self.textColor = textColor
        self.backgroundColor = backgroundColor
    }
    
    static func ==(lhs: ActivitiesTheme, rhs: ActivitiesTheme) -> Bool {
        return lhs.textColor.argb == rhs.textColor.argb && lhs.backgroundColor.argb == rhs.backgroundColor.argb
    }
}


final class TelegramTabBarTheme  {
    let color: NSColor
    let selectedColor: NSColor
    let badgeTextColor: NSColor
    let badgeColor: NSColor
    private let resources: PresentationsResourceCache = PresentationsResourceCache()
    init(color: NSColor, selectedColor: NSColor, badgeTextColor: NSColor, badgeColor: NSColor) {
        self.color = color
        self.selectedColor = selectedColor
        self.badgeTextColor = badgeTextColor
        self.badgeColor = badgeColor
    }
    
    func icon(key:Int32, image: NSImage, selected: Bool) -> CGImage {
        let color = self.color
        let selectedColor = self.selectedColor
        return resources.image(key + (selected ? 10 : 0), { () -> CGImage in
            return image.precomposed(selected ? selectedColor : color)
        })
    }
}


final class TelegramChatListTheme {
    let selectedBackgroundColor: NSColor
    let singleLayoutSelectedBackgroundColor: NSColor
    let activeDraggingBackgroundColor: NSColor
    let pinnedBackgroundColor: NSColor
    let contextMenuBackgroundColor: NSColor
    
    let textColor: NSColor
    let grayTextColor: NSColor
    let secretChatTextColor: NSColor
    let peerTextColor: NSColor
    
    let activityColor: NSColor
    let activitySelectedColor: NSColor
    let activityContextMenuColor: NSColor
    let activityPinnedColor: NSColor
    
    let badgeTextColor: NSColor
    let badgeBackgroundColor: NSColor
    let badgeSelectedTextColor: NSColor
    let badgeSelectedBackgroundColor: NSColor
    let badgeMutedTextColor: NSColor
    let badgeMutedBackgroundColor: NSColor
    

    init(selectedBackgroundColor: NSColor, singleLayoutSelectedBackgroundColor: NSColor, activeDraggingBackgroundColor: NSColor, pinnedBackgroundColor: NSColor, contextMenuBackgroundColor: NSColor, textColor: NSColor, grayTextColor: NSColor, secretChatTextColor: NSColor, peerTextColor: NSColor, activityColor: NSColor, activitySelectedColor: NSColor, activityContextMenuColor: NSColor, activityPinnedColor: NSColor, badgeTextColor: NSColor, badgeBackgroundColor: NSColor, badgeSelectedTextColor: NSColor, badgeSelectedBackgroundColor: NSColor,  badgeMutedTextColor: NSColor, badgeMutedBackgroundColor: NSColor) {
        
        
        
    
        
        self.selectedBackgroundColor = selectedBackgroundColor
        self.singleLayoutSelectedBackgroundColor = singleLayoutSelectedBackgroundColor
        self.activeDraggingBackgroundColor = activeDraggingBackgroundColor
        self.pinnedBackgroundColor = pinnedBackgroundColor
        self.contextMenuBackgroundColor = contextMenuBackgroundColor
        self.textColor = textColor
        self.grayTextColor = grayTextColor
        self.secretChatTextColor = secretChatTextColor
        self.peerTextColor = peerTextColor
        
        self.activityColor = activityColor
        self.activitySelectedColor = activitySelectedColor
        self.activityPinnedColor = activityPinnedColor
        self.activityContextMenuColor = activityContextMenuColor
        
        self.badgeTextColor = badgeTextColor
        self.badgeBackgroundColor = badgeBackgroundColor
        self.badgeSelectedTextColor = badgeSelectedTextColor
        self.badgeSelectedBackgroundColor = badgeSelectedBackgroundColor
        self.badgeMutedTextColor = badgeMutedTextColor
        self.badgeMutedBackgroundColor = badgeMutedBackgroundColor

    }
}


extension WallpaperSettings {
    func withUpdatedBlur(_ blur: Bool) -> WallpaperSettings {
        return WallpaperSettings(blur: blur, motion: self.motion, colors: self.colors, intensity: self.intensity)
    }
    func withUpdatedColor(_ color: UInt32?) -> WallpaperSettings {
        return WallpaperSettings(blur: self.blur, motion: self.motion, colors: color != nil ? [color!] : [], intensity: self.intensity)
    }
    
    func isSemanticallyEqual(to other: WallpaperSettings) -> Bool {
        return self.colors == other.colors && self.intensity == other.intensity
    }
}

public enum TelegramMediaImageRepresentationDecodingError: Error {
    case generic
}



func getAverageColor(_ image: NSImage) -> NSColor {
    let context = DrawingContext(size: CGSize(width: 1.0, height: 1.0), scale: 1.0, clear: false)
    context.withFlippedContext({ [weak image] context in
        if let cgImage = image {
            context.draw(cgImage.cgImage(forProposedRect: nil, context: nil, hints: nil)!, in: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))
        }
    })
    var color = context.colorAt(CGPoint())
    
    var hue: CGFloat = 0.0
    var saturation: CGFloat = 0.0
    var brightness: CGFloat = 0.0
    var alpha: CGFloat = 0.0
//    color = color.usingColorSpaceName(NSColorSpaceName.deviceRGB)!
    color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    saturation = min(1.0, saturation + 0.1 + 0.1 * (1.0 - saturation))
    brightness = max(0.0, brightness * 0.65)
    alpha = 0.5
    color = NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    
    return color
}

func getAverageColor(_ color: NSColor) -> NSColor {
    var hue: CGFloat = 0.0
    var saturation: CGFloat = 0.0
    var brightness: CGFloat = 0.0
    var alpha: CGFloat = 0.0
    let color = color.usingColorSpaceName(NSColorSpaceName.deviceRGB)!
    color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    saturation = min(1.0, saturation + 0.1 + 0.1 * (1.0 - saturation))
    brightness = max(0.0, brightness * 0.65)
    alpha = 0.5
    
    return NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
}

func backgroundExists(_ wallpaper: Wallpaper, palette: ColorPalette) -> Bool {
    #if !SHARE
    var backgroundMode: TableBackgroundMode
    switch wallpaper {
    case .builtin:
        return true
    case let.color(color):
        return true
    case let .gradient(_, colors, rotation):
        return true
    case let .image(representation, settings):
        if let resource = largestImageRepresentation(representation)?.resource {
            return FileManager.default.fileExists(atPath: wallpaperPath(resource, palette: palette, settings: settings))
        } else {
            return false
        }
        
    case let .file(_, file, settings, _):
        return FileManager.default.fileExists(atPath: wallpaperPath(file.resource, palette: palette, settings: settings))
    case .none:
        return true
    case let .custom(representation, blurred):
        return FileManager.default.fileExists(atPath: wallpaperPath(representation.resource, palette: palette, settings: WallpaperSettings(blur: blurred)))
    case let .emoticon(emoticon):
        return true
    }
    #else
    return false
    #endif
}

func generateBackgroundMode(_ wallpaper: Wallpaper, palette: ColorPalette, maxSize: NSSize = NSMakeSize(1040, 1580), emoticonThemes: [(String, TelegramPresentationTheme)]) -> TableBackgroundMode {
    #if !SHARE
    var backgroundMode: TableBackgroundMode
    switch wallpaper {
    case .builtin:
        backgroundMode = TelegramPresentationTheme.defaultBackground(palette)
    case let.color(color):
        backgroundMode = .color(color: NSColor(color))
    case let .gradient(_, colors, rotation):
        backgroundMode = .gradient(colors: colors.map({ NSColor(argb: $0).withAlphaComponent(1.0) }), rotation: rotation)
    case let .image(representation, settings):
        if let resource = largestImageRepresentation(representation)?.resource, let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(resource, settings: settings))) {
            backgroundMode = .background(image: image, intensity: settings.intensity, colors: settings.colors.map { NSColor(argb: $0) }, rotation: settings.rotation)
        } else {
            backgroundMode = TelegramPresentationTheme.defaultBackground(palette)
        }
        
    case let .file(_, file, settings, _):
        if let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(file.resource, palette: palette, settings: settings))) {
            backgroundMode = .background(image: image, intensity: settings.intensity, colors: settings.colors.map { NSColor(argb: $0) }, rotation: settings.rotation)
        } else {
            backgroundMode = TelegramPresentationTheme.defaultBackground(palette)
        }
    case .none:
        backgroundMode = .color(color: palette.chatBackground)
    case let .custom(representation, blurred):
        if let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(representation.resource, settings: WallpaperSettings(blur: blurred)))) {
            backgroundMode = .background(image: image, intensity: nil, colors: nil, rotation: nil)
        } else {
            backgroundMode = TelegramPresentationTheme.defaultBackground(palette)
        }
    case let .emoticon(emoticon):
        if let first = emoticonThemes.first(where: { $0.0.emojiUnmodified == emoticon.emojiUnmodified }) {
            backgroundMode = first.1.backgroundMode
        } else {
            backgroundMode = .plain
        }
    }
    return backgroundMode
    #else
    return .plain
    #endif
}
#if !SHARE
private func builtinBackgound(_ palette: ColorPalette) -> NSImage {
    let data = try? Data(contentsOf: Bundle.main.url(forResource: "builtin-wallpaper-svg", withExtension: nil)!)
    if let data = data {
        var image = drawSvgImageNano(TGGUnzipData(data, 8 * 1024 * 1024)!, NSMakeSize(400, 800))!
        
        let intense = CGFloat(0.5)
        if palette.isDark {
            image = generateImage(image.size, contextGenerator: { size, ctx in
                ctx.clear(size.bounds)
                ctx.setFillColor(NSColor.black.cgColor)
                ctx.fill(size.bounds)
                ctx.clip(to: size.bounds, mask: image._cgImage!)
                
                ctx.clear(size.bounds)
                ctx.setFillColor(NSColor.black.withAlphaComponent(1 - intense).cgColor)
                ctx.fill(size.bounds)
            })!._NSImage
        }
        return image
    } else {
        return generateImage(NSMakeSize(400, 800), contextGenerator: { size, ctx in
            ctx.clear(size.bounds)
            ctx.setFillColor(palette.background.cgColor)
        })!._NSImage
    }
}
#endif
class TelegramPresentationTheme : PresentationTheme {
    let chatList:TelegramChatListTheme
    #if !SHARE
    let chat: TelegramChatColors
    #endif
    let cloudTheme: TelegramTheme?
    let tabBar:TelegramTabBarTheme
    let icons: TelegramIconsTheme
    let bubbled: Bool
    let wallpaper: ThemeWallpaper
    let emoticonThemes: [(String, TelegramPresentationTheme)]
    
    
    #if !SHARE
    static func defaultBackground(_ palette: ColorPalette)-> TableBackgroundMode {
        return .background(image: builtinBackgound(palette), intensity: nil, colors: [0xdbddbb, 0x6ba587, 0xd5d88d, 0x88b884].map { .init(argb: $0) }, rotation: nil)
    }
    #endif
    

   
    private var _emptyChatNavigationPrev: CGImage?
    private var _emptyChatNavigationNext: CGImage?
    var emptyChatNavigationPrev: CGImage {
        if let icon = _emptyChatNavigationPrev {
            return icon
        } else {
            let new = NSImage(named: "Icon_GeneralNext")!.precomposed(self.chatServiceItemTextColor, flipHorizontal: true)
            _emptyChatNavigationPrev = new
            return new
        }
    }
    var emptyChatNavigationNext: CGImage {
        if let icon = _emptyChatNavigationNext {
            return icon
        } else {
            let new = NSImage(named: "Icon_GeneralNext")!.precomposed(self.chatServiceItemTextColor)
            _emptyChatNavigationNext = new
            return new
        }
    }
    
    private var _chatReadMarkServiceOverlayBubble1: CGImage?
    private var _chatReadMarkServiceOverlayBubble2: CGImage?
    var chatReadMarkServiceOverlayBubble1: CGImage {
        if let icon = _chatReadMarkServiceOverlayBubble1 {
            return icon
        } else {
            let new = NSImage(named: "Icon_MessageCheckMark1")!.precomposed(self.chatServiceItemTextColor)
            _chatReadMarkServiceOverlayBubble1 = new
            return new
        }
    }
    var chatReadMarkServiceOverlayBubble2: CGImage {
        if let icon = _chatReadMarkServiceOverlayBubble2 {
            return icon
        } else {
            let new = NSImage(named: "Icon_MessageCheckmark2")!.precomposed(self.chatServiceItemTextColor)
            _chatReadMarkServiceOverlayBubble2 = new
            return new
        }
    }
    
    private var _chatSendingOverlayServiceFrame: CGImage?
    private var _chatSendingOverlayServiceHour: CGImage?
    private var _chatSendingOverlayServiceMin: CGImage?
    var chatSendingOverlayServiceFrame: CGImage {
        if let icon = _chatSendingOverlayServiceFrame {
            return icon
        } else {
            let new = generateSendingFrame(self.chatServiceItemTextColor)
            _chatSendingOverlayServiceFrame = new
            return new
        }
    }
    var chatSendingOverlayServiceHour: CGImage {
        if let icon = _chatSendingOverlayServiceHour {
            return icon
        } else {
            let new = generateClockMinImage(self.chatServiceItemTextColor)
            _chatSendingOverlayServiceHour = new
            return new
        }
    }
    var chatSendingOverlayServiceMin: CGImage {
        if let icon = _chatSendingOverlayServiceMin {
            return icon
        } else {
            let new = generateClockMinImage(self.chatServiceItemTextColor)
            _chatSendingOverlayServiceMin = new
            return new
        }
    }
    
    private var _chatChannelViewsOverlayServiceBubble: CGImage?
    var chatChannelViewsOverlayServiceBubble: CGImage {
        if let icon = _chatChannelViewsOverlayServiceBubble {
            return icon
        } else {
            let new = #imageLiteral(resourceName: "Icon_ChannelViews").precomposed(self.chatServiceItemTextColor)
            _chatChannelViewsOverlayServiceBubble = new
            return new
        }
    }
    
    private var _chatPaidMessageOverlayServiceBubble: CGImage?
    var chatPaidMessageOverlayServiceBubble: CGImage {
        if let icon = _chatPaidMessageOverlayServiceBubble {
            return icon
        } else {
            let new = NSImage(resource: .iconPaidMessageStatus).precomposed(self.chatServiceItemTextColor)
            _chatPaidMessageOverlayServiceBubble = new
            return new
        }
    }
    
    private var _chat_pinned_message_overlay_service_bubble: CGImage?
    var chat_pinned_message_overlay_service_bubble: CGImage {
        if let icon = _chat_pinned_message_overlay_service_bubble {
            return icon
        } else {
            let new = NSImage(named: "Icon_ChatPinnedMessage")!.precomposed(self.chatServiceItemTextColor)
            _chat_pinned_message_overlay_service_bubble = new
            return new
        }
    }
    
    
    private var _chat_reply_count_overlay_service_bubble: CGImage?
    var chat_reply_count_overlay_service_bubble: CGImage {
        if let icon = _chat_reply_count_overlay_service_bubble {
            return icon
        } else {
            let new = NSImage(named: "Icon_ChatRepliesCount")!.precomposed(self.chatServiceItemTextColor)
            _chat_reply_count_overlay_service_bubble = new
            return new
        }
    }
    
    
    private var _chat_comments_overlay: CGImage?
    var chat_comments_overlay: CGImage {
        if let icon = _chat_comments_overlay {
            return icon
        } else {
            let new = NSImage(named: "Icon_ChannelComments_Overlay")!.precomposed(self.chatServiceItemTextColor)
            _chat_comments_overlay = new
            return new
        }
    }
    private var _chat_toggle_selected: CGImage?
    var chat_toggle_selected: CGImage {
        if let icon = _chat_toggle_selected {
            return icon
        } else {
            let new = generateChatGroupToggleSelected(foregroundColor: colors.accentIcon, backgroundColor: colors.underSelectedColor)
            _chat_toggle_selected = new
            return new
        }
    }
    private var _chat_toggle_unselected: CGImage?
    var chat_toggle_unselected: CGImage {
        if let icon = _chat_toggle_unselected {
            return icon
        } else {
            let new = generateChatGroupToggleUnselected(foregroundColor: chatBackground ==  chatServiceItemColor ? colors.grayIcon.withAlphaComponent(0.6) : chatServiceItemColor, backgroundColor: NSColor.black.withAlphaComponent(0.05))
            _chat_toggle_unselected = new
            return new
        }
    }
    
    private var _empty_chat_showtips: CGImage?
    var empty_chat_showtips: CGImage {
        if let icon = _empty_chat_showtips {
            return icon
        } else {
            _empty_chat_showtips = NSImage(named: "Icon_Empty_ShowTips")!.precomposed(chatServiceItemTextColor)
            return _empty_chat_showtips!
        }
    }
    private var _empty_chat_hidetips: CGImage?
    var empty_chat_hidetips: CGImage {
        if let icon = _empty_chat_hidetips {
            return icon
        } else {
            _empty_chat_hidetips = NSImage(named: "Icon_Empty_CloseTips")!.precomposed(chatServiceItemTextColor)
            return _empty_chat_hidetips!
        }
    }

    var blurServiceColor: NSColor {
        return NSColor.black.withAlphaComponent(colors.isDark ? 0.5 : 0.25)
    }
    
    private var _chatServiceItemColor: NSColor?
    var chatServiceItemColor: NSColor {
        if let value = _chatServiceItemColor {
            return value
        } else {
            let chatServiceItemColor: NSColor
            if bubbled {
                switch backgroundMode {
                case let .background(image, _, colors, _):
                    if let colors = colors, colors.count > 0 {
                        let blended = NSColor.average(of: colors).withAlphaComponent(0.6)
                        if self.colors.isDark {
                            chatServiceItemColor = NSColor.average(of: [getAverageColor(image), getAverageColor(blended)])
                        } else {
                            chatServiceItemColor = getAverageColor(blended)
                        }
                    } else {
                        chatServiceItemColor = getAverageColor(image)
                    }
                case let .color(color):
                    if color != colors.background {
                        chatServiceItemColor = getAverageColor(color)
                    } else {
                        chatServiceItemColor = color
                    }
                case let .gradient(colors, _):
                    let blended = colors.reduce(colors.first!, { color, with in
                        return color.blended(withFraction: 0.5, of: with)!
                    })
                    chatServiceItemColor = getAverageColor(blended)

                case let .tiled(image):
                    chatServiceItemColor = getAverageColor(image)
                case .plain:
                    chatServiceItemColor = colors.chatBackground
                }
            } else {
                chatServiceItemColor = colors.chatBackground
            }
           
            self._chatServiceItemColor = chatServiceItemColor
            return chatServiceItemColor
        }
    }
    private var _chatServiceItemTextColor: NSColor?
    var chatServiceItemTextColor: NSColor {
        if let value = _chatServiceItemTextColor {
            return value
        } else {
            let chatServiceItemTextColor: NSColor
            if bubbled {
                switch backgroundMode {
                case .background:
                    chatServiceItemTextColor = NSColor(rgb: 0xffffff)
                case let .color(color):
                    if color != colors.background {
                        chatServiceItemTextColor = chatServiceItemColor.brightnessAdjustedColor
                    } else {
                        chatServiceItemTextColor = colors.grayText
                    }
                case .gradient:
                    chatServiceItemTextColor = chatServiceItemColor.brightnessAdjustedColor
                case .tiled:
                    chatServiceItemTextColor = chatServiceItemColor.brightnessAdjustedColor
                case .plain:
                    chatServiceItemTextColor = colors.grayText
                }
            } else {
                chatServiceItemTextColor = colors.grayText
            }
            
            self._chatServiceItemTextColor = chatServiceItemTextColor
            return chatServiceItemTextColor
        }
    }
    
    let fontSize: CGFloat
    
    var hasWallpaper: Bool {
        return controllerBackgroundMode.hasWallpaper
    }
    var shouldBlurService: Bool {
        
        if #available(macOS 10.14, *) {
            return hasWallpaper
        } else {
            return false
        }
    }
    
    var controllerBackgroundMode: TableBackgroundMode {
        if self.bubbled {
            return self.backgroundMode
        } else {
            return .color(color: colors.chatBackground)
        }
    }
    
    var chatBackground: NSColor {
        return self.colors.chatBackground
    }
    
    var backgroundSize: NSSize = NSMakeSize(1040, 1580)
    
    private var _backgroundMode: TableBackgroundMode?
    var backgroundMode: TableBackgroundMode {
        if let value = _backgroundMode {
            return value
        } else {
            
            let backgroundMode: TableBackgroundMode
            if let cached = cachedBackground(wallpaper.wallpaper, palette: colors) {
                backgroundMode = cached
            } else {
                backgroundMode = generateBackgroundMode(wallpaper.wallpaper, palette: colors, maxSize: backgroundSize, emoticonThemes: self.emoticonThemes)
                switch wallpaper.wallpaper {
                case .emoticon:
                    if backgroundMode != .plain {
                        cacheBackground(wallpaper.wallpaper, palette: colors, background: backgroundMode)
                    }
                default:
                    cacheBackground(wallpaper.wallpaper, palette: colors, background: backgroundMode)
                }
            }
            
            self._backgroundMode = backgroundMode
            return backgroundMode
        }
    }
    init(colors: ColorPalette, cloudTheme: TelegramTheme?, search: SearchTheme, chatList: TelegramChatListTheme, tabBar: TelegramTabBarTheme, icons: TelegramIconsTheme, bubbled: Bool, fontSize: CGFloat, wallpaper: ThemeWallpaper, generated: Bool = false, emoticonThemes: [(String, TelegramPresentationTheme)] = [], backgroundSize: NSSize = NSMakeSize(1040, 1580)) {
        self.chatList = chatList
        #if !SHARE
            self.chat = TelegramChatColors(colors, bubbled)
        #endif
        self.backgroundSize = backgroundSize
        self.tabBar = tabBar
        self.icons = icons
        self.wallpaper = wallpaper
        self.bubbled = bubbled
        self.emoticonThemes = emoticonThemes
        self.fontSize = fontSize
        self.cloudTheme = cloudTheme
        if !Thread.isMainThread && generated {
            self._backgroundMode = generateBackgroundMode(wallpaper.wallpaper, palette: colors, maxSize: backgroundSize, emoticonThemes: emoticonThemes)
        }
        super.init(colors: colors, search: search, inputTheme: .init(quote: .init(foreground: .init(main: colors.accent), icon: NSImage(resource: .iconQuote), collapse: NSImage(resource: .iconQuoteCollapse), expand: NSImage(resource: .iconQuoteExpand)), indicatorColor: colors.accent, backgroundColor: colors.background, selectingColor: colors.selectText, textColor: colors.text, accentColor: colors.accent, grayTextColor: colors.grayText, fontSize: fontSize))
    }
    
    var dark: Bool {
        return colors.isDark
    }
    #if !SHARE
    var insantPageThemeType: InstantPageThemeType {
        if colors.isDark {
            return .dark
        } else {
            return .light
        }
    }
    #endif
    
    
    deinit {
       
    }
    
    func withUpdatedColors(_ colors: ColorPalette) -> TelegramPresentationTheme {
        return TelegramPresentationTheme(colors: colors, cloudTheme: self.cloudTheme, search: self.search, chatList: self.chatList, tabBar: self.tabBar, icons: generateIcons(from: colors, bubbled: self.bubbled), bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, emoticonThemes: self.emoticonThemes, backgroundSize: self.backgroundSize)
    }
    
    func withUpdatedEmoticonThemes(_ emoticonThemes: [(String, TelegramPresentationTheme)]) -> TelegramPresentationTheme {
        return TelegramPresentationTheme(colors: colors, cloudTheme: self.cloudTheme, search: self.search, chatList: self.chatList, tabBar: self.tabBar, icons: self.icons, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, emoticonThemes: emoticonThemes, backgroundSize: self.backgroundSize)
    }
    
    func withUpdatedChatMode(_ bubbled: Bool) -> TelegramPresentationTheme {
        return TelegramPresentationTheme(colors: colors, cloudTheme: self.cloudTheme, search: self.search, chatList: self.chatList, tabBar: self.tabBar, icons: generateIcons(from: colors, bubbled: bubbled), bubbled: bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, emoticonThemes: self.emoticonThemes, backgroundSize: self.backgroundSize)
    }
    func new() -> TelegramPresentationTheme {
        return TelegramPresentationTheme(colors: self.colors, cloudTheme: self.cloudTheme, search: self.search, chatList: self.chatList, tabBar: self.tabBar, icons: self.icons, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, emoticonThemes: self.emoticonThemes, backgroundSize: self.backgroundSize)
    }

    
    func withUpdatedBackgroundSize(_ size: NSSize) -> TelegramPresentationTheme {
        self.backgroundSize = size
        return self
    }
    
    func withUpdatedWallpaper(_ wallpaper: ThemeWallpaper) -> TelegramPresentationTheme {
        return TelegramPresentationTheme(colors: self.colors, cloudTheme: self.cloudTheme, search: self.search, chatList: self.chatList, tabBar: self.tabBar, icons: generateIcons(from: colors, bubbled: self.bubbled), bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: wallpaper, emoticonThemes: self.emoticonThemes, backgroundSize: self.backgroundSize)
    }
    
    func activity(key:Int32, foregroundColor: NSColor, backgroundColor: NSColor) -> ActivitiesTheme {
        return activityResources.object(key, { () -> Any in
            return ActivitiesTheme(text: textActivityAnimation(foregroundColor), uploading: uploadFileActivityAnimation(foregroundColor, backgroundColor), recording: recordVoiceActivityAnimation(foregroundColor), choosingSticker: choosingStickerActivityAnimation(foregroundColor), textColor: foregroundColor, backgroundColor: backgroundColor)
        }) as! ActivitiesTheme
    }
    
    private let activityResources: PresentationsResourceCache = PresentationsResourceCache()
    
}

let _themeSignal:ValuePromise<TelegramPresentationTheme> = ValuePromise(ignoreRepeated: true)

var themeSignal:Signal<TelegramPresentationTheme, NoError> {
    return _themeSignal.get() |> distinctUntilChanged |> deliverOnMainQueue
}

extension ColorPalette {
    var transparentBackground: NSColor {
        return NSColor(patternImage: NSImage(cgImage: theme.icons.transparentBackground, size: theme.icons.transparentBackground.backingSize))
    }
    var lottieTransparentBackground: NSColor {
        return NSColor(patternImage: NSImage(cgImage: theme.icons.lottieTransparentBackground, size: theme.icons.lottieTransparentBackground.backingSize))
    }
}



private func generateIcons(from palette: ColorPalette, bubbled: Bool) -> TelegramIconsTheme {
    return TelegramIconsTheme(dialogMuteImage: { #imageLiteral(resourceName: "Icon_DialogMute").precomposed(palette.grayIcon) },
                              dialogMuteImageSelected: { #imageLiteral(resourceName: "Icon_DialogMute").precomposed(palette.underSelectedColor) },
                              outgoingMessageImage: { #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(palette.accentIcon, flipVertical:true) },
                                               readMessageImage: { #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(palette.accentIcon, flipVertical:true) },
                                               outgoingMessageImageSelected: { #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(palette.underSelectedColor, flipVertical:true) },
                                               readMessageImageSelected: { #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(palette.underSelectedColor, flipVertical:true) },
                                               sendingImage: { #imageLiteral(resourceName: "Icon_ChatStateSending").precomposed(palette.grayIcon, flipVertical:true) },
                                               sendingImageSelected: { #imageLiteral(resourceName: "Icon_ChatStateSending").precomposed(palette.underSelectedColor, flipVertical:true) },
                                               secretImage: { #imageLiteral(resourceName: "Icon_SecretChatLock").precomposed(palette.accent, flipVertical:true) },
                                               secretImageSelected:{  #imageLiteral(resourceName: "Icon_SecretChatLock").precomposed(palette.underSelectedColor, flipVertical:true) },
                                               pinnedImage: { #imageLiteral(resourceName: "Icon_ChatListPinned").precomposed(palette.grayIcon, flipVertical:true) },
                                               pinnedImageSelected: { #imageLiteral(resourceName: "Icon_ChatListPinned").precomposed(palette.underSelectedColor, flipVertical:true) },
                                               verifiedImage: { generateDialogVerify(background: palette.underSelectedColor, foreground: palette.basicAccent) },
                                               verifiedImageSelected: { generateDialogVerify(background: palette.underSelectedColor, foreground: palette.basicAccent) },
                                               errorImage: { #imageLiteral(resourceName: "Icon_MessageSentFailed").precomposed(flipVertical: true) },
                                               errorImageSelected: { #imageLiteral(resourceName: "Icon_DialogSendingError").precomposed(flipVertical: true) },
                                               chatSearch: { generateChatAction(#imageLiteral(resourceName: "Icon_SearchChatMessages").precomposed(palette.accentIcon), background: palette.background) },
                                               chatSearchActive: { generateChatAction( #imageLiteral(resourceName: "Icon_SearchChatMessages").precomposed(palette.accentIcon), background: palette.grayIcon.withAlphaComponent(0.1)) },
                                               chatCall: {  generateChatAction(#imageLiteral(resourceName: "Icon_callNavigationHeader").precomposed(palette.accentIcon), background: palette.background)  },
                                               chatCallActive: { generateChatAction( #imageLiteral(resourceName: "Icon_callNavigationHeader").precomposed(palette.accentIcon), background: palette.grayIcon.withAlphaComponent(0.1)) },
                                               chatActions: { generateChatAction(#imageLiteral(resourceName: "Icon_ChatActionsActive").precomposed(palette.accentIcon), background: palette.background) },
                                               chatFailedCall_incoming: { #imageLiteral(resourceName: "Icon_MessageCallIncoming").precomposed(palette.redUI) },
                                               chatFailedCall_outgoing:  { #imageLiteral(resourceName: "Icon_MessageCallOutgoing").precomposed(palette.redUI) },
                                               chatCall_incoming:  { #imageLiteral(resourceName: "Icon_MessageCallIncoming").precomposed(palette.greenUI) },
                                               chatCall_outgoing:  { #imageLiteral(resourceName: "Icon_MessageCallOutgoing").precomposed(palette.greenUI) },
                                               chatFailedCallBubble_incoming:  { #imageLiteral(resourceName: "Icon_MessageCallIncoming").precomposed(palette.redBubble_incoming) },
                                               chatFailedCallBubble_outgoing:  { #imageLiteral(resourceName: "Icon_MessageCallOutgoing").precomposed(palette.redBubble_outgoing) },
                                               chatCallBubble_incoming:  { #imageLiteral(resourceName: "Icon_MessageCallIncoming").precomposed(palette.greenBubble_incoming) },
                                               chatCallBubble_outgoing:  { #imageLiteral(resourceName: "Icon_MessageCallOutgoing").precomposed(palette.greenBubble_outgoing) },
                                               chatFallbackCall: { #imageLiteral(resourceName: "Icon_MessageCall").precomposed(palette.accentIcon) },
                                               chatFallbackCallBubble_incoming: { #imageLiteral(resourceName: "Icon_callNavigationHeader").precomposed(palette.textBubble_incoming) },
                                               chatFallbackCallBubble_outgoing: { #imageLiteral(resourceName: "Icon_callNavigationHeader").precomposed(palette.textBubble_outgoing) },
                                               chatFallbackVideoCall: { #imageLiteral(resourceName: "Icon_VideoCall").precomposed(palette.accentIcon) },
                                               chatFallbackVideoCallBubble_incoming: { #imageLiteral(resourceName: "Icon_VideoCall").precomposed(palette.textBubble_incoming) },
                                               chatFallbackVideoCallBubble_outgoing: { #imageLiteral(resourceName: "Icon_VideoCall").precomposed(palette.textBubble_outgoing) },
                                               chatToggleSelected:  { generateChatGroupToggleSelected(foregroundColor: palette.accentIcon, backgroundColor: palette.underSelectedColor) },
                                               chatToggleUnselected:  { generateChatGroupToggleUnselected(foregroundColor: palette.grayIcon.withAlphaComponent(0.6), backgroundColor: NSColor.black.withAlphaComponent(0.01)) },
                                               chatMusicPlay:  { #imageLiteral(resourceName: "Icon_ChatMusicPlay").precomposed(palette.fileActivityForeground) },
                                               chatMusicPlayBubble_incoming:  { #imageLiteral(resourceName: "Icon_ChatMusicPlay").precomposed(palette.fileActivityForegroundBubble_incoming) },
                                               chatMusicPlayBubble_outgoing:  { #imageLiteral(resourceName: "Icon_ChatMusicPlay").precomposed(palette.fileActivityForegroundBubble_outgoing) },
                                               chatMusicPause:  { #imageLiteral(resourceName: "Icon_ChatMusicPause").precomposed(palette.fileActivityForeground) },
                                               chatMusicPauseBubble_incoming:  { #imageLiteral(resourceName: "Icon_ChatMusicPause").precomposed(palette.fileActivityForegroundBubble_incoming) },
                                               chatMusicPauseBubble_outgoing:  { #imageLiteral(resourceName: "Icon_ChatMusicPause").precomposed(palette.fileActivityForegroundBubble_outgoing) },
                                               chatGradientBubble_incoming: { generateGradientBubble([palette.bubbleBackground_incoming]) },
                                               chatGradientBubble_outgoing: { generateGradientBubble(palette.bubbleBackground_outgoing) },
                                               chatBubble_none_incoming_withInset: { messageBubbleImageModern(incoming: true, fillColor: .black, strokeColor: .clear, neighbors: .none) },
                                               chatBubble_none_outgoing_withInset: { messageBubbleImageModern(incoming: false, fillColor: .black, strokeColor: .clear, neighbors: .none) },
                                               chatBubbleBorder_none_incoming_withInset: { messageBubbleImageModern(incoming: true, fillColor: .clear, strokeColor: palette.bubbleBorder_incoming, neighbors: .none) },
                                               chatBubbleBorder_none_outgoing_withInset: { messageBubbleImageModern(incoming: false, fillColor: .clear, strokeColor: palette.bubbleBorder_outgoing, neighbors: .none) },
                                               chatBubble_both_incoming_withInset: { messageBubbleImageModern(incoming: true, fillColor: .black, strokeColor: .clear, neighbors: .both) },
                                               chatBubble_both_outgoing_withInset: { messageBubbleImageModern(incoming: false, fillColor: .black, strokeColor: .clear, neighbors: .both) },
                                               chatBubbleBorder_both_incoming_withInset: { messageBubbleImageModern(incoming: true, fillColor: .clear, strokeColor: palette.bubbleBorder_incoming, neighbors: .both) },
                                               chatBubbleBorder_both_outgoing_withInset: { messageBubbleImageModern(incoming: false, fillColor: .clear, strokeColor: palette.bubbleBorder_outgoing, neighbors: .both) },
                                               composeNewChat: { #imageLiteral(resourceName: "Icon_NewMessage").precomposed(palette.accentIcon) },
                                               composeNewChatActive: { #imageLiteral(resourceName: "Icon_NewMessage").precomposed(palette.underSelectedColor) },
                                               composeNewGroup: { #imageLiteral(resourceName: "Icon_NewGroup").precomposed(palette.accentIcon) },
                                               composeNewSecretChat: { #imageLiteral(resourceName: "Icon_NewSecretChat").precomposed(palette.accentIcon) },
                                               composeNewChannel: { #imageLiteral(resourceName: "Icon_NewChannel").precomposed(palette.accentIcon) },
                                               contactsNewContact: { #imageLiteral(resourceName: "Icon_NewContact").precomposed(palette.accentIcon) },
                                               chatReadMarkInBubble1_incoming: { #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(palette.accentIconBubble_incoming) },
                                               chatReadMarkInBubble2_incoming: { #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(palette.accentIconBubble_incoming) },
                                               chatReadMarkInBubble1_outgoing: { #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(palette.accentIconBubble_outgoing) },
                                               chatReadMarkInBubble2_outgoing: { #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(palette.accentIconBubble_outgoing) },
                                               chatReadMarkOutBubble1: { #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(palette.accentIcon) },
                                               chatReadMarkOutBubble2: { #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(palette.accentIcon) },
                                               chatReadMarkOverlayBubble1: { #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(.white) },
                                               chatReadMarkOverlayBubble2: { #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(.white) },
                                               sentFailed: { generateImage(NSMakeSize(13, 13), contextGenerator: { size, ctx in
                                                    ctx.clear(NSMakeRect(0, 0, size.width, size.height))
                                                    ctx.draw(#imageLiteral(resourceName: "Icon_MessageSentFailed").precomposed(), in: NSMakeRect(0, 0, size.width, size.height))
                                               })! },
                                               chatChannelViewsInBubble_incoming: { #imageLiteral(resourceName: "Icon_ChannelViews").precomposed(palette.grayIconBubble_incoming) },
                                               chatChannelViewsInBubble_outgoing: { #imageLiteral(resourceName: "Icon_ChannelViews").precomposed(palette.grayIconBubble_outgoing) },
                                               chatChannelViewsOutBubble: { #imageLiteral(resourceName: "Icon_ChannelViews").precomposed(palette.grayIcon) },
                                               chatChannelViewsOverlayBubble: { #imageLiteral(resourceName: "Icon_ChannelViews").precomposed(.white) },
                                               chatPaidMessageInBubble_incoming: { NSImage(resource: .iconPaidMessageStatus).precomposed(palette.grayIconBubble_incoming) },
                                               chatPaidMessageInBubble_outgoing: { NSImage(resource: .iconPaidMessageStatus).precomposed(palette.grayIconBubble_outgoing) },
                                               chatPaidMessageOutBubble: { NSImage(resource: .iconPaidMessageStatus).precomposed(palette.grayIcon) },
                                               chatPaidMessageOverlayBubble: { NSImage(resource: .iconPaidMessageStatus).precomposed(.white) },
                                               chatNavigationBack: { #imageLiteral(resourceName: "Icon_ChatNavigationBack").precomposed(palette.accentIcon) },
                                               peerInfoAddMember: { #imageLiteral(resourceName: "Icon_NewContact").precomposed(palette.accentIcon, flipVertical: true) },
                                               chatSearchUp: { #imageLiteral(resourceName: "Icon_SearchArrow").precomposed(palette.accentIcon) },
                                               chatSearchUpDisabled: { #imageLiteral(resourceName: "Icon_SearchArrow").precomposed(palette.grayIcon) },
                                               chatSearchDown: { #imageLiteral(resourceName: "Icon_SearchArrow").precomposed(palette.accentIcon, flipVertical:true) },
                                               chatSearchDownDisabled: { #imageLiteral(resourceName: "Icon_SearchArrow").precomposed(palette.grayIcon, flipVertical:true) },
                                               chatSearchCalendar: { #imageLiteral(resourceName: "Icon_Calendar").precomposed(palette.accentIcon) },
                                               dismissAccessory: { #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.grayIcon) },
                                               chatScrollUp: { generateChatScrolldownImage(backgroundColor: palette.background, borderColor: palette.chatBackground == palette.background && palette.isDark ? palette.grayIcon : .clear, arrowColor: palette.grayIcon) },
                                               chatScrollUpActive: { generateChatScrolldownImage(backgroundColor: palette.background, borderColor: palette.chatBackground == palette.background && palette.isDark ? palette.accentIcon : .clear, arrowColor: palette.accentIcon) },
                                               chatScrollDown: { generateChatScrolldownImage(backgroundColor: palette.background, borderColor: palette.chatBackground == palette.background && palette.isDark ? palette.grayIcon : .clear, arrowColor: palette.grayIcon, reversed: true) },
                                               chatScrollDownActive: { generateChatScrolldownImage(backgroundColor: palette.background, borderColor: palette.chatBackground == palette.background && palette.isDark ? palette.accentIcon : .clear, arrowColor: palette.accentIcon, reversed: true) },
                                               chatSendMessage: { #imageLiteral(resourceName: "Icon_SendMessage").precomposed(palette.accentIcon) },
                                               chatSaveEditedMessage: { generateSendIcon(NSImage(named: "Icon_SaveEditedMessage")!, palette.accentIcon) },
                                               chatRecordVoice: { #imageLiteral(resourceName: "Icon_RecordVoice").precomposed(palette.grayIcon) },
                                               chatEntertainment: { #imageLiteral(resourceName: "Icon_Entertainments").precomposed(palette.grayIcon) },
                                               chatInlineDismiss: { #imageLiteral(resourceName: "Icon_InlineResultCancel").precomposed(palette.grayIcon) },
                                               chatActiveReplyMarkup: { #imageLiteral(resourceName: "Icon_ReplyMarkupButton").precomposed(palette.accentIcon) },
                                               chatDisabledReplyMarkup: { #imageLiteral(resourceName: "Icon_ReplyMarkupButton").precomposed(palette.grayIcon) },
                                               chatSecretTimer: { #imageLiteral(resourceName: "Icon_SecretTimer").precomposed(palette.grayIcon) },
                                               chatForwardMessagesActive: { #imageLiteral(resourceName: "Icon_MessageActionPanelForward").precomposed(palette.accentIcon) },
                                               chatForwardMessagesInactive: { #imageLiteral(resourceName: "Icon_MessageActionPanelForward").precomposed(palette.grayIcon) },
                                               chatDeleteMessagesActive: { #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(palette.redUI) },
                                               chatDeleteMessagesInactive: { #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(palette.grayIcon) },
                                               generalNext: { #imageLiteral(resourceName: "Icon_GeneralNext").precomposed(palette.grayIcon.withAlphaComponent(0.5)) },
                                               generalNextActive: { #imageLiteral(resourceName: "Icon_GeneralNext").precomposed(.white) },
                                               generalSelect: { #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(palette.accentIcon) },
                                               chatVoiceRecording: { #imageLiteral(resourceName: "Icon_RecordingVoice").precomposed(palette.accentIcon) },
                                               chatVideoRecording: { #imageLiteral(resourceName: "Icon_RecordVideoMessage").precomposed(palette.accentIcon) },
                                               chatRecord: { #imageLiteral(resourceName: "Icon_RecordVoice").precomposed(palette.grayIcon) },
                                               deleteItem: { deleteItemIcon(palette.redUI) },
                                               deleteItemDisabled: { deleteItemIcon(palette.grayText) },
                                               chatAttach: { #imageLiteral(resourceName: "Icon_ChatAttach").precomposed(palette.grayIcon) },
                                               chatAttachFile: { #imageLiteral(resourceName: "Icon_AttachFile").precomposed(palette.accentIcon) },
                                               chatAttachPhoto: { #imageLiteral(resourceName: "Icon_AttachPhoto").precomposed(palette.accentIcon) },
                                               chatAttachCamera: { #imageLiteral(resourceName: "Icon_AttachCamera").precomposed(palette.accentIcon) },
                                               chatAttachLocation: { #imageLiteral(resourceName: "Icon_AttachLocation").precomposed(palette.accentIcon) },
                                               chatAttachPoll: { #imageLiteral(resourceName: "Icon_AttachPoll").precomposed(palette.accentIcon) },
                                               mediaEmptyShared: { #imageLiteral(resourceName: "Icon_EmptySharedMedia").precomposed(palette.grayIcon) },
                                               mediaEmptyFiles: { #imageLiteral(resourceName: "Icon_EmptySharedFiles").precomposed() },
                                               mediaEmptyMusic: { #imageLiteral(resourceName: "Icon_EmptySharedMusic").precomposed(palette.grayIcon) },
                                               mediaEmptyLinks: { #imageLiteral(resourceName: "Icon_EmptySharedLinks").precomposed(palette.grayIcon) },
                                               stickersAddFeatured: { #imageLiteral(resourceName: "Icon_GroupInfoAddMember").precomposed(palette.accentIcon) },
                                               stickersAddedFeatured: { #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(palette.grayIcon) },
                                               stickersRemove: { #imageLiteral(resourceName: "Icon_InlineResultCancel").precomposed(palette.grayIcon) },
                                               peerMediaDownloadFileStart: { #imageLiteral(resourceName: "Icon_MediaDownload").precomposed(palette.accentIcon) },
                                               peerMediaDownloadFilePause: { downloadFilePauseIcon(palette.accentIcon) },
                                               stickersShare: { #imageLiteral(resourceName: "Icon_ShareStickerPack").precomposed(palette.accentIcon) },
                                               emojiRecentTab: { #imageLiteral(resourceName: "Icon_EmojiTabRecent").precomposed(palette.grayIcon.withAlphaComponent(0.8)) },
                                               emojiSmileTab: { #imageLiteral(resourceName: "Icon_EmojiTabSmiles").precomposed(palette.grayIcon.withAlphaComponent(0.8)) },
                                               emojiNatureTab: { #imageLiteral(resourceName: "Icon_EmojiTabNature").precomposed(palette.grayIcon.withAlphaComponent(0.8)) },
                                               emojiFoodTab: { #imageLiteral(resourceName: "Icon_EmojiTabFood").precomposed(palette.grayIcon.withAlphaComponent(0.8)) },
                                               emojiSportTab: { #imageLiteral(resourceName: "Icon_EmojiTabSports").precomposed(palette.grayIcon.withAlphaComponent(0.8)) },
                                               emojiCarTab: { #imageLiteral(resourceName: "Icon_EmojiTabCar").precomposed(palette.grayIcon.withAlphaComponent(0.8)) },
                                               emojiObjectsTab: { #imageLiteral(resourceName: "Icon_EmojiTabObjects").precomposed(palette.grayIcon.withAlphaComponent(0.8)) },
                                               emojiSymbolsTab: { #imageLiteral(resourceName: "Icon_EmojiTabSymbols").precomposed(palette.grayIcon.withAlphaComponent(0.8)) },
                                               emojiFlagsTab: { #imageLiteral(resourceName: "Icon_EmojiTabFlag").precomposed(palette.grayIcon.withAlphaComponent(0.8)) },
                                               emojiRecentTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabRecent").precomposed(palette.grayIcon.darker()) },
                                               emojiSmileTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabSmiles").precomposed(palette.grayIcon.darker()) },
                                               emojiNatureTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabNature").precomposed(palette.grayIcon.darker()) },
                                               emojiFoodTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabFood").precomposed(palette.grayIcon.darker()) },
                                               emojiSportTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabSports").precomposed(palette.grayIcon.darker()) },
                                               emojiCarTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabCar").precomposed(palette.grayIcon.darker()) },
                                               emojiObjectsTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabObjects").precomposed(palette.grayIcon.darker()) },
                                               emojiSymbolsTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabSymbols").precomposed(palette.grayIcon.darker()) },
                                               emojiFlagsTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabFlag").precomposed(palette.grayIcon.darker()) },
                                               stickerBackground: { generateStickerBackground(NSMakeSize(83, 83), palette.background) },
                                               stickerBackgroundActive: { generateStickerBackground(NSMakeSize(83, 83), palette.grayBackground) },
                                               stickersTabRecent: { #imageLiteral(resourceName: "Icon_EmojiTabRecent").precomposed(palette.grayIcon) },
                                               stickersTabGIF: { #imageLiteral(resourceName: "Icon_GifToggle").precomposed(palette.grayIcon) },
                                               chatSendingInFrame_incoming: { generateSendingFrame(palette.grayIconBubble_incoming) },
                                               chatSendingInHour_incoming: { generateClockMinImage(palette.grayIconBubble_incoming) },
                                               chatSendingInMin_incoming: { generateClockMinImage(palette.grayIconBubble_incoming) },
                                               chatSendingInFrame_outgoing: { generateSendingFrame(palette.grayIconBubble_outgoing) },
                                               chatSendingInHour_outgoing: { generateClockMinImage(palette.grayIconBubble_outgoing) },
                                               chatSendingInMin_outgoing: { generateClockMinImage(palette.grayIconBubble_outgoing) },
                                               chatSendingOutFrame: { generateSendingFrame(palette.grayIcon) },
                                               chatSendingOutHour: { generateClockMinImage(palette.grayIcon) },
                                               chatSendingOutMin: { generateClockMinImage(palette.grayIcon) },
                                               chatSendingOverlayFrame: { generateSendingFrame(.white) },
                                               chatSendingOverlayHour: { generateClockMinImage(.white) },
                                               chatSendingOverlayMin: { generateClockMinImage(.white) },
                                               chatActionUrl: { #imageLiteral(resourceName: "Icon_InlineBotUrl").precomposed(palette.text) },
                                               callInlineDecline: { #imageLiteral(resourceName: "Icon_CallDecline_Inline").precomposed(.white) },
                                               callInlineMuted: { #imageLiteral(resourceName: "Icon_CallMute_Inline").precomposed(.white) },
                                               callInlineUnmuted: { #imageLiteral(resourceName: "Icon_CallUnmuted_Inline").precomposed(.white) },
                                               eventLogTriangle: { generateRecentActionsTriangle(palette.text) },
                                               channelIntro: { #imageLiteral(resourceName: "Icon_ChannelIntro").precomposed() },
                                               chatFileThumb: { #imageLiteral(resourceName: "Icon_MessageFile").precomposed(flipVertical:true) },
                                               chatFileThumbBubble_incoming: { #imageLiteral(resourceName: "Icon_MessageFile").precomposed(palette.fileActivityForegroundBubble_incoming,  flipVertical:true) },
                                               chatFileThumbBubble_outgoing: { #imageLiteral(resourceName: "Icon_MessageFile").precomposed(palette.fileActivityForegroundBubble_outgoing, flipVertical:true) },
                                               chatSecretThumb: { generateSecretThumb(#imageLiteral(resourceName: "Icon_SecretAutoremoveMedia").precomposed(.black, flipVertical:true)) },
                                               chatSecretThumbSmall: { generateSecretThumbSmall(#imageLiteral(resourceName: "Icon_SecretAutoremoveMedia").precomposed(.black, flipVertical:true)) },
                                               chatMapPin: { #imageLiteral(resourceName: "Icon_MapPinned").precomposed() },
                                               chatSecretTitle: { #imageLiteral(resourceName: "Icon_SecretChatLock").precomposed(palette.text, flipVertical:true) },
                                               emptySearch: { #imageLiteral(resourceName: "Icon_EmptySearchResults").precomposed(palette.grayIcon) },
                                               calendarBack: { #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(palette.accentIcon) },
                                               calendarNext: { #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(palette.accentIcon, flipHorizontal: true) },
                                               calendarBackDisabled: { #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(palette.grayIcon) },
                                               calendarNextDisabled: { #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(palette.grayIcon, flipHorizontal: true) },
                                               newChatCamera: { #imageLiteral(resourceName: "Icon_AttachCamera").precomposed(palette.grayIcon) },
                                               peerInfoVerify: { generateDialogVerify(background: palette.underSelectedColor, foreground: palette.basicAccent, reversed: true) },
                                               peerInfoVerifyProfile: { generateDialogVerify(background: palette.underSelectedColor, foreground: palette.basicAccent, reversed: true) },
                                               peerInfoCall: { #imageLiteral(resourceName: "Icon_ProfileCall").precomposed(palette.accent) },
                                               callOutgoing: { #imageLiteral(resourceName: "Icon_CallOutgoing").precomposed(palette.grayIcon, flipVertical: true) },
                                               recentDismiss: { NSImage(named: "Icon_Search_RemoveRecent")!.precomposed(palette.grayIcon) },
                                               recentDismissActive: { NSImage(named: "Icon_Search_RemoveRecent")!.precomposed(palette.underSelectedColor) },
                                               webgameShare: { #imageLiteral(resourceName: "Icon_ShareStickerPack").precomposed(palette.accentIcon) },
                                               chatSearchCancel: { #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.accentIcon) },
                                               chatSearchFrom: { #imageLiteral(resourceName: "Icon_ChatSearchFrom").precomposed(palette.accentIcon) },
                                               callWindowDecline: { #imageLiteral(resourceName: "Icon_CallDecline_Window").precomposed(.white) },
                                               callWindowDeclineSmall: { NSImage(named: "Icon_callDeclineSmall_Window")!.precomposed(.white) },
                                               callWindowAccept: { #imageLiteral(resourceName: "Icon_CallAccept_Window").precomposed(.white) },
                                               callWindowVideo: { #imageLiteral(resourceName: "Icon_CallVideo_Window").precomposed(.white) },
                                               callWindowVideoActive: { #imageLiteral(resourceName: "Icon_CallVideo_Window").precomposed(.grayIcon) },
                                               callWindowMute: { #imageLiteral(resourceName: "Icon_CallMuted_Window").precomposed(.white) },
                                               callWindowMuteActive: { #imageLiteral(resourceName: "Icon_CallMuted_Window").precomposed(.grayIcon) },
                                               callWindowClose: { #imageLiteral(resourceName: "Icon_CallWindowClose").precomposed(.white) },
                                               callWindowDeviceSettings: { #imageLiteral(resourceName: "Icon_CallDeviceSettings").precomposed(.white) },
                                               callSettings: { #imageLiteral(resourceName: "Icon_CallDeviceSettings").precomposed(palette.accentIcon) },
                                               callWindowCancel: { #imageLiteral(resourceName: "Icon_CallCancelIcon").precomposed(.white) },
                                               chatActionEdit: { #imageLiteral(resourceName: "Icon_ChatActionEdit").precomposed(palette.accentIcon) },
                                               chatActionInfo: { #imageLiteral(resourceName: "Icon_ChatActionInfo").precomposed(palette.accentIcon) },
                                               chatActionMute: { #imageLiteral(resourceName: "Icon_ChatActionMute").precomposed(palette.accentIcon) },
                                               chatActionUnmute: { #imageLiteral(resourceName: "Icon_ChatActionUnmute").precomposed(palette.accentIcon) },
                                               chatActionClearHistory: { #imageLiteral(resourceName: "Icon_ClearChat").precomposed(palette.accentIcon) },
                                               chatActionDeleteChat: { #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(palette.accentIcon) },
                                               dismissPinned: { #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.accentIcon) },
                                               chatActionsActive: { generateChatAction(#imageLiteral(resourceName: "Icon_ChatActionsActive").precomposed(palette.accentIcon), background: palette.grayIcon.withAlphaComponent(0.1)) },
                                               chatEntertainmentSticker: { #imageLiteral(resourceName: "Icon_ChatEntertainmentSticker").precomposed(palette.grayIcon) },
                                               chatEmpty: { #imageLiteral(resourceName: "Icon_EmptyChat").precomposed(palette.grayForeground) },
                                               stickerPackClose: { #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.accentIcon) },
                                               stickerPackDelete: { #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(palette.accentIcon) },
                                               modalShare: { #imageLiteral(resourceName: "Icon_ShareStickerPack").precomposed(palette.accentIcon) },
                                               modalClose: { #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.accentIcon) },
                                               ivChannelJoined: { #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(.white) },
                                               chatListMention: { generateBadgeMention(image: NSImage(named: "Icon_ChatListMention")!, backgroundColor: palette.badge, foregroundColor: palette.background) },
                                              chatListMentionActive: { generateBadgeMention(image: NSImage(named: "Icon_ChatListMention")!, backgroundColor: palette.underSelectedColor, foregroundColor: palette.accentSelect) },
                                               chatListMentionArchived: { generateBadgeMention(image: NSImage(named: "Icon_ChatListMention")!, backgroundColor: palette.badgeMuted, foregroundColor: palette.background) },
                                               chatListMentionArchivedActive: { generateBadgeMention(image: NSImage(named: "Icon_ChatListMention")!, backgroundColor: palette.underSelectedColor, foregroundColor: palette.accentSelect) },
                                               chatMention: { generateChatMention(image: NSImage(named: "Icon_ChatMention")!, backgroundColor: palette.background, border: palette.grayIcon, foregroundColor: palette.grayIcon) },
                                               chatMentionActive: { generateChatMention(image: NSImage(named: "Icon_ChatMention")!, backgroundColor: palette.background, border: palette.accentIcon, foregroundColor: palette.accentIcon) },
                                               sliderControl: { #imageLiteral(resourceName: "Icon_SliderNormal").precomposed() },
                                               sliderControlActive: { #imageLiteral(resourceName: "Icon_SliderNormal").precomposed() },
                                               chatInstantView: { #imageLiteral(resourceName: "Icon_ChatIV").precomposed(palette.webPreviewActivity) },
                                               chatInstantViewBubble_incoming: { #imageLiteral(resourceName: "Icon_ChatIV").precomposed(palette.webPreviewActivityBubble_incoming) },
                                               chatInstantViewBubble_outgoing: { #imageLiteral(resourceName: "Icon_ChatIV").precomposed(palette.webPreviewActivityBubble_outgoing) },
                                               instantViewShare: { #imageLiteral(resourceName: "Icon_ShareStickerPack").precomposed(palette.accentIcon) },
                                               instantViewActions: { #imageLiteral(resourceName: "Icon_ChatActions").precomposed(palette.accentIcon) },
                                               instantViewActionsActive: { #imageLiteral(resourceName: "Icon_ChatActionsActive").precomposed(palette.accentIcon) },
                                               instantViewSafari: { #imageLiteral(resourceName: "Icon_InstantViewSafari").precomposed(palette.accentIcon) },
                                               instantViewBack: { #imageLiteral(resourceName: "Icon_InstantViewBack").precomposed(palette.accentIcon) },
                                               instantViewCheck: { #imageLiteral(resourceName: "Icon_InstantViewCheck").precomposed(palette.accentIcon) },
                                               groupStickerNotFound: { #imageLiteral(resourceName: "Icon_GroupStickerNotFound").precomposed(palette.grayIcon) },
                                               settingsAskQuestion: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsAskQuestion").precomposed(flipVertical: true)) },
                                               settingsFaq: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsFaq").precomposed(flipVertical: true)) },
                                               settingsStories: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsStories").precomposed(flipVertical: true)) },
                                                settingsGeneral: { generateSettingsIcon(NSImage(resource: .iconSettingsGeneral).precomposed(flipVertical: true)) },
                                               settingsLanguage: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsLanguage").precomposed(flipVertical: true)) },
                                               settingsNotifications: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsNotifications").precomposed(flipVertical: true)) },
                                               settingsSecurity: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsSecurity").precomposed(flipVertical: true)) },
                                               settingsStickers: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsStickers").precomposed(flipVertical: true)) },
                                               settingsStorage: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsStorage").precomposed(flipVertical: true)) },
                                               settingsSessions: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_PrivacySettings_ActiveSessions").precomposed(flipVertical: true)) },
                                               settingsProxy: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsProxy").precomposed(flipVertical: true)) },
                                               settingsAppearance: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_AppearanceSettings").precomposed(flipVertical: true)) },
                                               settingsPassport: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsSecurity").precomposed(flipVertical: true)) },
                                               settingsWallet: { generateSettingsIcon(NSImage(named: "Icon_SettingsWallet")!.precomposed(NSColor(0x59a7d8), flipVertical: true)) },
                                               settingsUpdate: { generateSettingsIcon(NSImage(named: "Icon_SettingsUpdate")!.precomposed(flipVertical: true)) },
                                               settingsFilters: { generateSettingsIcon(NSImage(named: "Icon_SettingsFilters")!.precomposed(flipVertical: true)) },
                                               settingsPremium: { generatePremiumIcon(NSImage(named: "Icon_Premium_Settings")!.precomposed(flipVertical: true)) },
                                               settingsGiftPremium: { generateSettingsIcon(NSImage(named: "Icon_Settings_GiftPremium")!.precomposed(flipVertical: true)) },
                                               settingsAskQuestionActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsAskQuestion").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsFaqActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsFaq").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsStoriesActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsStories").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsGeneralActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsGeneral").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsLanguageActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsLanguage").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsNotificationsActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsNotifications").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsSecurityActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsSecurity").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsStickersActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsStickers").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsStorageActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsStorage").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsSessionsActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_PrivacySettings_ActiveSessions").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsProxyActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsProxy").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsAppearanceActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_AppearanceSettings").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsPassportActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsSecurity").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsWalletActive: { generateSettingsActiveIcon(NSImage(named: "Icon_SettingsWallet")!.precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsUpdateActive: { generateSettingsActiveIcon(NSImage(named: "Icon_SettingsUpdate")!.precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsFiltersActive: { generateSettingsActiveIcon(NSImage(named: "Icon_SettingsFilters")!.precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsProfile: { generateSettingsIcon(NSImage(resource: .iconSettingsProfile).precomposed(flipVertical: true)) },
                                               settingsBusiness: { generateSettingsIcon(NSImage(resource: .iconSettingsBusiness).precomposed(flipVertical: true)) },
                                               settingsBusinessActive: { generateSettingsActiveIcon(NSImage(resource: .iconSettingsBusiness).precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsStars: { generateSettingsIcon(NSImage(resource: .iconSettingsStars).precomposed(flipVertical: true)) },
                                               generalCheck: { #imageLiteral(resourceName: "Icon_Check").precomposed(palette.accentIcon) },
                                               settingsAbout: { #imageLiteral(resourceName: "Icon_SettingsAbout").precomposed(palette.accentIcon) },
                                               settingsLogout: { #imageLiteral(resourceName: "Icon_SettingsLogout").precomposed(palette.redUI) },
                                               fastSettingsLock: { #imageLiteral(resourceName: "Icon_FastSettingsLock").precomposed(palette.accentIcon) },
                                               fastSettingsDark: { #imageLiteral(resourceName: "Icon_FastSettingsDark").precomposed(palette.accentIcon) },
                                               fastSettingsSunny: { #imageLiteral(resourceName: "Icon_FastSettingsSunny").precomposed(palette.accentIcon) },
                                               fastSettingsMute: { #imageLiteral(resourceName: "Icon_ChatActionMute").precomposed(palette.accentIcon) },
                                               fastSettingsUnmute: { #imageLiteral(resourceName: "Icon_ChatActionUnmute").precomposed(palette.accentIcon) },
                                               chatRecordVideo: { #imageLiteral(resourceName: "Icon_RecordVideoMessage").precomposed(palette.grayIcon) },
                                               inputChannelMute: { #imageLiteral(resourceName: "Icon_InputChannelMute").precomposed(palette.grayIcon) },
                                               inputChannelUnmute: { #imageLiteral(resourceName: "Icon_InputChannelUnmute").precomposed(palette.grayIcon) },
                                               changePhoneNumberIntro: { #imageLiteral(resourceName: "Icon_ChangeNumberIntro").precomposed() },
                                               peerSavedMessages: { #imageLiteral(resourceName: "Icon_SavedMessages").precomposed() },
                                               previewSenderCollage: { #imageLiteral(resourceName: "Icon_PreviewCollage").precomposed(palette.grayIcon) },
                                               previewSenderPhoto: { NSImage(named: "Icon_PreviewSenderPhoto")!.precomposed(palette.grayIcon) },
                                               previewSenderFile: { NSImage(named: "Icon_PreviewSenderFile")!.precomposed(palette.grayIcon) },
                                               previewSenderCrop: { NSImage(named: "Icon_PreviewSenderCrop")!.precomposed(.white) },
                                               previewSenderDelete: { NSImage(named: "Icon_PreviewSenderDelete")!.precomposed(.white) },
                                               previewSenderDeleteFile: { NSImage(named: "Icon_PreviewSenderDelete")!.precomposed(palette.accentIcon) },
                                               previewSenderArchive: { NSImage(named: "Icon_PreviewSenderArchive")!.precomposed(palette.grayIcon) },
                                               chatGroupToggleSelected: { generateChatGroupToggleSelected(foregroundColor: palette.accentIcon, backgroundColor: palette.underSelectedColor) },
                                               chatGroupToggleUnselected: { generateChatGroupToggleUnselected(foregroundColor: palette.grayIcon.withAlphaComponent(0.6), backgroundColor: NSColor.black.withAlphaComponent(0.01)) },
                                               successModalProgress: { #imageLiteral(resourceName: "Icon_ProgressWindowCheck").precomposed(palette.grayIcon) },
                                               accentColorSelect: { #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(.white) },
                                               transparentBackground: { generateTransparentBackground() },
                                               lottieTransparentBackground: { generateLottieTransparentBackground() },
                                               passcodeTouchId: { #imageLiteral(resourceName: "Icon_TouchId").precomposed(palette.underSelectedColor) },
                                               passcodeLogin: { #imageLiteral(resourceName: "Icon_PasscodeLogin").precomposed(palette.underSelectedColor) },
                                               confirmDeleteMessagesAccessory: { generateConfirmDeleteMessagesAccessory(backgroundColor: palette.redUI) },
                                               alertCheckBoxSelected: { generateAlertCheckBoxSelected(backgroundColor: palette.accentIcon) },
                                               alertCheckBoxUnselected: { generateAlertCheckBoxUnselected(border: palette.grayIcon) },
                                               confirmPinAccessory: { generateConfirmPinAccessory(backgroundColor: palette.accentIcon) },
                                               confirmDeleteChatAccessory: { generateConfirmDeleteChatAccessory(backgroundColor: palette.background, foregroundColor: palette.redUI) },
                                               stickersEmptySearch: { generateStickersEmptySearch(color: palette.grayIcon) },
                                               twoStepVerificationCreateIntro: { #imageLiteral(resourceName: "Icon_TwoStepVerification_Create").precomposed() },
                                               secureIdAuth: { #imageLiteral(resourceName: "Icon_SecureIdAuth").precomposed() },
                                               ivAudioPlay: { generateIVAudioPlay(color: palette.text) },
                                               ivAudioPause: { generateIVAudioPause(color: palette.text) },
                                               proxyEnable: { #imageLiteral(resourceName: "Icon_ProxyEnable").precomposed(palette.accent) },
                                               proxyEnabled: { #imageLiteral(resourceName: "Icon_ProxyEnabled").precomposed(palette.accent) },
                                               proxyState: { #imageLiteral(resourceName: "Icon_ProxyState").precomposed(palette.accent) },
                                               proxyDeleteListItem: { #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(palette.accentIcon) },
                                               proxyInfoListItem: { NSImage(named: "Icon_DetailedInfo")!.precomposed(palette.accentIcon) },
                                               proxyConnectedListItem: { #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(palette.accentIcon) },
                                               proxyAddProxy: { #imageLiteral(resourceName: "Icon_GroupInfoAddMember").precomposed(palette.accentIcon, flipVertical: true) },
                                               proxyNextWaitingListItem: { #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(palette.grayIcon) },
                                               passportForgotPassword: { #imageLiteral(resourceName: "Icon_SecureIdForgotPassword").precomposed(palette.grayIcon) },
                                               confirmAppAccessoryIcon: { #imageLiteral(resourceName: "Icon_ConfirmAppAccessory").precomposed() },
                                               passportPassport: { #imageLiteral(resourceName: "Icon_PassportPassport").precomposed(palette.accentIcon, flipVertical: true) },
                                               passportIdCardReverse: { #imageLiteral(resourceName: "Icon_PassportIdCardReverse").precomposed(palette.accentIcon, flipVertical: true) },
                                               passportIdCard: { #imageLiteral(resourceName: "Icon_PassportIdCard").precomposed(palette.accentIcon, flipVertical: true) },
                                               passportSelfie: { #imageLiteral(resourceName: "Icon_PassportSelfie").precomposed(palette.accentIcon, flipVertical: true) },
                                               passportDriverLicense: { #imageLiteral(resourceName: "Icon_PassportDriverLicense").precomposed(palette.accentIcon, flipVertical: true) },
                                               chatOverlayVoiceRecording: { #imageLiteral(resourceName: "Icon_RecordingVoice").precomposed(.white) },
                                               chatOverlayVideoRecording: { #imageLiteral(resourceName: "Icon_RecordVideoMessage").precomposed(.white) },
                                               chatOverlaySendRecording: { #imageLiteral(resourceName: "Icon_ChatOverlayRecordingSend").precomposed(.white) },
                                               chatOverlayLockArrowRecording: { #imageLiteral(resourceName: "Icon_DropdownArrow").precomposed(palette.accentIcon, flipVertical: true) },
                                               chatOverlayLockerBodyRecording: { generateLockerBody(palette.accentIcon, backgroundColor: palette.background) },
                                               chatOverlayLockerHeadRecording: { generateLockerHead(palette.accentIcon, backgroundColor: palette.background) },
                                               locationPin: { generateLocationPinIcon(palette.accentIcon) },
                                               locationMapPin: { generateLocationMapPinIcon(palette.accentIcon) },
                                               locationMapLocate: { #imageLiteral(resourceName: "Icon_MapLocate").precomposed(palette.grayIcon) },
                                               locationMapLocated: { #imageLiteral(resourceName: "Icon_MapLocate").precomposed(palette.accentIcon) },
                                               passportSettings: { #imageLiteral(resourceName: "Icon_PassportSettings").precomposed(palette.grayIcon) },
                                               passportInfo: { #imageLiteral(resourceName: "Icon_SettingsBio").precomposed(palette.accentIcon) },
                                               editMessageMedia: { generateEditMessageMediaIcon(#imageLiteral(resourceName: "Icon_ReplaceMessageMedia").precomposed(palette.accentIcon), background: palette.background) },
                                               playerMusicPlaceholder: { generatePlayerListAlbumPlaceholder(#imageLiteral(resourceName: "Icon_MusicPlayerSmallAlbumArtPlaceholder").precomposed(palette.listGrayText), background: palette.listBackground, radius: .cornerRadius) },
                                               chatMusicPlaceholder: { generatePlayerListAlbumPlaceholder(#imageLiteral(resourceName: "Icon_MusicPlayerSmallAlbumArtPlaceholder").precomposed(palette.fileActivityForeground), background: palette.fileActivityBackground, radius: 20) },
                                               chatMusicPlaceholderCap: { generatePlayerListAlbumPlaceholder(nil, background: palette.fileActivityBackground, radius: 20) },
                                               searchArticle: { #imageLiteral(resourceName: "Icon_SearchArticles").precomposed(.white) },
                                               searchSaved: { #imageLiteral(resourceName: "Icon_SearchSaved").precomposed(.white) },
                                               archivedChats: { #imageLiteral(resourceName: "Icon_ArchiveAvatar").precomposed(.white) },
                                               hintPeerActive: { generateHitActiveIcon(activeColor: palette.accent, backgroundColor: palette.background) },
                                               hintPeerActiveSelected: { generateHitActiveIcon(activeColor: palette.underSelectedColor, backgroundColor: palette.accentSelect) },
                                               chatSwiping_delete: { #imageLiteral(resourceName: "Icon_ChatSwipingDelete").precomposed(.white) },
                                               chatSwiping_mute: { #imageLiteral(resourceName: "Icon_ChatSwipingMute").precomposed(.white) },
                                               chatSwiping_unmute: { #imageLiteral(resourceName: "Icon_ChatSwipingUnmute").precomposed(.white) },
                                               chatSwiping_read: { #imageLiteral(resourceName: "Icon_ChatSwipingRead").precomposed(.white) },
                                               chatSwiping_unread: { #imageLiteral(resourceName: "Icon_ChatSwipingUnread").precomposed(.white) },
                                               chatSwiping_pin: { #imageLiteral(resourceName: "Icon_ChatSwipingPin").precomposed(.white) },
                                               chatSwiping_unpin: { #imageLiteral(resourceName: "Icon_ChatSwipingUnpin").precomposed(.white) },
                                               chatSwiping_archive: { #imageLiteral(resourceName: "Icon_ChatListSwiping_Archive").precomposed(.white) },
                                               chatSwiping_unarchive: { #imageLiteral(resourceName: "Icon_ChatListSwiping_Unarchive").precomposed(.white) },
                                               galleryPrev: { #imageLiteral(resourceName: "Icon_GalleryPrev").precomposed(.white) },
                                               galleryNext: { #imageLiteral(resourceName: "Icon_GalleryNext").precomposed(.white) },
                                               galleryMore: { #imageLiteral(resourceName: "Icon_GalleryMore").precomposed(.white) },
                                               galleryShare: { #imageLiteral(resourceName: "Icon_GalleryShare").precomposed(.white) },
                                               galleryFastSave: { NSImage(named: "Icon_Gallery_FastSave")!.precomposed(.white) },
                                               galleryRotate: {NSImage(named: "Icon_GalleryRotate")!.precomposed(.white) },
                                               galleryZoomIn: {NSImage(named: "Icon_GalleryZoomIn")!.precomposed(.white) },
                                               galleryZoomOut: { NSImage(named: "Icon_GalleryZoomOut")!.precomposed(.white) },
                                               editMessageCurrentPhoto: { NSImage(named: "Icon_EditMessageCurrentPhoto")!.precomposed(palette.accentIcon) },
                                               videoPlayerPlay: { NSImage(named: "Icon_VideoPlayer_Play")!.precomposed(.white) },
                                               videoPlayerPause: { NSImage(named: "Icon_VideoPlayer_Pause")!.precomposed(.white) },
                                               videoPlayerEnterFullScreen: { NSImage(named: "Icon_VideoPlayer_EnterFullScreen")!.precomposed(.white) },
                                               videoPlayerExitFullScreen: { NSImage(named: "Icon_VideoPlayer_ExitFullScreen")!.precomposed(.white) },
                                               videoPlayerPIPIn: { NSImage(named: "Icon_VideoPlayer_PIPIN")!.precomposed(.white) },
                                               videoPlayerPIPOut: { NSImage(named: "Icon_VideoPlayer_PIPOUT")!.precomposed(.white) },
                                               videoPlayerRewind15Forward: { NSImage(named: "Icon_VideoPlayer_Rewind15Forward")!.precomposed(.white) },
                                               videoPlayerRewind15Backward: { NSImage(named: "Icon_VideoPlayer_Rewind15Backward")!.precomposed(.white) },
                                               videoPlayerVolume: { NSImage(named: "Icon_VideoPlayer_Volume")!.precomposed(.white) },
                                               videoPlayerVolumeOff: { NSImage(named: "Icon_VideoPlayer_VolumeOff")!.precomposed(.white) },
                                               videoPlayerClose: { NSImage(named: "Icon_VideoPlayer_Close")!.precomposed(.white) },
                                               videoPlayerSliderInteractor: { NSImage(named: "Icon_Slider")!.precomposed() },
                                               streamingVideoDownload: { NSImage(named: "Icon_StreamingDownload")!.precomposed(.white) },
                                               videoCompactFetching: { NSImage(named: "Icon_VideoCompactFetching")!.precomposed(.white) },
                                               compactStreamingFetchingCancel: { NSImage(named: "Icon_CompactStreamingFetchingCancel")!.precomposed(.white) },
                                               customLocalizationDelete: { NSImage(named: "Icon_MessageActionPanelDelete")!.precomposed(palette.accentIcon) },
                                               pollAddOption: { generatePollAddOption(palette.accentIcon) },
                                               pollDeleteOption: { generatePollDeleteOption(palette.redUI) },
                                               resort: { NSImage(named: "Icon_Resort")!.precomposed(palette.grayIcon.withAlphaComponent(0.6)) },
                                               chatPollVoteUnselected: { #imageLiteral(resourceName: "Icon_SelectionUncheck").precomposed(palette.grayText.withAlphaComponent(0.3)) },
                                               chatPollVoteUnselectedBubble_incoming: { #imageLiteral(resourceName: "Icon_SelectionUncheck").precomposed(palette.grayTextBubble_incoming.withAlphaComponent(0.3)) },
                                               chatPollVoteUnselectedBubble_outgoing: { #imageLiteral(resourceName: "Icon_SelectionUncheck").precomposed(palette.grayTextBubble_outgoing.withAlphaComponent(0.3)) },
                                               peerInfoAdmins: { NSImage(named: "Icon_ChatAdmins")!.precomposed(flipVertical: true) },
                                               peerInfoRecentActions: { NSImage(resource: .iconProfileRecentLog).precomposed(flipVertical: true) },
                                               peerInfoPermissions: { NSImage(named: "Icon_ChatPermissions")!.precomposed(flipVertical: true) },
                                               peerInfoBanned: { NSImage(named: "Icon_ChatBanned")!.precomposed(flipVertical: true) },
                                               peerInfoMembers: { NSImage(named: "Icon_ChatMembers")!.precomposed(flipVertical: true) },
                                               peerInfoStarsBalance: { NSImage(resource: .iconPeerInfoStarsBalance).precomposed(flipVertical: true) },
                                               peerInfoBalance: { NSImage(resource: .iconPeerInfoBalance).precomposed(flipVertical: true) },
                                               peerInfoTonBalance: { NSImage(resource: .iconPeerInfoTonBalance).precomposed(flipVertical: true) },
                                               peerInfoBotUsername: { NSImage(resource: .iconPeerInfoBotUsername).precomposed(flipVertical: true) },
                                               chatUndoAction: { NSImage(named: "Icon_ChatUndoAction")!.precomposed(NSColor(0x29ACFF)) },
                                               appUpdate: { NSImage(named: "Icon_AppUpdate")!.precomposed() },
                                               inlineVideoSoundOff: { NSImage(named: "Icon_InlineVideoSoundOff")!.precomposed() },
                                               inlineVideoSoundOn: { NSImage(named: "Icon_InlineVideoSoundOn")!.precomposed() },
                                               logoutOptionAddAccount: { generateSettingsIcon(NSImage(named: "Icon_LogoutOption_AddAccount")!.precomposed(flipVertical: true)) },
                                               logoutOptionSetPasscode: { generateSettingsIcon(NSImage(named: "Icon_LogoutOption_SetPasscode")!.precomposed(flipVertical: true)) },
                                               logoutOptionClearCache: { generateSettingsIcon(NSImage(named: "Icon_LogoutOption_ClearCache")!.precomposed(flipVertical: true)) },
                                               logoutOptionChangePhoneNumber: { generateSettingsIcon(NSImage(named: "Icon_LogoutOption_ChangePhoneNumber")!.precomposed(flipVertical: true)) },
                                               logoutOptionContactSupport: { generateSettingsIcon(NSImage(named: "Icon_LogoutOption_ContactSupport")!.precomposed(flipVertical: true)) },
                                               disableEmojiPrediction: { NSImage(named: "Icon_CallWindowClose")!.precomposed(palette.grayIcon) },
                                               scam: { generateScamIconReversed(foregroundColor: palette.redUI, backgroundColor: .clear) },
                                               scamActive: { generateScamIconReversed(foregroundColor: palette.underSelectedColor, backgroundColor: .clear) },
                                               chatScam: { generateScamIconReversed(foregroundColor: palette.redUI, backgroundColor: .clear) },
                                               fake: { generateFakeIconReversed(foregroundColor: palette.redUI, backgroundColor: .clear) },
                                               fakeActive: { generateFakeIconReversed(foregroundColor: palette.underSelectedColor, backgroundColor: .clear) },
                                               chatFake: { generateFakeIconReversed(foregroundColor: palette.redUI, backgroundColor: .clear) },
                                               chatUnarchive: { NSImage(named: "Icon_ChatUnarchive")!.precomposed(palette.accentIcon) },
                                               chatArchive: { NSImage(named: "Icon_ChatArchive")!.precomposed(palette.accentIcon) },
                                               privacySettings_blocked: { generateSettingsIcon(NSImage(named: "Icon_PrivacySettings_Blocked")!.precomposed(flipVertical: true)) },
                                               privacySettings_activeSessions: { generateSettingsIcon(NSImage(named: "Icon_PrivacySettings_ActiveSessions")!.precomposed(flipVertical: true)) },
                                               privacySettings_passcode: { generateSettingsIcon(NSImage(named: "Icon_SettingsSecurity")!.precomposed(palette.greenUI, flipVertical: true)) },
                                               privacySettings_twoStep: { generateSettingsIcon(NSImage(named: "Icon_PrivacySettings_TwoStep")!.precomposed(flipVertical: true)) },
                                               privacy_settings_autodelete: { generateSettingsIcon(NSImage(named: "Icon_PrivacySettings_AutoDelete")!.precomposed(flipVertical: true)) },
                                               deletedAccount: { NSImage(named: "Icon_DeletedAccount")!.precomposed() },
                                               stickerPackSelection: { generateStickerPackSelection(.clear) },
                                               stickerPackSelectionActive: { generateStickerPackSelection(palette.grayForeground.withAlphaComponent(0.8)) },
                                               entertainment_Emoji: { NSImage(named: "Icon_Entertainment_Emoji")!.precomposed(palette.grayIcon) },
                                               entertainment_Stickers: { NSImage(named: "Icon_Entertainment_Stickers")!.precomposed(palette.grayIcon) },
                                               entertainment_Gifs: { NSImage(named: "Icon_Entertainment_Gifs")!.precomposed(palette.grayIcon) },
                                               entertainment_Search: { NSImage(named: "Icon_Entertainment_Search")!.precomposed(palette.grayIcon) },
                                               entertainment_Settings: { NSImage(named: "Icon_Entertainment_Settings")!.precomposed(palette.grayIcon) },
                                               entertainment_SearchCancel: { NSImage(named: "Icon_Entertainment_SearchCancel")!.precomposed(palette.grayIcon) },
                                               entertainment_AnimatedEmoji:  { NSImage(named: "Icon_Entertainment_AnimatedEmoji")!.precomposed(palette.grayIcon) },
                                               scheduledAvatar: { NSImage(named: "Icon_AvatarScheduled")!.precomposed(.white) },
                                               scheduledInputAction: { NSImage(named: "Icon_ChatActionScheduled")!.precomposed(palette.accentIcon) },
                                               verifyDialog: { generateDialogVerify(background: palette.underSelectedColor, foreground: palette.basicAccent, reversed: true) },
                                               verifyDialogActive: { generateDialogVerify(background: palette.accentIcon, foreground: palette.underSelectedColor, reversed: true) },
                                              verify_dialog_left: { generateDialogVerifyLeft(background: palette.underSelectedColor, foreground: palette.basicAccent, reversed: true) },
                                              verify_dialog_active_left: { generateDialogVerifyLeft(background: palette.accentIcon, foreground: palette.underSelectedColor, reversed: true) },
                                               chatInputScheduled: { NSImage(named: "Icon_ChatInputScheduled")!.precomposed(palette.grayIcon) },
                                               appearanceAddPlatformTheme: {
                                                let image = NSImage(named: "Icon_AppearanceAddTheme")!.precomposed(palette.accentIcon)
                                                return generateImage(image.backingSize, contextGenerator: { size, ctx in
                                                    ctx.clear(NSMakeRect(0, 0, size.width, size.height))
                                                    ctx.draw(image, in: NSMakeRect(0, 0, size.width, size.height))
                                                })! },
                                               wallet_close: { #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.accentIcon) },
                                               wallet_qr: { NSImage(named: "Icon_WalletQR")!.precomposed(palette.accentIcon) },
                                               wallet_receive: { NSImage(named: "Icon_WalletReceive")!.precomposed(palette.underSelectedColor) },
                                               wallet_send: { NSImage(named: "Icon_WalletSend")!.precomposed(palette.underSelectedColor) },
                                               wallet_settings: { NSImage(named: "Icon_WalletSettings")!.precomposed(palette.accentIcon) },
                                               wallet_update: { NSImage(named: "Icon_WalletUpdate")!.precomposed(palette.grayIcon) },
                                               wallet_passcode_visible: { NSImage(named: "Icon_WalletPasscodeVisible")!.precomposed(palette.grayIcon) },
                                               wallet_passcode_hidden: { NSImage(named: "Icon_WalletPasscodeHidden")!.precomposed(palette.grayIcon) },
                                               wallpaper_color_close: { NSImage(named: "Icon_GradientClose")!.precomposed(palette.grayIcon) },
                                               wallpaper_color_add: { NSImage(named: "Icon_GradientAdd")!.precomposed(palette.grayIcon) },
                                               wallpaper_color_swap: { NSImage(named: "Icon_GradientSwap")!.precomposed(palette.grayIcon) },
                                               wallpaper_color_rotate: { NSImage(named: "Icon_GradientRotate")!.precomposed(.white) },
                                               wallpaper_color_play: { NSImage(named: "Icon_ChatMusicPlay")!.precomposed(.white) },
                                               login_cap: { NSImage(named: "Icon_LoginCap")!.precomposed(palette.accentIcon) },
                                               login_qr_cap: { NSImage(named: "Icon_loginQRCap")!.precomposed(palette.accentIcon) },
                                               login_qr_empty_cap: { generateLoginQrEmptyCap() },
                                               chat_failed_scroller: { generateChatFailed(backgroundColor: palette.background, border: palette.redUI, foregroundColor: palette.redUI) },
                                               chat_failed_scroller_active: { generateChatFailed(backgroundColor: palette.background, border: palette.accentIcon, foregroundColor: palette.accentIcon) },
                                               poll_quiz_unselected: { generateUnslectedCap(palette.grayText) },
                                               poll_selected: { generatePollIcon(NSImage(named: "Icon_PollSelected")!, backgound: palette.webPreviewActivity) },
                                               poll_selection: { generatePollIcon(NSImage(named: "Icon_PollSelected")!, backgound: palette.webPreviewActivity) },
                                               poll_selected_correct: { generatePollIcon(NSImage(named: "Icon_PollSelected")!, backgound: palette.greenUI) },
                                               poll_selected_incorrect: { generatePollIcon(NSImage(named: "Icon_PollSelectedIncorrect")!, backgound: palette.redUI) },
                                               poll_selected_incoming: { generatePollIcon(NSImage(named: "Icon_PollSelected")!, backgound: palette.webPreviewActivityBubble_incoming) },
                                               poll_selection_incoming: { generatePollIcon(NSImage(named: "Icon_PollSelected")!, backgound: palette.webPreviewActivityBubble_incoming) },
                                               poll_selected_correct_incoming: { generatePollIcon(NSImage(named: "Icon_PollSelected")!, backgound: palette.greenBubble_incoming) },
                                               poll_selected_incorrect_incoming: { generatePollIcon(NSImage(named: "Icon_PollSelectedIncorrect")!, backgound: palette.redBubble_incoming) },
                                               poll_selected_outgoing: { generatePollIcon(NSImage(named: "Icon_PollSelected")!, backgound: palette.webPreviewActivityBubble_outgoing) },
                                               poll_selection_outgoing: { generatePollIcon(NSImage(named: "Icon_PollSelected")!, backgound: palette.webPreviewActivityBubble_outgoing) },
                                               poll_selected_correct_outgoing: { generatePollIcon(NSImage(named: "Icon_PollSelected")!, backgound: palette.greenBubble_outgoing) },
                                               poll_selected_incorrect_outgoing: { generatePollIcon(NSImage(named: "Icon_PollSelectedIncorrect")!, backgound: palette.redBubble_outgoing) },
                                               chat_filter_edit: { NSImage(named: "Icon_FilterEdit")!.precomposed(palette.accentIcon) },
                                               chat_filter_add: { NSImage(named: "Icon_FilterAdd")!.precomposed(palette.accentIcon) },
                                               chat_filter_bots:  { NSImage(named: "Icon_FilterBots")!.precomposed(palette.accentIcon) },
                                               chat_filter_channels:  { NSImage(named: "Icon_FilterChannels")!.precomposed(palette.accentIcon) },
                                               chat_filter_custom:  { NSImage(named: "Icon_FilterCustom")!.precomposed(palette.accentIcon) },
                                               chat_filter_groups:  { NSImage(named: "Icon_FilterGroups")!.precomposed(palette.accentIcon) },
                                               chat_filter_muted: { NSImage(named: "Icon_FilterMuted")!.precomposed(palette.accentIcon) },
                                               chat_filter_private_chats: { NSImage(named: "Icon_FilterPrivateChats")!.precomposed(palette.accentIcon) },
                                               chat_filter_read: { NSImage(named: "Icon_FilterRead")!.precomposed(palette.accentIcon) },
                                               chat_filter_secret_chats: { NSImage(named: "Icon_FilterSecretChats")!.precomposed(palette.accentIcon) },
                                               chat_filter_unmuted: { NSImage(named: "Icon_FilterUnmuted")!.precomposed(palette.accentIcon) },
                                               chat_filter_unread: { NSImage(named: "Icon_FilterUnread")!.precomposed(palette.accentIcon) },
                                               chat_filter_large_groups: { NSImage(named: "Icon_FilterLargeGroups")!.precomposed(palette.accentIcon) },
                                               chat_filter_non_contacts: { NSImage(named: "Icon_FilterNonContacts")!.precomposed(palette.accentIcon) },
                                               chat_filter_archive: { NSImage(named: "Icon_FilterArchive")!.precomposed(palette.accentIcon) },
                                               chat_filter_bots_avatar:  { NSImage(named: "Icon_FilterBots")!.precomposed(.white) },
                                               chat_filter_channels_avatar:  { NSImage(named: "Icon_FilterChannels")!.precomposed(.white) },
                                               chat_filter_custom_avatar:  { NSImage(named: "Icon_FilterCustom")!.precomposed(.white) },
                                               chat_filter_groups_avatar:  { NSImage(named: "Icon_FilterGroups")!.precomposed(.white) },
                                               chat_filter_muted_avatar: { NSImage(named: "Icon_FilterMuted")!.precomposed(.white) },
                                               chat_filter_private_chats_avatar: { NSImage(named: "Icon_FilterPrivateChats")!.precomposed(.white) },
                                               chat_filter_read_avatar: { NSImage(named: "Icon_FilterRead")!.precomposed(.white) },
                                               chat_filter_secret_chats_avatar: { NSImage(named: "Icon_FilterSecretChats")!.precomposed(.white) },
                                               chat_filter_unmuted_avatar: { NSImage(named: "Icon_FilterUnmuted")!.precomposed(.white) },
                                               chat_filter_unread_avatar: { NSImage(named: "Icon_FilterUnread")!.precomposed(.white) },
                                               chat_filter_large_groups_avatar: { NSImage(named: "Icon_FilterLargeGroups")!.precomposed(.white) },
                                               chat_filter_non_contacts_avatar: { NSImage(named: "Icon_FilterNonContacts")!.precomposed(.white) },
                                               chat_filter_archive_avatar: { NSImage(named: "Icon_FilterArchive")!.precomposed(.white) },
                                               chat_filter_new_chats: { NSImage(resource: .iconFilterNewChats).precomposed(.white) },
                                               chat_filter_existing_chats: { NSImage(resource: .iconFilterExistingChats).precomposed(.white) },
                                               group_invite_via_link: { NSImage(named: "Icon_InviteViaLink")!.precomposed(palette.accentIcon) },
                                               tab_contacts: { NSImage(named: "Icon_TabContacts")!.precomposed(palette.grayIcon) },
                                               tab_contacts_active: { NSImage(named: "Icon_TabContacts")!.precomposed(palette.accentIcon) },
                                               tab_calls: { NSImage(named: "Icon_TabRecentCalls")!.precomposed(palette.grayIcon) },
                                               tab_calls_active: { NSImage(named: "Icon_TabRecentCalls")!.precomposed(palette.accentIcon) },
                                               tab_chats: { NSImage(named: "Icon_TabChatList")!.precomposed(palette.grayIcon) },
                                               tab_chats_active: { NSImage(named: "Icon_TabChatList")!.precomposed(palette.accentIcon) },
                                               tab_chats_active_filters: { generateChatTabFiltersIcon(NSImage(named: "Icon_TabChatList")!.precomposed(palette.accentIcon)) },
                                               tab_settings: { NSImage(named: "Icon_TabSettings")!.precomposed(palette.grayIcon) },
                                               tab_settings_active: { NSImage(named: "Icon_TabSettings")!.precomposed(palette.accentIcon) },
                                               profile_add_member: { generateProfileIcon(NSImage(named: "Icon_Profile_AddMember")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_call: { generateProfileIcon(NSImage(named: "Icon_Profile_Call")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_video_call: { generateProfileIcon(NSImage(named: "Icon_Profile_VideoCall")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_leave: { generateProfileIcon(NSImage(named: "Icon_Profile_Leave")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_message: { generateProfileIcon(NSImage(named: "Icon_Profile_Message")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_more: { generateProfileIcon(NSImage(named: "Icon_Profile_More")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_mute: { generateProfileIcon(NSImage(named: "Icon_Profile_Mute")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_unmute: { generateProfileIcon(NSImage(named: "Icon_Profile_Unmute")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_search: { generateProfileIcon(NSImage(named: "Icon_Profile_Search")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_secret_chat: { generateProfileIcon(NSImage(named: "Icon_Profile_SecretChat")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_edit_photo: { NSImage(named: "Icon_Profile_EditPhoto")!.precomposed(.white)},
                                               profile_block: { generateProfileIcon(NSImage(named: "Icon_Profile_Block")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_report: { generateProfileIcon(NSImage(named: "Icon_Profile_Report")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_share: { generateProfileIcon(NSImage(named: "Icon_Profile_Share")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_stats: { generateProfileIcon(NSImage(named: "Icon_Profile_Stats")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_unblock: { generateProfileIcon(NSImage(named: "Icon_Profile_Unblock")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_translate: { generateProfileIcon(NSImage(named: "Icon_Profile_Translate")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_join_channel: { generateProfileIcon(NSImage(named: "Icon_Profile_JoinChannel")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_boost: { generateProfileIcon(NSImage(named: "Icon_Profile_Boost")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               profile_archive: { generateProfileIcon(NSImage(resource: .iconProfileArchive).precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               stats_boost_boost: { generateProfileIcon(NSImage(named: "Icon_Boost_Boost")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               stats_boost_giveaway: { generateProfileIcon(NSImage(named: "Icon_Boost_Gift")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               stats_boost_info: { generateProfileIcon(NSImage(named: "Icon_Boost_Info")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },

                                               chat_quiz_explanation: { NSImage(named: "Icon_QuizExplanation")!.precomposed(palette.accentIcon) },
                                               chat_quiz_explanation_bubble_incoming: { NSImage(named: "Icon_QuizExplanation")!.precomposed(palette.accentIconBubble_incoming) },
                                               chat_quiz_explanation_bubble_outgoing: { NSImage(named: "Icon_QuizExplanation")!.precomposed(palette.accentIconBubble_outgoing) },
                                               stickers_add_featured: { NSImage(named: "Icon_AddFeaturedStickers")!.precomposed(palette.grayIcon.withAlphaComponent(0.8)) },
                                               stickers_add_featured_unread: { generateUnreadFeaturedStickers(NSImage(named: "Icon_AddFeaturedStickers")!.precomposed(palette.grayIcon.withAlphaComponent(0.8)), palette.redUI) },
                                               stickers_add_featured_active: { NSImage(named: "Icon_AddFeaturedStickers")!.precomposed(palette.grayIcon.darker()) },
                                               stickers_add_featured_unread_active: { generateUnreadFeaturedStickers(NSImage(named: "Icon_AddFeaturedStickers")!.precomposed(palette.grayIcon.darker()), palette.redUI) },
                                               stickers_favorite: { #imageLiteral(resourceName: "Icon_FaveStickers").precomposed(palette.grayIcon.withAlphaComponent(0.8)) },
                                               stickers_favorite_active: { #imageLiteral(resourceName: "Icon_FaveStickers").precomposed(palette.grayIcon.darker()) },
                                               channel_info_promo: { NSImage(named: "Icon_ChannelPromoInfo")!.precomposed(palette.grayIcon) },
                                               channel_info_promo_bubble_incoming: { NSImage(named: "Icon_ChannelPromoInfo")!.precomposed(palette.grayTextBubble_incoming) },
                                               channel_info_promo_bubble_outgoing: { NSImage(named: "Icon_ChannelPromoInfo")!.precomposed(palette.grayTextBubble_outgoing) },
                                               chat_share_message: {  NSImage(named: "Icon_ChannelShare")!.precomposed(palette.accent) },
                                               chat_goto_message: { NSImage(named: "Icon_ChatGoMessage")!.precomposed(palette.accentIcon) },
                                               chat_swipe_reply: { NSImage(named: "Icon_ChannelShare")!.precomposed(palette.accentIcon, flipHorizontal: true) },
                                               chat_like_message: { NSImage(named: "Icon_Like_MessageButton")!.precomposed(palette.accentIcon) },
                                               chat_like_message_unlike: { NSImage(named: "Icon_Like_MessageButtonUnlike")!.precomposed(palette.accentIcon) },
                                               chat_like_inside: { NSImage(named: "Icon_Like_MessageInside")!.precomposed(palette.redUI, flipVertical: true) },
                                               chat_like_inside_bubble_incoming: { NSImage(named: "Icon_Like_MessageInside")!.precomposed(palette.redBubble_incoming, flipVertical: true) },
                                               chat_like_inside_bubble_outgoing: { NSImage(named: "Icon_Like_MessageInside")!.precomposed(palette.redBubble_outgoing, flipVertical: true) },
                                               chat_like_inside_bubble_overlay: { NSImage(named: "Icon_Like_MessageInside")!.precomposed(.white, flipVertical: true) },
                                               chat_like_inside_empty: { NSImage(named: "Icon_Like_MessageInsideEmpty")!.precomposed(palette.grayIcon, flipVertical: true) },
                                               chat_like_inside_empty_bubble_incoming: { NSImage(named: "Icon_Like_MessageInsideEmpty")!.precomposed(palette.grayIconBubble_incoming, flipVertical: true) },
                                               chat_like_inside_empty_bubble_outgoing: { NSImage(named: "Icon_Like_MessageInsideEmpty")!.precomposed(palette.grayIconBubble_outgoing, flipVertical: true) },
                                               chat_like_inside_empty_bubble_overlay: { NSImage(named: "Icon_Like_MessageInsideEmpty")!.precomposed(.white, flipVertical: true) },
                                               gif_trending: { NSImage(named: "Icon_GifTrending")!.precomposed(palette.grayIcon.withAlphaComponent(0.8)) },
                                               gif_trending_active: { NSImage(named: "Icon_GifTrending")!.precomposed(palette.grayIcon.darker()) },
                                               gif_recent: { NSImage(named: "Icon_EmojiTabRecent")!.precomposed(palette.grayIcon.withAlphaComponent(0.8)) },
                                               gif_recent_active: { NSImage(named: "Icon_EmojiTabRecent")!.precomposed(palette.grayIcon.darker()) },
                                               chat_list_thumb_play: { NSImage(named: "Icon_ChatListThumbPlay")!.precomposed() },
                                               call_tooltip_battery_low: { NSImage(named: "Icon_Call_BatteryLow")!.precomposed(.white) },
                                               call_tooltip_camera_off: { NSImage(named: "Icon_Call_CameraOff")!.precomposed(.white) },
                                               call_tooltip_micro_off: { NSImage(named: "Icon_Call_MicroOff")!.precomposed(.white) },
                                               call_screen_sharing: { NSImage(named: "Icon_CallScreenSharing")!.precomposed(.white) },
                                               call_screen_sharing_active: { NSImage(named: "Icon_CallScreenSharing")!.precomposed(.grayIcon) },
                                               call_screen_settings: { NSImage(named: "Icon_CallScreenSettings")!.precomposed(.white) },
                                               search_filter: { NSImage(named: "Icon_SearchFilter")!.precomposed(palette.grayIcon) },
                                               search_filter_media: { NSImage(named: "Icon_SearchFilter_Media")!.precomposed(palette.grayIcon) },
                                               search_filter_files: { NSImage(named: "Icon_SearchFilter_Files")!.precomposed(palette.grayIcon) },
                                               search_filter_links: { NSImage(named: "Icon_SearchFilter_Links")!.precomposed(palette.grayIcon) },
                                               search_filter_music: { NSImage(named: "Icon_SearchFilter_Music")!.precomposed(palette.grayIcon) },
                                               search_filter_downloads: { NSImage(named: "Icon_SearchFilter_Downloads")!.precomposed(palette.grayIcon) },
                                               search_filter_add_peer: { NSImage(named: "Icon_SearchFilter_AddPeer")!.precomposed(palette.grayIcon) },
                                               search_filter_add_peer_active: { NSImage(named: "Icon_SearchFilter_AddPeer")!.precomposed(palette.underSelectedColor) }, 
                                               search_filter_hashtag: { NSImage(resource: .iconSearchFilterHashtag).precomposed(palette.grayIcon) },
                                               search_hashtag_chevron: { NSImage(resource: .iconHorizontalChevron).precomposed(palette.underSelectedColor) },
                                               chat_reply_count_bubble_incoming: { NSImage(named: "Icon_ChatRepliesCount")!.precomposed(palette.grayIconBubble_incoming) },
                                               chat_reply_count_bubble_outgoing: { NSImage(named: "Icon_ChatRepliesCount")!.precomposed(palette.grayIconBubble_outgoing) },
                                               chat_reply_count: { NSImage(named: "Icon_ChatRepliesCount")!.precomposed(palette.grayIcon) },
                                               chat_reply_count_overlay: { NSImage(named: "Icon_ChatRepliesCount")!.precomposed(.white) },
                                               channel_comments_bubble: { NSImage(named: "Icon_ChannelComments_Bubble")!.precomposed(palette.accentIcon
                                                , flipVertical: true) },
                                               channel_comments_bubble_next: { NSImage(named: "Icon_ChannelComments_Next")!.precomposed(palette.accentIcon, flipVertical: true) },
                                               channel_comments_list: { NSImage(named: "Icon_ChannelComments")!.precomposed(palette.accent, flipVertical: true) },
                                               channel_comments_overlay: { NSImage(named: "Icon_ChannelComments_Bubble")!.precomposed(palette.accent) },
                                               chat_replies_avatar: { NSImage(named: "Icon_RepliesChat")!.precomposed() },
                                               group_selection_foreground: { generateChatGroupToggleSelectionForeground(foregroundColor: palette.grayText.withAlphaComponent(0.4), backgroundColor: NSColor.black.withAlphaComponent(0.1)) },
                                               group_selection_foreground_bubble_incoming: { generateChatGroupToggleSelectionForeground(foregroundColor: palette.grayTextBubble_incoming.withAlphaComponent(0.4), backgroundColor: NSColor.black.withAlphaComponent(0.1)) },
                                               group_selection_foreground_bubble_outgoing: { generateChatGroupToggleSelectionForeground(foregroundColor: palette.grayTextBubble_outgoing.withAlphaComponent(0.4), backgroundColor: NSColor.black.withAlphaComponent(0.1)) },
                                               chat_pinned_list: { NSImage(named: "Icon_ChatPinnedList")!.precomposed(palette.accentIcon) },
                                               chat_pinned_message: { NSImage(named: "Icon_ChatPinnedMessage")!.precomposed(palette.accentIcon) },
                                               chat_pinned_message_bubble_incoming: { NSImage(named: "Icon_ChatPinnedMessage")!.precomposed(palette.grayIconBubble_incoming) },
                                               chat_pinned_message_bubble_outgoing: { NSImage(named: "Icon_ChatPinnedMessage")!.precomposed(palette.grayIconBubble_outgoing) },
                                               chat_pinned_message_overlay_bubble: { NSImage(named: "Icon_ChatPinnedMessage")!.precomposed(.white) },
                                               chat_voicechat_can_unmute: { NSImage(named: "Icon_GroupCall_Small_Muted")!.precomposed(.white) },
                                               chat_voicechat_cant_unmute: { NSImage(named: "Icon_GroupCall_Small_Muted")!.precomposed(palette.redUI) },
                                               chat_voicechat_unmuted: { NSImage(named: "Icon_GroupCall_Small_Unmuted")!.precomposed(.white) },
                                               profile_voice_chat: { generateProfileIcon(NSImage(named: "Icon_Profile_VoiceChat")!.precomposed(palette.accentIcon), backgroundColor: palette.accent) },
                                               chat_voice_chat: { generateChatAction(NSImage(named: "Icon_VoiceChat_Title")!.precomposed(palette.accentIcon), background: palette.background) },
                                               chat_voice_chat_active: { generateChatAction(NSImage(named: "Icon_VoiceChat_Title")!.precomposed(palette.accentIcon), background: palette.grayIcon.withAlphaComponent(0.1)) },
                                               editor_draw: { NSImage(named: "Icon_Editor_Paint")!.precomposed(.white) },
                                               editor_delete: { NSImage(named: "Icon_Editor_Delete")!.precomposed(.white) },
                                               editor_crop: { NSImage(named: "Icon_Editor_Crop")!.precomposed(.white) },
                                               fast_copy_link: { NSImage(named: "Icon_FastCopyLink")!.precomposed(palette.accent) },
                                               profile_channel_sign: {NSImage(named: "Icon_Profile_ChannelSign")!.precomposed(flipVertical: true)},
                                               profile_channel_type: {NSImage(named: "Icon_Profile_ChannelType")!.precomposed(flipVertical: true)},
                                               profile_group_type: {NSImage(named: "Icon_Profile_GroupType")!.precomposed(flipVertical: true)},
                                                profile_group_topics: {NSImage(named: "Icon_Profile_Topics")!.precomposed(flipVertical: true)},
                                               profile_group_destruct: {NSImage(named: "Icon_Profile_Destruct")!.precomposed(flipVertical: true)},
                                               profile_group_discussion: {NSImage(named: "Icon_Profile_Discussion")!.precomposed(flipVertical: true)},
                                               profile_requests: {NSImage(named: "Icon_Profile_Requests")!.precomposed(palette.accent, flipVertical: true)},
                                               profile_reactions: { NSImage(named: "Icon_PeerInfo_Reactions")!.precomposed(flipVertical: true) },
                                                profile_channel_color: { NSImage(named: "Icon_PeerInfo_ChannelColor")!.precomposed(flipVertical: true) },
                                               profile_channel_stats: { NSImage(named: "Icon_Profile_Channel_Stats")!.precomposed(flipVertical: true) },
                                               profile_removed: {NSImage(named: "Icon_Profile_Removed")!.precomposed(flipVertical: true)},
                                               profile_links: {NSImage(named: "Icon_Profile_Links")!.precomposed(flipVertical: true)},
                                               destruct_clear_history: { NSImage(named: "Icon_ClearChat")!.precomposed(palette.redUI, flipVertical: true) },
                                               chat_gigagroup_info: { NSImage(named: "Icon_GigagroupInfo")!.precomposed(palette.accent) },
                                               playlist_next: { NSImage(named: "Icon_PlayList_Next")!.precomposed(palette.text) },
                                               playlist_prev: { NSImage(named: "Icon_PlayList_Next")!.precomposed(palette.text, flipHorizontal: true) },
                                               playlist_next_locked: { NSImage(named: "Icon_PlayList_Next")!.precomposed(palette.text.withAlphaComponent(0.6)) },
                                               playlist_prev_locked: { NSImage(named: "Icon_PlayList_Next")!.precomposed(palette.text.withAlphaComponent(0.6), flipHorizontal: true) },
                                               playlist_random: { NSImage(named: "Icon_PlayList_Random")!.precomposed(palette.text) },
                                               playlist_order_normal: { NSImage(named: "Icon_PlayList_Order")!.precomposed(palette.text) },
                                               playlist_order_reversed: { NSImage(named: "Icon_PlayList_Order")!.precomposed(palette.accent) },
                                               playlist_order_random: { NSImage(named: "Icon_PlayList_Random")!.precomposed(palette.accent) },
                                               playlist_repeat_none: { NSImage(named: "Icon_PlayList_Repeat")!.precomposed(palette.text) },
                                               playlist_repeat_circle: { NSImage(named: "Icon_PlayList_Repeat")!.precomposed(palette.accent) },
                                               playlist_repeat_one: { NSImage(named: "Icon_PlayList_RepeatOne")!.precomposed(palette.accent) },
                                               audioplayer_next: { NSImage(named: "Icon_InlinePlayerNext")!.precomposed(palette.accent) },
                                               audioplayer_prev: { NSImage(named: "Icon_InlinePlayerNext")!.precomposed(palette.accent, flipHorizontal: true) },
                                               audioplayer_dismiss: { NSImage(named: "Icon_ChatSearchCancel")!.precomposed(palette.accentIcon) },
                                               audioplayer_repeat_none: { NSImage(named: "Icon_InlinePlayer_Repeat")!.precomposed(palette.grayIcon) },
                                               audioplayer_repeat_circle: { NSImage(named: "Icon_InlinePlayer_Repeat")!.precomposed(palette.accent) },
                                               audioplayer_repeat_one: { NSImage(named: "Icon_InlinePlayer_RepeatOne")!.precomposed(palette.accentIcon) },
                                               audioplayer_locked_next: { NSImage(named: "Icon_InlinePlayerNext")!.precomposed(palette.grayIcon) },
                                               audioplayer_locked_prev: { NSImage(named: "Icon_InlinePlayerNext")!.precomposed(palette.grayIcon, flipHorizontal: true) },
                                               audioplayer_volume: { NSImage(named: "Icon_InlinePlayer_VolumeOn")!.precomposed(palette.accent) },
                                               audioplayer_volume_off: { NSImage(named: "Icon_InlinePlayer_VolumeOff")!.precomposed(palette.grayIcon) },
                                               audioplayer_speed_x1: { NSImage(named: "Icon_InlinePlayer_x2")!.precomposed(palette.grayIcon) },
                                               audioplayer_speed_x2: { NSImage(named: "Icon_InlinePlayer_x2")!.precomposed(palette.accentIcon) },
                                               audioplayer_list: { NSImage(resource: .iconAudioPlayerList).precomposed(palette.grayIcon) },
                                               chat_info_voice_chat: { NSImage(named: "Icon_VoiceChat_Title")!.precomposed(palette.accentIcon) },
                                               chat_info_create_group: { NSImage(named: "Icon_NewGroup")!.precomposed(palette.accentIcon) },
                                               chat_info_change_colors: { NSImage(named: "Icon_ChangeColors")!.precomposed(palette.accentIcon) },
                                               empty_chat_system: { NSImage(named: "Icon_EmptyChat_System")!.precomposed(palette.text) },
                                               empty_chat_dark: { NSImage(named: "Icon_EmptyChat_Dark")!.precomposed(palette.text) },
                                               empty_chat_light: { NSImage(named: "Icon_EmptyChat_Light")!.precomposed(palette.text) },
                                               empty_chat_system_active: { NSImage(named: "Icon_EmptyChat_System")!.precomposed(palette.accent) },
                                               empty_chat_dark_active: { NSImage(named: "Icon_EmptyChat_Dark")!.precomposed(palette.accent) },
                                               empty_chat_light_active: { NSImage(named: "Icon_EmptyChat_Light")!.precomposed(palette.accent) },
                                               empty_chat_storage_clear: { NSImage(named: "Icon_EmptyChat_Storage_Clear")!.precomposed(palette.text) },
                                               empty_chat_storage_low: { NSImage(named: "Icon_EmptyChat_Storage_Medium")!.precomposed(palette.text) },
                                               empty_chat_storage_medium: { NSImage(named: "Icon_EmptyChat_Storage_High")!.precomposed(palette.text) },
                                               empty_chat_storage_high: { NSImage(named: "Icon_EmptyChat_Storage_NoLimit")!.precomposed(palette.text) },
                                               empty_chat_storage_low_active: { NSImage(named: "Icon_EmptyChat_Storage_Medium")!.precomposed(palette.accent) },
                                               empty_chat_storage_medium_active: { NSImage(named: "Icon_EmptyChat_Storage_High")!.precomposed(palette.accent) },
                                               empty_chat_storage_high_active: { NSImage(named: "Icon_EmptyChat_Storage_NoLimit")!.precomposed(palette.accent) },
                                               empty_chat_stickers_none: { NSImage(named: "Icon_EmptyChat_Stickers_None")!.precomposed(palette.text) },
                                               empty_chat_stickers_mysets: { NSImage(named: "Icon_EmptyChat_Stickers_MySets")!.precomposed(palette.text) },
                                               empty_chat_stickers_allsets: { NSImage(named: "Icon_EmptyChat_Stickers_AllSets")!.precomposed(palette.text) },
                                               empty_chat_stickers_none_active: { NSImage(named: "Icon_EmptyChat_Stickers_None")!.precomposed(palette.accent) },
                                               empty_chat_stickers_mysets_active: { NSImage(named: "Icon_EmptyChat_Stickers_MySets")!.precomposed(palette.accent) },
                                               empty_chat_stickers_allsets_active: { NSImage(named: "Icon_EmptyChat_Stickers_AllSets")!.precomposed(palette.accent) },
                                               chat_action_dismiss: { NSImage(named: "Icon_ChatAction_Close")!.precomposed(palette.accent) },
                                               chat_action_edit_message: { NSImage(named: "Icon_ChatAction_EditMessage")!.precomposed(palette.accent) },
                                               chat_action_forward_message: { NSImage(named: "Icon_ChatAction_ForwardMessage")!.precomposed(palette.accent) },
                                               chat_action_reply_message: { NSImage(named: "Icon_ChatAction_ReplyMessage")!.precomposed(palette.accent) },
                                               chat_action_url_preview: { NSImage(named: "Icon_ChatAction_UrlPreview")!.precomposed(palette.accent) },
                                               chat_action_menu_update_chat: { NSImage(named: "Icon_ChatAction_Menu_UpdateChat")!.precomposed(palette.accent) },
                                               chat_action_menu_selected: { NSImage(named: "Icon_UsernameAvailability")!.precomposed(palette.accent) },
                                               widget_peers_favorite: { NSImage(named: "Icon_Widget_Peers_Favorite")!.precomposed(palette.text) },
                                               widget_peers_recent: { NSImage(named: "Icon_Widget_Peers_Recent")!.precomposed(palette.text) },
                                               widget_peers_both: { NSImage(named: "Icon_Widget_Peers_Both")!.precomposed(palette.text) },
                                               widget_peers_favorite_active: { NSImage(named: "Icon_Widget_Peers_Favorite")!.precomposed(palette.accent) },
                                               widget_peers_recent_active: { NSImage(named: "Icon_Widget_Peers_Recent")!.precomposed(palette.accent) },
                                               widget_peers_both_active: { NSImage(named: "Icon_Widget_Peers_Both")!.precomposed(palette.accent) },
                                               chat_reactions_add: {  NSImage(named: "Icon_Reactions_Add")!.precomposed(palette.grayIcon) },
                                               chat_reactions_add_bubble: {  NSImage(named: "Icon_Reactions_Add")!.precomposed(palette.text) },
                                               chat_reactions_add_active: {  NSImage(named: "Icon_Reactions_Add")!.precomposed(palette.accent) },
                                               reactions_badge: { generateBadgeMention(image: NSImage(named: "Icon_ReactionBadge")!, backgroundColor: palette.redUI, foregroundColor: palette.background) },
                                               reactions_badge_active: { generateBadgeMention(image: NSImage(named: "Icon_ReactionBadge")!, backgroundColor: palette.underSelectedColor, foregroundColor: palette.accentSelect) },
                                               reactions_badge_archive: { generateBadgeMention(image: NSImage(named: "Icon_ReactionBadge")!, backgroundColor: palette.badgeMuted, foregroundColor: palette.background) },
                                               reactions_badge_archive_active: { generateBadgeMention(image: NSImage(named: "Icon_ReactionBadge")!, backgroundColor: palette.underSelectedColor, foregroundColor: palette.accentSelect) },
                                               reactions_show_more: { NSImage.init(named: "Icon_Reactions_ShowMore")!.precomposed(NSColor.white) },
                                               chat_reactions_badge: { generateChatMention(image: NSImage(named: "Icon_ReactionButton")!, backgroundColor: palette.background, border: palette.chatBackground == palette.background && palette.isDark ? palette.grayIcon : .clear, foregroundColor: palette.grayIcon) },
                                               chat_reactions_badge_active: { generateChatMention(image: NSImage(named: "Icon_ReactionButton")!, backgroundColor: palette.background, border: palette.chatBackground == palette.background && palette.isDark ? palette.accentIcon : .clear, foregroundColor: palette.accentIcon) },
                                                gallery_pip_close: { NSImage(named: "Icon_Pip_Close")!.precomposed(NSColor(0xffffff)) },
                                                gallery_pip_muted: { NSImage(named: "Icon_Pip_Muted")!.precomposed(NSColor(0xffffff)) },
                                                gallery_pip_unmuted: { NSImage(named: "Icon_Pip_Unmuted")!.precomposed(NSColor(0xffffff)) },
                                                gallery_pip_out: { NSImage(named: "Icon_Pip_Out")!.precomposed(NSColor(0xffffff)) },
                                                gallery_pip_pause: { NSImage(named: "Icon_Pip_Pause")!.precomposed(NSColor(0xffffff)) },
                                                gallery_pip_play: { NSImage(named: "Icon_Pip_Play")!.precomposed(NSColor(0xffffff)) },
                                                notification_sound_add: { NSImage(named: "Icon_Notification_Add")!.precomposed(palette.accent, flipVertical: true) },
                                                premium_lock: { generateLockPremium(palette) },
                                                premium_lock_gray: { NSImage(named: "Icon_Premium_Lock")!.precomposed(palette.grayIcon) },
                                                premium_plus: { NSImage(named: "Icon_Premium_Plus")!.precomposed(NSColor(0xffffff)) },
                                                premium_account: { generatePremium(false, color: palette.accent) },
                                                premium_account_active: { generatePremium(false, color: palette.underSelectedColor) },
                                                premium_account_rev: { generatePremium(true, color: palette.accent) },
                                                premium_account_rev_active: { generatePremium(true, color: palette.underSelectedColor, small: false) },
                                                premium_account_small: { generatePremium(false, color: palette.accent, small: true) },
                                                premium_account_small_active: { generatePremium(false, color: palette.underSelectedColor, small: true) },
                                                premium_account_small_rev: { generatePremium(true, color: palette.accent, small: true) },
                                                premium_account_small_rev_active: { generatePremium(true, color: palette.underSelectedColor, small: true) },
                                                premium_reaction_lock: { NSImage(named: "Icon_Premium_ReactionLock")!.precomposed(palette.accent) },
                                                premium_boarding_feature_next: { NSImage(named: "Premium_Boarding_Feature_Next")!.precomposed(palette.grayIcon) },
                                                premium_stickers: { generateStickerPackPremium() },
                                                premium_emoji_lock: { NSImage(named: "Icon_EmojiLock")!.precomposed(palette.grayIcon)},
                                                account_add_account: { NSImage(named: "Icon_Account_Add_Account")!.precomposed(palette.accent, flipVertical: true)},
                                                account_set_status: { NSImage(named: "Icon_Account_Set_Status")!.precomposed(palette.accent, flipVertical: true)},
                                                account_change_status: { NSImage(named: "Icon_Account_Change_Status")!.precomposed(palette.accent, flipVertical: true)},
                                                chat_premium_status_red: { generatePremium(false, color: palette.groupPeerNameRed, small: true) },
                                                chat_premium_status_orange: { generatePremium(false, color: palette.groupPeerNameOrange, small: true) },
                                                chat_premium_status_violet: { generatePremium(false, color: palette.groupPeerNameViolet, small: true) },
                                                chat_premium_status_green: { generatePremium(false, color: palette.groupPeerNameGreen, small: true) },
                                                chat_premium_status_cyan: { generatePremium(false, color: palette.groupPeerNameCyan, small: true) },
                                                chat_premium_status_light_blue: { generatePremium(false, color: palette.groupPeerNameLightBlue, small: true) },
                                                chat_premium_status_blue: { generatePremium(false, color: palette.groupPeerNameBlue, small: true) },
                                                extend_content_lock: { NSImage(named: "Icon_Premium_Lock")!.precomposed(.white) },
                                                chatlist_forum_closed_topic: { NSImage(named: "Icon_Forum_ClosedTopic")!.precomposed(palette.grayIcon, flipVertical: true) },
                                                chatlist_forum_closed_topic_active: { NSImage(named: "Icon_Forum_ClosedTopic")!.precomposed(palette.underSelectedColor, flipVertical: true) },
                                                chatlist_arrow: { NSImage(named: "Icon_ChatList_Arrow")!.precomposed(palette.text) },
                                                chatlist_arrow_active: { NSImage(named: "Icon_ChatList_Arrow")!.precomposed(palette.underSelectedColor) },
                                                dialog_auto_delete: {NSImage(named: "Icon_AutoDeleteCircle")!.precomposed(.white)},
                                                contact_set_photo: { NSImage(named: "Icon_PhotoCameraPlus")!.precomposed(palette.accent, flipVertical: true) },
                                                contact_suggest_photo: { NSImage(named: "Icon_PhotoCameraSuggest")!.precomposed(palette.accent, flipVertical: true) },
                                                send_media_spoiler: { NSImage.init(named: "Icon_PreviewSpoiler")!.precomposed(palette.grayIcon) },
                                                general_delete: { NSImage(named: "Icon_MessageActionPanelDelete")!.precomposed(palette.redUI, flipVertical: true) },
                                                storage_music_play: { NSImage(named: "Icon_Pip_Play")!.precomposed(palette.underSelectedColor, zoom: 0.8) },
                                                storage_music_pause: { NSImage(named: "Icon_Pip_Pause")!.precomposed(palette.underSelectedColor, zoom: 0.8) },
                                                storage_media_play: { NSImage(named: "Icon_Pip_Play")!.precomposed(palette.underSelectedColor, zoom: 0.6) },
                                                general_chevron_up: { NSImage(named: "Icon_HorizontalChevron")!.precomposed(palette.grayIcon, flipVertical: true) },
                                                general_chevron_down: { NSImage(named: "Icon_HorizontalChevron")!.precomposed(palette.grayIcon) },
                                                account_settings_set_password: { NSImage(named: "Icon_Settings_AddPassword")!.precomposed(palette.accent, flipVertical: true) },
                                                select_peer_create_channel: { NSImage(named: "Icon_CreateChannel")!.precomposed(palette.accent, flipVertical: true) },
                                                select_peer_create_group: { NSImage(named: "Icon_CreateGroup")!.precomposed(palette.accent, flipVertical: true) },
                                                chat_translate: { NSImage(named: "Icon_Chat_Translate")!.precomposed(palette.accent) },
                                                msg_emoji_activities: { NSImage(named: "msg_emoji_activities")!.precomposed(palette.grayIcon) },
                                                msg_emoji_angry: { NSImage(named: "msg_emoji_angry")!.precomposed(palette.grayIcon) },
                                                msg_emoji_away: { NSImage(named: "msg_emoji_away")!.precomposed(palette.grayIcon) },
                                                msg_emoji_bath: { NSImage(named: "msg_emoji_bath")!.precomposed(palette.grayIcon) },
                                                msg_emoji_busy: { NSImage(named: "msg_emoji_busy")!.precomposed(palette.grayIcon) },
                                                msg_emoji_dislike: { NSImage(named: "msg_emoji_dislike")!.precomposed(palette.grayIcon) },
                                                msg_emoji_food: { NSImage(named: "msg_emoji_food")!.precomposed(palette.grayIcon) },
                                                msg_emoji_haha: { NSImage(named: "msg_emoji_haha")!.precomposed(palette.grayIcon) },
                                                msg_emoji_happy: { NSImage(named: "msg_emoji_happy")!.precomposed(palette.grayIcon) },
                                                msg_emoji_heart: { NSImage(named: "msg_emoji_heart")!.precomposed(palette.grayIcon) },
                                                msg_emoji_hi2: { NSImage(named: "msg_emoji_hi2")!.precomposed(palette.grayIcon) },
                                                msg_emoji_home: { NSImage(named: "msg_emoji_home")!.precomposed(palette.grayIcon) },
                                                msg_emoji_like: { NSImage(named: "msg_emoji_like")!.precomposed(palette.grayIcon) },
                                                msg_emoji_neutral: { NSImage(named: "msg_emoji_neutral")!.precomposed(palette.grayIcon) },
                                                msg_emoji_omg: { NSImage(named: "msg_emoji_omg")!.precomposed(palette.grayIcon) },
                                                msg_emoji_party: { NSImage(named: "msg_emoji_party")!.precomposed(palette.grayIcon) },
                                                msg_emoji_recent: { NSImage(named: "msg_emoji_recent")!.precomposed(palette.grayIcon) },
                                                msg_emoji_sad: { NSImage(named: "msg_emoji_sad")!.precomposed(palette.grayIcon) },
                                                msg_emoji_sleep: { NSImage(named: "msg_emoji_sleep")!.precomposed(palette.grayIcon) },
                                                msg_emoji_study: { NSImage(named: "msg_emoji_study")!.precomposed(palette.grayIcon) },
                                                msg_emoji_tongue: { NSImage(named: "msg_emoji_tongue")!.precomposed(palette.grayIcon) },
                                                msg_emoji_vacation: { NSImage(named: "msg_emoji_vacation")!.precomposed(palette.grayIcon) },
                                                msg_emoji_what: { NSImage(named: "msg_emoji_what")!.precomposed(palette.grayIcon) },
                                                msg_emoji_work: { NSImage(named: "msg_emoji_work")!.precomposed(palette.grayIcon) },
                                                msg_emoji_premium: { NSImage(named: "msg_emoji_premium")!.precomposed(palette.grayIcon) },
                                                installed_stickers_archive: { NSImage(named: "Icon_InstalledStickers_Archive")!.precomposed(flipVertical: true) },
                                                installed_stickers_custom_emoji: { NSImage(named: "Icon_InstalledStickers_CustomEmoji")!.precomposed(flipVertical: true) },
                                                installed_stickers_dynamic_order: { NSImage(named: "Icon_InstalledStickers_DynamicOrder")!.precomposed(flipVertical: true) },
                                                installed_stickers_loop: { NSImage(named: "Icon_InstalledStickers_Loop")!.precomposed(flipVertical: true) },
                                                installed_stickers_reactions: { NSImage(named: "Icon_InstalledStickers_Reaction")!.precomposed() },
                                                installed_stickers_suggest: { NSImage(named: "Icon_InstalledStickers_Suggest")!.precomposed(flipVertical: true) },
                                                installed_stickers_trending: { NSImage(named: "Icon_InstalledStickers_Trending")!.precomposed(flipVertical: true) },
                                                folder_invite_link: { generateFolderLinkIcon(palette: palette, revoked: false) },
                                                folder_invite_link_revoked: { generateFolderLinkIcon(palette: palette, revoked: true) },
                              folders_sidebar_edit: { NSImage(named: "Icon_LeftSidebarEditFolders")!.precomposed(palette.grayIcon, flipVertical: true) },
                              folders_sidebar_edit_active: { NSImage(named: "Icon_LeftSidebarEditFolders")!.precomposed(palette.grayIcon.withAlphaComponent(0.8), flipVertical: true) },
                              story_unseen: { generateStoryState(palette.accent, bgColor: palette.background, size: NSMakeSize(50, 50), wide: 1.5) },
                              story_seen: { generateStoryState(palette.grayIcon.withAlphaComponent(0.5), bgColor: palette.background, size: NSMakeSize(50, 50), wide: 1.0) },
                              story_selected: { generateStoryState(palette.underSelectedColor, bgColor: palette.background, size: NSMakeSize(50, 50), wide: 1.0) },
                              story_unseen_chat: { generateStoryState(palette.accent, bgColor: palette.background, size: NSMakeSize(36, 36), wide: 1.5) },
                              story_seen_chat: { generateStoryState(palette.grayIcon, bgColor: palette.background, size: NSMakeSize(36, 36), wide: 1.0) },
                              story_unseen_profile: { generateStoryState(palette.accent, bgColor: palette.background, size: NSMakeSize(120, 120), wide: 1.5) },
                              story_seen_profile: { generateStoryState(palette.grayIcon, bgColor: palette.background, size: NSMakeSize(120, 120), wide: 1.0) },
                              story_view_read: { NSImage(named: "Icon_StoryViewRead")!.precomposed(palette.grayIcon) },
                              story_view_reaction: { NSImage(named: "Icon_StoryViewReaction")!.precomposed(palette.grayIcon) },
                              story_chatlist_reply: { NSImage(named: "Icon_StoryReply")!.precomposed(palette.grayIcon) },
                              story_chatlist_reply_active: { NSImage(named: "Icon_StoryReply")!.precomposed(palette.underSelectedColor) },
                              message_story_expired: { NSImage(named: "Icon_StoryExpired")!.precomposed(palette.chatReplyTitle) },
                              message_story_expired_bubble_incoming: { NSImage(named: "Icon_StoryExpired")!.precomposed(palette.chatReplyTitleBubble_incoming) },
                              message_story_expired_bubble_outgoing: { NSImage(named: "Icon_StoryExpired")!.precomposed(palette.chatReplyTitleBubble_outgoing) },
                              message_quote_accent: { NSImage(named: "Icon_Quote")!.precomposed(palette.accent) },
                              message_quote_red: { NSImage(named: "Icon_Quote")!.precomposed(NSColor(0xCC5049)) },
                              message_quote_orange: { NSImage(named: "Icon_Quote")!.precomposed(NSColor(0xD67722)) },
                              message_quote_violet: { NSImage(named: "Icon_Quote")!.precomposed(NSColor(0x955CDB)) },
                              message_quote_green: { NSImage(named: "Icon_Quote")!.precomposed(NSColor(0x40A920)) },
                              message_quote_cyan: { NSImage(named: "Icon_Quote")!.precomposed(NSColor(0x309EBA)) },
                              message_quote_blue: { NSImage(named: "Icon_Quote")!.precomposed(NSColor(0x368AD1)) },
                              message_quote_pink: { NSImage(named: "Icon_Quote")!.precomposed(NSColor(0xC7508B)) },
                              message_quote_bubble_incoming: { NSImage(named: "Icon_Quote")!.precomposed(palette.chatReplyTitleBubble_incoming) },
                              message_quote_bubble_outgoing: { NSImage(named: "Icon_Quote")!.precomposed(palette.chatReplyTitleBubble_outgoing) },
                              channel_stats_likes: { NSImage(named: "Icon_ChannelStats_Likes")!.precomposed(palette.grayIcon) },
                              channel_stats_shares: { NSImage(named: "Icon_ChannelStats_Shares")!.precomposed(palette.grayIcon) },
                              story_repost_from_white: { NSImage(named: "Icon_StoryRepostFrom")!.precomposed(palette.listGrayText) },
                              story_repost_from_green: { NSImage(named: "Icon_StoryRepostFrom")!.precomposed(palette.greenUI) },
                              channel_feature_background: { NSImage(named: "Icon_ChannelFeature_Background")!.precomposed(palette.accent) },
                              channel_feature_background_photo: { NSImage(named: "Icon_ChannelFeature_BackgroundPhoto")!.precomposed(palette.accent) },
                              channel_feature_cover_color: { NSImage(named: "Icon_ChannelFeature_CoverColor")!.precomposed(palette.accent) },
                              channel_feature_cover_icon: { NSImage(named: "Icon_ChannelFeature_CoverIcon")!.precomposed(palette.accent) },
                              channel_feature_link_color: { NSImage(named: "Icon_ChannelFeature_LinkColor")!.precomposed(palette.accent) },
                              channel_feature_link_icon: { NSImage(named: "Icon_ChannelFeature_LinkIcon")!.precomposed(palette.accent) },
                              channel_feature_name_color: { NSImage(named: "Icon_ChannelFeature_NameColor")!.precomposed(palette.accent) },
                              channel_feature_reaction: { NSImage(named: "Icon_ChannelFeature_Reaction")!.precomposed(palette.accent) },
                              channel_feature_status: { NSImage(named: "Icon_ChannelFeature_Status")!.precomposed(palette.accent) },
                              channel_feature_stories: { NSImage(named: "Icon_ChannelFeature_Stories")!.precomposed(palette.accent) },
                              channel_feature_emoji_pack: { NSImage(named: "Icon_ChannelFeature_EmojiPack")!.precomposed(palette.accent) },
                              channel_feature_voice_to_text: { NSImage(named: "Icon_ChannelFeature_VoiceToText")!.precomposed(palette.accent) },
                              channel_feature_no_ads: { NSImage(resource: .iconFragmentNoAds).precomposed(palette.accent) },
                              channel_feature_autotranslate: { NSImage(resource: .iconBoostTranslation).precomposed(palette.accent) },
                              chat_hidden_author: { NSImage(named: "Icon_AuthorHidden")!.precomposed(.white) },
                              chat_my_notes: { NSImage(named: "Icon_MyNotes")!.precomposed(.white) },
                              premium_required_forward: { NSImage(named: "Icon_PremiumRequired_Forward")!.precomposed() },
                              create_new_message_general: { NSImage(resource: .iconNewMessage).precomposed(palette.accent, flipVertical: true) },
                              bot_manager_settings: { NSImage(resource: .iconBotManagerSettings).precomposed(palette.grayIcon) },
                              preview_text_down: { NSImage(resource: .iconMoveCaptionDown).precomposed(palette.grayIcon) },
                              preview_text_up: { NSImage(resource: .iconMoveCaptionUp).precomposed(palette.grayIcon) },
                              avatar_star_badge: { generateAvatarStarBadge(color: palette.background) },
                              avatar_star_badge_active: { generateAvatarStarBadge(color: palette.accentSelect) },
                              avatar_star_badge_gray: { generateAvatarStarBadge(color: palette.listBackground) },
                              avatar_star_badge_large_gray: { generateAvatarStarBadgeLarge(color: palette.listBackground) },
                              chatlist_apps: { NSImage(resource: .iconChatListApps).precomposed(palette.accent) },
                              chat_input_channel_gift:  { NSImage(resource: .iconChannelGift).precomposed(palette.accent) },
                              chat_input_suggest_message: { NSImage(resource: .iconChatInputMessageSuggestion).precomposed(palette.accent) },
                              chat_input_send_gift: { NSImage(resource: .iconChannelGift).precomposed(palette.grayIcon) },
                              chat_input_suggest_post: { NSImage(resource: .iconInputSuggestPost).precomposed(palette.grayIcon) },
                              todo_selection: { generateTodoSelection(color: palette.webPreviewActivity) },
                              todo_selected: { generateTodoSelected(color: palette.webPreviewActivity) },
                              todo_selection_other_incoming: { generateTodoSelection(color: palette.webPreviewActivityBubble_incoming) },
                              todo_selection_other_outgoing: { generateTodoSelection(color: palette.webPreviewActivityBubble_outgoing) },
                              todo_selected_other_incoming: { generateTodoSelected(color: palette.webPreviewActivityBubble_incoming) },
                              todo_selected_other_outgoing: { generateTodoSelected(color: palette.webPreviewActivityBubble_outgoing) }
                              
    )
}


func generateTheme(palette: ColorPalette, cloudTheme: TelegramTheme?, bubbled: Bool, fontSize: CGFloat, wallpaper: ThemeWallpaper, backgroundSize: NSSize = NSMakeSize(1040, 1580)) -> TelegramPresentationTheme {
    
    let chatList = TelegramChatListTheme(selectedBackgroundColor: palette.accentSelect,
                                         singleLayoutSelectedBackgroundColor: palette.grayBackground,
                                         activeDraggingBackgroundColor: palette.border,
                                         pinnedBackgroundColor: palette.background,
                                         contextMenuBackgroundColor: palette.background,
                                         textColor: palette.text,
                                         grayTextColor: palette.grayText,
                                         secretChatTextColor: palette.accent,
                                         peerTextColor: palette.text,
                                         activityColor: palette.accent,
                                         activitySelectedColor: palette.underSelectedColor,
                                         activityContextMenuColor: palette.accent,
                                         activityPinnedColor: palette.accent,
                                         badgeTextColor: palette.background,
                                         badgeBackgroundColor: palette.badge,
                                         badgeSelectedTextColor: palette.accentSelect,
                                         badgeSelectedBackgroundColor: palette.underSelectedColor,
                                         badgeMutedTextColor: .white,
                                         badgeMutedBackgroundColor: palette.badgeMuted)
    
    let tabBar = TelegramTabBarTheme(color: palette.grayIcon, selectedColor: palette.accentIcon, badgeTextColor: .white, badgeColor: palette.redUI)
    return TelegramPresentationTheme(colors: palette, cloudTheme: cloudTheme, search: SearchTheme(palette.grayBackground, #imageLiteral(resourceName: "Icon_SearchField").precomposed(palette.grayIcon), #imageLiteral(resourceName: "Icon_SearchClear").precomposed(palette.grayIcon), { strings().searchFieldSearch }, palette.text, palette.grayText), chatList: chatList, tabBar: tabBar, icons: generateIcons(from: palette, bubbled: bubbled), bubbled: bubbled, fontSize: fontSize, wallpaper: wallpaper, generated: true, backgroundSize: backgroundSize)
}


func updateTheme(with settings: ThemePaletteSettings, for window: Window? = nil, animated: Bool = false) -> TelegramPresentationTheme {
    let palette: ColorPalette
    switch settings.palette.name {
    case whitePalette.name:
        if settings.palette.accent == whitePalette.accent {
            palette = whitePalette
        } else {
            palette = settings.palette
        }
    case darkPalette.name:
        if settings.palette.accent == darkPalette.accent {
            palette = darkPalette
        } else {
            palette = settings.palette
        }
    case dayClassicPalette.name:
        if settings.palette.accent == dayClassicPalette.accent {
            palette = dayClassicPalette
        } else {
            palette = settings.palette
        }
    case nightAccentPalette.name:
        if settings.palette.accent == nightAccentPalette.accent {
            palette = nightAccentPalette
        } else {
            palette = settings.palette
        }
    case systemPalette.name:
        palette = systemPalette
    default:
        palette = settings.palette
    }
    let theme = generateTheme(palette: palette, cloudTheme: settings.cloudTheme, bubbled: settings.bubbled, fontSize: settings.fontSize, wallpaper: settings.wallpaper)
    return theme
}

private let appearanceDisposable = MetaDisposable()

func telegramUpdateTheme(_ theme: TelegramPresentationTheme, window: Window? = nil, animated: Bool) {
    assertOnMainThread()
    updateTheme(theme)
    if let window = window {
        
        if animated, let contentView = window.contentView, window.isVisible, window.occlusionState.contains(.visible), window.windowNumber > 0 {

            let image = window.windowImageShot()
            let imageView = ImageView()
            imageView.image = image
            imageView.frame = window.bounds
            contentView.addSubview(imageView)

            
            let signal = Signal<Void, NoError>.single(Void()) |> delay(0.05, queue: Queue.mainQueue()) |> afterDisposed { [weak imageView] in
                if let imageView = imageView {
                    imageView.change(opacity: 0, animated: true, removeOnCompletion: false, duration: 0.2, completion: { [weak imageView] completed in
                        imageView?.removeFromSuperview()
                    })
                }
            }
            
            appearanceDisposable.set(signal.start())
            
        }
        window.contentView?.background = theme.colors.background
        window.contentView?.subviews.first?.background = theme.colors.background
        window.appearance = theme.appearance
        
       // NSAppearance.current = theme.appearance
       // window.titl
        
        window.backgroundColor = theme.colors.grayBackground
        window.titlebarAppearsTransparent = true//theme.dark
        
    }
    _themeSignal.set(theme)
}

func setDefaultTheme(for window: Window? = nil) {
    telegramUpdateTheme(generateTheme(palette: dayClassicPalette, cloudTheme: nil, bubbled: false, fontSize: 13.0, wallpaper: ThemeWallpaper()), window: window, animated: false)
}

func generateWebAppThemeParams(_ presentationTheme: PresentationTheme) -> [String: Any] {
    return [
        "bg_color": Int32(bitPattern: presentationTheme.colors.background.rgb),
        "text_color": Int32(bitPattern: presentationTheme.colors.text.rgb),
        "hint_color": Int32(bitPattern: presentationTheme.colors.grayText.rgb),
        "link_color": Int32(bitPattern: presentationTheme.colors.link.rgb),
        "button_color": Int32(bitPattern: presentationTheme.colors.accent.rgb),
        "button_text_color": Int32(bitPattern: presentationTheme.colors.underSelectedColor.rgb),
        "secondary_bg_color":Int32(bitPattern: presentationTheme.colors.listBackground.rgb),
        "header_bg_color": Int32(bitPattern: presentationTheme.colors.listBackground.rgb),
        "accent_text_color": Int32(bitPattern: presentationTheme.colors.accent.rgb),
        "section_bg_color": Int32(bitPattern: presentationTheme.colors.background.rgb),
        "section_header_text_color": Int32(bitPattern: presentationTheme.colors.listGrayText.rgb),
        "subtitle_text_color": Int32(bitPattern: presentationTheme.colors.grayText.rgb),
        "destructive_text_color": Int32(bitPattern: presentationTheme.colors.redUI.rgb),
        "bottom_bar_bg_color": Int32(bitPattern: presentationTheme.colors.grayForeground.rgb),
        "section_separator_color": Int32(bitPattern: presentationTheme.colors.border.rgb)
    ]
}


#if !SHARE
func generateSyntaxThemeParams(_ presentationTheme: TelegramPresentationTheme, bubbled: Bool, isIncoming: Bool) -> [String: NSColor] {
    var textColor = presentationTheme.chat.textColor(isIncoming, bubbled)
    var grayColor = presentationTheme.chat.grayText(isIncoming, bubbled)
    var redColor = presentationTheme.chat.redUI(isIncoming, bubbled)
    var greenColor = presentationTheme.chat.greenUI(isIncoming, bubbled)
    var blueColor = presentationTheme.chat.linkColor(isIncoming, bubbled)
    var purpleColor = presentationTheme.colors.peerAvatarVioletTop

    if presentationTheme.colors.isDark {
        textColor = textColor.lighter(amount: 0.05)
        grayColor = grayColor.lighter(amount: 0.05)
        redColor = redColor.lighter(amount: 0.05)
        greenColor = greenColor.lighter(amount: 0.05)
        blueColor = blueColor.lighter(amount: 0.05)
        purpleColor = purpleColor.lighter(amount: 0.05)
    } else {
        textColor = textColor.darker(amount: 0.15)
        grayColor = grayColor.darker(amount: 0.15)
        redColor = redColor.darker(amount: 0.15)
        greenColor = greenColor.darker(amount: 0.15)
        blueColor = blueColor.darker(amount: 0.15)
        purpleColor = blueColor.darker(amount: 0.15)
    }
    return [
        "comment": grayColor,
        "block-comment": grayColor,
        "prolog": grayColor,
        "doctype": grayColor,
        "cdata": grayColor,
        "punctuation": grayColor,
        "property": purpleColor,
        "tag": greenColor,
        "boolean": greenColor,
        "number": greenColor,
        "constant": redColor,
        "symbol": redColor,
        "deleted": redColor,
        "selector": redColor,
        "attr-name": redColor,
        "string": textColor,
        "char": purpleColor,
        "builtin": textColor,
        "inserted": greenColor,
        "operator": blueColor,
        "entity": blueColor,
        "url": blueColor,
        "atrule": textColor,
        "attr-value": blueColor,
        "keyword": blueColor,
        "function-definition": greenColor,
        "class-name": redColor
    ]
}
#endif
