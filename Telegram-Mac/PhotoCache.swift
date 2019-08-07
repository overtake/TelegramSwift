//
//  PhotoCache.swift
//  Telegram
//
//  Created by keepcoder on 14/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac
import TGUIKit

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


private enum PhotoCacheKeyEntry : Hashable {
    case avatar(PeerId, TelegramMediaImageRepresentation, NSSize, CGFloat)
    case emptyAvatar(PeerId, String, NSColor, NSSize, CGFloat)
    case media(Media, TransformImageArguments, CGFloat, LayoutPositionFlags?)
    case messageId(stableId: Int64, TransformImageArguments, CGFloat, LayoutPositionFlags)
    var hashValue:Int {
        switch self {
        case let .avatar(peerId, _, _, _):
            return peerId.id.hashValue
        case let .emptyAvatar(peerId, _, _, _, _):
            return peerId.id.hashValue
        case let .messageId(stableId, _, _, _):
            return stableId.hashValue
        case let .media(media, _, _, _):
            return media.id?.id.hashValue ?? 0
        }
    }
    
    var stringValue: NSString {
        switch self {
        case let .avatar(peerId, rep, size, scale):
            return "avatar-\(peerId.toInt64())-\(rep.resource.id.hashValue)-\(size.width)-\(size.height)-\(scale)".nsstring
        case let .emptyAvatar(peerId, letters, color, size, scale):
            return "emptyAvatar-\(peerId.toInt64())-\(letters)-\(color.hexString)-\(size.width)-\(size.height)-\(scale)".nsstring
        case let .media(media, transform, scale, layout):
            var addition: String = ""
            if let media = media as? TelegramMediaMap {
                addition = "\(media.longitude)-\(media.latitude)"
            }
            if let media = media as? TelegramMediaFile {
                addition += "\(media.resource.id.uniqueId)-\(String(describing: media.resource.size))"
            }
            return "media-\(String(describing: media.id?.id))-\(transform.imageSize.width)-\(transform.imageSize.height)-\(transform.boundingSize.width)-\(transform.boundingSize.height)-\(scale)-\(String(describing: layout?.rawValue))-\(addition)".nsstring
        case let .messageId(stableId, transform, scale, layout):
            return "messageId-\(stableId)-\(transform.imageSize.width)-\(transform.imageSize.height)-\(transform.boundingSize.width)-\(transform.boundingSize.height)-\(scale)-\(layout.rawValue)".nsstring
        }
    }
    
    static func ==(lhs:PhotoCacheKeyEntry, rhs: PhotoCacheKeyEntry) -> Bool {
        switch lhs {
        case let .avatar(lhsPeerId, lhsRepresentation, lhsSize, lhsScale):
            if case let .avatar(rhsPeerId, rhsRepresentation, rhsSize, rhsScale) = rhs {
                if lhsPeerId != rhsPeerId {
                    return false
                }
                if lhsSize != rhsSize {
                    return false
                }
                if lhsScale != rhsScale {
                    return false
                }
                if !lhsRepresentation.resource.id.isEqual(to: rhsRepresentation.resource.id)  {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .emptyAvatar(peerId, symbol, color, size, scale):
            if case .emptyAvatar(peerId, symbol, color, size, scale) = rhs {
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
        case let .messageId(stableId, size, scale, positionFlags):
            if case .messageId(stableId, size, scale, positionFlags) = rhs {
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
    private var values:NSCache<NSString, PhotoCachedRecord> = NSCache()
    
    init(_ memoryLimit:Int = 15) {
        self.memoryLimit = memoryLimit
        self.values.countLimit = memoryLimit
    }
    
    fileprivate func cacheImage(_ image:CGImage, for key:PhotoCacheKeyEntry) {
        self.values.setObject(PhotoCachedRecord(image: image, size: Int(image.backingSize.width * image.backingSize.height * 4)), forKey: key.stringValue)
    }
    
    private func freeMemoryIfNeeded() {
    }
    
    func cachedImage(for key:PhotoCacheKeyEntry) -> CGImage? {
        var image:CGImage? = nil
        image = self.values.object(forKey: key.stringValue)?.image
        return image
    }
    
    func removeRecord(for key:PhotoCacheKeyEntry) {
        self.values.removeObject(forKey: key.stringValue)
    }
    
    func clearAll() {
        self.values.removeAllObjects()
    }
}


private let peerPhotoCache = PhotoCache()
private let photosCache = PhotoCache(50)
private let photoThumbsCache = PhotoCache(50)

private let stickersCache = PhotoCache(500)


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

func cachedPeerPhoto(_ peerId:PeerId, representation: TelegramMediaImageRepresentation, size: NSSize, scale: CGFloat) -> Signal<CGImage?, NoError> {
    let entry:PhotoCacheKeyEntry = .avatar(peerId, representation, size, scale)
    return .single(peerPhotoCache.cachedImage(for: entry))
}

func cachePeerPhoto(image:CGImage, peerId:PeerId, representation: TelegramMediaImageRepresentation, size: NSSize, scale: CGFloat) -> Signal <Void, NoError> {
    let entry:PhotoCacheKeyEntry = .avatar(peerId, representation, size, scale)
    return .single(peerPhotoCache.cacheImage(image, for: entry))
}

func cachedEmptyPeerPhoto(_ peerId:PeerId, symbol: String, color: NSColor, size: NSSize, scale: CGFloat) -> Signal<CGImage?, NoError> {
    let entry:PhotoCacheKeyEntry = .emptyAvatar(peerId, symbol, color, size, scale)
    return .single(peerPhotoCache.cachedImage(for: entry))
}

func cacheEmptyPeerPhoto(image:CGImage, peerId:PeerId, symbol: String, color: NSColor, size: NSSize, scale: CGFloat) -> Signal <Void, NoError> {
    let entry:PhotoCacheKeyEntry = .emptyAvatar(peerId, symbol, color, size, scale)
    return .single(peerPhotoCache.cacheImage(image, for: entry))
}
func cachedPeerPhotoImmediatly(_ peerId:PeerId, representation: TelegramMediaImageRepresentation, size: NSSize, scale: CGFloat) -> CGImage? {
    let entry:PhotoCacheKeyEntry = .avatar(peerId, representation, size, scale)
    return peerPhotoCache.cachedImage(for: entry)
}
func cachedEmptyPeerPhotoImmediatly(_ peerId:PeerId, symbol: String, color: NSColor, size: NSSize, scale: CGFloat) -> CGImage? {
    let entry:PhotoCacheKeyEntry = .emptyAvatar(peerId, symbol, color, size, scale)
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

