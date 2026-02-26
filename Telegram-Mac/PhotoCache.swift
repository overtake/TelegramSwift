//
//  PhotoCache.swift
//  Telegram
//
//  Created by keepcoder on 14/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import TelegramCore
import ColorPalette
import Postbox
import TGUIKit
import ThemeSettings

enum ThemeSource : Equatable {
    case local(ColorPalette, TelegramTheme?)
    case cloud(TelegramTheme)
}

private final class PhotoCachedRecord {
    let date:TimeInterval
    let image:CGImage
    let sampleBuffer: CMSampleBuffer?
    let size:Int
    init(image:CGImage, sampleBuffer: CMSampleBuffer?, size:Int) {
        self.sampleBuffer = sampleBuffer
        self.date = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970
        self.size = size
        self.image = image
    }
}

private final class WallpaperCachedRecord {
    let date:TimeInterval
    let mode:TableBackgroundMode
    init(mode:TableBackgroundMode) {
        self.date = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970
        self.mode = mode
    }
}


enum AppearanceThumbSource : Int32 {
    case general
    case widget
}

enum PhotoCacheKeyEntry : Hashable {
    case avatar(PeerId, TelegramMediaImageRepresentation, PeerNameColor?, NSSize, CGFloat, Bool, Bool)
    case emptyAvatar(PeerId, String, NSColor, NSSize, CGFloat, Bool, Bool)
    case media(Media, TransformImageArguments, CGFloat, LayoutPositionFlags?)
    case slot(SlotMachineValue, TransformImageArguments, CGFloat)
    case platformTheme(TelegramThemeSettings, TransformImageArguments, CGFloat, LayoutPositionFlags?)
    case background(Wallpaper, ColorPalette)
    case messageId(stableId: Int64, TransformImageArguments, CGFloat, LayoutPositionFlags)
    case theme(ThemeSource, Bool, AppearanceThumbSource)
    case emoji(String, CGFloat)
    func hash(into hasher: inout Hasher) {
        
        switch self {
        case let .avatar(peerId, rep, nameColor, size, scale, isForum, isMonoforum):
            hasher.combine("avatar")
            hasher.combine(rep.resource.id.hashValue)
            hasher.combine(peerId.toInt64())
            hasher.combine(size.width)
            hasher.combine(size.height)
            hasher.combine(scale)
            hasher.combine(isForum)
            hasher.combine(isMonoforum)
            if let nameColor = nameColor {
                hasher.combine("nameColor")
                hasher.combine(nameColor.rawValue)
            }
        case let .emptyAvatar(peerId, letters, color, size, scale, isForum, isMonoforum):
            hasher.combine("emptyAvatar")
            hasher.combine(peerId.toInt64())
            hasher.combine(color.hashValue)
            hasher.combine(letters)
            hasher.combine(size.width)
            hasher.combine(size.height)
            hasher.combine(scale)
            hasher.combine(isForum)
        case let .media(media, transform, scale, layout):
            hasher.combine("media")
            
            if let media = media as? TelegramMediaMap {
                hasher.combine(media.longitude)
                hasher.combine(media.latitude)
            }
            
            if let media = media as? TelegramMediaFile {
                hasher.combine(media.resource.id.stringRepresentation)
                if let size = media.resource.size {
                    hasher.combine(size)
                }
                #if !SHARE
                if let fitz = media.animatedEmojiFitzModifier {
                    hasher.combine(fitz.rawValue)
                }
                #endif
            }
            if let media = media.id {
                hasher.combine(media.id)
            }
            hasher.combine(transform)
            if let layout = layout {
                hasher.combine(layout.rawValue)
            }
            hasher.combine(scale)
        case let .slot(slot, transform, scale):
            hasher.combine("slot")
            hasher.combine(slot)
            hasher.combine(transform)
            hasher.combine(scale)
        case let .messageId(stableId, transform, scale, layout):
            hasher.combine("messageId")
            hasher.combine(stableId)
            hasher.combine(transform)
            hasher.combine(scale)
            hasher.combine(layout.rawValue)
        case let .theme(source, bubbled, thumbSource):
            hasher.combine(bubbled)
            
            switch source {
            case let .local(palette, cloud):
                hasher.combine("theme-local")
                if let settings = cloud?.effectiveSettings(for: palette) {
                    #if !SHARE
                    hasher.combine(palette.name)
                    hasher.combine(settings.desc)
                    hasher.combine(thumbSource.rawValue)
                    #endif
                } else {
                    hasher.combine(palette.name)
                    hasher.combine(palette.accent.argb)
                    hasher.combine(thumbSource.rawValue)
                }
            case let .cloud(cloud):
                hasher.combine("theme-local")
                hasher.combine(cloud.id)
                if let file = cloud.file {
                    hasher.combine(file.fileId.id)
                }
                hasher.combine(thumbSource.rawValue)
            }
        case let .platformTheme(settings, arguments, scale, layout):
            hasher.combine("platformTheme")
            #if !SHARE
            hasher.combine(settings.desc)
            hasher.combine(scale)
            hasher.combine(arguments)
            if let layout = layout {
                hasher.combine(layout.rawValue)
            }
            #endif
        case let .emoji(emoji, scale):
            hasher.combine("emoji")
            hasher.combine(emoji)
            hasher.combine(scale)
        case let .background(wallpaper, palette):
            hasher.combine("wallpaper")
            hasher.combine(palette.toString)
            switch wallpaper {
            case .none:
                hasher.combine("none")
            case .builtin:
                hasher.combine("builtin")
            case let .color(color):
                hasher.combine("color")
                hasher.combine("\(color)")
            case let .custom(rep, blurred):
                hasher.combine("custom")
                hasher.combine("\(rep.resource.id.hashValue)")
                hasher.combine("\(blurred)")
            case let .emoticon(emoticon):
                hasher.combine("emoticon")
                hasher.combine("\(emoticon)")
            case let .file(slug, file, settings, isPattern):
                hasher.combine("file")
                hasher.combine("\(slug)")
                hasher.combine("\(file.fileId.id)")
                hasher.combine("\(settings.colors)")
                hasher.combine("\(settings.blur)")
                hasher.combine("\(settings.motion)")
                hasher.combine("\(String(describing: settings.rotation))")
                hasher.combine("\(isPattern)")
            case let .image(reps, settings):
                hasher.combine("image")
                for rep in reps {
                    hasher.combine("\(rep.resource.id.hashValue)")
                }
                hasher.combine("\(settings.colors)")
                hasher.combine("\(settings.blur)")
                hasher.combine("\(settings.motion)")
                hasher.combine("\(String(describing: settings.rotation))")
            case let .gradient(id, colors, rotation):
                hasher.combine("gradient")
                hasher.combine("\(String(describing: id))")
                hasher.combine("\(colors)")
                hasher.combine("\(String(describing: rotation))")
            }
        }
    }
    
    static func ==(lhs:PhotoCacheKeyEntry, rhs: PhotoCacheKeyEntry) -> Bool {
        switch lhs {
        case let .avatar(lhsPeerId, lhsRepresentation, lhsNameColor, lhsSize, lhsScale, lhsIsForum, lhsIsMonoforum):
            if case let .avatar(rhsPeerId, rhsRepresentation, rhsNameColor, rhsSize, rhsScale, rhsIsForum, rhsIsMonoforum) = rhs {
                if lhsPeerId != rhsPeerId {
                    return false
                }
                if lhsSize != rhsSize {
                    return false
                }
                if lhsScale != rhsScale {
                    return false
                }
                if lhsNameColor != rhsNameColor {
                    return false
                }
                if lhsIsMonoforum != rhsIsMonoforum {
                    return false
                }
                if lhsRepresentation.resource.id == rhsRepresentation.resource.id  {
                    return false
                }
                if lhsIsForum != rhsIsForum {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .emptyAvatar(peerId, symbol, color, size, scale, isForum, isMonoforum):
            if case .emptyAvatar(peerId, symbol, color, size, scale, isForum, isMonoforum) = rhs {
                return true
            } else {
                return false
            }
        case let .media(lhsMedia, lhsSize, lhsScale, lhsPositionFlags):
            if case let .media(rhsMedia, rhsSize, rhsScale, rhsPositionFlags) = rhs {
                if lhsMedia.id != rhsMedia.id {
                    return false
                }
                if let lhsMedia = lhsMedia as? TelegramMediaMap, let rhsMedia = rhsMedia as? TelegramMediaMap {
                    if lhsMedia.latitude != rhsMedia.latitude || lhsMedia.longitude != rhsMedia.longitude {
                        return false
                    }
                }
                if lhsSize != rhsSize {
                    return false
                }
                if lhsPositionFlags != rhsPositionFlags {
                    return false
                }
                if lhsScale != rhsScale {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .slot(value, size, scale):
            if case .slot(value, size, scale) = rhs {
                return true
            } else {
                return false
            }
        case let .messageId(stableId, size, scale, positionFlags):
            if case .messageId(stableId, size, scale, positionFlags) = rhs {
                return true
            } else {
                return false
            }
        case let .theme(source, bubbled, thumbSource):
            if case .theme(source, bubbled, thumbSource) = rhs {
                return true
            } else {
                return false
            }
        case let .platformTheme(settings, arguments, scale, position):
            if case .platformTheme(settings, arguments, scale, position) = rhs {
                return true
            } else {
                return false
            }
        case let .emoji(emoji, scale):
            if case .emoji(emoji, scale) = rhs {
                return true
            } else {
                return false
            }
        case let .background(wallpaper, colors):
            if case .background(wallpaper, colors) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}


private class WallpaperCache {
    let memoryLimit:Int
    let maxCount:Int = 50
    private var values:NSCache<NSNumber, WallpaperCachedRecord> = NSCache()
    
    init(_ memoryLimit:Int = 100) {
        self.memoryLimit = memoryLimit
        self.values.countLimit = memoryLimit
    }
    
    fileprivate func cacheImage(_ mode: TableBackgroundMode, for key:PhotoCacheKeyEntry) {
        self.values.setObject(WallpaperCachedRecord(mode: mode), forKey: .init(value: key.hashValue))
    }
    
    private func freeMemoryIfNeeded() {
    }
    
    func cachedImage(for key:PhotoCacheKeyEntry) -> TableBackgroundMode? {
        return self.values.object(forKey: .init(value: key.hashValue))?.mode
    }
    
    func removeRecord(for key:PhotoCacheKeyEntry) {
        self.values.removeObject(forKey: .init(value: key.hashValue))
    }
    
    func clearAll() {
        self.values.removeAllObjects()
    }
}


private class PhotoCache {
    let memoryLimit:Int
    let maxCount:Int = 50
    private var values:NSCache<NSNumber, PhotoCachedRecord> = NSCache()
    
    init(_ memoryLimit:Int = 100) {
        self.memoryLimit = memoryLimit
        self.values.countLimit = memoryLimit
    }
    
    fileprivate func cacheImage(_ image:CGImage, sampleBuffer: CMSampleBuffer?, for key:PhotoCacheKeyEntry) {
        self.values.setObject(PhotoCachedRecord(image: image, sampleBuffer: sampleBuffer, size: Int(image.backingSize.width * image.backingSize.height * 4)), forKey: .init(value: key.hashValue))
    }
    
    private func freeMemoryIfNeeded() {
    }
    
    func cachedImage(for key:PhotoCacheKeyEntry) -> (CGImage, CMSampleBuffer?)? {
        let result = self.values.object(forKey: .init(value: key.hashValue))
        if let result = result {
            return (result.image, result.sampleBuffer)
        } else {
            return nil
        }
    }
    
    func removeRecord(for key:PhotoCacheKeyEntry) {
        self.values.removeObject(forKey: .init(value: key.hashValue))
    }
    
    func clearAll() {
        self.values.removeAllObjects()
    }
}


private let peerPhotoCache = PhotoCache(200)
private let photosCache = PhotoCache(200)
private let photoThumbsCache = PhotoCache(200)
private let themeThums = PhotoCache(200)
private let wallpaperCache = WallpaperCache(20)

private let stickersCache = PhotoCache(200)
private let emojiCache = PhotoCache(10000)


func clearImageCache() -> Signal<Void, NoError> {
    return Signal<Void, NoError> { subscriber -> Disposable in
        photosCache.clearAll()
        photoThumbsCache.clearAll()
        peerPhotoCache.clearAll()
        subscriber.putNext(Void())
        subscriber.putCompletion()
        return EmptyDisposable
    }
}

func cachedPeerPhoto(_ peerId:PeerId, representation: TelegramMediaImageRepresentation, peerNameColor: PeerNameColor?, size: NSSize, scale: CGFloat, isForum: Bool, isMonoforum: Bool) -> Signal<CGImage?, NoError> {
    let entry:PhotoCacheKeyEntry = .avatar(peerId, representation, peerNameColor, size, scale, isForum, isMonoforum)
    return .single(peerPhotoCache.cachedImage(for: entry)?.0)
}

func cachePeerPhoto(image:CGImage, peerId:PeerId, representation: TelegramMediaImageRepresentation, peerNameColor: PeerNameColor?, size: NSSize, scale: CGFloat, isForum: Bool, isMonoforum: Bool) -> Signal <Void, NoError> {
    let entry:PhotoCacheKeyEntry = .avatar(peerId, representation, peerNameColor, size, scale, isForum, isMonoforum)
    return .single(peerPhotoCache.cacheImage(image, sampleBuffer: nil, for: entry))
}

func cachedEmptyPeerPhoto(_ peerId:PeerId, symbol: String, color: NSColor, size: NSSize, scale: CGFloat, isForum: Bool, isMonoforum: Bool) -> Signal<CGImage?, NoError> {
    let entry:PhotoCacheKeyEntry = .emptyAvatar(peerId, symbol, color, size, scale, isForum, isMonoforum)
    return .single(peerPhotoCache.cachedImage(for: entry)?.0)
}

func cacheEmptyPeerPhoto(image:CGImage, peerId:PeerId, symbol: String, color: NSColor, size: NSSize, scale: CGFloat, isForum: Bool, isMonoforum: Bool) -> Signal <Void, NoError> {
    let entry:PhotoCacheKeyEntry = .emptyAvatar(peerId, symbol, color, size, scale, isForum, isMonoforum)
    return .single(peerPhotoCache.cacheImage(image, sampleBuffer: nil, for: entry))
}
func cachedPeerPhotoImmediatly(_ peerId:PeerId, representation: TelegramMediaImageRepresentation, peerNameColor: PeerNameColor?, size: NSSize, scale: CGFloat, isForum: Bool, isMonoforum: Bool) -> CGImage? {
    let entry:PhotoCacheKeyEntry = .avatar(peerId, representation, peerNameColor, size, scale, isForum, isMonoforum)
    return peerPhotoCache.cachedImage(for: entry)?.0
}
func cachedEmptyPeerPhotoImmediatly(_ peerId:PeerId, symbol: String, color: NSColor, size: NSSize, scale: CGFloat, isForum: Bool, isMonoforum: Bool) -> CGImage? {
    let entry:PhotoCacheKeyEntry = .emptyAvatar(peerId, symbol, color, size, scale, isForum, isMonoforum)
    return peerPhotoCache.cachedImage(for: entry)?.0
}

func cachedMedia(media: Media, arguments: TransformImageArguments, scale: CGFloat, positionFlags: LayoutPositionFlags? = nil) -> Signal<TransformImageResult?, NoError> {
    let entry:PhotoCacheKeyEntry = .media(media, arguments, scale, positionFlags)
    let value: (CGImage, CMSampleBuffer?)?
    var full: Bool = false
    
    if arguments.imageSize.width <= 60, let media = media as? TelegramMediaFile, media.isStaticSticker || media.isAnimatedSticker {
        value = stickersCache.cachedImage(for: entry)
        full = true
    } else if let image = photosCache.cachedImage(for: entry) {
        value = image
        full = true
    } else {
        value = photoThumbsCache.cachedImage(for: entry)
    }
    if let value = value {
        return .single(TransformImageResult(value.0, full, value.1))
    } else {
        return .single(nil)
    }
}

func cachedSlot(value: SlotMachineValue, arguments: TransformImageArguments, scale: CGFloat) -> Signal<TransformImageResult?, NoError> {
    let entry:PhotoCacheKeyEntry = .slot(value, arguments, scale)
    let value: CGImage? = stickersCache.cachedImage(for: entry)?.0
    let full: Bool = value != nil
    if let value = value {
        return .single(TransformImageResult(value, full))
    } else {
        return .single(nil)
    }
}

func cachedMedia(media: TelegramThemeSettings, arguments: TransformImageArguments, scale: CGFloat, positionFlags: LayoutPositionFlags? = nil) -> Signal<TransformImageResult?, NoError> {
    let entry:PhotoCacheKeyEntry = .platformTheme(media, arguments, scale, positionFlags)
    let value: (CGImage, CMSampleBuffer?)?
    var full: Bool = false
    
    if let image = photosCache.cachedImage(for: entry) {
        value = image
        full = true
    } else {
        value = nil
    }
    if let value = value {
        return .single(TransformImageResult(value.0, full, value.1))
    } else {
        return .single(nil)
    }
}

func cachedMedia(messageId: Int64, arguments: TransformImageArguments, scale: CGFloat, positionFlags: LayoutPositionFlags? = nil) -> Signal<TransformImageResult?, NoError> {
    let entry:PhotoCacheKeyEntry = .messageId(stableId: messageId, arguments, scale, positionFlags ?? [])
    let value: (CGImage, CMSampleBuffer?)?
    var full: Bool = false
    if let image = photosCache.cachedImage(for: entry) {
        value = image
        full = true
    } else {
        value = photoThumbsCache.cachedImage(for: entry)
    }
    if let value = value {
        return .single(TransformImageResult(value.0, full, value.1))
    } else {
        return .single(nil)
    }
}

func cacheMedia(_ result: TransformImageResult, media: Media, arguments: TransformImageArguments, scale: CGFloat, positionFlags: LayoutPositionFlags? = nil) -> Void {
    if let image = result.image {
        let entry:PhotoCacheKeyEntry = .media(media, arguments, scale, positionFlags)
        if arguments.imageSize.width <= 60, result.highQuality, let media = media as? TelegramMediaFile,  media.isStaticSticker || media.isAnimatedSticker {
            stickersCache.cacheImage(image, sampleBuffer: result.sampleBuffer, for: entry)
        } else if !result.highQuality {
            photoThumbsCache.cacheImage(image, sampleBuffer: result.sampleBuffer, for: entry)
        } else {
            photosCache.cacheImage(image, sampleBuffer: result.sampleBuffer, for: entry)
        }
    }
}

func cacheSlot(_ result: TransformImageResult, value: SlotMachineValue, arguments: TransformImageArguments, scale: CGFloat) -> Void {
    if let image = result.image {
        stickersCache.cacheImage(image, sampleBuffer: nil, for: .slot(value, arguments, scale))
    }
}

func cacheEmoji(_ image: CGImage, emoji: String, scale: CGFloat) -> Void {
    emojiCache.cacheImage(image, sampleBuffer: nil, for: .emoji(emoji, scale))
}
func cachedEmoji(emoji: String, scale: CGFloat) -> CGImage? {
    return emojiCache.cachedImage(for: .emoji(emoji, scale))?.0
}

func cacheMedia(_ result: TransformImageResult, media: TelegramThemeSettings, arguments: TransformImageArguments, scale: CGFloat, positionFlags: LayoutPositionFlags? = nil) -> Void {
    if let image = result.image {
        let entry:PhotoCacheKeyEntry = .platformTheme(media, arguments, scale, positionFlags)
        photosCache.cacheImage(image, sampleBuffer: result.sampleBuffer, for: entry)
    }
}


func cacheBackground(_ result: Wallpaper, palette: ColorPalette, background: TableBackgroundMode) -> Void {
    let entry:PhotoCacheKeyEntry = .background(result, palette)
    wallpaperCache.cacheImage(background, for: entry)
}
func cachedBackground(_ wallpaper: Wallpaper, palette: ColorPalette) -> TableBackgroundMode? {
    return wallpaperCache.cachedImage(for: .background(wallpaper, palette))
}


func cacheMedia(_ result: TransformImageResult, messageId: Int64, arguments: TransformImageArguments, scale: CGFloat, positionFlags: LayoutPositionFlags? = nil) -> Void {
    
    if let image = result.image {
        let entry:PhotoCacheKeyEntry = .messageId(stableId: messageId, arguments, scale, positionFlags ?? [])
        if !result.highQuality {
            photoThumbsCache.cacheImage(image, sampleBuffer: result.sampleBuffer, for: entry)
        } else {
            photosCache.cacheImage(image, sampleBuffer: result.sampleBuffer, for: entry)
        }
    }
}

func cachedThemeThumb(source: ThemeSource, bubbled: Bool, thumbSource: AppearanceThumbSource = .general) -> Signal<TransformImageResult?, NoError> {
    let entry:PhotoCacheKeyEntry = .theme(source, bubbled, thumbSource)
    let value: (CGImage, CMSampleBuffer?)?
    var full: Bool = false
    if let image = themeThums.cachedImage(for: entry) {
        value = image
        full = true
    } else {
        value = themeThums.cachedImage(for: entry)
    }
    if let value = value {
        return .single(TransformImageResult(value.0, full, value.1))
    } else {
        return .single(nil)
    }
}

func cacheThemeThumb(_ result: TransformImageResult, source: ThemeSource, bubbled: Bool, thumbSource: AppearanceThumbSource = .general) -> Void {
    let entry:PhotoCacheKeyEntry = .theme(source, bubbled, thumbSource)
    
    if let image = result.image {
        if !result.highQuality {
            themeThums.cacheImage(image, sampleBuffer: result.sampleBuffer, for: entry)
        } else {
            themeThums.cacheImage(image, sampleBuffer: result.sampleBuffer, for: entry)
        }
    }
}
