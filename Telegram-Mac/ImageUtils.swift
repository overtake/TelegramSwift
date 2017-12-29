//
//  ImageUtils.swift
//  TelegramMac
//
//  Created by keepcoder on 18/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac
import TGUIKit



public func peerAvatarImage(account: Account, peer: Peer, displayDimensions: CGSize = CGSize(width: 60.0, height: 60.0), scale:CGFloat = 1.0, font:NSFont = .medium(.title), genCap: Bool = true) -> Signal<(CGImage?, Bool), NoError>? {
    if let smallProfileImage = peer.smallProfileImage {
        
        return cachedPeerPhoto(peer.id, representation: smallProfileImage, size: displayDimensions, scale: scale) |> mapToSignal { cached -> Signal<(CGImage?, Bool), Void> in
            if let cached = cached {
                return .single((cached, false))
            } else {
                let resourceData = account.postbox.mediaBox.resourceData(smallProfileImage.resource)
                let imageData = resourceData
                    |> take(1)
                    |> mapToSignal { maybeData -> Signal<(Data?, Bool), NoError> in
                        if maybeData.complete {
                            return .single((try? Data(contentsOf: URL(fileURLWithPath: maybeData.path)), false))
                        } else {
                            return Signal { subscriber in
                                let resourceDataDisposable = resourceData.start(next: { data in
                                    if data.complete {
                                        subscriber.putNext((try? Data(contentsOf: URL(fileURLWithPath: maybeData.path)), true))
                                        subscriber.putCompletion()
                                    }
                                }, error: { error in
                                    subscriber.putError(error)
                                }, completed: {
                                    subscriber.putCompletion()
                                })
                                let fetchedDataDisposable = account.postbox.mediaBox.fetchedResource(smallProfileImage.resource, tag: TelegramMediaResourceFetchTag(statsCategory: .image)).start()
                                return ActionDisposable {
                                    resourceDataDisposable.dispose()
                                    fetchedDataDisposable.dispose()
                                }
                            }
                        }
                }
                
                let def = deferred({ () -> Signal<(CGImage?, Bool), Void> in
                    return .single((generateAvatarPlaceholder(foregroundColor: theme.colors.grayBackground, size: displayDimensions), false))
                }) |> deliverOn(account.graphicsThreadPool)
                
                
                let img = imageData
                    |> deliverOn(account.graphicsThreadPool)
                    |> mapToSignal { data, animated -> Signal<(CGImage?, Bool), Void> in
                        
                        let image:CGImage?
                        if let data = data {
                            image = roundImage(data, displayDimensions, scale:scale)
                        } else {
                            image = nil
                        }
                        if let image = image {
                            return cachePeerPhoto(image: image, peerId: peer.id, representation: smallProfileImage, size: displayDimensions, scale: scale) |> map {
                                return (image, animated)
                            }
                        } else {
                            return .single((image, animated))
                        }
                        
                    }
                if genCap {
                    return def |> then(img)
                } else {
                    return img
                }
            }
        }
        
    } else {
        
        var letters = peer.displayLetters
        if letters.count < 2 {
            while letters.count != 2 {
                letters.append("")
            }
        }
        
        
        let color = theme.colors.peerColors(Int(abs(peer.id.id % 7)))
        
        
        let symbol = letters.reduce("", { (current, letter) -> String in
            return current + letter
        })
        
        return cachedEmptyPeerPhoto(peer.id, symbol: symbol, color: color.top, size: displayDimensions, scale: scale) |> mapToSignal { cached -> Signal<(CGImage?, Bool), Void> in
            if let cached = cached {
                return .single((cached, false))
            } else {
                return generateEmptyPhoto(displayDimensions, type: .peer(colors: color, letter: letters, font: font)) |> runOn(account.graphicsThreadPool) |> mapToSignal { image -> Signal<(CGImage?, Bool), Void> in
                    if let image = image {
                        return cacheEmptyPeerPhoto(image: image, peerId: peer.id, symbol: symbol, color: color.top, size: displayDimensions, scale: scale) |> map {
                            return (image, false)
                        }
                    } else {
                        return .single((image, false))
                    }
                }
            }
        }
        
    }
}

enum EmptyAvatartType {
    case peer(colors:(top:NSColor, bottom: NSColor), letter: [String], font: NSFont)
    case icon(colors:(top:NSColor, bottom: NSColor), icon: CGImage, iconSize: NSSize)
}

func generateEmptyPhoto(_ displayDimensions:NSSize, type: EmptyAvatartType) -> Signal<CGImage?, Void> {
    return Signal { subscriber in
        
        let color:(top: NSColor, bottom: NSColor)
        let letters: [String]?
        let icon: CGImage?
        let iconSize: NSSize?
        let font: NSFont?
        switch type {
        case let .icon(colors, _icon, _iconSize):
            color = colors
            icon = _icon
            letters = nil
            font = nil
            iconSize = _iconSize
        case let .peer(colors, _letters, _font):
            color = colors
            icon = nil
            font = _font
            letters = _letters
            iconSize = nil
        }
        
        let image = generateImage(displayDimensions, contextGenerator: { (size, ctx) in
            ctx.clear(NSMakeRect(0, 0, size.width, size.height))
            
            ctx.clear(NSMakeRect(0, 0, size.width, size.height))
            ctx.beginPath()
            ctx.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height:
                size.height))
            ctx.clip()
            
            var locations: [CGFloat] = [1.0, 0.2];
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: NSArray(array: [color.top.cgColor, color.bottom.cgColor]), locations: &locations)!
            
            ctx.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
            
            ctx.setBlendMode(.normal)
            
            if let letters = letters, let font = font {
                let string = letters.count == 0 ? "" : (letters[0] + (letters.count == 1 ? "" : letters[1]))
                let attributedString = NSAttributedString(string: string, attributes: [NSAttributedStringKey.font: font, NSAttributedStringKey.foregroundColor: NSColor.white])
                
                let line = CTLineCreateWithAttributedString(attributedString)
                let lineBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
                
                let lineOrigin = CGPoint(x: floorToScreenPixels(-lineBounds.origin.x + (size.width - lineBounds.size.width) / 2.0) , y: floorToScreenPixels(-lineBounds.origin.y + (size.height - lineBounds.size.height) / 2.0))
                
                ctx.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                ctx.scaleBy(x: 1.0, y: 1.0)
                ctx.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                //
                ctx.translateBy(x: lineOrigin.x, y: lineOrigin.y)
                CTLineDraw(line, ctx)
                ctx.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)
            }
            
            if let icon = icon, let iconSize = iconSize {
                let rect = NSMakeRect((displayDimensions.width - iconSize.width)/2, (displayDimensions.height - iconSize.height)/2, iconSize.width, iconSize.height)
                ctx.draw(icon, in: rect)
            }
            
        })
        subscriber.putNext(image)
        subscriber.putCompletion()
        return EmptyDisposable
    }
}

func generateEmptyRoundAvatar(_ displayDimensions:NSSize, font: NSFont, account:Account, peer:Peer) -> Signal<CGImage?, Void> {
    return Signal { subscriber in
        let letters = peer.displayLetters
        
        let color = theme.colors.peerColors(Int(abs(peer.id.id % 7)))
        
        let image = generateImage(displayDimensions, contextGenerator: { (size, ctx) in
            ctx.clear(NSMakeRect(0, 0, size.width, size.height))
            
            var locations: [CGFloat] = [1.0, 0.2];
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: NSArray(array: [color.top.cgColor, color.bottom.cgColor]), locations: &locations)!
            
            ctx.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
            
            ctx.setBlendMode(.normal)
            
            let letters = letters
            let string = letters.count == 0 ? "" : (letters[0] + (letters.count == 1 ? "" : letters[1]))
            let attributedString = NSAttributedString(string: string, attributes: [NSAttributedStringKey.font: font, NSAttributedStringKey.foregroundColor: NSColor.white])
            
            let line = CTLineCreateWithAttributedString(attributedString)
            let lineBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            
            let lineOrigin = CGPoint(x: floorToScreenPixels(-lineBounds.origin.x + (size.width - lineBounds.size.width) / 2.0) , y: floorToScreenPixels(-lineBounds.origin.y + (size.height - lineBounds.size.height) / 2.0))
            
            ctx.translateBy(x: size.width / 2.0, y: size.height / 2.0)
            ctx.scaleBy(x: 1.0, y: 1.0)
            ctx.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            //
            ctx.translateBy(x: lineOrigin.x, y: lineOrigin.y)
            CTLineDraw(line, ctx)
            ctx.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)
        })
        subscriber.putNext(image)
        subscriber.putCompletion()
        return EmptyDisposable
    }
    
    
}
