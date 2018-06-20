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

struct ThemePaletteSettings: PreferencesEntry, Equatable {
    let palette: ColorPalette
    
    let bubbled: Bool
    let fontSize: CGFloat
    let defaultNightName: String
    let defaultDayName: String
    let wallpaper: TelegramWallpaper
    init(palette: ColorPalette,
         bubbled: Bool,
         fontSize: CGFloat,
         wallpaper: TelegramWallpaper,
         defaultNightName: String,
         defaultDayName: String) {
        
        self.palette = palette
        self.bubbled = bubbled
        self.fontSize = fontSize
        self.wallpaper = wallpaper
        self.defaultNightName = defaultNightName
        self.defaultDayName = defaultDayName
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ThemePaletteSettings {
            return self == to
        } else {
            return false
        }
    }
    init(decoder: PostboxDecoder) {
        
        self.wallpaper = (decoder.decodeObjectForKey("w", decoder: { TelegramWallpaper(decoder: $0) }) as? TelegramWallpaper) ?? .none
        
        let dark = decoder.decodeBoolForKey("dark", orElse: false)
        let name = decoder.decodeStringForKey("name", orElse: "Default")

        let palette: ColorPalette = dark ? nightBluePalette : whitePalette
        
        self.palette = ColorPalette(isDark: dark,
            name: name,
            background: parseColor(decoder, "background") ?? palette.background,
            text: parseColor(decoder, "text") ?? palette.text,
            grayText: parseColor(decoder, "grayText") ?? palette.grayText,
            link: parseColor(decoder, "link") ?? palette.link,
            blueUI: parseColor(decoder, "blueUI") ?? palette.blueUI,
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
            chatDateText: parseColor(decoder, "chatDateText") ?? palette.chatDateText)
        
        
        
        
        self.bubbled = decoder.decodeBoolForKey("bubbled", orElse: false)
        self.fontSize = CGFloat(decoder.decodeDoubleForKey("fontSize", orElse: 13))
        self.defaultNightName = decoder.decodeStringForKey("defaultNightName", orElse: nightBluePalette.name)
        self.defaultDayName = decoder.decodeStringForKey("defaultDayName", orElse: dayClassic.name)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: palette).children {
            if let label = child.label {
                if let value = child.value as? NSColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                }
            }
        }
        encoder.encodeString(palette.name, forKey: "name")
        encoder.encodeBool(palette.isDark, forKey: "dark")
        encoder.encodeBool(bubbled, forKey: "bubbled")
        encoder.encodeDouble(Double(fontSize), forKey: "fontSize")
        encoder.encodeObject(wallpaper, forKey: "w")
        encoder.encodeString(defaultDayName, forKey: "defaultDayName")
        encoder.encodeString(defaultNightName, forKey: "defaultNightName")
    }
    
    
    static var defaultTheme: ThemePaletteSettings {
        return ThemePaletteSettings(palette: dayClassic, bubbled: false, fontSize: 13, wallpaper: .none, defaultNightName: nightBluePalette.name, defaultDayName: dayClassic.name)
    }
}

func ==(lhs: ThemePaletteSettings, rhs: ThemePaletteSettings) -> Bool {
    return lhs.palette === rhs.palette &&
    lhs.fontSize == rhs.fontSize &&
    lhs.bubbled == rhs.bubbled &&
    lhs.wallpaper == rhs.wallpaper &&
    lhs.defaultNightName == rhs.defaultNightName &&
    lhs.defaultDayName == rhs.defaultDayName
}


func updateThemeSettings(postbox: Postbox, palette: ColorPalette) -> Signal<Void, Void> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.themeSettings, { entry in
            let current = entry as? ThemePaletteSettings ?? ThemePaletteSettings.defaultTheme
            return ThemePaletteSettings(palette: palette, bubbled: current.bubbled, fontSize: current.fontSize, wallpaper: current.wallpaper, defaultNightName: current.defaultNightName, defaultDayName: current.defaultDayName)
        })
    }
}

func updateThemeInteractivetly(postbox: Postbox, f:@escaping (ThemePaletteSettings)->ThemePaletteSettings)-> Signal<Void, Void> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.themeSettings, { entry in
            let current = f(entry as? ThemePaletteSettings ?? ThemePaletteSettings.defaultTheme)
            return ThemePaletteSettings(palette: current.palette, bubbled: current.bubbled, fontSize: current.fontSize, wallpaper: current.wallpaper, defaultNightName: current.defaultNightName, defaultDayName: current.defaultDayName)
        })
    }
}

func updateBubbledSettings(postbox: Postbox, bubbled: Bool) -> Signal<Void, Void> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.themeSettings, { entry in
            let current = entry as? ThemePaletteSettings ?? ThemePaletteSettings.defaultTheme
            return ThemePaletteSettings(palette: current.palette, bubbled: bubbled, fontSize: current.fontSize, wallpaper: !bubbled ? .color(Int32(current.palette.background.rgb)) : (current.palette == dayClassic ? .builtin : current.wallpaper), defaultNightName: current.defaultNightName, defaultDayName: current.defaultDayName)
        })
    }
}

func updateApplicationFontSize(postbox: Postbox, fontSize: CGFloat) -> Signal<Void, Void> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.themeSettings, { entry in
            let current = entry as? ThemePaletteSettings ?? ThemePaletteSettings.defaultTheme
            return ThemePaletteSettings(palette: current.palette, bubbled: current.bubbled, fontSize: fontSize, wallpaper: current.wallpaper, defaultNightName: current.defaultNightName, defaultDayName: current.defaultDayName)
        })
    }
}

func updateApplicationWallpaper(postbox: Postbox, wallpaper: TelegramWallpaper) -> Signal<Void, Void> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.themeSettings, { entry in
            let current = entry as? ThemePaletteSettings ?? ThemePaletteSettings.defaultTheme
            return ThemePaletteSettings(palette: current.palette, bubbled: current.bubbled, fontSize: current.fontSize, wallpaper: wallpaper, defaultNightName: current.defaultNightName, defaultDayName: current.defaultDayName)
        })
    }
}
