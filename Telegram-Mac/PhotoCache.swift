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


enum ThemeSource : Equatable {
    case local(ColorPalette, TelegramTheme?)
    case cloud(TelegramTheme)
}

private final class PhotoCachedRecord {
    let date:TimeInterval
    let image:CGImage
    let size:Int
    init(image:CGImage, size:Int) {
        self.date = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970
        self.size = size
        self.image = image
    }
}

public final class TransformImageResult {
    let image: CGImage?
    let highQuality: Bool
    init(_ image: CGImage?, _ highQuality: Bool) {
        self.image = image
        self.highQuality = highQuality
    }
    deinit {
        
    }
}

enum AppearanceThumbSource : Int32 {
    case general
    case widget
}

enum PhotoCacheKeyEntry : Hashable {
    case avatar(PeerId, TelegramMediaImageRepresentation, NSSize, CGFloat, Bool)
    case emptyAvatar(PeerId, String, NSColor, NSSize, CGFloat, Bool)
    case media(Media, TransformImageArguments, CGFloat, LayoutPositionFlags?)
    case slot(SlotMachineValue, TransformImageArguments, CGFloat)
    case platformTheme(TelegramThemeSettings, TransformImageArguments, CGFloat, LayoutPositionFlags?)
    case messageId(stableId: Int64, TransformImageArguments, CGFloat, LayoutPositionFlags)
    case theme(ThemeSource, Bool, AppearanceThumbSource)
    case emoji(String, CGFloat)
    func hash(into hasher: inout Hasher) {
        
        switch self {
        case let .avatar(peerId, rep, size, scale, isForum):
            hasher.combine("avatar")
            hasher.combine(rep.resource.id.hashValue)
            hasher.combine(peerId.toInt64())
            hasher.combine(size.width)
            hasher.combine(size.height)
            hasher.combine(scale)
            hasher.combine(isForum)
        case let .emptyAvatar(peerId, letters, color, size, scale, isForum):
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
        }
    }
    
    static func ==(lhs:PhotoCacheKeyEntry, rhs: PhotoCacheKeyEntry) -> Bool {
        switch lhs {
        case let .avatar(lhsPeerId, lhsRepresentation, lhsSize, lhsScale, lhsIsForum):
            if case let .avatar(rhsPeerId, rhsRepresentation, rhsSize, rhsScale, rhsIsForum) = rhs {
                if lhsPeerId != rhsPeerId {
                    return false
                }
                if lhsSize != rhsSize {
                    return false
                }
                if lhsScale != rhsScale {
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
        case let .emptyAvatar(peerId, symbol, color, size, scale, isForum):
            if case .emptyAvatar(peerId, symbol, color, size, scale, isForum) = rhs {
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
        }
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
    
    fileprivate func cacheImage(_ image:CGImage, for key:PhotoCacheKeyEntry) {
        self.values.setObject(PhotoCachedRecord(image: image, size: Int(image.backingSize.width * image.backingSize.height * 4)), forKey: .init(value: key.hashValue))
    }
    
    private func freeMemoryIfNeeded() {
    }
    
    func cachedImage(for key:PhotoCacheKeyEntry) -> CGImage? {
        var image:CGImage? = nil
        image = self.values.object(forKey: .init(value: key.hashValue))?.image
        return image
    }
    
    func removeRecord(for key:PhotoCacheKeyEntry) {
        self.values.removeObject(forKey: .init(value: key.hashValue))
    }
    
    func clearAll() {
        self.values.removeAllObjects()
    }
}


private let peerPhotoCache = PhotoCache(300)
private let photosCache = PhotoCache(300)
private let photoThumbsCache = PhotoCache(500)
private let themeThums = PhotoCache(500)

private let stickersCache = PhotoCache(1000)


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

func cachedPeerPhoto(_ peerId:PeerId, representation: TelegramMediaImageRepresentation, size: NSSize, scale: CGFloat, isForum: Bool) -> Signal<CGImage?, NoError> {
    let entry:PhotoCacheKeyEntry = .avatar(peerId, representation, size, scale, isForum)
    return .single(peerPhotoCache.cachedImage(for: entry))
}

func cachePeerPhoto(image:CGImage, peerId:PeerId, representation: TelegramMediaImageRepresentation, size: NSSize, scale: CGFloat, isForum: Bool) -> Signal <Void, NoError> {
    let entry:PhotoCacheKeyEntry = .avatar(peerId, representation, size, scale, isForum)
    return .single(peerPhotoCache.cacheImage(image, for: entry))
}

func cachedEmptyPeerPhoto(_ peerId:PeerId, symbol: String, color: NSColor, size: NSSize, scale: CGFloat, isForum: Bool) -> Signal<CGImage?, NoError> {
    let entry:PhotoCacheKeyEntry = .emptyAvatar(peerId, symbol, color, size, scale, isForum)
    return .single(peerPhotoCache.cachedImage(for: entry))
}

func cacheEmptyPeerPhoto(image:CGImage, peerId:PeerId, symbol: String, color: NSColor, size: NSSize, scale: CGFloat, isForum: Bool) -> Signal <Void, NoError> {
    let entry:PhotoCacheKeyEntry = .emptyAvatar(peerId, symbol, color, size, scale, isForum)
    return .single(peerPhotoCache.cacheImage(image, for: entry))
}
func cachedPeerPhotoImmediatly(_ peerId:PeerId, representation: TelegramMediaImageRepresentation, size: NSSize, scale: CGFloat, isForum: Bool) -> CGImage? {
    let entry:PhotoCacheKeyEntry = .avatar(peerId, representation, size, scale, isForum)
    return peerPhotoCache.cachedImage(for: entry)
}
func cachedEmptyPeerPhotoImmediatly(_ peerId:PeerId, symbol: String, color: NSColor, size: NSSize, scale: CGFloat, isForum: Bool) -> CGImage? {
    let entry:PhotoCacheKeyEntry = .emptyAvatar(peerId, symbol, color, size, scale, isForum)
    return peerPhotoCache.cachedImage(for: entry)
}

func cachedMedia(media: Media, arguments: TransformImageArguments, scale: CGFloat, positionFlags: LayoutPositionFlags? = nil) -> Signal<TransformImageResult, NoError> {
    let entry:PhotoCacheKeyEntry = .media(media, arguments, scale, positionFlags)
    let value: CGImage?
    var full: Bool = false
    
    if arguments.imageSize.width <= 60, let media = media as? TelegramMediaFile, media.isStaticSticker || media.isAnimatedSticker, let image = stickersCache.cachedImage(for: entry) {
        value = image
        full = true
    } else if let image = photosCache.cachedImage(for: entry) {
        value = image
        full = true
    } else {
        value = photoThumbsCache.cachedImage(for: entry)
    }
    return .single(TransformImageResult(value, full))
}

func cachedSlot(value: SlotMachineValue, arguments: TransformImageArguments, scale: CGFloat) -> Signal<TransformImageResult, NoError> {
    let entry:PhotoCacheKeyEntry = .slot(value, arguments, scale)
    let value: CGImage? = stickersCache.cachedImage(for: entry)
    let full: Bool = value != nil
    
    return .single(TransformImageResult(value, full))
}

func cachedMedia(media: TelegramThemeSettings, arguments: TransformImageArguments, scale: CGFloat, positionFlags: LayoutPositionFlags? = nil) -> Signal<TransformImageResult, NoError> {
    let entry:PhotoCacheKeyEntry = .platformTheme(media, arguments, scale, positionFlags)
    let value: CGImage?
    var full: Bool = false
    
    if let image = photosCache.cachedImage(for: entry) {
        value = image
        full = true
    } else {
        value = nil
    }
    return .single(TransformImageResult(value, full))
}

func cachedMedia(messageId: Int64, arguments: TransformImageArguments, scale: CGFloat, positionFlags: LayoutPositionFlags? = nil) -> Signal<TransformImageResult, NoError> {
    let entry:PhotoCacheKeyEntry = .messageId(stableId: messageId, arguments, scale, positionFlags ?? [])
    let value: CGImage?
    var full: Bool = false
    if let image = photosCache.cachedImage(for: entry) {
        value = image
        full = true
    } else {
        value = photoThumbsCache.cachedImage(for: entry)
    }
    return .single(TransformImageResult(value, full))
}

func cacheMedia(_ result: TransformImageResult, media: Media, arguments: TransformImageArguments, scale: CGFloat, positionFlags: LayoutPositionFlags? = nil) -> Void {
    if let image = result.image {
        let entry:PhotoCacheKeyEntry = .media(media, arguments, scale, positionFlags)
        if arguments.imageSize.width <= 60, result.highQuality, let media = media as? TelegramMediaFile,  media.isStaticSticker || media.isAnimatedSticker {
            stickersCache.cacheImage(image, for: entry)
        } else if !result.highQuality {
            photoThumbsCache.cacheImage(image, for: entry)
        } else {
            photosCache.cacheImage(image, for: entry)
        }
    }
}

func cacheSlot(_ result: TransformImageResult, value: SlotMachineValue, arguments: TransformImageArguments, scale: CGFloat) -> Void {
    if let image = result.image {
        stickersCache.cacheImage(image, for: .slot(value, arguments, scale))
    }
}

func cacheEmoji(_ image: CGImage, emoji: String, scale: CGFloat) -> Void {
    stickersCache.cacheImage(image, for: .emoji(emoji, scale))
}
func cachedEmoji(emoji: String, scale: CGFloat) -> CGImage? {
    return stickersCache.cachedImage(for: .emoji(emoji, scale))
}

func cacheMedia(_ result: TransformImageResult, media: TelegramThemeSettings, arguments: TransformImageArguments, scale: CGFloat, positionFlags: LayoutPositionFlags? = nil) -> Void {
    if let image = result.image {
        let entry:PhotoCacheKeyEntry = .platformTheme(media, arguments, scale, positionFlags)
        photosCache.cacheImage(image, for: entry)
    }
}



func cacheMedia(_ result: TransformImageResult, messageId: Int64, arguments: TransformImageArguments, scale: CGFloat, positionFlags: LayoutPositionFlags? = nil) -> Void {
    
    if let image = result.image {
        let entry:PhotoCacheKeyEntry = .messageId(stableId: messageId, arguments, scale, positionFlags ?? [])
        if !result.highQuality {
            photoThumbsCache.cacheImage(image, for: entry)
        } else {
            photosCache.cacheImage(image, for: entry)
        }
    }
}

func cachedThemeThumb(source: ThemeSource, bubbled: Bool, thumbSource: AppearanceThumbSource = .general) -> Signal<TransformImageResult, NoError> {
    let entry:PhotoCacheKeyEntry = .theme(source, bubbled, thumbSource)
    let value: CGImage?
    var full: Bool = false
    if let image = themeThums.cachedImage(for: entry) {
        value = image
        full = true
    } else {
        value = themeThums.cachedImage(for: entry)
    }
    if value == nil {
        var bp:Int = 0
        bp += 1
    }
    return .single(TransformImageResult(value, full))
}

func cacheThemeThumb(_ result: TransformImageResult, source: ThemeSource, bubbled: Bool, thumbSource: AppearanceThumbSource = .general) -> Void {
    let entry:PhotoCacheKeyEntry = .theme(source, bubbled, thumbSource)
    
    if let image = result.image {
        if !result.highQuality {
            themeThums.cacheImage(image, for: entry)
        } else {
            themeThums.cacheImage(image, for: entry)
        }
    }
}
