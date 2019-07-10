//
//  CachedResourceRepresentations.swift
//  Telegram-Mac
//
//  Created by keepcoder on 24/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

import PostboxMac
import SwiftSignalKitMac
import TelegramCoreMac

final class CachedStickerAJpegRepresentation: CachedMediaResourceRepresentation {
    let size: CGSize?
    var keepDuration: CachedMediaRepresentationKeepDuration = .general
    var uniqueId: String {
        if let size = self.size {
            return "sticker-v1-png-\(Int(size.width))x\(Int(size.height))"
        } else {
            return "sticker-v1-png"
        }
    }
    
    init(size: CGSize?) {
        self.size = size
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedStickerAJpegRepresentation {
            return self.size == to.size
        } else {
            return false
        }
    }
}

class CachedScaledImageRepresentation: CachedMediaResourceRepresentation {
    let size: CGSize
    var keepDuration: CachedMediaRepresentationKeepDuration = .general
    var uniqueId: String {
        return "scaled-image-\(Int(self.size.width))x\(Int(self.size.height))"
    }
    
    init(size: CGSize) {
        self.size = size
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedScaledImageRepresentation {
            return self.size == to.size
        } else {
            return false
        }
    }
}



final class CachedVideoFirstFrameRepresentation: CachedMediaResourceRepresentation {
    var keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    var uniqueId: String {
        return "first-frame"
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if to is CachedVideoFirstFrameRepresentation {
            return true
        } else {
            return false
        }
    }
}

final class CachedScaledVideoFirstFrameRepresentation: CachedMediaResourceRepresentation {
    let size: CGSize
    var keepDuration: CachedMediaRepresentationKeepDuration = .general
    var uniqueId: String {
        return "scaled-frame-\(Int(self.size.width))x\(Int(self.size.height))"
    }
    
    init(size: CGSize) {
        self.size = size
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedScaledVideoFirstFrameRepresentation {
            return self.size == to.size
        } else {
            return false
        }
    }
}
final class CachedBlurredWallpaperRepresentation: CachedMediaResourceRepresentation {
    var keepDuration: CachedMediaRepresentationKeepDuration = .general
    var uniqueId: String {
        return CachedBlurredWallpaperRepresentation.uniqueId
    }
    
    static var uniqueId: String {
        return "blurred-wallpaper"
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if to is CachedBlurredWallpaperRepresentation {
            return true
        } else {
            return false
        }
    }
}


final class CachedAnimatedStickerRepresentation: CachedMediaResourceRepresentation {
    var keepDuration: CachedMediaRepresentationKeepDuration = .general
    var uniqueId: String {
        return "animated-sticker-v-\(self.thumb ? 1 : 0)"
    }
    let thumb: Bool
    init(thumb: Bool) {
        self.thumb = thumb
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedAnimatedStickerRepresentation {
            return self.thumb == to.thumb
        } else {
            return false
        }
    }
}
