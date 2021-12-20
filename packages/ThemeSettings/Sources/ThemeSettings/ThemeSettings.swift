//
//  ThemeSettings.swift
//  Telegram
//
//  Created by keepcoder on 07/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//
import Cocoa
import Postbox
import SwiftSignalKit
import TelegramCore
import ColorPalette
import Colors
import InAppSettings

public enum PresentationThemeParsingError: Error {
    case generic
}

private func parseColor(_ decoder: KeyedDecodingContainer<StringCodingKey>, _ key: String) throws -> NSColor? {
    if let value = try decoder.decodeIfPresent(Int32.self, forKey: .init(key)) {
        return NSColor(argb: UInt32(bitPattern: value))
    }
    return nil
}
private func parseColorArray(_ decoder: KeyedDecodingContainer<StringCodingKey>, _ key: String) throws -> [NSColor]? {
    let value = try decoder.decodeIfPresent([Int32].self, forKey: .init(key)) ?? []
    let list = value.map {
        NSColor(argb: UInt32(bitPattern: $0))
    }
    if list.isEmpty {
        return nil
    } else {
        return list
    }
}
public extension TelegramTheme {
    var effectiveSettings: TelegramThemeSettings? {
        return self.settings?.first
    }
    func effectiveSettings(for colors: ColorPalette) -> TelegramThemeSettings? {
        if let settings = self.settings {
            for settings in settings {
                switch settings.baseTheme {
                case .classic:
                    if colors.name == dayClassicPalette.name {
                        return settings
                    }
                case .day:
                    if colors.name == whitePalette.name {
                        return settings
                    }
                case .night, .tinted:
                    if colors.name == nightAccentPalette.name {
                        return settings
                    }
                }
            }

        }
        return nil
    }
    func effectiveSettings(isDark: Bool) -> TelegramThemeSettings? {
        if let settings = self.settings {
            for settings in settings {
                switch settings.baseTheme {
                case .classic:
                    if !isDark {
                        return settings
                    }
                case .day:
                    if !isDark {
                        return settings
                    }
                case .night, .tinted:
                    if isDark {
                        return settings
                    }
                }
            }

        }
        return nil
    }
}



public enum Wallpaper : Equatable, Codable {
    case builtin
    case color(UInt32)
    case gradient(Int64?, [UInt32], Int32?)
    case image([TelegramMediaImageRepresentation], settings: WallpaperSettings)
    case file(slug: String, file: TelegramMediaFile, settings: WallpaperSettings, isPattern: Bool)
    case none
    case custom(TelegramMediaImageRepresentation, blurred: Bool)
    
    public init(_ wallpaper: TelegramWallpaper) {
        switch wallpaper {
        case .builtin:
            self = .builtin
        case let .color(color):
            self = .color(color)
        case let .image(image, settings):
            self = .image(image, settings: settings)
        case let .file(values):
            self = .file(slug: values.slug, file: values.file, settings: values.settings, isPattern: values.isPattern)
        case let .gradient(gradient):
            self = .gradient(gradient.id, gradient.colors, gradient.settings.rotation)
        }
    }
    
    public static func ==(lhs: Wallpaper, rhs: Wallpaper) -> Bool {
        switch lhs {
        case .builtin:
            if case .builtin = rhs {
                return true
            } else {
                return false
            }
        case let .color(value):
            if case .color(value) = rhs {
                return true
            } else {
                return false
            }
        case let .gradient(id, colors, rotation):
            if case .gradient(id, colors, rotation) = rhs {
                return true
            } else {
                return false
            }
        case let .image(reps, settings):
            if case .image(reps, settings: settings) = rhs {
                return true
            } else {
                return false
            }
        case let .file(lhsSlug, lhsFile, lhsSettings, lhsIsPattern):
            if case let .file(rhsSlug, rhsFile, rhsSettings, rhsIsPattern) = rhs {
                if lhsSlug != rhsSlug {
                    return false
                }
                if lhsFile.fileId != rhsFile.fileId {
                    return false
                }
                if lhsSettings != rhsSettings {
                    return false
                }
                if lhsIsPattern != rhsIsPattern {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .custom(rep, blurred):
            if case .custom(rep, blurred) = rhs {
                return true
            } else {
                return false
            }
        case .none:
            if case .none = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    public var wallpaperUrl: String? {
        switch self {
        case .builtin:
            return "builtin"
        case let .file(slug, _, settings, isPattern):
            var options: [String] = []
            if settings.blur {
                options.append("mode=blur")
            }
            if isPattern {
                if let pattern = settings.colors.first {
                    var color = NSColor(argb: pattern).withAlphaComponent(1.0).hexString.lowercased()
                    color = String(color[color.index(after: color.startIndex) ..< color.endIndex])
                    options.append("bg_color=\(color)")
                }
                if let intensity = settings.intensity {
                    options.append("intensity=\(intensity)")
                }
            }
            var optionsString = ""
            if !options.isEmpty {
                optionsString = "?\(options.joined(separator: "&"))"
            }
            return "https://t.me/bg/\(slug)\(optionsString)"
        default:
            return nil
        }
    }
    
    public init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        switch try container.decode(Int32.self, forKey: "v") {
        case 0:
            self = .builtin
        case 1:
            self = .color(UInt32(bitPattern: try container.decode(Int32.self, forKey: "c")))
        case 2:
            let settings = try container.decode(WallpaperSettings.self, forKey: "settings")
            let reps = try container.decode([TelegramMediaImageRepresentationNativeCodable].self, forKey: "i").map { $0.value }
            self = .image(reps, settings: settings)
        case 3:
            let settings = try container.decode(WallpaperSettings.self, forKey: "settings")
            let slug = try container.decode(String.self, forKey: "slug")
            let file = try container.decode(TelegramMediaFile.self, forKey: "file")
            let isPattern = try container.decode(Int32.self, forKey: "p") == 1
            self = .file(slug: slug, file: file, settings: settings, isPattern: isPattern)
        case 4:
            let rep = try container.decode(TelegramMediaImageRepresentationNativeCodable.self, forKey: "rep").value
            let blurred = try container.decode(Int32.self, forKey: "b") == 1
            self = .custom(rep, blurred: blurred)
        case 5:
            self = .none
        case 6:
            var colors = try container.decode([Int32].self, forKey: "c").map { UInt32(bitPattern: $0) }
            if colors.isEmpty {
                let ct = try container.decodeIfPresent(Int32.self, forKey: "ct") ?? 0
                let cb = try container.decodeIfPresent(Int32.self, forKey: "cb") ?? 0
                colors = [UInt32(bitPattern: ct), UInt32(bitPattern: cb)]
            }
            let id = try container.decodeIfPresent(Int64.self, forKey: "id")
            let cr = try container.decodeIfPresent(Int32.self, forKey: "cr")
            self = .gradient(id, colors, cr)

        default:
            assertionFailure()
            self = .color(0xffffff)
        }
    }
    
    
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        switch self {
        case .builtin:
            try container.encode(Int32(0), forKey: "v")
        case let .color(color):
            try container.encode(Int32(1), forKey: "v")
            try container.encode(Int32(bitPattern: color), forKey: "c")
        case let .image(representations, settings):
            try container.encode(Int32(2), forKey: "v")
            try container.encode(representations.map { TelegramMediaImageRepresentationNativeCodable($0) }, forKey: "i")
            try container.encode(settings, forKey: "settings")
        case let .file(slug, file, settings, isPattern):
            try container.encode(Int32(3), forKey: "v")
            try container.encode(slug, forKey: "slug")
            try container.encode(file, forKey: "file")
            try container.encode(settings, forKey: "settings")
            try container.encode(Int32(isPattern ? 1 : 0), forKey: "p")
        case let .custom(resource, blurred):
            try container.encode(Int32(4), forKey: "v")
            try container.encode(TelegramMediaImageRepresentationNativeCodable(resource), forKey: "rep")
            try container.encode(Int32(blurred ? 1 : 0), forKey: "b")
        case .none:
            try container.encode(Int32(5), forKey: "v")
        case let .gradient(id, colors, rotation):
            try container.encode(Int32(6), forKey: "v")
            try container.encode(colors.map { Int32(bitPattern: $0) }, forKey: "c")
            if let rotation = rotation {
                try container.encode(rotation, forKey: "cr")
            } else {
                try container.encodeNil(forKey: "cr")
            }
            if let id = id {
                try container.encode(id, forKey: "id")
            } else {
                try container.encodeNil(forKey: "id")
            }
        }
    }
    
    public func withUpdatedBlurrred(_ blurred: Bool) -> Wallpaper {
        switch self {
        case .builtin:
            return self
        case .color:
            return self
        case .gradient:
            return self
        case let .image(representations, settings):
            return .image(representations, settings: WallpaperSettings(blur: blurred, motion: settings.motion, colors: settings.colors, intensity: settings.intensity, rotation: settings.rotation))
        case let .file(slug, file, settings, isPattern):
            return .file(slug: slug, file: file, settings: WallpaperSettings(blur: blurred, motion: settings.motion, colors: settings.colors, intensity: settings.intensity, rotation: settings.rotation), isPattern: isPattern)
        case let .custom(path, _):
            return .custom(path, blurred: blurred)
        case .none:
            return self
        }
    }
    
    public func withUpdatedSettings(_ settings: WallpaperSettings) -> Wallpaper {
        switch self {
        case .builtin:
            return self
        case .color:
            return self
        case .gradient:
            return self
        case let .image(representations, _):
            return .image(representations, settings: settings)
        case let .file(slug, file, _, isPattern):
            return .file(slug: slug, file: file, settings: settings, isPattern: isPattern)
        case .custom:
            return self
        case .none:
            return self
        }
    }
    
    public var isBlurred: Bool {
        switch self {
        case .builtin:
            return false
        case .color:
            return false
        case .gradient:
            return false
        case let .image(_, settings):
            return settings.blur
        case let .file(_, _, settings, _):
            return settings.blur
        case let .custom(_, blurred):
            return blurred
        case .none:
            return false
        }
    }
    
    public var settings: WallpaperSettings {
        switch self {
        case let .image(_, settings):
            return settings
        case let .file(_, _, settings, _):
            return settings
        case let .color(t):
            return WallpaperSettings(colors: [t])
        case let .gradient(_, colors, r):
            return WallpaperSettings(colors: colors, rotation: r)
        default:
            return WallpaperSettings()
        }
    }
    
    public func isSemanticallyEqual(to other: Wallpaper) -> Bool {
        switch self {
        case .none:
            return other == self
        case .builtin:
            return other == self
        case .color:
            return other == self
        case .gradient:
            return other == self
        case let .custom(resource, _):
            if case .custom(resource, _) = other {
                return true
            } else {
                return false
            }
        case let .image(representations, _):
            if case .image(representations, _) = other {
                return true
            } else {
                return false
            }
        case let .file(slug, _, _, _):
            if case .file(slug: slug, _, _, _) = other {
                return true
            } else {
                return false
            }
        }
    }
}

final class TelegramMediaImageRepresentationNativeCodable : Codable {
    let value: TelegramMediaImageRepresentation
    init(_ value: TelegramMediaImageRepresentation) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        let data = try container.decode(Data.self, forKey: "data")
        let postboxDecoder = PostboxDecoder(buffer: MemoryBuffer(data: data))
        guard let object = postboxDecoder.decodeRootObject() as? TelegramMediaImageRepresentation else {
            throw TelegramMediaImageReferenceDecodingError.generic
        }
        self.value = object
    }
    
    func encode(to encoder: Encoder) throws {
        let postboxEncoder = PostboxEncoder()
        postboxEncoder.encodeRootObject(self.value)
        
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(postboxEncoder.makeData(), forKey: "data")
    }
}

public extension PaletteWallpaper {
    var wallpaper: Wallpaper {
        switch self {
        case .none:
            return .none
        case .builtin:
            return .builtin
        case let .color(color):
            return .color(color.argb)
        default:
            return .none
        }
    }
}


public struct AssociatedWallpaper : Codable, Equatable {
    public let cloud: TelegramWallpaper?
    public let wallpaper: Wallpaper
   
    public static func ==(lhs: AssociatedWallpaper, rhs: AssociatedWallpaper) -> Bool {
        if let lhsCloud = lhs.cloud, let rhsCloud = rhs.cloud {
            switch lhsCloud {
            case let .file(file):
                if case .file(file) = rhsCloud {
                    return true
                } else {
                    return lhsCloud == rhsCloud && lhs.wallpaper == rhs.wallpaper
                }
            default:
                return lhsCloud == rhsCloud && lhs.wallpaper == rhs.wallpaper
            }
        }
        return lhs.cloud == rhs.cloud && lhs.wallpaper == rhs.wallpaper
    }
    
    public init() {
        self.cloud = nil
        self.wallpaper = .none
    }
    public init(cloud: TelegramWallpaper?, wallpaper: Wallpaper) {
        self.cloud = cloud
        self.wallpaper = wallpaper
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.cloud = try container.decodeIfPresent(TelegramWallpaperNativeCodable.self, forKey: "c")?.value
        self.wallpaper = try container.decodeIfPresent(Wallpaper.self, forKey: "w1") ?? .builtin
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        if let cloud = self.cloud {
            try container.encode(TelegramWallpaperNativeCodable(cloud), forKey: "c")
        } else {
            try container.encodeNil(forKey: "c")
        }
        try container.encode(self.wallpaper, forKey: "w1")
    }
}

public struct ThemeWallpaper : Codable, Equatable {
    public let wallpaper: Wallpaper
    public let associated: AssociatedWallpaper?
    
    public init() {
        self.wallpaper = .none
        self.associated =  nil
    }
    public init(wallpaper: Wallpaper, associated: AssociatedWallpaper?) {
        self.wallpaper = wallpaper
        self.associated =  associated
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.wallpaper = try container.decode(Wallpaper.self, forKey: "w")
        self.associated = try container.decodeIfPresent(AssociatedWallpaper.self, forKey: "aw")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        if let associated = self.associated {
            try container.encode(associated, forKey: "aw")
        } else {
            try container.encodeNil(forKey: "aw")
        }
        try container.encode(self.wallpaper, forKey: "w")
    }
    
    public func withUpdatedWallpaper(_ wallpaper: Wallpaper) -> ThemeWallpaper {
        return ThemeWallpaper(wallpaper: wallpaper, associated: self.associated)
    }
    public func withUpdatedAssociated(_ associated: AssociatedWallpaper?) -> ThemeWallpaper {
        return ThemeWallpaper(wallpaper: self.wallpaper, associated: associated)
    }
    
    public var paletteWallpaper: PaletteWallpaper {
        switch self.wallpaper {
        case let .file(slug, _, settings, isPattern):
            var options: [String] = []
            if settings.blur {
                options.append("mode=blur")
            }
            if isPattern {
                if let pattern = settings.colors.first {
                    var color = NSColor(argb: pattern).hexString.lowercased()
                    color = String(color[color.index(after: color.startIndex) ..< color.endIndex])
                    options.append("bg_color=\(color)")
                }
                if let intensity = settings.intensity {
                    options.append("intensity=\(intensity)")
                }
            }
            var optionsString = ""
            if !options.isEmpty {
                optionsString = "?\(options.joined(separator: "&"))"
            }
            return .url("https://t.me/bg/\(slug)\(optionsString)")
        case .builtin:
            return .builtin
        default:
            return .none
        }
    }
    
}

final class PaletteAccentColorNativeCodable : Codable {

    let value: PaletteAccentColor
    init(_ value: PaletteAccentColor) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        let accent = NSColor(argb: UInt32(bitPattern: try container.decode(Int32.self, forKey: "c")))
        let colors = try container.decodeIfPresent([Int32].self, forKey: "bc") ?? []
        let messages: [NSColor]?
        if colors.isEmpty {
            if let rawTop = try container.decodeIfPresent(Int32.self, forKey: "bt"), let rawBottom = try container.decodeIfPresent(Int32.self, forKey: "bb") {
                messages = [NSColor(argb: UInt32(bitPattern: rawTop)), NSColor(argb: UInt32(bitPattern: rawBottom))]
            } else {
                messages = nil
            }
        } else {
            messages = colors.map { NSColor(argb: UInt32(bitPattern: $0)) }
        }
        self.value = .init(accent, messages)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(Int32(bitPattern: self.value.accent.argb), forKey: "c")
        if let messages = self.value.messages {
            try container.encode(messages.map { Int32(bitPattern: $0.argb) }, forKey: "bc")
        } else {
            try container.encodeNil(forKey: "bc")
        }
    }
    
}

final class ColorPaletteNativeCodable : Codable {
    let value: ColorPalette
    
    init(_ value: ColorPalette) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        let dark = try container.decode(Bool.self, forKey: "dark")
        let tinted = try container.decode(Bool.self, forKey: "tinted")
        
        
        let parent: TelegramBuiltinTheme = TelegramBuiltinTheme(rawValue: try container.decodeIfPresent(String.self, forKey: "parent") ?? dayClassicPalette.name) ?? (dark ? .nightAccent : .dayClassic)
        let copyright: String = try container.decodeIfPresent(String.self, forKey: "copyright") ?? "Telegram"
        
        let isNative = try container.decodeIfPresent(Bool.self, forKey: "isNative") ?? true
        let name = try container.decodeIfPresent(String.self, forKey: "name") ?? "Default"
        
        let palette: ColorPalette = parent.palette
        let pw = PaletteWallpaper(try container.decodeIfPresent(String.self, forKey: "pw") ?? "none")
        
        
        let accentList: [PaletteAccentColor] = try container.decode([PaletteAccentColorNativeCodable].self, forKey: "accentList_1").map { $0.value }
        
        let bubbleBackground_outgoing:[NSColor]
        if let colors = try parseColorArray(container, "bubbleBackground_outgoing") {
            bubbleBackground_outgoing = colors
        } else {
            let colors = [try parseColor(container, "bubbleBackgroundTop_outgoing"), try parseColor(container, "bubbleBackgroundBottom_outgoing")].compactMap { $0 }
            if colors.isEmpty {
                bubbleBackground_outgoing = palette.bubbleBackground_outgoing
            } else {
                bubbleBackground_outgoing = colors
            }
        }
        
        self.value = ColorPalette(isNative: isNative,
                                    isDark: dark,
                                    tinted: tinted,
                                    name: name,
                                    parent: parent,
                                    wallpaper: pw ?? palette.wallpaper,
                                    copyright: copyright,
                                    accentList: accentList,
                                    basicAccent: try parseColor(container, "basicAccent") ?? palette.basicAccent,
                                    background: try parseColor(container, "background") ?? palette.background,
                                    text: try parseColor(container, "text") ?? palette.text,
                                    grayText: try parseColor(container, "grayText") ?? palette.grayText,
                                    link: try parseColor(container, "link") ?? palette.link,
                                    accent: try parseColor(container, "accent") ?? palette.accent,
                                    redUI: try parseColor(container, "redUI") ?? palette.redUI,
                                    greenUI: try parseColor(container, "greenUI") ?? palette.greenUI,
                                    blackTransparent: try parseColor(container, "blackTransparent") ?? palette.blackTransparent,
                                    grayTransparent: try parseColor(container, "grayTransparent") ?? palette.grayTransparent,
                                    grayUI: try parseColor(container, "grayUI") ?? palette.grayUI,
                                    darkGrayText: try parseColor(container, "darkGrayText") ?? palette.darkGrayText,
                                    accentSelect: try parseColor(container, "accentSelect") ?? palette.accentSelect,
                                    selectText: try parseColor(container, "selectText") ?? palette.selectText,
                                    border: try parseColor(container, "border") ?? palette.border,
                                    grayBackground: try parseColor(container, "grayBackground") ?? palette.grayBackground,
                                    grayForeground: try parseColor(container, "grayForeground") ?? palette.grayForeground,
                                    grayIcon: try parseColor(container, "grayIcon") ?? palette.grayIcon,
                                    accentIcon: try parseColor(container, "accentIcon") ?? parseColor(container, "blueIcon") ?? palette.accentIcon,
                                    badgeMuted: try parseColor(container, "badgeMuted") ?? palette.badgeMuted,
                                    badge: try parseColor(container, "badge") ?? palette.badge,
                                    indicatorColor: try parseColor(container, "indicatorColor") ?? palette.indicatorColor,
                                    selectMessage: try parseColor(container, "selectMessage") ?? palette.selectMessage,
                                    monospacedPre: try parseColor(container, "monospacedPre") ?? palette.monospacedPre,
                                    monospacedCode: try parseColor(container, "monospacedCode") ?? palette.monospacedCode,
                                    monospacedPreBubble_incoming: try parseColor(container, "monospacedPreBubble_incoming") ?? palette.monospacedPreBubble_incoming,
                                    monospacedPreBubble_outgoing: try parseColor(container, "monospacedPreBubble_outgoing") ?? palette.monospacedPreBubble_outgoing,
                                    monospacedCodeBubble_incoming: try parseColor(container, "monospacedCodeBubble_incoming") ?? palette.monospacedCodeBubble_incoming,
                                    monospacedCodeBubble_outgoing: try parseColor(container, "monospacedCodeBubble_outgoing") ?? palette.monospacedCodeBubble_outgoing,
                                    selectTextBubble_incoming: try parseColor(container, "selectTextBubble_incoming") ?? palette.selectTextBubble_incoming,
                                    selectTextBubble_outgoing: try parseColor(container, "selectTextBubble_outgoing") ?? palette.selectTextBubble_outgoing,
                                    bubbleBackground_incoming: try parseColor(container, "bubbleBackground_incoming") ?? palette.bubbleBackground_incoming,
                                    bubbleBackground_outgoing: bubbleBackground_outgoing,
                                    bubbleBorder_incoming: try parseColor(container, "bubbleBorder_incoming") ?? palette.bubbleBorder_incoming,
                                    bubbleBorder_outgoing: try parseColor(container, "bubbleBorder_outgoing") ?? palette.bubbleBorder_outgoing,
                                    grayTextBubble_incoming: try parseColor(container, "grayTextBubble_incoming") ?? palette.grayTextBubble_incoming,
                                    grayTextBubble_outgoing: try parseColor(container, "grayTextBubble_outgoing") ?? palette.grayTextBubble_outgoing,
                                    grayIconBubble_incoming: try parseColor(container, "grayIconBubble_incoming") ?? palette.grayIconBubble_incoming,
                                    grayIconBubble_outgoing: try parseColor(container, "grayIconBubble_outgoing") ?? palette.grayIconBubble_outgoing,
                                    accentIconBubble_incoming: try parseColor(container, "accentIconBubble_incoming") ?? parseColor(container, "blueIconBubble_incoming") ?? palette.accentIconBubble_incoming,
                                    accentIconBubble_outgoing: try parseColor(container, "accentIconBubble_outgoing") ?? parseColor(container, "blueIconBubble_outgoing") ?? palette.accentIconBubble_outgoing,
                                    linkBubble_incoming: try parseColor(container, "linkBubble_incoming") ?? palette.linkBubble_incoming,
                                    linkBubble_outgoing: try parseColor(container, "linkBubble_outgoing") ?? palette.linkBubble_outgoing,
                                    textBubble_incoming: try parseColor(container, "textBubble_incoming") ?? palette.textBubble_incoming,
                                    textBubble_outgoing: try parseColor(container, "textBubble_outgoing") ?? palette.textBubble_outgoing,
                                    selectMessageBubble: try parseColor(container, "selectMessageBubble") ?? palette.selectMessageBubble,
                                    fileActivityBackground: try parseColor(container, "fileActivityBackground") ?? palette.fileActivityBackground,
                                    fileActivityForeground: try parseColor(container, "fileActivityForeground") ?? palette.fileActivityForeground,
                                    fileActivityBackgroundBubble_incoming: try parseColor(container, "fileActivityBackgroundBubble_incoming") ?? palette.fileActivityBackgroundBubble_incoming,
                                    fileActivityBackgroundBubble_outgoing: try parseColor(container, "fileActivityBackgroundBubble_outgoing") ?? palette.fileActivityBackgroundBubble_outgoing,
                                    fileActivityForegroundBubble_incoming: try parseColor(container, "fileActivityForegroundBubble_incoming") ?? palette.fileActivityForegroundBubble_incoming,
                                    fileActivityForegroundBubble_outgoing: try parseColor(container, "fileActivityForegroundBubble_outgoing") ?? palette.fileActivityForegroundBubble_outgoing,
                                    waveformBackground: try parseColor(container, "waveformBackground") ?? palette.waveformBackground,
                                    waveformForeground: try parseColor(container, "waveformForeground") ?? palette.waveformForeground,
                                    waveformBackgroundBubble_incoming: try parseColor(container, "waveformBackgroundBubble_incoming") ?? palette.waveformBackgroundBubble_incoming,
                                    waveformBackgroundBubble_outgoing: try parseColor(container, "waveformBackgroundBubble_outgoing") ?? palette.waveformBackgroundBubble_outgoing,
                                    waveformForegroundBubble_incoming: try parseColor(container, "waveformForegroundBubble_incoming") ?? palette.waveformForegroundBubble_incoming,
                                    waveformForegroundBubble_outgoing: try parseColor(container, "waveformForegroundBubble_outgoing") ?? palette.waveformForegroundBubble_outgoing,
                                    webPreviewActivity: try parseColor(container, "webPreviewActivity") ?? palette.webPreviewActivity,
                                    webPreviewActivityBubble_incoming: try parseColor(container, "webPreviewActivityBubble_incoming") ?? palette.webPreviewActivityBubble_incoming,
                                    webPreviewActivityBubble_outgoing: try parseColor(container, "webPreviewActivityBubble_outgoing") ?? palette.webPreviewActivityBubble_outgoing,
                                    redBubble_incoming: try parseColor(container, "redBubble_incoming") ?? palette.redBubble_incoming,
                                    redBubble_outgoing: try parseColor(container, "redBubble_outgoing") ?? palette.redBubble_outgoing,
                                    greenBubble_incoming: try parseColor(container, "greenBubble_incoming") ?? palette.greenBubble_incoming,
                                    greenBubble_outgoing: try parseColor(container, "greenBubble_outgoing") ?? palette.greenBubble_outgoing,
                                    chatReplyTitle: try parseColor(container, "chatReplyTitle") ?? palette.chatReplyTitle,
                                    chatReplyTextEnabled: try parseColor(container, "chatReplyTextEnabled") ?? palette.chatReplyTextEnabled,
                                    chatReplyTextDisabled: try parseColor(container, "chatReplyTextDisabled") ?? palette.chatReplyTextDisabled,
                                    chatReplyTitleBubble_incoming: try parseColor(container, "chatReplyTitleBubble_incoming") ?? palette.chatReplyTitleBubble_incoming,
                                    chatReplyTitleBubble_outgoing: try parseColor(container, "chatReplyTitleBubble_outgoing") ?? palette.chatReplyTitleBubble_outgoing,
                                    chatReplyTextEnabledBubble_incoming: try parseColor(container, "chatReplyTextEnabledBubble_incoming") ?? palette.chatReplyTextEnabledBubble_incoming,
                                    chatReplyTextEnabledBubble_outgoing: try parseColor(container, "chatReplyTextEnabledBubble_outgoing") ?? palette.chatReplyTextEnabledBubble_outgoing,
                                    chatReplyTextDisabledBubble_incoming: try parseColor(container, "chatReplyTextDisabledBubble_incoming") ?? palette.chatReplyTextDisabledBubble_incoming,
                                    chatReplyTextDisabledBubble_outgoing: try parseColor(container, "chatReplyTextDisabledBubble_outgoing") ?? palette.chatReplyTextDisabledBubble_outgoing,
                                    groupPeerNameRed: try parseColor(container, "groupPeerNameRed") ?? palette.groupPeerNameRed,
                                    groupPeerNameOrange: try parseColor(container, "groupPeerNameOrange") ?? palette.groupPeerNameOrange,
                                    groupPeerNameViolet: try parseColor(container, "groupPeerNameViolet") ?? palette.groupPeerNameViolet,
                                    groupPeerNameGreen: try parseColor(container, "groupPeerNameGreen") ?? palette.groupPeerNameGreen,
                                    groupPeerNameCyan: try parseColor(container, "groupPeerNameCyan") ?? palette.groupPeerNameCyan,
                                    groupPeerNameLightBlue: try parseColor(container, "groupPeerNameLightBlue") ?? palette.groupPeerNameLightBlue,
                                    groupPeerNameBlue: try parseColor(container, "groupPeerNameBlue") ?? palette.groupPeerNameBlue,
                                    peerAvatarRedTop: try parseColor(container, "peerAvatarRedTop") ?? palette.peerAvatarRedTop,
                                    peerAvatarRedBottom: try parseColor(container, "peerAvatarRedBottom") ?? palette.peerAvatarRedBottom,
                                    peerAvatarOrangeTop: try parseColor(container, "peerAvatarOrangeTop") ?? palette.peerAvatarOrangeTop,
                                    peerAvatarOrangeBottom: try parseColor(container, "peerAvatarOrangeBottom") ?? palette.peerAvatarOrangeBottom,
                                    peerAvatarVioletTop: try parseColor(container, "peerAvatarVioletTop") ?? palette.peerAvatarVioletTop,
                                    peerAvatarVioletBottom: try parseColor(container, "peerAvatarVioletBottom") ?? palette.peerAvatarVioletBottom,
                                    peerAvatarGreenTop: try parseColor(container, "peerAvatarGreenTop") ?? palette.peerAvatarGreenTop,
                                    peerAvatarGreenBottom: try parseColor(container, "peerAvatarGreenBottom") ?? palette.peerAvatarGreenBottom,
                                    peerAvatarCyanTop: try parseColor(container, "peerAvatarCyanTop") ?? palette.peerAvatarCyanTop,
                                    peerAvatarCyanBottom: try parseColor(container, "peerAvatarCyanBottom") ?? palette.peerAvatarCyanBottom,
                                    peerAvatarBlueTop: try parseColor(container, "peerAvatarBlueTop") ?? palette.peerAvatarBlueTop,
                                    peerAvatarBlueBottom: try parseColor(container, "peerAvatarBlueBottom") ?? palette.peerAvatarBlueBottom,
                                    peerAvatarPinkTop: try parseColor(container, "peerAvatarPinkTop") ?? palette.peerAvatarPinkTop,
                                    peerAvatarPinkBottom: try parseColor(container, "peerAvatarPinkBottom") ?? palette.peerAvatarPinkBottom,
                                    bubbleBackgroundHighlight_incoming: try parseColor(container, "bubbleBackgroundHighlight_incoming") ?? palette.bubbleBackgroundHighlight_incoming,
                                    bubbleBackgroundHighlight_outgoing: try parseColor(container, "bubbleBackgroundHighlight_outgoing") ?? palette.bubbleBackgroundHighlight_outgoing,
                                    chatDateActive: try parseColor(container, "chatDateActive") ?? palette.chatDateActive,
                                    chatDateText: try parseColor(container, "chatDateText") ?? palette.chatDateText,
                                    revealAction_neutral1_background: try parseColor(container, "revealAction_neutral1_background") ?? palette.revealAction_neutral1_background,
                                    revealAction_neutral1_foreground: try parseColor(container, "revealAction_neutral1_foreground") ?? palette.revealAction_neutral1_foreground,
                                    revealAction_neutral2_background: try parseColor(container, "revealAction_neutral2_background") ?? palette.revealAction_neutral2_background,
                                    revealAction_neutral2_foreground: try parseColor(container, "revealAction_neutral2_foreground") ?? palette.revealAction_neutral2_foreground,
                                    revealAction_destructive_background: try parseColor(container, "revealAction_destructive_background") ?? palette.revealAction_destructive_background,
                                    revealAction_destructive_foreground: try parseColor(container, "revealAction_destructive_foreground") ?? palette.revealAction_destructive_foreground,
                                    revealAction_constructive_background: try parseColor(container, "revealAction_constructive_background") ?? palette.revealAction_constructive_background,
                                    revealAction_constructive_foreground: try parseColor(container, "revealAction_constructive_foreground") ?? palette.revealAction_constructive_foreground,
                                    revealAction_accent_background: try parseColor(container, "revealAction_accent_background") ?? palette.revealAction_accent_background,
                                    revealAction_accent_foreground: try parseColor(container, "revealAction_accent_foreground") ?? palette.revealAction_accent_foreground,
                                    revealAction_warning_background: try parseColor(container, "revealAction_warning_background") ?? palette.revealAction_warning_background,
                                    revealAction_warning_foreground: try parseColor(container, "revealAction_warning_foreground") ?? palette.revealAction_warning_foreground,
                                    revealAction_inactive_background: try parseColor(container, "revealAction_inactive_background") ?? palette.revealAction_inactive_background,
                                    revealAction_inactive_foreground: try parseColor(container, "revealAction_inactive_foreground") ?? palette.revealAction_inactive_foreground,
                                    chatBackground: try parseColor(container, "chatBackground") ?? palette.chatBackground,
                                    listBackground: try parseColor(container, "listBackground") ?? palette.listBackground,
                                    listGrayText: try parseColor(container, "listGrayText") ?? palette.listGrayText,
                                    grayHighlight: try parseColor(container, "grayHighlight") ?? palette.grayHighlight,
                                    focusAnimationColor: try parseColor(container, "focusAnimationColor") ?? palette.focusAnimationColor
        )
        
    }
    
    func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: StringCodingKey.self)

        
        try container.encode(self.value.isNative, forKey: "isNative")
        try container.encode(self.value.name, forKey: "name")
        try container.encode(self.value.copyright, forKey: "copyright")
        try container.encode(self.value.parent.rawValue, forKey: "parent")
        try container.encode(self.value.isDark, forKey: "dark")
        try container.encode(self.value.tinted, forKey: "tinted")
        try container.encode(self.value.wallpaper.toString, forKey: "pw")
        try container.encode(self.value.accentList.map { PaletteAccentColorNativeCodable($0) }, forKey: "accentList_1")
        
        for child in Mirror(reflecting: self.value).children {
            if let label = child.label {
                if let value = child.value as? NSColor {
                    var label = label
                    _ = label.removeFirst()
                    try container.encode(Int32(bitPattern: value.argb), forKey: .init(label))
                } else if let value = child.value as? [NSColor] {
                    var label = label
                    _ = label.removeFirst()
                    try container.encode(value.map { Int32(bitPattern: $0.argb) }, forKey: .init(label))
                }
            }
        }
    }
           
}

public struct DefaultCloudTheme : Equatable, Codable {
    public let cloud: TelegramTheme
    public let palette: ColorPalette
    public let wallpaper: AssociatedWallpaper
    
    public init(cloud: TelegramTheme, palette: ColorPalette, wallpaper: AssociatedWallpaper) {
        self.cloud = cloud
        self.palette = palette
        self.wallpaper = wallpaper
    }
 
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.cloud = try container.decode(TelegramThemeNativeCodable.self, forKey: "c").value
        self.palette = try container.decode(ColorPaletteNativeCodable.self, forKey: "p").value
        self.wallpaper = try container.decode(AssociatedWallpaper.self, forKey: "w")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(TelegramThemeNativeCodable(self.cloud), forKey: "c")
        try container.encode(ColorPaletteNativeCodable(self.palette), forKey: "p")
        try container.encode(self.wallpaper, forKey: "w")
    }
    
}



public struct DefaultTheme : Equatable, Codable {
    public let local: TelegramBuiltinTheme
    public let cloud: DefaultCloudTheme?
    public init(local: TelegramBuiltinTheme, cloud: DefaultCloudTheme?) {
        self.local = local
        self.cloud = cloud
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        let localRawValue = try container.decode(String.self, forKey: "dl_1")
        self.local = TelegramBuiltinTheme(rawValue: localRawValue) ?? .dayClassic
        self.cloud = try container.decodeIfPresent(DefaultCloudTheme.self, forKey: "dc")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.local.rawValue, forKey: "dl_1")
        if let cloud = self.cloud {
            try container.encode(cloud, forKey: "dc")
        } else {
            try container.encodeNil(forKey: "dc")
        }
    }
    
    
    public func withUpdatedLocal(_ local: TelegramBuiltinTheme) -> DefaultTheme {
        return DefaultTheme(local: local, cloud: self.cloud)
    }
    public func updateCloud(_ f: (DefaultCloudTheme?)->DefaultCloudTheme?) -> DefaultTheme {
        return DefaultTheme(local: self.local, cloud: f(self.cloud))
    }
}

public struct LocalWallapper : Equatable, Codable {
    public let name: TelegramBuiltinTheme
    public let cloud: TelegramTheme?
    public let wallpaper: AssociatedWallpaper
    public let associated: AssociatedWallpaper?
    public let accentColor: UInt32
    public init(name: TelegramBuiltinTheme, accentColor: UInt32, wallpaper: AssociatedWallpaper, associated: AssociatedWallpaper?, cloud: TelegramTheme?) {
        self.name = name
        self.accentColor = accentColor
        self.wallpaper = wallpaper
        self.cloud = cloud
        self.associated = associated
    }
    
    public func isEqual(to other: ColorPalette) -> Bool {
        if self.name != other.parent {
            return false
        }
        if self.accentColor != 0 {
            return self.accentColor == other.accent.argb
        }
        return self.cloud == nil
    }

    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.name = TelegramBuiltinTheme(rawValue: try container.decode(String.self, forKey: "name")) ?? .dayClassic
        self.wallpaper = try container.decode(AssociatedWallpaper.self, forKey: "aw")
        self.cloud = try container.decodeIfPresent(TelegramThemeNativeCodable.self, forKey: "cloud")?.value
        self.associated = try container.decodeIfPresent(AssociatedWallpaper.self, forKey: "as")
        self.accentColor = UInt32(bitPattern: try container.decode(Int32.self, forKey: "ac"))
       
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.wallpaper, forKey: "aw")
        try container.encode(self.name.rawValue, forKey: "name")
        if let cloud = self.cloud {
            try container.encode(TelegramThemeNativeCodable(cloud), forKey: "cloud")
        } else {
            try container.encodeNil(forKey: "cloud")
        }
        if let associated = self.associated {
            try container.encode(associated, forKey: "as")
        } else {
            try container.encodeNil(forKey: "as")
        }
        try container.encode(Int32(bitPattern: self.accentColor), forKey: "ac")
    }
    
}

public struct LocalAccentColor : Equatable, Codable {
    public let name: TelegramBuiltinTheme
    public let color: PaletteAccentColor
    public let cloud: TelegramTheme?
    public init(name: TelegramBuiltinTheme, color: PaletteAccentColor, cloud: TelegramTheme?) {
        self.name = name
        self.color = color
        self.cloud = cloud
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
       
        self.name = TelegramBuiltinTheme(rawValue: try container.decode(String.self, forKey: "name")) ?? .dayClassic
        let hex = try container.decodeIfPresent(String.self, forKey: "color")
        if let hex = hex, let color = NSColor(hexString: hex) {
            self.color = .init(color)
        } else if let value = try container.decodeIfPresent(PaletteAccentColorNativeCodable.self, forKey: "pac1")?.value {
            self.color = value
        } else {
            self.color = PaletteAccentColor(self.name.palette.basicAccent)
        }
        self.cloud = try container.decodeIfPresent(TelegramThemeNativeCodable.self, forKey: "cloud")?.value
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.name.rawValue, forKey: "name")
        try container.encode(PaletteAccentColorNativeCodable(self.color), forKey: "pac1")
        if let cloud = self.cloud {
            try container.encode(TelegramThemeNativeCodable(cloud), forKey: "cloud")
        } else {
            try container.encodeNil(forKey: "cloud")
        }
    }
    
}

public struct ThemePaletteSettings: Codable, Equatable {
    public let palette: ColorPalette
    public let bubbled: Bool
    public let defaultIsDark: Bool
    public let fontSize: CGFloat
    public let defaultDark: DefaultTheme
    public let defaultDay: DefaultTheme
    public let associated:[DefaultTheme]
    public let wallpapers: [LocalWallapper]
    public let accents:[LocalAccentColor]
    public let wallpaper: ThemeWallpaper
    public let cloudTheme: TelegramTheme?
    public let legacyMenu: Bool
    public init(palette: ColorPalette,
         bubbled: Bool,
         fontSize: CGFloat,
         wallpaper: ThemeWallpaper,
         defaultDark: DefaultTheme,
         defaultDay: DefaultTheme,
         defaultIsDark: Bool,
         wallpapers: [LocalWallapper],
         accents: [LocalAccentColor],
         cloudTheme: TelegramTheme?,
         associated: [DefaultTheme],
         legacyMenu: Bool) {
        
        self.palette = palette
        self.bubbled = bubbled
        self.fontSize = fontSize
        self.wallpaper = wallpaper
        self.defaultDark = defaultDark
        self.defaultDay = defaultDay
        self.cloudTheme = cloudTheme
        self.wallpapers = wallpapers
        self.accents = accents
        self.defaultIsDark = defaultIsDark
        self.associated = associated.filter({$0.cloud?.cloud.settings != nil})
        self.legacyMenu = legacyMenu
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.wallpaper = try container.decodeIfPresent(ThemeWallpaper.self, forKey: "wallpaper") ?? .init()

    
        self.bubbled = try container.decodeIfPresent(Bool.self, forKey: "bubbled") ?? false
        self.fontSize = CGFloat(try container.decodeIfPresent(Double.self, forKey: "fontSize") ?? 13)
        

        self.defaultDark = try container.decode(DefaultTheme.self, forKey: "defaultDark_1")
        self.defaultDay = try container.decode(DefaultTheme.self, forKey: "defaultDay_1")
        self.cloudTheme = try container.decodeIfPresent(TelegramThemeNativeCodable.self, forKey: "cloudTheme")?.value
        self.wallpapers = try container.decode([LocalWallapper].self, forKey: "local_wallpapers")
        self.accents = try container.decode([LocalAccentColor].self, forKey: "local_accents")
        self.defaultIsDark = try container.decode(Bool.self, forKey: "defaultIsDark")
        self.associated = try container.decode([DefaultTheme].self, forKey: "associated")
        
        
        let defautlPalette = defaultIsDark ? defaultDark.local.palette : defaultDay.local.palette
        
        self.palette = try container.decodeIfPresent(ColorPaletteNativeCodable.self, forKey: "palette")?.value ?? defautlPalette

        self.legacyMenu = try container.decodeIfPresent(Bool.self, forKey: "legacyMenu") ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(ColorPaletteNativeCodable(self.palette), forKey: "palette")
        try container.encode(self.bubbled, forKey: "bubbled")
        try container.encode(Double(fontSize), forKey: "fontSize")
        try container.encode(wallpaper, forKey: "wallpaper")
        try container.encode(defaultDay, forKey: "defaultDay_1")
        try container.encode(defaultDark, forKey: "defaultDark_1")
        try container.encode(self.wallpapers, forKey: "local_wallpapers")
        try container.encode(self.accents, forKey: "local_accents")
        try container.encode(self.associated, forKey: "associated")
        try container.encode(self.legacyMenu, forKey: "legacyMenu")

        try container.encode(self.defaultIsDark, forKey: "defaultIsDark")

        if let cloudTheme = self.cloudTheme {
            try container.encode(TelegramThemeNativeCodable(cloudTheme), forKey: "cloudTheme")
        } else {
            try container.encodeNil(forKey: "cloudTheme")
        }
    }
    
    public func withUpdatedPalette(_ palette: ColorPalette) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme, associated: self.associated, legacyMenu: self.legacyMenu)
    }
    public func withUpdatedBubbled(_ bubbled: Bool) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme, associated: self.associated, legacyMenu: self.legacyMenu)
    }
    public func withUpdatedLegacyMenu(_ legacyMenu: Bool) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme, associated: self.associated, legacyMenu: legacyMenu)
    }
    public func withUpdatedFontSize(_ fontSize: CGFloat) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: fontSize, wallpaper: self.wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme, associated: self.associated, legacyMenu: self.legacyMenu)
    }
    
    public func updateWallpaper(_ f:(ThemeWallpaper)->ThemeWallpaper) -> ThemePaletteSettings {
        let updated = f(self.wallpaper)
        
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: updated, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme, associated: self.associated, legacyMenu: self.legacyMenu)
    }
    
    public func saveDefaultWallpaper() -> ThemePaletteSettings {
        var wallpapers = self.wallpapers
        let local = LocalWallapper(name: self.palette.parent, accentColor: self.palette.accent.argb, wallpaper: AssociatedWallpaper(cloud: self.wallpaper.associated?.cloud, wallpaper: self.wallpaper.wallpaper), associated: self.wallpaper.associated, cloud: self.cloudTheme)
        
        if let cloud = cloudTheme {
            if let index = wallpapers.firstIndex(where: { $0.cloud?.id == cloud.id }) {
                wallpapers[index] = local
            } else {
                wallpapers.append(local)
            }
        } else {
            if let index = wallpapers.firstIndex(where: { $0.isEqual(to: self.palette) }) {
                wallpapers[index] = local
            } else {
                wallpapers.append(local)
            }
        }
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: wallpapers, accents: self.accents, cloudTheme: self.cloudTheme, associated: self.associated, legacyMenu: self.legacyMenu)
    }
    
    public func installDefaultWallpaper() -> ThemePaletteSettings {
        
        let wallpaper:ThemeWallpaper
        if let cloud = self.cloudTheme {
            let first = self.wallpapers.first(where: { $0.cloud?.id == cloud.id })
            wallpaper = ThemeWallpaper(wallpaper: first?.wallpaper.wallpaper ?? self.palette.wallpaper.wallpaper, associated: first?.associated)
        } else {
            let first = self.wallpapers.first(where: { $0.isEqual(to: self.palette) })
            wallpaper = ThemeWallpaper(wallpaper: first?.wallpaper.wallpaper ?? self.palette.wallpaper.wallpaper, associated: nil)
        }
        
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme, associated: self.associated, legacyMenu: self.legacyMenu)
    }
    
    public func saveDefaultAccent(color: PaletteAccentColor) -> ThemePaletteSettings {
        var accents = self.accents
        let local = LocalAccentColor(name: self.palette.parent, color: color, cloud: self.cloudTheme)
        if let index = accents.firstIndex(where: { $0.name == palette.parent && $0.cloud?.id == self.cloudTheme?.id }) {
            accents[index] = local
        } else {
            accents.append(local)
        }
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: accents, cloudTheme: self.cloudTheme, associated: self.associated, legacyMenu: self.legacyMenu)
    }
    
    
    public func installDefaultAccent() -> ThemePaletteSettings {
        let accent: LocalAccentColor? = self.accents.first(where: { $0.name == self.palette.parent && $0.cloud?.id == self.cloudTheme?.id })
        var palette: ColorPalette = self.palette.withoutAccentColor()
        if let accent = accent {
             palette = palette.withAccentColor(accent.color)
        }
        return ThemePaletteSettings(palette: palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme, associated: self.associated, legacyMenu: self.legacyMenu)
    }
    
    public func withUpdatedDefaultDay(_ defaultDay: DefaultTheme) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: wallpaper, defaultDark: self.defaultDark, defaultDay: defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme, associated: self.associated, legacyMenu: self.legacyMenu)
    }
    public func withUpdatedDefaultDark(_ defaultDark: DefaultTheme) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: wallpaper, defaultDark: defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme, associated: self.associated, legacyMenu: self.legacyMenu)
    }
    public func withUpdatedDefaultIsDark(_ defaultIsDark: Bool) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme, associated: self.associated, legacyMenu: self.legacyMenu)
    }
    public func withUpdatedCloudTheme(_ cloudTheme: TelegramTheme?) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultDark: defaultDark, defaultDay: defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: cloudTheme, associated: self.associated, legacyMenu: self.legacyMenu)
    }
    
    public func withSavedAssociatedTheme() -> ThemePaletteSettings {
        var associated = self.associated
        if let cloudTheme = self.cloudTheme {
            if cloudTheme.effectiveSettings(for: self.palette) != nil {
                let value = DefaultTheme(local: self.palette.parent, cloud: DefaultCloudTheme(cloud: cloudTheme, palette: self.palette, wallpaper: AssociatedWallpaper(cloud: self.wallpaper.associated?.cloud, wallpaper: self.wallpaper.wallpaper)))
                if let index = associated.firstIndex(where: { $0.local == self.palette.parent }) {
                    associated[index] = value
                } else {
                    associated.append(value)
                }
            } 
        } else {
            let value = DefaultTheme(local: self.palette.parent, cloud: nil)
            if let index = associated.firstIndex(where: { $0.local == self.palette.parent }) {
                associated[index] = value
            } else {
                associated.append(value)
            }
        }
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme, associated: associated, legacyMenu: self.legacyMenu)
    }
    
    
    public func withUpdatedToDefault(dark: Bool, onlyLocal: Bool = false) -> ThemePaletteSettings {
        if dark {
            if let cloud = self.defaultDark.cloud, !onlyLocal {
                return self.withUpdatedPalette(cloud.palette)
                    .withUpdatedCloudTheme(cloud.cloud)
                    .installDefaultWallpaper()
            } else {
                return self.withUpdatedPalette(self.defaultDark.local.palette)
                    .withUpdatedCloudTheme(nil)
                    .installDefaultAccent()
                    .installDefaultWallpaper()
            }
        } else {
            if let cloud = self.defaultDay.cloud, !onlyLocal {
                return self.withUpdatedPalette(cloud.palette)
                    .withUpdatedCloudTheme(cloud.cloud)
                    .installDefaultWallpaper()
            } else {
                return self.withUpdatedPalette(self.defaultDay.local.palette)
                    .withUpdatedCloudTheme(nil)
                    .installDefaultAccent()
                    .installDefaultWallpaper()
            }
        }
    }
    
    public static var defaultTheme: ThemePaletteSettings {
        let defDark = DefaultTheme(local: .nightAccent, cloud: nil)
        let defDay = DefaultTheme(local: .dayClassic, cloud: nil)
        return ThemePaletteSettings(palette: dayClassicPalette, bubbled: false, fontSize: 13, wallpaper: ThemeWallpaper(), defaultDark: defDark, defaultDay: defDay, defaultIsDark: false, wallpapers: [LocalWallapper(name: .dayClassic, accentColor: dayClassicPalette.accent.argb, wallpaper: AssociatedWallpaper(cloud: nil, wallpaper: .builtin), associated: nil, cloud: nil)], accents: [], cloudTheme: nil, associated: [], legacyMenu: false)
    }
}

public func ==(lhs: ThemePaletteSettings, rhs: ThemePaletteSettings) -> Bool {
    if lhs.palette != rhs.palette {
        return false
    }
    if lhs.fontSize != rhs.fontSize {
        return false
    }
    if lhs.bubbled != rhs.bubbled {
        return false
    }
    if lhs.wallpaper != rhs.wallpaper {
        return false
    }
    if lhs.defaultDay != rhs.defaultDay {
        return false
    }
    if lhs.defaultDark != rhs.defaultDark {
        return false
    }
    if lhs.cloudTheme != rhs.cloudTheme {
        return false
    }
    if lhs.wallpapers != rhs.wallpapers {
        return false
    }
    if lhs.defaultIsDark != rhs.defaultIsDark {
        return false
    }
    if lhs.associated != rhs.associated {
        return false
    }
    if lhs.legacyMenu != rhs.legacyMenu {
        return false
    }
    return true
}


public func themeSettingsView(accountManager: AccountManager<TelegramAccountManagerTypes>)-> Signal<ThemePaletteSettings, NoError> {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.themeSettings]) |> map { $0.entries[ApplicationSharedPreferencesKeys.themeSettings]?.get(ThemePaletteSettings.self) ?? ThemePaletteSettings.defaultTheme
    }
}

public func themeUnmodifiedSettings(accountManager: AccountManager<TelegramAccountManagerTypes>)-> Signal<ThemePaletteSettings, NoError> {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.themeSettings]) |> map { $0.entries[ApplicationSharedPreferencesKeys.themeSettings]?.get(ThemePaletteSettings.self) ?? ThemePaletteSettings.defaultTheme
    }
}


public func updateThemeInteractivetly(accountManager: AccountManager<TelegramAccountManagerTypes>, f:@escaping (ThemePaletteSettings)->ThemePaletteSettings)-> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSharedPreferencesKeys.themeSettings, { entry in
            return PreferencesEntry(f(entry?.get(ThemePaletteSettings.self) ?? ThemePaletteSettings.defaultTheme))
        })
    }
}
