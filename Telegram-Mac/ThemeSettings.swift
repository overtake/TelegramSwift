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
        default:
            return .none
        }
    }
}

struct StandartPaletteWallpaper : Equatable, PostboxCoding {
    let paletteName: TelegramBuiltinTheme
    let wallpaper: Wallpaper
    
    init(paletteName: TelegramBuiltinTheme, wallpaper: Wallpaper) {
        self.paletteName = paletteName
        self.wallpaper = wallpaper
    }
    
    init(decoder: PostboxDecoder) {
        self.paletteName = TelegramBuiltinTheme(rawValue: decoder.decodeStringForKey("pn", orElse: dayClassicPalette.name)) ?? .dayClassic
        self.wallpaper = decoder.decodeObjectForKey("tw", decoder: { Wallpaper(decoder: $0) }) as! Wallpaper
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.wallpaper, forKey: "tw")
        encoder.encodeString(self.paletteName.rawValue, forKey: "pn")
    }
}

struct AssociatedWallpaper : PostboxCoding, Equatable {
    let cloud: TelegramWallpaper?
    let wallpaper: Wallpaper
    init(decoder: PostboxDecoder) {
        self.cloud = decoder.decodeObjectForKey("c", decoder: { TelegramWallpaper(decoder: $0) }) as? TelegramWallpaper
        self.wallpaper = decoder.decodeObjectForKey("w", decoder: { Wallpaper(decoder: $0) }) as! Wallpaper
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

struct ThemePaletteSettings: PreferencesEntry, Equatable {
    let palette: ColorPalette
    let followSystemAppearance: Bool
    let bubbled: Bool
    let fontSize: CGFloat
    let defaultNightName: String
    let defaultDayName: String
    let wallpaper: ThemeWallpaper
    let cloudTheme: TelegramTheme?
    fileprivate let standartWallpapers: [StandartPaletteWallpaper]
    
    init(palette: ColorPalette,
         bubbled: Bool,
         fontSize: CGFloat,
         wallpaper: ThemeWallpaper,
         defaultNightName: String,
         defaultDayName: String,
         followSystemAppearance: Bool,
         standartWallpapers: [StandartPaletteWallpaper],
         cloudTheme: TelegramTheme?) {
        
        self.palette = palette
        self.bubbled = bubbled
        self.fontSize = fontSize
        self.wallpaper = wallpaper
        self.defaultNightName = defaultNightName
        self.defaultDayName = defaultDayName
        self.followSystemAppearance = followSystemAppearance
        self.standartWallpapers = standartWallpapers
        self.cloudTheme = cloudTheme
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
        self.standartWallpapers = (try? decoder.decodeObjectArrayWithCustomDecoderForKey("standart_w", decoder: {StandartPaletteWallpaper(decoder: $0)})) ?? []
        
        let dark = decoder.decodeBoolForKey("dark", orElse: false)
        let tinted = decoder.decodeBoolForKey("tinted", orElse: false)
        
        let parent: TelegramBuiltinTheme = TelegramBuiltinTheme(rawValue: decoder.decodeStringForKey("parent", orElse: TelegramBuiltinTheme.dayClassic.rawValue)) ?? (dark ? .nightBlue : .dayClassic)
        let copyright = decoder.decodeStringForKey("copyright", orElse: "Telegram")

        let isNative = decoder.decodeBoolForKey("isNative", orElse: false)
        let name = decoder.decodeStringForKey("name", orElse: "Default")

        let palette: ColorPalette = parent.palette
        let pw = PaletteWallpaper(decoder.decodeStringForKey("pw", orElse: "none"))
        
        let accentList = decoder.decodeStringForKey("accentList", orElse: "").components(separatedBy: ",").compactMap { NSColor(hexString: $0) }
        
        self.palette = ColorPalette(isNative: isNative,
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
            chatBackground: parseColor(decoder, "chatBackground") ?? palette.chatBackground
        )
        
        self.bubbled = decoder.decodeBoolForKey("bubbled", orElse: false)
        self.fontSize = CGFloat(decoder.decodeDoubleForKey("fontSize", orElse: 13))
        self.defaultNightName = decoder.decodeStringForKey("defaultNightName", orElse: nightBluePalette.name)
        self.defaultDayName = decoder.decodeStringForKey("defaultDayName", orElse: dayClassicPalette.name)
        self.followSystemAppearance = decoder.decodeBoolForKey("fsa", orElse: false)
        self.cloudTheme = decoder.decodeObjectForKey("cloudTheme", decoder: { TelegramTheme(decoder: $0) }) as? TelegramTheme
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: palette).children {
            if let label = child.label {
                if let value = child.value as? NSColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                }
            }
        }
        encoder.encodeBool(palette.isNative, forKey: "isNative")
        encoder.encodeString(palette.name, forKey: "name")
        encoder.encodeString(palette.copyright, forKey: "copyright")
        encoder.encodeString(palette.parent.rawValue, forKey: "parent")
        encoder.encodeBool(palette.isDark, forKey: "dark")
        encoder.encodeBool(palette.tinted, forKey: "tinted")
        encoder.encodeBool(bubbled, forKey: "bubbled")
        encoder.encodeDouble(Double(fontSize), forKey: "fontSize")
        encoder.encodeObject(wallpaper, forKey: "wallpaper")
        encoder.encodeString(defaultDayName, forKey: "defaultDayName")
        encoder.encodeString(defaultNightName, forKey: "defaultNightName")
        encoder.encodeBool(followSystemAppearance, forKey: "fsa")
        encoder.encodeObjectArray(standartWallpapers, forKey: "standart_w")
        
        encoder.encodeString(palette.wallpaper.toString, forKey: "pw")
        encoder.encodeString(palette.accentList.map {$0.hexString}.joined(separator: ","), forKey: "accentList")
                
        if let cloudTheme = self.cloudTheme {
            encoder.encodeObject(cloudTheme, forKey: "cloudTheme")
        } else {
            encoder.encodeNil(forKey: "cloudTheme")
        }
    }
    
    func withUpdatedPalette(_ palette: ColorPalette) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: wallpaper, defaultNightName: self.defaultNightName, defaultDayName: self.defaultDayName, followSystemAppearance: self.followSystemAppearance, standartWallpapers: self.standartWallpapers, cloudTheme: self.cloudTheme)
    }
    func withUpdatedBubbled(_ bubbled: Bool) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultNightName: self.defaultNightName, defaultDayName: self.defaultDayName, followSystemAppearance: self.followSystemAppearance, standartWallpapers: self.standartWallpapers, cloudTheme: self.cloudTheme)
    }
    func withUpdatedFontSize(_ fontSize: CGFloat) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: fontSize, wallpaper: self.wallpaper, defaultNightName: self.defaultNightName, defaultDayName: self.defaultDayName, followSystemAppearance: self.followSystemAppearance, standartWallpapers: self.standartWallpapers, cloudTheme: self.cloudTheme)
    }
    func withUpdatedFollowSystemAppearance(_ followSystemAppearance: Bool) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultNightName: self.defaultNightName, defaultDayName: self.defaultDayName, followSystemAppearance: followSystemAppearance, standartWallpapers: self.standartWallpapers, cloudTheme: self.cloudTheme)
    }
    
    func updateWallpaper(_ f:(ThemeWallpaper)->ThemeWallpaper) -> ThemePaletteSettings {
        let updated = f(self.wallpaper)
        var standartWallpapers = self.standartWallpapers
        if self.cloudTheme == nil {
            if let index = standartWallpapers.firstIndex(where: {$0.paletteName == self.palette.parent}) {
                standartWallpapers[index] = StandartPaletteWallpaper(paletteName: self.palette.parent, wallpaper: updated.wallpaper)
            } else {
                standartWallpapers.append(StandartPaletteWallpaper(paletteName: self.palette.parent, wallpaper: updated.wallpaper))
            }
        }
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: updated, defaultNightName: self.defaultNightName, defaultDayName: self.defaultDayName, followSystemAppearance: self.followSystemAppearance, standartWallpapers: standartWallpapers, cloudTheme: self.cloudTheme)
    }
    
    func withUpdatedDefaultDayName(_ defaultDayName: String) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: wallpaper, defaultNightName: self.defaultNightName, defaultDayName: defaultDayName, followSystemAppearance: self.followSystemAppearance, standartWallpapers: self.standartWallpapers, cloudTheme: self.cloudTheme)
    }
    func withUpdatedDefaultNightName(_ defaultNightName: String) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: wallpaper, defaultNightName: defaultNightName, defaultDayName: self.defaultDayName, followSystemAppearance: self.followSystemAppearance, standartWallpapers: self.standartWallpapers, cloudTheme: self.cloudTheme)
    }
    func withUpdatedCloudTheme(_ cloudTheme: TelegramTheme?) -> ThemePaletteSettings {
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultNightName: self.defaultNightName, defaultDayName: self.defaultDayName, followSystemAppearance: self.followSystemAppearance, standartWallpapers: self.standartWallpapers, cloudTheme: cloudTheme)
    }
    func withStandartWallpaper() -> ThemePaletteSettings {
        let standart = self.standartWallpapers.first(where: { $0.paletteName == self.palette.parent })?.wallpaper
        
        let wallpaper = ThemeWallpaper(wallpaper: standart ?? self.palette.wallpaper.wallpaper, associated: nil)
        
        return ThemePaletteSettings(palette: self.palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: wallpaper, defaultNightName: self.defaultNightName, defaultDayName: self.defaultDayName, followSystemAppearance: self.followSystemAppearance, standartWallpapers: self.standartWallpapers, cloudTheme: self.cloudTheme)
    }
    func withUpdatedPaletteToDefault() -> ThemePaletteSettings {
        var palettes:[String : ColorPalette] = [:]
        palettes[dayClassicPalette.name] = dayClassicPalette
        palettes[whitePalette.name] = whitePalette
        palettes[darkPalette.name] = darkPalette
        palettes[nightBluePalette.name] = nightBluePalette
        palettes[mojavePalette.name] = mojavePalette
        let palette: ColorPalette
        if self.palette.isDark {
            palette = palettes[self.defaultNightName] ?? nightBluePalette
        } else {
            palette = palettes[self.defaultDayName] ?? dayClassicPalette
        }
        return ThemePaletteSettings(palette: palette, bubbled: self.bubbled, fontSize: self.fontSize, wallpaper: self.wallpaper, defaultNightName: self.defaultNightName, defaultDayName: self.defaultDayName, followSystemAppearance: self.followSystemAppearance, standartWallpapers: self.standartWallpapers, cloudTheme: self.cloudTheme)
    }
    
    static var defaultTheme: ThemePaletteSettings {
        let followSystemAppearance: Bool
        let defaultNightName: String
        if #available(OSX 10.14, *) {
            followSystemAppearance = true
            defaultNightName = nightBluePalette.name
        } else {
            followSystemAppearance = false
            defaultNightName = nightBluePalette.name
        }
        return ThemePaletteSettings(palette: dayClassicPalette, bubbled: false, fontSize: 13, wallpaper: ThemeWallpaper(), defaultNightName: defaultNightName, defaultDayName: dayClassicPalette.name, followSystemAppearance: followSystemAppearance, standartWallpapers: [], cloudTheme: nil)
    }
}

func ==(lhs: ThemePaletteSettings, rhs: ThemePaletteSettings) -> Bool {
    return lhs.palette == rhs.palette &&
    lhs.fontSize == rhs.fontSize &&
    lhs.bubbled == rhs.bubbled &&
    lhs.wallpaper == rhs.wallpaper &&
    lhs.defaultNightName == rhs.defaultNightName &&
    lhs.defaultDayName == rhs.defaultDayName &&
    lhs.followSystemAppearance == rhs.followSystemAppearance &&
    lhs.standartWallpapers == rhs.standartWallpapers &&
    lhs.cloudTheme == rhs.cloudTheme
}


func themeSettingsView(accountManager: AccountManager)-> Signal<ThemePaletteSettings, NoError> {
    
    return accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.themeSettings]) |> map { $0.entries[ApplicationSharedPreferencesKeys.themeSettings] as? ThemePaletteSettings ?? ThemePaletteSettings.defaultTheme } |> map { settings in
        if #available(OSX 10.14, *), settings.followSystemAppearance {
            let pallete: ColorPalette
            switch NSApp.effectiveAppearance.name {
            case NSAppearance.Name.aqua:
                switch settings.defaultDayName {
                case dayClassicPalette.name:
                    pallete = dayClassicPalette
                case whitePalette.name:
                    pallete = whitePalette.withAccentColor(settings.palette.accent)
                default:
                    pallete = dayClassicPalette
                }
            case NSAppearance.Name.darkAqua:
                switch settings.defaultNightName {
                case nightBluePalette.name:
                    pallete = nightBluePalette.withAccentColor(settings.palette.accent)
                case mojavePalette.name:
                    
                    pallete = mojavePalette.withAccentColor(settings.palette.accent)
                default:
                    pallete = nightBluePalette.withAccentColor(settings.palette.accent)
                }
                
            default:
                pallete = settings.palette
            }
            return settings.withUpdatedPalette(pallete)
        } else {
            return settings
        }
    }
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
