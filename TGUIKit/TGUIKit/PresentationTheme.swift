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
    public let placeholder:String
    public let textColor: NSColor
    public let placeholderColor: NSColor
    public init(_ backgroundColor: NSColor, _ searchImage:CGImage, _ clearImage:CGImage, _ placeholder:String, _ textColor: NSColor, _ placeholderColor: NSColor) {
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
                groupPeerNameBlue:NSColor) {
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
                                       name: "Default",
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
                                       bubbleBackground_outgoing: NSColor(0x4c91c7),
                                       bubbleBorder_incoming: NSColor(0xeaeaea),
                                       bubbleBorder_outgoing: NSColor(0xeaeaea),
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
                                       selectMessageBubble: NSColor(0xEDF4F9),
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
                                       groupPeerNameBlue:NSColor(0x3d72ed))

/*
 colors[0] = NSColor(0xfc5c51); // red
 colors[1] = NSColor(0xfa790f); // orange
 colors[2] = NSColor(0x895dd5); // violet
 colors[3] = NSColor(0x0fb297); // green
 colors[4] = NSColor(0x00c1a6); // cyan
 colors[5] = NSColor(0x3ca5ec); // light blue
 colors[6] = NSColor(0x3d72ed); // blue
 */
public let darkPalette = ColorPalette(isDark: true,
                                      name: "Dark",
                                      background: NSColor(0x292b36),
                                      text: NSColor(0xe9e9e9),
                                      grayText: NSColor(0x8699a3),
                                      link: NSColor(0x04afc8),
                                      blueUI: NSColor(0x04afc8),
                                      redUI: NSColor(0xec6657),
                                      greenUI:NSColor(0x49ad51),
                                      blackTransparent: NSColor(0x000000, 0.6),
                                      grayTransparent: NSColor(0x2f313d, 0.5),
                                      grayUI: NSColor(0x292b36),
                                      darkGrayText:NSColor(0x8699a3),
                                      blueText:NSColor(0x04afc8),
                                      blueSelect:NSColor(0x20889a),
                                      selectText: NSColor(0x8699a3),
                                      blueFill: NSColor(0x04afc8),
                                      border: NSColor(0x464a57),
                                      grayBackground:NSColor(0x464a57),
                                      grayForeground:NSColor(0x3d414d),
                                      grayIcon: NSColor(0x8699a3),
                                      blueIcon: NSColor(0x04afc8),
                                      badgeMuted:NSColor(0x8699a3),
                                      badge:NSColor(0x04afc8),
                                      indicatorColor: .white,
                                      selectMessage: NSColor(0x3d414d),
                                      //grayOutgoingBubble: NSColor(0xa0d5dd),
                                      //grayIncomingBubble: NSColor(0x3d414d),
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
                                      bubbleBorder_outgoing: NSColor(0x464a57),
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
                                      webPreviewActivity: NSColor(0x04afc8),
                                      webPreviewActivityBubble_incoming: NSColor(0x04afc8),
                                      webPreviewActivityBubble_outgoing: NSColor(0xffffff),
                                      redBubble_incoming:NSColor(0xec6657),
                                      redBubble_outgoing:NSColor(0xec6657),
                                      greenBubble_incoming:NSColor(0x49ad51),
                                      greenBubble_outgoing:NSColor(0x49ad51),
                                      chatReplyTitle: NSColor(0x04afc8),
                                      chatReplyTextEnabled: NSColor(0xe9e9e9),
                                      chatReplyTextDisabled: NSColor(0x8699a3),
                                      chatReplyTitleBubble_incoming: NSColor(0xffffff),
                                      chatReplyTitleBubble_outgoing: NSColor(0xffffff),
                                      chatReplyTextEnabledBubble_incoming: NSColor(0xffffff),
                                      chatReplyTextEnabledBubble_outgoing: NSColor(0xffffff),
                                      chatReplyTextDisabledBubble_incoming: NSColor(0x8699a3),
                                      chatReplyTextDisabledBubble_outgoing: NSColor(0xa0d5dd),
                                      groupPeerNameRed:NSColor(0xfc5c51),
                                      groupPeerNameOrange:NSColor(0xfa790f),
                                      groupPeerNameViolet:NSColor(0x895dd5),
                                      groupPeerNameGreen:NSColor(0x0fb297),
                                      groupPeerNameCyan:NSColor(0x00c1a6),
                                      groupPeerNameLightBlue:NSColor(0x3ca5ec),
                                      groupPeerNameBlue:NSColor(0x3d72ed))


/*
 public let darkPalette = ColorPalette(background: NSColor(0x282e33), text: NSColor(0xe9e9e9), grayText: NSColor(0x999999), link: NSColor(0x20eeda), blueUI: NSColor(0x20eeda), redUI: NSColor(0xec6657), greenUI:NSColor(0x63DA6E), blackTransparent: NSColor(0x000000, 0.6), grayTransparent: NSColor(0xf4f4f4, 0.4), grayUI: NSColor(0xFaFaFa), darkGrayText:NSColor(0x333333), blueText:NSColor(0x009687), blueSelect:NSColor(0x009687), selectText:NSColor(0xeaeaea), blueFill: NSColor(0x20eeda), border: NSColor(0x3d444b), grayBackground:NSColor(0x3d444b), grayForeground:NSColor(0xe4e4e4), grayIcon:NSColor(0x757676), blueIcon: NSColor(0x20eeda), badgeMuted:NSColor(0xd7d7d7), badge:NSColor(0x4ba3e2), indicatorColor: .white)
 */


private var _theme:Atomic<PresentationTheme> = Atomic(value: whiteTheme)

public let whiteTheme = PresentationTheme(colors: whitePalette, search: SearchTheme(.grayBackground, #imageLiteral(resourceName: "Icon_SearchField").precomposed(), #imageLiteral(resourceName: "Icon_SearchClear").precomposed(), localizedString("SearchField.Search"), .text, .grayText))



public var presentation:PresentationTheme {
    return _theme.modify {$0}
}

public func updateTheme(_ theme:PresentationTheme) {
    assertOnMainThread()
    _ = _theme.swap(theme)
}


