//
//  Appearance.swift
//  Telegram
//
//  Created by keepcoder on 22/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac

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
        case .builtin, .file, .color:
            switch backgroundMode {
            case let .background(image):
                let imageSize = image.size.aspectFilled(size)
                ctx.draw(image.precomposed(flipVertical: true), in: rect.focus(imageSize))
                break
            case let .color(color):
                ctx.setFillColor(color.cgColor)
                ctx.fill(rect)
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
        let chatAction = NSImage(named: "Icon_ChatActions")!.precomposed(palette.blueIcon)
        ctx.draw(chatAction, in: NSMakeRect(rect.width - 20 - chatAction.backingSize.width, (50 - chatAction.backingSize.height) / 2, chatAction.backingSize.width, chatAction.backingSize.height))
        
        //fill attach icon
        let inputAttach = NSImage(named: "Icon_ChatAttach")!.precomposed(palette.grayIcon, flipVertical: true)
        ctx.draw(inputAttach, in: NSMakeRect(20, rect.height - 50 + ((50 - inputAttach.backingSize.height) / 2), inputAttach.backingSize.width, inputAttach.backingSize.height))
        
        //fill micro icon
        let micro = NSImage(named: "Icon_RecordVoice")!.precomposed(palette.grayIcon, flipVertical: true)
        ctx.draw(micro, in: NSMakeRect(rect.width - 20 - inputAttach.backingSize.width, (rect.height - 50 + (50 - micro.backingSize.height) / 2), micro.backingSize.width, micro.backingSize.height))
        
        
        //fill date
        ctx.setFillColor(getAverageColor(palette.chatBackground).cgColor)
        let path = NSBezierPath(roundedRect: NSMakeRect(rect.width / 2 - 30, rect.height - 50 - 10 - 60 - 5 - 20 - 5, 60, 20), xRadius: 10, yRadius: 10)
        ctx.addPath(path.cgPath)
        ctx.closePath()
        ctx.fillPath()
        
        
        //fill outgoing bubble
        if true {
            let data = messageBubbleImageModern(incoming: false, fillColor: palette.bubbleBackground_outgoing, strokeColor: palette.bubbleBorder_outgoing, neighbors: .none)
            
            let layer = CALayer()
            layer.frame = NSMakeRect(0, 200, 150, 30)
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
            
            ctx.translateBy(x: rect.width - 170, y: rect.height - 50 - 10)
            ctx.scaleBy(x: 1.0, y: -1.0)
            layer.render(in: ctx)
        }
        
        //fill incoming bubble
        if true {
            let data = messageBubbleImageModern(incoming: true, fillColor: palette.bubbleBackground_incoming, strokeColor: palette.bubbleBorder_incoming, neighbors: .none)
            
            let layer = CALayer()
            layer.frame = NSMakeRect(0, 200, 150, 30)
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
            
            ctx.translateBy(x: -130, y: 35)
            layer.render(in: ctx)
        }
        
        
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
        ctx.strokeEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2.0, height: size.height - 2.0)))

        let icon = #imageLiteral(resourceName: "Icon_ChatMention").precomposed(foregroundColor)
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
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        
        let icon = #imageLiteral(resourceName: "Icon_EmptySearchResults").precomposed(color)
        let imageSize = icon.backingSize.fitted(size)
        let imageRect = NSMakeRect(floorToScreenPixels(System.backingScale, (size.width - imageSize.width) / 2), floorToScreenPixels(System.backingScale, (size.height - imageSize.height) / 2), imageSize.width, imageSize.height)
        
        ctx.draw(icon, in: imageRect)
    })!
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
    return generateImage(NSMakeSize(icon.backingSize.width + 2, icon.backingSize.height + 2), contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.round(size, size.width/2)
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
        let imageRect = NSMakeRect((size.width - icon.backingSize.width) / 2, (size.height - icon.backingSize.height) / 2, icon.backingSize.width, icon.backingSize.height)
        ctx.draw(icon, in: imageRect)
    })!
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
private func generateSendingHour(_ color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(12, 12), contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.setFillColor(color.cgColor)
        ctx.fill(NSMakeRect(5,5,4,1.5))
    })!
}
private func generateSendingMin(_ color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(12, 12), contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.setFillColor(color.cgColor)
        ctx.fill(NSMakeRect(5, 5, 4, 1))
    })!
}

private func generateChatScrolldownImage(backgroundColor: NSColor, borderColor: NSColor, arrowColor: NSColor) -> CGImage {
    return generateImage(CGSize(width: 38.0, height: 38.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2.0, height: size.height - 2.0)))
        context.setLineWidth(1.0)
        context.setStrokeColor(borderColor.withAlphaComponent(0.7).cgColor)
        context.strokeEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2.0, height: size.height - 2.0)))
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


extension TelegramPresentationTheme {
    var appearance: NSAppearance? {
        if #available(OSX 10.14, *), followSystemAppearance {
            return nil
        } else {
            return colors.isDark ? NSAppearance(named: NSAppearance.Name.vibrantDark) : NSAppearance(named: NSAppearance.Name.vibrantLight)
        }
    }
}

extension WallpaperSettings {
    func withUpdatedBlur(_ blur: Bool) -> WallpaperSettings {
        return WallpaperSettings(blur: blur, motion: self.motion, color: self.color, intensity: self.intensity)
    }
    func withUpdatedColor(_ color: Int32?) -> WallpaperSettings {
        return WallpaperSettings(blur: self.blur, motion: self.motion, color: color, intensity: self.intensity)
    }
    
    func isSemanticallyEqual(to other: WallpaperSettings) -> Bool {
        return self.color == other.color && self.intensity == other.intensity
    }
}

enum Wallpaper : Equatable, PostboxCoding {
    case builtin
    case color(Int32)
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
                    var color = NSColor(rgb: UInt32(bitPattern: pattern)).hexString.lowercased()
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
            self = .color(decoder.decodeInt32ForKey("c", orElse: 0))
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
            encoder.encodeInt32(color, forKey: "c")
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
        }
    }
    
    func withUpdatedBlurrred(_ blurred: Bool) -> Wallpaper {
        switch self {
        case .builtin:
            return self
        case .color:
            return self
        case let .image(representations, settings):
            return .image(representations, settings: WallpaperSettings(blur: blurred, motion: settings.motion, color: settings.color, intensity: settings.intensity))
        case let .file(values):
            return .file(slug: values.slug, file: values.file, settings: WallpaperSettings(blur: blurred, motion: settings.motion, color: settings.color, intensity: settings.intensity), isPattern: values.isPattern)
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
    let followSystemAppearance: Bool
    
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
    
    private var _backgroundMode: TableBackgroundMode?
    var backgroundMode: TableBackgroundMode {
        if let value = _backgroundMode {
            return value
        } else {
            let backgroundMode: TableBackgroundMode
            #if !SHARE
            switch wallpaper.wallpaper {
            case .builtin:
                backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
            case let.color(color):
                backgroundMode = .color(color: NSColor(UInt32(abs(color))))
            case let .image(representation, settings):
                if let resource = largestImageRepresentation(representation)?.resource, let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(resource, blurred: settings.blur))) {
                    backgroundMode = .background(image: image)
                } else {
                    backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
                }
                
            case let .file(_, file, settings, isPattern):
                if let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(file.resource, blurred: settings.blur))) {
                    if isPattern {
                        let image = generateImage(image.size, contextGenerator: { size, ctx in
                            let imageRect = NSMakeRect(0, 0, size.width, size.height)
                            var _patternColor: NSColor = NSColor(rgb: 0xd6e2ee, alpha: 0.5)
                            
                            var patternIntensity: CGFloat = 0.5
                            if let color = settings.color {
                                if let intensity = settings.intensity {
                                    patternIntensity = CGFloat(intensity) / 100.0
                                }
                                _patternColor = NSColor(rgb: UInt32(bitPattern: color), alpha: patternIntensity)
                            }
                            
                            let color = _patternColor.withAlphaComponent(1.0)
                            let intensity = _patternColor.alpha
                            
                            ctx.setBlendMode(.copy)
                            ctx.setFillColor(color.cgColor)
                            ctx.fill(imageRect)
                            
                            ctx.setBlendMode(.normal)
                            ctx.interpolationQuality = .high
                            
                            ctx.clip(to: imageRect, mask: image.cgImage(forProposedRect: nil, context: nil, hints: nil)!)
                            ctx.setFillColor(patternColor(for: color, intensity: intensity).cgColor)
                            ctx.fill(imageRect)
                        })!
                        backgroundMode = .background(image: NSImage(cgImage: image, size: image.size))
                    } else {
                        backgroundMode = .background(image: image)
                    }
                } else {
                    backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
                }
            case .none:
                backgroundMode = .color(color: colors.chatBackground)
            case let .custom(representation, blurred):
                if let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(representation.resource, blurred: blurred))) {
                    backgroundMode = .background(image: image)
                } else {
                    backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
                }
            }
            #else
            backgroundMode = .plain
            #endif
            
            self._backgroundMode = backgroundMode
            return backgroundMode
        }
    }
    init(colors: ColorPalette, cloudTheme: TelegramTheme?, search: SearchTheme, chatList: TelegramChatListTheme, tabBar: TelegramTabBarTheme, icons: TelegramIconsTheme, bubbled: Bool, fontSize: CGFloat, wallpaper: ThemeWallpaper, followSystemAppearance: Bool) {
        self.chatList = chatList
        #if !SHARE
            self.chat = TelegramChatColors(colors, bubbled)
        #endif
        self.tabBar = tabBar
        self.icons = icons
        self.wallpaper = wallpaper
        self.bubbled = bubbled
        self.fontSize = fontSize
        self.followSystemAppearance = followSystemAppearance
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
        return TelegramPresentationTheme(colors: colors, cloudTheme: self.cloudTheme, search: self.search, chatList: self.chatList, tabBar: self.tabBar, icons: generateIcons(from: colors, bubbled: self.bubbled), bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, followSystemAppearance: self.followSystemAppearance)
    }
    func withUpdatedChatMode(_ bubbled: Bool) -> TelegramPresentationTheme {
        return TelegramPresentationTheme(colors: colors, cloudTheme: self.cloudTheme, search: self.search, chatList: self.chatList, tabBar: self.tabBar, icons: generateIcons(from: colors, bubbled: bubbled), bubbled: bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, followSystemAppearance: self.followSystemAppearance)
    }
    func withUpdatedWallpaper(_ wallpaper: ThemeWallpaper) -> TelegramPresentationTheme {
        return TelegramPresentationTheme(colors: self.colors, cloudTheme: self.cloudTheme, search: self.search, chatList: self.chatList, tabBar: self.tabBar, icons: generateIcons(from: colors, bubbled: self.bubbled), bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: wallpaper, followSystemAppearance: self.followSystemAppearance)
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
                              outgoingMessageImage: { #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(palette.name == dayClassicPalette.name && bubbled ? palette.blueIconBubble_outgoing : palette.blueIcon, flipVertical:true) },
                                               readMessageImage: { #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(palette.name == dayClassicPalette.name && bubbled ? palette.blueIconBubble_outgoing : palette.blueIcon, flipVertical:true) },
                                               outgoingMessageImageSelected: { #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(palette.underSelectedColor, flipVertical:true) },
                                               readMessageImageSelected: { #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(palette.underSelectedColor, flipVertical:true) },
                                               sendingImage: { #imageLiteral(resourceName: "Icon_ChatStateSending").precomposed(palette.grayIcon, flipVertical:true) },
                                               sendingImageSelected: { #imageLiteral(resourceName: "Icon_ChatStateSending").precomposed(palette.underSelectedColor, flipVertical:true) },
                                               secretImage: { #imageLiteral(resourceName: "Icon_SecretChatLock").precomposed(bubbled && palette.name == dayClassicPalette.name ? palette.blueIconBubble_outgoing : palette.blueIcon, flipVertical:true) },
                                               secretImageSelected:{  #imageLiteral(resourceName: "Icon_SecretChatLock").precomposed(palette.underSelectedColor, flipVertical:true) },
                                               pinnedImage: { #imageLiteral(resourceName: "Icon_ChatListPinned").precomposed(palette.grayIcon, flipVertical:true) },
                                               pinnedImageSelected: { #imageLiteral(resourceName: "Icon_ChatListPinned").precomposed(palette.underSelectedColor, flipVertical:true) },
                                               verifiedImage: { #imageLiteral(resourceName: "Icon_VerifyPeer").precomposed(flipVertical: true) },
                                               verifiedImageSelected: { #imageLiteral(resourceName: "Icon_VerifyPeerActive").precomposed(flipVertical: true) },
                                               errorImage: { #imageLiteral(resourceName: "Icon_MessageSentFailed").precomposed(flipVertical: true) },
                                               errorImageSelected: { #imageLiteral(resourceName: "Icon_DialogSendingError").precomposed(flipVertical: true) },
                                               chatSearch: { #imageLiteral(resourceName: "Icon_SearchChatMessages").precomposed(palette.blueIcon) },
                                               chatCall: { #imageLiteral(resourceName: "Icon_callNavigationHeader").precomposed(palette.blueIcon) },
                                               chatActions: { #imageLiteral(resourceName: "Icon_ChatActions").precomposed(palette.blueIcon) },
                                               chatFailedCall_incoming: { #imageLiteral(resourceName: "Icon_MessageCallIncoming").precomposed(palette.redUI) },
                                               chatFailedCall_outgoing:  { #imageLiteral(resourceName: "Icon_MessageCallOutgoing").precomposed(palette.redUI) },
                                               chatCall_incoming:  { #imageLiteral(resourceName: "Icon_MessageCallIncoming").precomposed(palette.greenUI) },
                                               chatCall_outgoing:  { #imageLiteral(resourceName: "Icon_MessageCallOutgoing").precomposed(palette.greenUI) },
                                               chatFailedCallBubble_incoming:  { #imageLiteral(resourceName: "Icon_MessageCallIncoming").precomposed(palette.redBubble_incoming) },
                                               chatFailedCallBubble_outgoing:  { #imageLiteral(resourceName: "Icon_MessageCallOutgoing").precomposed(palette.redBubble_outgoing) },
                                               chatCallBubble_incoming:  { #imageLiteral(resourceName: "Icon_MessageCallIncoming").precomposed(palette.greenBubble_incoming) },
                                               chatCallBubble_outgoing:  { #imageLiteral(resourceName: "Icon_MessageCallOutgoing").precomposed(palette.greenBubble_outgoing) },
                                               chatFallbackCall: { #imageLiteral(resourceName: "Icon_MessageCall").precomposed(palette.blueIcon) },
                                               chatFallbackCallBubble_incoming: { #imageLiteral(resourceName: "Icon_MessageCall").precomposed(palette.fileActivityBackgroundBubble_incoming) },
                                               chatFallbackCallBubble_outgoing: { #imageLiteral(resourceName: "Icon_MessageCall").precomposed(palette.fileActivityBackgroundBubble_outgoing) },
                                               
                                               chatToggleSelected:  { generateChatGroupToggleSelected(foregroundColor: palette.blueIcon, backgroundColor: palette.underSelectedColor) },
                                               chatToggleUnselected:  { #imageLiteral(resourceName: "Icon_SelectionUncheck").precomposed() },
                                               chatShare:  { #imageLiteral(resourceName: "Icon_ChannelShare").precomposed(palette.blueIcon) },
                                               chatMusicPlay:  { #imageLiteral(resourceName: "Icon_ChatMusicPlay").precomposed() },
                                               chatMusicPlayBubble_incoming:  { #imageLiteral(resourceName: "Icon_ChatMusicPlay").precomposed(palette.fileActivityForegroundBubble_incoming) },
                                               chatMusicPlayBubble_outgoing:  { #imageLiteral(resourceName: "Icon_ChatMusicPlay").precomposed(palette.fileActivityForegroundBubble_outgoing) },
                                               chatMusicPause:  { #imageLiteral(resourceName: "Icon_ChatMusicPause").precomposed() },
                                               chatMusicPauseBubble_incoming:  { #imageLiteral(resourceName: "Icon_ChatMusicPause").precomposed(palette.fileActivityForegroundBubble_incoming) },
                                               chatMusicPauseBubble_outgoing:  { #imageLiteral(resourceName: "Icon_ChatMusicPause").precomposed(palette.fileActivityForegroundBubble_outgoing) },
                                               composeNewChat: { #imageLiteral(resourceName: "Icon_NewMessage").precomposed(palette.blueIcon) },
                                               composeNewChatActive: { #imageLiteral(resourceName: "Icon_NewMessage").precomposed(palette.underSelectedColor) },
                                               composeNewGroup: { #imageLiteral(resourceName: "Icon_NewGroup").precomposed(palette.blueIcon) },
                                               composeNewSecretChat: { #imageLiteral(resourceName: "Icon_NewSecretChat").precomposed(palette.blueIcon) },
                                               composeNewChannel: { #imageLiteral(resourceName: "Icon_NewChannel").precomposed(palette.blueIcon) },
                                               contactsNewContact: { #imageLiteral(resourceName: "Icon_NewContact").precomposed(palette.blueIcon) },
                                               chatReadMarkInBubble1_incoming: { #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(palette.blueIconBubble_incoming) },
                                               chatReadMarkInBubble2_incoming: { #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(palette.blueIconBubble_incoming) },
                                               chatReadMarkInBubble1_outgoing: { #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(palette.blueIconBubble_outgoing) },
                                               chatReadMarkInBubble2_outgoing: { #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(palette.blueIconBubble_outgoing) },
                                               chatReadMarkOutBubble1: { #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(palette.blueIcon) },
                                               chatReadMarkOutBubble2: { #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(palette.blueIcon) },
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
                                               chatNavigationBack: { #imageLiteral(resourceName: "Icon_ChatNavigationBack").precomposed(palette.blueIcon) },
                                               peerInfoAddMember: { #imageLiteral(resourceName: "Icon_GroupInfoAddMember").precomposed(palette.blueIcon, flipVertical: true) },
                                               chatSearchUp: { #imageLiteral(resourceName: "Icon_SearchArrow").precomposed(palette.blueIcon) },
                                               chatSearchUpDisabled: { #imageLiteral(resourceName: "Icon_SearchArrow").precomposed(palette.grayIcon) },
                                               chatSearchDown: { #imageLiteral(resourceName: "Icon_SearchArrow").precomposed(palette.blueIcon, flipVertical:true) },
                                               chatSearchDownDisabled: { #imageLiteral(resourceName: "Icon_SearchArrow").precomposed(palette.grayIcon, flipVertical:true) },
                                               chatSearchCalendar: { #imageLiteral(resourceName: "Icon_Calendar").precomposed(palette.blueIcon) },
                                               dismissAccessory: { #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.grayIcon) },
                                               chatScrollUp: { generateChatScrolldownImage(backgroundColor: palette.background, borderColor: palette.grayIcon, arrowColor: palette.grayIcon) },
                                               chatScrollUpActive: { generateChatScrolldownImage(backgroundColor: palette.background, borderColor: palette.blueIcon, arrowColor: palette.blueIcon) },
                                               audioPlayerPlay: { #imageLiteral(resourceName: "Icon_InlinePlayerPlay").precomposed(palette.blueIcon) },
                                               audioPlayerPause: { #imageLiteral(resourceName: "Icon_InlinePlayerPause").precomposed(palette.blueIcon) },
                                               audioPlayerNext: { #imageLiteral(resourceName: "Icon_InlinePlayerNext").precomposed(palette.blueIcon) },
                                               audioPlayerPrev: { #imageLiteral(resourceName: "Icon_InlinePlayerPrevious").precomposed(palette.blueIcon) },
                                               auduiPlayerDismiss: { #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.blueIcon) },
                                               audioPlayerRepeat: { #imageLiteral(resourceName: "Icon_RepeatAudio").precomposed(palette.grayIcon) },
                                               audioPlayerRepeatActive: { #imageLiteral(resourceName: "Icon_RepeatAudio").precomposed(palette.blueIcon) },
                                               audioPlayerLockedPlay: { #imageLiteral(resourceName: "Icon_InlinePlayerPlay").precomposed(palette.grayIcon) },
                                               audioPlayerLockedNext: { #imageLiteral(resourceName: "Icon_InlinePlayerNext").precomposed(palette.grayIcon) },
                                               audioPlayerLockedPrev: { #imageLiteral(resourceName: "Icon_InlinePlayerPrevious").precomposed(palette.grayIcon) },
                                               chatSendMessage: { #imageLiteral(resourceName: "Icon_SendMessage").precomposed(palette.blueIcon) },
                                               chatRecordVoice: { #imageLiteral(resourceName: "Icon_RecordVoice").precomposed(palette.grayIcon) },
                                               chatEntertainment: { #imageLiteral(resourceName: "Icon_Entertainments").precomposed(palette.grayIcon) },
                                               chatInlineDismiss: { #imageLiteral(resourceName: "Icon_InlineResultCancel").precomposed(palette.grayIcon) },
                                               chatActiveReplyMarkup: { #imageLiteral(resourceName: "Icon_ReplyMarkupButton").precomposed(palette.blueIcon) },
                                               chatDisabledReplyMarkup: { #imageLiteral(resourceName: "Icon_ReplyMarkupButton").precomposed(palette.grayIcon) },
                                               chatSecretTimer: { #imageLiteral(resourceName: "Icon_SecretTimer").precomposed(palette.grayIcon) },
                                               chatForwardMessagesActive: { #imageLiteral(resourceName: "Icon_MessageActionPanelForward").precomposed(palette.blueIcon) },
                                               chatForwardMessagesInactive: { #imageLiteral(resourceName: "Icon_MessageActionPanelForward").precomposed(palette.grayIcon) },
                                               chatDeleteMessagesActive: { #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(palette.redUI) },
                                               chatDeleteMessagesInactive: { #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(palette.grayIcon) },
                                               generalNext: { #imageLiteral(resourceName: "Icon_GeneralNext").precomposed(palette.grayIcon.withAlphaComponent(0.5)) },
                                               generalNextActive: { #imageLiteral(resourceName: "Icon_GeneralNext").precomposed(.white) },
                                               generalSelect: { #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(palette.blueIcon) },
                                               chatVoiceRecording: { #imageLiteral(resourceName: "Icon_RecordingVoice").precomposed(palette.blueIcon) },
                                               chatVideoRecording: { #imageLiteral(resourceName: "Icon_RecordVideoMessage").precomposed(palette.blueIcon) },
                                               chatRecord: { #imageLiteral(resourceName: "Icon_RecordVoice").precomposed(palette.grayIcon) },
                                               deleteItem: { deleteItemIcon(palette.redUI) },
                                               deleteItemDisabled: { deleteItemIcon(palette.grayText) },
                                               chatAttach: { #imageLiteral(resourceName: "Icon_ChatAttach").precomposed(palette.grayIcon) },
                                               chatAttachFile: { #imageLiteral(resourceName: "Icon_AttachFile").precomposed(palette.blueIcon) },
                                               chatAttachPhoto: { #imageLiteral(resourceName: "Icon_AttachPhoto").precomposed(palette.blueIcon) },
                                               chatAttachCamera: { #imageLiteral(resourceName: "Icon_AttachCamera").precomposed(palette.blueIcon) },
                                               chatAttachLocation: { #imageLiteral(resourceName: "Icon_AttachLocation").precomposed(palette.blueIcon) },
                                               chatAttachPoll: { #imageLiteral(resourceName: "Icon_AttachPoll").precomposed(palette.blueIcon) },
                                               mediaEmptyShared: { #imageLiteral(resourceName: "Icon_EmptySharedMedia").precomposed(palette.grayIcon) },
                                               mediaEmptyFiles: { #imageLiteral(resourceName: "Icon_EmptySharedFiles").precomposed() },
                                               mediaEmptyMusic: { #imageLiteral(resourceName: "Icon_EmptySharedMusic").precomposed(palette.grayIcon) },
                                               mediaEmptyLinks: { #imageLiteral(resourceName: "Icon_EmptySharedLinks").precomposed(palette.grayIcon) },
                                               mediaDropdown: { #imageLiteral(resourceName: "Icon_DropdownArrow").precomposed(palette.blueIcon) },
                                               stickersAddFeatured: { #imageLiteral(resourceName: "Icon_GroupInfoAddMember").precomposed(palette.blueIcon) },
                                               stickersAddedFeatured: { #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(palette.grayIcon) },
                                               stickersRemove: { #imageLiteral(resourceName: "Icon_InlineResultCancel").precomposed(palette.grayIcon) },
                                               peerMediaDownloadFileStart: { #imageLiteral(resourceName: "Icon_MediaDownload").precomposed(palette.blueIcon) },
                                               peerMediaDownloadFilePause: { downloadFilePauseIcon(palette.blueIcon) },
                                               stickersShare: { #imageLiteral(resourceName: "Icon_ShareStickerPack").precomposed(palette.blueIcon) },
                                               emojiRecentTab: { #imageLiteral(resourceName: "Icon_EmojiTabRecent").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiSmileTab: { #imageLiteral(resourceName: "Icon_EmojiTabSmiles").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiNatureTab: { #imageLiteral(resourceName: "Icon_EmojiTabNature").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiFoodTab: { #imageLiteral(resourceName: "Icon_EmojiTabFood").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiSportTab: { #imageLiteral(resourceName: "Icon_EmojiTabSports").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiCarTab: { #imageLiteral(resourceName: "Icon_EmojiTabCar").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiObjectsTab: { #imageLiteral(resourceName: "Icon_EmojiTabObjects").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiSymbolsTab: { #imageLiteral(resourceName: "Icon_EmojiTabSymbols").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiFlagsTab: { #imageLiteral(resourceName: "Icon_EmojiTabFlag").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiRecentTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabRecent").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiSmileTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabSmiles").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiNatureTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabNature").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiFoodTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabFood").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiSportTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabSports").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiCarTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabCar").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiObjectsTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabObjects").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiSymbolsTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabSymbols").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true) },
                                               emojiFlagsTabActive: { #imageLiteral(resourceName: "Icon_EmojiTabFlag").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true) },
                                               stickerBackground: { generateStickerBackground(NSMakeSize(83, 83), palette.background) },
                                               stickerBackgroundActive: { generateStickerBackground(NSMakeSize(83, 83), palette.grayBackground) },
                                               stickersTabRecent: { #imageLiteral(resourceName: "Icon_EmojiTabRecent").precomposed(palette.grayIcon) },
                                               stickersTabGIF: { #imageLiteral(resourceName: "Icon_GifToggle").precomposed(palette.grayIcon) },
                                               chatSendingInFrame_incoming: { generateSendingFrame(palette.grayIconBubble_incoming) },
                                               chatSendingInHour_incoming: { generateSendingHour(palette.grayIconBubble_incoming) },
                                               chatSendingInMin_incoming: { generateSendingMin(palette.grayIconBubble_incoming) },
                                               chatSendingInFrame_outgoing: { generateSendingFrame(palette.grayIconBubble_outgoing) },
                                               chatSendingInHour_outgoing: { generateSendingHour(palette.grayIconBubble_outgoing) },
                                               chatSendingInMin_outgoing: { generateSendingMin(palette.grayIconBubble_outgoing) },
                                               chatSendingOutFrame: { generateSendingFrame(palette.grayIcon) },
                                               chatSendingOutHour: { generateSendingHour(palette.grayIcon) },
                                               chatSendingOutMin: { generateSendingMin(palette.grayIcon) },
                                               chatSendingOverlayFrame: { generateSendingFrame(.white) },
                                               chatSendingOverlayHour: { generateSendingHour(.white) },
                                               chatSendingOverlayMin: { generateSendingMin(.white) },
                                               chatActionUrl: { #imageLiteral(resourceName: "Icon_InlineBotUrl").precomposed(palette.text) },
                                               callInlineDecline: { #imageLiteral(resourceName: "Icon_CallDecline_Inline").precomposed(.white) },
                                               callInlineMuted: { #imageLiteral(resourceName: "Icon_CallMute_Inline").precomposed(.white) },
                                               callInlineUnmuted: { #imageLiteral(resourceName: "Icon_CallUnmuted_Inline").precomposed(.white) },
                                               eventLogTriangle: { generateRecentActionsTriangle(palette.text) },
                                               channelIntro: { #imageLiteral(resourceName: "Icon_ChannelIntro").precomposed() },
                                               chatFileThumb: { #imageLiteral(resourceName: "Icon_MessageFile").precomposed(flipVertical:true) },
                                               chatFileThumbBubble_incoming: { #imageLiteral(resourceName: "Icon_MessageFile").precomposed(palette.fileActivityForegroundBubble_incoming,  flipVertical:true) },
                                               chatFileThumbBubble_outgoing: { #imageLiteral(resourceName: "Icon_MessageFile").precomposed(palette.fileActivityForegroundBubble_outgoing, flipVertical:true) },
                                               chatSecretThumb: { #imageLiteral(resourceName: "Icon_SecretAutoremoveMedia").precomposed(.black, flipVertical:true) },
                                               chatMapPin: { #imageLiteral(resourceName: "Icon_MapPinned").precomposed() },
                                               chatSecretTitle: { #imageLiteral(resourceName: "Icon_SecretChatLock").precomposed(palette.text, flipVertical:true) },
                                               emptySearch: { #imageLiteral(resourceName: "Icon_EmptySearchResults").precomposed(palette.grayIcon) },
                                               calendarBack: { #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(palette.blueIcon) },
                                               calendarNext: { #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(palette.blueIcon, flipHorizontal: true) },
                                               calendarBackDisabled: { #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(palette.grayIcon) },
                                               calendarNextDisabled: { #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(palette.grayIcon, flipHorizontal: true) },
                                               newChatCamera: { #imageLiteral(resourceName: "Icon_AttachCamera").precomposed(palette.grayIcon) },
                                               peerInfoVerify: { #imageLiteral(resourceName: "Icon_VerifyPeer").precomposed(flipVertical: true) },
                                               peerInfoVerifyProfile: { #imageLiteral(resourceName: "Icon_VerifyPeer").precomposed() },
                                               peerInfoCall: { #imageLiteral(resourceName: "Icon_ProfileCall").precomposed(palette.accent) },
                                               callOutgoing: { #imageLiteral(resourceName: "Icon_CallOutgoing").precomposed(palette.grayIcon, flipVertical: true) },
                                               recentDismiss: { #imageLiteral(resourceName: "Icon_SearchClear").precomposed(palette.grayIcon) },
                                               recentDismissActive: { #imageLiteral(resourceName: "Icon_SearchClear").precomposed(.white) },
                                               webgameShare: { #imageLiteral(resourceName: "Icon_ShareExternal").precomposed(palette.blueIcon) },
                                               chatSearchCancel: { #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.blueIcon) },
                                               chatSearchFrom: { #imageLiteral(resourceName: "Icon_ChatSearchFrom").precomposed(palette.blueIcon) },
                                               callWindowDecline: { #imageLiteral(resourceName: "Icon_CallDecline_Window").precomposed() },
                                               callWindowAccept: { #imageLiteral(resourceName: "Icon_CallAccept_Window").precomposed() },
                                               callWindowMute: { #imageLiteral(resourceName: "Icon_CallMic_Window").precomposed() },
                                               callWindowUnmute: { #imageLiteral(resourceName: "Icon_CallMute_Inline").precomposed() },
                                               callWindowClose: { #imageLiteral(resourceName: "Icon_CallWindowClose").precomposed(.white) },
                                               callWindowDeviceSettings: { #imageLiteral(resourceName: "Icon_CallDeviceSettings").precomposed(.white) },
                                               callSettings: { #imageLiteral(resourceName: "Icon_CallDeviceSettings").precomposed(palette.blueIcon) },
                                               callWindowCancel: { #imageLiteral(resourceName: "Icon_CallCancelIcon").precomposed(.white) },
                                               chatActionEdit: { #imageLiteral(resourceName: "Icon_ChatActionEdit").precomposed(palette.blueIcon) },
                                               chatActionInfo: { #imageLiteral(resourceName: "Icon_ChatActionInfo").precomposed(palette.blueIcon) },
                                               chatActionMute: { #imageLiteral(resourceName: "Icon_ChatActionMute").precomposed(palette.blueIcon) },
                                               chatActionUnmute: { #imageLiteral(resourceName: "Icon_ChatActionUnmute").precomposed(palette.blueIcon) },
                                               chatActionClearHistory: { #imageLiteral(resourceName: "Icon_ClearChat").precomposed(palette.blueIcon) },
                                               chatActionDeleteChat: { #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(palette.blueIcon) },
                                               dismissPinned: { #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.blueIcon) },
                                               chatActionsActive: { #imageLiteral(resourceName: "Icon_ChatActionsActive").precomposed(palette.blueIcon) },
                                               chatEntertainmentSticker: { #imageLiteral(resourceName: "Icon_ChatEntertainmentSticker").precomposed(palette.grayIcon) },
                                               chatEmpty: { #imageLiteral(resourceName: "Icon_EmptyChat").precomposed(palette.grayForeground) },
                                               stickerPackClose: { #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.blueIcon) },
                                               stickerPackDelete: { #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(palette.blueIcon) },
                                               modalShare: { #imageLiteral(resourceName: "Icon_ShareStickerPack").precomposed(palette.blueIcon) },
                                               modalClose: { #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.blueIcon) },
                                               ivChannelJoined: { #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(.white) },
                                               chatListMention: { generateBadgeMention(backgroundColor: palette.accent, foregroundColor: palette.background) },
                                               chatListMentionActive: { generateBadgeMention(backgroundColor: .white, foregroundColor: palette.blueSelect) },
                                               chatListMentionArchived: { generateBadgeMention(backgroundColor: palette.badgeMuted, foregroundColor: palette.background) },
                                               chatListMentionArchivedActive: { generateBadgeMention(backgroundColor: palette.underSelectedColor, foregroundColor: palette.blueSelect) },
                                               chatMention: { generateChatMention(backgroundColor: palette.background, border: palette.grayIcon, foregroundColor: palette.grayIcon) },
                                               chatMentionActive: { generateChatMention(backgroundColor: palette.background, border: palette.blueIcon, foregroundColor: palette.blueIcon) },
                                               sliderControl: { #imageLiteral(resourceName: "Icon_SliderNormal").precomposed() },
                                               sliderControlActive: { #imageLiteral(resourceName: "Icon_SliderNormal").precomposed() },
                                               stickersTabFave: { #imageLiteral(resourceName: "Icon_FaveStickers").precomposed(palette.grayIcon) },
                                               chatInstantView: { #imageLiteral(resourceName: "Icon_ChatIV").precomposed(palette.webPreviewActivity) },
                                               chatInstantViewBubble_incoming: { #imageLiteral(resourceName: "Icon_ChatIV").precomposed(palette.webPreviewActivityBubble_incoming) },
                                               chatInstantViewBubble_outgoing: { #imageLiteral(resourceName: "Icon_ChatIV").precomposed(palette.webPreviewActivityBubble_outgoing) },
                                               instantViewShare: { #imageLiteral(resourceName: "Icon_ShareStickerPack").precomposed(palette.blueIcon) },
                                               instantViewActions: { #imageLiteral(resourceName: "Icon_ChatActions").precomposed(palette.blueIcon) },
                                               instantViewActionsActive: { #imageLiteral(resourceName: "Icon_ChatActionsActive").precomposed(palette.blueIcon) },
                                               instantViewSafari: { #imageLiteral(resourceName: "Icon_InstantViewSafari").precomposed(palette.blueIcon) },
                                               instantViewBack: { #imageLiteral(resourceName: "Icon_InstantViewBack").precomposed(palette.blueIcon) },
                                               instantViewCheck: { #imageLiteral(resourceName: "Icon_InstantViewCheck").precomposed(palette.blueIcon) },
                                               groupStickerNotFound: { #imageLiteral(resourceName: "Icon_GroupStickerNotFound").precomposed(palette.grayIcon) },
                                               settingsAskQuestion: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsAskQuestion").precomposed(flipVertical: true)) },
                                               settingsFaq: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsFaq").precomposed(flipVertical: true)) },
                                               settingsGeneral: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsGeneral").precomposed(flipVertical: true)) },
                                               settingsLanguage: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsLanguage").precomposed(flipVertical: true)) },
                                               settingsNotifications: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsNotifications").precomposed(flipVertical: true)) },
                                               settingsSecurity: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsSecurity").precomposed(flipVertical: true)) },
                                               settingsStickers: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsStickers").precomposed(flipVertical: true)) },
                                               settingsStorage: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsStorage").precomposed(flipVertical: true)) },
                                               settingsProxy: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsProxy").precomposed(flipVertical: true)) },
                                               settingsAppearance: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_AppearanceSettings").precomposed(flipVertical: true)) },
                                               settingsPassport: { generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsSecurity").precomposed(flipVertical: true)) },
                                               settingsUpdate: { generateSettingsIcon(NSImage(named: "Icon_SettingsUpdate")!.precomposed(flipVertical: true)) },
                                               settingsAskQuestionActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsAskQuestion").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.blueSelect) },
                                               settingsFaqActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsFaq").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.blueSelect) },
                                               settingsGeneralActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsGeneral").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.blueSelect) },
                                               settingsLanguageActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsLanguage").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.blueSelect) },
                                               settingsNotificationsActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsNotifications").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.blueSelect) },
                                               settingsSecurityActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsSecurity").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.blueSelect) },
                                               settingsStickersActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsStickers").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.blueSelect) },
                                               settingsStorageActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsStorage").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.blueSelect) },
                                               settingsProxyActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsProxy").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.blueSelect) },
                                               settingsAppearanceActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_AppearanceSettings").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.blueSelect) },
                                               settingsPassportActive: { generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsSecurity").precomposed(palette.underSelectedColor, flipVertical: true), background: palette.blueSelect) },
                                               settingsUpdateActive: { generateSettingsActiveIcon(NSImage(named: "Icon_SettingsUpdate")!.precomposed(palette.underSelectedColor, flipVertical: true), background: palette.blueSelect) },
                                               generalCheck: { #imageLiteral(resourceName: "Icon_Check").precomposed(palette.blueIcon) },
                                               settingsAbout: { #imageLiteral(resourceName: "Icon_SettingsAbout").precomposed(palette.blueIcon) },
                                               settingsLogout: { #imageLiteral(resourceName: "Icon_SettingsLogout").precomposed(palette.redUI) },
                                               fastSettingsLock: { #imageLiteral(resourceName: "Icon_FastSettingsLock").precomposed(palette.blueIcon) },
                                               fastSettingsDark: { #imageLiteral(resourceName: "Icon_FastSettingsDark").precomposed(palette.blueIcon) },
                                               fastSettingsSunny: { #imageLiteral(resourceName: "Icon_FastSettingsSunny").precomposed(palette.blueIcon) },
                                               fastSettingsMute: { #imageLiteral(resourceName: "Icon_ChatActionMute").precomposed(palette.blueIcon) },
                                               fastSettingsUnmute: { #imageLiteral(resourceName: "Icon_ChatActionUnmute").precomposed(palette.blueIcon) },
                                               chatRecordVideo: { #imageLiteral(resourceName: "Icon_RecordVideoMessage").precomposed(palette.grayIcon) },
                                               inputChannelMute: { #imageLiteral(resourceName: "Icon_InputChannelMute").precomposed(palette.grayIcon) },
                                               inputChannelUnmute: { #imageLiteral(resourceName: "Icon_InputChannelUnmute").precomposed(palette.grayIcon) },
                                               changePhoneNumberIntro: { #imageLiteral(resourceName: "Icon_ChangeNumberIntro").precomposed() },
                                               peerSavedMessages: { #imageLiteral(resourceName: "Icon_SavedMessages").precomposed() },
                                               previewCollage: { #imageLiteral(resourceName: "Icon_PreviewCollage").precomposed(palette.grayIcon) },
                                               chatGoMessage: { #imageLiteral(resourceName: "Icon_ChatGoMessage").precomposed(palette.blueIcon) },
                                               chatGroupToggleSelected: { generateChatGroupToggleSelected(foregroundColor: palette.blueIcon, backgroundColor: palette.underSelectedColor) },
                                               chatGroupToggleUnselected: { #imageLiteral(resourceName: "Icon_SelectionUncheck").precomposed() },
                                               successModalProgress: { #imageLiteral(resourceName: "Icon_ProgressWindowCheck").precomposed(palette.grayIcon) },
                                               accentColorSelect: { #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(.white) },
                                               chatShareWallpaper: { #imageLiteral(resourceName: "Icon_ShareInBubble").precomposed(palette.blueIcon) },
                                               chatGotoMessageWallpaper: { #imageLiteral(resourceName: "Icon_GotoBubbleMessage").precomposed(palette.blueIcon) },
                                               transparentBackground: { generateTransparentBackground() },
                                               lottieTransparentBackground: { generateLottieTransparentBackground() },
                                               passcodeTouchId: { #imageLiteral(resourceName: "Icon_TouchId").precomposed() },
                                               passcodeLogin: { #imageLiteral(resourceName: "Icon_PasscodeLogin").precomposed() },
                                               confirmDeleteMessagesAccessory: { generateConfirmDeleteMessagesAccessory(backgroundColor: palette.redUI) },
                                               alertCheckBoxSelected: { generateAlertCheckBoxSelected(backgroundColor: palette.blueIcon) },
                                               alertCheckBoxUnselected: { generateAlertCheckBoxUnselected(border: palette.grayIcon) },
                                               confirmPinAccessory: { generateConfirmPinAccessory(backgroundColor: palette.blueIcon) },
                                               confirmDeleteChatAccessory: { generateConfirmDeleteChatAccessory(backgroundColor: palette.background, foregroundColor: palette.redUI) },
                                               stickersEmptySearch: { generateStickersEmptySearch(color: palette.grayIcon) },
                                               twoStepVerificationCreateIntro: { #imageLiteral(resourceName: "Icon_TwoStepVerification_Create").precomposed() },
                                               secureIdAuth: { #imageLiteral(resourceName: "Icon_SecureIdAuth").precomposed() },
                                               ivAudioPlay: { generateIVAudioPlay(color: palette.text) },
                                               ivAudioPause: { generateIVAudioPause(color: palette.text) },
                                               proxyEnable: { #imageLiteral(resourceName: "Icon_ProxyEnable").precomposed(palette.accent) },
                                               proxyEnabled: { #imageLiteral(resourceName: "Icon_ProxyEnabled").precomposed(palette.accent) },
                                               proxyState: { #imageLiteral(resourceName: "Icon_ProxyState").precomposed(palette.accent) },
                                               proxyDeleteListItem: { #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(palette.blueIcon) },
                                               proxyInfoListItem: { #imageLiteral(resourceName: "Icon_SettingsBio").precomposed(palette.blueIcon) },
                                               proxyConnectedListItem: { #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(palette.blueIcon) },
                                               proxyAddProxy: { #imageLiteral(resourceName: "Icon_GroupInfoAddMember").precomposed(palette.blueIcon, flipVertical: true) },
                                               proxyNextWaitingListItem: { #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(palette.grayIcon) },
                                               passportForgotPassword: { #imageLiteral(resourceName: "Icon_SecureIdForgotPassword").precomposed(palette.grayIcon) },
                                               confirmAppAccessoryIcon: { #imageLiteral(resourceName: "Icon_ConfirmAppAccessory").precomposed() },
                                               passportPassport: { #imageLiteral(resourceName: "Icon_PassportPassport").precomposed(palette.blueIcon, flipVertical: true) },
                                               passportIdCardReverse: { #imageLiteral(resourceName: "Icon_PassportIdCardReverse").precomposed(palette.blueIcon, flipVertical: true) },
                                               passportIdCard: { #imageLiteral(resourceName: "Icon_PassportIdCard").precomposed(palette.blueIcon, flipVertical: true) },
                                               passportSelfie: { #imageLiteral(resourceName: "Icon_PassportSelfie").precomposed(palette.blueIcon, flipVertical: true) },
                                               passportDriverLicense: { #imageLiteral(resourceName: "Icon_PassportDriverLicense").precomposed(palette.blueIcon, flipVertical: true) },
                                               chatOverlayVoiceRecording: { #imageLiteral(resourceName: "Icon_RecordingVoice").precomposed(.white) },
                                               chatOverlayVideoRecording: { #imageLiteral(resourceName: "Icon_RecordVideoMessage").precomposed(.white) },
                                               chatOverlaySendRecording: { #imageLiteral(resourceName: "Icon_ChatOverlayRecordingSend").precomposed(.white) },
                                               chatOverlayLockArrowRecording: { #imageLiteral(resourceName: "Icon_DropdownArrow").precomposed(palette.blueIcon, flipVertical: true) },
                                               chatOverlayLockerBodyRecording: { generateLockerBody(palette.blueIcon, backgroundColor: palette.background) },
                                               chatOverlayLockerHeadRecording: { generateLockerHead(palette.blueIcon, backgroundColor: palette.background) },
                                               locationPin: { generateLocationPinIcon(palette.blueIcon) },
                                               locationMapPin: { generateLocationMapPinIcon(palette.blueIcon) },
                                               locationMapLocate: { #imageLiteral(resourceName: "Icon_MapLocate").precomposed(palette.grayIcon) },
                                               locationMapLocated: { #imageLiteral(resourceName: "Icon_MapLocate").precomposed(palette.blueIcon) },
                                               chatTabIconSelected: { #imageLiteral(resourceName: "Icon_TabChatList_Highlighted").precomposed(palette.blueIcon) },
                                               chatTabIconSelectedUp: { generateChatTabSelected(palette.blueIcon, #imageLiteral(resourceName: "Icon_ChatListScrollUnread").precomposed(palette.background, flipVertical: true)) },
                                               chatTabIconSelectedDown: { generateChatTabSelected(palette.blueIcon, #imageLiteral(resourceName: "Icon_ChatListScrollUnread").precomposed(palette.background)) },
                                               chatTabIcon: { #imageLiteral(resourceName: "Icon_TabChatList").precomposed(palette.grayIcon) },
                                               passportSettings: { #imageLiteral(resourceName: "Icon_PassportSettings").precomposed(palette.grayIcon) },
                                               passportInfo: { #imageLiteral(resourceName: "Icon_SettingsBio").precomposed(palette.blueIcon) },
                                               editMessageMedia: { generateEditMessageMediaIcon(#imageLiteral(resourceName: "Icon_ReplaceMessageMedia").precomposed(palette.blueIcon), background: palette.background) },
                                               playerMusicPlaceholder: { generatePlayerListAlbumPlaceholder(#imageLiteral(resourceName: "Icon_MusicPlayerSmallAlbumArtPlaceholder").precomposed(palette.accent), background: palette.grayForeground, radius: .cornerRadius) },
                                               chatMusicPlaceholder: { generatePlayerListAlbumPlaceholder(#imageLiteral(resourceName: "Icon_MusicPlayerSmallAlbumArtPlaceholder").precomposed(palette.fileActivityForeground), background: palette.fileActivityBackground, radius: 20) },
                                               chatMusicPlaceholderCap: { generatePlayerListAlbumPlaceholder(nil, background: palette.fileActivityBackground, radius: 20) },
                                               searchArticle: { #imageLiteral(resourceName: "Icon_SearchArticles").precomposed(.white) },
                                               searchSaved: { #imageLiteral(resourceName: "Icon_SearchSaved").precomposed(.white) },
                                               archivedChats: { #imageLiteral(resourceName: "Icon_ArchiveAvatar").precomposed(.white) },
                                               hintPeerActive: { generateHitActiveIcon(activeColor: palette.accent, backgroundColor: palette.background) },
                                               hintPeerActiveSelected: { generateHitActiveIcon(activeColor: palette.underSelectedColor, backgroundColor: palette.blueSelect) },
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
                                               playingVoice2x: { #imageLiteral(resourceName: "Icon_PlayingVoice2x").precomposed(palette.blueIcon) },
                                               galleryRotate: {NSImage(named: "Icon_GalleryRotate")!.precomposed(.white) },
                                               galleryZoomIn: {NSImage(named: "Icon_GalleryZoomIn")!.precomposed(.white) },
                                               galleryZoomOut: { NSImage(named: "Icon_GalleryZoomOut")!.precomposed(.white) },
                                               previewSenderCrop: { NSImage(named: "Icon_PreviewSenderCrop")!.precomposed(.white) },
                                               previewSenderDelete: { NSImage(named: "Icon_PreviewSenderDelete")!.precomposed(.white) },
                                               editMessageCurrentPhoto: { NSImage(named: "Icon_EditMessageCurrentPhoto")!.precomposed(palette.blueIcon) },
                                               previewSenderDeleteFile: { NSImage(named: "Icon_PreviewSenderDelete")!.precomposed(palette.blueIcon) },
                                               previewSenderArchive: { NSImage(named: "Icon_PreviewSenderArchive")!.precomposed(palette.grayIcon) },
                                               chatSwipeReply: { #imageLiteral(resourceName: "Icon_MessageActionPanelForward").precomposed(palette.blueIcon, flipHorizontal: true) },
                                               chatSwipeReplyWallpaper: { #imageLiteral(resourceName: "Icon_ShareInBubble").precomposed(palette.blueIcon, flipHorizontal: true) },
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
                                               customLocalizationDelete: { NSImage(named: "Icon_MessageActionPanelDelete")!.precomposed(palette.blueIcon) },
                                               pollAddOption: { generatePollAddOption(palette.blueIcon) },
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
                                               chatUnarchive: { NSImage(named: "Icon_ChatUnarchive")!.precomposed(palette.blueIcon) },
                                               chatArchive: { NSImage(named: "Icon_ChatArchive")!.precomposed(palette.blueIcon) },
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
                                               scheduledInputAction: { NSImage(named: "Icon_ChatActionScheduled")!.precomposed(palette.blueIcon) },
                                               verifyDialog: { generateDialogVerify(background: .white, foreground: palette.basicAccent) },
                                               verifyDialogActive: { generateDialogVerify(background: palette.blueIcon, foreground: palette.underSelectedColor) },
                                               chatInputScheduled: { NSImage(named: "Icon_ChatInputScheduled")!.precomposed(palette.grayIcon) }
    )

}
private func generateTheme(palette: ColorPalette, cloudTheme: TelegramTheme?, bubbled: Bool, fontSize: CGFloat, followSystemAppearance: Bool, wallpaper: ThemeWallpaper) -> TelegramPresentationTheme {
    
    let chatList = TelegramChatListTheme(selectedBackgroundColor: palette.blueSelect,
                                         singleLayoutSelectedBackgroundColor: palette.grayBackground,
                                         activeDraggingBackgroundColor: palette.border,
                                         pinnedBackgroundColor: palette.background,
                                         contextMenuBackgroundColor: palette.background,
                                         textColor: palette.text,
                                         grayTextColor: palette.grayText,
                                         secretChatTextColor: bubbled && palette.name == dayClassicPalette.name ? palette.blueIconBubble_outgoing : palette.accent,
                                         peerTextColor: palette.text,
                                         activityColor: palette.accent,
                                         activitySelectedColor: palette.underSelectedColor,
                                         activityContextMenuColor: palette.accent,
                                         activityPinnedColor: palette.accent,
                                         badgeTextColor: palette.background,
                                         badgeBackgroundColor: palette.badge,
                                         badgeSelectedTextColor: palette.blueSelect,
                                         badgeSelectedBackgroundColor: palette.underSelectedColor,
                                         badgeMutedTextColor: .white,
                                         badgeMutedBackgroundColor: palette.badgeMuted)
    
    let tabBar = TelegramTabBarTheme(color: palette.grayIcon, selectedColor: palette.blueIcon, badgeTextColor: .white, badgeColor: palette.redUI)
    return TelegramPresentationTheme(colors: palette, cloudTheme: cloudTheme, search: SearchTheme(palette.grayBackground, #imageLiteral(resourceName: "Icon_SearchField").precomposed(palette.grayIcon), #imageLiteral(resourceName: "Icon_SearchClear").precomposed(palette.grayIcon), { L10n.searchFieldSearch }, palette.text, palette.grayText), chatList: chatList, tabBar: tabBar, icons: generateIcons(from: palette, bubbled: bubbled), bubbled: bubbled, fontSize: fontSize, wallpaper: wallpaper, followSystemAppearance: followSystemAppearance)
}


func updateTheme(with settings: ThemePaletteSettings, for window: Window? = nil, animated: Bool = false) {
    let palette: ColorPalette
    switch settings.palette.name {
    case whitePalette.name:
        if settings.palette.blueFill.hexString == whitePalette.blueFill.hexString {
            palette = whitePalette
        } else {
            palette = settings.palette
        }
    case darkPalette.name:
        if settings.palette.blueFill.hexString == darkPalette.blueFill.hexString {
            palette = darkPalette
        } else {
            palette = settings.palette
        }
    case dayClassicPalette.name:
        if settings.palette.blueFill.hexString == dayClassicPalette.blueFill.hexString {
            palette = dayClassicPalette
        } else {
            palette = settings.palette
        }
    case nightBluePalette.name:
        if settings.palette.blueFill.hexString == nightBluePalette.blueFill.hexString {
            palette = nightBluePalette
        } else {
            palette = settings.palette
        }
    case mojavePalette.name:
        if settings.palette.blueFill.hexString == mojavePalette.blueFill.hexString {
            palette = mojavePalette
        } else {
            palette = settings.palette
        }
    default:
        palette = settings.palette
    }
    telegramUpdateTheme(generateTheme(palette: palette, cloudTheme: settings.cloudTheme, bubbled: settings.bubbled, fontSize: settings.fontSize, followSystemAppearance: settings.followSystemAppearance, wallpaper: settings.wallpaper), window: window, animated: animated)
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
            imageView.frame = contentView.superview!.bounds
            contentView.addSubview(imageView)

            
            let signal = Signal<Void, NoError>.single(Void()) |> delay(0.15, queue: Queue.mainQueue()) |> afterDisposed { [weak imageView] in
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
        window.backgroundColor = theme.colors.grayBackground
        window.titlebarAppearsTransparent = true//theme.dark
    }
    _themeSignal.set(theme)
}

func setDefaultTheme(for window: Window? = nil) {
    telegramUpdateTheme(generateTheme(palette: dayClassicPalette, cloudTheme: nil, bubbled: false, fontSize: 13.0, followSystemAppearance: true, wallpaper: ThemeWallpaper()), window: window, animated: false)
}


