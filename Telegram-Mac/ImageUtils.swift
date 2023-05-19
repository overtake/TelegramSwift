//
//  ImageUtils.swift
//  TelegramMac
//
//  Created by keepcoder on 18/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import TelegramCore
import FastBlur
import SwiftSignalKit
import TGUIKit
import FastBlur

let graphicsThreadPool = ThreadPool(threadCount: 5, threadPriority: 1)

enum PeerPhoto {
    case peer(Peer, TelegramMediaImageRepresentation?, [String], Message?)
    case topic(EngineMessageHistoryThread.Info)
}

private let capHolder:Atomic<[String : CGImage]> = Atomic(value: [:])

private func peerImage(account: Account, peer: Peer, displayDimensions: NSSize, representation: TelegramMediaImageRepresentation?, message: Message? = nil, displayLetters: [String], font: NSFont, scale: CGFloat, genCap: Bool, synchronousLoad: Bool) -> Signal<(CGImage?, Bool), NoError> {
    
    let isForum: Bool = peer.isForum
    
    if let representation = representation {
        return cachedPeerPhoto(peer.id, representation: representation, size: displayDimensions, scale: scale, isForum: isForum) |> mapToSignal { cached -> Signal<(CGImage?, Bool), NoError> in
            return autoreleasepool {
                if let cached = cached {
                    return cachePeerPhoto(image: cached, peerId: peer.id, representation: representation, size: displayDimensions, scale: scale, isForum: isForum) |> map {
                        return (cached, false)
                    }
                } else {
                    let resourceData = account.postbox.mediaBox.resourceData(representation.resource, attemptSynchronously: synchronousLoad)
                    let imageData = resourceData
                        |> take(1)
                        |> mapToSignal { maybeData -> Signal<(Data?, Bool, Bool), NoError> in
                            return autoreleasepool {
                               if maybeData.complete {
                                   return .single((try? Data(contentsOf: URL(fileURLWithPath: maybeData.path)), false, false))
                               } else {
                                   return Signal { subscriber in
                                                
                                       if let data = representation.immediateThumbnailData {
                                           subscriber.putNext((decodeTinyThumbnail(data: data), false, true))
                                       }
                                    
                                       let resourceData = account.postbox.mediaBox.resourceData(representation.resource, attemptSynchronously: synchronousLoad)
                                    
                                       let resourceDataDisposable = resourceData.start(next: { data in
                                           if data.complete {
                                               subscriber.putNext((try? Data(contentsOf: URL(fileURLWithPath: data.path)), true, false))
                                               subscriber.putCompletion()
                                           } 
                                       }, completed: {
                                           subscriber.putCompletion()
                                       })
                                       
                                       let fetchedDataDisposable: Disposable
                                       if let message = message, message.author?.id == peer.id {
                                            fetchedDataDisposable = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: MediaResourceReference.messageAuthorAvatar(message: MessageReference(message), resource: representation.resource), statsCategory: .image).start()
                                        } else if let reference = PeerReference(peer) {
                                           fetchedDataDisposable = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: MediaResourceReference.avatar(peer: reference, resource: representation.resource), statsCategory: .image).start()
                                       } else {
                                           fetchedDataDisposable = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: MediaResourceReference.standalone(resource: representation.resource), statsCategory: .image).start()
                                       }
                                       return ActionDisposable {
                                           resourceDataDisposable.dispose()
                                           fetchedDataDisposable.dispose()
                                       }
                                   }
                               }
                            }
                    }
                    
                    let def = deferred({ () -> Signal<(CGImage?, Bool), NoError> in
                        let key = NSStringFromSize(displayDimensions)
                        if let image = capHolder.with({ $0[key] }) {
                            return .single((image, false))
                        } else {
                            let size = NSMakeSize(max(15, displayDimensions.width), max(15, displayDimensions.height))
                            let image = generateAvatarPlaceholder(foregroundColor: theme.colors.grayBackground, size: size, cornerRadius: isForum ? floor(size.height / 3) : -1)
                            _ = capHolder.modify { current in
                                var current = current
                                current[key] = image
                                return current
                            }
                            return .single((image, false))
                        }
                    }) |> deliverOnMainQueue
                    
                    let loadDataSignal = synchronousLoad ? imageData : imageData |> deliverOn(graphicsThreadPool)
                    
                    let img = loadDataSignal |> mapToSignal { data, animated, tiny -> Signal<(CGImage?, Bool), NoError> in
                            
                        var image:CGImage?
                        if let data = data {
                            image = roundImage(data, displayDimensions, cornerRadius: isForum ? displayDimensions.width / 3 : -1, scale: scale)
                        } else {
                            image = nil
                        }
                        #if !SHARE
                        if tiny, let img = image {
                            let size = img.size
                            let ctx = DrawingContext(size: img.size, scale: 1.0)
                            ctx.withContext { ctx in
                                ctx.clear(size.bounds)
                                ctx.draw(img, in: size.bounds)
                            }
                            telegramFastBlurMore(Int32(size.width), Int32(size.height), Int32(ctx.bytesPerRow), ctx.bytes)
                            
                            let rounded = DrawingContext(size: img.size, scale: 1.0)
                            rounded.withContext { c in
                                c.clear(size.bounds)
                                c.round(size, isForum ? min(floor(size.height / 3), size.height / 2) : size.height / 2)
                                c.clear(size.bounds)
                                c.draw(ctx.generateImage()!, in: size.bounds)
                            }
                            
                            image = rounded.generateImage()//ctx.generateImage()
                        }
                        #endif
                        if let image = image {
                            if tiny {
                                return .single((image, animated))
                            }
                            return cachePeerPhoto(image: image, peerId: peer.id, representation: representation, size: displayDimensions, scale: scale, isForum: isForum) |> map {
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
        }
        
    } else {
        
        var letters = displayLetters
        if letters.count < 2 {
            while letters.count != 2 {
                letters.append("")
            }
        }
        
        
        let color = theme.colors.peerColors(Int(abs(peer.id.id._internalGetInt64Value() % 7)))
        
        
        let symbol = letters.reduce("", { (current, letter) -> String in
            return current + letter
        })
        
        return cachedEmptyPeerPhoto(peer.id, symbol: symbol, color: color.top, size: displayDimensions, scale: scale, isForum: isForum) |> mapToSignal { cached -> Signal<(CGImage?, Bool), NoError> in
            if let cached = cached {
                return .single((cached, false))
            } else {
                return generateEmptyPhoto(displayDimensions, type: .peer(colors: color, letter: letters, font: font, cornerRadius: isForum ? floor(displayDimensions.height / 3) : nil)) |> runOn(graphicsThreadPool) |> mapToSignal { image -> Signal<(CGImage?, Bool), NoError> in
                    if let image = image {
                        return cacheEmptyPeerPhoto(image: image, peerId: peer.id, symbol: symbol, color: color.top, size: displayDimensions, scale: scale, isForum: isForum) |> map {
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

func peerAvatarImage(account: Account, photo: PeerPhoto, displayDimensions: CGSize = CGSize(width: 60.0, height: 60.0), scale:CGFloat = 1.0, font:NSFont = .medium(17), genCap: Bool = true, synchronousLoad: Bool = false) -> Signal<(CGImage?, Bool), NoError> {
   
    switch photo {
    case let .peer(peer, representation, displayLetters, message):
        return peerImage(account: account, peer: peer, displayDimensions: displayDimensions, representation: representation, message: message, displayLetters: displayLetters, font: font, scale: scale, genCap: genCap, synchronousLoad: synchronousLoad)
    case let .topic(info):
        #if !SHARE
      
        let file: Signal<TelegramMediaFile, NoError>
        
        if let fileId = info.icon {
            file = TelegramEngine(account: account).stickers.resolveInlineStickers(fileIds: [fileId]) |> map {
                return $0[fileId]
            }
            |> filter { $0 != nil }
            |> map { $0! }
        } else {
            file = .single(ForumUI.makeIconFile(title: info.title, iconColor: info.iconColor))
        }
        
        return file |> mapToSignal { file in
            let reference = FileMediaReference.standalone(media: file)
            let signal:Signal<ImageDataTransformation, NoError>
            
            let emptyColor: TransformImageEmptyColor?
            if isDefaultStatusesPackId(file.emojiReference) {
                emptyColor = .fill(theme.colors.accent)
            } else {
                emptyColor = nil
            }
            
            let aspectSize = file.dimensions?.size.aspectFilled(displayDimensions) ?? displayDimensions
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: aspectSize, boundingSize: displayDimensions, intrinsicInsets: NSEdgeInsets(), emptyColor: emptyColor)
            
            switch file.mimeType {
            case "image/webp":
                signal = chatMessageSticker(postbox: account.postbox, file: reference, small: false, scale: System.backingScale, fetched: true)
            case "bundle/topic":
                if let resource = file.resource as? ForumTopicIconResource {
                    signal = makeTopicIcon(resource.title, bgColors: resource.bgColors, strokeColors: resource.strokeColors)
                } else {
                    signal = .complete()
                }
            default:
                signal = chatMessageAnimatedSticker(postbox: account.postbox, file: reference, small: false, scale: System.backingScale, size: aspectSize, fetched: true, thumbAtFrame: 0, isVideo: file.fileName == "webm-preview" || file.isVideoSticker)
            }
            return signal |> map { data -> (CGImage?, Bool) in
                let context = data.execute(arguments, data.data)
                let image = context?.generateImage()
                return (image, true)
            }
        }
        #else
        return .complete()
        #endif
    }
}

/*

 */

enum EmptyAvatartType {
    case peer(colors:(top:NSColor, bottom: NSColor), letter: [String], font: NSFont, cornerRadius: CGFloat?)
    case icon(colors:(top:NSColor, bottom: NSColor), icon: CGImage, iconSize: NSSize, cornerRadius: CGFloat?)
}

func generateEmptyPhoto(_ displayDimensions:NSSize, type: EmptyAvatartType) -> Signal<CGImage?, NoError> {
    return Signal { subscriber in
        
        let color:(top: NSColor, bottom: NSColor)
        let letters: [String]?
        let icon: CGImage?
        let iconSize: NSSize?
        let font: NSFont?
        let cornerRadius: CGFloat?
        switch type {
        case let .icon(colors, _icon, _iconSize, _cornerRadius):
            color = colors
            icon = _icon
            letters = nil
            font = nil
            iconSize = _iconSize
            cornerRadius = _cornerRadius
        case let .peer(colors, _letters, _font, _cornerRadius):
            color = colors
            icon = nil
            font = _font
            letters = _letters
            iconSize = nil
            cornerRadius = _cornerRadius
        }
        
        let image = generateImage(displayDimensions, contextGenerator: { (size, ctx) in
            ctx.clear(NSMakeRect(0, 0, size.width, size.height))
            
            if let cornerRadius = cornerRadius {
                ctx.round(size, cornerRadius)
            } else {
                ctx.round(size, size.height / 2)
            }
            //ctx.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height:
             //   size.height))
           // ctx.clip()
            
            var locations: [CGFloat] = [1.0, 0.2];
            let colorSpace = deviceColorSpace
            let gradient = CGGradient(colorsSpace: colorSpace, colors: NSArray(array: [color.top.cgColor, color.bottom.cgColor]), locations: &locations)!
            
            ctx.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
            
            ctx.setBlendMode(.normal)
            
            if let letters = letters, let font = font {
                let string = letters.count == 0 ? "" : (letters[0] + (letters.count == 1 ? "" : letters[1]))
                let attributedString = NSAttributedString(string: string, attributes: [NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: NSColor.white])
                
                let line = CTLineCreateWithAttributedString(attributedString)
                let lineBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
                
                let lineOrigin = CGPoint(x: floorToScreenPixels(System.backingScale, -lineBounds.origin.x + (size.width - lineBounds.size.width) / 2.0) , y: floorToScreenPixels(System.backingScale, -lineBounds.origin.y + (size.height - lineBounds.size.height) / 2.0))
                
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

func generateEmptyRoundAvatar(_ displayDimensions:NSSize, font: NSFont, account:Account, peer:Peer) -> Signal<CGImage?, NoError> {
    return Signal { subscriber in
        let letters = peer.displayLetters
        
        let color = theme.colors.peerColors(Int(abs(peer.id.id._internalGetInt64Value() % 7)))
        
        let image = generateImage(displayDimensions, contextGenerator: { (size, ctx) in
            ctx.clear(NSMakeRect(0, 0, size.width, size.height))
            
            var locations: [CGFloat] = [1.0, 0.2];
            let colorSpace = deviceColorSpace
            let gradient = CGGradient(colorsSpace: colorSpace, colors: NSArray(array: [color.top.cgColor, color.bottom.cgColor]), locations: &locations)!
            
            ctx.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
            
            ctx.setBlendMode(.normal)
            
            let letters = letters
            let string = letters.count == 0 ? "" : (letters[0] + (letters.count == 1 ? "" : letters[1]))
            let attributedString = NSAttributedString(string: string, attributes: [NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: NSColor.white])
            
            let line = CTLineCreateWithAttributedString(attributedString)
            let lineBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            
            let lineOrigin = CGPoint(x: floorToScreenPixels(System.backingScale, -lineBounds.origin.x + (size.width - lineBounds.size.width) / 2.0) , y: floorToScreenPixels(System.backingScale, -lineBounds.origin.y + (size.height - lineBounds.size.height) / 2.0))
            
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
