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
import SyncCore
import SwiftSignalKit
import Postbox
import SyncCore

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


func generateTextIcon(_ text: NSAttributedString) -> CGImage {
    
    let textNode = TextNode.layoutText(text, nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .center)
    
    return generateImage(textNode.0.size, rotatedContext: { size, ctx in
        let rect = NSMakeRect(0, 0, size.width, size.height)
        ctx.clear(rect)
        
        textNode.1.draw(rect.focus(textNode.0.size), in: ctx, backingScaleFactor: System.backingScale, backgroundColor: .clear)
    })!
}

private func generateGradientBubble(_ top: NSColor, _ bottom: NSColor) -> CGImage {
    
    var bottom = bottom
    var top = top
    if !System.supportsTransparentFontDrawing {
        bottom = top.blended(withFraction: 0.5, of: bottom)!
        top = bottom
    }
    
    return generateImage(CGSize(width: 1.0, height: 100), opaque: true, scale: 1.0, rotatedContext: { size, context in
        var locations: [CGFloat] = [0.0, 1.0]
        let colors = [top.cgColor, bottom.cgColor] as NSArray
        
        let colorSpace = deviceColorSpace
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations)!
        
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    })!
}

private func generateProfileIcon(_ image: CGImage, backgroundColor: NSColor) -> CGImage {
    return generateImage(image.backingSize, contextGenerator: { size, ctx in
        let rect = CGRect(origin: CGPoint(), size: size)
        ctx.clear(rect)
        
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fillEllipse(in: NSMakeRect(2, 2, rect.width - 4, rect.height - 4))
        
        ctx.draw(image, in: CGRect(origin: CGPoint(), size: size))
        
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
        
        ctx.setFillColor(background.cgColor)
        ctx.fillEllipse(in: rect)
        ctx.draw(image, in: rect.focus(image.backingSize))
        
    })!
}

private func generatePollIcon(_ image: NSImage, backgound: NSColor) -> CGImage {
    return generateImage(NSMakeSize(18, 18), contextGenerator: { size, ctx in
        let rect = NSMakeRect(0, 0, size.width, size.height)
        ctx.clear(rect)
        
        ctx.setBlendMode(.copy)
        ctx.round(size, size.height / 2)
        ctx.setFillColor(backgound.cgColor)
        ctx.fill(rect)
        
        ctx.setBlendMode(.normal)
        let image = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        if backgound == NSColor(0xffffff) {
            ctx.clip(to: rect, mask: image)
            ctx.clear(rect)
        } else {
            ctx.draw(image, in: rect.focus(NSMakeSize(image.size.width / System.backingScale, image.size.height / System.backingScale)))
        }
    }, scale: System.backingScale)!
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
        
        switch wallpaper {
        case .builtin, .file, .color, .gradient:
            switch backgroundMode {
            case let .background(image):
                let imageSize = image.size.aspectFilled(size)
                ctx.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                ctx.scaleBy(x: 1.0, y: -1.0)
                ctx.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)

                ctx.draw(image.cgImage(forProposedRect: nil, context: nil, hints: nil)!, in: rect.focus(imageSize))
                
                ctx.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                ctx.scaleBy(x: 1.0, y: -1.0)
                ctx.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)

                
                break
            case let .color(color):
                ctx.setFillColor(color.cgColor)
                ctx.fill(rect)
            case let .gradient(top, bottom, rotation):
                let colors = [top, bottom].reversed()
                
                let gradientColors = colors.map { $0.cgColor } as CFArray
                let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                
                var locations: [CGFloat] = []
                for i in 0 ..< colors.count {
                    locations.append(delta * CGFloat(i))
                }
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                
                ctx.saveGState()
                ctx.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                ctx.rotate(by: CGFloat(rotation ?? 0) * CGFloat.pi / -180.0)
                ctx.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                ctx.restoreGState()
            default:
                break
            }
        default:
            break
        }
        
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
            case let .background(image):
                chatServiceItemColor = getAverageColor(image)
            case let .color(color):
                if color != palette.background {
                    chatServiceItemColor = getAverageColor(color)
                } else {
                    chatServiceItemColor = color
                }
            case let .gradient(top, bottom, _):
                if let blended = top.blended(withFraction: 0.5, of: bottom) {
                    chatServiceItemColor = getAverageColor(blended)
                } else {
                    chatServiceItemColor = getAverageColor(top)
                }
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
        let path = NSBezierPath(roundedRect: NSMakeRect(rect.width / 2 - 30, rect.height - 50 - 10 - 60 - 5 - 20 - 5, 60, 20), xRadius: 10, yRadius: 10)
        ctx.addPath(path.cgPath)
        ctx.closePath()
        ctx.fillPath()
        
        
        //fill outgoing bubble
        CATransaction.begin()
        if true {
            
            let image = generateImage(NSMakeSize(150, 30), rotatedContext: { size, ctx in
                ctx.clear(NSMakeRect(0, 0, size.width, size.height))
                
                let data = messageBubbleImageModern(incoming: false, fillColor: palette.bubbleBackgroundTop_outgoing, strokeColor: palette.bubbleBorder_outgoing, neighbors: .none)
                
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
            if palette.bubbleBackgroundTop_outgoing != palette.bubbleBackgroundBottom_outgoing {
                bubble = generateImage(NSMakeSize(150, 30), contextGenerator: { size, ctx in
                    let colors = [palette.bubbleBackgroundTop_outgoing, palette.bubbleBackgroundBottom_outgoing]
                    let rect = NSMakeRect(0, 0, size.width, size.height)
                    ctx.clear(rect)
                    ctx.clip(to: rect, mask: image)
                    
                    let gradientColors = colors.map { $0.cgColor } as CFArray
                    let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                    
                    var locations: [CGFloat] = []
                    for i in 0 ..< colors.count {
                        locations.append(delta * CGFloat(i))
                    }
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: rect.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                })!
            }
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

private func generateDialogVerify(background: NSColor, foreground: NSColor) -> CGImage {
    return generateImage(NSMakeSize(24, 24), rotatedContext: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))

        let image = NSImage(named: "Icon_VerifyDialog")!.precomposed(foreground)
        
        ctx.setFillColor(background.cgColor)
        ctx.fillEllipse(in: NSMakeRect(8, 8, size.width - 16, size.height - 16))
        
        ctx.draw(image, in: CGRect(origin: CGPoint(), size: size))
    })!
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
    return generateImage(NSMakeSize(35, 35), contextGenerator: { size, ctx in
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

private func generateScamIcon(foregroundColor: NSColor, backgroundColor: NSColor) -> CGImage {
    
    let textNode = TextNode.layoutText(NSAttributedString.initialize(string: L10n.markScam, color: foregroundColor, font: .medium(9)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .center)
    
    return generateImage(NSMakeSize(textNode.0.size.width + 8, 16), contextGenerator: { size, ctx in
        ctx.interpolationQuality = .high
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        
        let borderPath = NSBezierPath(roundedRect: NSMakeRect(1, 1, size.width - 2, size.height - 2), xRadius: 2, yRadius: 2)
        
        ctx.setStrokeColor(foregroundColor.cgColor)
        ctx.addPath(borderPath.cgPath)
        ctx.closePath()
        ctx.strokePath()
        
        let textRect = NSMakeRect((size.width - textNode.0.size.width) / 2, (size.height - textNode.0.size.height) / 2 + 1, textNode.0.size.width, textNode.0.size.height)
        textNode.1.draw(textRect, in: ctx, backingScaleFactor: System.backingScale, backgroundColor: backgroundColor)
        
    })!
}

private func generateScamIconReversed(foregroundColor: NSColor, backgroundColor: NSColor) -> CGImage {
    
    let textNode = TextNode.layoutText(NSAttributedString.initialize(string: L10n.markScam, color: foregroundColor, font: .medium(9)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, 20), nil, false, .center)
    return generateImage(NSMakeSize(textNode.0.size.width + 8, 16), rotatedContext: { size, ctx in
        ctx.interpolationQuality = .high
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        
        let borderPath = NSBezierPath(roundedRect: NSMakeRect(1, 1, size.width - 2, size.height - 2), xRadius: 2, yRadius: 2)
        
        ctx.setStrokeColor(foregroundColor.cgColor)
        ctx.addPath(borderPath.cgPath)
        ctx.closePath()
        ctx.strokePath()
        
        let textRect = NSMakeRect((size.width - textNode.0.size.width) / 2, (size.height - textNode.0.size.height) / 2 + 1, textNode.0.size.width, textNode.0.size.height)
        textNode.1.draw(textRect, in: ctx, backingScaleFactor: System.backingScale, backgroundColor: backgroundColor)
        
    })!
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

private func generateChatMention(backgroundColor: NSColor, border: NSColor, foregroundColor: NSColor) -> CGImage {
    return generateImage(NSMakeSize(38, 38), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fillEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2.0, height: size.height - 2.0)))
        ctx.setLineWidth(1.0)
        ctx.setStrokeColor(border.withAlphaComponent(0.7).cgColor)
      //  ctx.strokeEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2.0, height: size.height - 2.0)))

        let icon = #imageLiteral(resourceName: "Icon_ChatMention").precomposed(foregroundColor)
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


private func generateSettingsIcon(_ icon: CGImage) -> CGImage {
    return generateImage(icon.backingSize, contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.setFillColor(.white)
        ctx.fill(CGRect(origin: CGPoint(x: 2, y: 2), size: NSMakeSize(size.width - 4, size.height - 4)))
        ctx.draw(icon, in: CGRect(origin: CGPoint(), size: size))
    })!
}


private func generateSettingsActiveIcon(_ icon: CGImage, background: NSColor) -> CGImage {
    return generateImage(icon.backingSize, contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.setFillColor(background.cgColor)
        ctx.fill(CGRect(origin: CGPoint(x: 2, y: 2), size: NSMakeSize(size.width - 4, size.height - 4)))
        ctx.draw(icon, in: CGRect(origin: CGPoint(), size: size))
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

private func generateBadgeMention(backgroundColor: NSColor, foregroundColor: NSColor) -> CGImage {
    return generateImage(NSMakeSize(20, 20), contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.round(size, size.width/2)
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
        let icon = #imageLiteral(resourceName: "Icon_ChatListMention").precomposed(foregroundColor, flipVertical: true)
        let imageRect = NSMakeRect(floorToScreenPixels(System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height)
        ctx.draw(icon, in: imageRect)
    })!
}

private func generateChatGroupToggleSelected(foregroundColor: NSColor, backgroundColor: NSColor) -> CGImage {
    let icon = #imageLiteral(resourceName: "Icon_Check").precomposed(foregroundColor)
    return generateImage(NSMakeSize(icon.size.width + 2, icon.size.height + 2), contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.round(size, size.width/2)
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
        let imageRect = NSMakeRect((size.width - icon.size.width) / 2, (size.height - icon.size.height) / 2, icon.size.width, icon.size.height)
        ctx.draw(icon, in: imageRect)
    }, scale: 1)!
}

private func generateChatGroupToggleUnselected(foregroundColor: NSColor, backgroundColor: NSColor) -> CGImage {
    let icon = #imageLiteral(resourceName: "Icon_SelectionUncheck").precomposed(foregroundColor)
    return generateImage(NSMakeSize(icon.size.width, icon.size.height), contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.round(size, size.width/2)
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
        let imageRect = NSMakeRect((size.width - icon.size.width) / 2, (size.height - icon.size.height) / 2, icon.size.width, icon.size.height)
        ctx.draw(icon, in: imageRect)
    }, scale: 1)!
}

func generateAvatarPlaceholder(foregroundColor: NSColor, size: NSSize) -> CGImage {
    return generateImage(size, contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.round(size, size.width/2)
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


private func  generateChatScrolldownImage(backgroundColor: NSColor, borderColor: NSColor, arrowColor: NSColor) -> CGImage {
    return generateImage(CGSize(width: 38.0, height: 38.0), contextGenerator: { size, context in
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
    })!
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
    let textColor:NSColor
    let backgroundColor:NSColor
    init(text:[CGImage], uploading:[CGImage], recording:[CGImage], textColor:NSColor, backgroundColor:NSColor) {
        self.text = text
        self.uploading = uploading
        self.recording = recording
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
        return WallpaperSettings(blur: blur, motion: self.motion, color: self.color, intensity: self.intensity)
    }
    func withUpdatedColor(_ color: UInt32?) -> WallpaperSettings {
        return WallpaperSettings(blur: self.blur, motion: self.motion, color: color, intensity: self.intensity)
    }
    
    func isSemanticallyEqual(to other: WallpaperSettings) -> Bool {
        return self.color == other.color && self.intensity == other.intensity
    }
}

enum Wallpaper : Equatable, PostboxCoding {
    case builtin
    case color(UInt32)
    case gradient(UInt32, UInt32, Int32?)
    case image([TelegramMediaImageRepresentation], settings: WallpaperSettings)
    case file(slug: String, file: TelegramMediaFile, settings: WallpaperSettings, isPattern: Bool)
    case none
    case custom(TelegramMediaImageRepresentation, blurred: Bool)
    
    init(_ wallpaper: TelegramWallpaper) {
        switch wallpaper {
        case .builtin:
            self = .builtin
        case let .color(color):
            self = .color(color)
        case let .image(image, settings):
            self = .image(image, settings: settings)
        case let .file(values):
            self = .file(slug: values.slug, file: values.file, settings: values.settings, isPattern: values.isPattern)
        case let .gradient(top, bottom, settings):
            self = .gradient(top, bottom, settings.rotation)
        }
    }
    
    static func ==(lhs: Wallpaper, rhs: Wallpaper) -> Bool {
        switch lhs {
        case .builtin:
            if case .builtin = rhs {
                return true
            } else {
                return false
            }
        case let .color(value):
            if case .color(value) = rhs {
                return true
            } else {
                return false
            }
        case let .gradient(top, bottom, rotation):
            if case .gradient(top, bottom, rotation) = rhs {
                return true
            } else {
                return false
            }
        case let .image(reps, settings):
            if case .image(reps, settings: settings) = rhs {
                return true
            } else {
                return false
            }
        case let .file(slug, lhsFile, settings, isPattern):
            if case .file(slug, let rhsFile, settings, isPattern) = rhs, lhsFile.isSemanticallyEqual(to: rhsFile) {
                return true
            } else {
                return false
            }
        case let .custom(rep, blurred):
            if case .custom(rep, blurred) = rhs {
                return true
            } else {
                return false
            }
        case .none:
            if case .none = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    var wallpaperUrl: String? {
        switch self {
        case .builtin:
            return "builtin"
        case let .file(slug, _, settings, isPattern):
            var options: [String] = []
            if settings.blur {
                options.append("mode=blur")
            }
            if isPattern {
                if let pattern = settings.color {
                    var color = NSColor(argb: pattern).withAlphaComponent(1.0).hexString.lowercased()
                    color = String(color[color.index(after: color.startIndex) ..< color.endIndex])
                    options.append("bg_color=\(color)")
                }
                if let intensity = settings.intensity {
                    options.append("intensity=\(intensity)")
                }
            }
            var optionsString = ""
            if !options.isEmpty {
                optionsString = "?\(options.joined(separator: "&"))"
            }
            return "https://t.me/bg/\(slug)\(optionsString)"
        default:
            return nil
        }
    }
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
        case 0:
            self = .builtin
        case 1:
            self = .color(UInt32(bitPattern: decoder.decodeInt32ForKey("c", orElse: 0)))
        case 2:
            let settings = decoder.decodeObjectForKey("settings", decoder: { WallpaperSettings(decoder: $0) }) as? WallpaperSettings ?? WallpaperSettings()
            self = .image(decoder.decodeObjectArrayWithDecoderForKey("i"), settings: settings)
        case 3:
            let settings = decoder.decodeObjectForKey("settings", decoder: { WallpaperSettings(decoder: $0) }) as? WallpaperSettings ?? WallpaperSettings()
            self = .file(slug: decoder.decodeStringForKey("slug", orElse: ""), file: decoder.decodeObjectForKey("file", decoder: { TelegramMediaFile(decoder: $0) }) as! TelegramMediaFile, settings: settings, isPattern: decoder.decodeInt32ForKey("p", orElse: 0) == 1)
        case 4:
            self = .custom(decoder.decodeObjectForKey("rep", decoder: { TelegramMediaImageRepresentation(decoder: $0) }) as! TelegramMediaImageRepresentation, blurred: decoder.decodeInt32ForKey("b", orElse: 0) == 1)
        case 5:
            self = .none
        case 6:
            self = .gradient(UInt32(bitPattern: decoder.decodeInt32ForKey("ct", orElse: 0)), UInt32(bitPattern: decoder.decodeInt32ForKey("cb", orElse: 0)), decoder.decodeOptionalInt32ForKey("cr"))

        default:
            assertionFailure()
            self = .color(0xffffff)
        }
    }
    
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
        case .builtin:
            encoder.encodeInt32(0, forKey: "v")
        case let .color(color):
            encoder.encodeInt32(1, forKey: "v")
            encoder.encodeInt32(Int32(bitPattern: color), forKey: "c")
        case let .image(representations, settings):
            encoder.encodeInt32(2, forKey: "v")
            encoder.encodeObjectArray(representations, forKey: "i")
            encoder.encodeObject(settings, forKey: "settings")
        case let .file(slug, file, settings, isPattern):
            encoder.encodeInt32(3, forKey: "v")
            encoder.encodeString(slug, forKey: "slug")
            encoder.encodeObject(file, forKey: "file")
            encoder.encodeObject(settings, forKey: "settings")
            encoder.encodeInt32(isPattern ? 1 : 0, forKey: "p")
        case let .custom(resource, blurred):
            encoder.encodeInt32(4, forKey: "v")
            encoder.encodeObject(resource, forKey: "rep")
            encoder.encodeInt32(blurred ? 1 : 0, forKey: "b")
        case .none:
            encoder.encodeInt32(5, forKey: "v")
        case let .gradient(top, bottom, rotation):
            encoder.encodeInt32(6, forKey: "v")
            encoder.encodeInt32(Int32(bitPattern: top), forKey: "ct")
            encoder.encodeInt32(Int32(bitPattern: bottom), forKey: "cb")
            if let rotation = rotation {
                encoder.encodeInt32(rotation, forKey: "cr")
            } else {
                encoder.encodeNil(forKey: "cr")
            }
        }
    }
    
    func withUpdatedBlurrred(_ blurred: Bool) -> Wallpaper {
        switch self {
        case .builtin:
            return self
        case .color:
            return self
        case .gradient:
            return self
        case let .image(representations, settings):
            return .image(representations, settings: WallpaperSettings(blur: blurred, motion: settings.motion, color: settings.color, bottomColor: settings.bottomColor, intensity: settings.intensity, rotation: settings.rotation))
        case let .file(values):
            return .file(slug: values.slug, file: values.file, settings: WallpaperSettings(blur: blurred, motion: settings.motion, color: settings.color, bottomColor: settings.bottomColor, intensity: settings.intensity, rotation: settings.rotation), isPattern: values.isPattern)
        case let .custom(path, _):
            return .custom(path, blurred: blurred)
        case .none:
            return self
        }
    }
    
    func withUpdatedSettings(_ settings: WallpaperSettings) -> Wallpaper {
        switch self {
        case .builtin:
            return self
        case .color:
            return self
        case .gradient:
            return self
        case let .image(representations, _):
            return .image(representations, settings: settings)
        case let .file(values):
            return .file(slug: values.slug, file: values.file, settings: settings, isPattern: values.isPattern)
        case .custom:
            return self
        case .none:
            return self
        }
    }
    
    var isBlurred: Bool {
        switch self {
        case .builtin:
            return false
        case .color:
            return false
        case .gradient:
            return false
        case let .image(_, settings):
            return settings.blur
        case let .file(values):
            return values.settings.blur
        case let .custom(_, blurred):
            return blurred
        case .none:
            return false
        }
    }
    
    var settings: WallpaperSettings {
        switch self {
        case let .image(_, settings):
            return settings
        case let .file(values):
            return values.settings
        case let .color(t):
            return WallpaperSettings(color: t)
        case let .gradient(t, b, r):
            return WallpaperSettings(color: t, bottomColor: b, rotation: r)
        default:
            return WallpaperSettings()
        }
    }
    
    func isSemanticallyEqual(to other: Wallpaper) -> Bool {
        switch self {
        case .none:
            return other == self
        case .builtin:
            return other == self
        case .color:
            return other == self
        case .gradient:
            return other == self
        case let .custom(resource, _):
            if case .custom(resource, _) = other {
                return true
            } else {
                return false
            }
        case let .image(representations, _):
            if case .image(representations, _) = other {
                return true
            } else {
                return false
            }
        case let .file(values):
            if case .file(slug: values.slug, _, _, _) = other {
                return true
            } else {
                return false
            }
        }
    }
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

private func getAverageColor(_ color: NSColor) -> NSColor {
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

func generateBackgroundMode(_ wallpaper: Wallpaper, palette: ColorPalette, maxSize: NSSize = NSMakeSize(1040, 1580)) -> TableBackgroundMode {
    #if !SHARE
    var backgroundMode: TableBackgroundMode
    switch wallpaper {
    case .builtin:
        backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
    case let.color(color):
        backgroundMode = .color(color: NSColor(color))
    case let .gradient(top, bottom, rotation):
        backgroundMode = .gradient(top: NSColor(argb: top).withAlphaComponent(1.0), bottom: NSColor(argb: bottom).withAlphaComponent(1.0), rotation: rotation)
    case let .image(representation, settings):
        if let resource = largestImageRepresentation(representation)?.resource, let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(resource, settings: settings))) {
            backgroundMode = .background(image: image)
        } else {
            backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
        }
        
    case let .file(_, file, settings, _):
        if let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(file.resource, settings: settings))) {
            backgroundMode = .background(image: image)
        } else {
            backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
        }
    case .none:
        backgroundMode = .color(color: palette.chatBackground)
    case let .custom(representation, blurred):
        if let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(representation.resource, settings: WallpaperSettings(blur: blurred)))) {
            backgroundMode = .background(image: image)
        } else {
            backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
        }
    }
    return backgroundMode
    #else
    return .plain
    #endif
}

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
            let new = #imageLiteral(resourceName: "Icon_ChannelViews").precomposed(self.chatServiceItemTextColor, flipVertical: true)
            _chatChannelViewsOverlayServiceBubble = new
            return new
        }
    }
    
    
    private var _chat_reply_count_overlay_service_bubble: CGImage?
    var chat_reply_count_overlay_service_bubble: CGImage {
        if let icon = _chat_reply_count_overlay_service_bubble {
            return icon
        } else {
            let new = NSImage(named: "Icon_ChatRepliesCount")!.precomposed(self.chatServiceItemTextColor, flipVertical: true)
            _chat_reply_count_overlay_service_bubble = new
            return new
        }
    }
    
    private var _chat_like_inside_bubble_service: CGImage?
    var chat_like_inside_bubble_service: CGImage {
        if let icon = _chat_like_inside_bubble_service {
            return icon
        } else {
            
            let new = NSImage(named: "Icon_Like_MessageInside")!.precomposed(self.chatServiceItemTextColor, flipVertical: true)
            _chat_like_inside_bubble_service = new
            return new
        }
    }
    private var _chat_like_inside_empty_bubble_service: CGImage?
    var chat_like_inside_empty_bubble_service: CGImage {
        if let icon = _chat_like_inside_empty_bubble_service {
            return icon
        } else {
            let new = NSImage(named: "Icon_Like_MessageInsideEmpty")!.precomposed(self.chatServiceItemTextColor, flipVertical: true)
            _chat_like_inside_empty_bubble_service = new
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
    
    private var _chatServiceItemColor: NSColor?
    var chatServiceItemColor: NSColor {
        if let value = _chatServiceItemColor {
            return value
        } else {
            let chatServiceItemColor: NSColor
            if bubbled {
                switch backgroundMode {
                case let .background(image):
                    chatServiceItemColor = getAverageColor(image)
                case let .color(color):
                    if color != colors.background {
                        return getAverageColor(color)
                    } else {
                        return color
                    }
                case let .gradient(top, bottom, rotation):
                    if let blended = top.blended(withFraction: 0.5, of: bottom) {
                        return getAverageColor(blended)
                    } else {
                        return getAverageColor(top)
                    }
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
                    chatServiceItemTextColor = .white
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
            let backgroundMode: TableBackgroundMode = generateBackgroundMode(wallpaper.wallpaper, palette: colors, maxSize: backgroundSize)
            
            self._backgroundMode = backgroundMode
            return backgroundMode
        }
    }
    init(colors: ColorPalette, cloudTheme: TelegramTheme?, search: SearchTheme, chatList: TelegramChatListTheme, tabBar: TelegramTabBarTheme, icons: TelegramIconsTheme, bubbled: Bool, fontSize: CGFloat, wallpaper: ThemeWallpaper) {
        self.chatList = chatList
        #if !SHARE
            self.chat = TelegramChatColors(colors, bubbled)
        #endif
        self.tabBar = tabBar
        self.icons = icons
        self.wallpaper = wallpaper
        self.bubbled = bubbled
        self.fontSize = fontSize
        self.cloudTheme = cloudTheme
        
        super.init(colors: colors, search: search)
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
        return TelegramPresentationTheme(colors: colors, cloudTheme: self.cloudTheme, search: self.search, chatList: self.chatList, tabBar: self.tabBar, icons: generateIcons(from: colors, bubbled: self.bubbled), bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper)
    }
    func withUpdatedChatMode(_ bubbled: Bool) -> TelegramPresentationTheme {
        return TelegramPresentationTheme(colors: colors, cloudTheme: self.cloudTheme, search: self.search, chatList: self.chatList, tabBar: self.tabBar, icons: generateIcons(from: colors, bubbled: bubbled), bubbled: bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper)
    }
    
    func withUpdatedBackgroundSize(_ size: NSSize) -> TelegramPresentationTheme {
        self.backgroundSize = size
        return self
    }
    
    func withUpdatedWallpaper(_ wallpaper: ThemeWallpaper) -> TelegramPresentationTheme {
        return TelegramPresentationTheme(colors: self.colors, cloudTheme: self.cloudTheme, search: self.search, chatList: self.chatList, tabBar: self.tabBar, icons: generateIcons(from: colors, bubbled: self.bubbled), bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: wallpaper)
    }
    
    func activity(key:Int32, foregroundColor: NSColor, backgroundColor: NSColor) -> ActivitiesTheme {
        return activityResources.object(key, { () -> Any in
            return ActivitiesTheme(text: textActivityAnimation(foregroundColor), uploading: uploadFileActivityAnimation(foregroundColor, backgroundColor), recording: recordVoiceActivityAnimation(foregroundColor), textColor: foregroundColor, backgroundColor: backgroundColor)
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
                                               verifiedImage: { #imageLiteral(resourceName: "Icon_VerifyPeer").precomposed(flipVertical: true) },
                                               verifiedImageSelected: { #imageLiteral(resourceName: "Icon_VerifyPeerActive").precomposed(flipVertical: true) },
                                               errorImage: { #imageLiteral(resourceName: "Icon_MessageSentFailed").precomposed(flipVertical: true) },
                                               errorImageSelected: { #imageLiteral(resourceName: "Icon_DialogSendingError").precomposed(flipVertical: true) },
                                               chatSearch: { generateChatAction(#imageLiteral(resourceName: "Icon_SearchChatMessages").precomposed(palette.accentIcon), background: palette.background) },
                                               chatSearchActive: { generateChatAction( #imageLiteral(resourceName: "Icon_SearchChatMessages").precomposed(palette.accentIcon), background: palette.grayIcon.withAlphaComponent(0.1)) },
                                               chatCall: { #imageLiteral(resourceName: "Icon_callNavigationHeader").precomposed(palette.accentIcon) },
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
                                               chatGradientBubble_incoming: { generateGradientBubble(palette.bubbleBackground_incoming, palette.bubbleBackground_incoming) },
                                               chatGradientBubble_outgoing: { generateGradientBubble(palette.bubbleBackgroundTop_outgoing, palette.bubbleBackgroundBottom_outgoing) },
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
                                               chatChannelViewsInBubble_incoming: { #imageLiteral(resourceName: "Icon_ChannelViews").precomposed(palette.grayIconBubble_incoming, flipVertical: true) },
                                               chatChannelViewsInBubble_outgoing: { #imageLiteral(resourceName: "Icon_ChannelViews").precomposed(palette.grayIconBubble_outgoing, flipVertical: true) },
                                               chatChannelViewsOutBubble: { #imageLiteral(resourceName: "Icon_ChannelViews").precomposed(palette.grayIcon, flipVertical: true) },
                                               chatChannelViewsOverlayBubble: { #imageLiteral(resourceName: "Icon_ChannelViews").precomposed(.white, flipVertical: true) },
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
                                               audioPlayerPlay: { #imageLiteral(resourceName: "Icon_InlinePlayerPlay").precomposed(palette.accentIcon) },
                                               audioPlayerPause: { #imageLiteral(resourceName: "Icon_InlinePlayerPause").precomposed(palette.accentIcon) },
                                               audioPlayerNext: { #imageLiteral(resourceName: "Icon_InlinePlayerNext").precomposed(palette.accentIcon) },
                                               audioPlayerPrev: { #imageLiteral(resourceName: "Icon_InlinePlayerPrevious").precomposed(palette.accentIcon) },
                                               auduiPlayerDismiss: { #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.accentIcon) },
                                               audioPlayerRepeat: { #imageLiteral(resourceName: "Icon_RepeatAudio").precomposed(palette.grayIcon) },
                                               audioPlayerRepeatActive: { #imageLiteral(resourceName: "Icon_RepeatAudio").precomposed(palette.accentIcon) },
                                               audioPlayerLockedPlay: { #imageLiteral(resourceName: "Icon_InlinePlayerPlay").precomposed(palette.grayIcon) },
                                               audioPlayerLockedNext: { #imageLiteral(resourceName: "Icon_InlinePlayerNext").precomposed(palette.grayIcon) },
                                               audioPlayerLockedPrev: { #imageLiteral(resourceName: "Icon_InlinePlayerPrevious").precomposed(palette.grayIcon) },
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
                                               emojiRecentTab: { #imageLiteral(resourceName: "Icon_EmojiTabRecent").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiSmileTab: { #imageLiteral(resourceName: "Icon_EmojiTabSmiles").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiNatureTab: { #imageLiteral(resourceName: "Icon_EmojiTabNature").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiFoodTab: { #imageLiteral(resourceName: "Icon_EmojiTabFood").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiSportTab: { #imageLiteral(resourceName: "Icon_EmojiTabSports").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiCarTab: { #imageLiteral(resourceName: "Icon_EmojiTabCar").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiObjectsTab: { #imageLiteral(resourceName: "Icon_EmojiTabObjects").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiSymbolsTab: { #imageLiteral(resourceName: "Icon_EmojiTabSymbols").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiFlagsTab: { #imageLiteral(resourceName: "Icon_EmojiTabFlag").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiRecentTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabRecent").precomposed(palette.accentIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiSmileTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabSmiles").precomposed(palette.accentIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiNatureTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabNature").precomposed(palette.accentIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiFoodTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabFood").precomposed(palette.accentIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiSportTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabSports").precomposed(palette.accentIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiCarTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabCar").precomposed(palette.accentIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiObjectsTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabObjects").precomposed(palette.accentIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiSymbolsTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabSymbols").precomposed(palette.accentIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiFlagsTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabFlag").precomposed(palette.accentIcon, flipVertical:true, flipHorizontal:true) },
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
                                               peerInfoVerify: { #imageLiteral(resourceName: "Icon_VerifyPeer").precomposed(flipVertical: true) },
                                               peerInfoVerifyProfile: { #imageLiteral(resourceName: "Icon_VerifyPeer").precomposed() },
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
                                               chatListMention: { generateBadgeMention(backgroundColor: palette.badge, foregroundColor: palette.background) },
                                               chatListMentionActive: { generateBadgeMention(backgroundColor: .white, foregroundColor: palette.accentSelect) },
                                               chatListMentionArchived: { generateBadgeMention(backgroundColor: palette.badgeMuted, foregroundColor: palette.background) },
                                               chatListMentionArchivedActive: { generateBadgeMention(backgroundColor: palette.underSelectedColor, foregroundColor: palette.accentSelect) },
                                               chatMention: { generateChatMention(backgroundColor: palette.background, border: palette.grayIcon, foregroundColor: palette.grayIcon) },
                                               chatMentionActive: { generateChatMention(backgroundColor: palette.background, border: palette.accentIcon, foregroundColor: palette.accentIcon) },
                                               sliderControl: { #imageLiteral(resourceName: "Icon_SliderNormal").precomposed() },
                                               sliderControlActive: { #imageLiteral(resourceName: "Icon_SliderNormal").precomposed() },
                                               stickersTabFave: { #imageLiteral(resourceName: "Icon_FaveStickers").precomposed(palette.grayIcon) },
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
                                               settingsGeneral: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsGeneral").precomposed(flipVertical: true)) },
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
                                               settingsAskQuestionActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsAskQuestion").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
                                               settingsFaqActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsFaq").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.accentSelect) },
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
                                               settingsProfile: { generateSettingsIcon(NSImage(named: "Icon_SettingsProfile")!.precomposed(flipVertical: true)) },
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
                                               playingVoice1x: { #imageLiteral(resourceName: "Icon_PlayingVoice2x").precomposed(palette.grayIcon) },
                                               playingVoice2x: { #imageLiteral(resourceName: "Icon_PlayingVoice2x").precomposed(palette.accentIcon) },
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
                                               peerInfoPermissions: { NSImage(named: "Icon_ChatPermissions")!.precomposed(flipVertical: true) },
                                               peerInfoBanned: { NSImage(named: "Icon_ChatBanned")!.precomposed(flipVertical: true) },
                                               peerInfoMembers: { NSImage(named: "Icon_ChatMembers")!.precomposed(flipVertical: true) },
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
                                               scam: { generateScamIcon(foregroundColor: palette.redUI, backgroundColor: .clear) },
                                               scamActive: { generateScamIcon(foregroundColor: palette.underSelectedColor, backgroundColor: .clear) },
                                               chatScam: { generateScamIconReversed(foregroundColor: palette.redUI, backgroundColor: .clear) },
                                               chatUnarchive: { NSImage(named: "Icon_ChatUnarchive")!.precomposed(palette.accentIcon) },
                                               chatArchive: { NSImage(named: "Icon_ChatArchive")!.precomposed(palette.accentIcon) },
                                               privacySettings_blocked: { generateSettingsIcon(NSImage(named: "Icon_PrivacySettings_Blocked")!.precomposed(flipVertical: true)) },
                                               privacySettings_activeSessions: { generateSettingsIcon(NSImage(named: "Icon_PrivacySettings_ActiveSessions")!.precomposed(flipVertical: true)) },
                                               privacySettings_passcode: { generateSettingsIcon(NSImage(named: "Icon_SettingsSecurity")!.precomposed(palette.greenUI, flipVertical: true)) },
                                               privacySettings_twoStep: { generateSettingsIcon(NSImage(named: "Icon_PrivacySettings_TwoStep")!.precomposed(flipVertical: true)) },
                                               deletedAccount: { NSImage(named: "Icon_DeletedAccount")!.precomposed() },
                                               stickerPackSelection: { generateStickerPackSelection(.clear) },
                                               stickerPackSelectionActive: { generateStickerPackSelection(palette.grayForeground) },
                                               entertainment_Emoji: { NSImage(named: "Icon_Entertainment_Emoji")!.precomposed(palette.grayIcon) },
                                               entertainment_Stickers: { NSImage(named: "Icon_Entertainment_Stickers")!.precomposed(palette.grayIcon) },
                                               entertainment_Gifs: { NSImage(named: "Icon_Entertainment_Gifs")!.precomposed(palette.grayIcon) },
                                               entertainment_Search: { NSImage(named: "Icon_Entertainment_Search")!.precomposed(palette.grayIcon) },
                                               entertainment_Settings: { NSImage(named: "Icon_Entertainment_Settings")!.precomposed(palette.grayIcon) },
                                               entertainment_SearchCancel: { NSImage(named: "Icon_Entertainment_SearchCancel")!.precomposed(palette.grayIcon) },
                                               scheduledAvatar: { NSImage(named: "Icon_AvatarScheduled")!.precomposed(.white) },
                                               scheduledInputAction: { NSImage(named: "Icon_ChatActionScheduled")!.precomposed(palette.accentIcon) },
                                               verifyDialog: { generateDialogVerify(background: .white, foreground: palette.basicAccent) },
                                               verifyDialogActive: { generateDialogVerify(background: palette.accentIcon, foreground: palette.underSelectedColor) },
                                               chatInputScheduled: { NSImage(named: "Icon_ChatInputScheduled")!.precomposed(palette.grayIcon) },
                                               appearanceAddPlatformTheme: {
                                                let image = NSImage(named: "Icon_AppearanceAddTheme")!.precomposed(palette.accentIcon)
                                                return generateImage(image.backingSize, contextGenerator: { size, ctx in
                                                    ctx.clear(NSMakeRect(0, 0, size.width, size.height))
                                                    ctx.draw(image, in: NSMakeRect(0, 0, size.width, size.height))
                                                }, scale: System.backingScale)! },
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
                                               wallpaper_color_rotate: { NSImage(named: "Icon_GradientRotate")!.precomposed(palette.grayIcon) },
                                               login_cap: { NSImage(named: "Icon_LoginCap")!.precomposed(palette.accentIcon) },
                                               login_qr_cap: { NSImage(named: "Icon_loginQRCap")!.precomposed(palette.accentIcon) },
                                               login_qr_empty_cap: { generateLoginQrEmptyCap() },
                                               chat_failed_scroller: { generateChatFailed(backgroundColor: palette.background, border: palette.redUI, foregroundColor: palette.redUI) },
                                               chat_failed_scroller_active: { generateChatFailed(backgroundColor: palette.background, border: palette.accentIcon, foregroundColor: palette.accentIcon) },
                                               poll_quiz_unselected: { generateUnslectedCap(palette.grayText) },
                                               poll_selected: { generatePollIcon(NSImage(named: "Icon_PollSelected")!, backgound: palette.webPreviewActivity) },
                                               poll_selected_correct: { generatePollIcon(NSImage(named: "Icon_PollSelected")!, backgound: palette.greenUI) },
                                               poll_selected_incorrect: { generatePollIcon(NSImage(named: "Icon_PollSelectedIncorrect")!, backgound: palette.redUI) },
                                               poll_selected_incoming: { generatePollIcon(NSImage(named: "Icon_PollSelected")!, backgound: palette.webPreviewActivityBubble_incoming) },
                                               poll_selected_correct_incoming: { generatePollIcon(NSImage(named: "Icon_PollSelected")!, backgound: palette.greenBubble_incoming) },
                                               poll_selected_incorrect_incoming: { generatePollIcon(NSImage(named: "Icon_PollSelectedIncorrect")!, backgound: palette.redBubble_incoming) },
                                               poll_selected_outgoing: { generatePollIcon(NSImage(named: "Icon_PollSelected")!, backgound: palette.webPreviewActivityBubble_outgoing) },
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
                                               profile_add_member: { generateProfileIcon(NSImage(named: "Icon_Profile_AddMember")!.precomposed(palette.accentIcon), backgroundColor: palette.underSelectedColor) },
                                               profile_call: { generateProfileIcon(NSImage(named: "Icon_Profile_Call")!.precomposed(palette.accentIcon), backgroundColor: palette.underSelectedColor) },
                                               profile_video_call: { generateProfileIcon(NSImage(named: "Icon_Profile_VideoCall")!.precomposed(palette.accentIcon), backgroundColor: palette.underSelectedColor) },
                                               profile_leave: { generateProfileIcon(NSImage(named: "Icon_Profile_Leave")!.precomposed(palette.accentIcon), backgroundColor: palette.underSelectedColor) },
                                               profile_message: { generateProfileIcon(NSImage(named: "Icon_Profile_Message")!.precomposed(palette.accentIcon), backgroundColor: palette.underSelectedColor) },
                                               profile_more: { generateProfileIcon(NSImage(named: "Icon_Profile_More")!.precomposed(palette.accentIcon), backgroundColor: palette.underSelectedColor) },
                                               profile_mute: { generateProfileIcon(NSImage(named: "Icon_Profile_Mute")!.precomposed(palette.accentIcon), backgroundColor: palette.underSelectedColor) },
                                               profile_unmute: { generateProfileIcon(NSImage(named: "Icon_Profile_Unmute")!.precomposed(palette.accentIcon), backgroundColor: palette.underSelectedColor) },
                                               profile_search: { generateProfileIcon(NSImage(named: "Icon_Profile_Search")!.precomposed(palette.accentIcon), backgroundColor: palette.underSelectedColor) },
                                               profile_secret_chat: { generateProfileIcon(NSImage(named: "Icon_Profile_SecretChat")!.precomposed(palette.accentIcon), backgroundColor: palette.underSelectedColor) },
                                               profile_edit_photo: { NSImage(named: "Icon_Profile_EditPhoto")!.precomposed(.white)},
                                               profile_block: { generateProfileIcon(NSImage(named: "Icon_Profile_Block")!.precomposed(palette.accentIcon), backgroundColor: palette.underSelectedColor) },
                                               profile_report: { generateProfileIcon(NSImage(named: "Icon_Profile_Report")!.precomposed(palette.accentIcon), backgroundColor: palette.underSelectedColor) },
                                               profile_share: { generateProfileIcon(NSImage(named: "Icon_Profile_Share")!.precomposed(palette.accentIcon), backgroundColor: palette.underSelectedColor) },
                                               profile_stats: { generateProfileIcon(NSImage(named: "Icon_Profile_Stats")!.precomposed(palette.accentIcon), backgroundColor: palette.underSelectedColor) },
                                               profile_unblock: { generateProfileIcon(NSImage(named: "Icon_Profile_Unblock")!.precomposed(palette.accentIcon), backgroundColor: palette.underSelectedColor) },
                                               chat_quiz_explanation: { NSImage(named: "Icon_QuizExplanation")!.precomposed(palette.accentIcon) },
                                               chat_quiz_explanation_bubble_incoming: { NSImage(named: "Icon_QuizExplanation")!.precomposed(palette.accentIconBubble_incoming) },
                                               chat_quiz_explanation_bubble_outgoing: { NSImage(named: "Icon_QuizExplanation")!.precomposed(palette.accentIconBubble_outgoing) },
                                               stickers_add_featured: { NSImage(named: "Icon_AddFeaturedStickers")!.precomposed(palette.grayIcon) },
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
                                               gif_trending: { NSImage(named: "Icon_GifTrending")!.precomposed(palette.grayIcon) },
                                               chat_list_thumb_play: { NSImage(named: "Icon_ChatListThumbPlay")!.precomposed() },
                                               inline_audio_volume: { NSImage(named: "Icon_InlinePlayer_VolumeOn")!.precomposed(palette.accent) },
                                               inline_audio_volume_off: { NSImage(named: "Icon_InlinePlayer_VolumeOff")!.precomposed(palette.grayIcon) },
                                               call_tooltip_battery_low: { NSImage(named: "Icon_Call_BatteryLow")!.precomposed(.white) },
                                               call_tooltip_camera_off: { NSImage(named: "Icon_Call_CameraOff")!.precomposed(.white) },
                                               call_tooltip_micro_off: { NSImage(named: "Icon_Call_MicroOff")!.precomposed(.white) },
                                               call_screen_sharing: { NSImage(named: "Icon_CallScreenSharing")!.precomposed(.white) },
                                               call_screen_sharing_active: { NSImage(named: "Icon_CallScreenSharing")!.precomposed(.grayIcon) },
                                               search_filter: { NSImage(named: "Icon_SearchFilter")!.precomposed(palette.grayIcon) },
                                               search_filter_media: { NSImage(named: "Icon_SearchFilter_Media")!.precomposed(palette.grayIcon) },
                                               search_filter_files: { NSImage(named: "Icon_SearchFilter_Files")!.precomposed(palette.grayIcon) },
                                               search_filter_links: { NSImage(named: "Icon_SearchFilter_Links")!.precomposed(palette.grayIcon) },
                                               search_filter_music: { NSImage(named: "Icon_SearchFilter_Music")!.precomposed(palette.grayIcon) },
                                               search_filter_add_peer: { NSImage(named: "Icon_SearchFilter_AddPeer")!.precomposed(palette.grayIcon) },
                                               search_filter_add_peer_active: { NSImage(named: "Icon_SearchFilter_AddPeer")!.precomposed(palette.underSelectedColor) }, 
                                               chat_reply_count_bubble_incoming: { NSImage(named: "Icon_ChatRepliesCount")!.precomposed(palette.grayIconBubble_incoming, flipVertical: true) },
                                               chat_reply_count_bubble_outgoing: { NSImage(named: "Icon_ChatRepliesCount")!.precomposed(palette.grayIconBubble_outgoing, flipVertical: true) },
                                               chat_reply_count: { NSImage(named: "Icon_ChatRepliesCount")!.precomposed(palette.grayIcon, flipVertical: true) },
                                               chat_reply_count_overlay: { NSImage(named: "Icon_ChatRepliesCount")!.precomposed(.white, flipVertical: true) },
                                               channel_comments_bubble: { NSImage(named: "Icon_ChannelComments_Bubble")!.precomposed(palette.linkBubble_incoming, flipVertical: true) },
                                               channel_comments_bubble_next: { NSImage(named: "Icon_ChannelComments_Next")!.precomposed(palette.linkBubble_incoming, flipVertical: true) },
                                               channel_comments_list: { NSImage(named: "Icon_ChannelComments")!.precomposed(palette.accent, flipVertical: true) },
                                               channel_comments_overlay: { NSImage(named: "Icon_ChannelComments_Bubble")!.precomposed(palette.accent) },
                                               chat_replies_avatar: { NSImage(named: "Icon_RepliesChat")!.precomposed() }

    )

}
func generateTheme(palette: ColorPalette, cloudTheme: TelegramTheme?, bubbled: Bool, fontSize: CGFloat, wallpaper: ThemeWallpaper) -> TelegramPresentationTheme {
    
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
    return TelegramPresentationTheme(colors: palette, cloudTheme: cloudTheme, search: SearchTheme(palette.grayBackground, #imageLiteral(resourceName: "Icon_SearchField").precomposed(palette.grayIcon), #imageLiteral(resourceName: "Icon_SearchClear").precomposed(palette.grayIcon), { L10n.searchFieldSearch }, palette.text, palette.grayText), chatList: chatList, tabBar: tabBar, icons: generateIcons(from: palette, bubbled: bubbled), bubbled: bubbled, fontSize: fontSize, wallpaper: wallpaper)
}


func updateTheme(with settings: ThemePaletteSettings, for window: Window? = nil, animated: Bool = false) {
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
    telegramUpdateTheme(generateTheme(palette: palette, cloudTheme: settings.cloudTheme, bubbled: settings.bubbled, fontSize: settings.fontSize, wallpaper: settings.wallpaper), window: window, animated: animated)
}

private let appearanceDisposable = MetaDisposable()

private func telegramUpdateTheme(_ theme: TelegramPresentationTheme, window: Window? = nil, animated: Bool) {
    assertOnMainThread()
    updateTheme(theme)
    if let window = window {
        
        if animated, let contentView = window.contentView {

            let image = window.windowImageShot()
            let imageView = ImageView()
            imageView.image = image
            imageView.frame = window.bounds
            contentView.addSubview(imageView)

            
            let signal = Signal<Void, NoError>.single(Void()) |> delay(0.25, queue: Queue.mainQueue()) |> afterDisposed { [weak imageView] in
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
        
//        NSAppearance.current = theme.appearance
       // window.titl
        window.backgroundColor = theme.colors.grayBackground
        window.titlebarAppearsTransparent = true//theme.dark
        
    }
    _themeSignal.set(theme)
}

func setDefaultTheme(for window: Window? = nil) {
    telegramUpdateTheme(generateTheme(palette: dayClassicPalette, cloudTheme: nil, bubbled: false, fontSize: 13.0, wallpaper: ThemeWallpaper()), window: window, animated: false)
}

