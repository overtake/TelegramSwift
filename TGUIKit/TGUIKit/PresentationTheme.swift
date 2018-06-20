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


public final class ColorPalette : Equatable {
    
    public let isDark: Bool
    public let name: String
    
    public let background: NSColor
    public let text: NSColor
    public let grayText:NSColor
    public let link:NSColor
    public let blueUI:NSColor
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
    
    public init(isDark: Bool,
                name: String,
                background:NSColor,
                text: NSColor,
                grayText: NSColor,
                link: NSColor,
                blueUI:NSColor,
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
                chatDateText: NSColor) {
        self.isDark = isDark
        self.name = name
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
        
        self.monospacedPre = monospacedPre
        self.monospacedCode = monospacedCode
        self.monospacedPreBubble_incoming = monospacedPreBubble_incoming
        self.monospacedPreBubble_outgoing = monospacedPreBubble_outgoing
        self.monospacedCodeBubble_incoming = monospacedCodeBubble_incoming
        self.monospacedCodeBubble_outgoing = monospacedCodeBubble_outgoing
        self.selectTextBubble_incoming = selectTextBubble_incoming
        self.selectTextBubble_outgoing = selectTextBubble_outgoing
        self.bubbleBackground_incoming = bubbleBackground_incoming
        self.bubbleBackground_outgoing = bubbleBackground_outgoing
        self.bubbleBorder_incoming = bubbleBorder_incoming
        self.bubbleBorder_outgoing = bubbleBorder_outgoing
        self.grayTextBubble_incoming = grayTextBubble_incoming
        self.grayTextBubble_outgoing = grayTextBubble_outgoing
        self.grayIconBubble_incoming = grayIconBubble_incoming
        self.grayIconBubble_outgoing = grayIconBubble_outgoing
        self.blueIconBubble_incoming = blueIconBubble_incoming
        self.blueIconBubble_outgoing = blueIconBubble_outgoing
        self.linkBubble_incoming = linkBubble_incoming
        self.linkBubble_outgoing = linkBubble_outgoing
        self.textBubble_incoming = textBubble_incoming
        self.textBubble_outgoing = textBubble_outgoing
        self.selectMessageBubble = selectMessageBubble
        self.fileActivityBackground = fileActivityBackground
        self.fileActivityForeground = fileActivityForeground
        self.fileActivityBackgroundBubble_incoming = fileActivityBackgroundBubble_incoming
        self.fileActivityBackgroundBubble_outgoing = fileActivityBackgroundBubble_outgoing
        self.fileActivityForegroundBubble_incoming = fileActivityForegroundBubble_incoming
        self.fileActivityForegroundBubble_outgoing = fileActivityForegroundBubble_outgoing
        self.waveformBackground = waveformBackground
        self.waveformForeground = waveformForeground
        self.waveformBackgroundBubble_incoming = waveformBackgroundBubble_incoming
        self.waveformBackgroundBubble_outgoing = waveformBackgroundBubble_outgoing
        self.waveformForegroundBubble_incoming = waveformForegroundBubble_incoming
        self.waveformForegroundBubble_outgoing = waveformForegroundBubble_outgoing
        self.webPreviewActivity = webPreviewActivity
        self.webPreviewActivityBubble_incoming = webPreviewActivityBubble_incoming
        self.webPreviewActivityBubble_outgoing = webPreviewActivityBubble_outgoing
        self.redBubble_incoming = redBubble_incoming
        self.redBubble_outgoing = redBubble_outgoing
        self.greenBubble_incoming = greenBubble_incoming
        self.greenBubble_outgoing = greenBubble_outgoing
        self.chatReplyTitle = chatReplyTitle
        self.chatReplyTextEnabled = chatReplyTextEnabled
        self.chatReplyTextDisabled = chatReplyTextDisabled
        self.chatReplyTitleBubble_incoming = chatReplyTitleBubble_incoming
        self.chatReplyTitleBubble_outgoing = chatReplyTitleBubble_outgoing
        self.chatReplyTextEnabledBubble_incoming = chatReplyTextEnabledBubble_incoming
        self.chatReplyTextEnabledBubble_outgoing = chatReplyTextEnabledBubble_outgoing
        self.chatReplyTextDisabledBubble_incoming = chatReplyTextDisabledBubble_incoming
        self.chatReplyTextDisabledBubble_outgoing = chatReplyTextDisabledBubble_outgoing
        self.groupPeerNameRed = groupPeerNameRed
        self.groupPeerNameOrange = groupPeerNameOrange
        self.groupPeerNameViolet = groupPeerNameViolet
        self.groupPeerNameGreen = groupPeerNameGreen
        self.groupPeerNameCyan = groupPeerNameCyan
        self.groupPeerNameLightBlue = groupPeerNameLightBlue
        self.groupPeerNameBlue = groupPeerNameBlue
        
        self.peerAvatarRedTop =  peerAvatarRedTop
        self.peerAvatarRedBottom = peerAvatarRedBottom
        self.peerAvatarOrangeTop = peerAvatarOrangeTop
        self.peerAvatarOrangeBottom = peerAvatarOrangeBottom
        self.peerAvatarVioletTop = peerAvatarVioletTop
        self.peerAvatarVioletBottom = peerAvatarVioletBottom
        self.peerAvatarGreenTop = peerAvatarGreenTop
        self.peerAvatarGreenBottom = peerAvatarGreenBottom
        self.peerAvatarCyanTop = peerAvatarCyanTop
        self.peerAvatarCyanBottom = peerAvatarCyanBottom
        self.peerAvatarBlueTop = peerAvatarBlueTop
        self.peerAvatarBlueBottom = peerAvatarBlueBottom
        self.peerAvatarPinkTop = peerAvatarPinkTop
        self.peerAvatarPinkBottom = peerAvatarPinkBottom
        self.bubbleBackgroundHighlight_incoming = bubbleBackgroundHighlight_incoming
        self.bubbleBackgroundHighlight_outgoing = bubbleBackgroundHighlight_outgoing
        self.chatDateActive = chatDateActive
        self.chatDateText = chatDateText
        
        
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
    
    public func withAccentColor(_ color: NSColor) -> ColorPalette {
        
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        let highlightColor = NSColor(hue: hue, saturation: saturation * 0.9, brightness: min(1.0, brightness * 0.85), alpha: 1.0)
        
        return ColorPalette(isDark: isDark,
                                 name: name,
                                 background: background,
                                 text: text,
                                 grayText: grayText,
                                 link: color,
                                 blueUI: color,
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
                                 bubbleBackground_outgoing: color,
                                 bubbleBorder_incoming: bubbleBorder_incoming,
                                 bubbleBorder_outgoing: color,
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
                                 fileActivityBackgroundBubble_incoming: color,
                                 fileActivityBackgroundBubble_outgoing: fileActivityBackgroundBubble_outgoing,
                                 fileActivityForegroundBubble_incoming: fileActivityForegroundBubble_incoming,
                                 fileActivityForegroundBubble_outgoing: color,
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
                                 bubbleBackgroundHighlight_outgoing: highlightColor,
                                 chatDateActive: chatDateActive,
                                 chatDateText: chatDateText)
    }
}

public func ==(lhs: ColorPalette, rhs: ColorPalette) -> Bool {
    return lhs.name == rhs.name && lhs.isDark == rhs.isDark
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
    return ControlStyle(font: .normal(.title), foregroundColor: presentation.colors.blueUI, backgroundColor: presentation.colors.background, highlightColor: presentation.colors.blueUI)
}
public var switchViewAppearance: SwitchViewAppearance {
    return SwitchViewAppearance(backgroundColor: presentation.colors.background, stateOnColor: presentation.colors.blueUI, stateOffColor: presentation.colors.grayBackground, disabledColor: presentation.colors.grayTransparent, borderColor: presentation.colors.border)
}
//0xE3EDF4
public let whitePalette = ColorPalette(isDark: false,
                                       name: "Day",
                                       background: .white,
                                       text: NSColor(0x000000),
                                       grayText: NSColor(0x999999),
                                       link: NSColor(0x2481cc),
                                       blueUI: NSColor(0x2481cc),
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
                                       chatDateText: NSColor(0x333333)
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

public let nightBluePalette = ColorPalette(isDark: true,
                                      name:"Night Blue",
    background: NSColor(0x18222d),
    text: NSColor(0xffffff),
    grayText: NSColor(0xb1c3d5),
    link: NSColor(0x62bcf9),
    blueUI: NSColor(0x2ea6ff),
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
    monospacedPre: NSColor(0xffffff),
    monospacedCode: NSColor(0xffffff),
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
    grayTextBubble_outgoing: NSColor(0xb1c3d5),
    grayIconBubble_incoming: NSColor(0xb1c3d5),
    grayIconBubble_outgoing: NSColor(0xb1c3d5),
    blueIconBubble_incoming: NSColor(0xb1c3d5),
    blueIconBubble_outgoing: NSColor(0x62bcf9),
    linkBubble_incoming: NSColor(0x62bcf9),
    linkBubble_outgoing: NSColor(0x62bcf9),
    textBubble_incoming: NSColor(0xffffff),
    textBubble_outgoing: NSColor(0xffffff),
    selectMessageBubble: NSColor(0x213040),
    fileActivityBackground: NSColor(0x2ea6ff, 0.8),
    fileActivityForeground: NSColor(0xffffff),
    fileActivityBackgroundBubble_incoming: NSColor(0xb1c3d5),
    fileActivityBackgroundBubble_outgoing: NSColor(0xb1c3d5),
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
    chatDateText: NSColor(0xb1c3d5)
)

public let dayClassic = ColorPalette(isDark: false,
    name:"Day Classic",
    background: NSColor(0xffffff),
    text: NSColor(0x000000),
    grayText: NSColor(0x999999),
    link: NSColor(0x2481cc),
    blueUI: NSColor(0x2481cc),
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
    chatDateText: NSColor(0x999999)
)

public let darkPalette = ColorPalette(isDark:true,
                                      name:"Dark",
background: NSColor(0x292b36),
text: NSColor(0xe9e9e9),
grayText: NSColor(0x8699a3),
link: NSColor(0x04afc8),
blueUI: NSColor(0x04afc8),
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
chatDateText : NSColor(0x8699a3)
)


public let mojavePalette = ColorPalette(isDark: true,
                                        name: "Mojave",
background: NSColor(0x292A2F),
text: NSColor(0xffffff),
grayText: NSColor(0xb1c3d5),
link: NSColor(0x2ea6ff),
blueUI: NSColor(0x2ea6ff),
redUI: NSColor(0xef5b5b),
greenUI: NSColor(0x49ad51),
blackTransparent: NSColor(0x000000, 0.6),
grayTransparent: NSColor(0x2f313d, 0.5),
grayUI: NSColor(0x292A2F),
darkGrayText: NSColor(0xb1c3d5),
blueText: NSColor(0x2ea6ff),
blueSelect: NSColor(0x3d6a97),
selectText: NSColor(0x3e6b9b),
blueFill: NSColor(0x2ea6ff),
border: NSColor(0x3C3D3F),
grayBackground: NSColor(0x3D3E40),
grayForeground: NSColor(0x3D3E40),
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
grayTextBubble_outgoing: NSColor(0xb1c3d5),
grayIconBubble_incoming: NSColor(0xb1c3d5),
grayIconBubble_outgoing: NSColor(0xb1c3d5),
blueIconBubble_incoming: NSColor(0xb1c3d5),
blueIconBubble_outgoing: NSColor(0x2ea6ff),
linkBubble_incoming: NSColor(0x2ea6ff),
linkBubble_outgoing: NSColor(0x2ea6ff),
textBubble_incoming: NSColor(0xffffff),
textBubble_outgoing: NSColor(0xffffff),
selectMessageBubble: NSColor(0x4e5058),
fileActivityBackground: NSColor(0x2ea6ff, 0.8),
fileActivityForeground: NSColor(0xffffff),
fileActivityBackgroundBubble_incoming: NSColor(0xb1c3d5),
fileActivityBackgroundBubble_outgoing: NSColor(0xb1c3d5),
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
chatDateText: NSColor(0xb1c3d5))


/*
 public let darkPalette = ColorPalette(background: NSColor(0x282e33), text: NSColor(0xe9e9e9), grayText: NSColor(0x999999), link: NSColor(0x20eeda), blueUI: NSColor(0x20eeda), redUI: NSColor(0xec6657), greenUI:NSColor(0x63DA6E), blackTransparent: NSColor(0x000000, 0.6), grayTransparent: NSColor(0xf4f4f4, 0.4), grayUI: NSColor(0xFaFaFa), darkGrayText:NSColor(0x333333), blueText:NSColor(0x009687), blueSelect:NSColor(0x009687), selectText:NSColor(0xeaeaea), blueFill: NSColor(0x20eeda), border: NSColor(0x3d444b), grayBackground:NSColor(0x3d444b), grayForeground:NSColor(0xe4e4e4), grayIcon:NSColor(0x757676), blueIcon: NSColor(0x20eeda), badgeMuted:NSColor(0xd7d7d7), badge:NSColor(0x4ba3e2), indicatorColor: .white)
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


