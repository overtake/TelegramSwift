//
//  CachedResourceRepresentations.swift
//  Telegram-Mac
//
//  Created by keepcoder on 24/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

import Postbox
import SwiftSignalKit
import TelegramCore
import SyncCore

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
        let version: Int = 1
        if let fitzModifier = self.fitzModifier {
            return "animated-sticker-v\(version)-\(self.thumb ? 1 : 0)-w:\(size.width)-h:\(size.height)-fitz\(fitzModifier.rawValue)"
        } else {
            return "animated-sticker-v\(version)-\(self.thumb ? 1 : 0)-w:\(size.width)-h:\(size.height)"
        }
    }
    let thumb: Bool
    let size: NSSize
    let fitzModifier: EmojiFitzModifier?
    init(thumb: Bool, size: NSSize, fitzModifier: EmojiFitzModifier? = nil) {
        self.thumb = thumb
        self.size = size
        self.fitzModifier = fitzModifier
    }
    
    func isEqual(to: CachedMediaResourceRepresentation) -> Bool {
        if let to = to as? CachedAnimatedStickerRepresentation {
            return self.thumb == to.thumb && self.size == to.size && self.fitzModifier == to.fitzModifier
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
            return "pattern-wallpaper-mask----\(Int(size.width))x\(Int(size.height))" + color
        } else {
            return "pattern-wallpaper-mask----" + color
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




public enum EmojiFitzModifier: Int32, Equatable {
    case type12
    case type3
    case type4
    case type5
    case type6
    
    public init?(emoji: String) {
        switch emoji.unicodeScalars.first?.value {
        case 0x1f3fb:
            self = .type12
        case 0x1f3fc:
            self = .type3
        case 0x1f3fd:
            self = .type4
        case 0x1f3fe:
            self = .type5
        case 0x1f3ff:
            self = .type6
        default:
            return nil
        }
    }
}
