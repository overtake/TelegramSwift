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
import ColorPalette




private extension PeerNameColors.Colors {
    init?(colors: EngineAvailableColorOptions.MultiColorPack) {
        if colors.colors.isEmpty {
            return nil
        }
        let secondary: NSColor?
        let tertiary: NSColor?
        
        let main = NSColor(rgb: colors.colors[0])
        if colors.colors.count > 1 {
            secondary = NSColor(rgb: colors.colors[1])
        } else {
            secondary = nil
        }
        if colors.colors.count > 2 {
            tertiary = NSColor(rgb: colors.colors[2])
        } else {
            tertiary = nil
        }
        self.init(main: main, secondary: secondary, tertiary: tertiary)
    }
}


extension PeerNameColors {
    
    public func get(_ color: PeerNameColor, dark: Bool = false) -> Colors {
        if dark, let colors = self.darkColors[color.rawValue] {
            return colors
        } else if let colors = self.colors[color.rawValue] {
            return colors
        } else {
            return PeerNameColors.defaultSingleColors[5]!
        }
    }
    
    public func getProfile(_ color: PeerNameColor, dark: Bool = false, subject: Subject = .background) -> Colors {
        switch subject {
        case .background:
            if dark, let colors = self.profileDarkColors[color.rawValue] {
                return colors
            } else if let colors = self.profileColors[color.rawValue] {
                return colors
            } else {
                return Colors(main: NSColor(rgb: 0xcc5049))
            }
        case .palette:
            if dark, let colors = self.profilePaletteDarkColors[color.rawValue] {
                return colors
            } else if let colors = self.profilePaletteColors[color.rawValue] {
                return colors
            } else {
                return self.getProfile(color, dark: dark, subject: .background)
            }
        case .stories:
            if dark, let colors = self.profileStoryDarkColors[color.rawValue] {
                return colors
            } else if let colors = self.profileStoryColors[color.rawValue] {
                return colors
            } else {
                return self.getProfile(color, dark: dark, subject: .background)
            }
        }
    }
    
    public static func with(availableReplyColors: EngineAvailableColorOptions, availableProfileColors: EngineAvailableColorOptions) -> PeerNameColors {
        var colors: [Int32: Colors] = [:]
        var darkColors: [Int32: Colors] = [:]
        var displayOrder: [Int32] = []
        var profileColors: [Int32: Colors] = [:]
        var profileDarkColors: [Int32: Colors] = [:]
        var profilePaletteColors: [Int32: Colors] = [:]
        var profilePaletteDarkColors: [Int32: Colors] = [:]
        var profileStoryColors: [Int32: Colors] = [:]
        var profileStoryDarkColors: [Int32: Colors] = [:]
        var profileDisplayOrder: [Int32] = []
        
        var nameColorsChannelMinRequiredBoostLevel: [Int32: Int32] = [:]
        var nameColorsGroupMinRequiredBoostLevel: [Int32: Int32] = [:]
        
        if !availableReplyColors.options.isEmpty {
            for option in availableReplyColors.options {
                if let requiredChannelMinBoostLevel = option.value.requiredChannelMinBoostLevel {
                    nameColorsChannelMinRequiredBoostLevel[option.key] = requiredChannelMinBoostLevel
                }
                if let requiredGroupMinBoostLevel = option.value.requiredGroupMinBoostLevel {
                    nameColorsGroupMinRequiredBoostLevel[option.key] = requiredGroupMinBoostLevel
                }
                
                if let parsedLight = PeerNameColors.Colors(colors: option.value.light.background) {
                    colors[option.key] = parsedLight
                }
                if let parsedDark = (option.value.dark?.background).flatMap(PeerNameColors.Colors.init(colors:)) {
                    darkColors[option.key] = parsedDark
                }
                
                for option in availableReplyColors.options {
                    if !displayOrder.contains(option.key) {
                        displayOrder.append(option.key)
                    }
                }
            }
        } else {
            let defaultValue = PeerNameColors.defaultValue
            colors = defaultValue.colors
            darkColors = defaultValue.darkColors
            displayOrder = defaultValue.displayOrder
        }
            
        if !availableProfileColors.options.isEmpty {
            for option in availableProfileColors.options {
                if let parsedLight = PeerNameColors.Colors(colors: option.value.light.background) {
                    profileColors[option.key] = parsedLight
                }
                if let parsedDark = (option.value.dark?.background).flatMap(PeerNameColors.Colors.init(colors:)) {
                    profileDarkColors[option.key] = parsedDark
                }
                if let parsedPaletteLight = PeerNameColors.Colors(colors: option.value.light.palette) {
                    profilePaletteColors[option.key] = parsedPaletteLight
                }
                if let parsedPaletteDark = (option.value.dark?.palette).flatMap(PeerNameColors.Colors.init(colors:)) {
                    profilePaletteDarkColors[option.key] = parsedPaletteDark
                }
                if let parsedStoryLight = (option.value.light.stories).flatMap(PeerNameColors.Colors.init(colors:)) {
                    profileStoryColors[option.key] = parsedStoryLight
                }
                if let parsedStoryDark = (option.value.dark?.stories).flatMap(PeerNameColors.Colors.init(colors:)) {
                    profileStoryDarkColors[option.key] = parsedStoryDark
                }
                for option in availableProfileColors.options {
                    if !profileDisplayOrder.contains(option.key) {
                        profileDisplayOrder.append(option.key)
                    }
                }
            }
        }
        
        return PeerNameColors(
            colors: colors,
            darkColors: darkColors,
            displayOrder: displayOrder,
            profileColors: profileColors,
            profileDarkColors: profileDarkColors,
            profilePaletteColors: profilePaletteColors,
            profilePaletteDarkColors: profilePaletteDarkColors,
            profileStoryColors: profileStoryColors,
            profileStoryDarkColors: profileStoryDarkColors,
            profileDisplayOrder: profileDisplayOrder,
            nameColorsChannelMinRequiredBoostLevel: nameColorsChannelMinRequiredBoostLevel,
            nameColorsGroupMinRequiredBoostLevel: nameColorsGroupMinRequiredBoostLevel
        )
    }
}




let graphicsThreadPool = ThreadPool(threadCount: 5, threadPriority: 1)

enum PeerPhoto {
    case peer(Peer, TelegramMediaImageRepresentation?, PeerNameColor?, [String], Message?, CGFloat?)
    case topic(EngineMessageHistoryThread.Info, Bool)
}

private let capHolder:Atomic<[String : CGImage]> = Atomic(value: [:])

private func peerImage(account: Account, peer: Peer, displayDimensions: NSSize, representation: TelegramMediaImageRepresentation?, message: Message? = nil, displayLetters: [String], font: NSFont, scale: CGFloat, genCap: Bool, synchronousLoad: Bool, disableForum: Bool = false, cornerRadius: CGFloat? = nil) -> Signal<(CGImage?, Bool), NoError> {
    
    let isForum: Bool = peer.isForumOrMonoForum && !disableForum
    let isMonoforum: Bool = peer.isMonoForum
    
    if isMonoforum {
        var bp = 0
        bp += 1
    }
    
    if let representation = representation {
        return cachedPeerPhoto(peer.id, representation: representation, peerNameColor: nil, size: displayDimensions, scale: scale, isForum: isForum, isMonoforum: isMonoforum) |> mapToSignal { cached -> Signal<(CGImage?, Bool), NoError> in
            return autoreleasepool {
                if let cached = cached {
                    return cachePeerPhoto(image: cached, peerId: peer.id, representation: representation, peerNameColor: nil, size: displayDimensions, scale: scale, isForum: isForum, isMonoforum: isMonoforum) |> map {
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
                                           fetchedDataDisposable = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .peer(peer.id), userContentType: .avatar, reference: MediaResourceReference.messageAuthorAvatar(message: MessageReference(message), resource: representation.resource), statsCategory: .image).start()
                                        } else if let reference = PeerReference(peer) {
                                            fetchedDataDisposable = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .peer(peer.id), userContentType: .avatar, reference: MediaResourceReference.avatar(peer: reference, resource: representation.resource), statsCategory: .image).start()
                                       } else {
                                           fetchedDataDisposable = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .peer(peer.id), userContentType: .avatar, reference: MediaResourceReference.standalone(resource: representation.resource), statsCategory: .image).start()
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
                            let image = generateAvatarPlaceholder(foregroundColor: theme.colors.grayBackground, size: size, cornerRadius: isForum ? floor(size.height / 3) : (cornerRadius ?? -1), bubble: isMonoforum)
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
                            image = roundImage(data, displayDimensions, cornerRadius: isForum ? displayDimensions.width / 3 : (cornerRadius ?? -1), scale: scale, bubble: isMonoforum)
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
                            return cachePeerPhoto(image: image, peerId: peer.id, representation: representation, peerNameColor: nil, size: displayDimensions, scale: scale, isForum: isForum, isMonoforum: isMonoforum) |> map {
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
        
        //peer.nameColor?.index ??
        let number = peer.nameColor.flatMap { Int64($0.rawValue) } ?? peer.id.id._internalGetInt64Value()
        let index = Int(abs(number % 7))
        let color = theme.colors.peerColors(index)

        
        let symbol = letters.reduce("", { (current, letter) -> String in
            return current + letter
        })
        
        return cachedEmptyPeerPhoto(peer.id, symbol: symbol, color: color.top, size: displayDimensions, scale: scale, isForum: isForum, isMonoforum: isMonoforum) |> mapToSignal { cached -> Signal<(CGImage?, Bool), NoError> in
            if let cached = cached {
                return .single((cached, false))
            } else {
                return generateEmptyPhoto(displayDimensions, type: .peer(colors: color, letter: letters, font: font, cornerRadius: isForum ? floor(displayDimensions.height / 3) : nil), bubble: isMonoforum) |> runOn(graphicsThreadPool) |> mapToSignal { image -> Signal<(CGImage?, Bool), NoError> in
                    if let image = image {
                        return cacheEmptyPeerPhoto(image: image, peerId: peer.id, symbol: symbol, color: color.top, size: displayDimensions, scale: scale, isForum: isForum, isMonoforum: isMonoforum) |> map {
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

func peerAvatarImage(account: Account, photo: PeerPhoto, displayDimensions: CGSize = CGSize(width: 60.0, height: 60.0), scale:CGFloat = 1.0, font:NSFont = .medium(17), genCap: Bool = true, synchronousLoad: Bool = false, disableForum: Bool = false) -> Signal<(CGImage?, Bool), NoError> {
   
    switch photo {
    case let .peer(peer, representation, peerNameColor, displayLetters, message, cornerRadius):
        return peerImage(account: account, peer: peer, displayDimensions: displayDimensions, representation: representation, message: message, displayLetters: displayLetters, font: font, scale: scale, genCap: genCap, synchronousLoad: synchronousLoad, disableForum: disableForum, cornerRadius: cornerRadius)
    case let .topic(info, isGeneral):
        #if !SHARE
      
        let file: Signal<TelegramMediaFile, NoError>
        
        if let fileId = info.icon {
            file = TelegramEngine(account: account).stickers.resolveInlineStickers(fileIds: [fileId]) |> map {
                return $0[fileId]
            }
            |> filter { $0 != nil }
            |> map { $0! }
        } else {
            file = .single(ForumUI.makeIconFile(title: info.title, iconColor: info.iconColor, isGeneral: isGeneral))
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
            case "bundle/jpeg":
                if let resource = file.resource as? LocalBundleResource {
                    signal = makeGeneralTopicIcon(resource)
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

func generateEmptyPhoto(_ displayDimensions:NSSize, type: EmptyAvatartType, bubble: Bool) -> Signal<CGImage?, NoError> {
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
                if let cornerRadius = cornerRadius {
                    ctx.round(size, cornerRadius)
                } else {
                    ctx.round(size, size.height / 2)
                }
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
                
                ctx.translateBy(x: floorToScreenPixels(size.width / 2.0), y: floorToScreenPixels(size.height / 2.0))
                ctx.scaleBy(x: 1.0, y: 1.0)
                ctx.translateBy(x: -floorToScreenPixels(size.width / 2.0), y: -floorToScreenPixels(size.height / 2.0))
                //
                ctx.translateBy(x: lineOrigin.x, y: lineOrigin.y)
                CTLineDraw(line, ctx)
                ctx.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)
            }
            
            if let icon = icon, let iconSize = iconSize {
                let rect = NSMakeRect(floorToScreenPixels((displayDimensions.width - iconSize.width)/2), floorToScreenPixels((displayDimensions.height - iconSize.height)/2), iconSize.width, iconSize.height)
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
        
        //peer.nameColor?.index ??
        let number = peer.nameColor.flatMap { Int64($0.rawValue) } ?? peer.id.id._internalGetInt64Value()
        let index = Int(abs(number % 7))
        
        let color = theme.colors.peerColors(index)
        
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
