//
//  ThemeSettings.swift
//  Telegram
//
//  Created by keepcoder on 07/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//
import Cocoa
import PostboxMac
import SwiftSignalKitMac
import TelegramCoreMac
import TGUIKit

public enum PresentationThemeParsingError: Error {
    case generic
}

private func parseColor(_ decoder: PostboxDecoder, _ key: String) -> NSColor? {
    if let value = decoder.decodeOptionalInt32ForKey(key) {
        return NSColor(argb: UInt32(bitPattern: value))
    }
    return nil
}


extension PaletteWallpaper {
    var wallpaper: Wallpaper {
        switch self {
        case .none:
            return .none
        case .builtin:
            return .builtin
        case let .color(color):
            return .color(Int32(color.rgb))
        default:
            return .none
        }
    }
}


struct AssociatedWallpaper : PostboxCoding, Equatable {
    let cloud: TelegramWallpaper?
    let wallpaper: Wallpaper
    init(decoder: PostboxDecoder) {
        self.cloud = decoder.decodeObjectForKey("c", decoder: { TelegramWallpaper(decoder: $0) }) as? TelegramWallpaper
        self.wallpaper = decoder.decodeObjectForKey("w", decoder: { Wallpaper(decoder: $0) }) as! Wallpaper
    }
    
    static func ==(lhs: AssociatedWallpaper, rhs: AssociatedWallpaper) -> Bool {
        if let lhsCloud = lhs.cloud, let rhsCloud = rhs.cloud {
            switch lhsCloud {
            case let .file(id, accessHash, isCreator, isDefault, isPattern, isDark, slug, lhsFile, settings):
                if case .file(id, accessHash, isCreator, isDefault, isPattern, isDark, slug, let rhsFile, settings) = rhsCloud {
                    return lhsFile.isSemanticallyEqual(to: rhsFile) && lhs.wallpaper == rhs.wallpaper
                } else {
                    return lhsCloud == rhsCloud && lhs.wallpaper == rhs.wallpaper
                }
            default:
                return lhsCloud == rhsCloud && lhs.wallpaper == rhs.wallpaper
            }
        }
        return lhs.cloud == rhs.cloud && lhs.wallpaper == rhs.wallpaper
    }
    
    init() {
        self.cloud = nil
        self.wallpaper = .none
    }
    init(cloud: TelegramWallpaper?, wallpaper: Wallpaper) {
        self.cloud = cloud
        self.wallpaper = wallpaper
    }
    
    func encode(_ encoder: PostboxEncoder) {
        if let cloud = cloud {
            encoder.encodeObject(cloud, forKey: "c")
        } else {
            encoder.encodeNil(forKey: "c")
        }
        encoder.encodeObject(self.wallpaper, forKey: "w")
    }
    
}

struct ThemeWallpaper : PostboxCoding, Equatable {
    let wallpaper: Wallpaper
    let associated: AssociatedWallpaper?
    
    init() {
        self.wallpaper = .none
        self.associated =  nil
    }
    init(wallpaper: Wallpaper, associated: AssociatedWallpaper?) {
        self.wallpaper = wallpaper
        self.associated =  associated
    }
    
    init(decoder: PostboxDecoder) {
        self.wallpaper = decoder.decodeObjectForKey("w", decoder: { Wallpaper(decoder: $0) }) as? Wallpaper ?? .none
        self.associated = decoder.decodeObjectForKey("aw", decoder: { AssociatedWallpaper(decoder: $0) }) as? AssociatedWallpaper
    }
    
    func encode(_ encoder: PostboxEncoder) {
        if let associated = associated {
            encoder.encodeObject(associated, forKey: "aw")
        } else {
            encoder.encodeNil(forKey: "aw")
        }
        encoder.encodeObject(self.wallpaper, forKey: "w")
    }
    
    func withUpdatedWallpaper(_ wallpaper: Wallpaper) -> ThemeWallpaper {
        return ThemeWallpaper(wallpaper: wallpaper, associated: self.associated)
    }
    func withUpdatedAssociated(_ associated: AssociatedWallpaper?) -> ThemeWallpaper {
        return ThemeWallpaper(wallpaper: self.wallpaper, associated: associated)
    }
    
    var paletteWallpaper: PaletteWallpaper {
        switch self.wallpaper {
        case let .file(slug, _, settings, isPattern):
            var options: [String] = []
            if settings.blur {
                options.append("mode=blur")
            }
            if isPattern {
                if let pattern = settings.color {
                    var color = NSColor(rgb: UInt32(bitPattern: pattern)).hexString.lowercased()
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

extension ColorPalette : PostboxCoding {
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: self).children {
            if let label = child.label {
                if let value = child.value as? NSColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                }
            }
        }
        encoder.encodeBool(self.isNative, forKey: "isNative")
        encoder.encodeString(self.name, forKey: "name")
        encoder.encodeString(self.copyright, forKey: "copyright")
        encoder.encodeString(self.parent.rawValue, forKey: "parent")
        encoder.encodeBool(self.isDark, forKey: "dark")
        encoder.encodeBool(self.tinted, forKey: "tinted")
        encoder.encodeString(self.wallpaper.toString, forKey: "pw")
        encoder.encodeString(self.accentList.map { $0.hexString }.joined(separator: ","), forKey: "accentList")
    }
    
    public init(decoder: PostboxDecoder) {
        let dark = decoder.decodeBoolForKey("dark", orElse: false)
        let tinted = decoder.decodeBoolForKey("tinted", orElse: false)
        
        let parent: TelegramBuiltinTheme = TelegramBuiltinTheme(rawValue: decoder.decodeStringForKey("parent", orElse: TelegramBuiltinTheme.dayClassic.rawValue)) ?? (dark ? .tintedNight : .dayClassic)
        let copyright = decoder.decodeStringForKey("copyright", orElse: "Telegram")
        
        let isNative = decoder.decodeBoolForKey("isNative", orElse: false)
        let name = decoder.decodeStringForKey("name", orElse: "Default")
        
        let palette: ColorPalette = parent.palette
        let pw = PaletteWallpaper(decoder.decodeStringForKey("pw", orElse: "none"))
        
        let accentList = decoder.decodeStringForKey("accentList", orElse: "").components(separatedBy: ",").compactMap { NSColor(hexString: $0) }
        
        self = ColorPalette(isNative: isNative,
                                    isDark: dark,
                                    tinted: tinted,
                                    name: name,
                                    parent: parent,
                                    wallpaper: pw ?? palette.wallpaper,
                                    copyright: copyright,
                                    accentList: accentList,
                                    basicAccent: parseColor(decoder, "basicAccent") ?? palette.basicAccent,
                                    background: parseColor(decoder, "background") ?? palette.background,
                                    text: parseColor(decoder, "text") ?? palette.text,
                                    grayText: parseColor(decoder, "grayText") ?? palette.grayText,
                                    link: parseColor(decoder, "link") ?? palette.link,
                                    accent: parseColor(decoder, "accent") ?? palette.accent,
                                    redUI: parseColor(decoder, "redUI") ?? palette.redUI,
                                    greenUI: parseColor(decoder, "greenUI") ?? palette.greenUI,
                                    blackTransparent: parseColor(decoder, "blackTransparent") ?? palette.blackTransparent,
                                    grayTransparent: parseColor(decoder, "grayTransparent") ?? palette.grayTransparent,
                                    grayUI: parseColor(decoder, "grayUI") ?? palette.grayUI,
                                    darkGrayText: parseColor(decoder, "darkGrayText") ?? palette.darkGrayText,
                                    blueText: parseColor(decoder, "blueText") ?? palette.blueText,
                                    blueSelect: parseColor(decoder, "blueSelect") ?? palette.blueSelect,
                                    selectText: parseColor(decoder, "selectText") ?? palette.selectText,
                                    blueFill: parseColor(decoder, "blueFill") ?? palette.blueFill,
                                    border: parseColor(decoder, "border") ?? palette.border,
                                    grayBackground: parseColor(decoder, "grayBackground") ?? palette.grayBackground,
                                    grayForeground: parseColor(decoder, "grayForeground") ?? palette.grayForeground,
                                    grayIcon: parseColor(decoder, "grayIcon") ?? palette.grayIcon,
                                    blueIcon: parseColor(decoder, "blueIcon") ?? palette.blueIcon,
                                    badgeMuted: parseColor(decoder, "badgeMuted") ?? palette.badgeMuted,
                                    badge: parseColor(decoder, "badge") ?? palette.badge,
                                    indicatorColor: parseColor(decoder, "indicatorColor") ?? palette.indicatorColor,
                                    selectMessage: parseColor(decoder, "selectMessage") ?? palette.selectMessage,
                                    monospacedPre: parseColor(decoder, "monospacedPre") ?? palette.monospacedPre,
                                    monospacedCode: parseColor(decoder, "monospacedCode") ?? palette.monospacedCode,
                                    monospacedPreBubble_incoming: parseColor(decoder, "monospacedPreBubble_incoming") ?? palette.monospacedPreBubble_incoming,
                                    monospacedPreBubble_outgoing: parseColor(decoder, "monospacedPreBubble_outgoing") ?? palette.monospacedPreBubble_outgoing,
                                    monospacedCodeBubble_incoming: parseColor(decoder, "monospacedCodeBubble_incoming") ?? palette.monospacedCodeBubble_incoming,
                                    monospacedCodeBubble_outgoing: parseColor(decoder, "monospacedCodeBubble_outgoing") ?? palette.monospacedCodeBubble_outgoing,
                                    selectTextBubble_incoming: parseColor(decoder, "selectTextBubble_incoming") ?? palette.selectTextBubble_incoming,
                                    selectTextBubble_outgoing: parseColor(decoder, "selectTextBubble_outgoing") ?? palette.selectTextBubble_outgoing,
                                    bubbleBackground_incoming: parseColor(decoder, "bubbleBackground_incoming") ?? palette.bubbleBackground_incoming,
                                    bubbleBackground_outgoing: parseColor(decoder, "bubbleBackground_outgoing") ?? palette.bubbleBackground_outgoing,
                                    bubbleBorder_incoming: parseColor(decoder, "bubbleBorder_incoming") ?? palette.bubbleBorder_incoming,
                                    bubbleBorder_outgoing: parseColor(decoder, "bubbleBorder_outgoing") ?? palette.bubbleBorder_outgoing,
                                    grayTextBubble_incoming: parseColor(decoder, "grayTextBubble_incoming") ?? palette.grayTextBubble_incoming,
                                    grayTextBubble_outgoing: parseColor(decoder, "grayTextBubble_outgoing") ?? palette.grayTextBubble_outgoing,
                                    grayIconBubble_incoming: parseColor(decoder, "grayIconBubble_incoming") ?? palette.grayIconBubble_incoming,
                                    grayIconBubble_outgoing: parseColor(decoder, "grayIconBubble_outgoing") ?? palette.grayIconBubble_outgoing,
                                    blueIconBubble_incoming: parseColor(decoder, "blueIconBubble_incoming") ?? palette.blueIconBubble_incoming,
                                    blueIconBubble_outgoing: parseColor(decoder, "blueIconBubble_outgoing") ?? palette.blueIconBubble_outgoing,
                                    linkBubble_incoming: parseColor(decoder, "linkBubble_incoming") ?? palette.linkBubble_incoming,
                                    linkBubble_outgoing: parseColor(decoder, "linkBubble_outgoing") ?? palette.linkBubble_outgoing,
                                    textBubble_incoming: parseColor(decoder, "textBubble_incoming") ?? palette.textBubble_incoming,
                                    textBubble_outgoing: parseColor(decoder, "textBubble_outgoing") ?? palette.textBubble_outgoing,
                                    selectMessageBubble: parseColor(decoder, "selectMessageBubble") ?? palette.selectMessageBubble,
                                    fileActivityBackground: parseColor(decoder, "fileActivityBackground") ?? palette.fileActivityBackground,
                                    fileActivityForeground: parseColor(decoder, "fileActivityForeground") ?? palette.fileActivityForeground,
                                    fileActivityBackgroundBubble_incoming: parseColor(decoder, "fileActivityBackgroundBubble_incoming") ?? palette.fileActivityBackgroundBubble_incoming,
                                    fileActivityBackgroundBubble_outgoing: parseColor(decoder, "fileActivityBackgroundBubble_outgoing") ?? palette.fileActivityBackgroundBubble_outgoing,
                                    fileActivityForegroundBubble_incoming: parseColor(decoder, "fileActivityForegroundBubble_incoming") ?? palette.fileActivityForegroundBubble_incoming,
                                    fileActivityForegroundBubble_outgoing: parseColor(decoder, "fileActivityForegroundBubble_outgoing") ?? palette.fileActivityForegroundBubble_outgoing,
                                    waveformBackground: parseColor(decoder, "waveformBackground") ?? palette.waveformBackground,
                                    waveformForeground: parseColor(decoder, "waveformForeground") ?? palette.waveformForeground,
                                    waveformBackgroundBubble_incoming: parseColor(decoder, "waveformBackgroundBubble_incoming") ?? palette.waveformBackgroundBubble_incoming,
                                    waveformBackgroundBubble_outgoing: parseColor(decoder, "waveformBackgroundBubble_outgoing") ?? palette.waveformBackgroundBubble_outgoing,
                                    waveformForegroundBubble_incoming: parseColor(decoder, "waveformForegroundBubble_incoming") ?? palette.waveformForegroundBubble_incoming,
                                    waveformForegroundBubble_outgoing: parseColor(decoder, "waveformForegroundBubble_outgoing") ?? palette.waveformForegroundBubble_outgoing,
                                    webPreviewActivity: parseColor(decoder, "webPreviewActivity") ?? palette.webPreviewActivity,
                                    webPreviewActivityBubble_incoming: parseColor(decoder, "webPreviewActivityBubble_incoming") ?? palette.webPreviewActivityBubble_incoming,
                                    webPreviewActivityBubble_outgoing: parseColor(decoder, "webPreviewActivityBubble_outgoing") ?? palette.webPreviewActivityBubble_outgoing,
                                    redBubble_incoming: parseColor(decoder, "redBubble_incoming") ?? palette.redBubble_incoming,
                                    redBubble_outgoing: parseColor(decoder, "redBubble_outgoing") ?? palette.redBubble_outgoing,
                                    greenBubble_incoming: parseColor(decoder, "greenBubble_incoming") ?? palette.greenBubble_incoming,
                                    greenBubble_outgoing: parseColor(decoder, "greenBubble_outgoing") ?? palette.greenBubble_outgoing,
                                    chatReplyTitle: parseColor(decoder, "chatReplyTitle") ?? palette.chatReplyTitle,
                                    chatReplyTextEnabled: parseColor(decoder, "chatReplyTextEnabled") ?? palette.chatReplyTextEnabled,
                                    chatReplyTextDisabled: parseColor(decoder, "chatReplyTextDisabled") ?? palette.chatReplyTextDisabled,
                                    chatReplyTitleBubble_incoming: parseColor(decoder, "chatReplyTitleBubble_incoming") ?? palette.chatReplyTitleBubble_incoming,
                                    chatReplyTitleBubble_outgoing: parseColor(decoder, "chatReplyTitleBubble_outgoing") ?? palette.chatReplyTitleBubble_outgoing,
                                    chatReplyTextEnabledBubble_incoming: parseColor(decoder, "chatReplyTextEnabledBubble_incoming") ?? palette.chatReplyTextEnabledBubble_incoming,
                                    chatReplyTextEnabledBubble_outgoing: parseColor(decoder, "chatReplyTextEnabledBubble_outgoing") ?? palette.chatReplyTextEnabledBubble_outgoing,
                                    chatReplyTextDisabledBubble_incoming: parseColor(decoder, "chatReplyTextDisabledBubble_incoming") ?? palette.chatReplyTextDisabledBubble_incoming,
                                    chatReplyTextDisabledBubble_outgoing: parseColor(decoder, "chatReplyTextDisabledBubble_outgoing") ?? palette.chatReplyTextDisabledBubble_outgoing,
                                    groupPeerNameRed: parseColor(decoder, "groupPeerNameRed") ?? palette.groupPeerNameRed,
                                    groupPeerNameOrange: parseColor(decoder, "groupPeerNameOrange") ?? palette.groupPeerNameOrange,
                                    groupPeerNameViolet:parseColor(decoder, "groupPeerNameViolet") ?? palette.groupPeerNameViolet,
                                    groupPeerNameGreen:parseColor(decoder, "groupPeerNameGreen") ?? palette.groupPeerNameGreen,
                                    groupPeerNameCyan: parseColor(decoder, "groupPeerNameCyan") ?? palette.groupPeerNameCyan,
                                    groupPeerNameLightBlue: parseColor(decoder, "groupPeerNameLightBlue") ?? palette.groupPeerNameLightBlue,
                                    groupPeerNameBlue: parseColor(decoder, "groupPeerNameBlue") ?? palette.groupPeerNameBlue,
                                    peerAvatarRedTop: parseColor(decoder, "peerAvatarRedTop") ?? palette.peerAvatarRedTop,
                                    peerAvatarRedBottom: parseColor(decoder, "peerAvatarRedBottom") ?? palette.peerAvatarRedBottom,
                                    peerAvatarOrangeTop: parseColor(decoder, "peerAvatarOrangeTop") ?? palette.peerAvatarOrangeTop,
                                    peerAvatarOrangeBottom: parseColor(decoder, "peerAvatarOrangeBottom") ?? palette.peerAvatarOrangeBottom,
                                    peerAvatarVioletTop: parseColor(decoder, "peerAvatarVioletTop") ?? palette.peerAvatarVioletTop,
                                    peerAvatarVioletBottom: parseColor(decoder, "peerAvatarVioletBottom") ?? palette.peerAvatarVioletBottom,
                                    peerAvatarGreenTop: parseColor(decoder, "peerAvatarGreenTop") ?? palette.peerAvatarGreenTop,
                                    peerAvatarGreenBottom: parseColor(decoder, "peerAvatarGreenBottom") ?? palette.peerAvatarGreenBottom,
                                    peerAvatarCyanTop: parseColor(decoder, "peerAvatarCyanTop") ?? palette.peerAvatarCyanTop,
                                    peerAvatarCyanBottom: parseColor(decoder, "peerAvatarCyanBottom") ?? palette.peerAvatarCyanBottom,
                                    peerAvatarBlueTop: parseColor(decoder, "peerAvatarBlueTop") ?? palette.peerAvatarBlueTop,
                                    peerAvatarBlueBottom: parseColor(decoder, "peerAvatarBlueBottom") ?? palette.peerAvatarBlueBottom,
                                    peerAvatarPinkTop: parseColor(decoder, "peerAvatarPinkTop") ?? palette.peerAvatarPinkTop,
                                    peerAvatarPinkBottom: parseColor(decoder, "peerAvatarPinkBottom") ?? palette.peerAvatarPinkBottom,
                                    bubbleBackgroundHighlight_incoming:  parseColor(decoder, "bubbleBackgroundHighlight_incoming") ?? palette.bubbleBackgroundHighlight_incoming,
                                    bubbleBackgroundHighlight_outgoing:  parseColor(decoder, "bubbleBackgroundHighlight_outgoing") ?? palette.bubbleBackgroundHighlight_outgoing,
                                    chatDateActive: parseColor(decoder, "chatDateActive") ?? palette.chatDateActive,
                                    chatDateText: parseColor(decoder, "chatDateText") ?? palette.chatDateText,
                                    revealAction_neutral1_background: parseColor(decoder, "revealAction_neutral1_background") ?? palette.revealAction_neutral1_background,
                                    revealAction_neutral1_foreground: parseColor(decoder, "revealAction_neutral1_foreground") ?? palette.revealAction_neutral1_foreground,
                                    revealAction_neutral2_background: parseColor(decoder, "revealAction_neutral2_background") ?? palette.revealAction_neutral2_background,
                                    revealAction_neutral2_foreground: parseColor(decoder, "revealAction_neutral2_foreground") ?? palette.revealAction_neutral2_foreground,
                                    revealAction_destructive_background: parseColor(decoder, "revealAction_destructive_background") ?? palette.revealAction_destructive_background,
                                    revealAction_destructive_foreground: parseColor(decoder, "revealAction_destructive_foreground") ?? palette.revealAction_destructive_foreground,
                                    revealAction_constructive_background: parseColor(decoder, "revealAction_constructive_background") ?? palette.revealAction_constructive_background,
                                    revealAction_constructive_foreground: parseColor(decoder, "revealAction_constructive_foreground") ?? palette.revealAction_constructive_foreground,
                                    revealAction_accent_background: parseColor(decoder, "revealAction_accent_background") ?? palette.revealAction_accent_background,
                                    revealAction_accent_foreground: parseColor(decoder, "revealAction_accent_foreground") ?? palette.revealAction_accent_foreground,
                                    revealAction_warning_background: parseColor(decoder, "revealAction_warning_background") ?? palette.revealAction_warning_background,
                                    revealAction_warning_foreground: parseColor(decoder, "revealAction_warning_foreground") ?? palette.revealAction_warning_foreground,
                                    revealAction_inactive_background: parseColor(decoder, "revealAction_inactive_background") ?? palette.revealAction_inactive_background,
                                    revealAction_inactive_foreground: parseColor(decoder, "revealAction_inactive_foreground") ?? palette.revealAction_inactive_foreground,
                                    chatBackground: parseColor(decoder, "chatBackground") ?? palette.chatBackground,
                                    listBackground: parseColor(decoder, "listBackground") ?? palette.listBackground,
                                    listGrayText: parseColor(decoder, "listGrayText") ?? palette.listBackground,
                                    grayHighlight: parseColor(decoder, "grayHighlight") ?? palette.grayHighlight
        )
    }
}

struct DefaultCloudTheme : Equatable, PostboxCoding {
    let cloud: TelegramTheme
    let palette: ColorPalette
    let wallpaper: AssociatedWallpaper
    
    init(cloud: TelegramTheme, palette: ColorPalette, wallpaper: AssociatedWallpaper) {
        self.cloud = cloud
        self.palette = palette
        self.wallpaper = wallpaper
    }
    
    init(decoder: PostboxDecoder) {
        self.cloud = decoder.decodeObjectForKey("c", decoder: { TelegramTheme(decoder: $0) }) as! TelegramTheme
        self.palette = decoder.decodeObjectForKey("p", decoder: { ColorPalette(decoder: $0) }) as! ColorPalette
        self.wallpaper = decoder.decodeObjectForKey("w", decoder: { AssociatedWallpaper(decoder: $0) }) as! AssociatedWallpaper
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.cloud, forKey: "c")
        encoder.encodeObject(self.palette, forKey: "p")
        encoder.encodeObject(self.wallpaper, forKey: "w")
    }
}



struct DefaultTheme : Equatable, PostboxCoding {
    let local: TelegramBuiltinTheme
    let cloud: DefaultCloudTheme?
    init(local: TelegramBuiltinTheme, cloud: DefaultCloudTheme?) {
        self.local = local
        self.cloud = cloud
    }
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.local.rawValue, forKey: "dl_1")
        if let cloud = cloud {
            encoder.encodeObject(cloud, forKey: "dc")
        } else {
            encoder.encodeNil(forKey: "dc")
        }
    }
    init(decoder: PostboxDecoder) {
        self.local = TelegramBuiltinTheme(rawValue: decoder.decodeStringForKey("dl_1", orElse: TelegramBuiltinTheme.dayClassic.rawValue)) ?? .dayClassic
        self.cloud = decoder.decodeObjectForKey("dc", decoder: { DefaultCloudTheme(decoder: $0) }) as? DefaultCloudTheme
    }
    func withUpdatedLocal(_ local: TelegramBuiltinTheme) -> DefaultTheme {
        return DefaultTheme(local: local, cloud: self.cloud)
    }
    func updateCloud(_ f: (DefaultCloudTheme?)->DefaultCloudTheme?) -> DefaultTheme {
        return DefaultTheme(local: self.local, cloud: f(self.cloud))
    }
}

struct LocalWallapper : Equatable, PostboxCoding {
    let name: TelegramBuiltinTheme
    let cloud: TelegramTheme?
    let wallpaper: AssociatedWallpaper
    
    init(name: TelegramBuiltinTheme, wallpaper: AssociatedWallpaper, cloud: TelegramTheme?) {
        self.name = name
        self.wallpaper = wallpaper
        self.cloud = cloud
    }
    
    init(decoder: PostboxDecoder) {
        self.name = TelegramBuiltinTheme(rawValue: decoder.decodeStringForKey("name", orElse: dayClassicPalette.name)) ?? .dayClassic
        self.wallpaper = decoder.decodeObjectForKey("aw", decoder: { AssociatedWallpaper(decoder: $0) }) as! AssociatedWallpaper
        self.cloud = decoder.decodeObjectForKey("cloud", decoder: { TelegramTheme(decoder: $0) }) as? TelegramTheme
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.wallpaper, forKey: "aw")
        encoder.encodeString(self.name.rawValue, forKey: "name")
        if let cloud = cloud {
            encoder.encodeObject(cloud, forKey: "cloud")
        } else {
            encoder.encodeNil(forKey: "cloud")
        }
    }
}

struct LocalAccentColor : Equatable, PostboxCoding {
    let name: TelegramBuiltinTheme
    let color: NSColor
    
    init(name: TelegramBuiltinTheme, color: NSColor) {
        self.name = name
        self.color = color
    }
    
    init(decoder: PostboxDecoder) {
        self.name = TelegramBuiltinTheme(rawValue: decoder.decodeStringForKey("name", orElse: dayClassicPalette.name)) ?? .dayClassic
        if let hex = decoder.decodeOptionalStringForKey("color"), let color = NSColor(hexString: hex) {
            self.color = color
        } else {
            self.color = self.name.palette.basicAccent
        }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.name.rawValue, forKey: "name")
        encoder.encodeString(self.color.hexString, forKey: "color")
    }
}

struct ThemePaletteSettings: PreferencesEntry, Equatable {
    let palette: ColorPalette
    let bubbled: Bool
    let defaultIsDark: Bool
    let fontSize: CGFloat
    let defaultDark: DefaultTheme
    let defaultDay: DefaultTheme
    let wallpapers: [LocalWallapper]
    let accents:[LocalAccentColor]
    let wallpaper: ThemeWallpaper
    let cloudTheme: TelegramTheme?
    
    init(palette: ColorPalette,
         bubbled: Bool,
         fontSize: CGFloat,
         wallpaper: ThemeWallpaper,
         defaultDark: DefaultTheme,
         defaultDay: DefaultTheme,
         defaultIsDark: Bool,
         wallpapers: [LocalWallapper],
         accents: [LocalAccentColor],
         cloudTheme: TelegramTheme?) {
        
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
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ThemePaletteSettings {
            return self == to
        } else {
            return false
        }
    }
    init(decoder: PostboxDecoder) {
        self.wallpaper = (decoder.decodeObjectForKey("wallpaper", decoder: { ThemeWallpaper(decoder: $0) }) as? ThemeWallpaper) ?? ThemeWallpaper()
        self.palette = ColorPalette(decoder: decoder)
        
        self.bubbled = decoder.decodeBoolForKey("bubbled", orElse: false)
        self.fontSize = CGFloat(decoder.decodeDoubleForKey("fontSize", orElse: 13))
        
        let defDark = DefaultTheme(local: .tintedNight, cloud: nil)
        let defDay = DefaultTheme(local: .dayClassic, cloud: nil)

        self.defaultDark = decoder.decodeObjectForKey("defaultDark_1", decoder: { DefaultTheme(decoder: $0) }) as? DefaultTheme ?? defDark
        self.defaultDay = decoder.decodeObjectForKey("defaultDay_1", decoder: { DefaultTheme(decoder: $0) }) as? DefaultTheme ?? defDay

        self.cloudTheme = decoder.decodeObjectForKey("cloudTheme", decoder: { TelegramTheme(decoder: $0) }) as? TelegramTheme
        
        self.wallpapers = (try? decoder.decodeObjectArrayWithCustomDecoderForKey("local_wallpapers", decoder: { LocalWallapper(decoder: $0) })) ?? []
        self.accents = (try? decoder.decodeObjectArrayWithCustomDecoderForKey("local_accents", decoder: { LocalAccentColor(decoder: $0) })) ?? []
        
        self.defaultIsDark = decoder.decodeBoolForKey("defaultIsDark", orElse: self.palette.isDark)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        
        self.palette.encode(encoder)
        encoder.encodeBool(bubbled, forKey: "bubbled")
        encoder.encodeDouble(Double(fontSize), forKey: "fontSize")
        encoder.encodeObject(wallpaper, forKey: "wallpaper")
        
        encoder.encodeObject(defaultDay, forKey: "defaultDay_1")
        encoder.encodeObject(defaultDark, forKey: "defaultDark_1")
        encoder.encodeObjectArray(self.wallpapers, forKey: "local_wallpapers")
        encoder.encodeObjectArray(self.accents, forKey: "local_accents")

        encoder.encodeBool(self.defaultIsDark, forKey: "defaultIsDark")

        
        if let cloudTheme = self.cloudTheme {
            encoder.encodeObject(cloudTheme, forKey: "cloudTheme")
        } else {
            encoder.encodeNil(forKey: "cloudTheme")
        }
    }
    
    func withUpdatedPalette(_ palette: ColorPalette) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme)
    }
    func withUpdatedBubbled(_ bubbled: Bool) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme)
    }
    func withUpdatedFontSize(_ fontSize: CGFloat) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: fontSize, wallpaper: self.wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme)
    }
    
    func updateWallpaper(_ f:(ThemeWallpaper)->ThemeWallpaper) -> ThemePaletteSettings {
        let updated = f(self.wallpaper)
        
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: updated, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme)
    }
    
    func saveDefaultWallpaper() -> ThemePaletteSettings {
        var wallpapers = self.wallpapers
        let local = LocalWallapper(name: self.palette.parent, wallpaper: AssociatedWallpaper(cloud: self.wallpaper.associated?.cloud, wallpaper: self.wallpaper.wallpaper), cloud: self.cloudTheme)
        
        if let cloud = cloudTheme {
            if let index = wallpapers.firstIndex(where: { $0.cloud?.id == cloud.id }) {
                wallpapers[index] = local
            } else {
                wallpapers.append(local)
            }
        } else {
            if let index = wallpapers.firstIndex(where: { $0.name == palette.parent }) {
                wallpapers[index] = local
            } else {
                wallpapers.append(local)
            }
        }
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: wallpapers, accents: self.accents, cloudTheme: self.cloudTheme)
    }
    
    func installDefaultWallpaper() -> ThemePaletteSettings {
        
        let wallpaper:ThemeWallpaper
        if palette.isDark {
            if let cloud = self.defaultDark.cloud {
                let first = self.wallpapers.first(where: { $0.cloud?.id == cloud.cloud.id })
                wallpaper = ThemeWallpaper(wallpaper: first?.wallpaper.wallpaper ?? .none, associated: cloud.wallpaper)
            } else {
                let first = self.wallpapers.first(where: { $0.name == self.palette.parent })
                wallpaper = ThemeWallpaper(wallpaper: first?.wallpaper.wallpaper ?? .none, associated: nil)
            }
        } else {
            if let cloud = self.defaultDay.cloud {
                let first = self.wallpapers.first(where: { $0.cloud?.id == cloud.cloud.id })
                wallpaper = ThemeWallpaper(wallpaper: first?.wallpaper.wallpaper ?? .none, associated: cloud.wallpaper)
            } else {
                let first = self.wallpapers.first(where: { $0.name == self.palette.parent })
                wallpaper = ThemeWallpaper(wallpaper: first?.wallpaper.wallpaper ?? .none, associated: nil)
            }
        }
        
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme)
    }
    
    func saveDefaultAccent(color: NSColor) -> ThemePaletteSettings {
        var accents = self.accents
        let local = LocalAccentColor(name: self.palette.parent, color: color)
        if let index = accents.firstIndex(where: { $0.name == palette.parent }) {
            accents[index] = local
        } else {
            accents.append(local)
        }
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: accents, cloudTheme: self.cloudTheme)
    }
    
    func installDefaultAccent() -> ThemePaletteSettings {
        let accent: LocalAccentColor? = self.accents.first(where: { $0.name == self.palette.parent })
        var palette: ColorPalette = self.palette.withoutAccentColor()
        if let accent = accent {
             palette = palette.withAccentColor(accent.color)
        }
        return ThemePaletteSettings(palette: palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme)
    }
    
    func withUpdatedDefaultDay(_ defaultDay: DefaultTheme) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: wallpaper, defaultDark: self.defaultDark, defaultDay: defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme)
    }
    func withUpdatedDefaultDark(_ defaultDark: DefaultTheme) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: wallpaper, defaultDark: defaultDark, defaultDay: self.defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme)
    }
    func withUpdatedDefaultIsDark(_ defaultIsDark: Bool) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: wallpaper, defaultDark: self.defaultDark, defaultDay: self.defaultDay, defaultIsDark: defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: self.cloudTheme)
    }
    func withUpdatedCloudTheme(_ cloudTheme: TelegramTheme?) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultDark: defaultDark, defaultDay: defaultDay, defaultIsDark: self.defaultIsDark, wallpapers: self.wallpapers, accents: self.accents, cloudTheme: cloudTheme)
    }
    
    
    func withUpdatedToDefault(dark: Bool, onlyLocal: Bool = false) -> ThemePaletteSettings {
        if dark {
            if let cloud = self.defaultDark.cloud, !onlyLocal {
                return self.withUpdatedPalette(cloud.palette)
                    .withUpdatedCloudTheme(cloud.cloud)
                    .installDefaultWallpaper()
            } else {
                return self.withUpdatedPalette(self.defaultDark.local.palette)
                    .withUpdatedCloudTheme(nil)
                    .installDefaultWallpaper().installDefaultAccent()
            }
        } else {
            if let cloud = self.defaultDay.cloud, !onlyLocal {
                return self.withUpdatedPalette(cloud.palette)
                    .withUpdatedCloudTheme(cloud.cloud)
                    .installDefaultWallpaper()
            } else {
                return self.withUpdatedPalette(self.defaultDay.local.palette)
                    .withUpdatedCloudTheme(nil)
                    .installDefaultWallpaper().installDefaultAccent()
            }
        }
    }
    
    static var defaultTheme: ThemePaletteSettings {
        let defDark = DefaultTheme(local: .tintedNight, cloud: nil)
        let defDay = DefaultTheme(local: .dayClassic, cloud: nil)
        return ThemePaletteSettings(palette: dayClassicPalette, bubbled: false, fontSize: 13, wallpaper: ThemeWallpaper(), defaultDark: defDark, defaultDay: defDay, defaultIsDark: false, wallpapers: [LocalWallapper(name: .dayClassic, wallpaper: AssociatedWallpaper(cloud: nil, wallpaper: .builtin), cloud: nil)], accents: [], cloudTheme: nil)
    }
}

func ==(lhs: ThemePaletteSettings, rhs: ThemePaletteSettings) -> Bool {
    return lhs.palette == rhs.palette &&
    lhs.fontSize == rhs.fontSize &&
    lhs.bubbled == rhs.bubbled &&
    lhs.wallpaper == rhs.wallpaper &&
    lhs.defaultDay == rhs.defaultDay &&
    lhs.defaultDark == rhs.defaultDark &&
    lhs.cloudTheme == rhs.cloudTheme &&
    lhs.wallpapers == rhs.wallpapers &&
    lhs.accents == rhs.accents &&
    lhs.defaultIsDark == rhs.defaultIsDark
}


func themeSettingsView(accountManager: AccountManager)-> Signal<ThemePaletteSettings, NoError> {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.themeSettings]) |> map { $0.entries[ApplicationSharedPreferencesKeys.themeSettings] as? ThemePaletteSettings ?? ThemePaletteSettings.defaultTheme }
}

func themeUnmodifiedSettings(accountManager: AccountManager)-> Signal<ThemePaletteSettings, NoError> {
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.themeSettings]) |> map { $0.entries[ApplicationSharedPreferencesKeys.themeSettings] as? ThemePaletteSettings ?? ThemePaletteSettings.defaultTheme }
}


func updateThemeInteractivetly(accountManager: AccountManager, f:@escaping (ThemePaletteSettings)->ThemePaletteSettings)-> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSharedPreferencesKeys.themeSettings, { entry in
            return f(entry as? ThemePaletteSettings ?? ThemePaletteSettings.defaultTheme)
        })
    }
}
