//
//  ParseAppearanceColors.swift
//  Telegram
//
//  Created by keepcoder on 01/12/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

func importPalette(_ path: String) -> ColorPalette? {
    if let data = try? String(contentsOf: URL(fileURLWithPath: path)) {
        let lines = data.components(separatedBy: "\n").filter({!$0.isEmpty})
        
        
        var isDark: Bool = false
        var tinted: Bool = false
        var paletteName: String? = nil
        var copyright: String = "Telegram"
        var parent: TelegramBuiltinTheme = .dayClassic

        var colors:[String: NSColor] = [:]
        for line in lines {
            let components = line.components(separatedBy: "=")
            if components.count == 2 {
                let name = components[0].trimmed
                let value = components[1].trimmed
                
                if name == "name" {
                    paletteName = value
                } else if name == "isDark" {
                    isDark = Int32(value) == 1
                } else if name == "tinted" {
                    tinted = Int32(value) == 1
                } else if name == "copyright" {
                    copyright = value
                } else if name == "parent" {
                    parent = TelegramBuiltinTheme(rawValue: value) ?? .dayClassic
                } else {
                    let components = value.components(separatedBy: ":")
                    var hex:UInt32?
                    var alpha: Float = 1.0
                    
                    if components.count == 1 {
                        hex = UInt32(String(components[0].trimmed.suffix(6)), radix: 16)
                    } else if components.count == 2, let alphaValue = Float(components[1].trimmed) {
                        hex = UInt32(String(components[0].trimmed.suffix(6)), radix: 16)
                        alpha = max(0, min(1, alphaValue))
                    }
                    if let hex = hex {
                        colors[name] = NSColor(hex, CGFloat(alpha))
                    }
                }
            }
        }
        
        if let name = paletteName {
            return ColorPalette(isDark: isDark,
                                tinted: tinted,
                                name: name,
                                parent: parent,
                                copyright: copyright,
                                basicAccent: colors["basicAccent"] ?? parent.palette.basicAccent,
                                background: colors["background"] ?? parent.palette.background,
                                text: colors["text"] ?? parent.palette.text,
                                grayText: colors["grayText"] ?? parent.palette.grayText,
                                link: colors["link"] ?? parent.palette.link,
                                accent: colors["accent"] ?? parent.palette.accent,
                                redUI: colors["redUI"] ?? parent.palette.redUI,
                                greenUI: colors["greenUI"] ?? parent.palette.greenUI,
                                blackTransparent: colors["blackTransparent"] ?? parent.palette.blackTransparent,
                                grayTransparent: colors["grayTransparent"] ?? parent.palette.grayTransparent,
                                grayUI: colors["grayUI"] ?? parent.palette.grayUI,
                                darkGrayText: colors["darkGrayText"] ?? parent.palette.darkGrayText,
                                blueText: colors["blueText"] ?? parent.palette.blueText,
                                blueSelect: colors["blueSelect"] ?? parent.palette.blueSelect,
                                selectText: colors["selectText"] ?? parent.palette.selectText,
                                blueFill: colors["blueFill"] ?? parent.palette.blueFill,
                                border: colors["border"] ?? parent.palette.border,
                                grayBackground: colors["grayBackground"] ?? parent.palette.grayBackground,
                                grayForeground: colors["grayForeground"] ?? parent.palette.grayForeground,
                                grayIcon: colors["grayIcon"] ?? parent.palette.grayIcon,
                                blueIcon: colors["blueIcon"] ?? parent.palette.blueIcon,
                                badgeMuted: colors["badgeMuted"] ?? parent.palette.badgeMuted,
                                badge: colors["badge"] ?? parent.palette.badge,
                                indicatorColor: colors["indicatorColor"] ?? parent.palette.indicatorColor,
                                selectMessage: colors["selectMessage"] ?? parent.palette.selectMessage,
                                monospacedPre: colors["monospacedPre"] ?? parent.palette.monospacedPre,
                                monospacedCode: colors["monospacedCode"] ?? parent.palette.monospacedCode,
                                monospacedPreBubble_incoming: colors["monospacedPreBubble_incoming"] ?? parent.palette.monospacedPreBubble_incoming,
                                monospacedPreBubble_outgoing: colors["monospacedPreBubble_outgoing"] ?? parent.palette.monospacedPreBubble_outgoing,
                                monospacedCodeBubble_incoming: colors["monospacedCodeBubble_incoming"] ?? parent.palette.monospacedCodeBubble_incoming,
                                monospacedCodeBubble_outgoing: colors["monospacedCodeBubble_outgoing"] ?? parent.palette.monospacedCodeBubble_outgoing,
                                selectTextBubble_incoming: colors["selectTextBubble_incoming"] ?? parent.palette.selectTextBubble_incoming,
                                selectTextBubble_outgoing: colors["selectTextBubble_outgoing"] ?? parent.palette.selectTextBubble_outgoing,
                                bubbleBackground_incoming: colors["bubbleBackground_incoming"] ?? parent.palette.bubbleBackground_incoming,
                                bubbleBackground_outgoing: colors["bubbleBackground_outgoing"] ?? parent.palette.bubbleBackground_outgoing,
                                bubbleBorder_incoming: colors["bubbleBorder_incoming"] ?? parent.palette.bubbleBorder_incoming,
                                bubbleBorder_outgoing: colors["bubbleBorder_outgoing"] ?? parent.palette.bubbleBorder_outgoing,
                                grayTextBubble_incoming: colors["grayTextBubble_incoming"] ?? parent.palette.grayTextBubble_incoming,
                                grayTextBubble_outgoing: colors["grayTextBubble_outgoing"] ?? parent.palette.grayTextBubble_outgoing,
                                grayIconBubble_incoming: colors["grayIconBubble_incoming"] ?? parent.palette.grayIconBubble_incoming,
                                grayIconBubble_outgoing: colors["grayIconBubble_outgoing"] ?? parent.palette.grayIconBubble_outgoing,
                                blueIconBubble_incoming: colors["blueIconBubble_incoming"] ?? parent.palette.blueIconBubble_incoming,
                                blueIconBubble_outgoing: colors["blueIconBubble_outgoing"] ?? parent.palette.blueIconBubble_outgoing,
                                linkBubble_incoming: colors["linkBubble_incoming"] ?? parent.palette.linkBubble_incoming,
                                linkBubble_outgoing: colors["linkBubble_outgoing"] ?? parent.palette.linkBubble_outgoing,
                                textBubble_incoming: colors["textBubble_incoming"] ?? parent.palette.textBubble_incoming,
                                textBubble_outgoing: colors["textBubble_outgoing"] ?? parent.palette.textBubble_outgoing,
                                selectMessageBubble: colors["selectMessageBubble"] ?? parent.palette.selectMessageBubble,
                                fileActivityBackground: colors["fileActivityBackground"] ?? parent.palette.fileActivityBackground,
                                fileActivityForeground: colors["fileActivityForeground"] ?? parent.palette.fileActivityForeground,
                                fileActivityBackgroundBubble_incoming: colors["fileActivityBackgroundBubble_incoming"] ?? parent.palette.fileActivityBackgroundBubble_incoming,
                                fileActivityBackgroundBubble_outgoing: colors["fileActivityBackgroundBubble_outgoing"] ?? parent.palette.fileActivityBackgroundBubble_outgoing,
                                fileActivityForegroundBubble_incoming: colors["fileActivityForegroundBubble_incoming"] ?? parent.palette.fileActivityForegroundBubble_incoming,
                                fileActivityForegroundBubble_outgoing: colors["fileActivityForegroundBubble_outgoing"] ?? parent.palette.fileActivityForegroundBubble_outgoing,
                                waveformBackground: colors["waveformBackground"] ?? parent.palette.waveformBackground,
                                waveformForeground: colors["waveformForeground"] ?? parent.palette.waveformForeground,
                                waveformBackgroundBubble_incoming: colors["waveformBackgroundBubble_incoming"] ?? parent.palette.waveformBackgroundBubble_incoming,
                                waveformBackgroundBubble_outgoing: colors["waveformBackgroundBubble_outgoing"] ?? parent.palette.waveformBackgroundBubble_outgoing,
                                waveformForegroundBubble_incoming: colors["waveformForegroundBubble_incoming"] ?? parent.palette.waveformForegroundBubble_incoming,
                                waveformForegroundBubble_outgoing: colors["waveformForegroundBubble_outgoing"] ?? parent.palette.waveformForegroundBubble_outgoing,
                                webPreviewActivity: colors["webPreviewActivity"] ?? parent.palette.webPreviewActivity,
                                webPreviewActivityBubble_incoming: colors["webPreviewActivityBubble_incoming"] ?? parent.palette.webPreviewActivityBubble_incoming,
                                webPreviewActivityBubble_outgoing: colors["webPreviewActivityBubble_outgoing"] ?? parent.palette.webPreviewActivityBubble_outgoing,
                                redBubble_incoming: colors["redBubble_incoming"] ?? parent.palette.redBubble_incoming,
                                redBubble_outgoing: colors["redBubble_outgoing"] ?? parent.palette.redBubble_outgoing,
                                greenBubble_incoming: colors["greenBubble_incoming"] ?? parent.palette.greenBubble_incoming,
                                greenBubble_outgoing: colors["greenBubble_outgoing"] ?? parent.palette.greenBubble_outgoing,
                                chatReplyTitle: colors["chatReplyTitle"] ?? parent.palette.chatReplyTitle,
                                chatReplyTextEnabled: colors["chatReplyTextEnabled"] ?? parent.palette.chatReplyTextEnabled,
                                chatReplyTextDisabled: colors["chatReplyTextDisabled"] ?? parent.palette.chatReplyTextDisabled,
                                chatReplyTitleBubble_incoming: colors["chatReplyTitleBubble_incoming"] ?? parent.palette.chatReplyTitleBubble_incoming,
                                chatReplyTitleBubble_outgoing: colors["chatReplyTitleBubble_outgoing"] ?? parent.palette.chatReplyTitleBubble_outgoing,
                                chatReplyTextEnabledBubble_incoming: colors["chatReplyTextEnabledBubble_incoming"] ?? parent.palette.chatReplyTextEnabledBubble_incoming,
                                chatReplyTextEnabledBubble_outgoing: colors["chatReplyTextEnabledBubble_outgoing"] ?? parent.palette.chatReplyTextEnabledBubble_outgoing,
                                chatReplyTextDisabledBubble_incoming: colors["chatReplyTextDisabledBubble_incoming"] ?? parent.palette.chatReplyTextDisabledBubble_incoming,
                                chatReplyTextDisabledBubble_outgoing: colors["chatReplyTextDisabledBubble_outgoing"] ?? parent.palette.chatReplyTextDisabledBubble_outgoing,
                                groupPeerNameRed: colors["groupPeerNameRed"] ?? parent.palette.groupPeerNameRed,
                                groupPeerNameOrange: colors["groupPeerNameOrange"] ?? parent.palette.groupPeerNameOrange,
                                groupPeerNameViolet: colors["groupPeerNameViolet"] ?? parent.palette.groupPeerNameViolet,
                                groupPeerNameGreen: colors["groupPeerNameGreen"] ?? parent.palette.groupPeerNameGreen,
                                groupPeerNameCyan: colors["groupPeerNameCyan"] ?? parent.palette.groupPeerNameCyan,
                                groupPeerNameLightBlue: colors["groupPeerNameLightBlue"] ?? parent.palette.groupPeerNameLightBlue,
                                groupPeerNameBlue: colors["groupPeerNameBlue"] ?? parent.palette.groupPeerNameBlue,
                                peerAvatarRedTop: colors["peerAvatarRedTop"] ?? parent.palette.peerAvatarRedTop,
                                peerAvatarRedBottom: colors["peerAvatarRedBottom"] ?? parent.palette.peerAvatarRedBottom,
                                peerAvatarOrangeTop: colors["peerAvatarOrangeTop"] ?? parent.palette.peerAvatarOrangeTop,
                                peerAvatarOrangeBottom: colors["peerAvatarOrangeBottom"] ?? parent.palette.peerAvatarOrangeBottom,
                                peerAvatarVioletTop: colors["peerAvatarVioletTop"] ?? parent.palette.peerAvatarVioletTop,
                                peerAvatarVioletBottom: colors["peerAvatarVioletBottom"] ?? parent.palette.peerAvatarVioletBottom,
                                peerAvatarGreenTop: colors["peerAvatarGreenTop"] ?? parent.palette.peerAvatarGreenTop,
                                peerAvatarGreenBottom: colors["peerAvatarGreenBottom"] ?? parent.palette.peerAvatarGreenBottom,
                                peerAvatarCyanTop: colors["peerAvatarCyanTop"] ?? parent.palette.peerAvatarCyanTop,
                                peerAvatarCyanBottom: colors["peerAvatarCyanBottom"] ?? parent.palette.peerAvatarCyanBottom,
                                peerAvatarBlueTop: colors["peerAvatarBlueTop"] ?? parent.palette.peerAvatarBlueTop,
                                peerAvatarBlueBottom: colors["peerAvatarBlueBottom"] ?? parent.palette.peerAvatarBlueBottom,
                                peerAvatarPinkTop: colors["peerAvatarPinkTop"] ?? parent.palette.peerAvatarPinkTop,
                                peerAvatarPinkBottom: colors["peerAvatarPinkBottom"] ?? parent.palette.peerAvatarPinkBottom,
                                bubbleBackgroundHighlight_incoming: colors["bubbleBackgroundHighlight_incoming"] ?? parent.palette.bubbleBackgroundHighlight_incoming,
                                bubbleBackgroundHighlight_outgoing: colors["bubbleBackgroundHighlight_outgoing"] ?? parent.palette.bubbleBackgroundHighlight_outgoing,
                                chatDateActive: colors["chatDateActive"] ?? parent.palette.chatDateActive,
                                chatDateText: colors["chatDateText"] ?? parent.palette.chatDateText,
                                revealAction_neutral1_background: colors["revealAction_neutral1_background"] ?? parent.palette.revealAction_neutral1_background,
                                revealAction_neutral1_foreground: colors["revealAction_neutral1_foreground"] ?? parent.palette.revealAction_neutral1_foreground,
                                revealAction_neutral2_background: colors["revealAction_neutral2_background"] ?? parent.palette.revealAction_neutral2_background,
                                revealAction_neutral2_foreground: colors["revealAction_neutral2_foreground"] ?? parent.palette.revealAction_neutral2_foreground,
                                revealAction_destructive_background: colors["revealAction_destructive_background"] ?? parent.palette.revealAction_destructive_background,
                                revealAction_destructive_foreground: colors["revealAction_destructive_foreground"] ?? parent.palette.revealAction_destructive_foreground,
                                revealAction_constructive_background: colors["revealAction_constructive_background"] ?? parent.palette.revealAction_constructive_background,
                                revealAction_constructive_foreground: colors["revealAction_constructive_foreground"] ?? parent.palette.revealAction_constructive_foreground,
                                revealAction_accent_background: colors["revealAction_accent_background"] ?? parent.palette.revealAction_accent_background,
                                revealAction_accent_foreground: colors["revealAction_accent_foreground"] ?? parent.palette.revealAction_accent_foreground,
                                revealAction_warning_background: colors["revealAction_warning_background"] ?? parent.palette.revealAction_warning_background,
                                revealAction_warning_foreground: colors["revealAction_warning_foreground"] ?? parent.palette.revealAction_warning_foreground,
                                revealAction_inactive_background: colors["revealAction_inactive_background"] ?? parent.palette.revealAction_inactive_background,
                                revealAction_inactive_foreground: colors["revealAction_inactive_foreground"] ?? parent.palette.revealAction_inactive_foreground,
                                chatBackground: colors["chatBackground"] ?? parent.palette.chatBackground)
        }
        
    }
    
    return nil
}


func exportPalette(palette: ColorPalette, completion:((String?)->Void)? = nil) -> Void {
    let string = palette.toString
    let temp = NSTemporaryDirectory() + "tmac.palette"
    try? string.write(to: URL(fileURLWithPath: temp), atomically: true, encoding: .utf8)
    savePanel(file: temp, ext: "palette", for: mainWindow, defaultName: "\(palette.name).palette", completion: completion)
}



func findBestNameForPalette(_ palette: ColorPalette) -> String {
    
    let readList = Bundle.main.path(forResource: "theme-names-tree", ofType: nil)
    
    if let readList = readList, let string = try? String(contentsOfFile: readList) {
        let lines = string.components(separatedBy: "\n")
        
        var list:[(String, NSColor)] = []
        
        for line in lines {
            let value = line.components(separatedBy: "=")
            if value.count == 2 {
                if let color = NSColor(hexString: value[1]) {
                    let name = value[0].components(separatedBy: " ").map({ $0.capitalizingFirstLetter() }).joined()
                    list.append((name, color))
                }
            }
        }
        
        if list.count > 0 {
            
            let first = pow(palette.accent.hsv.0 - list[0].1.hsv.0, 2) + pow(palette.accent.hsv.1 - list[0].1.hsv.1, 2) + pow(palette.accent.hsv.2 - list[0].1.hsv.2, 2)
            var closest: (Int, CGFloat) = (0, first)
            
            
            for i in 0 ..< list.count {
                let distance = pow(palette.accent.hsv.0 - list[i].1.hsv.0, 2) + pow(palette.accent.hsv.1 - list[i].1.hsv.1, 2) + pow(palette.accent.hsv.2 - list[i].1.hsv.2, 2)
                if distance < closest.1 {
                    closest = (i, distance)
                }
            }
            
            if let animalsPath = Bundle.main.path(forResource: "animals", ofType: nil), let string = try? String(contentsOfFile: animalsPath) {
                let animals = string.components(separatedBy: "\n").filter { !$0.isEmpty }
                let animal = animals[Int(arc4random()) % animals.count].capitalizingFirstLetter()
                return list[closest.0].0 + " " + animal
            }
            return list[closest.0].0
        }
        
    }
    
    return palette.name
}
