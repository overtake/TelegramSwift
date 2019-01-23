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

private func generatePollDeleteOption(_ color: NSColor) -> CGImage {
    let image = NSImage(named: "Icon_PollDeleteOption")!.precomposed(color)
    return generateImage(image.backingSize, contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        
        ctx.setFillColor(.white)
        ctx.fillEllipse(in: NSMakeRect(0, 0, size.width, size.height))
        
        ctx.draw(image, in: CGRect(origin: CGPoint(), size: size))
    })!
}

private func generateHitActiveIcon(activeColor: NSColor, backgroundColor: NSColor) -> CGImage {
    return generateImage(NSMakeSize(10, 10), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.round(size, size.width / 2)
        
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fillEllipse(in: NSMakeRect(0, 0, size.width, size.height))
        
        ctx.setFillColor(activeColor.cgColor)
        ctx.fillEllipse(in: NSMakeRect(2, 2, 6, 6))
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
        
        let imageRect = NSMakeRect(floorToScreenPixels(scaleFactor: System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(scaleFactor: System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height)
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
            let imageRect = NSMakeRect(floorToScreenPixels(scaleFactor: System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(scaleFactor: System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height)
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
        let imageRect = NSMakeRect(floorToScreenPixels(scaleFactor: System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(scaleFactor: System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height)
        ctx.draw(icon, in: imageRect)

    })!
}

private func generateChatTabSelected(_ color: NSColor, _ icon: CGImage) -> CGImage {
    let main = #imageLiteral(resourceName: "Icon_TabChatList_Highlighted").precomposed(color)
    return generateImage(main.backingSize, contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.draw(main, in: NSMakeRect(0, 0, size.width, size.height))
        
        
        let imageRect = NSMakeRect(floorToScreenPixels(scaleFactor: System.backingScale, (size.width - icon.backingSize.width) / 2) - 2, floorToScreenPixels(scaleFactor: System.backingScale, (size.height - icon.backingSize.height) / 2) + 2, icon.backingSize.width, icon.backingSize.height)
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
        let imageRect = NSMakeRect(floorToScreenPixels(scaleFactor: System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(scaleFactor: System.backingScale, (size.height - icon.backingSize.height) / 2) + 3, icon.backingSize.width, icon.backingSize.height)
        ctx.draw(icon, in: imageRect)
        
        let triangle = generateTriangle(NSMakeSize(12, 10), color: background)
        let triangleRect = NSMakeRect(floorToScreenPixels(scaleFactor: System.backingScale, (size.width - triangle.backingSize.width) / 2), 0, triangle.backingSize.width, triangle.backingSize.height)
        
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
        ctx.fillEllipse(in: NSMakeRect(floorToScreenPixels(scaleFactor: System.backingScale, (size.width - 2)/2), floorToScreenPixels(scaleFactor: System.backingScale, (size.height - 2)/2), 2, 2))
       
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
        let imageRect = NSMakeRect(floorToScreenPixels(scaleFactor: System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(scaleFactor: System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height)
        
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
        let imageRect = NSMakeRect(floorToScreenPixels(scaleFactor: System.backingScale, (size.width - imageSize.width) / 2), floorToScreenPixels(scaleFactor: System.backingScale, (size.height - imageSize.height) / 2), imageSize.width, imageSize.height)
        
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

private func generateIVAudioPlay(color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(40, 40), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(3)
        ctx.strokeEllipse(in: NSMakeRect(2, 2, size.width - 4, size.height - 4))
        let icon = #imageLiteral(resourceName: "Icon_ChatMusicPlay").precomposed(color)
        
        ctx.draw(icon, in: NSMakeRect(floorToScreenPixels(scaleFactor: System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(scaleFactor: System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height))
        
    })!
}

private func generateIVAudioPause(color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(40, 40), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(3)
        ctx.strokeEllipse(in: NSMakeRect(2, 2, size.width - 4, size.height - 4))
        let icon = #imageLiteral(resourceName: "Icon_ChatMusicPause").precomposed(color)
        ctx.draw(icon, in: NSMakeRect(floorToScreenPixels(scaleFactor: System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(scaleFactor: System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height))
    })!
}

private func generateBadgeMention(backgroundColor: NSColor, foregroundColor: NSColor) -> CGImage {
    return generateImage(NSMakeSize(20, 20), contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.round(size, size.width/2)
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
        let icon = #imageLiteral(resourceName: "Icon_ChatListMention").precomposed(foregroundColor, flipVertical: true)
        let imageRect = NSMakeRect(floorToScreenPixels(scaleFactor: System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(scaleFactor: System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height)
        ctx.draw(icon, in: imageRect)
    })!
}

private func generateChatGroupToggleSelected(foregroundColor: NSColor) -> CGImage {
    let icon = #imageLiteral(resourceName: "Icon_Check").precomposed(foregroundColor)
    return generateImage(NSMakeSize(icon.backingSize.width + 2, icon.backingSize.height + 2), contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.round(size, size.width/2)
        ctx.setFillColor(NSColor.white.cgColor)
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
    return ControlStyle(font: NSFont.normal(.title), foregroundColor: theme.colors.blueUI)
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




struct TelegramIconsTheme {
    let dialogMuteImage: CGImage
    let dialogMuteImageSelected: CGImage
    let outgoingMessageImage: CGImage
    let readMessageImage: CGImage
    let outgoingMessageImageSelected: CGImage
    let readMessageImageSelected: CGImage
    let sendingImage: CGImage
    let sendingImageSelected: CGImage
    let secretImage:CGImage
    let secretImageSelected: CGImage
    let pinnedImage: CGImage
    let pinnedImageSelected: CGImage
    let verifiedImage: CGImage
    let verifiedImageSelected: CGImage
    let errorImage: CGImage
    let errorImageSelected: CGImage
    
    let chatSearch: CGImage
    let chatCall: CGImage
    let chatActions: CGImage
    
    let chatFailedCall_incoming: CGImage
    let chatFailedCall_outgoing: CGImage
    let chatCall_incoming: CGImage
    let chatCall_outgoing: CGImage
    
    let chatFailedCallBubble_incoming: CGImage
    let chatFailedCallBubble_outgoing: CGImage
    let chatCallBubble_incoming: CGImage
    let chatCallBubble_outgoing: CGImage
    
    let chatFallbackCall: CGImage
    
    let chatFallbackCallBubble_incoming: CGImage
    let chatFallbackCallBubble_outgoing: CGImage
    
    let chatToggleSelected: CGImage
    let chatToggleUnselected: CGImage
    let chatShare: CGImage
    
    
    let chatMusicPlay: CGImage
    let chatMusicPlayBubble_incoming: CGImage
    let chatMusicPlayBubble_outgoing: CGImage
    
    let chatMusicPause: CGImage
    let chatMusicPauseBubble_incoming: CGImage
    let chatMusicPauseBubble_outgoing: CGImage
    
    let composeNewChat:CGImage
    let composeNewChatActive: CGImage
    let composeNewGroup:CGImage
    let composeNewSecretChat: CGImage
    let composeNewChannel: CGImage
    
    let contactsNewContact: CGImage
    
    let chatReadMarkInBubble1_incoming: CGImage
    let chatReadMarkInBubble2_incoming: CGImage
    let chatReadMarkInBubble1_outgoing: CGImage
    let chatReadMarkInBubble2_outgoing: CGImage
    
    let chatReadMarkOutBubble1: CGImage
    let chatReadMarkOutBubble2: CGImage
    let chatReadMarkOverlayBubble1: CGImage
    let chatReadMarkOverlayBubble2: CGImage
    
    let sentFailed: CGImage
    
    let chatChannelViewsInBubble_incoming:CGImage
    let chatChannelViewsInBubble_outgoing:CGImage
    let chatChannelViewsOutBubble: CGImage
    let chatChannelViewsOverlayBubble: CGImage
    
    let chatNavigationBack: CGImage
    
    let peerInfoAddMember: CGImage
    

    let chatSearchUp: CGImage
    let chatSearchUpDisabled: CGImage
    let chatSearchDown: CGImage
    let chatSearchDownDisabled: CGImage
    let chatSearchCalendar: CGImage
    
    let dismissAccessory: CGImage
    
    let chatScrollUp: CGImage
    let chatScrollUpActive: CGImage
    

    let audioPlayerPlay: CGImage
    let audioPlayerPause: CGImage
    let audioPlayerNext: CGImage
    let audioPlayerPrev: CGImage
    let auduiPlayerDismiss: CGImage
    let audioPlayerRepeat: CGImage
    let audioPlayerRepeatActive: CGImage
    
    let audioPlayerLockedPlay: CGImage
    let audioPlayerLockedNext: CGImage
    let audioPlayerLockedPrev: CGImage
    

    
    let chatSendMessage: CGImage
    let chatRecordVoice: CGImage
    let chatEntertainment: CGImage
    let chatInlineDismiss: CGImage
    let chatActiveReplyMarkup: CGImage
    let chatDisabledReplyMarkup: CGImage
    let chatSecretTimer: CGImage

    let chatForwardMessagesActive: CGImage
    let chatForwardMessagesInactive: CGImage
    let chatDeleteMessagesActive: CGImage
    let chatDeleteMessagesInactive: CGImage
    
    let generalNext: CGImage
    let generalNextActive: CGImage
    let generalSelect: CGImage


    let chatVoiceRecording: CGImage
    let chatVideoRecording: CGImage
    let chatRecord: CGImage
    
    let deleteItem: CGImage
    let deleteItemDisabled: CGImage
    
    let chatAttach: CGImage
    let chatAttachFile: CGImage
    let chatAttachPhoto: CGImage
    let chatAttachCamera: CGImage
    let chatAttachLocation: CGImage
    let chatAttachPoll: CGImage
    
    let mediaEmptyShared: CGImage
    let mediaEmptyFiles: CGImage
    let mediaEmptyMusic: CGImage
    let mediaEmptyLinks: CGImage
    
    let mediaDropdown: CGImage
    
    let stickersAddFeatured: CGImage
    let stickersAddedFeatured: CGImage
    let stickersRemove: CGImage
    
    let peerMediaDownloadFileStart: CGImage
    let peerMediaDownloadFilePause: CGImage
    
    let stickersShare: CGImage
    
    let emojiRecentTab: CGImage
    let emojiSmileTab: CGImage
    let emojiNatureTab: CGImage
    let emojiFoodTab: CGImage
    let emojiSportTab: CGImage
    let emojiCarTab: CGImage
    let emojiObjectsTab: CGImage
    let emojiSymbolsTab: CGImage
    let emojiFlagsTab: CGImage
    
    let emojiRecentTabActive: CGImage
    let emojiSmileTabActive: CGImage
    let emojiNatureTabActive: CGImage
    let emojiFoodTabActive: CGImage
    let emojiSportTabActive: CGImage
    let emojiCarTabActive: CGImage
    let emojiObjectsTabActive: CGImage
    let emojiSymbolsTabActive: CGImage
    let emojiFlagsTabActive: CGImage
    
    let stickerBackground: CGImage
    let stickerBackgroundActive: CGImage
    let stickersTabRecent: CGImage
    let stickersTabGIF: CGImage
    
    let chatSendingInFrame_incoming: CGImage
    let chatSendingInHour_incoming: CGImage
    let chatSendingInMin_incoming: CGImage
    
    let chatSendingInFrame_outgoing: CGImage
    let chatSendingInHour_outgoing: CGImage
    let chatSendingInMin_outgoing: CGImage
    
    let chatSendingOutFrame: CGImage
    let chatSendingOutHour: CGImage
    let chatSendingOutMin: CGImage
    
    let chatSendingOverlayFrame: CGImage
    let chatSendingOverlayHour: CGImage
    let chatSendingOverlayMin: CGImage
    
    let chatActionUrl: CGImage

    let callInlineDecline: CGImage
    let callInlineMuted: CGImage
    let callInlineUnmuted: CGImage
    let eventLogTriangle: CGImage
    let channelIntro: CGImage
    
    let chatFileThumb: CGImage
    let chatFileThumbBubble_incoming: CGImage
    let chatFileThumbBubble_outgoing: CGImage

    
    let chatSecretThumb: CGImage
    let chatMapPin: CGImage
    let chatSecretTitle: CGImage
    let emptySearch: CGImage
    let calendarBack: CGImage
    let calendarNext: CGImage
    let calendarBackDisabled: CGImage
    let calendarNextDisabled: CGImage
    let newChatCamera: CGImage
    let peerInfoVerify: CGImage
    let peerInfoCall: CGImage
    let callOutgoing: CGImage
    let recentDismiss: CGImage
    let recentDismissActive: CGImage
    let webgameShare: CGImage
    
    let chatSearchCancel: CGImage
    let chatSearchFrom: CGImage
    
    let callWindowDecline: CGImage
    let callWindowAccept: CGImage
    let callWindowMute: CGImage
    let callWindowUnmute: CGImage
    let callWindowClose: CGImage
    let callWindowDeviceSettings: CGImage
    let callWindowCancel: CGImage
    
    let chatActionEdit: CGImage
    let chatActionInfo: CGImage
    let chatActionMute: CGImage
    let chatActionUnmute: CGImage
    let chatActionClearHistory: CGImage
    let chatActionDeleteChat: CGImage
    
    let dismissPinned: CGImage
    let chatActionsActive: CGImage
    let chatEntertainmentSticker: CGImage
    let chatEmpty: CGImage
    let stickerPackClose: CGImage
    let stickerPackDelete: CGImage
    
    let modalShare: CGImage
    let modalClose: CGImage
    
    let ivChannelJoined: CGImage
    let chatListMention: CGImage
    let chatListMentionActive: CGImage
    
    let chatMention: CGImage
    let chatMentionActive: CGImage
    
    let sliderControl: CGImage
    let sliderControlActive: CGImage
    
    let stickersTabFave: CGImage
    let chatInstantView: CGImage
    let chatInstantViewBubble_incoming: CGImage
    let chatInstantViewBubble_outgoing: CGImage
    
    let instantViewShare: CGImage
    let instantViewActions: CGImage
    let instantViewActionsActive: CGImage
    let instantViewSafari: CGImage
    let instantViewBack: CGImage
    let instantViewCheck: CGImage
    
    let groupStickerNotFound: CGImage
    
    let settingsAskQuestion: CGImage
    let settingsFaq: CGImage
    let settingsGeneral: CGImage
    let settingsLanguage: CGImage
    let settingsNotifications: CGImage
    let settingsSecurity: CGImage
    let settingsStickers: CGImage
    let settingsStorage: CGImage
    let settingsProxy: CGImage
    let settingsAppearance: CGImage
    let settingsPassport: CGImage
    
    let settingsAskQuestionActive: CGImage
    let settingsFaqActive: CGImage
    let settingsGeneralActive: CGImage
    let settingsLanguageActive: CGImage
    let settingsNotificationsActive: CGImage
    let settingsSecurityActive: CGImage
    let settingsStickersActive: CGImage
    let settingsStorageActive: CGImage
    let settingsProxyActive: CGImage
    let settingsAppearanceActive: CGImage
    let settingsPassportActive: CGImage

    let generalCheck: CGImage
    let settingsAbout: CGImage
    let settingsLogout: CGImage
    
    let fastSettingsLock: CGImage
    let fastSettingsDark: CGImage
    let fastSettingsSunny: CGImage
    let fastSettingsMute: CGImage
    let fastSettingsUnmute: CGImage
    
    let chatRecordVideo: CGImage
    
    let inputChannelMute: CGImage
    let inputChannelUnmute: CGImage
    
    let changePhoneNumberIntro: CGImage
    
    let peerSavedMessages: CGImage
    
    let previewCollage: CGImage
    let chatGoMessage: CGImage
    
    let chatGroupToggleSelected: CGImage
    let chatGroupToggleUnselected: CGImage
    
    let successModalProgress: CGImage
    
    let accentColorSelect: CGImage
    
    let chatShareWallpaper: CGImage
    let chatGotoMessageWallpaper: CGImage
    let transparentBackground: CGImage
    
    let passcodeTouchId: CGImage
    let passcodeLogin: CGImage
    let confirmDeleteMessagesAccessory: CGImage
    let alertCheckBoxSelected: CGImage
    let alertCheckBoxUnselected: CGImage
    let confirmPinAccessory: CGImage
    let confirmDeleteChatAccessory: CGImage
    
    let stickersEmptySearch: CGImage
    
    let twoStepVerificationCreateIntro: CGImage
    let secureIdAuth: CGImage
    
    let ivAudioPlay: CGImage
    let ivAudioPause: CGImage
    
    let proxyEnable: CGImage
    let proxyEnabled: CGImage
    let proxyState: CGImage
    let proxyDeleteListItem: CGImage
    let proxyInfoListItem: CGImage
    let proxyConnectedListItem: CGImage
    let proxyAddProxy: CGImage
    let proxyNextWaitingListItem: CGImage
    let passportForgotPassword: CGImage
    
    let confirmAppAccessoryIcon: CGImage
    
    let passportPassport: CGImage
    let passportIdCardReverse: CGImage
    let passportIdCard: CGImage
    let passportSelfie: CGImage
    let passportDriverLicense: CGImage
    
    let chatOverlayVoiceRecording: CGImage
    let chatOverlayVideoRecording: CGImage
    let chatOverlaySendRecording: CGImage
    
    let chatOverlayLockArrowRecording: CGImage
    let chatOverlayLockerBodyRecording: CGImage
    let chatOverlayLockerHeadRecording: CGImage
    
    let locationPin: CGImage
    let locationMapPin: CGImage
    let locationMapLocate: CGImage
    let locationMapLocated: CGImage
    
    let chatTabIconSelected: CGImage
    let chatTabIconSelectedUp: CGImage
    let chatTabIconSelectedDown: CGImage
    let chatTabIcon: CGImage
    
    let passportSettings: CGImage
    let passportInfo: CGImage
    
    let editMessageMedia: CGImage
    
    let playerMusicPlaceholder: CGImage
    let chatMusicPlaceholder: CGImage
    let chatMusicPlaceholderCap: CGImage
    
    let searchArticle: CGImage
    let searchSaved: CGImage
    
    let hintPeerActive: CGImage
    
    
    let chatSwiping_delete: CGImage
    let chatSwiping_mute: CGImage
    let chatSwiping_unmute: CGImage
    let chatSwiping_read: CGImage
    let chatSwiping_unread: CGImage
    let chatSwiping_pin: CGImage
    let chatSwiping_unpin: CGImage
    
    
    let galleryPrev: CGImage
    let galleryNext: CGImage
    let galleryMore: CGImage
    let galleryShare: CGImage
    let galleryFastSave: CGImage
    
    let playingVoice1x: CGImage
    let playingVoice2x: CGImage
    
    
    let galleryRotate: CGImage
    let galleryZoomIn: CGImage
    let galleryZoomOut: CGImage
    
    let previewSenderCrop: CGImage
    let previewSenderDelete: CGImage
    
    let editMessageCurrentPhoto: CGImage
    
    let previewSenderDeleteFile: CGImage
    let previewSenderArchive: CGImage
    
    let chatSwipeReply: CGImage
    let chatSwipeReplyWallpaper: CGImage
    
    let videoPlayerPlay: CGImage
    let videoPlayerPause: CGImage
    let videoPlayerEnterFullScreen: CGImage
    let videoPlayerExitFullScreen: CGImage
    let videoPlayerPIPIn: CGImage
    let videoPlayerPIPOut: CGImage
    let videoPlayerRewind15Forward: CGImage
    let videoPlayerRewind15Backward: CGImage
    let videoPlayerVolume: CGImage
    let videoPlayerVolumeOff: CGImage
    let videoPlayerClose: CGImage
    
    let videoPlayerSliderInteractor: CGImage
    
    let streamingVideoDownload: CGImage
    
    let videoCompactFetching: CGImage
    let compactStreamingFetchingCancel : CGImage
    
    let customLocalizationDelete: CGImage
    
    let pollAddOption: CGImage
    let pollDeleteOption: CGImage
    
    let resort: CGImage
    
    let chatPollVoteUnselected: CGImage
    let chatPollVoteUnselectedBubble_incoming: CGImage
    let chatPollVoteUnselectedBubble_outgoing: CGImage

    
    let peerInfoAdmins: CGImage
    let peerInfoPermissions: CGImage
    let peerInfoBanned: CGImage
    let peerInfoMembers: CGImage
    
    let chatUndoAction: CGImage
    
   // let videoMessageChatCap: CGImage

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


enum Wallpaper : Equatable, PostboxCoding {
    case builtin
    case color(Int32)
    case image([TelegramMediaImageRepresentation], blurred: Bool)
    case file(slug: String, file: TelegramMediaFile, blurred: Bool)
    case none
    case custom(TelegramMediaImageRepresentation, blurred: Bool)
    
    init(_ wallpaper: TelegramWallpaper) {
        switch wallpaper {
        case .builtin:
            self = .builtin
        case let .color(color):
            self = .color(color)
        case let .image(image):
            self = .image(image, blurred: false)
        case let .file(values):
            self = .file(slug: values.slug, file: values.file, blurred: false)
        }
    }
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
        case 0:
            self = .builtin
        case 1:
            self = .color(decoder.decodeInt32ForKey("c", orElse: 0))
        case 2:
            self = .image(decoder.decodeObjectArrayWithDecoderForKey("i"), blurred: decoder.decodeInt32ForKey("b", orElse: 0) == 1)
        case 3:
            self = .file(slug: decoder.decodeStringForKey("slug", orElse: ""), file: decoder.decodeObjectForKey("file", decoder: { TelegramMediaFile(decoder: $0) }) as! TelegramMediaFile, blurred: decoder.decodeInt32ForKey("b", orElse: 0) == 1)
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
        case let .image(representations, blurred):
            encoder.encodeInt32(2, forKey: "v")
            encoder.encodeObjectArray(representations, forKey: "i")
            encoder.encodeInt32(blurred ? 1 : 0, forKey: "b")
        case let .file(slug, file, blurred):
            encoder.encodeInt32(3, forKey: "v")
            encoder.encodeString(slug, forKey: "slug")
            encoder.encodeObject(file, forKey: "file")
            encoder.encodeInt32(blurred ? 1 : 0, forKey: "b")
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
        case let .image(representations, _):
            return .image(representations, blurred: blurred)
        case let .file(values):
            return .file(slug: values.slug, file: values.file, blurred: blurred)
        case let .custom(path, _):
            return .custom(path, blurred: blurred)
        case .none:
            return self
        }
    }
    
    var isBlurred: Bool {
        switch self {
        case let .builtin:
            return false
        case .color:
            return false
        case let .image(_, blurred):
            return blurred
        case let .file(values):
            return values.blurred
        case let .custom(_, blurred):
            return blurred
        case .none:
            return false
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
            if case .file(slug: values.slug, file: _, blurred: _) = other {
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
    color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    saturation = min(1.0, saturation + 0.05 + 0.1 * (1.0 - saturation))
    brightness = max(0.0, brightness * 0.65)
    alpha = 0.4
    color = NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    
    return color
}

private func getAverageColor(_ color: NSColor) -> NSColor {
    var hue: CGFloat = 0.0
    var saturation: CGFloat = 0.0
    var brightness: CGFloat = 0.0
    var alpha: CGFloat = 0.0
    color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    saturation = min(1.0, saturation + 0.05 + 0.1 * (1.0 - saturation))
    brightness = max(0.0, brightness * 0.65)
    alpha = 0.4
    
    return NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
}

class TelegramPresentationTheme : PresentationTheme {
    let chatList:TelegramChatListTheme
    #if !SHARE
        let chat: TelegramChatColors
    #endif
    let tabBar:TelegramTabBarTheme
    let icons: TelegramIconsTheme
    let bubbled: Bool
    let wallpaper: Wallpaper
    let backgroundMode: TableBackgroundMode
    let chatServiceItemColor: NSColor
    let chatServiceItemTextColor: NSColor
    let fontSize: CGFloat
    let followSystemAppearance: Bool
    init(colors: ColorPalette, search: SearchTheme, chatList: TelegramChatListTheme, tabBar: TelegramTabBarTheme, icons: TelegramIconsTheme, bubbled: Bool, fontSize: CGFloat, wallpaper: Wallpaper, followSystemAppearance: Bool) {
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
        #if !SHARE
        switch wallpaper {
        case .builtin:
            backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
        case let.color(color):
            backgroundMode = .color(color: NSColor(UInt32(abs(color))))
        case let .image(representation, blurred):
            if let resource = largestImageRepresentation(representation)?.resource, let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(resource, blurred: blurred))) {
                backgroundMode = .background(image: image)
            } else {
                backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
            }
            
        case let .file(_, file, blurred):
            if let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(file.resource, blurred: blurred))) {
                backgroundMode = .background(image: image)
            } else {
                backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
            }
        case .none:
            backgroundMode = .plain
        case let .custom(representation, blurred):
            if let image = NSImage(contentsOf: URL(fileURLWithPath: wallpaperPath(representation.resource, blurred: blurred))) {
                backgroundMode = .background(image: image)
            } else {
                backgroundMode = .background(image: #imageLiteral(resourceName: "builtin-wallpaper-0.jpg"))
            }
        }
        #else
            self.backgroundMode = .plain
        #endif

        switch backgroundMode {
        case let .background(image):
            chatServiceItemColor = getAverageColor(image)
            chatServiceItemTextColor = .white
        case let .color(color):
            chatServiceItemColor = getAverageColor(color)
            chatServiceItemTextColor = .white
        case let .tiled(image):
            chatServiceItemColor = getAverageColor(image)
            chatServiceItemTextColor = chatServiceItemColor.brightnessAdjustedColor
        case .plain:
            chatServiceItemColor = colors.background
            chatServiceItemTextColor = colors.grayText
        }
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
}



private func generateIcons(from palette: ColorPalette, bubbled: Bool) -> TelegramIconsTheme {
    return TelegramIconsTheme(dialogMuteImage: #imageLiteral(resourceName: "Icon_DialogMute").precomposed(palette.grayIcon),
                                               dialogMuteImageSelected: #imageLiteral(resourceName: "Icon_DialogMute").precomposed(.white),
                                               outgoingMessageImage: #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(palette.name == dayClassic.name && bubbled ? palette.blueIconBubble_outgoing : palette.blueIcon, flipVertical:true),
                                               readMessageImage: #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(palette.name == dayClassic.name && bubbled ? palette.blueIconBubble_outgoing : palette.blueIcon, flipVertical:true),
                                               outgoingMessageImageSelected: #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(.white, flipVertical:true),
                                               readMessageImageSelected: #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(.white, flipVertical:true),
                                               sendingImage: #imageLiteral(resourceName: "Icon_ChatStateSending").precomposed(palette.grayIcon, flipVertical:true),
                                               sendingImageSelected: #imageLiteral(resourceName: "Icon_ChatStateSending").precomposed(.white, flipVertical:true),
                                               secretImage:#imageLiteral(resourceName: "Icon_SecretChatLock").precomposed(bubbled && palette.name == dayClassic.name ? palette.blueIconBubble_outgoing : palette.blueIcon, flipVertical:true),
                                               secretImageSelected: #imageLiteral(resourceName: "Icon_SecretChatLock").precomposed(.white, flipVertical:true),
                                               pinnedImage: #imageLiteral(resourceName: "Icon_ChatListPinned").precomposed(palette.grayIcon, flipVertical:true),
                                               pinnedImageSelected: #imageLiteral(resourceName: "Icon_ChatListPinned").precomposed(.white, flipVertical:true),
                                               verifiedImage: #imageLiteral(resourceName: "Icon_VerifyPeer").precomposed(flipVertical: true),
                                               verifiedImageSelected: #imageLiteral(resourceName: "Icon_VerifyPeerActive").precomposed(flipVertical: true),
                                               errorImage: #imageLiteral(resourceName: "Icon_MessageSentFailed").precomposed(flipVertical: true),
                                               errorImageSelected: #imageLiteral(resourceName: "Icon_DialogSendingError").precomposed(flipVertical: true),
                                               chatSearch: #imageLiteral(resourceName: "Icon_SearchChatMessages").precomposed(palette.blueIcon),
                                               chatCall: #imageLiteral(resourceName: "Icon_callNavigationHeader").precomposed(palette.blueIcon),
                                               chatActions: #imageLiteral(resourceName: "Icon_ChatActions").precomposed(palette.blueIcon),
                                               chatFailedCall_incoming: #imageLiteral(resourceName: "Icon_MessageCallIncoming").precomposed(palette.redUI),
                                               chatFailedCall_outgoing: #imageLiteral(resourceName: "Icon_MessageCallOutgoing").precomposed(palette.redUI),
                                               chatCall_incoming: #imageLiteral(resourceName: "Icon_MessageCallIncoming").precomposed(palette.greenUI),
                                               chatCall_outgoing: #imageLiteral(resourceName: "Icon_MessageCallOutgoing").precomposed(palette.greenUI),
                                               chatFailedCallBubble_incoming: #imageLiteral(resourceName: "Icon_MessageCallIncoming").precomposed(palette.redBubble_incoming),
                                               chatFailedCallBubble_outgoing: #imageLiteral(resourceName: "Icon_MessageCallOutgoing").precomposed(palette.redBubble_outgoing),
                                               chatCallBubble_incoming: #imageLiteral(resourceName: "Icon_MessageCallIncoming").precomposed(palette.greenBubble_incoming),
                                               chatCallBubble_outgoing: #imageLiteral(resourceName: "Icon_MessageCallOutgoing").precomposed(palette.greenBubble_outgoing),
                                               chatFallbackCall: #imageLiteral(resourceName: "Icon_MessageCall").precomposed(palette.blueIcon),
                                               chatFallbackCallBubble_incoming: #imageLiteral(resourceName: "Icon_MessageCall").precomposed(palette.fileActivityBackgroundBubble_incoming),
                                               chatFallbackCallBubble_outgoing: #imageLiteral(resourceName: "Icon_MessageCall").precomposed(palette.fileActivityBackgroundBubble_outgoing),
                                               
                                               chatToggleSelected: #imageLiteral(resourceName: "Icon_Check").precomposed(palette.blueIcon),
                                               chatToggleUnselected: #imageLiteral(resourceName: "Icon_SelectionUncheck").precomposed(),
                                               chatShare: #imageLiteral(resourceName: "Icon_ChannelShare").precomposed(palette.blueIcon),
                                               chatMusicPlay: #imageLiteral(resourceName: "Icon_ChatMusicPlay").precomposed(),
                                               chatMusicPlayBubble_incoming: #imageLiteral(resourceName: "Icon_ChatMusicPlay").precomposed(palette.fileActivityForegroundBubble_incoming),
                                               chatMusicPlayBubble_outgoing: #imageLiteral(resourceName: "Icon_ChatMusicPlay").precomposed(palette.fileActivityForegroundBubble_outgoing),
                                               chatMusicPause: #imageLiteral(resourceName: "Icon_ChatMusicPause").precomposed(),
                                               chatMusicPauseBubble_incoming: #imageLiteral(resourceName: "Icon_ChatMusicPause").precomposed(palette.fileActivityForegroundBubble_incoming),
                                               chatMusicPauseBubble_outgoing: #imageLiteral(resourceName: "Icon_ChatMusicPause").precomposed(palette.fileActivityForegroundBubble_outgoing),
                                               composeNewChat:#imageLiteral(resourceName: "Icon_NewMessage").precomposed(palette.blueIcon),
                                               composeNewChatActive:#imageLiteral(resourceName: "Icon_NewMessage").precomposed(.white),
                                               composeNewGroup:#imageLiteral(resourceName: "Icon_NewGroup").precomposed(palette.blueIcon),
                                               composeNewSecretChat: #imageLiteral(resourceName: "Icon_NewSecretChat").precomposed(palette.blueIcon),
                                               composeNewChannel: #imageLiteral(resourceName: "Icon_NewChannel").precomposed(palette.blueIcon),
                                               contactsNewContact: #imageLiteral(resourceName: "Icon_NewContact").precomposed(palette.blueIcon),
                                               chatReadMarkInBubble1_incoming: #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(palette.blueIconBubble_incoming),
                                               chatReadMarkInBubble2_incoming: #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(palette.blueIconBubble_incoming),
                                               chatReadMarkInBubble1_outgoing: #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(palette.blueIconBubble_outgoing),
                                               chatReadMarkInBubble2_outgoing: #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(palette.blueIconBubble_outgoing),
                                               chatReadMarkOutBubble1: #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(palette.blueIcon),
                                               chatReadMarkOutBubble2: #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(palette.blueIcon),
                                               chatReadMarkOverlayBubble1: #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(.white),
                                               chatReadMarkOverlayBubble2:#imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(.white),
                                               sentFailed: generateImage(NSMakeSize(13, 13), contextGenerator: { size, ctx in
                                                    ctx.clear(NSMakeRect(0, 0, size.width, size.height))
                                                    ctx.draw(#imageLiteral(resourceName: "Icon_MessageSentFailed").precomposed(), in: NSMakeRect(0, 0, size.width, size.height))
                                               })!,
                                               chatChannelViewsInBubble_incoming: #imageLiteral(resourceName: "Icon_ChannelViews").precomposed(palette.grayIconBubble_incoming, flipVertical: true),
                                               chatChannelViewsInBubble_outgoing: #imageLiteral(resourceName: "Icon_ChannelViews").precomposed(palette.grayIconBubble_outgoing, flipVertical: true),
                                               chatChannelViewsOutBubble: #imageLiteral(resourceName: "Icon_ChannelViews").precomposed(palette.grayIcon, flipVertical: true),
                                               chatChannelViewsOverlayBubble: #imageLiteral(resourceName: "Icon_ChannelViews").precomposed(.white, flipVertical: true),
                                               chatNavigationBack: #imageLiteral(resourceName: "Icon_ChatNavigationBack").precomposed(palette.blueIcon),
                                               peerInfoAddMember: #imageLiteral(resourceName: "Icon_GroupInfoAddMember").precomposed(palette.blueIcon, flipVertical: true),
                                               chatSearchUp: #imageLiteral(resourceName: "Icon_SearchArrow").precomposed(palette.blueIcon),
                                               chatSearchUpDisabled: #imageLiteral(resourceName: "Icon_SearchArrow").precomposed(palette.grayIcon),
                                               chatSearchDown: #imageLiteral(resourceName: "Icon_SearchArrow").precomposed(palette.blueIcon, flipVertical:true),
                                               chatSearchDownDisabled: #imageLiteral(resourceName: "Icon_SearchArrow").precomposed(palette.grayIcon, flipVertical:true),
                                               chatSearchCalendar: #imageLiteral(resourceName: "Icon_Calendar").precomposed(palette.blueIcon),
                                               dismissAccessory: #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.grayIcon),
                                               chatScrollUp: generateChatScrolldownImage(backgroundColor: palette.background, borderColor: palette.grayIcon, arrowColor: palette.grayIcon),
                                               chatScrollUpActive: generateChatScrolldownImage(backgroundColor: palette.background, borderColor: palette.blueIcon, arrowColor: palette.blueIcon),
                                               audioPlayerPlay: #imageLiteral(resourceName: "Icon_InlinePlayerPlay").precomposed(palette.blueIcon),
                                               audioPlayerPause: #imageLiteral(resourceName: "Icon_InlinePlayerPause").precomposed(palette.blueIcon),
                                               audioPlayerNext: #imageLiteral(resourceName: "Icon_InlinePlayerNext").precomposed(palette.blueIcon),
                                               audioPlayerPrev: #imageLiteral(resourceName: "Icon_InlinePlayerPrevious").precomposed(palette.blueIcon),
                                               auduiPlayerDismiss: #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.blueIcon),
                                               audioPlayerRepeat: #imageLiteral(resourceName: "Icon_RepeatAudio").precomposed(palette.grayIcon),
                                               audioPlayerRepeatActive: #imageLiteral(resourceName: "Icon_RepeatAudio").precomposed(palette.blueIcon),
                                               audioPlayerLockedPlay: #imageLiteral(resourceName: "Icon_InlinePlayerPlay").precomposed(palette.grayIcon),
                                               audioPlayerLockedNext: #imageLiteral(resourceName: "Icon_InlinePlayerNext").precomposed(palette.grayIcon),
                                               audioPlayerLockedPrev: #imageLiteral(resourceName: "Icon_InlinePlayerPrevious").precomposed(palette.grayIcon),
                                               chatSendMessage: #imageLiteral(resourceName: "Icon_SendMessage").precomposed(palette.blueIcon),
                                               chatRecordVoice: #imageLiteral(resourceName: "Icon_RecordVoice").precomposed(palette.grayIcon),
                                               chatEntertainment: #imageLiteral(resourceName: "Icon_Entertainments").precomposed(palette.grayIcon),
                                               chatInlineDismiss: #imageLiteral(resourceName: "Icon_InlineResultCancel").precomposed(palette.grayIcon),
                                               chatActiveReplyMarkup: #imageLiteral(resourceName: "Icon_ReplyMarkupButton").precomposed(palette.blueIcon),
                                               chatDisabledReplyMarkup: #imageLiteral(resourceName: "Icon_ReplyMarkupButton").precomposed(palette.grayIcon),
                                               chatSecretTimer: #imageLiteral(resourceName: "Icon_SecretTimer").precomposed(palette.grayIcon),
                                               chatForwardMessagesActive: #imageLiteral(resourceName: "Icon_MessageActionPanelForward").precomposed(palette.blueIcon),
                                               chatForwardMessagesInactive: #imageLiteral(resourceName: "Icon_MessageActionPanelForward").precomposed(palette.grayIcon),
                                               chatDeleteMessagesActive: #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(palette.redUI),
                                               chatDeleteMessagesInactive: #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(palette.grayIcon),
                                               generalNext: #imageLiteral(resourceName: "Icon_GeneralNext").precomposed(palette.grayIcon.withAlphaComponent(0.5)),
                                               generalNextActive: #imageLiteral(resourceName: "Icon_GeneralNext").precomposed(.white),
                                               generalSelect: #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(palette.blueIcon),
                                               chatVoiceRecording: #imageLiteral(resourceName: "Icon_RecordingVoice").precomposed(palette.blueIcon),
                                               chatVideoRecording: #imageLiteral(resourceName: "Icon_RecordVideoMessage").precomposed(palette.blueIcon),
                                               chatRecord: #imageLiteral(resourceName: "Icon_RecordVoice").precomposed(palette.grayIcon),
                                               deleteItem: deleteItemIcon(palette.redUI),
                                               deleteItemDisabled: deleteItemIcon(palette.grayTransparent),
                                               chatAttach: #imageLiteral(resourceName: "Icon_ChatAttach").precomposed(palette.grayIcon),
                                               chatAttachFile: #imageLiteral(resourceName: "Icon_AttachFile").precomposed(palette.blueIcon),
                                               chatAttachPhoto: #imageLiteral(resourceName: "Icon_AttachPhoto").precomposed(palette.blueIcon),
                                               chatAttachCamera: #imageLiteral(resourceName: "Icon_AttachCamera").precomposed(palette.blueIcon),
                                               chatAttachLocation: #imageLiteral(resourceName: "Icon_AttachLocation").precomposed(palette.blueIcon),
                                               chatAttachPoll: #imageLiteral(resourceName: "Icon_AttachPoll").precomposed(palette.blueIcon),
                                               mediaEmptyShared: #imageLiteral(resourceName: "Icon_EmptySharedMedia").precomposed(palette.grayIcon),
                                               mediaEmptyFiles: #imageLiteral(resourceName: "Icon_EmptySharedFiles").precomposed(),
                                               mediaEmptyMusic: #imageLiteral(resourceName: "Icon_EmptySharedMusic").precomposed(palette.grayIcon),
                                               mediaEmptyLinks: #imageLiteral(resourceName: "Icon_EmptySharedLinks").precomposed(palette.grayIcon),
                                               mediaDropdown: #imageLiteral(resourceName: "Icon_DropdownArrow").precomposed(palette.blueIcon),
                                               stickersAddFeatured: #imageLiteral(resourceName: "Icon_GroupInfoAddMember").precomposed(palette.blueIcon),
                                               stickersAddedFeatured: #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(palette.grayIcon),
                                               stickersRemove: #imageLiteral(resourceName: "Icon_InlineResultCancel").precomposed(palette.grayIcon),
                                               peerMediaDownloadFileStart: #imageLiteral(resourceName: "Icon_MediaDownload").precomposed(palette.blueIcon),
                                               peerMediaDownloadFilePause: downloadFilePauseIcon(palette.blueIcon),
                                               stickersShare: #imageLiteral(resourceName: "Icon_ShareStickerPack").precomposed(palette.blueIcon),
                                               emojiRecentTab: #imageLiteral(resourceName: "Icon_EmojiTabRecent").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiSmileTab: #imageLiteral(resourceName: "Icon_EmojiTabSmiles").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiNatureTab: #imageLiteral(resourceName: "Icon_EmojiTabNature").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiFoodTab: #imageLiteral(resourceName: "Icon_EmojiTabFood").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiSportTab: #imageLiteral(resourceName: "Icon_EmojiTabSports").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiCarTab: #imageLiteral(resourceName: "Icon_EmojiTabCar").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiObjectsTab: #imageLiteral(resourceName: "Icon_EmojiTabObjects").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiSymbolsTab: #imageLiteral(resourceName: "Icon_EmojiTabSymbols").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiFlagsTab: #imageLiteral(resourceName: "Icon_EmojiTabFlag").precomposed(palette.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiRecentTabActive: #imageLiteral(resourceName: "Icon_EmojiTabRecent").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true),
                                               emojiSmileTabActive: #imageLiteral(resourceName: "Icon_EmojiTabSmiles").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true),
                                               emojiNatureTabActive: #imageLiteral(resourceName: "Icon_EmojiTabNature").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true),
                                               emojiFoodTabActive: #imageLiteral(resourceName: "Icon_EmojiTabFood").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true),
                                               emojiSportTabActive: #imageLiteral(resourceName: "Icon_EmojiTabSports").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true),
                                               emojiCarTabActive: #imageLiteral(resourceName: "Icon_EmojiTabCar").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true),
                                               emojiObjectsTabActive: #imageLiteral(resourceName: "Icon_EmojiTabObjects").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true),
                                               emojiSymbolsTabActive: #imageLiteral(resourceName: "Icon_EmojiTabSymbols").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true),
                                               emojiFlagsTabActive: #imageLiteral(resourceName: "Icon_EmojiTabFlag").precomposed(palette.blueIcon, flipVertical:true, flipHorizontal:true),
                                               stickerBackground: generateStickerBackground(NSMakeSize(83, 83), palette.background),
                                               stickerBackgroundActive: generateStickerBackground(NSMakeSize(83, 83), palette.grayBackground),
                                               stickersTabRecent: #imageLiteral(resourceName: "Icon_EmojiTabRecent").precomposed(palette.grayIcon),
                                               stickersTabGIF: #imageLiteral(resourceName: "Icon_GifToggle").precomposed(palette.grayIcon),
                                               chatSendingInFrame_incoming: generateSendingFrame(palette.grayIconBubble_incoming),
                                               chatSendingInHour_incoming: generateSendingHour(palette.grayIconBubble_incoming),
                                               chatSendingInMin_incoming: generateSendingMin(palette.grayIconBubble_incoming),
                                               chatSendingInFrame_outgoing: generateSendingFrame(palette.grayIconBubble_outgoing),
                                               chatSendingInHour_outgoing: generateSendingHour(palette.grayIconBubble_outgoing),
                                               chatSendingInMin_outgoing: generateSendingMin(palette.grayIconBubble_outgoing),
                                               chatSendingOutFrame: generateSendingFrame(palette.grayIcon),
                                               chatSendingOutHour: generateSendingHour(palette.grayIcon),
                                               chatSendingOutMin: generateSendingMin(palette.grayIcon),
                                               chatSendingOverlayFrame: generateSendingFrame(.white),
                                               chatSendingOverlayHour: generateSendingHour(.white),
                                               chatSendingOverlayMin: generateSendingMin(.white),
                                               chatActionUrl: #imageLiteral(resourceName: "Icon_InlineBotUrl").precomposed(palette.text),
                                               callInlineDecline: #imageLiteral(resourceName: "Icon_CallDecline_Inline").precomposed(.white),
                                               callInlineMuted: #imageLiteral(resourceName: "Icon_CallMute_Inline").precomposed(.white),
                                               callInlineUnmuted: #imageLiteral(resourceName: "Icon_CallUnmuted_Inline").precomposed(.white),
                                               eventLogTriangle: generateRecentActionsTriangle(palette.text),
                                               channelIntro: #imageLiteral(resourceName: "Icon_ChannelIntro").precomposed(),
                                               chatFileThumb: #imageLiteral(resourceName: "Icon_MessageFile").precomposed(flipVertical:true),
                                               chatFileThumbBubble_incoming: #imageLiteral(resourceName: "Icon_MessageFile").precomposed(palette.fileActivityForegroundBubble_incoming,  flipVertical:true),
                                               chatFileThumbBubble_outgoing: #imageLiteral(resourceName: "Icon_MessageFile").precomposed(palette.fileActivityForegroundBubble_outgoing, flipVertical:true),
                                               chatSecretThumb: #imageLiteral(resourceName: "Icon_SecretAutoremoveMedia").precomposed(.black, flipVertical:true),
                                               chatMapPin: #imageLiteral(resourceName: "Icon_MapPinned").precomposed(),
                                               chatSecretTitle: #imageLiteral(resourceName: "Icon_SecretChatLock").precomposed(palette.text, flipVertical:true),
                                               emptySearch: #imageLiteral(resourceName: "Icon_EmptySearchResults").precomposed(palette.grayIcon),
                                               calendarBack: #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(palette.blueIcon),
                                               calendarNext: #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(palette.blueIcon, flipHorizontal: true),
                                               calendarBackDisabled: #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(palette.grayIcon),
                                               calendarNextDisabled: #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(palette.grayIcon, flipHorizontal: true),
                                               newChatCamera: #imageLiteral(resourceName: "Icon_AttachCamera").precomposed(palette.grayIcon),
                                               peerInfoVerify: #imageLiteral(resourceName: "Icon_VerifyPeer").precomposed(flipVertical: true),
                                               peerInfoCall: #imageLiteral(resourceName: "Icon_ProfileCall").precomposed(palette.blueUI),
                                               callOutgoing: #imageLiteral(resourceName: "Icon_CallOutgoing").precomposed(palette.grayIcon, flipVertical: true),
                                               recentDismiss: #imageLiteral(resourceName: "Icon_SearchClear").precomposed(palette.grayIcon),
                                               recentDismissActive: #imageLiteral(resourceName: "Icon_SearchClear").precomposed(.white),
                                               webgameShare: #imageLiteral(resourceName: "Icon_ShareExternal").precomposed(palette.blueIcon),
                                               chatSearchCancel: #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.blueIcon),
                                               chatSearchFrom: #imageLiteral(resourceName: "Icon_ChatSearchFrom").precomposed(palette.blueIcon),
                                               callWindowDecline: #imageLiteral(resourceName: "Icon_CallDecline_Window").precomposed(),
                                               callWindowAccept: #imageLiteral(resourceName: "Icon_CallAccept_Window").precomposed(),
                                               callWindowMute: #imageLiteral(resourceName: "Icon_CallMic_Window").precomposed(),
                                               callWindowUnmute: #imageLiteral(resourceName: "Icon_CallMute_Inline").precomposed(),
                                               callWindowClose: #imageLiteral(resourceName: "Icon_CallWindowClose").precomposed(.white),
                                               callWindowDeviceSettings: #imageLiteral(resourceName: "Icon_CallDeviceSettings").precomposed(.white),
                                               callWindowCancel: #imageLiteral(resourceName: "Icon_CallCancelIcon").precomposed(.white),
                                               chatActionEdit: #imageLiteral(resourceName: "Icon_ChatActionEdit").precomposed(palette.blueIcon),
                                               chatActionInfo: #imageLiteral(resourceName: "Icon_ChatActionInfo").precomposed(palette.blueIcon),
                                               chatActionMute: #imageLiteral(resourceName: "Icon_ChatActionMute").precomposed(palette.blueIcon),
                                               chatActionUnmute: #imageLiteral(resourceName: "Icon_ChatActionUnmute").precomposed(palette.blueIcon),
                                               chatActionClearHistory: #imageLiteral(resourceName: "Icon_ClearChat").precomposed(palette.blueIcon),
                                               chatActionDeleteChat: #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(palette.blueIcon),
                                               dismissPinned: #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.blueIcon),
                                               chatActionsActive: #imageLiteral(resourceName: "Icon_ChatActionsActive").precomposed(palette.blueIcon),
                                               chatEntertainmentSticker: #imageLiteral(resourceName: "Icon_ChatEntertainmentSticker").precomposed(palette.grayIcon),
                                               chatEmpty: #imageLiteral(resourceName: "Icon_EmptyChat").precomposed(palette.grayForeground),
                                               stickerPackClose: #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.blueIcon),
                                               stickerPackDelete: #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(palette.blueIcon),
                                               modalShare: #imageLiteral(resourceName: "Icon_ShareStickerPack").precomposed(palette.blueIcon),
                                               modalClose: #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(palette.blueIcon),
                                               ivChannelJoined: #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(.white),
                                               chatListMention: generateBadgeMention(backgroundColor: palette.blueUI, foregroundColor: palette.background),
                                               chatListMentionActive: generateBadgeMention(backgroundColor: .white, foregroundColor: palette.blueSelect),
                                               chatMention: generateChatMention(backgroundColor: palette.background, border: palette.grayIcon, foregroundColor: palette.grayIcon),
                                               chatMentionActive: generateChatMention(backgroundColor: palette.background, border: palette.blueIcon, foregroundColor: palette.blueIcon),
                                               sliderControl: #imageLiteral(resourceName: "Icon_SliderNormal").precomposed(),
                                               sliderControlActive: #imageLiteral(resourceName: "Icon_SliderNormal").precomposed(),
                                               stickersTabFave: #imageLiteral(resourceName: "Icon_FaveStickers").precomposed(palette.grayIcon),
                                               chatInstantView: #imageLiteral(resourceName: "Icon_ChatIV").precomposed(palette.webPreviewActivity),
                                               chatInstantViewBubble_incoming: #imageLiteral(resourceName: "Icon_ChatIV").precomposed(palette.webPreviewActivityBubble_incoming),
                                               chatInstantViewBubble_outgoing: #imageLiteral(resourceName: "Icon_ChatIV").precomposed(palette.webPreviewActivityBubble_outgoing),
                                               instantViewShare: #imageLiteral(resourceName: "Icon_ShareStickerPack").precomposed(palette.blueIcon),
                                               instantViewActions: #imageLiteral(resourceName: "Icon_ChatActions").precomposed(palette.blueIcon),
                                               instantViewActionsActive: #imageLiteral(resourceName: "Icon_ChatActionsActive").precomposed(palette.blueIcon),
                                               instantViewSafari: #imageLiteral(resourceName: "Icon_InstantViewSafari").precomposed(palette.blueIcon),
                                               instantViewBack: #imageLiteral(resourceName: "Icon_InstantViewBack").precomposed(palette.blueIcon),
                                               instantViewCheck: #imageLiteral(resourceName: "Icon_InstantViewCheck").precomposed(palette.blueIcon),
                                               groupStickerNotFound: #imageLiteral(resourceName: "Icon_GroupStickerNotFound").precomposed(palette.grayIcon),
                                               settingsAskQuestion: generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsAskQuestion").precomposed(flipVertical: true)),
                                               settingsFaq: generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsFaq").precomposed(flipVertical: true)),
                                               settingsGeneral: generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsGeneral").precomposed(flipVertical: true)),
                                               settingsLanguage: generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsLanguage").precomposed(flipVertical: true)),
                                               settingsNotifications: generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsNotifications").precomposed(flipVertical: true)),
                                               settingsSecurity: generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsSecurity").precomposed(flipVertical: true)),
                                               settingsStickers: generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsStickers").precomposed(flipVertical: true)),
                                               settingsStorage: generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsStorage").precomposed(flipVertical: true)),
                                               settingsProxy: generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsProxy").precomposed(flipVertical: true)),
                                               settingsAppearance: generateSettingsIcon(#imageLiteral(resourceName: "Icon_AppearanceSettings").precomposed(flipVertical: true)),
                                               settingsPassport: generateSettingsIcon(#imageLiteral(resourceName: "Icon_SettingsSecurity").precomposed(flipVertical: true)),
                                               settingsAskQuestionActive: generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsAskQuestion").precomposed(.white, flipVertical: true), background: palette.blueSelect),
                                               settingsFaqActive: generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsFaq").precomposed(.white, flipVertical: true), background: palette.blueSelect),
                                               settingsGeneralActive: generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsGeneral").precomposed(.white, flipVertical: true), background: palette.blueSelect),
                                               settingsLanguageActive: generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsLanguage").precomposed(.white, flipVertical: true), background: palette.blueSelect),
                                               settingsNotificationsActive: generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsNotifications").precomposed(.white, flipVertical: true), background: palette.blueSelect),
                                               settingsSecurityActive: generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsSecurity").precomposed(.white, flipVertical: true), background: palette.blueSelect),
                                               settingsStickersActive: generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsStickers").precomposed(.white, flipVertical: true), background: palette.blueSelect),
                                               settingsStorageActive: generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsStorage").precomposed(.white, flipVertical: true), background: palette.blueSelect),
                                               settingsProxyActive: generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsProxy").precomposed(.white, flipVertical: true), background: palette.blueSelect),
                                               settingsAppearanceActive: generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_AppearanceSettings").precomposed(.white, flipVertical: true), background: palette.blueSelect),
                                               settingsPassportActive: generateSettingsActiveIcon(#imageLiteral(resourceName: "Icon_SettingsSecurity").precomposed(.white, flipVertical: true), background: palette.blueSelect),
                                               generalCheck: #imageLiteral(resourceName: "Icon_Check").precomposed(palette.blueIcon),
                                               settingsAbout: #imageLiteral(resourceName: "Icon_SettingsAbout").precomposed(palette.blueIcon),
                                               settingsLogout: #imageLiteral(resourceName: "Icon_SettingsLogout").precomposed(palette.redUI),
                                               fastSettingsLock: #imageLiteral(resourceName: "Icon_FastSettingsLock").precomposed(palette.blueIcon),
                                               fastSettingsDark: #imageLiteral(resourceName: "Icon_FastSettingsDark").precomposed(palette.blueIcon),
                                               fastSettingsSunny: #imageLiteral(resourceName: "Icon_FastSettingsSunny").precomposed(palette.blueIcon),
                                               fastSettingsMute: #imageLiteral(resourceName: "Icon_ChatActionMute").precomposed(palette.blueIcon),
                                               fastSettingsUnmute: #imageLiteral(resourceName: "Icon_ChatActionUnmute").precomposed(palette.blueIcon),
                                               chatRecordVideo: #imageLiteral(resourceName: "Icon_RecordVideoMessage").precomposed(palette.grayIcon),
                                               inputChannelMute: #imageLiteral(resourceName: "Icon_InputChannelMute").precomposed(palette.grayIcon),
                                               inputChannelUnmute: #imageLiteral(resourceName: "Icon_InputChannelUnmute").precomposed(palette.grayIcon),
                                               changePhoneNumberIntro: #imageLiteral(resourceName: "Icon_ChangeNumberIntro").precomposed(),
                                               peerSavedMessages: #imageLiteral(resourceName: "Icon_SavedMessages").precomposed(),
                                               previewCollage: #imageLiteral(resourceName: "Icon_PreviewCollage").precomposed(palette.grayIcon),
                                               chatGoMessage: #imageLiteral(resourceName: "Icon_ChatGoMessage").precomposed(palette.blueIcon),
                                               chatGroupToggleSelected: generateChatGroupToggleSelected(foregroundColor: palette.blueIcon),
                                               chatGroupToggleUnselected: #imageLiteral(resourceName: "Icon_SelectionUncheck").precomposed(),
                                               successModalProgress: #imageLiteral(resourceName: "Icon_ProgressWindowCheck").precomposed(palette.grayIcon),
                                               accentColorSelect: #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(.white),
                                               chatShareWallpaper: #imageLiteral(resourceName: "Icon_ShareInBubble").precomposed(palette.blueIcon),
                                               chatGotoMessageWallpaper: #imageLiteral(resourceName: "Icon_GotoBubbleMessage").precomposed(palette.blueIcon),
                                               transparentBackground: generateTransparentBackground(),
                                               passcodeTouchId: #imageLiteral(resourceName: "Icon_TouchId").precomposed(),
                                               passcodeLogin: #imageLiteral(resourceName: "Icon_PasscodeLogin").precomposed(),
                                               confirmDeleteMessagesAccessory: generateConfirmDeleteMessagesAccessory(backgroundColor: palette.redUI),
                                               alertCheckBoxSelected: generateAlertCheckBoxSelected(backgroundColor: palette.blueIcon),
                                               alertCheckBoxUnselected: generateAlertCheckBoxUnselected(border: palette.grayIcon),
                                               confirmPinAccessory: generateConfirmPinAccessory(backgroundColor: palette.blueIcon),
                                               confirmDeleteChatAccessory: generateConfirmDeleteChatAccessory(backgroundColor: palette.background, foregroundColor: palette.redUI),
                                               stickersEmptySearch: generateStickersEmptySearch(color: palette.grayIcon),
                                               twoStepVerificationCreateIntro: #imageLiteral(resourceName: "Icon_TwoStepVerification_Create").precomposed(),
                                               secureIdAuth: #imageLiteral(resourceName: "Icon_SecureIdAuth").precomposed(),
                                               ivAudioPlay: generateIVAudioPlay(color: palette.text),
                                               ivAudioPause: generateIVAudioPause(color: palette.text),
                                               proxyEnable: #imageLiteral(resourceName: "Icon_ProxyEnable").precomposed(palette.blueUI),
                                               proxyEnabled: #imageLiteral(resourceName: "Icon_ProxyEnabled").precomposed(palette.blueUI),
                                               proxyState: #imageLiteral(resourceName: "Icon_ProxyState").precomposed(palette.blueUI),
                                               proxyDeleteListItem: #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(palette.blueIcon),
                                               proxyInfoListItem: #imageLiteral(resourceName: "Icon_SettingsBio").precomposed(palette.blueIcon),
                                               proxyConnectedListItem: #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(palette.blueIcon),
                                               proxyAddProxy: #imageLiteral(resourceName: "Icon_GroupInfoAddMember").precomposed(palette.blueIcon, flipVertical: true),
                                               proxyNextWaitingListItem: #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(palette.grayIcon),
                                               passportForgotPassword: #imageLiteral(resourceName: "Icon_SecureIdForgotPassword").precomposed(palette.grayIcon),
                                               confirmAppAccessoryIcon: #imageLiteral(resourceName: "Icon_ConfirmAppAccessory").precomposed(),
                                               passportPassport: #imageLiteral(resourceName: "Icon_PassportPassport").precomposed(palette.blueIcon, flipVertical: true),
                                               passportIdCardReverse: #imageLiteral(resourceName: "Icon_PassportIdCardReverse").precomposed(palette.blueIcon, flipVertical: true),
                                               passportIdCard: #imageLiteral(resourceName: "Icon_PassportIdCard").precomposed(palette.blueIcon, flipVertical: true),
                                               passportSelfie: #imageLiteral(resourceName: "Icon_PassportSelfie").precomposed(palette.blueIcon, flipVertical: true),
                                               passportDriverLicense: #imageLiteral(resourceName: "Icon_PassportDriverLicense").precomposed(palette.blueIcon, flipVertical: true),
                                               chatOverlayVoiceRecording: #imageLiteral(resourceName: "Icon_RecordingVoice").precomposed(.white),
                                               chatOverlayVideoRecording: #imageLiteral(resourceName: "Icon_RecordVideoMessage").precomposed(.white),
                                               chatOverlaySendRecording: #imageLiteral(resourceName: "Icon_ChatOverlayRecordingSend").precomposed(.white),
                                               chatOverlayLockArrowRecording: #imageLiteral(resourceName: "Icon_DropdownArrow").precomposed(palette.blueIcon, flipVertical: true),
                                               chatOverlayLockerBodyRecording: generateLockerBody(palette.blueIcon, backgroundColor: palette.background),
                                               chatOverlayLockerHeadRecording: generateLockerHead(palette.blueIcon, backgroundColor: palette.background),
                                               locationPin: generateLocationPinIcon(palette.blueIcon),
                                               locationMapPin: generateLocationMapPinIcon(palette.blueIcon),
                                               locationMapLocate: #imageLiteral(resourceName: "Icon_MapLocate").precomposed(palette.grayIcon),
                                               locationMapLocated: #imageLiteral(resourceName: "Icon_MapLocate").precomposed(palette.blueIcon),
                                               chatTabIconSelected: #imageLiteral(resourceName: "Icon_TabChatList_Highlighted").precomposed(palette.blueIcon),
                                               chatTabIconSelectedUp: generateChatTabSelected(palette.blueIcon, #imageLiteral(resourceName: "Icon_ChatListScrollUnread").precomposed(palette.background, flipVertical: true)),
                                               chatTabIconSelectedDown: generateChatTabSelected(palette.blueIcon, #imageLiteral(resourceName: "Icon_ChatListScrollUnread").precomposed(palette.background)),
                                               chatTabIcon: #imageLiteral(resourceName: "Icon_TabChatList").precomposed(palette.grayIcon),
                                               passportSettings: #imageLiteral(resourceName: "Icon_PassportSettings").precomposed(palette.grayIcon),
                                               passportInfo: #imageLiteral(resourceName: "Icon_SettingsBio").precomposed(palette.blueIcon),
                                               editMessageMedia: generateEditMessageMediaIcon(#imageLiteral(resourceName: "Icon_ReplaceMessageMedia").precomposed(palette.blueIcon), background: palette.background),
                                               playerMusicPlaceholder: generatePlayerListAlbumPlaceholder(#imageLiteral(resourceName: "Icon_MusicPlayerSmallAlbumArtPlaceholder").precomposed(palette.blueUI), background: palette.grayForeground, radius: .cornerRadius),
                                               chatMusicPlaceholder: generatePlayerListAlbumPlaceholder(#imageLiteral(resourceName: "Icon_MusicPlayerSmallAlbumArtPlaceholder").precomposed(palette.fileActivityForeground), background: palette.fileActivityBackground, radius: 20),
                                               chatMusicPlaceholderCap: generatePlayerListAlbumPlaceholder(nil, background: palette.fileActivityBackground, radius: 20),
                                               searchArticle: #imageLiteral(resourceName: "Icon_SearchArticles").precomposed(.white),
                                               searchSaved: #imageLiteral(resourceName: "Icon_SearchSaved").precomposed(.white),
                                               hintPeerActive: generateHitActiveIcon(activeColor: palette.blueUI, backgroundColor: palette.background),
                                               chatSwiping_delete: #imageLiteral(resourceName: "Icon_ChatSwipingDelete").precomposed(.white),
                                               chatSwiping_mute: #imageLiteral(resourceName: "Icon_ChatSwipingMute").precomposed(.white),
                                               chatSwiping_unmute: #imageLiteral(resourceName: "Icon_ChatSwipingUnmute").precomposed(.white),
                                               chatSwiping_read: #imageLiteral(resourceName: "Icon_ChatSwipingRead").precomposed(.white),
                                               chatSwiping_unread: #imageLiteral(resourceName: "Icon_ChatSwipingUnread").precomposed(.white),
                                               chatSwiping_pin: #imageLiteral(resourceName: "Icon_ChatSwipingPin").precomposed(.white),
                                               chatSwiping_unpin: #imageLiteral(resourceName: "Icon_ChatSwipingUnpin").precomposed(.white),
                                               galleryPrev: #imageLiteral(resourceName: "Icon_GalleryPrev").precomposed(.white),
                                               galleryNext: #imageLiteral(resourceName: "Icon_GalleryNext").precomposed(.white),
                                               galleryMore: #imageLiteral(resourceName: "Icon_GalleryMore").precomposed(.white),
                                               galleryShare: #imageLiteral(resourceName: "Icon_GalleryShare").precomposed(.white),
                                               galleryFastSave: NSImage(named: "Icon_Gallery_FastSave")!.precomposed(.white),
                                               playingVoice1x: #imageLiteral(resourceName: "Icon_PlayingVoice2x").precomposed(palette.grayIcon),
                                               playingVoice2x: #imageLiteral(resourceName: "Icon_PlayingVoice2x").precomposed(palette.blueIcon),
                                               galleryRotate: NSImage(named: "Icon_GalleryRotate")!.precomposed(.white),
                                               galleryZoomIn: NSImage(named: "Icon_GalleryZoomIn")!.precomposed(.white),
                                               galleryZoomOut: NSImage(named: "Icon_GalleryZoomOut")!.precomposed(.white),
                                               previewSenderCrop: NSImage(named: "Icon_PreviewSenderCrop")!.precomposed(.white),
                                               previewSenderDelete: NSImage(named: "Icon_PreviewSenderDelete")!.precomposed(.white),
                                               editMessageCurrentPhoto: NSImage(named: "Icon_EditMessageCurrentPhoto")!.precomposed(palette.blueIcon),
                                               previewSenderDeleteFile: NSImage(named: "Icon_PreviewSenderDelete")!.precomposed(palette.blueIcon),
                                               previewSenderArchive: NSImage(named: "Icon_PreviewSenderArchive")!.precomposed(palette.grayIcon),
                                               chatSwipeReply: #imageLiteral(resourceName: "Icon_MessageActionPanelForward").precomposed(palette.blueIcon, flipHorizontal: true),
                                               chatSwipeReplyWallpaper: #imageLiteral(resourceName: "Icon_ShareInBubble").precomposed(palette.blueIcon, flipHorizontal: true),
                                               videoPlayerPlay:  NSImage(named: "Icon_VideoPlayer_Play")!.precomposed(.white),
                                               videoPlayerPause: NSImage(named: "Icon_VideoPlayer_Pause")!.precomposed(.white),
                                               videoPlayerEnterFullScreen: NSImage(named: "Icon_VideoPlayer_EnterFullScreen")!.precomposed(.white),
                                               videoPlayerExitFullScreen: NSImage(named: "Icon_VideoPlayer_ExitFullScreen")!.precomposed(.white),
                                               videoPlayerPIPIn: NSImage(named: "Icon_VideoPlayer_PIPIN")!.precomposed(.white),
                                               videoPlayerPIPOut: NSImage(named: "Icon_VideoPlayer_PIPOUT")!.precomposed(.white),
                                               videoPlayerRewind15Forward: NSImage(named: "Icon_VideoPlayer_Rewind15Forward")!.precomposed(.white),
                                               videoPlayerRewind15Backward: NSImage(named: "Icon_VideoPlayer_Rewind15Backward")!.precomposed(.white),
                                               videoPlayerVolume: NSImage(named: "Icon_VideoPlayer_Volume")!.precomposed(.white),
                                               videoPlayerVolumeOff: NSImage(named: "Icon_VideoPlayer_VolumeOff")!.precomposed(.white),
                                               videoPlayerClose: NSImage(named: "Icon_VideoPlayer_Close")!.precomposed(.white),
                                               videoPlayerSliderInteractor: NSImage(named: "Icon_Slider")!.precomposed(),
                                               streamingVideoDownload: NSImage(named: "Icon_StreamingDownload")!.precomposed(.white),
                                               videoCompactFetching: NSImage(named: "Icon_VideoCompactFetching")!.precomposed(.white),
                                               compactStreamingFetchingCancel: NSImage(named: "Icon_CompactStreamingFetchingCancel")!.precomposed(.white),
                                               customLocalizationDelete: NSImage(named: "Icon_MessageActionPanelDelete")!.precomposed(palette.blueIcon),
                                               pollAddOption: generatePollAddOption(palette.blueIcon),
                                               pollDeleteOption: generatePollDeleteOption(palette.redUI),
                                               resort: NSImage(named: "Icon_Resort")!.precomposed(palette.grayIcon.withAlphaComponent(0.6)),
                                               chatPollVoteUnselected: #imageLiteral(resourceName: "Icon_SelectionUncheck").precomposed(palette.grayText.withAlphaComponent(0.3)),
                                               chatPollVoteUnselectedBubble_incoming: #imageLiteral(resourceName: "Icon_SelectionUncheck").precomposed(palette.grayTextBubble_incoming.withAlphaComponent(0.3)),
                                               chatPollVoteUnselectedBubble_outgoing: #imageLiteral(resourceName: "Icon_SelectionUncheck").precomposed(palette.grayTextBubble_outgoing.withAlphaComponent(0.3)),
                                               peerInfoAdmins: NSImage(named: "Icon_ChatAdmins")!.precomposed(flipVertical: true),
                                               peerInfoPermissions: NSImage(named: "Icon_ChatPermissions")!.precomposed(flipVertical: true),
                                               peerInfoBanned: NSImage(named: "Icon_ChatBanned")!.precomposed(flipVertical: true),
                                               peerInfoMembers: NSImage(named: "Icon_ChatMembers")!.precomposed(flipVertical: true),
                                               chatUndoAction: NSImage(named: "Icon_ChatUndoAction")!.precomposed(NSColor(0x29ACFF))
                                               ///videoMessageChatCap: generateVideoMessageChatCap(backgroundColor: palette.background)
    )
}


private func generateTheme(palette: ColorPalette, bubbled: Bool, fontSize: CGFloat, followSystemAppearance: Bool, wallpaper: Wallpaper) -> TelegramPresentationTheme {
    
    let chatList = TelegramChatListTheme(selectedBackgroundColor: palette.blueSelect,
                                         singleLayoutSelectedBackgroundColor: palette.grayBackground,
                                         activeDraggingBackgroundColor: palette.border,
                                         pinnedBackgroundColor: palette.background,
                                         contextMenuBackgroundColor: palette.background,
                                         textColor: palette.text,
                                         grayTextColor: palette.grayText,
                                         secretChatTextColor: bubbled && palette.name == dayClassic.name ? palette.blueIconBubble_outgoing : palette.blueUI,
                                         peerTextColor: palette.text,
                                         activityColor: palette.blueUI,
                                         activitySelectedColor: .white,
                                         activityContextMenuColor: palette.blueUI,
                                         activityPinnedColor: palette.blueUI,
                                         badgeTextColor: palette.background,
                                         badgeBackgroundColor: palette.badge,
                                         badgeSelectedTextColor: palette.blueSelect,
                                         badgeSelectedBackgroundColor: .white,
                                         badgeMutedTextColor: .white,
                                         badgeMutedBackgroundColor: palette.badgeMuted)
    
    let tabBar = TelegramTabBarTheme(color: palette.grayIcon, selectedColor: palette.blueIcon, badgeTextColor: .white, badgeColor: palette.redUI)
    return TelegramPresentationTheme(colors: palette, search: SearchTheme(palette.grayBackground, #imageLiteral(resourceName: "Icon_SearchField").precomposed(palette.grayIcon), #imageLiteral(resourceName: "Icon_SearchClear").precomposed(palette.grayIcon), { L10n.searchFieldSearch }, palette.text, palette.grayText), chatList: chatList, tabBar: tabBar, icons: generateIcons(from: palette, bubbled: bubbled), bubbled: bubbled, fontSize: fontSize, wallpaper: wallpaper, followSystemAppearance: followSystemAppearance)
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
    case dayClassic.name:
        if settings.palette.blueFill.hexString == dayClassic.blueFill.hexString {
            palette = dayClassic
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
    telegramUpdateTheme(generateTheme(palette: palette, bubbled: settings.bubbled, fontSize: settings.fontSize, followSystemAppearance: settings.followSystemAppearance, wallpaper: settings.wallpaper), window: window, animated: animated)
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

            
            let signal = Signal<Void, NoError>.single(Void()) |> delay(0.3, queue: Queue.mainQueue()) |> afterDisposed { [weak imageView] in
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
    telegramUpdateTheme(generateTheme(palette: dayClassic, bubbled: false, fontSize: 13.0, followSystemAppearance: true, wallpaper: .none), window: window, animated: false)
}


