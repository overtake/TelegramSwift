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
        
        let properties = whitePalette.listProperties()
        
        var isDark: Bool? = nil
        var paletteName: String? = nil
        
        if lines.count == properties.count {
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
            
            
            for prop in properties {
                if colors[prop] == nil && prop != "isDark" && prop != "name" {
                    return nil
                }
            }
            if let isDark = isDark, let name = paletteName {
                return ColorPalette(isDark: isDark,
                                    name: name,
                                    background: colors["background"]!,
                                     text: colors["text"]!,
                                     grayText: colors["grayText"]!,
                                     link: colors["link"]!,
                                     blueUI: colors["blueUI"]!,
                                     redUI: colors["redUI"]!,
                                     greenUI: colors["greenUI"]!,
                                     blackTransparent: colors["blackTransparent"]!,
                                     grayTransparent: colors["grayTransparent"]!,
                                     grayUI: colors["grayUI"]!,
                                     darkGrayText: colors["darkGrayText"]!,
                                     blueText: colors["blueText"]!,
                                     blueSelect: colors["blueSelect"]!,
                                     selectText: colors["selectText"]!,
                                     blueFill: colors["blueFill"]!,
                                     border: colors["border"]!,
                                     grayBackground: colors["grayBackground"]!,
                                     grayForeground: colors["grayForeground"]!,
                                     grayIcon: colors["grayIcon"]!,
                                     blueIcon: colors["blueIcon"]!,
                                     badgeMuted: colors["badgeMuted"]!,
                                     badge: colors["badge"]!,
                                     indicatorColor: colors["indicatorColor"]!,
                                     selectMessage: colors["selectMessage"]!,
                                     monospacedPre: colors["monospacedPre"]!,
                                     monospacedCode: colors["monospacedCode"]!,
                                     monospacedPreBubble_incoming: colors["monospacedPreBubble_incoming"]!,
                                     monospacedPreBubble_outgoing: colors["monospacedPreBubble_outgoing"]!,
                                     monospacedCodeBubble_incoming: colors["monospacedCodeBubble_incoming"]!,
                                     monospacedCodeBubble_outgoing: colors["monospacedCodeBubble_outgoing"]!,
                                     selectTextBubble_incoming: colors["selectTextBubble_incoming"]!,
                                     selectTextBubble_outgoing: colors["selectTextBubble_outgoing"]!,
                                     bubbleBackground_incoming: colors["bubbleBackground_incoming"]!,
                                     bubbleBackground_outgoing: colors["bubbleBackground_outgoing"]!,
                                     bubbleBorder_incoming: colors["bubbleBorder_incoming"]!,
                                     bubbleBorder_outgoing: colors["bubbleBorder_outgoing"]!,
                                     grayTextBubble_incoming: colors["grayTextBubble_incoming"]!,
                                     grayTextBubble_outgoing: colors["grayTextBubble_outgoing"]!,
                                     grayIconBubble_incoming: colors["grayIconBubble_incoming"]!,
                                     grayIconBubble_outgoing: colors["grayIconBubble_outgoing"]!,
                                     blueIconBubble_incoming: colors["blueIconBubble_incoming"]!,
                                     blueIconBubble_outgoing: colors["blueIconBubble_outgoing"]!,
                                     linkBubble_incoming: colors["linkBubble_incoming"]!,
                                     linkBubble_outgoing: colors["linkBubble_outgoing"]!,
                                     textBubble_incoming: colors["textBubble_incoming"]!,
                                     textBubble_outgoing: colors["textBubble_outgoing"]!,
                                     selectMessageBubble: colors["selectMessageBubble"]!,
                                     fileActivityBackground: colors["fileActivityBackground"]!,
                                     fileActivityForeground: colors["fileActivityForeground"]!,
                                     fileActivityBackgroundBubble_incoming: colors["fileActivityBackgroundBubble_incoming"]!,
                                     fileActivityBackgroundBubble_outgoing: colors["fileActivityBackgroundBubble_outgoing"]!,
                                     fileActivityForegroundBubble_incoming: colors["fileActivityForegroundBubble_incoming"]!,
                                     fileActivityForegroundBubble_outgoing: colors["fileActivityForegroundBubble_outgoing"]!,
                                     waveformBackground: colors["waveformBackground"]!,
                                     waveformForeground: colors["waveformForeground"]!,
                                     waveformBackgroundBubble_incoming: colors["waveformBackgroundBubble_incoming"]!,
                                     waveformBackgroundBubble_outgoing: colors["waveformBackgroundBubble_outgoing"]!,
                                     waveformForegroundBubble_incoming: colors["waveformForegroundBubble_incoming"]!,
                                     waveformForegroundBubble_outgoing: colors["waveformForegroundBubble_outgoing"]!,
                                     webPreviewActivity: colors["webPreviewActivity"]!,
                                     webPreviewActivityBubble_incoming: colors["webPreviewActivityBubble_incoming"]!,
                                     webPreviewActivityBubble_outgoing: colors["webPreviewActivityBubble_outgoing"]!,
                                     redBubble_incoming: colors["redBubble_incoming"]!,
                                     redBubble_outgoing: colors["redBubble_outgoing"]!,
                                     greenBubble_incoming: colors["greenBubble_incoming"]!,
                                     greenBubble_outgoing: colors["greenBubble_outgoing"]!,
                                     chatReplyTitle: colors["chatReplyTitle"]!,
                                     chatReplyTextEnabled: colors["chatReplyTextEnabled"]!,
                                     chatReplyTextDisabled: colors["chatReplyTextDisabled"]!,
                                     chatReplyTitleBubble_incoming: colors["chatReplyTitleBubble_incoming"]!,
                                     chatReplyTitleBubble_outgoing: colors["chatReplyTitleBubble_outgoing"]!,
                                     chatReplyTextEnabledBubble_incoming: colors["chatReplyTextEnabledBubble_incoming"]!,
                                     chatReplyTextEnabledBubble_outgoing: colors["chatReplyTextEnabledBubble_outgoing"]!,
                                     chatReplyTextDisabledBubble_incoming: colors["chatReplyTextDisabledBubble_incoming"]!,
                                     chatReplyTextDisabledBubble_outgoing: colors["chatReplyTextDisabledBubble_outgoing"]!,
                                     groupPeerNameRed: colors["groupPeerNameRed"]!,
                                     groupPeerNameOrange: colors["groupPeerNameOrange"]!,
                                     groupPeerNameViolet: colors["groupPeerNameViolet"]!,
                                     groupPeerNameGreen: colors["groupPeerNameGreen"]!,
                                     groupPeerNameCyan: colors["groupPeerNameCyan"]!,
                                     groupPeerNameLightBlue: colors["groupPeerNameLightBlue"]!,
                                     groupPeerNameBlue: colors["groupPeerNameBlue"]!,
                                     peerAvatarRedTop: colors["peerAvatarRedTop"]!,
                                     peerAvatarRedBottom: colors["peerAvatarRedBottom"]!,
                                     peerAvatarOrangeTop: colors["peerAvatarOrangeTop"]!,
                                     peerAvatarOrangeBottom: colors["peerAvatarOrangeBottom"]!,
                                     peerAvatarVioletTop: colors["peerAvatarVioletTop"]!,
                                     peerAvatarVioletBottom: colors["peerAvatarVioletBottom"]!,
                                     peerAvatarGreenTop: colors["peerAvatarGreenTop"]!,
                                     peerAvatarGreenBottom: colors["peerAvatarGreenBottom"]!,
                                     peerAvatarCyanTop: colors["peerAvatarCyanTop"]!,
                                     peerAvatarCyanBottom: colors["peerAvatarCyanBottom"]!,
                                     peerAvatarBlueTop: colors["peerAvatarBlueTop"]!,
                                     peerAvatarBlueBottom: colors["peerAvatarBlueBottom"]!,
                                     peerAvatarPinkTop: colors["peerAvatarPinkTop"]!,
                                     peerAvatarPinkBottom: colors["peerAvatarPinkBottom"]!,
                                     bubbleBackgroundHighlight_incoming: colors["bubbleBackgroundHighlight_incoming"]!,
                                     bubbleBackgroundHighlight_outgoing: colors["bubbleBackgroundHighlight_outgoing"]!,
                                     chatDateActive: colors["chatDateActive"]!,
                                     chatDateText: colors["chatDateText"]!)
            }
        }
        
    }
    
    return nil
}


func exportCurrentPalette() -> Void {
    var string: String = ""
    
    string += "isDark = \(theme.colors.isDark ? 1 : 0)\n"
    string += "name = \(theme.colors.name)\n"

    for prop in theme.colors.listProperties() {
        if let color = theme.colors.colorFromStringVariable(prop) {
            string += "\(prop) = \(color.hexString.lowercased())\n"
        }
    }
    
    let temp = NSTemporaryDirectory() + "tmac.palette"
    
    try? string.write(to: URL(fileURLWithPath: temp), atomically: true, encoding: .utf8)
    
    //let exportPath = NSTemporaryDirectory() + "\(resource.randomId).mp4"
    savePanel(file: temp, ext: "palette", for: mainWindow)
    
    var bp:Int = 0
    bp += 1
}

