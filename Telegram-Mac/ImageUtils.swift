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

/*
 @[TGColorWithHex(0xff516a), TGColorWithHex(0xff885e)],
 @[TGColorWithHex(0xffa85c), TGColorWithHex(0xffcd6a)],
 @[TGColorWithHex(0x54cb68), TGColorWithHex(0xa0de7e)],
 @[TGColorWithHex(0x2a9ef1), TGColorWithHex(0x72d5fd)],
 @[TGColorWithHex(0x665fff), TGColorWithHex(0x82b1ff)],
 @[TGColorWithHex(0xd669ed), TGColorWithHex(0xe0a2f3)],
 */

private let colors: [(top: NSColor, bottom: NSColor)] = [
    (NSColor(0xff516a), NSColor(0xff885e)),
    (NSColor(0xffa85c), NSColor(0xffcd6a)),
    (NSColor(0x54cb68), NSColor(0xa0de7e)),
    (NSColor(0x2a9ef1), NSColor(0x72d5fd)),
    (NSColor(0x665fff), NSColor(0x82b1ff)),
    (NSColor(0xd669ed), NSColor(0xe0a2f3))
]

public func peerAvatarImage(account: Account, peer: Peer, displayDimensions: CGSize = CGSize(width: 60.0, height: 60.0), scale:CGFloat = 1.0, font:NSFont = .medium(.title)) -> Signal<CGImage?, NoError>? {
    if let smallProfileImage = peer.smallProfileImage {
        
        return cachedPeerPhoto(peer.id, representation: smallProfileImage, size: displayDimensions, scale: scale) |> mapToSignal { cached -> Signal<CGImage?, Void> in
            if let cached = cached {
                return .single(cached)
            } else {
                let resourceData = account.postbox.mediaBox.resourceData(smallProfileImage.resource)
                let imageData = resourceData
                    |> take(1)
                    |> mapToSignal { maybeData -> Signal<Data?, NoError> in
                        if maybeData.complete {
                            return .single(try? Data(contentsOf: URL(fileURLWithPath: maybeData.path)))
                        } else {
                            return Signal { subscriber in
                                let resourceDataDisposable = resourceData.start(next: { data in
                                    if data.complete {
                                        subscriber.putNext(try? Data(contentsOf: URL(fileURLWithPath: maybeData.path)))
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
                return imageData
                    |> deliverOn(account.graphicsThreadPool)
                    |> mapToSignal { data -> Signal<CGImage?, Void> in
                        
                        let image:CGImage?
                        if let data = data {
                            image = roundImage(data, displayDimensions, scale:scale)
                        } else {
                            image = nil
                        }
                        if let image = image {
                            return cachePeerPhoto(image: image, peerId: peer.id, representation: smallProfileImage, size: displayDimensions, scale: scale) |> map {
                                return image
                            }
                        } else {
                            return .single(image)
                        }
                        
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
        
        let colorIndex: Int32
        if peer.id.namespace == Namespaces.Peer.CloudUser {
            colorIndex = colorIndexForUid(peer.id.id, account.peerId.id)
        } else if peer.id.namespace == Namespaces.Peer.CloudChannel {
            colorIndex = colorIndexForGroupId(TGPeerIdFromChannelId(peer.id.id))
        } else {
            colorIndex = colorIndexForGroupId(-Int64(peer.id.id))
        }
        let color = colors[abs(Int(colorIndex % 6))]
        
        
        let symbol = letters.reduce("", { (current, letter) -> String in
            return current + letter
        })
        
        return cachedEmptyPeerPhoto(peer.id, symbol: symbol, color: color.top, size: displayDimensions, scale: scale) |> mapToSignal { cached -> Signal<CGImage?, Void> in
            if let cached = cached {
                return .single(cached)
            } else {
                return generateEmptyPhoto(displayDimensions, type: .peer(colors: color, letter: letters, font: font)) |> runOn(account.graphicsThreadPool) |> mapToSignal { image -> Signal<CGImage?, Void> in
                    if let image = image {
                        return cacheEmptyPeerPhoto(image: image, peerId: peer.id, symbol: symbol, color: color.top, size: displayDimensions, scale: scale) |> map {
                            return image
                        }
                    } else {
                        return .single(image)
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
            let gradient = CGGradient(colorsSpace: colorSpace, colors: NSArray(array: [color.bottom.cgColor, color.top.cgColor]), locations: &locations)!
            
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
        
        let colorIndex: Int32
        if peer.id.namespace == Namespaces.Peer.CloudUser {
            colorIndex = colorIndexForUid(peer.id.id, account.peerId.id)
        } else if peer.id.namespace == Namespaces.Peer.CloudChannel {
            colorIndex = colorIndexForGroupId(TGPeerIdFromChannelId(peer.id.id))
        } else {
            colorIndex = colorIndexForGroupId(-Int64(peer.id.id))
        }
        let color = colors[abs(Int(colorIndex % 6))]
        
        let image = generateImage(displayDimensions, contextGenerator: { (size, ctx) in
            ctx.clear(NSMakeRect(0, 0, size.width, size.height))
            
            var locations: [CGFloat] = [1.0, 0.2];
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: NSArray(array: [color.bottom.cgColor, color.top.cgColor]), locations: &locations)!
            
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
