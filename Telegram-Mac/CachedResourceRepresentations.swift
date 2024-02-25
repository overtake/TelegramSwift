//
//  CachedResourceRepresentations.swift
//  Telegram-Mac
//
//  Created by keepcoder on 24/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore


final class CachedStickerAJpegRepresentation: CachedMediaResourceRepresentation {
    let size: CGSize?
    var keepDuration: CachedMediaRepresentationKeepDuration = .general
    var uniqueId: String {
        if let size = self.size {
            return "sticker-v3-png-\(Int(size.width))x\(Int(size.height))"
        } else {
            return "sticker-v3-png"
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

final class CachedWallpaperRepresentation: CachedMediaResourceRepresentation {
    var keepDuration: CachedMediaRepresentationKeepDuration = .general
    var uniqueId: String {
        return CachedBlurredWallpaperRepresentation.uniqueId
    }
    let isDark: Bool
    let settings: WallpaperSettings
    init(isDark: Bool, settings: WallpaperSettings) {
        self.isDark = isDark
        self.settings = settings
    }
    
    static var uniqueId: String {
        return "cached-wallpaper"
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedWallpaperRepresentation {
            return to.isDark == self.isDark && to.settings == to.settings
        } else {
            return false
        }
    }
}


final class CachedAnimatedStickerRepresentation: CachedMediaResourceRepresentation {
    var keepDuration: CachedMediaRepresentationKeepDuration = .general
    var uniqueId: String {
        let version: Int = 17
        if let fitzModifier = self.fitzModifier {
            return "1animated-sticker-v\(version)-\(self.thumb ? 1 : 0)-w:\(size.width)-h:\(size.height)-fitz\(fitzModifier.rawValue)-f\(frame)-m1\(self.isVideo)"
        } else {
            return "1animated-sticker-v\(version)-\(self.thumb ? 1 : 0)-w:\(size.width)-h:\(size.height)-f\(frame)-m1\(self.isVideo)"
        }
    }
    let thumb: Bool
    let size: NSSize
    let fitzModifier: EmojiFitzModifier?
    let frame: Int
    let isVideo: Bool
    init(thumb: Bool, size: NSSize, fitzModifier: EmojiFitzModifier? = nil, frame: Int = 0, isVideo: Bool = false) {
        self.thumb = thumb
        self.size = size
        self.fitzModifier = fitzModifier
        self.frame = frame
        self.isVideo = isVideo
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedAnimatedStickerRepresentation {
            return self.thumb == to.thumb && self.size == to.size && self.fitzModifier == to.fitzModifier && self.frame == to.frame && self.isVideo == to.isVideo
        } else {
            return false
        }
    }
}

final class CachedPatternWallpaperMaskRepresentation: CachedMediaResourceRepresentation {
    let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    let size: CGSize?
    let settings: WallpaperSettings?
    var uniqueId: String {
        
        var color:String = ""
        
        if let settings = settings {
            color += settings.stringValue
        }
        
        if let size = self.size {
            return "pattern-wallpaper-mask--------\(Int(size.width))x\(Int(size.height))" + color
        } else {
            return "pattern-wallpaper-mask--------" + color
        }
    }
    
    init(size: CGSize? = nil, settings: WallpaperSettings? = nil) {
        self.size = size
        self.settings = settings
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedPatternWallpaperMaskRepresentation {
            return self.size == to.size && self.settings == to.settings
        } else {
            return false
        }
    }
}


final class CachedDiceRepresentation: CachedMediaResourceRepresentation {
    let keepDuration: CachedMediaRepresentationKeepDuration = .general
    let emoji: String
    let value: String
    let size: NSSize
    var uniqueId: String {
        return emoji + value + ":dice2"
    }
    
    init(emoji: String, value: String, size: NSSize) {
        self.value = value
        self.size = size
        self.emoji = emoji
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedDiceRepresentation {
            return self.value == to.value && self.size == to.size && self.emoji == to.emoji
        } else {
            return false
        }
    }
}

final class CachedSlotMachineRepresentation: CachedMediaResourceRepresentation {
    let keepDuration: CachedMediaRepresentationKeepDuration = .general
    let value: SlotMachineValue
    let size: NSSize
    var uniqueId: String {
        return "l: \(value.left.hashValue)" + ", c: \(value.center.hashValue)" + ", c: \(value.right.hashValue)" + " :slot1"
    }
    
    init(value: SlotMachineValue, size: NSSize) {
        self.value = value
        self.size = size
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedSlotMachineRepresentation {
            return self.value == to.value && self.size == to.size
        } else {
            return false
        }
    }
}





final class CachedPreparedSvgRepresentation: CachedMediaResourceRepresentation {
    public let keepDuration: CachedMediaRepresentationKeepDuration = .general
    
    public var uniqueId: String {
        return "prepared-svg"
    }
    
    public init() {
    }
    
    public func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if to is CachedPreparedSvgRepresentation {
            return true
        } else {
            return false
        }
    }
}
