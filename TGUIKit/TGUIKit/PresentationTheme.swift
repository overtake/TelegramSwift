//
//  PresentationTheme.swift
//  Telegram
//
//  Created by keepcoder on 22/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac

//





public struct SearchTheme {
    public let backgroundColor: NSColor
    public let searchImage:CGImage
    public let clearImage:CGImage
    public let placeholder:()->String
    public let textColor: NSColor
    public let placeholderColor: NSColor
    public init(_ backgroundColor: NSColor, _ searchImage:CGImage, _ clearImage:CGImage, _ placeholder:@escaping()->String, _ textColor: NSColor, _ placeholderColor: NSColor) {
        self.backgroundColor = backgroundColor
        self.searchImage = searchImage
        self.clearImage = clearImage
        self.placeholder = placeholder
        self.textColor = textColor
        self.placeholderColor = placeholderColor
    }
}

public enum PaletteWallpaper : Equatable {
    case none
    case url(String)
    case builtin
    case color(NSColor)
    public init?(_ string: String) {
        switch string {
        case "none":
            self = .none
        case "builtin":
            self = .builtin
        default:
            if string.hasPrefix("t.me/bg/") || string.hasPrefix("https://t.me/bg/") || string.hasPrefix("http://t.me/bg/") {
                self = .url(string)
            } else if let color = NSColor(hexString: string) {
                self = .color(color)
            } else {
                return nil
            }
        }
    }
    
    public var toString: String {
        switch self {
        case .builtin:
            return "builtin"
        case .none:
            return "none"
        case let .color(color):
            return color.hexString
        case let .url(string):
            return string
        }
    }
}

public struct ColorPalette : Equatable {
    
    public let isNative: Bool
    
    public let isDark: Bool
    public let tinted: Bool
    public let name: String
    public let copyright:String
    public let parent: TelegramBuiltinTheme
    public let wallpaper: PaletteWallpaper
    
    public let basicAccent: NSColor
    
    public let accentList:[NSColor]
    
    public let background: NSColor
    public let text: NSColor
    public let grayText:NSColor
    public let link:NSColor
    public let accent:NSColor
    public let redUI:NSColor
    public let greenUI:NSColor
    public let blackTransparent:NSColor
    public let grayTransparent:NSColor
    public let grayUI:NSColor
    public let darkGrayText:NSColor
    public let blueText:NSColor
    public let blueSelect:NSColor
    public let selectText:NSColor
    public let blueFill:NSColor
    public let border:NSColor
    public let grayBackground:NSColor
    public let grayForeground:NSColor
    
    public let grayIcon:NSColor
    public let blueIcon:NSColor
    public let badgeMuted:NSColor
    public let badge:NSColor
    public let indicatorColor: NSColor
    public let selectMessage: NSColor
    
    
    // chat
    public let monospacedPre: NSColor
    public let monospacedCode: NSColor
    public let monospacedPreBubble_incoming: NSColor
    public let monospacedPreBubble_outgoing: NSColor
    public let monospacedCodeBubble_incoming: NSColor
    public let monospacedCodeBubble_outgoing: NSColor
    public let selectTextBubble_incoming: NSColor
    public let selectTextBubble_outgoing: NSColor
    public let bubbleBackground_incoming: NSColor
    public let bubbleBackground_outgoing: NSColor
    public let bubbleBorder_incoming: NSColor
    public let bubbleBorder_outgoing: NSColor
    public let grayTextBubble_incoming: NSColor
    public let grayTextBubble_outgoing: NSColor
    public let grayIconBubble_incoming: NSColor
    public let grayIconBubble_outgoing: NSColor
    public let blueIconBubble_incoming: NSColor
    public let blueIconBubble_outgoing: NSColor
    public let linkBubble_incoming: NSColor
    public let linkBubble_outgoing: NSColor
    public let textBubble_incoming: NSColor
    public let textBubble_outgoing: NSColor
    public let selectMessageBubble: NSColor
    public let fileActivityBackground: NSColor
    public let fileActivityForeground: NSColor
    public let fileActivityBackgroundBubble_incoming: NSColor
    public let fileActivityBackgroundBubble_outgoing: NSColor
    public let fileActivityForegroundBubble_incoming: NSColor
    public let fileActivityForegroundBubble_outgoing: NSColor
    public let waveformBackground: NSColor
    public let waveformForeground: NSColor
    public let waveformBackgroundBubble_incoming: NSColor
    public let waveformBackgroundBubble_outgoing: NSColor
    public let waveformForegroundBubble_incoming: NSColor
    public let waveformForegroundBubble_outgoing: NSColor
    public let webPreviewActivity: NSColor
    public let webPreviewActivityBubble_incoming: NSColor
    public let webPreviewActivityBubble_outgoing: NSColor
    public let redBubble_incoming:NSColor
    public let redBubble_outgoing:NSColor
    public let greenBubble_incoming:NSColor
    public let greenBubble_outgoing:NSColor
    
    public let chatReplyTitle: NSColor
    public let chatReplyTextEnabled: NSColor
    public let chatReplyTextDisabled: NSColor
    public let chatReplyTitleBubble_incoming: NSColor
    public let chatReplyTitleBubble_outgoing: NSColor
    public let chatReplyTextEnabledBubble_incoming: NSColor
    public let chatReplyTextEnabledBubble_outgoing: NSColor
    public let chatReplyTextDisabledBubble_incoming: NSColor
    public let chatReplyTextDisabledBubble_outgoing: NSColor
    public let groupPeerNameRed:NSColor
    public let groupPeerNameOrange:NSColor
    public let groupPeerNameViolet:NSColor
    public let groupPeerNameGreen:NSColor
    public let groupPeerNameCyan:NSColor
    public let groupPeerNameLightBlue:NSColor
    public let groupPeerNameBlue:NSColor
    
    public let peerAvatarRedTop: NSColor
    public let peerAvatarRedBottom: NSColor
    public let peerAvatarOrangeTop: NSColor
    public let peerAvatarOrangeBottom: NSColor
    public let peerAvatarVioletTop: NSColor
    public let peerAvatarVioletBottom: NSColor
    public let peerAvatarGreenTop: NSColor
    public let peerAvatarGreenBottom: NSColor
    public let peerAvatarCyanTop: NSColor
    public let peerAvatarCyanBottom: NSColor
    public let peerAvatarBlueTop: NSColor
    public let peerAvatarBlueBottom: NSColor
    public let peerAvatarPinkTop: NSColor
    public let peerAvatarPinkBottom: NSColor
    
    public let bubbleBackgroundHighlight_incoming: NSColor
    public let bubbleBackgroundHighlight_outgoing: NSColor
    
    public let chatDateActive: NSColor
    public let chatDateText: NSColor
    
    public let revealAction_neutral1_background: NSColor
    public let revealAction_neutral1_foreground: NSColor
    public let revealAction_neutral2_background: NSColor
    public let revealAction_neutral2_foreground: NSColor
    public let revealAction_destructive_background: NSColor
    public let revealAction_destructive_foreground: NSColor
    public let revealAction_constructive_background: NSColor
    public let revealAction_constructive_foreground: NSColor
    public let revealAction_accent_background: NSColor
    public let revealAction_accent_foreground: NSColor
    public let revealAction_warning_background: NSColor
    public let revealAction_warning_foreground: NSColor
    public let revealAction_inactive_background: NSColor
    public let revealAction_inactive_foreground: NSColor
    
    public let chatBackground: NSColor
    public let listBackground: NSColor
    
    public var underSelectedColor: NSColor {
        if basicAccent != accent {
            return accent.lightness > 0.8 ? NSColor(0x000000) : NSColor(0xffffff)
        } else {
            return NSColor(0xffffff)
        }
    }
    public var hasAccent: Bool {
        return basicAccent != accent
    }
    
    public func peerColors(_ index: Int) -> (top: NSColor, bottom: NSColor) {
        let colors: [(top: NSColor, bottom: NSColor)] = [
            (peerAvatarRedTop, peerAvatarRedBottom),
            (peerAvatarOrangeTop, peerAvatarOrangeBottom),
            (peerAvatarVioletTop, peerAvatarVioletBottom),
            (peerAvatarGreenTop, peerAvatarGreenBottom),
            (peerAvatarCyanTop, peerAvatarCyanBottom),
            (peerAvatarBlueTop, peerAvatarBlueBottom),
            (peerAvatarPinkTop, peerAvatarPinkBottom)
        ]
        
        return colors[index]
    }
    
    public var toString: String {
        var string: String = ""
        
        string += "isDark = \(self.isDark ? 1 : 0)\n"
        string += "tinted = \(self.tinted ? 1 : 0)\n"
        string += "name = \(self.name)\n"
        string += "//Fallback for parameters which didn't define. Available values: Day, Day Classic, Dark, Tinted Blue, Mojave\n"
        string += "parent = \(self.parent.rawValue)\n"
        string += "copyright = \(self.copyright)\n"
//        string += "accentList = \(self.accentList.map{$0.hexString}.joined(separator: ","))\n"
        for prop in self.listProperties() {
            if let color = self.colorFromStringVariable(prop) {
                if prop == "chatBackground" {
                    string += "//Parameter is usually using for minimalistic chat mode, but also works as fallback for bubbles if wallpaper doesn't installed\n"
                }
                string += "\(prop) = \(color.hexString.lowercased())\n"
            }
        }
        string += "//Parameter only affects bubble chat mode. Available values: none, builtin, hexColor or url to cloud backgound like a t.me/bg/%slug%\n"
        string += "wallpaper = \(wallpaper.toString)\n"
        return string
    }
    
    public init(isNative: Bool, isDark: Bool,
                tinted: Bool,
                name: String,
                parent: TelegramBuiltinTheme,
                wallpaper: PaletteWallpaper,
                copyright: String,
                accentList: [NSColor],
                basicAccent: NSColor,
                background:NSColor,
                text: NSColor,
                grayText: NSColor,
                link: NSColor,
                accent:NSColor,
                redUI:NSColor,
                greenUI:NSColor,
                blackTransparent:NSColor,
                grayTransparent:NSColor,
                grayUI:NSColor,
                darkGrayText:NSColor,
                blueText:NSColor,
                blueSelect:NSColor,
                selectText:NSColor,
                blueFill:NSColor,
                border:NSColor,
                grayBackground:NSColor,
                grayForeground:NSColor,
                grayIcon:NSColor,
                blueIcon:NSColor,
                badgeMuted:NSColor,
                badge:NSColor,
                indicatorColor: NSColor,
                selectMessage: NSColor,
                monospacedPre: NSColor,
                monospacedCode: NSColor,
                monospacedPreBubble_incoming: NSColor,
                monospacedPreBubble_outgoing: NSColor,
                monospacedCodeBubble_incoming: NSColor,
                monospacedCodeBubble_outgoing: NSColor,
                selectTextBubble_incoming: NSColor,
                selectTextBubble_outgoing: NSColor,
                bubbleBackground_incoming: NSColor,
                bubbleBackground_outgoing: NSColor,
                bubbleBorder_incoming: NSColor,
                bubbleBorder_outgoing: NSColor,
                grayTextBubble_incoming: NSColor,
                grayTextBubble_outgoing: NSColor,
                grayIconBubble_incoming: NSColor,
                grayIconBubble_outgoing: NSColor,
                blueIconBubble_incoming: NSColor,
                blueIconBubble_outgoing: NSColor,
                linkBubble_incoming: NSColor,
                linkBubble_outgoing: NSColor,
                textBubble_incoming: NSColor,
                textBubble_outgoing: NSColor,
                selectMessageBubble: NSColor,
                fileActivityBackground: NSColor,
                fileActivityForeground: NSColor,
                fileActivityBackgroundBubble_incoming: NSColor,
                fileActivityBackgroundBubble_outgoing: NSColor,
                fileActivityForegroundBubble_incoming: NSColor,
                fileActivityForegroundBubble_outgoing: NSColor,
                waveformBackground: NSColor,
                waveformForeground: NSColor,
                waveformBackgroundBubble_incoming: NSColor,
                waveformBackgroundBubble_outgoing: NSColor,
                waveformForegroundBubble_incoming: NSColor,
                waveformForegroundBubble_outgoing: NSColor,
                webPreviewActivity: NSColor,
                webPreviewActivityBubble_incoming: NSColor,
                webPreviewActivityBubble_outgoing: NSColor,
                redBubble_incoming:NSColor,
                redBubble_outgoing:NSColor,
                greenBubble_incoming:NSColor,
                greenBubble_outgoing:NSColor,
                chatReplyTitle: NSColor,
                chatReplyTextEnabled: NSColor,
                chatReplyTextDisabled: NSColor,
                chatReplyTitleBubble_incoming: NSColor,
                chatReplyTitleBubble_outgoing: NSColor,
                chatReplyTextEnabledBubble_incoming: NSColor,
                chatReplyTextEnabledBubble_outgoing: NSColor,
                chatReplyTextDisabledBubble_incoming: NSColor,
                chatReplyTextDisabledBubble_outgoing: NSColor,
                groupPeerNameRed:NSColor,
                groupPeerNameOrange:NSColor,
                groupPeerNameViolet:NSColor,
                groupPeerNameGreen:NSColor,
                groupPeerNameCyan:NSColor,
                groupPeerNameLightBlue:NSColor,
                groupPeerNameBlue:NSColor,
                peerAvatarRedTop: NSColor,
                peerAvatarRedBottom: NSColor,
                peerAvatarOrangeTop: NSColor,
                peerAvatarOrangeBottom: NSColor,
                peerAvatarVioletTop: NSColor,
                peerAvatarVioletBottom: NSColor,
                peerAvatarGreenTop: NSColor,
                peerAvatarGreenBottom: NSColor,
                peerAvatarCyanTop: NSColor,
                peerAvatarCyanBottom: NSColor,
                peerAvatarBlueTop: NSColor,
                peerAvatarBlueBottom: NSColor,
                peerAvatarPinkTop: NSColor,
                peerAvatarPinkBottom: NSColor,
                bubbleBackgroundHighlight_incoming: NSColor,
                bubbleBackgroundHighlight_outgoing: NSColor,
                chatDateActive: NSColor,
                chatDateText: NSColor,
                revealAction_neutral1_background: NSColor,
                revealAction_neutral1_foreground: NSColor,
                revealAction_neutral2_background: NSColor,
                revealAction_neutral2_foreground: NSColor,
                revealAction_destructive_background: NSColor,
                revealAction_destructive_foreground: NSColor,
                revealAction_constructive_background: NSColor,
                revealAction_constructive_foreground: NSColor,
                revealAction_accent_background: NSColor,
                revealAction_accent_foreground: NSColor,
                revealAction_warning_background: NSColor,
                revealAction_warning_foreground: NSColor,
                revealAction_inactive_background: NSColor,
                revealAction_inactive_foreground: NSColor,
                chatBackground: NSColor,
                listBackground: NSColor) {
        
        let background: NSColor = background.withAlphaComponent(1.0)
        let grayBackground: NSColor = grayBackground.withAlphaComponent(1.0)
        let grayForeground: NSColor = grayForeground.withAlphaComponent(1.0)
        var text: NSColor = text.withAlphaComponent(1.0)
        var link: NSColor = link.withAlphaComponent(1.0)
        var grayText: NSColor = grayText.withAlphaComponent(1.0)
        var accent: NSColor = accent.withAlphaComponent(1)
        var blueIcon: NSColor = blueIcon
        var grayIcon: NSColor = grayIcon
        var blueSelect: NSColor = blueSelect
        var textBubble_incoming: NSColor = textBubble_incoming.withAlphaComponent(1.0)
        var textBubble_outgoing: NSColor = textBubble_outgoing.withAlphaComponent(1.0)
        var grayTextBubble_incoming: NSColor = grayTextBubble_incoming.withAlphaComponent(1.0)
        var grayTextBubble_outgoing: NSColor = grayTextBubble_outgoing.withAlphaComponent(1.0)
        var grayIconBubble_incoming: NSColor = grayIconBubble_incoming
        var grayIconBubble_outgoing: NSColor = grayIconBubble_outgoing
        var blueIconBubble_incoming: NSColor = blueIconBubble_incoming
        var blueIconBubble_outgoing: NSColor = blueIconBubble_outgoing
        
        let bubbleBackground_incoming = bubbleBackground_incoming.withAlphaComponent(1.0)
        let bubbleBackground_outgoing = bubbleBackground_outgoing.withAlphaComponent(1.0)
        let linkBubble_incoming = linkBubble_incoming.withAlphaComponent(1.0)
        let linkBubble_outgoing = linkBubble_outgoing.withAlphaComponent(1.0)
        
        let chatBackground = chatBackground.withAlphaComponent(1.0)
        
        if link.isTooCloseHSV(to: background) {
            link = background.brightnessAdjustedColor
        }
        if text.isTooCloseHSV(to: background) {
            text = background.brightnessAdjustedColor
        }
        if accent.isTooCloseHSV(to: background) {
            accent = background.brightnessAdjustedColor
        }
        if blueIcon.isTooCloseHSV(to: background) {
            blueIcon = background.brightnessAdjustedColor
        }
        if grayIcon.isTooCloseHSV(to: background) {
            grayIcon = background.brightnessAdjustedColor
        }
        if grayText.isTooCloseHSV(to: background) {
            grayText = background.brightnessAdjustedColor
        }
        if blueSelect.isTooCloseHSV(to: background) {
            blueSelect = background.brightnessAdjustedColor
        }
        if textBubble_incoming.isTooCloseHSV(to: bubbleBackground_incoming) {
            textBubble_incoming = bubbleBackground_incoming.brightnessAdjustedColor
        }
        if textBubble_outgoing.isTooCloseHSV(to: bubbleBackground_outgoing) {
            textBubble_outgoing = bubbleBackground_outgoing.brightnessAdjustedColor
        }
        if grayTextBubble_incoming.isTooCloseHSV(to: bubbleBackground_incoming) {
            grayTextBubble_incoming = bubbleBackground_incoming.brightnessAdjustedColor
        }
        if grayTextBubble_outgoing.isTooCloseHSV(to: bubbleBackground_outgoing) {
            grayTextBubble_outgoing = bubbleBackground_outgoing.brightnessAdjustedColor
        }
        if grayIconBubble_incoming.isTooCloseHSV(to: bubbleBackground_incoming) {
            grayIconBubble_incoming = bubbleBackground_incoming.brightnessAdjustedColor
        }
        if grayIconBubble_outgoing.isTooCloseHSV(to: bubbleBackground_outgoing) {
            grayIconBubble_outgoing = bubbleBackground_outgoing.brightnessAdjustedColor
        }
        if blueIconBubble_incoming.isTooCloseHSV(to: bubbleBackground_incoming) {
            blueIconBubble_incoming = bubbleBackground_incoming.brightnessAdjustedColor
        }
        if blueIconBubble_outgoing.isTooCloseHSV(to: bubbleBackground_outgoing) {
            blueIconBubble_outgoing = bubbleBackground_outgoing.brightnessAdjustedColor
        }
        self.isNative = isNative
        self.parent = parent
        self.copyright = copyright
        self.isDark = isDark
        self.tinted = tinted
        self.name = name
        self.accentList = accentList
        self.basicAccent = basicAccent.withAlphaComponent(max(0.6, basicAccent.alpha))
        self.background = background.withAlphaComponent(max(0.6, background.alpha))
        self.text = text.withAlphaComponent(max(0.6, text.alpha))
        self.grayText = grayText.withAlphaComponent(max(0.6, grayText.alpha))
        self.link = link.withAlphaComponent(max(0.6, link.alpha))
        self.accent = accent.withAlphaComponent(max(0.6, accent.alpha))
        self.redUI = redUI.withAlphaComponent(max(0.6, redUI.alpha))
        self.greenUI = greenUI.withAlphaComponent(max(0.6, greenUI.alpha))
        self.blackTransparent = blackTransparent.withAlphaComponent(max(0.6, blackTransparent.alpha))
        self.grayTransparent = grayTransparent.withAlphaComponent(max(0.6, grayTransparent.alpha))
        self.grayUI = grayUI.withAlphaComponent(max(0.6, grayUI.alpha))
        self.darkGrayText = darkGrayText.withAlphaComponent(max(0.6, darkGrayText.alpha))
        self.blueText = blueText.withAlphaComponent(max(0.6, blueText.alpha))
        self.blueSelect = blueSelect.withAlphaComponent(max(0.6, blueSelect.alpha))
        self.selectText = selectText.withAlphaComponent(max(0.6, selectText.alpha))
        self.blueFill = blueFill.withAlphaComponent(max(0.6, blueFill.alpha))
        self.border = border.withAlphaComponent(max(0.6, border.alpha))
        self.grayBackground = grayBackground.withAlphaComponent(max(0.6, grayBackground.alpha))
        self.grayForeground = grayForeground.withAlphaComponent(max(0.6, grayForeground.alpha))
        self.grayIcon = grayIcon.withAlphaComponent(max(0.6, grayIcon.alpha))
        self.blueIcon = blueIcon.withAlphaComponent(max(0.6, blueIcon.alpha))
        self.badgeMuted = badgeMuted.withAlphaComponent(max(0.6, badgeMuted.alpha))
        self.badge = badge.withAlphaComponent(max(0.6, badge.alpha))
        self.indicatorColor = indicatorColor.withAlphaComponent(max(0.6, indicatorColor.alpha))
        self.selectMessage = selectMessage.withAlphaComponent(max(0.6, selectMessage.alpha))
        
        self.monospacedPre = monospacedPre.withAlphaComponent(max(0.6, monospacedPre.alpha))
        self.monospacedCode = monospacedCode.withAlphaComponent(max(0.6, monospacedCode.alpha))
        self.monospacedPreBubble_incoming = monospacedPreBubble_incoming.withAlphaComponent(max(0.6, monospacedPreBubble_incoming.alpha))
        self.monospacedPreBubble_outgoing = monospacedPreBubble_outgoing.withAlphaComponent(max(0.6, monospacedPreBubble_outgoing.alpha))
        self.monospacedCodeBubble_incoming = monospacedCodeBubble_incoming.withAlphaComponent(max(0.6, monospacedCodeBubble_incoming.alpha))
        self.monospacedCodeBubble_outgoing = monospacedCodeBubble_outgoing.withAlphaComponent(max(0.6, monospacedCodeBubble_outgoing.alpha))
        self.selectTextBubble_incoming = selectTextBubble_incoming.withAlphaComponent(max(0.6, selectTextBubble_incoming.alpha))
        self.selectTextBubble_outgoing = selectTextBubble_outgoing.withAlphaComponent(max(0.6, selectTextBubble_outgoing.alpha))
        self.bubbleBackground_incoming = bubbleBackground_incoming.withAlphaComponent(max(0.6, bubbleBackground_incoming.alpha))
        self.bubbleBackground_outgoing = bubbleBackground_outgoing.withAlphaComponent(max(0.6, bubbleBackground_outgoing.alpha))
        self.bubbleBorder_incoming = bubbleBorder_incoming.withAlphaComponent(max(0.6, bubbleBorder_incoming.alpha))
        self.bubbleBorder_outgoing = bubbleBorder_outgoing.withAlphaComponent(max(0.6, bubbleBorder_outgoing.alpha))
        self.grayTextBubble_incoming = grayTextBubble_incoming.withAlphaComponent(max(0.6, grayTextBubble_incoming.alpha))
        self.grayTextBubble_outgoing = grayTextBubble_outgoing.withAlphaComponent(max(0.6, grayTextBubble_outgoing.alpha))
        self.grayIconBubble_incoming = grayIconBubble_incoming.withAlphaComponent(max(0.6, grayIconBubble_incoming.alpha))
        self.grayIconBubble_outgoing = grayIconBubble_outgoing.withAlphaComponent(max(0.6, grayIconBubble_outgoing.alpha))
        self.blueIconBubble_incoming = blueIconBubble_incoming.withAlphaComponent(max(0.6, blueIconBubble_incoming.alpha))
        self.blueIconBubble_outgoing = blueIconBubble_outgoing.withAlphaComponent(max(0.6, blueIconBubble_outgoing.alpha))
        self.linkBubble_incoming = linkBubble_incoming.withAlphaComponent(max(0.6, linkBubble_incoming.alpha))
        self.linkBubble_outgoing = linkBubble_outgoing.withAlphaComponent(max(0.6, linkBubble_outgoing.alpha))
        self.textBubble_incoming = textBubble_incoming.withAlphaComponent(max(0.6, textBubble_incoming.alpha))
        self.textBubble_outgoing = textBubble_outgoing.withAlphaComponent(max(0.6, textBubble_outgoing.alpha))
        self.selectMessageBubble = selectMessageBubble.withAlphaComponent(max(0.6, selectMessageBubble.alpha))
        self.fileActivityBackground = fileActivityBackground.withAlphaComponent(max(0.6, fileActivityBackground.alpha))
        self.fileActivityForeground = fileActivityForeground.withAlphaComponent(max(0.6, fileActivityForeground.alpha))
        self.fileActivityBackgroundBubble_incoming = fileActivityBackgroundBubble_incoming.withAlphaComponent(max(0.6, fileActivityBackgroundBubble_incoming.alpha))
        self.fileActivityBackgroundBubble_outgoing = fileActivityBackgroundBubble_outgoing.withAlphaComponent(max(0.6, fileActivityBackgroundBubble_outgoing.alpha))
        self.fileActivityForegroundBubble_incoming = fileActivityForegroundBubble_incoming.withAlphaComponent(max(0.6, fileActivityForegroundBubble_incoming.alpha))
        self.fileActivityForegroundBubble_outgoing = fileActivityForegroundBubble_outgoing.withAlphaComponent(max(0.6, fileActivityForegroundBubble_outgoing.alpha))
        self.waveformBackground = waveformBackground.withAlphaComponent(max(0.6, waveformBackground.alpha))
        self.waveformForeground = waveformForeground.withAlphaComponent(max(0.6, waveformForeground.alpha))
        self.waveformBackgroundBubble_incoming = waveformBackgroundBubble_incoming.withAlphaComponent(max(0.6, waveformBackgroundBubble_incoming.alpha))
        self.waveformBackgroundBubble_outgoing = waveformBackgroundBubble_outgoing.withAlphaComponent(max(0.6, waveformBackgroundBubble_outgoing.alpha))
        self.waveformForegroundBubble_incoming = waveformForegroundBubble_incoming.withAlphaComponent(max(0.6, waveformForegroundBubble_incoming.alpha))
        self.waveformForegroundBubble_outgoing = waveformForegroundBubble_outgoing.withAlphaComponent(max(0.6, waveformForegroundBubble_outgoing.alpha))
        self.webPreviewActivity = webPreviewActivity.withAlphaComponent(max(0.6, webPreviewActivity.alpha))
        self.webPreviewActivityBubble_incoming = webPreviewActivityBubble_incoming.withAlphaComponent(max(0.6, webPreviewActivityBubble_incoming.alpha))
        self.webPreviewActivityBubble_outgoing = webPreviewActivityBubble_outgoing.withAlphaComponent(max(0.6, webPreviewActivityBubble_outgoing.alpha))
        self.redBubble_incoming = redBubble_incoming.withAlphaComponent(max(0.6, redBubble_incoming.alpha))
        self.redBubble_outgoing = redBubble_outgoing.withAlphaComponent(max(0.6, redBubble_outgoing.alpha))
        self.greenBubble_incoming = greenBubble_incoming.withAlphaComponent(max(0.6, greenBubble_incoming.alpha))
        self.greenBubble_outgoing = greenBubble_outgoing.withAlphaComponent(max(0.6, greenBubble_outgoing.alpha))
        self.chatReplyTitle = chatReplyTitle.withAlphaComponent(max(0.6, chatReplyTitle.alpha))
        self.chatReplyTextEnabled = chatReplyTextEnabled.withAlphaComponent(max(0.6, chatReplyTextEnabled.alpha))
        self.chatReplyTextDisabled = chatReplyTextDisabled.withAlphaComponent(max(0.6, chatReplyTextDisabled.alpha))
        self.chatReplyTitleBubble_incoming = chatReplyTitleBubble_incoming.withAlphaComponent(max(0.6, chatReplyTitleBubble_incoming.alpha))
        self.chatReplyTitleBubble_outgoing = chatReplyTitleBubble_outgoing.withAlphaComponent(max(0.6, chatReplyTitleBubble_outgoing.alpha))
        self.chatReplyTextEnabledBubble_incoming = chatReplyTextEnabledBubble_incoming.withAlphaComponent(max(0.6, chatReplyTextEnabledBubble_incoming.alpha))
        self.chatReplyTextEnabledBubble_outgoing = chatReplyTextEnabledBubble_outgoing.withAlphaComponent(max(0.6, chatReplyTextEnabledBubble_outgoing.alpha))
        self.chatReplyTextDisabledBubble_incoming = chatReplyTextDisabledBubble_incoming.withAlphaComponent(max(0.6, chatReplyTextDisabledBubble_incoming.alpha))
        self.chatReplyTextDisabledBubble_outgoing = chatReplyTextDisabledBubble_outgoing.withAlphaComponent(max(0.6, chatReplyTextDisabledBubble_outgoing.alpha))
        self.groupPeerNameRed = groupPeerNameRed.withAlphaComponent(max(0.6, groupPeerNameRed.alpha))
        self.groupPeerNameOrange = groupPeerNameOrange.withAlphaComponent(max(0.6, groupPeerNameOrange.alpha))
        self.groupPeerNameViolet = groupPeerNameViolet.withAlphaComponent(max(0.6, groupPeerNameViolet.alpha))
        self.groupPeerNameGreen = groupPeerNameGreen.withAlphaComponent(max(0.6, groupPeerNameGreen.alpha))
        self.groupPeerNameCyan = groupPeerNameCyan.withAlphaComponent(max(0.6, groupPeerNameCyan.alpha))
        self.groupPeerNameLightBlue = groupPeerNameLightBlue.withAlphaComponent(max(0.6, groupPeerNameLightBlue.alpha))
        self.groupPeerNameBlue = groupPeerNameBlue.withAlphaComponent(max(0.6, groupPeerNameBlue.alpha))
        
        self.peerAvatarRedTop =  peerAvatarRedTop.withAlphaComponent(max(0.6, peerAvatarRedTop.alpha))
        self.peerAvatarRedBottom = peerAvatarRedBottom.withAlphaComponent(max(0.6, peerAvatarRedBottom.alpha))
        self.peerAvatarOrangeTop = peerAvatarOrangeTop.withAlphaComponent(max(0.6, peerAvatarOrangeTop.alpha))
        self.peerAvatarOrangeBottom = peerAvatarOrangeBottom.withAlphaComponent(max(0.6, peerAvatarOrangeBottom.alpha))
        self.peerAvatarVioletTop = peerAvatarVioletTop.withAlphaComponent(max(0.6, peerAvatarVioletTop.alpha))
        self.peerAvatarVioletBottom = peerAvatarVioletBottom.withAlphaComponent(max(0.6, peerAvatarVioletBottom.alpha))
        self.peerAvatarGreenTop = peerAvatarGreenTop.withAlphaComponent(max(0.6, peerAvatarGreenTop.alpha))
        self.peerAvatarGreenBottom = peerAvatarGreenBottom.withAlphaComponent(max(0.6, peerAvatarGreenBottom.alpha))
        self.peerAvatarCyanTop = peerAvatarCyanTop.withAlphaComponent(max(0.6, peerAvatarCyanTop.alpha))
        self.peerAvatarCyanBottom = peerAvatarCyanBottom.withAlphaComponent(max(0.6, peerAvatarCyanBottom.alpha))
        self.peerAvatarBlueTop = peerAvatarBlueTop.withAlphaComponent(max(0.6, peerAvatarBlueTop.alpha))
        self.peerAvatarBlueBottom = peerAvatarBlueBottom.withAlphaComponent(max(0.6, peerAvatarBlueBottom.alpha))
        self.peerAvatarPinkTop = peerAvatarPinkTop.withAlphaComponent(max(0.6, peerAvatarPinkTop.alpha))
        self.peerAvatarPinkBottom = peerAvatarPinkBottom.withAlphaComponent(max(0.6, peerAvatarPinkBottom.alpha))
        self.bubbleBackgroundHighlight_incoming = bubbleBackgroundHighlight_incoming.withAlphaComponent(max(0.6, bubbleBackgroundHighlight_incoming.alpha))
        self.bubbleBackgroundHighlight_outgoing = bubbleBackgroundHighlight_outgoing.withAlphaComponent(max(0.6, bubbleBackgroundHighlight_outgoing.alpha))
        self.chatDateActive = chatDateActive.withAlphaComponent(max(0.6, chatDateActive.alpha))
        self.chatDateText = chatDateText.withAlphaComponent(max(0.6, chatDateText.alpha))
        
        self.revealAction_neutral1_background = revealAction_neutral1_background.withAlphaComponent(max(0.6, revealAction_neutral1_background.alpha))
        self.revealAction_neutral1_foreground = revealAction_neutral1_foreground.withAlphaComponent(max(0.6, revealAction_neutral1_foreground.alpha))
        self.revealAction_neutral2_background = revealAction_neutral2_background.withAlphaComponent(max(0.6, revealAction_neutral2_background.alpha))
        self.revealAction_neutral2_foreground = revealAction_neutral2_foreground.withAlphaComponent(max(0.6, revealAction_neutral2_foreground.alpha))
        self.revealAction_destructive_background = revealAction_destructive_background.withAlphaComponent(max(0.6, revealAction_destructive_background.alpha))
        self.revealAction_destructive_foreground = revealAction_destructive_foreground.withAlphaComponent(max(0.6, revealAction_destructive_foreground.alpha))
        self.revealAction_constructive_background = revealAction_constructive_background.withAlphaComponent(max(0.6, revealAction_constructive_background.alpha))
        self.revealAction_constructive_foreground = revealAction_constructive_foreground.withAlphaComponent(max(0.6, revealAction_constructive_foreground.alpha))
        self.revealAction_accent_background = revealAction_accent_background.withAlphaComponent(max(0.6, revealAction_accent_background.alpha))
        self.revealAction_accent_foreground = revealAction_accent_foreground.withAlphaComponent(max(0.6, revealAction_accent_foreground.alpha))
        self.revealAction_warning_background = revealAction_warning_background.withAlphaComponent(max(0.6, revealAction_warning_background.alpha))
        self.revealAction_warning_foreground = revealAction_warning_foreground.withAlphaComponent(max(0.6, revealAction_warning_foreground.alpha))
        self.revealAction_inactive_background = revealAction_inactive_background.withAlphaComponent(max(0.6, revealAction_inactive_background.alpha))
        self.revealAction_inactive_foreground = revealAction_inactive_foreground.withAlphaComponent(max(0.6, revealAction_inactive_foreground.alpha))
        
        self.chatBackground = chatBackground.withAlphaComponent(max(0.6, chatBackground.alpha))
        self.wallpaper = wallpaper
        self.listBackground = listBackground
    }
    
    public func listProperties(reflect: Mirror? = nil) -> [String] {
        let mirror = reflect ?? Mirror(reflecting: self)
        
        return mirror.children.enumerated().filter({$0.element.label != nil}).map({$0.element.label!})
    }
    
    public func colorFromStringVariable(_ string: String) -> NSColor? {
        let mirror = Mirror(reflecting: self)
        for (_, value) in mirror.children.enumerated() {
            if value.label == string {
                return value.value as? NSColor
            }
        }
        return nil
    }
    
    public func withoutAccentColor() -> ColorPalette {
        switch self.name {
        case whitePalette.name:
            return whitePalette
        case "Night Blue":
            return tintedNightPalette
        case tintedNightPalette.name:
            return tintedNightPalette
        case darkPalette.name:
            return darkPalette
        case dayClassicPalette.name:
            return dayClassicPalette
        case mojavePalette.name:
            return mojavePalette
        default:
            return self
        }
    }
    
    public func withUpdatedName(_ name: String) -> ColorPalette {
        return ColorPalette(isNative: self.isNative, isDark: isDark,
                            tinted: tinted,
                            name: name,
                            parent: parent,
                            wallpaper: wallpaper,
                            copyright: copyright,
                            accentList: accentList,
                            basicAccent: basicAccent,
                            background: background,
                            text: text,
                            grayText: grayText,
                            link: link,
                            accent: accent,
                            redUI: redUI,
                            greenUI: greenUI,
                            blackTransparent: blackTransparent,
                            grayTransparent: grayTransparent,
                            grayUI: grayUI,
                            darkGrayText: darkGrayText,
                            blueText: blueText,
                            blueSelect: blueSelect,
                            selectText: selectText,
                            blueFill: blueFill,
                            border: border,
                            grayBackground: grayBackground,
                            grayForeground: grayForeground,
                            grayIcon: grayIcon,
                            blueIcon: blueIcon,
                            badgeMuted: badgeMuted,
                            badge: badge,
                            indicatorColor: indicatorColor,
                            selectMessage: selectMessage,
                            monospacedPre: monospacedPre,
                            monospacedCode: monospacedCode,
                            monospacedPreBubble_incoming: monospacedPreBubble_incoming,
                            monospacedPreBubble_outgoing: monospacedPreBubble_outgoing,
                            monospacedCodeBubble_incoming: monospacedCodeBubble_incoming,
                            monospacedCodeBubble_outgoing: monospacedCodeBubble_outgoing,
                            selectTextBubble_incoming: selectTextBubble_incoming,
                            selectTextBubble_outgoing: selectTextBubble_outgoing,
                            bubbleBackground_incoming: bubbleBackground_incoming,
                            bubbleBackground_outgoing: bubbleBackground_outgoing,
                            bubbleBorder_incoming: bubbleBorder_incoming,
                            bubbleBorder_outgoing: bubbleBackground_outgoing,
                            grayTextBubble_incoming: grayTextBubble_incoming,
                            grayTextBubble_outgoing: grayTextBubble_outgoing,
                            grayIconBubble_incoming: grayIconBubble_incoming,
                            grayIconBubble_outgoing: grayIconBubble_outgoing,
                            blueIconBubble_incoming: blueIconBubble_incoming,
                            blueIconBubble_outgoing: blueIconBubble_outgoing,
                            linkBubble_incoming: linkBubble_incoming,
                            linkBubble_outgoing: linkBubble_outgoing,
                            textBubble_incoming: textBubble_incoming,
                            textBubble_outgoing: textBubble_outgoing,
                            selectMessageBubble: selectMessageBubble,
                            fileActivityBackground: fileActivityBackground,
                            fileActivityForeground: fileActivityForeground,
                            fileActivityBackgroundBubble_incoming: fileActivityBackgroundBubble_incoming,
                            fileActivityBackgroundBubble_outgoing: fileActivityBackgroundBubble_outgoing,
                            fileActivityForegroundBubble_incoming: fileActivityForegroundBubble_incoming,
                            fileActivityForegroundBubble_outgoing: fileActivityForegroundBubble_outgoing,
                            waveformBackground: waveformBackground,
                            waveformForeground: waveformForeground,
                            waveformBackgroundBubble_incoming: waveformBackgroundBubble_incoming,
                            waveformBackgroundBubble_outgoing: waveformBackgroundBubble_outgoing,
                            waveformForegroundBubble_incoming: waveformForegroundBubble_incoming,
                            waveformForegroundBubble_outgoing: waveformForegroundBubble_outgoing,
                            webPreviewActivity: webPreviewActivity,
                            webPreviewActivityBubble_incoming: webPreviewActivityBubble_incoming,
                            webPreviewActivityBubble_outgoing: webPreviewActivityBubble_outgoing,
                            redBubble_incoming: redBubble_incoming,
                            redBubble_outgoing: redBubble_outgoing,
                            greenBubble_incoming: greenBubble_incoming,
                            greenBubble_outgoing: greenBubble_outgoing,
                            chatReplyTitle: chatReplyTitle,
                            chatReplyTextEnabled: chatReplyTextEnabled,
                            chatReplyTextDisabled: chatReplyTextDisabled,
                            chatReplyTitleBubble_incoming: chatReplyTitleBubble_incoming,
                            chatReplyTitleBubble_outgoing: chatReplyTitleBubble_outgoing,
                            chatReplyTextEnabledBubble_incoming: chatReplyTextEnabledBubble_incoming,
                            chatReplyTextEnabledBubble_outgoing: chatReplyTextEnabledBubble_outgoing,
                            chatReplyTextDisabledBubble_incoming: chatReplyTextDisabledBubble_incoming,
                            chatReplyTextDisabledBubble_outgoing: chatReplyTextDisabledBubble_outgoing,
                            groupPeerNameRed: groupPeerNameRed,
                            groupPeerNameOrange: groupPeerNameOrange,
                            groupPeerNameViolet: groupPeerNameViolet,
                            groupPeerNameGreen: groupPeerNameGreen,
                            groupPeerNameCyan: groupPeerNameCyan,
                            groupPeerNameLightBlue: groupPeerNameLightBlue,
                            groupPeerNameBlue: groupPeerNameBlue,
                            peerAvatarRedTop: peerAvatarRedTop,
                            peerAvatarRedBottom: peerAvatarRedBottom,
                            peerAvatarOrangeTop: peerAvatarOrangeTop,
                            peerAvatarOrangeBottom: peerAvatarOrangeBottom,
                            peerAvatarVioletTop: peerAvatarVioletTop,
                            peerAvatarVioletBottom: peerAvatarVioletBottom,
                            peerAvatarGreenTop: peerAvatarGreenTop,
                            peerAvatarGreenBottom: peerAvatarGreenBottom,
                            peerAvatarCyanTop: peerAvatarCyanTop,
                            peerAvatarCyanBottom: peerAvatarCyanBottom,
                            peerAvatarBlueTop: peerAvatarBlueTop,
                            peerAvatarBlueBottom: peerAvatarBlueBottom,
                            peerAvatarPinkTop: peerAvatarPinkTop,
                            peerAvatarPinkBottom: peerAvatarPinkBottom,
                            bubbleBackgroundHighlight_incoming: bubbleBackgroundHighlight_incoming,
                            bubbleBackgroundHighlight_outgoing: bubbleBackgroundHighlight_outgoing,
                            chatDateActive: chatDateActive,
                            chatDateText: chatDateText,
                            revealAction_neutral1_background: revealAction_neutral1_background,
                            revealAction_neutral1_foreground: revealAction_neutral1_foreground,
                            revealAction_neutral2_background: revealAction_neutral2_background,
                            revealAction_neutral2_foreground: revealAction_neutral2_foreground,
                            revealAction_destructive_background: revealAction_destructive_background,
                            revealAction_destructive_foreground: revealAction_destructive_foreground,
                            revealAction_constructive_background: revealAction_constructive_background,
                            revealAction_constructive_foreground: revealAction_constructive_foreground,
                            revealAction_accent_background: revealAction_accent_background,
                            revealAction_accent_foreground: revealAction_accent_foreground,
                            revealAction_warning_background: revealAction_warning_background,
                            revealAction_warning_foreground: revealAction_warning_foreground,
                            revealAction_inactive_background: revealAction_inactive_background,
                            revealAction_inactive_foreground: revealAction_inactive_foreground,
                            chatBackground: chatBackground,
                            listBackground: listBackground)
    }
    
    public func withUpdatedWallpaper(_ wallpaper: PaletteWallpaper) -> ColorPalette {
        return ColorPalette(isNative: self.isNative, isDark: isDark,
                            tinted: tinted,
                            name: name,
                            parent: parent,
                            wallpaper: wallpaper,
                            copyright: copyright,
                            accentList: accentList,
                            basicAccent: basicAccent,
                            background: background,
                            text: text,
                            grayText: grayText,
                            link: link,
                            accent: accent,
                            redUI: redUI,
                            greenUI: greenUI,
                            blackTransparent: blackTransparent,
                            grayTransparent: grayTransparent,
                            grayUI: grayUI,
                            darkGrayText: darkGrayText,
                            blueText: blueText,
                            blueSelect: blueSelect,
                            selectText: selectText,
                            blueFill: blueFill,
                            border: border,
                            grayBackground: grayBackground,
                            grayForeground: grayForeground,
                            grayIcon: grayIcon,
                            blueIcon: blueIcon,
                            badgeMuted: badgeMuted,
                            badge: badge,
                            indicatorColor: indicatorColor,
                            selectMessage: selectMessage,
                            monospacedPre: monospacedPre,
                            monospacedCode: monospacedCode,
                            monospacedPreBubble_incoming: monospacedPreBubble_incoming,
                            monospacedPreBubble_outgoing: monospacedPreBubble_outgoing,
                            monospacedCodeBubble_incoming: monospacedCodeBubble_incoming,
                            monospacedCodeBubble_outgoing: monospacedCodeBubble_outgoing,
                            selectTextBubble_incoming: selectTextBubble_incoming,
                            selectTextBubble_outgoing: selectTextBubble_outgoing,
                            bubbleBackground_incoming: bubbleBackground_incoming,
                            bubbleBackground_outgoing: bubbleBackground_outgoing,
                            bubbleBorder_incoming: bubbleBorder_incoming,
                            bubbleBorder_outgoing: bubbleBackground_outgoing,
                            grayTextBubble_incoming: grayTextBubble_incoming,
                            grayTextBubble_outgoing: grayTextBubble_outgoing,
                            grayIconBubble_incoming: grayIconBubble_incoming,
                            grayIconBubble_outgoing: grayIconBubble_outgoing,
                            blueIconBubble_incoming: blueIconBubble_incoming,
                            blueIconBubble_outgoing: blueIconBubble_outgoing,
                            linkBubble_incoming: linkBubble_incoming,
                            linkBubble_outgoing: linkBubble_outgoing,
                            textBubble_incoming: textBubble_incoming,
                            textBubble_outgoing: textBubble_outgoing,
                            selectMessageBubble: selectMessageBubble,
                            fileActivityBackground: fileActivityBackground,
                            fileActivityForeground: fileActivityForeground,
                            fileActivityBackgroundBubble_incoming: fileActivityBackgroundBubble_incoming,
                            fileActivityBackgroundBubble_outgoing: fileActivityBackgroundBubble_outgoing,
                            fileActivityForegroundBubble_incoming: fileActivityForegroundBubble_incoming,
                            fileActivityForegroundBubble_outgoing: fileActivityForegroundBubble_outgoing,
                            waveformBackground: waveformBackground,
                            waveformForeground: waveformForeground,
                            waveformBackgroundBubble_incoming: waveformBackgroundBubble_incoming,
                            waveformBackgroundBubble_outgoing: waveformBackgroundBubble_outgoing,
                            waveformForegroundBubble_incoming: waveformForegroundBubble_incoming,
                            waveformForegroundBubble_outgoing: waveformForegroundBubble_outgoing,
                            webPreviewActivity: webPreviewActivity,
                            webPreviewActivityBubble_incoming: webPreviewActivityBubble_incoming,
                            webPreviewActivityBubble_outgoing: webPreviewActivityBubble_outgoing,
                            redBubble_incoming: redBubble_incoming,
                            redBubble_outgoing: redBubble_outgoing,
                            greenBubble_incoming: greenBubble_incoming,
                            greenBubble_outgoing: greenBubble_outgoing,
                            chatReplyTitle: chatReplyTitle,
                            chatReplyTextEnabled: chatReplyTextEnabled,
                            chatReplyTextDisabled: chatReplyTextDisabled,
                            chatReplyTitleBubble_incoming: chatReplyTitleBubble_incoming,
                            chatReplyTitleBubble_outgoing: chatReplyTitleBubble_outgoing,
                            chatReplyTextEnabledBubble_incoming: chatReplyTextEnabledBubble_incoming,
                            chatReplyTextEnabledBubble_outgoing: chatReplyTextEnabledBubble_outgoing,
                            chatReplyTextDisabledBubble_incoming: chatReplyTextDisabledBubble_incoming,
                            chatReplyTextDisabledBubble_outgoing: chatReplyTextDisabledBubble_outgoing,
                            groupPeerNameRed: groupPeerNameRed,
                            groupPeerNameOrange: groupPeerNameOrange,
                            groupPeerNameViolet: groupPeerNameViolet,
                            groupPeerNameGreen: groupPeerNameGreen,
                            groupPeerNameCyan: groupPeerNameCyan,
                            groupPeerNameLightBlue: groupPeerNameLightBlue,
                            groupPeerNameBlue: groupPeerNameBlue,
                            peerAvatarRedTop: peerAvatarRedTop,
                            peerAvatarRedBottom: peerAvatarRedBottom,
                            peerAvatarOrangeTop: peerAvatarOrangeTop,
                            peerAvatarOrangeBottom: peerAvatarOrangeBottom,
                            peerAvatarVioletTop: peerAvatarVioletTop,
                            peerAvatarVioletBottom: peerAvatarVioletBottom,
                            peerAvatarGreenTop: peerAvatarGreenTop,
                            peerAvatarGreenBottom: peerAvatarGreenBottom,
                            peerAvatarCyanTop: peerAvatarCyanTop,
                            peerAvatarCyanBottom: peerAvatarCyanBottom,
                            peerAvatarBlueTop: peerAvatarBlueTop,
                            peerAvatarBlueBottom: peerAvatarBlueBottom,
                            peerAvatarPinkTop: peerAvatarPinkTop,
                            peerAvatarPinkBottom: peerAvatarPinkBottom,
                            bubbleBackgroundHighlight_incoming: bubbleBackgroundHighlight_incoming,
                            bubbleBackgroundHighlight_outgoing: bubbleBackgroundHighlight_outgoing,
                            chatDateActive: chatDateActive,
                            chatDateText: chatDateText,
                            revealAction_neutral1_background: revealAction_neutral1_background,
                            revealAction_neutral1_foreground: revealAction_neutral1_foreground,
                            revealAction_neutral2_background: revealAction_neutral2_background,
                            revealAction_neutral2_foreground: revealAction_neutral2_foreground,
                            revealAction_destructive_background: revealAction_destructive_background,
                            revealAction_destructive_foreground: revealAction_destructive_foreground,
                            revealAction_constructive_background: revealAction_constructive_background,
                            revealAction_constructive_foreground: revealAction_constructive_foreground,
                            revealAction_accent_background: revealAction_accent_background,
                            revealAction_accent_foreground: revealAction_accent_foreground,
                            revealAction_warning_background: revealAction_warning_background,
                            revealAction_warning_foreground: revealAction_warning_foreground,
                            revealAction_inactive_background: revealAction_inactive_background,
                            revealAction_inactive_foreground: revealAction_inactive_foreground,
                            chatBackground: chatBackground,
                            listBackground: listBackground)
    }
    
    public func withAccentColor(_ color: NSColor, disableTint: Bool = false) -> ColorPalette {
        
        var accentColor = color
        let hsv = color.hsv
        accentColor = NSColor(hue: hsv.0, saturation: hsv.1, brightness: max(hsv.2, 0.18), alpha: 1.0)
        
        var background = self.background
        var border = self.border
        var grayBackground = self.grayBackground
        var grayForeground = self.grayForeground
        var bubbleBackground_incoming = self.bubbleBackground_incoming
        var bubbleBorder_incoming = self.bubbleBorder_incoming
        var bubbleBackgroundHighlight_incoming = self.bubbleBackgroundHighlight_incoming
        var bubbleBackgroundHighlight_outgoing = self.bubbleBackgroundHighlight_outgoing
        var chatBackground = self.chatBackground
        var listBackground = self.listBackground
        var selectMessage = self.selectMessage
        if tinted && !disableTint {
            background = accentColor.withMultiplied(hue: 1.024, saturation: 0.585, brightness: 0.25)
            border = accentColor.withMultiplied(hue: 1.024, saturation: 0.585, brightness: 0.3)
            grayForeground = accentColor.withMultiplied(hue: 1.024, saturation: 0.573, brightness: 0.18)
            grayBackground = accentColor.withMultiplied(hue: 1.024, saturation: 0.573, brightness: 0.18)
            bubbleBackground_incoming = accentColor.withMultiplied(hue: 1.024, saturation: 0.573, brightness: 0.28)
            bubbleBorder_incoming = accentColor.withMultiplied(hue: 1.024, saturation: 0.573, brightness: 0.38)
            bubbleBackgroundHighlight_incoming = accentColor.withMultiplied(hue: 1.024, saturation: 0.573, brightness: 0.38)
            chatBackground = accentColor.withMultiplied(hue: 1.024, saturation: 0.570, brightness: 0.14)
            selectMessage = accentColor.withMultiplied(hue: 1.024, saturation: 0.570, brightness: 0.3)
            listBackground = accentColor.withMultiplied(hue: 1.024, saturation: 0.572, brightness: 0.16)
        }
        
        
        let bubbleBackground_outgoing = color
        bubbleBackgroundHighlight_outgoing = accentColor.withMultiplied(hue: 1.024, saturation: 0.9, brightness: 0.9)
        
        let textBubble_outgoing = color.lightness > 0.8 ? NSColor(0x000000) : NSColor(0xffffff)
        
        let webPreviewActivityBubble_outgoing = color.lightness > 0.8 ? NSColor(0x000000) : NSColor(0xffffff)
        let link = color
        
        let monospacedPreBubble_outgoing = color.lightness > 0.8 ? NSColor(0x000000) : NSColor(0xffffff)
        let monospacedCodeBubble_outgoing = color.lightness > 0.8 ? NSColor(0x000000) : NSColor(0xffffff)
        
        
        let grayTextBubble_outgoing = textBubble_outgoing.withMultiplied(hue: 0.956, saturation: 0.17, brightness: 1.0)
        let grayIconBubble_outgoing = textBubble_outgoing.withMultiplied(hue: 0.956, saturation: 0.17, brightness: 1.0)
        let blueIconBubble_outgoing = textBubble_outgoing
        
        let fileActivityForegroundBubble_outgoing = color
        let fileActivityBackgroundBubble_outgoing = textBubble_outgoing
        
        let linkBubble_outgoing = textBubble_outgoing
        let chatReplyTextEnabledBubble_outgoing = textBubble_outgoing.withMultiplied(hue: 0.956, saturation: 0.17, brightness: 1.0)
        let chatReplyTextDisabledBubble_outgoing = textBubble_outgoing.withMultiplied(hue: 0.956, saturation: 0.17, brightness: 1.0)
        let chatReplyTitleBubble_outgoing = textBubble_outgoing.withMultiplied(hue: 0.956, saturation: 0.17, brightness: 1.0)
        
        
        let chatReplyTitleBubble_incoming = color
        
        return ColorPalette(isNative: self.isNative, isDark: isDark,
                            tinted: tinted,
                            name: name,
                            parent: parent,
                            wallpaper: wallpaper,
                            copyright: copyright,
                            accentList: accentList,
                            basicAccent: basicAccent,
                            background: background,
                            text: text,
                            grayText: grayText,
                            link: link,
                            accent: color,
                            redUI: redUI,
                            greenUI: greenUI,
                            blackTransparent: blackTransparent,
                            grayTransparent: grayTransparent,
                            grayUI: grayUI,
                            darkGrayText: darkGrayText,
                            blueText: color,
                            blueSelect: color,
                            selectText: selectText,
                            blueFill: color,
                            border: border,
                            grayBackground: grayBackground,
                            grayForeground: grayForeground,
                            grayIcon: grayIcon,
                            blueIcon: color,
                            badgeMuted: badgeMuted,
                            badge: color,
                            indicatorColor: indicatorColor,
                            selectMessage: selectMessage,
                            monospacedPre: monospacedPre,
                            monospacedCode: monospacedCode,
                            monospacedPreBubble_incoming: monospacedPreBubble_incoming,
                            monospacedPreBubble_outgoing: monospacedPreBubble_outgoing,
                            monospacedCodeBubble_incoming: monospacedCodeBubble_incoming,
                            monospacedCodeBubble_outgoing: monospacedCodeBubble_outgoing,
                            selectTextBubble_incoming: selectTextBubble_incoming,
                            selectTextBubble_outgoing: selectTextBubble_outgoing,
                            bubbleBackground_incoming: bubbleBackground_incoming,
                            bubbleBackground_outgoing: bubbleBackground_outgoing,
                            bubbleBorder_incoming: bubbleBorder_incoming,
                            bubbleBorder_outgoing: bubbleBackground_outgoing,
                            grayTextBubble_incoming: grayTextBubble_incoming,
                            grayTextBubble_outgoing: grayTextBubble_outgoing,
                            grayIconBubble_incoming: grayIconBubble_incoming,
                            grayIconBubble_outgoing: grayIconBubble_outgoing,
                            blueIconBubble_incoming: blueIconBubble_incoming,
                            blueIconBubble_outgoing: blueIconBubble_outgoing,
                            linkBubble_incoming: linkBubble_incoming,
                            linkBubble_outgoing: linkBubble_outgoing,
                            textBubble_incoming: textBubble_incoming,
                            textBubble_outgoing: textBubble_outgoing,
                            selectMessageBubble: selectMessageBubble,
                            fileActivityBackground: color,
                            fileActivityForeground: fileActivityForeground,
                            fileActivityBackgroundBubble_incoming: fileActivityBackgroundBubble_incoming,
                            fileActivityBackgroundBubble_outgoing: fileActivityBackgroundBubble_outgoing,
                            fileActivityForegroundBubble_incoming: fileActivityForegroundBubble_incoming,
                            fileActivityForegroundBubble_outgoing: fileActivityForegroundBubble_outgoing,
                            waveformBackground: waveformBackground,
                            waveformForeground: color,
                            waveformBackgroundBubble_incoming: waveformBackgroundBubble_incoming,
                            waveformBackgroundBubble_outgoing: waveformBackgroundBubble_outgoing,
                            waveformForegroundBubble_incoming: color,
                            waveformForegroundBubble_outgoing: waveformForegroundBubble_outgoing,
                            webPreviewActivity: color,
                            webPreviewActivityBubble_incoming: webPreviewActivityBubble_incoming,
                            webPreviewActivityBubble_outgoing: webPreviewActivityBubble_outgoing,
                            redBubble_incoming: redBubble_incoming,
                            redBubble_outgoing: redBubble_outgoing,
                            greenBubble_incoming: greenBubble_incoming,
                            greenBubble_outgoing: greenBubble_outgoing,
                            chatReplyTitle: color,
                            chatReplyTextEnabled: chatReplyTextEnabled,
                            chatReplyTextDisabled: chatReplyTextDisabled,
                            chatReplyTitleBubble_incoming: chatReplyTitleBubble_incoming,
                            chatReplyTitleBubble_outgoing: chatReplyTitleBubble_outgoing,
                            chatReplyTextEnabledBubble_incoming: chatReplyTextEnabledBubble_incoming,
                            chatReplyTextEnabledBubble_outgoing: chatReplyTextEnabledBubble_outgoing,
                            chatReplyTextDisabledBubble_incoming: chatReplyTextDisabledBubble_incoming,
                            chatReplyTextDisabledBubble_outgoing: chatReplyTextDisabledBubble_outgoing,
                            groupPeerNameRed: groupPeerNameRed,
                            groupPeerNameOrange: groupPeerNameOrange,
                            groupPeerNameViolet: groupPeerNameViolet,
                            groupPeerNameGreen: groupPeerNameGreen,
                            groupPeerNameCyan: groupPeerNameCyan,
                            groupPeerNameLightBlue: groupPeerNameLightBlue,
                            groupPeerNameBlue: groupPeerNameBlue,
                            peerAvatarRedTop: peerAvatarRedTop,
                            peerAvatarRedBottom: peerAvatarRedBottom,
                            peerAvatarOrangeTop: peerAvatarOrangeTop,
                            peerAvatarOrangeBottom: peerAvatarOrangeBottom,
                            peerAvatarVioletTop: peerAvatarVioletTop,
                            peerAvatarVioletBottom: peerAvatarVioletBottom,
                            peerAvatarGreenTop: peerAvatarGreenTop,
                            peerAvatarGreenBottom: peerAvatarGreenBottom,
                            peerAvatarCyanTop: peerAvatarCyanTop,
                            peerAvatarCyanBottom: peerAvatarCyanBottom,
                            peerAvatarBlueTop: peerAvatarBlueTop,
                            peerAvatarBlueBottom: peerAvatarBlueBottom,
                            peerAvatarPinkTop: peerAvatarPinkTop,
                            peerAvatarPinkBottom: peerAvatarPinkBottom,
                            bubbleBackgroundHighlight_incoming: bubbleBackgroundHighlight_incoming,
                            bubbleBackgroundHighlight_outgoing: bubbleBackgroundHighlight_outgoing,
                            chatDateActive: chatDateActive,
                            chatDateText: chatDateText,
                            revealAction_neutral1_background: revealAction_neutral1_background,
                            revealAction_neutral1_foreground: revealAction_neutral1_foreground,
                            revealAction_neutral2_background: revealAction_neutral2_background,
                            revealAction_neutral2_foreground: revealAction_neutral2_foreground,
                            revealAction_destructive_background: revealAction_destructive_background,
                            revealAction_destructive_foreground: revealAction_destructive_foreground,
                            revealAction_constructive_background: revealAction_constructive_background,
                            revealAction_constructive_foreground: revealAction_constructive_foreground,
                            revealAction_accent_background: revealAction_accent_background,
                            revealAction_accent_foreground: revealAction_accent_foreground,
                            revealAction_warning_background: revealAction_warning_background,
                            revealAction_warning_foreground: revealAction_warning_foreground,
                            revealAction_inactive_background: revealAction_inactive_background,
                            revealAction_inactive_foreground: revealAction_inactive_foreground,
                            chatBackground: chatBackground,
                            listBackground: listBackground)
    }
}



open class PresentationTheme : Equatable {
    
    public let colors:ColorPalette
    public let search: SearchTheme
    
    public let resourceCache = PresentationsResourceCache()
    
    public init(colors: ColorPalette, search: SearchTheme) {
        self.colors = colors
        self.search = search
    }
    
    static var current: PresentationTheme {
        return presentation
    }
    
    
    public static func ==(lhs: PresentationTheme, rhs: PresentationTheme) -> Bool {
        return lhs === rhs
    }
    
    //    public func image(_ key: Int32, _ generate: (PresentationTheme) -> CGImage?) -> CGImage? {
    //        return self.resourceCache.image(key, self, generate)
    //    }
    //
    //    public func object(_ key: Int32, _ generate: (PresentationTheme) -> AnyObject?) -> AnyObject? {
    //        return self.resourceCache.object(key, self, generate)
    //    }
}


public var navigationButtonStyle:ControlStyle {
    return ControlStyle(font: .medium(.title), foregroundColor: presentation.colors.accent, backgroundColor: presentation.colors.background, highlightColor: presentation.colors.accent)
}
public var switchViewAppearance: SwitchViewAppearance {
    return SwitchViewAppearance(backgroundColor: presentation.colors.background, stateOnColor: presentation.colors.accent, stateOffColor: presentation.colors.grayForeground, disabledColor: presentation.colors.grayTransparent, borderColor: presentation.colors.border)
}

public enum TelegramBuiltinTheme : String {
    case day = "Day"
    case dayClassic = "Day Classic"
    case dark = "Dark"
    case tintedNight = "Tinted Blue"
    case mojave = "Mojave"
    
    public init?(rawValue: String) {
        switch rawValue {
        case  "Day":
            self = .day
        case "Day Classic":
            self = .dayClassic
        case "Dark":
            self = .dark
        case "Tinted Blue":
            self = .tintedNight
        case "Night Blue":
            self = .tintedNight
        case "Mojave":
            self = .mojave
        default:
            return nil
        }
    }
    
    public var palette: ColorPalette {
        switch self {
        case .day:
            return whitePalette
        case .dark:
            return darkPalette
        case .dayClassic:
            return dayClassicPalette
        case .mojave:
            return mojavePalette
        case .tintedNight:
            return tintedNightPalette
        }
    }
}



//0xE3EDF4
public let whitePalette = ColorPalette(isNative: true, isDark: false,
                                       tinted: false,
                                       name: "Day",
                                       parent: .day,
                                       wallpaper: .none,
                                       copyright: "Telegram",
                                       accentList: [NSColor(0x2481cc),
                                                    NSColor(0xf83b4c),
                                                    NSColor(0xff7519),
                                                    NSColor(0xeba239),
                                                    NSColor(0x29b327),
                                                    NSColor(0x00c2ed),
                                                    NSColor(0x7748ff),
                                                    NSColor(0xff5da2)],
                                       basicAccent: NSColor(0x2481cc),
                                       background: NSColor(0xffffff),
                                       text: NSColor(0x000000),
                                       grayText: NSColor(0x999999),
                                       link: NSColor(0x2481cc),
                                       accent: NSColor(0x2481cc),
                                       redUI: NSColor(0xff3b30),
                                       greenUI:NSColor(0x63DA6E),
                                       blackTransparent: NSColor(0x000000, 0.6),
                                       grayTransparent: NSColor(0xf4f4f4, 0.4),
                                       grayUI: NSColor(0xFaFaFa),
                                       darkGrayText:NSColor(0x333333),
                                       blueText:NSColor(0x2481CC),
                                       blueSelect:NSColor(0x4c91c7),
                                       selectText:NSColor(0xeaeaea),
                                       blueFill:NSColor(0x4ba3e2),
                                       border:NSColor(0xeaeaea),
                                       grayBackground:NSColor(0xf4f4f4),
                                       grayForeground:NSColor(0xe4e4e4),
                                       grayIcon:NSColor(0x9e9e9e),
                                       blueIcon:NSColor(0x0f8fe4),
                                       badgeMuted:NSColor(0xd7d7d7),
                                       badge:NSColor(0x4ba3e2),
                                       indicatorColor: NSColor(0x464a57),
                                       selectMessage: NSColor(0xeaeaea),
                                       monospacedPre: NSColor(0x000000),
                                       monospacedCode: NSColor(0xff3b30),
                                       monospacedPreBubble_incoming: NSColor(0xff3b30),
                                       monospacedPreBubble_outgoing: NSColor(0xffffff),
                                       monospacedCodeBubble_incoming: NSColor(0xff3b30),
                                       monospacedCodeBubble_outgoing: NSColor(0xffffff),
                                       selectTextBubble_incoming: NSColor(0xCCDDEA),
                                       selectTextBubble_outgoing: NSColor(0x6DA8D6),
                                       bubbleBackground_incoming: NSColor(0xF4F4F4),
                                       bubbleBackground_outgoing: NSColor(0x4c91c7),//0x007ee5
    bubbleBorder_incoming: NSColor(0xeaeaea),
    bubbleBorder_outgoing: NSColor(0x4c91c7),
    grayTextBubble_incoming: NSColor(0x999999),
    grayTextBubble_outgoing: NSColor(0xEFFAFF, 0.8),
    grayIconBubble_incoming: NSColor(0x999999),
    grayIconBubble_outgoing: NSColor(0xEFFAFF, 0.8),
    blueIconBubble_incoming: NSColor(0x999999),
    blueIconBubble_outgoing: NSColor(0xEFFAFF, 0.8),
    linkBubble_incoming: NSColor(0x2481cc),
    linkBubble_outgoing: NSColor(0xffffff),
    textBubble_incoming: NSColor(0x000000),
    textBubble_outgoing: NSColor(0xffffff),
    selectMessageBubble: NSColor(0xEDF4F9, 0.6),
    fileActivityBackground: NSColor(0x4ba3e2),
    fileActivityForeground: NSColor(0xffffff),
    fileActivityBackgroundBubble_incoming: NSColor(0x4ba3e2),
    fileActivityBackgroundBubble_outgoing: NSColor(0xffffff),
    fileActivityForegroundBubble_incoming: NSColor(0xffffff),
    fileActivityForegroundBubble_outgoing: NSColor(0x4c91c7),
    waveformBackground: NSColor(0x9e9e9e, 0.7),
    waveformForeground: NSColor(0x4ba3e2),
    waveformBackgroundBubble_incoming: NSColor(0x999999),
    waveformBackgroundBubble_outgoing: NSColor(0xffffff),
    waveformForegroundBubble_incoming: NSColor(0x4ba3e2),
    waveformForegroundBubble_outgoing: NSColor(0xEFFAFF),
    webPreviewActivity: NSColor(0x2481cc),
    webPreviewActivityBubble_incoming: NSColor(0x2481cc),
    webPreviewActivityBubble_outgoing: NSColor(0xffffff),
    redBubble_incoming:NSColor(0xff3b30),
    redBubble_outgoing:NSColor(0xff3b30),
    greenBubble_incoming:NSColor(0x63DA6E),
    greenBubble_outgoing:NSColor(0x63DA6E),
    chatReplyTitle: NSColor(0x2481cc),
    chatReplyTextEnabled: NSColor(0x000000),
    chatReplyTextDisabled: NSColor(0x999999),
    chatReplyTitleBubble_incoming: NSColor(0x2481cc),
    chatReplyTitleBubble_outgoing: NSColor(0xffffff),
    chatReplyTextEnabledBubble_incoming: NSColor(0x000000),
    chatReplyTextEnabledBubble_outgoing: NSColor(0xffffff),
    chatReplyTextDisabledBubble_incoming: NSColor(0x999999),
    chatReplyTextDisabledBubble_outgoing: NSColor(0xEFFAFF, 0.8),
    groupPeerNameRed:NSColor(0xfc5c51),
    groupPeerNameOrange:NSColor(0xfa790f),
    groupPeerNameViolet:NSColor(0x895dd5),
    groupPeerNameGreen:NSColor(0x0fb297),
    groupPeerNameCyan:NSColor(0x00c1a6),
    groupPeerNameLightBlue:NSColor(0x3ca5ec),
    groupPeerNameBlue:NSColor(0x3d72ed),
    peerAvatarRedTop: NSColor(0xff885e),
    peerAvatarRedBottom: NSColor(0xff516a),
    peerAvatarOrangeTop: NSColor(0xffcd6a),
    peerAvatarOrangeBottom: NSColor(0xffa85c),
    peerAvatarVioletTop: NSColor(0x82b1ff),
    peerAvatarVioletBottom: NSColor(0x665fff),
    peerAvatarGreenTop: NSColor(0xa0de7e),
    peerAvatarGreenBottom: NSColor(0x54cb68),
    peerAvatarCyanTop: NSColor(0x53edd6),
    peerAvatarCyanBottom: NSColor(0x28c9b7),
    peerAvatarBlueTop: NSColor(0x72d5fd),
    peerAvatarBlueBottom: NSColor(0x2a9ef1),
    peerAvatarPinkTop: NSColor(0xe0a2f3),
    peerAvatarPinkBottom: NSColor(0xd669ed),
    bubbleBackgroundHighlight_incoming: NSColor(0xeaeaea),
    bubbleBackgroundHighlight_outgoing: NSColor(0x4b7bad),
    chatDateActive: NSColor(0xffffff, 1.0),
    chatDateText: NSColor(0x333333),
    revealAction_neutral1_background: NSColor(0x4892f2),
    revealAction_neutral1_foreground: NSColor(0xffffff),
    revealAction_neutral2_background: NSColor(0xf09a37),
    revealAction_neutral2_foreground: NSColor(0xffffff),
    revealAction_destructive_background: NSColor(0xff3824),
    revealAction_destructive_foreground: NSColor(0xffffff),
    revealAction_constructive_background: NSColor(0x00c900),
    revealAction_constructive_foreground: NSColor(0xffffff),
    revealAction_accent_background: NSColor(0x2481cc),
    revealAction_accent_foreground: NSColor(0xffffff),
    revealAction_warning_background: NSColor(0xff9500),
    revealAction_warning_foreground: NSColor(0xffffff),
    revealAction_inactive_background: NSColor(0xbcbcc3),
    revealAction_inactive_foreground: NSColor(0xffffff),
    chatBackground: NSColor(0xffffff),
    listBackground: NSColor(0xf4f4f4)
)



/*
 colors[0] = NSColor(0xfc5c51); // red
 colors[1] = NSColor(0xfa790f); // orange
 colors[2] = NSColor(0x895dd5); // violet
 colors[3] = NSColor(0x0fb297); // green
 colors[4] = NSColor(0x00c1a6); // cyan
 colors[5] = NSColor(0x3ca5ec); // light blue
 colors[6] = NSColor(0x3d72ed); // blue
 */

public let tintedNightPalette = ColorPalette(isNative: true, isDark: true,
                                           tinted: true,
                                           name:"Tinted Blue",
                                           parent: .tintedNight,
                                           wallpaper: .none,
                                           copyright: "Telegram",
                                           accentList: [NSColor(0x2ea6ff),
                                                        NSColor(0xf83b4c),
                                                        NSColor(0xff7519),
                                                        NSColor(0xeba239),
                                                        NSColor(0x29b327),
                                                        NSColor(0x00c2ed),
                                                        NSColor(0x7748ff),
                                                        NSColor(0xff5da2)],
                                           basicAccent: NSColor(0x2ea6ff),
                                           background: NSColor(0x18222d),
                                           text: NSColor(0xffffff),
                                           grayText: NSColor(0xb1c3d5),
                                           link: NSColor(0x62bcf9),
                                           accent: NSColor(0x2ea6ff),
                                           redUI: NSColor(0xef5b5b),
                                           greenUI: NSColor(0x49ad51),
                                           blackTransparent: NSColor(0x000000, 0.6),
                                           grayTransparent: NSColor(0x2f313d, 0.5),
                                           grayUI: NSColor(0x18222d),
                                           darkGrayText: NSColor(0xb1c3d5),
                                           blueText: NSColor(0x62bcf9),
                                           blueSelect: NSColor(0x3d6a97),
                                           selectText: NSColor(0x3e6b9b),
                                           blueFill: NSColor(0x2ea6ff),
                                           border: NSColor(0x213040),
                                           grayBackground: NSColor(0x213040),
                                           grayForeground: NSColor(0x213040),
                                           grayIcon: NSColor(0xb1c3d5),
                                           blueIcon: NSColor(0x2ea6ff),
                                           badgeMuted: NSColor(0xb1c3d5),
                                           badge: NSColor(0x2ea6ff),
                                           indicatorColor: NSColor(0xffffff),
                                           selectMessage: NSColor(0x0F161E),
                                           monospacedPre: NSColor(0x2ea6ff),
                                           monospacedCode: NSColor(0x2ea6ff),
                                           monospacedPreBubble_incoming: NSColor(0xffffff),
                                           monospacedPreBubble_outgoing: NSColor(0xffffff),
                                           monospacedCodeBubble_incoming: NSColor(0xffffff),
                                           monospacedCodeBubble_outgoing: NSColor(0xffffff),
                                           selectTextBubble_incoming: NSColor(0x3e6b9b),
                                           selectTextBubble_outgoing: NSColor(0x355a80),
                                           bubbleBackground_incoming: NSColor(0x213040),
                                           bubbleBackground_outgoing: NSColor(0x3d6a97),
                                           bubbleBorder_incoming: NSColor(0x213040),
                                           bubbleBorder_outgoing: NSColor(0x3d6a97),
                                           grayTextBubble_incoming: NSColor(0xb1c3d5),
                                           grayTextBubble_outgoing: NSColor(0xEFFAFF, 0.8),
                                           grayIconBubble_incoming: NSColor(0xb1c3d5),
                                           grayIconBubble_outgoing: NSColor(0xb1c3d5),
                                           blueIconBubble_incoming: NSColor(0xb1c3d5),
                                           blueIconBubble_outgoing: NSColor(0xEFFAFF, 0.8),
                                           linkBubble_incoming: NSColor(0x62bcf9),
                                           linkBubble_outgoing: NSColor(0x62bcf9),
                                           textBubble_incoming: NSColor(0xffffff),
                                           textBubble_outgoing: NSColor(0xffffff),
                                           selectMessageBubble: NSColor(0x213040),
                                           fileActivityBackground: NSColor(0x2ea6ff, 0.8),
                                           fileActivityForeground: NSColor(0xffffff),
                                           fileActivityBackgroundBubble_incoming: NSColor(0xb1c3d5),
                                           fileActivityBackgroundBubble_outgoing: NSColor(0xffffff),
                                           fileActivityForegroundBubble_incoming: NSColor(0x213040),
                                           fileActivityForegroundBubble_outgoing: NSColor(0x3d6a97),
                                           waveformBackground: NSColor(0xb1c3d5, 0.7),
                                           waveformForeground: NSColor(0x2ea6ff, 0.8),
                                           waveformBackgroundBubble_incoming: NSColor(0xb1c3d5),
                                           waveformBackgroundBubble_outgoing: NSColor(0xb1c3d5),
                                           waveformForegroundBubble_incoming: NSColor(0xffffff),
                                           waveformForegroundBubble_outgoing: NSColor(0xffffff),
                                           webPreviewActivity: NSColor(0x62bcf9),
                                           webPreviewActivityBubble_incoming: NSColor(0xffffff),
                                           webPreviewActivityBubble_outgoing: NSColor(0xffffff),
                                           redBubble_incoming: NSColor(0xef5b5b),
                                           redBubble_outgoing: NSColor(0xef5b5b),
                                           greenBubble_incoming: NSColor(0x49ad51),
                                           greenBubble_outgoing: NSColor(0x49ad51),
                                           chatReplyTitle: NSColor(0x62bcf9),
                                           chatReplyTextEnabled: NSColor(0xffffff),
                                           chatReplyTextDisabled: NSColor(0xb1c3d5),
                                           chatReplyTitleBubble_incoming: NSColor(0xffffff),
                                           chatReplyTitleBubble_outgoing: NSColor(0xffffff),
                                           chatReplyTextEnabledBubble_incoming: NSColor(0xffffff),
                                           chatReplyTextEnabledBubble_outgoing: NSColor(0xffffff),
                                           chatReplyTextDisabledBubble_incoming: NSColor(0xb1c3d5),
                                           chatReplyTextDisabledBubble_outgoing: NSColor(0xb1c3d5),
                                           groupPeerNameRed: NSColor(0xff8e86),
                                           groupPeerNameOrange: NSColor(0xffa357),
                                           groupPeerNameViolet: NSColor(0xbf9aff),
                                           groupPeerNameGreen: NSColor(0x4dd6bf),
                                           groupPeerNameCyan: NSColor(0x45e8d1),
                                           groupPeerNameLightBlue: NSColor(0x7ac9ff),
                                           groupPeerNameBlue: NSColor(0x7aa2ff),
                                           peerAvatarRedTop: NSColor(0xffac8e),
                                           peerAvatarRedBottom: NSColor(0xff8597),
                                           peerAvatarOrangeTop: NSColor(0xffdc97),
                                           peerAvatarOrangeBottom: NSColor(0xffc28d),
                                           peerAvatarVioletTop: NSColor(0xa8c8ff),
                                           peerAvatarVioletBottom: NSColor(0x948fff),
                                           peerAvatarGreenTop: NSColor(0xcdffb2),
                                           peerAvatarGreenBottom: NSColor(0x90f4a0),
                                           peerAvatarCyanTop: NSColor(0x8bffee),
                                           peerAvatarCyanBottom: NSColor(0x6af1e2),
                                           peerAvatarBlueTop: NSColor(0x9de3ff),
                                           peerAvatarBlueBottom: NSColor(0x6cc2ff),
                                           peerAvatarPinkTop: NSColor(0xf1c4ff),
                                           peerAvatarPinkBottom: NSColor(0xee9cff),
                                           bubbleBackgroundHighlight_incoming: NSColor(0x2D3A49),
                                           bubbleBackgroundHighlight_outgoing: NSColor(0x5079A1),
                                           chatDateActive: NSColor(0x18222d),
                                           chatDateText: NSColor(0xb1c3d5),
                                           revealAction_neutral1_background: NSColor(0x007cd6),
                                           revealAction_neutral1_foreground: NSColor(0xffffff),
                                           revealAction_neutral2_background: NSColor(0xcd7800),
                                           revealAction_neutral2_foreground: NSColor(0xffffff),
                                           revealAction_destructive_background: NSColor(0xc70c0c),
                                           revealAction_destructive_foreground: NSColor(0xffffff),
                                           revealAction_constructive_background: NSColor(0x08a723),
                                           revealAction_constructive_foreground: NSColor(0xffffff),
                                           revealAction_accent_background: NSColor(0x007cd6),
                                           revealAction_accent_foreground: NSColor(0xffffff),
                                           revealAction_warning_background: NSColor(0xcd7800),
                                           revealAction_warning_foreground: NSColor(0xffffff),
                                           revealAction_inactive_background: NSColor(0x26384c),
                                           revealAction_inactive_foreground: NSColor(0xffffff),
                                           chatBackground: NSColor(0x18222d),
                                           listBackground: NSColor(0x213040)
)

public let dayClassicPalette = ColorPalette(isNative: true,
                                            isDark: false,
                                            tinted: false,
                                            name:"Day Classic",
                                            parent: .dayClassic,
                                            wallpaper: .builtin,
                                            copyright: "Telegram",
                                            accentList: [],
                                            basicAccent: NSColor(0x2481cc),
                                            background: NSColor(0xffffff),
                                            text: NSColor(0x000000),
                                            grayText: NSColor(0x999999),
                                            link: NSColor(0x2481cc),
                                            accent: NSColor(0x2481cc),
                                            redUI: NSColor(0xff3b30),
                                            greenUI: NSColor(0x63DA6E),
                                            blackTransparent: NSColor(0x000000,0.6),
                                            grayTransparent: NSColor(0xf4f4f4,0.4),
                                            grayUI: NSColor(0xFaFaFa),
                                            darkGrayText: NSColor(0x333333),
                                            blueText: NSColor(0x2481CC),
                                            blueSelect: NSColor(0x4c91c7),
                                            selectText: NSColor(0xeaeaea),
                                            blueFill: NSColor(0x4ba3e2),
                                            border: NSColor(0xeaeaea),
                                            grayBackground: NSColor(0xf4f4f4),
                                            grayForeground: NSColor(0xe4e4e4),
                                            grayIcon: NSColor(0x9e9e9e),
                                            blueIcon: NSColor(0x0f8fe4),
                                            badgeMuted: NSColor(0xd7d7d7),
                                            badge: NSColor(0x4ba3e2),
                                            indicatorColor: NSColor(0x464a57),
                                            selectMessage: NSColor(0xeaeaea),
                                            monospacedPre: NSColor(0x000000),
                                            monospacedCode: NSColor(0xff3b30),
                                            monospacedPreBubble_incoming: NSColor(0xff3b30),
                                            monospacedPreBubble_outgoing: NSColor(0x000000),
                                            monospacedCodeBubble_incoming: NSColor(0xff3b30),
                                            monospacedCodeBubble_outgoing: NSColor(0x000000),
                                            selectTextBubble_incoming: NSColor(0xCCDDEA),
                                            selectTextBubble_outgoing: NSColor(0xCCDDEA),
                                            bubbleBackground_incoming: NSColor(0xffffff),
                                            bubbleBackground_outgoing: NSColor(0xE1FFC7),
                                            bubbleBorder_incoming: NSColor(0x86A9C9,0.5),
                                            bubbleBorder_outgoing: NSColor(0x86A9C9,0.5),
                                            grayTextBubble_incoming: NSColor(0x999999),
                                            grayTextBubble_outgoing: NSColor(0x008c09,0.8),
                                            grayIconBubble_incoming: NSColor(0x999999),
                                            grayIconBubble_outgoing: NSColor(0x008c09,0.8),
                                            blueIconBubble_incoming: NSColor(0x999999),
                                            blueIconBubble_outgoing: NSColor(0x008c09,0.8),
                                            linkBubble_incoming: NSColor(0x2481cc),
                                            linkBubble_outgoing: NSColor(0x004bad),
                                            textBubble_incoming: NSColor(0x000000),
                                            textBubble_outgoing: NSColor(0x000000),
                                            selectMessageBubble: NSColor(0xEDF4F9),
                                            fileActivityBackground: NSColor(0x4ba3e2),
                                            fileActivityForeground: NSColor(0xffffff),
                                            fileActivityBackgroundBubble_incoming: NSColor(0x3ca7fe),
                                            fileActivityBackgroundBubble_outgoing: NSColor(0x00a700),
                                            fileActivityForegroundBubble_incoming: NSColor(0xffffff),
                                            fileActivityForegroundBubble_outgoing: NSColor(0xffffff),
                                            waveformBackground: NSColor(0x9e9e9e,0.7),
                                            waveformForeground: NSColor(0x4ba3e2),
                                            waveformBackgroundBubble_incoming: NSColor(0x3ca7fe,0.6),
                                            waveformBackgroundBubble_outgoing: NSColor(0x00a700,0.6),
                                            waveformForegroundBubble_incoming: NSColor(0x3ca7fe),
                                            waveformForegroundBubble_outgoing: NSColor(0x00a700),
                                            webPreviewActivity: NSColor(0x2481cc),
                                            webPreviewActivityBubble_incoming: NSColor(0x2481cc),
                                            webPreviewActivityBubble_outgoing: NSColor(0x00a700),
                                            redBubble_incoming: NSColor(0xff3b30),
                                            redBubble_outgoing: NSColor(0xff3b30),
                                            greenBubble_incoming: NSColor(0x63DA6E),
                                            greenBubble_outgoing: NSColor(0x63DA6E),
                                            chatReplyTitle: NSColor(0x2481cc),
                                            chatReplyTextEnabled: NSColor(0x000000),
                                            chatReplyTextDisabled: NSColor(0x999999),
                                            chatReplyTitleBubble_incoming: NSColor(0x2481cc),
                                            chatReplyTitleBubble_outgoing: NSColor(0x00a700),
                                            chatReplyTextEnabledBubble_incoming: NSColor(0x000000),
                                            chatReplyTextEnabledBubble_outgoing: NSColor(0x000000),
                                            chatReplyTextDisabledBubble_incoming: NSColor(0x999999),
                                            chatReplyTextDisabledBubble_outgoing: NSColor(0x008c09,0.8),
                                            groupPeerNameRed: NSColor(0xfc5c51),
                                            groupPeerNameOrange: NSColor(0xfa790f),
                                            groupPeerNameViolet: NSColor(0x895dd5),
                                            groupPeerNameGreen: NSColor(0x0fb297),
                                            groupPeerNameCyan: NSColor(0x00c1a6),
                                            groupPeerNameLightBlue: NSColor(0x3ca5ec),
                                            groupPeerNameBlue: NSColor(0x3d72ed),
                                            peerAvatarRedTop: NSColor(0xff885e),
                                            peerAvatarRedBottom: NSColor(0xff516a),
                                            peerAvatarOrangeTop: NSColor(0xffcd6a),
                                            peerAvatarOrangeBottom: NSColor(0xffa85c),
                                            peerAvatarVioletTop: NSColor(0x82b1ff),
                                            peerAvatarVioletBottom: NSColor(0x665fff),
                                            peerAvatarGreenTop: NSColor(0xa0de7e),
                                            peerAvatarGreenBottom: NSColor(0x54cb68),
                                            peerAvatarCyanTop: NSColor(0x53edd6),
                                            peerAvatarCyanBottom: NSColor(0x28c9b7),
                                            peerAvatarBlueTop: NSColor(0x72d5fd),
                                            peerAvatarBlueBottom: NSColor(0x2a9ef1),
                                            peerAvatarPinkTop: NSColor(0xe0a2f3),
                                            peerAvatarPinkBottom: NSColor(0xd669ed),
                                            bubbleBackgroundHighlight_incoming: NSColor(0xd9f4ff),
                                            bubbleBackgroundHighlight_outgoing: NSColor(0xc8ffa6),
                                            chatDateActive: NSColor(0xffffff, 1.0),
                                            chatDateText: NSColor(0x999999),
                                            revealAction_neutral1_background: NSColor(0x4892f2),
                                            revealAction_neutral1_foreground: NSColor(0xffffff),
                                            revealAction_neutral2_background: NSColor(0xf09a37),
                                            revealAction_neutral2_foreground: NSColor(0xffffff),
                                            revealAction_destructive_background: NSColor(0xff3824),
                                            revealAction_destructive_foreground: NSColor(0xffffff),
                                            revealAction_constructive_background: NSColor(0x00c900),
                                            revealAction_constructive_foreground: NSColor(0xffffff),
                                            revealAction_accent_background: NSColor(0x2481cc),
                                            revealAction_accent_foreground: NSColor(0xffffff),
                                            revealAction_warning_background: NSColor(0xff9500),
                                            revealAction_warning_foreground: NSColor(0xffffff),
                                            revealAction_inactive_background: NSColor(0xbcbcc3),
                                            revealAction_inactive_foreground: NSColor(0xffffff),
                                            chatBackground: NSColor(0xffffff),
                                            listBackground: NSColor(0xf4f4f4)
)

public let darkPalette = ColorPalette(isNative: true, isDark:true,
                                      tinted: false,
                                      name:"Dark",
                                      parent: .dark,
                                      wallpaper: .none,
                                      copyright: "Telegram",
                                      accentList: [NSColor(0x04afc8),
                                                   NSColor(0xf83b4c),
                                                   NSColor(0xff7519),
                                                   NSColor(0xeba239),
                                                   NSColor(0x29b327),
                                                   NSColor(0x00c2ed),
                                                   NSColor(0x7748ff),
                                                   NSColor(0xff5da2)],
                                      basicAccent: NSColor(0x04afc8),
                                      background: NSColor(0x292b36),
                                      text: NSColor(0xe9e9e9),
                                      grayText: NSColor(0x8699a3),
                                      link: NSColor(0x04afc8),
                                      accent: NSColor(0x04afc8),
                                      redUI: NSColor(0xec6657),
                                      greenUI : NSColor(0x49ad51),
                                      blackTransparent: NSColor(0x000000, 0.6),
                                      grayTransparent: NSColor(0x2f313d, 0.5),
                                      grayUI: NSColor(0x292b36),
                                      darkGrayText : NSColor(0x8699a3),
                                      blueText: NSColor(0x04afc8),
                                      blueSelect: NSColor(0x20889a),
                                      selectText: NSColor(0x8699a3),
                                      blueFill: NSColor(0x04afc8),
                                      border: NSColor(0x464a57),
                                      grayBackground : NSColor(0x464a57),
                                      grayForeground : NSColor(0x3d414d),
                                      grayIcon: NSColor(0x8699a3),
                                      blueIcon: NSColor(0x04afc8),
                                      badgeMuted: NSColor(0x8699a3),
                                      badge: NSColor(0x04afc8),
                                      indicatorColor: NSColor(0xffffff),
                                      selectMessage: NSColor(0x3d414d),
                                      monospacedPre: NSColor(0xffffff),
                                      monospacedCode: NSColor(0xff3b30),
                                      monospacedPreBubble_incoming: NSColor(0xffffff),
                                      monospacedPreBubble_outgoing: NSColor(0xffffff),
                                      monospacedCodeBubble_incoming: NSColor(0xec6657),
                                      monospacedCodeBubble_outgoing: NSColor(0xffffff),
                                      selectTextBubble_incoming: NSColor(0x8699a3),
                                      selectTextBubble_outgoing: NSColor(0x8699a3),
                                      bubbleBackground_incoming: NSColor(0x3d414d),
                                      bubbleBackground_outgoing: NSColor(0x20889a),
                                      bubbleBorder_incoming: NSColor(0x464a57),
                                      bubbleBorder_outgoing: NSColor(0x20889a),
                                      grayTextBubble_incoming: NSColor(0x8699a3),
                                      grayTextBubble_outgoing: NSColor(0xa0d5dd),
                                      grayIconBubble_incoming: NSColor(0x8699a3),
                                      grayIconBubble_outgoing: NSColor(0xa0d5dd),
                                      blueIconBubble_incoming: NSColor(0x8699a3),
                                      blueIconBubble_outgoing: NSColor(0xa0d5dd),
                                      linkBubble_incoming: NSColor(0x04afc8),
                                      linkBubble_outgoing: NSColor(0xffffff),
                                      textBubble_incoming: NSColor(0xe9e9e9),
                                      textBubble_outgoing: NSColor(0xffffff),
                                      selectMessageBubble: NSColor(0x3d414d),
                                      fileActivityBackground: NSColor(0x04afc8),
                                      fileActivityForeground: NSColor(0xffffff),
                                      fileActivityBackgroundBubble_incoming: NSColor(0x04afc8),
                                      fileActivityBackgroundBubble_outgoing: NSColor(0xffffff),
                                      fileActivityForegroundBubble_incoming: NSColor(0xffffff),
                                      fileActivityForegroundBubble_outgoing: NSColor(0x20889a),
                                      waveformBackground: NSColor(0x8699a3, 0.7),
                                      waveformForeground: NSColor(0x04afc8),
                                      waveformBackgroundBubble_incoming: NSColor(0x8699a3),
                                      waveformBackgroundBubble_outgoing: NSColor(0xa0d5dd),
                                      waveformForegroundBubble_incoming: NSColor(0x04afc8),
                                      waveformForegroundBubble_outgoing: NSColor(0xffffff),
                                      webPreviewActivity : NSColor(0x04afc8),
                                      webPreviewActivityBubble_incoming : NSColor(0x04afc8),
                                      webPreviewActivityBubble_outgoing : NSColor(0xffffff),
                                      redBubble_incoming : NSColor(0xec6657),
                                      redBubble_outgoing : NSColor(0xec6657),
                                      greenBubble_incoming : NSColor(0x49ad51),
                                      greenBubble_outgoing : NSColor(0x49ad51),
                                      chatReplyTitle: NSColor(0x04afc8),
                                      chatReplyTextEnabled: NSColor(0xe9e9e9),
                                      chatReplyTextDisabled: NSColor(0x8699a3),
                                      chatReplyTitleBubble_incoming: NSColor(0xffffff),
                                      chatReplyTitleBubble_outgoing: NSColor(0xffffff),
                                      chatReplyTextEnabledBubble_incoming: NSColor(0xffffff),
                                      chatReplyTextEnabledBubble_outgoing: NSColor(0xffffff),
                                      chatReplyTextDisabledBubble_incoming: NSColor(0x8699a3),
                                      chatReplyTextDisabledBubble_outgoing: NSColor(0xa0d5dd),
                                      groupPeerNameRed : NSColor(0xfc5c51),
                                      groupPeerNameOrange : NSColor(0xfa790f),
                                      groupPeerNameViolet : NSColor(0x895dd5),
                                      groupPeerNameGreen : NSColor(0x0fb297),
                                      groupPeerNameCyan : NSColor(0x00c1a6),
                                      groupPeerNameLightBlue : NSColor(0x3ca5ec),
                                      groupPeerNameBlue : NSColor(0x3d72ed),
                                      peerAvatarRedTop: NSColor(0xff885e),
                                      peerAvatarRedBottom: NSColor(0xff516a),
                                      peerAvatarOrangeTop : NSColor(0xffcd6a),
                                      peerAvatarOrangeBottom : NSColor(0xffa85c),
                                      peerAvatarVioletTop : NSColor(0x82b1ff),
                                      peerAvatarVioletBottom : NSColor(0x665fff),
                                      peerAvatarGreenTop : NSColor(0xa0de7e),
                                      peerAvatarGreenBottom : NSColor(0x54cb68),
                                      peerAvatarCyanTop : NSColor(0x53edd6),
                                      peerAvatarCyanBottom : NSColor(0x28c9b7),
                                      peerAvatarBlueTop : NSColor(0x72d5fd),
                                      peerAvatarBlueBottom : NSColor(0x2a9ef1),
                                      peerAvatarPinkTop : NSColor(0xe0a2f3),
                                      peerAvatarPinkBottom : NSColor(0xd669ed),
                                      bubbleBackgroundHighlight_incoming : NSColor(0x525768),
                                      bubbleBackgroundHighlight_outgoing : NSColor(0x387080),
                                      chatDateActive : NSColor(0x292b36),
                                      chatDateText : NSColor(0x8699a3),
                                      revealAction_neutral1_background: NSColor(0x666666),
                                      revealAction_neutral1_foreground: NSColor(0xffffff),
                                      revealAction_neutral2_background: NSColor(0xcd7800),
                                      revealAction_neutral2_foreground: NSColor(0xffffff),
                                      revealAction_destructive_background: NSColor(0xc70c0c),
                                      revealAction_destructive_foreground: NSColor(0xffffff),
                                      revealAction_constructive_background: NSColor(0x08a723),
                                      revealAction_constructive_foreground: NSColor(0xffffff),
                                      revealAction_accent_background: NSColor(0x666666),
                                      revealAction_accent_foreground: NSColor(0xffffff),
                                      revealAction_warning_background: NSColor(0xcd7800),
                                      revealAction_warning_foreground: NSColor(0xffffff),
                                      revealAction_inactive_background: NSColor(0x666666),
                                      revealAction_inactive_foreground: NSColor(0xffffff),
                                      chatBackground: NSColor(0x292b36),
                                      listBackground: NSColor(0x3d414d)
)


public let mojavePalette = ColorPalette(isNative: true, isDark: true,
                                        tinted: false,
                                        name: "Mojave",
                                        parent: .mojave,
                                        wallpaper: .none,
                                        copyright: "Telegram",
                                        accentList: [NSColor(0x2ea6ff),
                                                     NSColor(0xf83b4c),
                                                     NSColor(0xff7519),
                                                     NSColor(0xeba239),
                                                     NSColor(0x29b327),
                                                     NSColor(0x00c2ed),
                                                     NSColor(0x7748ff),
                                                     NSColor(0xff5da2)],
                                        basicAccent: NSColor(0x2ea6ff),
                                        background: NSColor(0x292a2f),
                                        text: NSColor(0xffffff),
                                        grayText: NSColor(0xb1c3d5),
                                        link: NSColor(0x2ea6ff),
                                        accent: NSColor(0x2ea6ff),
                                        redUI: NSColor(0xef5b5b),
                                        greenUI: NSColor(0x49ad51),
                                        blackTransparent: NSColor(0x000000, 0.6),
                                        grayTransparent: NSColor(0x3e464c, 0.5),
                                        grayUI: NSColor(0x292A2F),
                                        darkGrayText: NSColor(0xb1c3d5),
                                        blueText: NSColor(0x2ea6ff),
                                        blueSelect: NSColor(0x3d6a97),
                                        selectText: NSColor(0x3e6b9b),
                                        blueFill: NSColor(0x2ea6ff),
                                        border: NSColor(0x3d474f),
                                        grayBackground: NSColor(0x3e464c),
                                        grayForeground: NSColor(0x3e464c),
                                        grayIcon: NSColor(0xb1c3d5),
                                        blueIcon: NSColor(0x2ea6ff),
                                        badgeMuted: NSColor(0xb1c3d5),
                                        badge: NSColor(0x2ea6ff),
                                        indicatorColor: NSColor(0xffffff),
                                        selectMessage: NSColor(0x42444a),
                                        monospacedPre: NSColor(0xffffff),
                                        monospacedCode: NSColor(0xffffff),
                                        monospacedPreBubble_incoming: NSColor(0xffffff),
                                        monospacedPreBubble_outgoing: NSColor(0xffffff),
                                        monospacedCodeBubble_incoming: NSColor(0xffffff),
                                        monospacedCodeBubble_outgoing: NSColor(0xffffff),
                                        selectTextBubble_incoming: NSColor(0x3e6b9b),
                                        selectTextBubble_outgoing: NSColor(0x355a80),
                                        bubbleBackground_incoming: NSColor(0x4e5058),
                                        bubbleBackground_outgoing: NSColor(0x3d6a97),
                                        bubbleBorder_incoming: NSColor(0x4e5058),
                                        bubbleBorder_outgoing: NSColor(0x3d6a97),
                                        grayTextBubble_incoming: NSColor(0xb1c3d5),
                                        grayTextBubble_outgoing: NSColor(0xEFFAFF, 0.8),
                                        grayIconBubble_incoming: NSColor(0xb1c3d5),
                                        grayIconBubble_outgoing: NSColor(0xb1c3d5),
                                        blueIconBubble_incoming: NSColor(0xb1c3d5),
                                        blueIconBubble_outgoing: NSColor(0xEFFAFF, 0.8),
                                        linkBubble_incoming: NSColor(0x2ea6ff),
                                        linkBubble_outgoing: NSColor(0x2ea6ff),
                                        textBubble_incoming: NSColor(0xffffff),
                                        textBubble_outgoing: NSColor(0xffffff),
                                        selectMessageBubble: NSColor(0x4e5058),
                                        fileActivityBackground: NSColor(0x2ea6ff, 0.8),
                                        fileActivityForeground: NSColor(0xffffff),
                                        fileActivityBackgroundBubble_incoming: NSColor(0xb1c3d5),
                                        fileActivityBackgroundBubble_outgoing: NSColor(0xffffff),
                                        fileActivityForegroundBubble_incoming: NSColor(0x4e5058),
                                        fileActivityForegroundBubble_outgoing: NSColor(0x3d6a97),
                                        waveformBackground: NSColor(0xb1c3d5, 0.7),
                                        waveformForeground: NSColor(0x2ea6ff, 0.8),
                                        waveformBackgroundBubble_incoming: NSColor(0xb1c3d5),
                                        waveformBackgroundBubble_outgoing: NSColor(0xb1c3d5),
                                        waveformForegroundBubble_incoming: NSColor(0xffffff),
                                        waveformForegroundBubble_outgoing: NSColor(0xffffff),
                                        webPreviewActivity: NSColor(0x2ea6ff),
                                        webPreviewActivityBubble_incoming: NSColor(0xffffff),
                                        webPreviewActivityBubble_outgoing: NSColor(0xffffff),
                                        redBubble_incoming: NSColor(0xef5b5b),
                                        redBubble_outgoing: NSColor(0xef5b5b),
                                        greenBubble_incoming: NSColor(0x49ad51),
                                        greenBubble_outgoing: NSColor(0x49ad51),
                                        chatReplyTitle: NSColor(0x2ea6ff),
                                        chatReplyTextEnabled: NSColor(0xffffff),
                                        chatReplyTextDisabled: NSColor(0xb1c3d5),
                                        chatReplyTitleBubble_incoming: NSColor(0xffffff),
                                        chatReplyTitleBubble_outgoing: NSColor(0xffffff),
                                        chatReplyTextEnabledBubble_incoming: NSColor(0xffffff),
                                        chatReplyTextEnabledBubble_outgoing: NSColor(0xffffff),
                                        chatReplyTextDisabledBubble_incoming: NSColor(0xb1c3d5),
                                        chatReplyTextDisabledBubble_outgoing: NSColor(0xb1c3d5),
                                        groupPeerNameRed: NSColor(0xff8e86),
                                        groupPeerNameOrange: NSColor(0xffa357),
                                        groupPeerNameViolet: NSColor(0xbf9aff),
                                        groupPeerNameGreen: NSColor(0x9ccfc3),
                                        groupPeerNameCyan: NSColor(0x45e8d1),
                                        groupPeerNameLightBlue: NSColor(0x7ac9ff),
                                        groupPeerNameBlue: NSColor(0x7aa2ff),
                                        peerAvatarRedTop: NSColor(0xffac8e),
                                        peerAvatarRedBottom: NSColor(0xff8597),
                                        peerAvatarOrangeTop: NSColor(0xffdc97),
                                        peerAvatarOrangeBottom: NSColor(0xffc28d),
                                        peerAvatarVioletTop: NSColor(0xa8c8ff),
                                        peerAvatarVioletBottom: NSColor(0x948fff),
                                        peerAvatarGreenTop: NSColor(0xcdffb2),
                                        peerAvatarGreenBottom: NSColor(0x90f4a0),
                                        peerAvatarCyanTop: NSColor(0x8bffee),
                                        peerAvatarCyanBottom: NSColor(0x6af1e2),
                                        peerAvatarBlueTop: NSColor(0x9de3ff),
                                        peerAvatarBlueBottom: NSColor(0x6cc2ff),
                                        peerAvatarPinkTop: NSColor(0xf1c4ff),
                                        peerAvatarPinkBottom: NSColor(0xee9cff),
                                        bubbleBackgroundHighlight_incoming: NSColor(0x42444a),
                                        bubbleBackgroundHighlight_outgoing: NSColor(0x5079a1),
                                        chatDateActive: NSColor(0x292A2F),
                                        chatDateText: NSColor(0xb1c3d5),
                                        revealAction_neutral1_background: NSColor(0x666666),
                                        revealAction_neutral1_foreground: NSColor(0xffffff),
                                        revealAction_neutral2_background: NSColor(0xcd7800),
                                        revealAction_neutral2_foreground: NSColor(0xffffff),
                                        revealAction_destructive_background: NSColor(0xc70c0c),
                                        revealAction_destructive_foreground: NSColor(0xffffff),
                                        revealAction_constructive_background: NSColor(0x08a723),
                                        revealAction_constructive_foreground: NSColor(0xffffff),
                                        revealAction_accent_background: NSColor(0x666666),
                                        revealAction_accent_foreground: NSColor(0xffffff),
                                        revealAction_warning_background: NSColor(0xcd7800),
                                        revealAction_warning_foreground: NSColor(0xffffff),
                                        revealAction_inactive_background: NSColor(0x666666),
                                        revealAction_inactive_foreground: NSColor(0xffffff),
                                        chatBackground: NSColor(0x292a2f),
                                        listBackground: NSColor(0x3e464c)
)


/*
 public let darkPalette = ColorPalette(background: NSColor(0x282e33), text: NSColor(0xe9e9e9), grayText: NSColor(0x999999), link: NSColor(0x20eeda), accent: NSColor(0x20eeda), redUI: NSColor(0xec6657), greenUI:NSColor(0x63DA6E), blackTransparent: NSColor(0x000000, 0.6), grayTransparent: NSColor(0xf4f4f4, 0.4), grayUI: NSColor(0xFaFaFa), darkGrayText:NSColor(0x333333), blueText:NSColor(0x009687), blueSelect:NSColor(0x009687), selectText:NSColor(0xeaeaea), blueFill: NSColor(0x20eeda), border: NSColor(0x3d444b), grayBackground:NSColor(0x3d444b), grayForeground:NSColor(0xe4e4e4), grayIcon:NSColor(0x757676), blueIcon: NSColor(0x20eeda), badgeMuted:NSColor(0xd7d7d7), badge:NSColor(0x4ba3e2), indicatorColor: NSColor(0xffffff))
 */


private var _theme:Atomic<PresentationTheme> = Atomic(value: whiteTheme)

public let whiteTheme = PresentationTheme(colors: whitePalette, search: SearchTheme(.grayBackground, #imageLiteral(resourceName: "Icon_SearchField").precomposed(), #imageLiteral(resourceName: "Icon_SearchClear").precomposed(), {localizedString("SearchField.Search")}, .text, .grayText))



public var presentation:PresentationTheme {
    return _theme.modify {$0}
}

public func updateTheme(_ theme:PresentationTheme) {
    assertOnMainThread()
    _ = _theme.swap(theme)
}


