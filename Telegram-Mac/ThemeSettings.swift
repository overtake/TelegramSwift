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
import TGUIKit

public enum PresentationThemeParsingError: Error {
    case generic
}

private func parseColor(_ decoder: PostboxDecoder, _ key: String) -> NSColor {
    if let value = decoder.decodeOptionalInt32ForKey(key) {
        return NSColor(argb: UInt32(bitPattern: value))
    } else {
        return NSColor(0x000000)
    }
}

struct ThemePalleteSettings: PreferencesEntry, Equatable {
    let background: NSColor
    let text: NSColor
    let grayText:NSColor
    let link:NSColor
    let blueUI:NSColor
    let redUI:NSColor
    let greenUI:NSColor
    let blackTransparent:NSColor
    let grayTransparent:NSColor
    let grayUI:NSColor
    let darkGrayText:NSColor
    let blueText:NSColor
    let blueSelect:NSColor
    let selectText:NSColor
    let blueFill:NSColor
    let border:NSColor
    let grayBackground:NSColor
    let grayForeground:NSColor
    let grayIcon:NSColor
    let blueIcon:NSColor
    let badgeMuted:NSColor
    let badge:NSColor
    let indicatorColor: NSColor
    let selectMessage: NSColor
    let dark: Bool
    
    let fontSize: CGFloat
    
    init(background:NSColor, text: NSColor, grayText: NSColor, link: NSColor, blueUI:NSColor, redUI:NSColor, greenUI:NSColor, blackTransparent:NSColor, grayTransparent:NSColor, grayUI:NSColor, darkGrayText:NSColor, blueText:NSColor, blueSelect:NSColor, selectText:NSColor, blueFill:NSColor, border:NSColor, grayBackground:NSColor, grayForeground:NSColor, grayIcon:NSColor, blueIcon:NSColor, badgeMuted:NSColor, badge:NSColor, indicatorColor: NSColor, selectMessage: NSColor, dark:Bool, fontSize: CGFloat) {
        self.background = background
        self.text = text
        self.grayText = grayText
        self.link = link
        self.blueUI = blueUI
        self.redUI = redUI
        self.greenUI = greenUI
        self.blackTransparent = blackTransparent
        self.grayTransparent = grayTransparent
        self.grayUI = grayUI
        self.darkGrayText = darkGrayText
        self.blueText = blueText
        self.blueSelect = blueSelect
        self.selectText = selectText
        self.blueFill = blueFill
        self.border = border
        self.grayBackground = grayBackground
        self.grayForeground = grayForeground
        self.grayIcon = grayIcon
        self.blueIcon = blueIcon
        self.badgeMuted = badgeMuted
        self.badge = badge
        self.indicatorColor = indicatorColor
        self.selectMessage = selectMessage
        self.dark = dark
        self.fontSize = fontSize
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ThemePalleteSettings {
            return self == to
        } else {
            return false
        }
    }
    init(decoder: PostboxDecoder) {
        self.background = parseColor(decoder, "background")
        self.text = parseColor(decoder, "text")
        self.grayText = parseColor(decoder, "grayText")
        self.link = parseColor(decoder, "link")
        self.blueUI = parseColor(decoder, "blueUI")
        self.redUI = parseColor(decoder, "redUI")
        self.greenUI = parseColor(decoder, "greenUI")
        self.blackTransparent = parseColor(decoder, "blackTransparent")
        self.grayTransparent = parseColor(decoder, "grayTransparent")
        self.grayUI = parseColor(decoder, "grayUI")
        self.darkGrayText = parseColor(decoder, "darkGrayText")
        self.blueText = parseColor(decoder, "blueText")
        self.blueSelect = parseColor(decoder, "blueSelect")
        self.selectText = parseColor(decoder, "selectText")
        self.blueFill = parseColor(decoder, "blueFill")
        self.border = parseColor(decoder, "border")
        self.grayBackground = parseColor(decoder, "grayBackground")
        self.grayForeground = parseColor(decoder, "grayForeground")
        self.grayIcon = parseColor(decoder, "grayIcon")
        self.blueIcon = parseColor(decoder, "blueIcon")
        self.badgeMuted = parseColor(decoder, "badgeMuted")
        self.badge = parseColor(decoder, "badge")
        self.indicatorColor = parseColor(decoder, "indicatorColor")
        self.selectMessage = parseColor(decoder, "selectMessage")
        self.dark = decoder.decodeBoolForKey("dark", orElse: false)
        self.fontSize = CGFloat(decoder.decodeDoubleForKey("fontSize", orElse: 13.0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: self).children {
            if let label = child.label {
                if let value = child.value as? NSColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                }
            }
        }
        encoder.encodeBool(dark, forKey: "dark")
        encoder.encodeDouble(Double(fontSize), forKey: "fontSize")
    }
    
    
    static var defaultTheme: ThemePalleteSettings {
        return ThemePalleteSettings(whitePallete, dark: false, fontSize: 13.0)
    }
}

func ==(lhs: ThemePalleteSettings, rhs: ThemePalleteSettings) -> Bool {
    return lhs.background == rhs.background &&
    lhs.text == rhs.text &&
    lhs.grayText == rhs.grayText &&
    lhs.link == rhs.link &&
    lhs.blueUI == rhs.blueUI &&
    lhs.redUI == rhs.redUI &&
    lhs.greenUI == rhs.greenUI &&
    lhs.blackTransparent == rhs.blackTransparent &&
    lhs.grayTransparent == rhs.grayTransparent &&
    lhs.grayUI == rhs.grayUI &&
    lhs.darkGrayText == rhs.darkGrayText &&
    lhs.blueText == rhs.blueText &&
    lhs.blueSelect == rhs.blueSelect &&
    lhs.selectText == rhs.selectText &&
    lhs.blueFill == rhs.blueFill &&
    lhs.border == rhs.border &&
    lhs.grayBackground == rhs.grayBackground &&
    lhs.grayForeground == rhs.grayForeground &&
    lhs.grayIcon == rhs.grayIcon &&
    lhs.blueIcon == rhs.blueIcon &&
    lhs.badgeMuted == rhs.badgeMuted &&
    lhs.badge == rhs.badge &&
    lhs.indicatorColor == rhs.indicatorColor &&
    lhs.selectMessage == rhs.selectMessage &&
    lhs.dark == rhs.dark &&
    lhs.fontSize == rhs.fontSize
}

extension ThemePalleteSettings {
    init(_ pallete: ColorPallete, dark: Bool, fontSize: CGFloat) {
        self.init(background: pallete.background, text: pallete.text, grayText: pallete.grayText, link: pallete.link, blueUI: pallete.blueUI, redUI: pallete.redUI, greenUI: pallete.greenUI, blackTransparent: pallete.blackTransparent, grayTransparent: pallete.grayTransparent, grayUI: pallete.grayUI, darkGrayText: pallete.darkGrayText, blueText: pallete.blueText, blueSelect: pallete.blueSelect, selectText: pallete.selectText, blueFill: pallete.blueFill, border: pallete.border, grayBackground: pallete.grayBackground, grayForeground: pallete.grayForeground, grayIcon: pallete.grayIcon, blueIcon: pallete.blueIcon, badgeMuted: pallete.badgeMuted, badge: pallete.badge, indicatorColor: pallete.indicatorColor, selectMessage: pallete.selectMessage, dark: dark, fontSize: fontSize)
    }
}

func updateThemeSettings(postbox: Postbox, pallete: ColorPallete, dark: Bool) -> Signal<Void, Void> {
    return postbox.modify { modifier -> Void in
        modifier.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.themeSettings, { entry in
            let current = entry as? ThemePalleteSettings
            return ThemePalleteSettings(pallete, dark: dark, fontSize: current?.fontSize ?? 13.0)
        })
    }
}

func updateApplicationFontSize(postbox: Postbox, fontSize: CGFloat) -> Signal<Void, Void> {
    return postbox.modify { modifier -> Void in
        modifier.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.themeSettings, { entry in
            let current = entry as? ThemePalleteSettings ?? ThemePalleteSettings.defaultTheme
            return ThemePalleteSettings(ColorPallete(current), dark: current.dark, fontSize: fontSize)
        })
    }
}
