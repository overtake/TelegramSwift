//
//  PresentationTheme.swift
//  Telegram
//
//  Created by keepcoder on 22/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit

//

/*
 colorItems.append(.preset(PresentationThemeAccentColor(index: 104, baseColor: .preset, accentColor: 0x5a9e29, bubbleColors: (0xdcf8c6, nil), wallpaper: patternWallpaper("R3j69wKskFIBAAAAoUdXWCKMzCM", 0xede6dd, nil, 50, nil))))
 colorItems.append(.preset(PresentationThemeAccentColor(index: 106, baseColor: .preset, accentColor: 0xf55783, bubbleColors: (0xd6f5ff, nil), wallpaper: patternWallpaper("p-pXcflrmFIBAAAAvXYQk-mCwZU", 0xfce3ec, nil, 40, nil))))
 colorItems.append(.preset(PresentationThemeAccentColor(index: 101, baseColor: .preset, accentColor: 0x7e5fe5, bubbleColors: (0xf5e2ff, nil), wallpaper: patternWallpaper("nQcFYJe1mFIBAAAAcI95wtIK0fk", 0xfcccf4, 0xae85f0, 54, nil))))
 colorItems.append(.preset(PresentationThemeAccentColor(index: 102, baseColor: .preset, accentColor: 0xff5fa9, bubbleColors: (0xfff4d7, nil), wallpaper: patternWallpaper("51nnTjx8mFIBAAAAaFGJsMIvWkk", 0xf6b594, 0xebf6cd, 46, 45))))
 colorItems.append(.preset(PresentationThemeAccentColor(index: 103, baseColor: .preset, accentColor: 0x199972, bubbleColors: (0xfffec7, nil), wallpaper: patternWallpaper("fqv01SQemVIBAAAApND8LDRUhRU", 0xc1e7cb, nil, 50, nil))))
 colorItems.append(.preset(PresentationThemeAccentColor(index: 105, baseColor: .preset, accentColor: 0x009eee, bubbleColors: (0x94fff9, 0xccffc7), wallpaper: patternWallpaper("p-pXcflrmFIBAAAAvXYQk-mCwZU", 0xffbca6, 0xff63bd, 57, 225))))
 */



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

public func ==(lhs: ColorPalette, rhs: ColorPalette) -> Bool {
    

    if lhs.isNative != rhs.isNative {
        return false
    }
    if lhs.isDark != rhs.isDark {
        return false
    }
    if lhs.tinted != rhs.tinted {
        return false
    }
    if lhs.name != rhs.name {
        return false
    }
    if lhs.copyright != rhs.copyright {
        return false
    }
    if lhs.accentList != rhs.accentList {
        return false
    }
    if lhs.parent != rhs.parent {
        return false
    }
    if lhs.wallpaper != rhs.wallpaper {
        return false
    }
    
    let lhsMirror = Mirror(reflecting: lhs).superclassMirror ?? Mirror(reflecting: lhs)
    let rhsMirror = Mirror(reflecting: rhs).superclassMirror ?? Mirror(reflecting: rhs)

    for (i, lhsChildren) in lhsMirror.children.enumerated() {
        let lhsValue = lhsChildren.value as? NSColor
        let rhsValue = Array(rhsMirror.children)[i].value as? NSColor
        if let lhsValue = lhsValue, let rhsValue = rhsValue {
            if lhsValue != rhsValue {
                return false
            }
        }
    }
    
    return true
}

public struct PaletteAccentColor : Equatable {
    public static func == (lhs: PaletteAccentColor, rhs: PaletteAccentColor) -> Bool {
        return lhs.accent == rhs.accent && lhs.messages?.top == rhs.messages?.top && lhs.messages?.bottom == rhs.messages?.bottom
    }
    
    public let accent: NSColor
    public let messages: (top: NSColor, bottom: NSColor)?
    public init(_ accent: NSColor, _ messages: (top: NSColor, bottom: NSColor)? = nil) {
        self.accent = accent.withAlphaComponent(1.0)
        self.messages = messages.map { (top: $0.top.withAlphaComponent(1.0), bottom: $0.bottom.withAlphaComponent(1.0)) }
    }
}

public class ColorPalette : Equatable {
    
    public let isNative: Bool
    public let isDark: Bool
    public let tinted: Bool
    public let name: String
    public let copyright:String
    public let accentList:[PaletteAccentColor]
    public let parent: TelegramBuiltinTheme
    public let wallpaper: PaletteWallpaper
    
    private let _basicAccent: NSColor
    public var basicAccent: NSColor {
        return self._basicAccent
    }
    private let _background: NSColor
    public var background: NSColor {
        return self._background
    }
    private let _text: NSColor
    public var text: NSColor {
        return self._text
    }
    private let _grayText:NSColor
    public var grayText: NSColor {
        return self._grayText
    }
    private let _link:NSColor
    public var link: NSColor {
        return self._link
    }
    private let _accent:NSColor
    public var accent: NSColor {
        return self._accent
    }
    private let _redUI:NSColor
    public var redUI: NSColor {
        return self._redUI
    }
    private let _greenUI:NSColor
    public var greenUI: NSColor {
        return self._greenUI
    }
    private let _blackTransparent:NSColor
    public var blackTransparent: NSColor {
        return self._blackTransparent
    }
    private let _grayTransparent:NSColor
    public var grayTransparent: NSColor {
        return self._grayTransparent
    }
    private let _grayUI:NSColor
    public var grayUI: NSColor {
        return self._grayUI
    }
    private let _darkGrayText:NSColor
    public var darkGrayText: NSColor {
        return self._darkGrayText
    }

    private let _accentSelect:NSColor
    public var accentSelect: NSColor {
        return self._accentSelect
    }
    private let _selectText:NSColor
    public var selectText: NSColor {
        return self._selectText
    }
    private let _border:NSColor
    public var border: NSColor {
        return self._border
    }
    private let _grayBackground:NSColor
    public var grayBackground: NSColor {
        return self._grayBackground
    }
    private let _grayForeground:NSColor
    public var grayForeground: NSColor {
        return self._grayForeground
    }
    private let _grayIcon:NSColor
    public var grayIcon: NSColor {
        return self._grayIcon
    }
    private let _accentIcon:NSColor
    public var accentIcon: NSColor {
        return self._accentIcon
    }
    private let _badgeMuted:NSColor
    public var badgeMuted: NSColor {
        return self._badgeMuted
    }
    private let _badge:NSColor
    public var badge: NSColor {
        return self._badge
    }
    private let _indicatorColor: NSColor
    public var indicatorColor: NSColor {
        return self._indicatorColor
    }
    private let _selectMessage: NSColor
    public var selectMessage: NSColor {
        return self._selectMessage
    }
    private let _monospacedPre: NSColor
    public var monospacedPre: NSColor {
        return self._monospacedPre
    }
    private let _monospacedCode: NSColor
    public var monospacedCode: NSColor {
        return self._monospacedCode
    }
    private let _monospacedPreBubble_incoming: NSColor
    public var monospacedPreBubble_incoming: NSColor {
        return self._monospacedPreBubble_incoming
    }
    private let _monospacedPreBubble_outgoing: NSColor
    public var monospacedPreBubble_outgoing: NSColor {
        return self._monospacedPreBubble_outgoing
    }
    private let _monospacedCodeBubble_incoming: NSColor
    public var monospacedCodeBubble_incoming: NSColor {
        return self._monospacedCodeBubble_incoming
    }
    private let _monospacedCodeBubble_outgoing: NSColor
    public var monospacedCodeBubble_outgoing: NSColor {
        return self._monospacedCodeBubble_outgoing
    }
    private let _selectTextBubble_incoming: NSColor
    public var selectTextBubble_incoming: NSColor {
        return self._selectTextBubble_incoming
    }
    private let _selectTextBubble_outgoing: NSColor
    public var selectTextBubble_outgoing: NSColor {
        return self._selectTextBubble_outgoing
    }
    private let _bubbleBackground_incoming: NSColor
    public var bubbleBackground_incoming: NSColor {
        return self._bubbleBackground_incoming
    }
    private let _bubbleBackgroundTop_outgoing: NSColor
    public var bubbleBackgroundTop_outgoing: NSColor {
        return self._bubbleBackgroundTop_outgoing
    }
    private let _bubbleBackgroundBottom_outgoing: NSColor
    public var bubbleBackgroundBottom_outgoing: NSColor {
        return self._bubbleBackgroundBottom_outgoing
    }
    
    private let _bubbleBorder_incoming: NSColor
    public var bubbleBorder_incoming: NSColor {
        return self._bubbleBorder_incoming
    }
    private let _bubbleBorder_outgoing: NSColor
    public var bubbleBorder_outgoing: NSColor {
        return self._bubbleBorder_outgoing
    }
    private let _grayTextBubble_incoming: NSColor
    public var grayTextBubble_incoming: NSColor {
        return self._grayTextBubble_incoming
    }
    private let _grayTextBubble_outgoing: NSColor
    public var grayTextBubble_outgoing: NSColor {
        return self._grayTextBubble_outgoing
    }
    private let _grayIconBubble_incoming: NSColor
    public var grayIconBubble_incoming: NSColor {
        return self._grayIconBubble_incoming
    }
    private let _grayIconBubble_outgoing: NSColor
    public var grayIconBubble_outgoing: NSColor {
        return self._grayIconBubble_outgoing
    }
    private let _accentIconBubble_incoming: NSColor
    public var accentIconBubble_incoming: NSColor {
        return self._accentIconBubble_incoming
    }
    private let _accentIconBubble_outgoing: NSColor
    public var accentIconBubble_outgoing: NSColor {
        return self._accentIconBubble_outgoing
    }
    private let _linkBubble_incoming: NSColor
    public var linkBubble_incoming: NSColor {
        return self._linkBubble_incoming
    }
    private let _linkBubble_outgoing: NSColor
    public var linkBubble_outgoing: NSColor {
        return self._linkBubble_outgoing
    }
    private let _textBubble_incoming: NSColor
    public var textBubble_incoming: NSColor {
        return self._textBubble_incoming
    }
    private let _textBubble_outgoing: NSColor
    public var textBubble_outgoing: NSColor {
        return self._textBubble_outgoing
    }
    private let _selectMessageBubble: NSColor
    public var selectMessageBubble: NSColor {
        return self._selectMessageBubble
    }
    private let _fileActivityBackground: NSColor
    public var fileActivityBackground: NSColor {
        return self._fileActivityBackground
    }
    private let _fileActivityForeground: NSColor
    public var fileActivityForeground: NSColor {
        return self._fileActivityForeground
    }
    private let _fileActivityBackgroundBubble_incoming: NSColor
    public var fileActivityBackgroundBubble_incoming: NSColor {
        return self._fileActivityBackgroundBubble_incoming
    }
    private let _fileActivityBackgroundBubble_outgoing: NSColor
    public var fileActivityBackgroundBubble_outgoing: NSColor {
        return self._fileActivityBackgroundBubble_outgoing
    }
    private let _fileActivityForegroundBubble_incoming: NSColor
    public var fileActivityForegroundBubble_incoming: NSColor {
        return self._fileActivityForegroundBubble_incoming
    }
    private let _fileActivityForegroundBubble_outgoing: NSColor
    public var fileActivityForegroundBubble_outgoing: NSColor {
        return self._fileActivityForegroundBubble_outgoing
    }
    private let _waveformBackground: NSColor
    public var waveformBackground: NSColor {
        return self._waveformBackground
    }
    private let _waveformForeground: NSColor
    public var waveformForeground: NSColor {
        return self._waveformForeground
    }
    private let _waveformBackgroundBubble_incoming: NSColor
    public var waveformBackgroundBubble_incoming: NSColor {
        return self._waveformBackgroundBubble_incoming
    }
    private let _waveformBackgroundBubble_outgoing: NSColor
    public var waveformBackgroundBubble_outgoing: NSColor {
        return self._waveformBackgroundBubble_outgoing
    }
    private let _waveformForegroundBubble_incoming: NSColor
    public var waveformForegroundBubble_incoming: NSColor {
        return self._waveformForegroundBubble_incoming
    }
    private let _waveformForegroundBubble_outgoing: NSColor
    public var waveformForegroundBubble_outgoing: NSColor {
        return self._waveformForegroundBubble_outgoing
    }
    private let _webPreviewActivity: NSColor
    public var webPreviewActivity: NSColor {
        return self._webPreviewActivity
    }
    private let _webPreviewActivityBubble_incoming: NSColor
    public var webPreviewActivityBubble_incoming: NSColor {
        return self._webPreviewActivityBubble_incoming
    }
    private let _webPreviewActivityBubble_outgoing: NSColor
    public var webPreviewActivityBubble_outgoing: NSColor {
        return self._webPreviewActivityBubble_outgoing
    }
    private let _redBubble_incoming:NSColor
    public var redBubble_incoming: NSColor {
        return self._redBubble_incoming
    }
    private let _redBubble_outgoing:NSColor
    public var redBubble_outgoing: NSColor {
        return self._redBubble_outgoing
    }
    private let _greenBubble_incoming:NSColor
    public var greenBubble_incoming: NSColor {
        return self._greenBubble_incoming
    }
    private let _greenBubble_outgoing:NSColor
    public var greenBubble_outgoing: NSColor {
        return self._greenBubble_outgoing
    }
    private let _chatReplyTitle: NSColor
    public var chatReplyTitle: NSColor {
        return self._chatReplyTitle
    }
    private let _chatReplyTextEnabled: NSColor
    public var chatReplyTextEnabled: NSColor {
        return self._chatReplyTextEnabled
    }
    private let _chatReplyTextDisabled: NSColor
    public var chatReplyTextDisabled: NSColor {
        return self._chatReplyTextDisabled
    }
    private let _chatReplyTitleBubble_incoming: NSColor
    public var chatReplyTitleBubble_incoming: NSColor {
        return self._chatReplyTitleBubble_incoming
    }
    private let _chatReplyTitleBubble_outgoing: NSColor
    public var chatReplyTitleBubble_outgoing: NSColor {
        return self._chatReplyTitleBubble_outgoing
    }
    private let _chatReplyTextEnabledBubble_incoming: NSColor
    public var chatReplyTextEnabledBubble_incoming: NSColor {
        return self._chatReplyTextEnabledBubble_incoming
    }
    private let _chatReplyTextEnabledBubble_outgoing: NSColor
    public var chatReplyTextEnabledBubble_outgoing: NSColor {
        return self._chatReplyTextEnabledBubble_outgoing
    }
    private let _chatReplyTextDisabledBubble_incoming: NSColor
    public var chatReplyTextDisabledBubble_incoming: NSColor {
        return self._chatReplyTextDisabledBubble_incoming
    }
    private let _chatReplyTextDisabledBubble_outgoing: NSColor
    public var chatReplyTextDisabledBubble_outgoing: NSColor {
        return self._chatReplyTextDisabledBubble_outgoing
    }
    private let _groupPeerNameRed:NSColor
    public var groupPeerNameRed: NSColor {
        return self._groupPeerNameRed
    }
    private let _groupPeerNameOrange:NSColor
    public var groupPeerNameOrange: NSColor {
        return self._groupPeerNameOrange
    }
    private let _groupPeerNameViolet:NSColor
    public var groupPeerNameViolet: NSColor {
        return self._groupPeerNameViolet
    }
    private let _groupPeerNameGreen:NSColor
    public var groupPeerNameGreen: NSColor {
        return self._groupPeerNameGreen
    }
    private let _groupPeerNameCyan:NSColor
    public var groupPeerNameCyan: NSColor {
        return self._groupPeerNameCyan
    }
    private let _groupPeerNameLightBlue:NSColor
    public var groupPeerNameLightBlue: NSColor {
        return self._groupPeerNameLightBlue
    }
    private let _groupPeerNameBlue:NSColor
    public var groupPeerNameBlue: NSColor {
        return self._groupPeerNameBlue
    }
    private let _peerAvatarRedTop: NSColor
    public var peerAvatarRedTop: NSColor {
        return self._peerAvatarRedTop
    }
    private let _peerAvatarRedBottom: NSColor
    public var peerAvatarRedBottom: NSColor {
        return self._peerAvatarRedBottom
    }
    private let _peerAvatarOrangeTop: NSColor
    public var peerAvatarOrangeTop: NSColor {
        return self._peerAvatarOrangeTop
    }
    private let _peerAvatarOrangeBottom: NSColor
    public var peerAvatarOrangeBottom: NSColor {
        return self._peerAvatarOrangeBottom
    }
    private let _peerAvatarVioletTop: NSColor
    public var peerAvatarVioletTop: NSColor {
        return self._peerAvatarVioletTop
    }
    private let _peerAvatarVioletBottom: NSColor
    public var peerAvatarVioletBottom: NSColor {
        return self._peerAvatarVioletBottom
    }
    private let _peerAvatarGreenTop: NSColor
    public var peerAvatarGreenTop: NSColor {
        return self._peerAvatarGreenTop
    }
    private let _peerAvatarGreenBottom: NSColor
    public var peerAvatarGreenBottom: NSColor {
        return self._peerAvatarGreenBottom
    }
    private let _peerAvatarCyanTop: NSColor
    public var peerAvatarCyanTop: NSColor {
        return self._peerAvatarCyanTop
    }
    private let _peerAvatarCyanBottom: NSColor
    public var peerAvatarCyanBottom: NSColor {
        return self._peerAvatarCyanBottom
    }
    private let _peerAvatarBlueTop: NSColor
    public var peerAvatarBlueTop: NSColor {
        return self._peerAvatarBlueTop
    }
    private let _peerAvatarBlueBottom: NSColor
    public var peerAvatarBlueBottom: NSColor {
        return self._peerAvatarBlueBottom
    }
    private let _peerAvatarPinkTop: NSColor
    public var peerAvatarPinkTop: NSColor {
        return self._peerAvatarPinkTop
    }
    private let _peerAvatarPinkBottom: NSColor
    public var peerAvatarPinkBottom: NSColor {
        return self._peerAvatarPinkBottom
    }
    private let _bubbleBackgroundHighlight_incoming: NSColor
    public var bubbleBackgroundHighlight_incoming: NSColor {
        return self._bubbleBackgroundHighlight_incoming
    }
    private let _bubbleBackgroundHighlight_outgoing: NSColor
    public var bubbleBackgroundHighlight_outgoing: NSColor {
        return self._bubbleBackgroundHighlight_outgoing
    }
    private let _chatDateActive: NSColor
    public var chatDateActive: NSColor {
        return self._chatDateActive
    }
    private let _chatDateText: NSColor
    public var chatDateText: NSColor {
        return self._chatDateText
    }
    private let _revealAction_neutral1_background: NSColor
    public var revealAction_neutral1_background: NSColor {
        return self._revealAction_neutral1_background
    }
    private let _revealAction_neutral1_foreground: NSColor
    public var revealAction_neutral1_foreground: NSColor {
        return self._revealAction_neutral1_foreground
    }
    private let _revealAction_neutral2_background: NSColor
    public var revealAction_neutral2_background: NSColor {
        return self._revealAction_neutral2_background
    }
    private let _revealAction_neutral2_foreground: NSColor
    public var revealAction_neutral2_foreground: NSColor {
        return self._revealAction_neutral2_foreground
    }
    private let _revealAction_destructive_background: NSColor
    public var revealAction_destructive_background: NSColor {
        return self._revealAction_destructive_background
    }
    private let _revealAction_destructive_foreground: NSColor
    public var revealAction_destructive_foreground: NSColor {
        return self._revealAction_destructive_foreground
    }
    private let _revealAction_constructive_background: NSColor
    public var revealAction_constructive_background: NSColor {
        return self._revealAction_constructive_background
    }
    private let _revealAction_constructive_foreground: NSColor
    public var revealAction_constructive_foreground: NSColor {
        return self._revealAction_constructive_foreground
    }
    private let _revealAction_accent_background: NSColor
    public var revealAction_accent_background: NSColor {
        return self._revealAction_accent_background
    }
    private let _revealAction_accent_foreground: NSColor
    public var revealAction_accent_foreground: NSColor {
        return self._revealAction_accent_foreground
    }
    private let _revealAction_warning_background: NSColor
    public var revealAction_warning_background: NSColor {
        return self._revealAction_warning_background
    }
    private let _revealAction_warning_foreground: NSColor
    public var revealAction_warning_foreground: NSColor {
        return self._revealAction_warning_foreground
    }
    private let _revealAction_inactive_background: NSColor
    public var revealAction_inactive_background: NSColor {
        return self._revealAction_inactive_background
    }
    private let _revealAction_inactive_foreground: NSColor
    public var revealAction_inactive_foreground: NSColor {
        return self._revealAction_inactive_foreground
    }
    private let _chatBackground: NSColor
    public var chatBackground: NSColor {
        return self._chatBackground
    }
    private let _listBackground: NSColor
    public var listBackground: NSColor {
        return self._listBackground
    }
    private let _listGrayText: NSColor
    public var listGrayText: NSColor {
        return self._listGrayText
    }
    private let _grayHighlight: NSColor
    public var grayHighlight: NSColor {
        return self._grayHighlight
    }
    
    private let _focusAnimationColor: NSColor
    public var focusAnimationColor: NSColor {
        return self._focusAnimationColor
    }
    
    
    
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
        string += "//Fallback for parameters which didn't define. Available values: day, dayClassic, dark, nightAccent\n"
        string += "parent = \(self.parent.rawValue)\n"
        string += "copyright = \(self.copyright)\n"
//        string += "accentList = \(self.accentList.map{$0.hexString}.joined(separator: ","))\n"
        for prop in self.listProperties() {
            if let color = self.colorFromStringVariable(prop) {
                var prop = prop
                _ = prop.removeFirst()
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
    
    public required init(isNative: Bool, isDark: Bool,
                tinted: Bool,
                name: String,
                parent: TelegramBuiltinTheme,
                wallpaper: PaletteWallpaper,
                copyright: String,
                accentList: [PaletteAccentColor],
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
                accentSelect:NSColor,
                selectText:NSColor,
                border:NSColor,
                grayBackground:NSColor,
                grayForeground:NSColor,
                grayIcon:NSColor,
                accentIcon:NSColor,
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
                bubbleBackgroundTop_outgoing: NSColor,
                bubbleBackgroundBottom_outgoing: NSColor,
                bubbleBorder_incoming: NSColor,
                bubbleBorder_outgoing: NSColor,
                grayTextBubble_incoming: NSColor,
                grayTextBubble_outgoing: NSColor,
                grayIconBubble_incoming: NSColor,
                grayIconBubble_outgoing: NSColor,
                accentIconBubble_incoming: NSColor,
                accentIconBubble_outgoing: NSColor,
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
                listBackground: NSColor,
                listGrayText: NSColor,
                grayHighlight: NSColor,
                focusAnimationColor: NSColor) {
        
        let background: NSColor = background.withAlphaComponent(1.0)
        let grayBackground: NSColor = grayBackground.withAlphaComponent(1.0)
        let grayForeground: NSColor = grayForeground.withAlphaComponent(1.0)
        var text: NSColor = text.withAlphaComponent(1.0)
        var link: NSColor = link.withAlphaComponent(1.0)
        var grayText: NSColor = grayText.withAlphaComponent(1.0)
        var accent: NSColor = accent.withAlphaComponent(1)
        var accentIcon: NSColor = accentIcon
        var grayIcon: NSColor = grayIcon
        var accentSelect: NSColor = accentSelect
        var textBubble_incoming: NSColor = textBubble_incoming.withAlphaComponent(1.0)
        var textBubble_outgoing: NSColor = textBubble_outgoing.withAlphaComponent(1.0)
        var grayTextBubble_incoming: NSColor = grayTextBubble_incoming.withAlphaComponent(1.0)
        var grayTextBubble_outgoing: NSColor = grayTextBubble_outgoing.withAlphaComponent(1.0)
        var grayIconBubble_incoming: NSColor = grayIconBubble_incoming
        var grayIconBubble_outgoing: NSColor = grayIconBubble_outgoing
        var accentIconBubble_incoming: NSColor = accentIconBubble_incoming
        var accentIconBubble_outgoing: NSColor = accentIconBubble_outgoing
        
        let bubbleBackground_incoming = bubbleBackground_incoming.withAlphaComponent(1.0)
        let bubbleBackgroundTop_outgoing = bubbleBackgroundTop_outgoing.withAlphaComponent(1.0)
        let bubbleBackgroundBottom_outgoing = bubbleBackgroundBottom_outgoing.withAlphaComponent(1.0)
        let linkBubble_incoming = linkBubble_incoming.withAlphaComponent(1.0)
        let linkBubble_outgoing = linkBubble_outgoing.withAlphaComponent(1.0)
        
        
        let bubbleBackground_outgoing = bubbleBackgroundTop_outgoing.blended(withFraction: 0.5, of: bubbleBackgroundBottom_outgoing)!
        
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
        if accentIcon.isTooCloseHSV(to: background) {
            accentIcon = background.brightnessAdjustedColor
        }
        if grayIcon.isTooCloseHSV(to: background) {
            grayIcon = background.brightnessAdjustedColor
        }
        if grayText.isTooCloseHSV(to: background) {
            grayText = background.brightnessAdjustedColor
        }
        if accentSelect.isTooCloseHSV(to: background) {
            accentSelect = background.brightnessAdjustedColor
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
        if accentIconBubble_incoming.isTooCloseHSV(to: bubbleBackground_incoming) {
            accentIconBubble_incoming = bubbleBackground_incoming.brightnessAdjustedColor
        }
        if accentIconBubble_outgoing.isTooCloseHSV(to: bubbleBackground_outgoing) {
            accentIconBubble_outgoing = bubbleBackground_outgoing.brightnessAdjustedColor
        }
        self.isNative = isNative
        self.parent = parent
        self.copyright = copyright
        self.isDark = isDark
        self.tinted = tinted
        self.name = name
        self.accentList = accentList
        self._basicAccent = basicAccent.withAlphaComponent(max(0.6, basicAccent.alpha))
        self._background = background.withAlphaComponent(max(0.6, background.alpha))
        self._text = text.withAlphaComponent(max(0.6, text.alpha))
        self._grayText = grayText.withAlphaComponent(max(0.6, grayText.alpha))
        self._link = link.withAlphaComponent(max(0.6, link.alpha))
        self._accent = accent.withAlphaComponent(max(0.6, accent.alpha))
        self._redUI = redUI.withAlphaComponent(max(0.6, redUI.alpha))
        self._greenUI = greenUI.withAlphaComponent(max(0.6, greenUI.alpha))
        self._blackTransparent = blackTransparent.withAlphaComponent(max(0.6, blackTransparent.alpha))
        self._grayTransparent = grayTransparent.withAlphaComponent(max(0.6, grayTransparent.alpha))
        self._grayUI = grayUI.withAlphaComponent(max(0.6, grayUI.alpha))
        self._darkGrayText = darkGrayText.withAlphaComponent(max(0.6, darkGrayText.alpha))
        self._accentSelect = accentSelect.withAlphaComponent(max(0.6, accentSelect.alpha))
        self._selectText = selectText.withAlphaComponent(max(0.6, selectText.alpha))
        self._border = border.withAlphaComponent(max(0.6, border.alpha))
        self._grayBackground = grayBackground.withAlphaComponent(max(0.6, grayBackground.alpha))
        self._grayForeground = grayForeground.withAlphaComponent(max(0.6, grayForeground.alpha))
        self._grayIcon = grayIcon.withAlphaComponent(max(0.6, grayIcon.alpha))
        self._accentIcon = accentIcon.withAlphaComponent(max(0.6, accentIcon.alpha))
        self._badgeMuted = badgeMuted.withAlphaComponent(max(0.6, badgeMuted.alpha))
        self._badge = badge.withAlphaComponent(max(0.6, badge.alpha))
        self._indicatorColor = indicatorColor.withAlphaComponent(max(0.6, indicatorColor.alpha))
        self._selectMessage = selectMessage.withAlphaComponent(max(0.6, selectMessage.alpha))
        
        self._monospacedPre = monospacedPre.withAlphaComponent(max(0.6, monospacedPre.alpha))
        self._monospacedCode = monospacedCode.withAlphaComponent(max(0.6, monospacedCode.alpha))
        self._monospacedPreBubble_incoming = monospacedPreBubble_incoming.withAlphaComponent(max(0.6, monospacedPreBubble_incoming.alpha))
        self._monospacedPreBubble_outgoing = monospacedPreBubble_outgoing.withAlphaComponent(max(0.6, monospacedPreBubble_outgoing.alpha))
        self._monospacedCodeBubble_incoming = monospacedCodeBubble_incoming.withAlphaComponent(max(0.6, monospacedCodeBubble_incoming.alpha))
        self._monospacedCodeBubble_outgoing = monospacedCodeBubble_outgoing.withAlphaComponent(max(0.6, monospacedCodeBubble_outgoing.alpha))
        self._selectTextBubble_incoming = selectTextBubble_incoming.withAlphaComponent(max(0.6, selectTextBubble_incoming.alpha))
        self._selectTextBubble_outgoing = selectTextBubble_outgoing.withAlphaComponent(max(0.6, selectTextBubble_outgoing.alpha))
        self._bubbleBackground_incoming = bubbleBackground_incoming.withAlphaComponent(max(0.6, bubbleBackground_incoming.alpha))
        self._bubbleBackgroundTop_outgoing = bubbleBackgroundTop_outgoing.withAlphaComponent(max(1.0, bubbleBackgroundTop_outgoing.alpha))
        self._bubbleBackgroundBottom_outgoing = bubbleBackgroundBottom_outgoing.withAlphaComponent(max(1.0, bubbleBackgroundBottom_outgoing.alpha))
        self._bubbleBorder_incoming = bubbleBorder_incoming.withAlphaComponent(max(0.6, bubbleBorder_incoming.alpha))
        self._bubbleBorder_outgoing = bubbleBorder_outgoing.withAlphaComponent(max(0.6, bubbleBorder_outgoing.alpha))
        self._grayTextBubble_incoming = grayTextBubble_incoming.withAlphaComponent(max(0.6, grayTextBubble_incoming.alpha))
        self._grayTextBubble_outgoing = grayTextBubble_outgoing.withAlphaComponent(max(0.6, grayTextBubble_outgoing.alpha))
        self._grayIconBubble_incoming = grayIconBubble_incoming.withAlphaComponent(max(0.6, grayIconBubble_incoming.alpha))
        self._grayIconBubble_outgoing = grayIconBubble_outgoing.withAlphaComponent(max(0.6, grayIconBubble_outgoing.alpha))
        self._accentIconBubble_incoming = accentIconBubble_incoming.withAlphaComponent(max(0.6, accentIconBubble_incoming.alpha))
        self._accentIconBubble_outgoing = accentIconBubble_outgoing.withAlphaComponent(max(0.6, accentIconBubble_outgoing.alpha))
        self._linkBubble_incoming = linkBubble_incoming.withAlphaComponent(max(0.6, linkBubble_incoming.alpha))
        self._linkBubble_outgoing = linkBubble_outgoing.withAlphaComponent(max(0.6, linkBubble_outgoing.alpha))
        self._textBubble_incoming = textBubble_incoming.withAlphaComponent(max(0.6, textBubble_incoming.alpha))
        self._textBubble_outgoing = textBubble_outgoing.withAlphaComponent(max(0.6, textBubble_outgoing.alpha))
        self._selectMessageBubble = selectMessageBubble.withAlphaComponent(max(0.6, selectMessageBubble.alpha))
        self._fileActivityBackground = fileActivityBackground.withAlphaComponent(max(0.6, fileActivityBackground.alpha))
        self._fileActivityForeground = fileActivityForeground.withAlphaComponent(max(0.6, fileActivityForeground.alpha))
        self._fileActivityBackgroundBubble_incoming = fileActivityBackgroundBubble_incoming.withAlphaComponent(max(0.6, fileActivityBackgroundBubble_incoming.alpha))
        self._fileActivityBackgroundBubble_outgoing = fileActivityBackgroundBubble_outgoing.withAlphaComponent(max(0.6, fileActivityBackgroundBubble_outgoing.alpha))
        self._fileActivityForegroundBubble_incoming = fileActivityForegroundBubble_incoming.withAlphaComponent(max(0.6, fileActivityForegroundBubble_incoming.alpha))
        self._fileActivityForegroundBubble_outgoing = fileActivityForegroundBubble_outgoing.withAlphaComponent(max(0.6, fileActivityForegroundBubble_outgoing.alpha))
        self._waveformBackground = waveformBackground.withAlphaComponent(max(0.6, waveformBackground.alpha))
        self._waveformForeground = waveformForeground.withAlphaComponent(max(0.6, waveformForeground.alpha))
        self._waveformBackgroundBubble_incoming = waveformBackgroundBubble_incoming.withAlphaComponent(max(0.6, waveformBackgroundBubble_incoming.alpha))
        self._waveformBackgroundBubble_outgoing = waveformBackgroundBubble_outgoing.withAlphaComponent(max(0.6, waveformBackgroundBubble_outgoing.alpha))
        self._waveformForegroundBubble_incoming = waveformForegroundBubble_incoming.withAlphaComponent(max(0.6, waveformForegroundBubble_incoming.alpha))
        self._waveformForegroundBubble_outgoing = waveformForegroundBubble_outgoing.withAlphaComponent(max(0.6, waveformForegroundBubble_outgoing.alpha))
        self._webPreviewActivity = webPreviewActivity.withAlphaComponent(max(0.6, webPreviewActivity.alpha))
        self._webPreviewActivityBubble_incoming = webPreviewActivityBubble_incoming.withAlphaComponent(max(0.6, webPreviewActivityBubble_incoming.alpha))
        self._webPreviewActivityBubble_outgoing = webPreviewActivityBubble_outgoing.withAlphaComponent(max(0.6, webPreviewActivityBubble_outgoing.alpha))
        self._redBubble_incoming = redBubble_incoming.withAlphaComponent(max(0.6, redBubble_incoming.alpha))
        self._redBubble_outgoing = redBubble_outgoing.withAlphaComponent(max(0.6, redBubble_outgoing.alpha))
        self._greenBubble_incoming = greenBubble_incoming.withAlphaComponent(max(0.6, greenBubble_incoming.alpha))
        self._greenBubble_outgoing = greenBubble_outgoing.withAlphaComponent(max(0.6, greenBubble_outgoing.alpha))
        self._chatReplyTitle = chatReplyTitle.withAlphaComponent(max(0.6, chatReplyTitle.alpha))
        self._chatReplyTextEnabled = chatReplyTextEnabled.withAlphaComponent(max(0.6, chatReplyTextEnabled.alpha))
        self._chatReplyTextDisabled = chatReplyTextDisabled.withAlphaComponent(max(0.6, chatReplyTextDisabled.alpha))
        self._chatReplyTitleBubble_incoming = chatReplyTitleBubble_incoming.withAlphaComponent(max(0.6, chatReplyTitleBubble_incoming.alpha))
        self._chatReplyTitleBubble_outgoing = chatReplyTitleBubble_outgoing.withAlphaComponent(max(0.6, chatReplyTitleBubble_outgoing.alpha))
        self._chatReplyTextEnabledBubble_incoming = chatReplyTextEnabledBubble_incoming.withAlphaComponent(max(0.6, chatReplyTextEnabledBubble_incoming.alpha))
        self._chatReplyTextEnabledBubble_outgoing = chatReplyTextEnabledBubble_outgoing.withAlphaComponent(max(0.6, chatReplyTextEnabledBubble_outgoing.alpha))
        self._chatReplyTextDisabledBubble_incoming = chatReplyTextDisabledBubble_incoming.withAlphaComponent(max(0.6, chatReplyTextDisabledBubble_incoming.alpha))
        self._chatReplyTextDisabledBubble_outgoing = chatReplyTextDisabledBubble_outgoing.withAlphaComponent(max(0.6, chatReplyTextDisabledBubble_outgoing.alpha))
        self._groupPeerNameRed = groupPeerNameRed.withAlphaComponent(max(0.6, groupPeerNameRed.alpha))
        self._groupPeerNameOrange = groupPeerNameOrange.withAlphaComponent(max(0.6, groupPeerNameOrange.alpha))
        self._groupPeerNameViolet = groupPeerNameViolet.withAlphaComponent(max(0.6, groupPeerNameViolet.alpha))
        self._groupPeerNameGreen = groupPeerNameGreen.withAlphaComponent(max(0.6, groupPeerNameGreen.alpha))
        self._groupPeerNameCyan = groupPeerNameCyan.withAlphaComponent(max(0.6, groupPeerNameCyan.alpha))
        self._groupPeerNameLightBlue = groupPeerNameLightBlue.withAlphaComponent(max(0.6, groupPeerNameLightBlue.alpha))
        self._groupPeerNameBlue = groupPeerNameBlue.withAlphaComponent(max(0.6, groupPeerNameBlue.alpha))
        
        self._peerAvatarRedTop =  peerAvatarRedTop.withAlphaComponent(max(0.6, peerAvatarRedTop.alpha))
        self._peerAvatarRedBottom = peerAvatarRedBottom.withAlphaComponent(max(0.6, peerAvatarRedBottom.alpha))
        self._peerAvatarOrangeTop = peerAvatarOrangeTop.withAlphaComponent(max(0.6, peerAvatarOrangeTop.alpha))
        self._peerAvatarOrangeBottom = peerAvatarOrangeBottom.withAlphaComponent(max(0.6, peerAvatarOrangeBottom.alpha))
        self._peerAvatarVioletTop = peerAvatarVioletTop.withAlphaComponent(max(0.6, peerAvatarVioletTop.alpha))
        self._peerAvatarVioletBottom = peerAvatarVioletBottom.withAlphaComponent(max(0.6, peerAvatarVioletBottom.alpha))
        self._peerAvatarGreenTop = peerAvatarGreenTop.withAlphaComponent(max(0.6, peerAvatarGreenTop.alpha))
        self._peerAvatarGreenBottom = peerAvatarGreenBottom.withAlphaComponent(max(0.6, peerAvatarGreenBottom.alpha))
        self._peerAvatarCyanTop = peerAvatarCyanTop.withAlphaComponent(max(0.6, peerAvatarCyanTop.alpha))
        self._peerAvatarCyanBottom = peerAvatarCyanBottom.withAlphaComponent(max(0.6, peerAvatarCyanBottom.alpha))
        self._peerAvatarBlueTop = peerAvatarBlueTop.withAlphaComponent(max(0.6, peerAvatarBlueTop.alpha))
        self._peerAvatarBlueBottom = peerAvatarBlueBottom.withAlphaComponent(max(0.6, peerAvatarBlueBottom.alpha))
        self._peerAvatarPinkTop = peerAvatarPinkTop.withAlphaComponent(max(0.6, peerAvatarPinkTop.alpha))
        self._peerAvatarPinkBottom = peerAvatarPinkBottom.withAlphaComponent(max(0.6, peerAvatarPinkBottom.alpha))
        self._bubbleBackgroundHighlight_incoming = bubbleBackgroundHighlight_incoming.withAlphaComponent(max(0.6, bubbleBackgroundHighlight_incoming.alpha))
        self._bubbleBackgroundHighlight_outgoing = bubbleBackgroundHighlight_outgoing.withAlphaComponent(max(0.6, bubbleBackgroundHighlight_outgoing.alpha))
        self._chatDateActive = chatDateActive.withAlphaComponent(max(0.6, chatDateActive.alpha))
        self._chatDateText = chatDateText.withAlphaComponent(max(0.6, chatDateText.alpha))
        
        self._revealAction_neutral1_background = revealAction_neutral1_background.withAlphaComponent(max(0.6, revealAction_neutral1_background.alpha))
        self._revealAction_neutral1_foreground = revealAction_neutral1_foreground.withAlphaComponent(max(0.6, revealAction_neutral1_foreground.alpha))
        self._revealAction_neutral2_background = revealAction_neutral2_background.withAlphaComponent(max(0.6, revealAction_neutral2_background.alpha))
        self._revealAction_neutral2_foreground = revealAction_neutral2_foreground.withAlphaComponent(max(0.6, revealAction_neutral2_foreground.alpha))
        self._revealAction_destructive_background = revealAction_destructive_background.withAlphaComponent(max(0.6, revealAction_destructive_background.alpha))
        self._revealAction_destructive_foreground = revealAction_destructive_foreground.withAlphaComponent(max(0.6, revealAction_destructive_foreground.alpha))
        self._revealAction_constructive_background = revealAction_constructive_background.withAlphaComponent(max(0.6, revealAction_constructive_background.alpha))
        self._revealAction_constructive_foreground = revealAction_constructive_foreground.withAlphaComponent(max(0.6, revealAction_constructive_foreground.alpha))
        self._revealAction_accent_background = revealAction_accent_background.withAlphaComponent(max(0.6, revealAction_accent_background.alpha))
        self._revealAction_accent_foreground = revealAction_accent_foreground.withAlphaComponent(max(0.6, revealAction_accent_foreground.alpha))
        self._revealAction_warning_background = revealAction_warning_background.withAlphaComponent(max(0.6, revealAction_warning_background.alpha))
        self._revealAction_warning_foreground = revealAction_warning_foreground.withAlphaComponent(max(0.6, revealAction_warning_foreground.alpha))
        self._revealAction_inactive_background = revealAction_inactive_background.withAlphaComponent(max(0.6, revealAction_inactive_background.alpha))
        self._revealAction_inactive_foreground = revealAction_inactive_foreground.withAlphaComponent(max(0.6, revealAction_inactive_foreground.alpha))
        
        self._chatBackground = chatBackground.withAlphaComponent(max(0.6, chatBackground.alpha))
        self.wallpaper = wallpaper
        self._listBackground = listBackground
        self._listGrayText = listGrayText
        self._grayHighlight = grayHighlight
        self._focusAnimationColor = focusAnimationColor
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
            return nightAccentPalette
        case nightAccentPalette.name:
            return nightAccentPalette
        case darkPalette.name:
            return darkPalette
        case dayClassicPalette.name:
            return dayClassicPalette
        case systemPalette.name:
            return systemPalette
        case "Mojave":
            return darkPalette
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
                            accentSelect: accentSelect,
                            selectText: selectText,
                            border: border,
                            grayBackground: grayBackground,
                            grayForeground: grayForeground,
                            grayIcon: grayIcon,
                            accentIcon: accentIcon,
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
                            bubbleBackgroundTop_outgoing: bubbleBackgroundTop_outgoing,
                            bubbleBackgroundBottom_outgoing: bubbleBackgroundBottom_outgoing,
                            bubbleBorder_incoming: bubbleBorder_incoming,
                            bubbleBorder_outgoing: bubbleBorder_outgoing,
                            grayTextBubble_incoming: grayTextBubble_incoming,
                            grayTextBubble_outgoing: grayTextBubble_outgoing,
                            grayIconBubble_incoming: grayIconBubble_incoming,
                            grayIconBubble_outgoing: grayIconBubble_outgoing,
                            accentIconBubble_incoming: accentIconBubble_incoming,
                            accentIconBubble_outgoing: accentIconBubble_outgoing,
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
                            listBackground: listBackground,
                            listGrayText: listGrayText,
                            grayHighlight: grayHighlight,
                            focusAnimationColor: focusAnimationColor)
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
                            accentSelect: accentSelect,
                            selectText: selectText,
                            border: border,
                            grayBackground: grayBackground,
                            grayForeground: grayForeground,
                            grayIcon: grayIcon,
                            accentIcon: accentIcon,
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
                            bubbleBackgroundTop_outgoing: bubbleBackgroundTop_outgoing,
                            bubbleBackgroundBottom_outgoing: bubbleBackgroundBottom_outgoing,
                            bubbleBorder_incoming: bubbleBorder_incoming,
                            bubbleBorder_outgoing: bubbleBorder_outgoing,
                            grayTextBubble_incoming: grayTextBubble_incoming,
                            grayTextBubble_outgoing: grayTextBubble_outgoing,
                            grayIconBubble_incoming: grayIconBubble_incoming,
                            grayIconBubble_outgoing: grayIconBubble_outgoing,
                            accentIconBubble_incoming: accentIconBubble_incoming,
                            accentIconBubble_outgoing: accentIconBubble_outgoing,
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
                            listBackground: listBackground,
                            listGrayText: listGrayText,
                            grayHighlight: grayHighlight,
                            focusAnimationColor: focusAnimationColor)
    }
    
    public func withAccentColor(_ color: PaletteAccentColor, disableTint: Bool = false) -> ColorPalette {
        
        var accentColor = color.accent
        let hsv = color.accent.hsv
        accentColor = NSColor(hue: hsv.0, saturation: hsv.1, brightness: max(hsv.2, 0.18), alpha: 1.0)
        


        
        var background = self.background
        var border = self.border
        var grayBackground = self.grayBackground
        var grayForeground = self.grayForeground
        var bubbleBackground_incoming = self.bubbleBackground_incoming
        var bubbleBorder_incoming = self.bubbleBorder_incoming
        var bubbleBorder_outgoing = self.bubbleBorder_outgoing
        var bubbleBackgroundHighlight_incoming = self.bubbleBackgroundHighlight_incoming
        var bubbleBackgroundHighlight_outgoing = self.bubbleBackgroundHighlight_outgoing
        var chatBackground = self.chatBackground
        var listBackground = self.listBackground
        var selectMessage = self.selectMessage
        var grayHighlight = self.grayHighlight
        let link = color.accent

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
            grayHighlight = background.darker(amount: 0.08)
        }
        
        
        var lightnessColor = color.messages?.top ?? color.accent
        
        if color.messages == nil {
            switch parent {
            case .dayClassic:
                let hsb = accentColor.hsb
                lightnessColor = NSColor(hue: hsb.0, saturation: (hsb.1 > 0.0 && hsb.2 > 0.0) ? 0.14 : 0.0, brightness: 0.79 + hsb.2 * 0.21, alpha: 1.0)
            default:
                break
            }
        } else if let messages = color.messages {
            lightnessColor = messages.top.blended(withFraction: 0.5, of: messages.bottom)!
        }
        
        
        
        let bubbleBackgroundTop_outgoing = color.messages?.top ?? lightnessColor
        let bubbleBackgroundBottom_outgoing = color.messages?.bottom ?? lightnessColor

        bubbleBackgroundHighlight_outgoing = lightnessColor.darker(amount: 0.1)

        
        
        
        var textBubble_outgoing = self.textBubble_outgoing
        var webPreviewActivityBubble_outgoing = self.webPreviewActivityBubble_outgoing
        var monospacedPreBubble_outgoing = self.monospacedPreBubble_outgoing
        var monospacedCodeBubble_outgoing = self.monospacedCodeBubble_outgoing
        var grayTextBubble_outgoing = self.grayTextBubble_outgoing
        var grayIconBubble_outgoing = self.grayIconBubble_outgoing
        var accentIconBubble_outgoing = self.accentIconBubble_outgoing
        var fileActivityForegroundBubble_outgoing = self.fileActivityForegroundBubble_outgoing
        var fileActivityBackgroundBubble_outgoing = self.fileActivityBackgroundBubble_outgoing
        var linkBubble_outgoing = self.linkBubble_outgoing
        var chatReplyTextEnabledBubble_outgoing = self.chatReplyTextEnabledBubble_outgoing
        var chatReplyTextDisabledBubble_outgoing = self.chatReplyTextDisabledBubble_outgoing
        var chatReplyTitleBubble_outgoing = self.chatReplyTitleBubble_outgoing
        
        var waveformForegroundBubble_outgoing = self.waveformForegroundBubble_outgoing
        var waveformBackgroundBubble_outgoing = self.waveformBackgroundBubble_outgoing
        var waveformForegroundBubble_incoming = self.waveformForegroundBubble_outgoing
        var waveformBackgroundBubble_incoming = self.waveformBackgroundBubble_incoming

        
        let fileActivityForegroundBubble_incoming = NSColor(0xffffff)
        let fileActivityBackgroundBubble_incoming = color.accent

        
        var selectTextBubble_outgoing = self.selectTextBubble_outgoing

        
        bubbleBorder_outgoing = lightnessColor.withAlphaComponent(0.7)
        
        if lightnessColor.lightness > 0.75 {
            let hueFactor: CGFloat = 0.75
            let saturationFactor: CGFloat = 1.1
            let outgoingPrimaryTextColor = NSColor(rgb: 0x000000)
            let outgoingSecondaryTextColor = lightnessColor.withMultiplied(hue: 1.344 * hueFactor, saturation: 4.554 * saturationFactor, brightness: 0.549).withAlphaComponent(0.8)
            bubbleBackgroundHighlight_outgoing = lightnessColor.withMultiplied(hue: 1.024, saturation: 0.9, brightness: 0.9)

            textBubble_outgoing = outgoingPrimaryTextColor
            webPreviewActivityBubble_outgoing = outgoingSecondaryTextColor.withAlphaComponent(1.0)
            monospacedPreBubble_outgoing = outgoingPrimaryTextColor
            monospacedCodeBubble_outgoing = outgoingPrimaryTextColor
            grayTextBubble_outgoing = outgoingSecondaryTextColor
            grayIconBubble_outgoing = outgoingSecondaryTextColor
            accentIconBubble_outgoing = outgoingSecondaryTextColor
            fileActivityForegroundBubble_outgoing = NSColor(0xffffff)
            fileActivityBackgroundBubble_outgoing = outgoingSecondaryTextColor.withAlphaComponent(1.0)
            linkBubble_outgoing = outgoingSecondaryTextColor
            chatReplyTextEnabledBubble_outgoing = outgoingPrimaryTextColor
            chatReplyTextDisabledBubble_outgoing = outgoingSecondaryTextColor
            chatReplyTitleBubble_outgoing = outgoingSecondaryTextColor
            
            waveformBackgroundBubble_outgoing = lightnessColor.withMultiplied(hue: 1.344 * hueFactor, saturation: 4.554 * saturationFactor, brightness: 0.549).withAlphaComponent(0.4)
            waveformForegroundBubble_outgoing = lightnessColor.withMultiplied(hue: 1.344 * hueFactor, saturation: 4.554 * saturationFactor, brightness: 0.549).withAlphaComponent(0.8)
            
            selectTextBubble_outgoing = lightnessColor.lighter(amount: 0.2)
            

        } else {
            
            waveformBackgroundBubble_outgoing = NSColor(0xffffff, 0)
            waveformForegroundBubble_outgoing = NSColor(0xffffff, 0)

            textBubble_outgoing = NSColor(0xffffff)
            bubbleBackgroundHighlight_outgoing = lightnessColor.withMultiplied(hue: 1.024, saturation: 0.9, brightness: 0.9)
            webPreviewActivityBubble_outgoing = NSColor(0xffffff)
            monospacedPreBubble_outgoing = NSColor(0xffffff)
            monospacedCodeBubble_outgoing = NSColor(0xffffff)
            grayTextBubble_outgoing = textBubble_outgoing.withMultiplied(hue: 0.956, saturation: 0.17, brightness: 1.0)
            grayIconBubble_outgoing = textBubble_outgoing.withMultiplied(hue: 0.956, saturation: 0.17, brightness: 1.0)
            accentIconBubble_outgoing = textBubble_outgoing
            fileActivityForegroundBubble_outgoing = color.accent
            fileActivityBackgroundBubble_outgoing = textBubble_outgoing
            linkBubble_outgoing = textBubble_outgoing
            chatReplyTextEnabledBubble_outgoing = textBubble_outgoing.withMultiplied(hue: 0.956, saturation: 0.17, brightness: 1.0)
            chatReplyTextDisabledBubble_outgoing = textBubble_outgoing.withMultiplied(hue: 0.956, saturation: 0.17, brightness: 1.0)
            chatReplyTitleBubble_outgoing = textBubble_outgoing.withMultiplied(hue: 0.956, saturation: 0.17, brightness: 1.0)
            
        }
        
        
        
        let chatReplyTitleBubble_incoming = color.accent
        
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
                            accent: color.accent,
                            redUI: redUI,
                            greenUI: greenUI,
                            blackTransparent: blackTransparent,
                            grayTransparent: grayTransparent,
                            grayUI: grayUI,
                            darkGrayText: darkGrayText,
                            accentSelect: color.accent,
                            selectText: selectText,
                            border: border,
                            grayBackground: grayBackground,
                            grayForeground: grayForeground,
                            grayIcon: grayIcon,
                            accentIcon: color.accent,
                            badgeMuted: badgeMuted,
                            badge: color.accent,
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
                            bubbleBackgroundTop_outgoing: bubbleBackgroundTop_outgoing,
                            bubbleBackgroundBottom_outgoing: bubbleBackgroundBottom_outgoing,
                            bubbleBorder_incoming: bubbleBorder_incoming,
                            bubbleBorder_outgoing: bubbleBorder_outgoing,
                            grayTextBubble_incoming: grayTextBubble_incoming,
                            grayTextBubble_outgoing: grayTextBubble_outgoing,
                            grayIconBubble_incoming: grayIconBubble_incoming,
                            grayIconBubble_outgoing: grayIconBubble_outgoing,
                            accentIconBubble_incoming: accentIconBubble_incoming,
                            accentIconBubble_outgoing: accentIconBubble_outgoing,
                            linkBubble_incoming: linkBubble_incoming,
                            linkBubble_outgoing: linkBubble_outgoing,
                            textBubble_incoming: textBubble_incoming,
                            textBubble_outgoing: textBubble_outgoing,
                            selectMessageBubble: selectMessageBubble,
                            fileActivityBackground: color.accent,
                            fileActivityForeground: fileActivityForeground,
                            fileActivityBackgroundBubble_incoming: fileActivityBackgroundBubble_incoming,
                            fileActivityBackgroundBubble_outgoing: fileActivityBackgroundBubble_outgoing,
                            fileActivityForegroundBubble_incoming: fileActivityForegroundBubble_incoming,
                            fileActivityForegroundBubble_outgoing: fileActivityForegroundBubble_outgoing,
                            waveformBackground: waveformBackground,
                            waveformForeground: color.accent,
                            waveformBackgroundBubble_incoming: waveformBackgroundBubble_incoming,
                            waveformBackgroundBubble_outgoing: waveformBackgroundBubble_outgoing,
                            waveformForegroundBubble_incoming: waveformForegroundBubble_incoming,
                            waveformForegroundBubble_outgoing: waveformForegroundBubble_outgoing,
                            webPreviewActivity: color.accent,
                            webPreviewActivityBubble_incoming: webPreviewActivityBubble_incoming,
                            webPreviewActivityBubble_outgoing: webPreviewActivityBubble_outgoing,
                            redBubble_incoming: redBubble_incoming,
                            redBubble_outgoing: redBubble_outgoing,
                            greenBubble_incoming: greenBubble_incoming,
                            greenBubble_outgoing: greenBubble_outgoing,
                            chatReplyTitle: color.accent,
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
                            listBackground: listBackground,
                            listGrayText: listGrayText,
                            grayHighlight: grayHighlight,
                            focusAnimationColor: focusAnimationColor)
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
    case day = "day"
    case dayClassic = "dayClassic"
    case dark = "dark"
    case nightAccent = "nightAccent"
    case system = "system"
    
    public init?(rawValue: String) {
        switch rawValue {
        case  "Day":
            self = .day
        case  "day":
            self = .day
        case "Day Classic":
            self = .dayClassic
        case "dayClassic":
            self = .dayClassic
        case "Dark":
            self = .dark
        case "dark":
            self = .dark
        case "Tinted Blue":
            self = .nightAccent
        case "Night Blue":
            self = .nightAccent
        case "nightAccent":
            self = .nightAccent
        case "System":
            self = .system
        case "system":
            self = .system
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
        case .system:
            return systemPalette
        case .nightAccent:
            return nightAccentPalette
        }
    }
}



//0xE3EDF4
public let whitePalette = ColorPalette(isNative: true, isDark: false,
                                       tinted: false,
                                       name: "day",
                                       parent: .day,
                                       wallpaper: .none,
                                       copyright: "Telegram",
                                       accentList: [PaletteAccentColor(NSColor(0x2481cc)),
                                                    PaletteAccentColor(NSColor(0xf83b4c)),
                                                    PaletteAccentColor(NSColor(0xff7519)),
                                                    PaletteAccentColor(NSColor(0xeba239)),
                                                    PaletteAccentColor(NSColor(0x29b327)),
                                                    PaletteAccentColor(NSColor(0x00c2ed)),
                                                    PaletteAccentColor(NSColor(0x7748ff)),
                                                    PaletteAccentColor(NSColor(0xff5da2))],
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
                                       accentSelect:NSColor(0x4c91c7),
                                       selectText:NSColor(0xeaeaea),
                                       border:NSColor(0xeaeaea),
                                       grayBackground:NSColor(0xf4f4f4),
                                       grayForeground:NSColor(0xe4e4e4),
                                       grayIcon:NSColor(0x9e9e9e),
                                       accentIcon:NSColor(0x2481cc),
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
                                       bubbleBackgroundTop_outgoing: NSColor(0x4c91c7),//0x007ee5
                                        bubbleBackgroundBottom_outgoing: NSColor(0x4c91c7),//0x007ee5
                                        bubbleBorder_incoming: NSColor(0xeaeaea),
                                        bubbleBorder_outgoing: NSColor(0x4c91c7),
                                        grayTextBubble_incoming: NSColor(0x999999),
                                        grayTextBubble_outgoing: NSColor(0xEFFAFF, 0.8),
                                        grayIconBubble_incoming: NSColor(0x999999),
                                        grayIconBubble_outgoing: NSColor(0xEFFAFF, 0.8),
                                        accentIconBubble_incoming: NSColor(0x999999),
                                        accentIconBubble_outgoing: NSColor(0xEFFAFF, 0.8),
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
                                        listBackground: NSColor(0xefeff3),
                                        listGrayText: NSColor(0x6D6D71),
                                        grayHighlight: NSColor(0xF8F8F8),
                                        focusAnimationColor: NSColor(0x68A8E2)
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

public let nightAccentPalette = ColorPalette(isNative: true, isDark: true,
                                           tinted: true,
                                           name:"nightAccent",
                                           parent: .nightAccent,
                                           wallpaper: .none,
                                           copyright: "Telegram",
                                           accentList: [PaletteAccentColor(NSColor(0x2ea6ff)),
                                                        PaletteAccentColor(NSColor(0xf83b4c)),
                                                        PaletteAccentColor(NSColor(0xff7519)),
                                                        PaletteAccentColor(NSColor(0xeba239)),
                                                        PaletteAccentColor(NSColor(0x29b327)),
                                                        PaletteAccentColor(NSColor(0x00c2ed)),
                                                        PaletteAccentColor(NSColor(0x7748ff)),
                                                        PaletteAccentColor(NSColor(0xff5da2))],
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
                                           accentSelect: NSColor(0x3d6a97),
                                           selectText: NSColor(0x3e6b9b),
                                           border: NSColor(0x213040),
                                           grayBackground: NSColor(0x213040),
                                           grayForeground: NSColor(0x213040),
                                           grayIcon: NSColor(0xb1c3d5),
                                           accentIcon: NSColor(0x2ea6ff),
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
                                           bubbleBackgroundTop_outgoing: NSColor(0x3d6a97),
                                           bubbleBackgroundBottom_outgoing: NSColor(0x3d6a97),
                                           bubbleBorder_incoming: NSColor(0x213040),
                                           bubbleBorder_outgoing: NSColor(0x3d6a97),
                                           grayTextBubble_incoming: NSColor(0xb1c3d5),
                                           grayTextBubble_outgoing: NSColor(0xEFFAFF, 0.8),
                                           grayIconBubble_incoming: NSColor(0xb1c3d5),
                                           grayIconBubble_outgoing: NSColor(0xb1c3d5),
                                           accentIconBubble_incoming: NSColor(0xb1c3d5),
                                           accentIconBubble_outgoing: NSColor(0xEFFAFF, 0.8),
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
                                           listBackground: NSColor(0x131415),
                                           listGrayText: NSColor(0xb1c3d5),
                                           grayHighlight: NSColor(0x18222d).darker(amount: 0.08),
                                           focusAnimationColor: NSColor(0x68A8E2)
)
public let dayClassicPalette = ColorPalette(isNative: true,
                                            isDark: false,
                                            tinted: false,
                                            name:"dayClassic",
                                            parent: .dayClassic,
                                            wallpaper: .builtin,
                                            copyright: "Telegram",
                                            accentList: [PaletteAccentColor(NSColor(0x2481cc), (top: NSColor(0xdcf8c6), bottom: NSColor(0xdcf8c6))),
                                                         PaletteAccentColor(NSColor(0x5a9e29), (top: NSColor(0xdcf8c6), bottom: NSColor(0xdcf8c6))),
                                                         PaletteAccentColor(NSColor(0xf55783), (top: NSColor(0xd6f5ff), bottom: NSColor(0xd6f5ff))),
                                                         PaletteAccentColor(NSColor(0x7e5fe5), (top: NSColor(0xf5e2ff), bottom: NSColor(0xf5e2ff))),
                                                         PaletteAccentColor(NSColor(0xff5fa9), (top: NSColor(0xfff4d7), bottom: NSColor(0xfff4d7))),
                                                         PaletteAccentColor(NSColor(0x199972), (top: NSColor(0xfffec7), bottom: NSColor(0xfffec7))),
                                                         PaletteAccentColor(NSColor(0x009eee), (top: NSColor(0x94fff9), bottom: NSColor(0x94fff9)))],
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
                                            accentSelect: NSColor(0x4c91c7),
                                            selectText: NSColor(0xeaeaea),
                                            border: NSColor(0xeaeaea),
                                            grayBackground: NSColor(0xf4f4f4),
                                            grayForeground: NSColor(0xe4e4e4),
                                            grayIcon: NSColor(0x9e9e9e),
                                            accentIcon: NSColor(0x2481cc),
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
                                            bubbleBackgroundTop_outgoing: NSColor(0xE1FFC7),
                                            bubbleBackgroundBottom_outgoing: NSColor(0xE1FFC7),
                                            bubbleBorder_incoming: NSColor(0x86A9C9,0.5),
                                            bubbleBorder_outgoing: NSColor(0x86A9C9,0.5),
                                            grayTextBubble_incoming: NSColor(0x999999),
                                            grayTextBubble_outgoing: NSColor(0x008c09,0.8),
                                            grayIconBubble_incoming: NSColor(0x999999),
                                            grayIconBubble_outgoing: NSColor(0x008c09,0.8),
                                            accentIconBubble_incoming: NSColor(0x999999),
                                            accentIconBubble_outgoing: NSColor(0x008c09,0.8),
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
                                            listBackground: NSColor(0xefeff3),
                                            listGrayText: NSColor(0x6D6D71),
                                            grayHighlight: NSColor(0xF8F8F8),
                                            focusAnimationColor: NSColor(0x68A8E2)
)

public let darkPalette = ColorPalette(isNative: true, isDark:true,
                                      tinted: false,
                                      name:"Dark",
                                      parent: .dark,
                                      wallpaper: .none,
                                      copyright: "Telegram",
                                      accentList: [PaletteAccentColor(NSColor(0x04afc8)),
                                                   PaletteAccentColor(NSColor(0xf83b4c)),
                                                   PaletteAccentColor(NSColor(0xff7519)),
                                                   PaletteAccentColor(NSColor(0xeba239)),
                                                   PaletteAccentColor(NSColor(0x29b327)),
                                                   PaletteAccentColor(NSColor(0x00c2ed)),
                                                   PaletteAccentColor(NSColor(0x7748ff)),
                                                   PaletteAccentColor(NSColor(0xff5da2))],
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
                                      accentSelect: NSColor(0x20889a),
                                      selectText: NSColor(0x8699a3),
                                      border: NSColor(0x464a57),
                                      grayBackground : NSColor(0x464a57),
                                      grayForeground : NSColor(0x3d414d),
                                      grayIcon: NSColor(0x8699a3),
                                      accentIcon: NSColor(0x04afc8),
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
                                      bubbleBackgroundTop_outgoing: NSColor(0x20889a),
                                      bubbleBackgroundBottom_outgoing: NSColor(0x20889a),
                                      bubbleBorder_incoming: NSColor(0x464a57),
                                      bubbleBorder_outgoing: NSColor(0x20889a),
                                      grayTextBubble_incoming: NSColor(0x8699a3),
                                      grayTextBubble_outgoing: NSColor(0xa0d5dd),
                                      grayIconBubble_incoming: NSColor(0x8699a3),
                                      grayIconBubble_outgoing: NSColor(0xa0d5dd),
                                      accentIconBubble_incoming: NSColor(0x8699a3),
                                      accentIconBubble_outgoing: NSColor(0xa0d5dd),
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
                                      listBackground: NSColor(0x131415),
                                      listGrayText: NSColor(0x8699a3),
                                      grayHighlight: NSColor(0x292b36).darker(amount: 0.08),
                                      focusAnimationColor: NSColor(0x68A8E2)
)

@available(macOS 10.14, *)
private final class MojavePalette : ColorPalette {
    
    private var underPageBackgroundColor: NSColor {
        return NSColor(0x282828)
    }
    private var windowBackgroundColor: NSColor {
        return NSColor(0x323232)
    }
    private var controlAccentColor: NSColor {
        return NSColor.controlAccentColor.usingColorSpaceName(NSColorSpaceName.deviceRGB)!
    }
    private var selectedTextBackgroundColor: NSColor {
        return controlAccentColor.darker()
    }
    private var secondaryLabelColor: NSColor {
        return NSColor(0xffffff, 0.55)
    }
    private var systemRed: NSColor {
        return NSColor(0xFF453A)
    }
    private var systemGreen: NSColor {
        return NSColor(0x32D74B)
    }
    private var controlBackgroundColor: NSColor {
        return NSColor(0x1E1E1E)
    }
    private var separatorColor: NSColor {
        return NSColor(0x3d3d3d)
    }
    private var textColor: NSColor {
        return NSColor(0xffffff, 0.85)
    }
    private var disabledControlTextColor: NSColor {
        return NSColor(0xffffff, 0.25)
    }
    private var unemphasizedSelectedTextBackgroundColor: NSColor {
        return NSColor(0x464646)
    }
    
    override var background: NSColor {
        return underPageBackgroundColor
    }
    override var grayBackground: NSColor {
        return windowBackgroundColor
    }
    override var link: NSColor {
        return controlAccentColor
    }
    override var selectText: NSColor {
        return selectedTextBackgroundColor
    }
    override var accent: NSColor {
        return controlAccentColor
    }
    override var accentIcon: NSColor {
        return controlAccentColor
    }
    override var grayIcon: NSColor {
        return secondaryLabelColor
    }
    override var redUI: NSColor {
        return systemRed
    }
    override var greenUI: NSColor {
        return systemGreen
    }
    override var text: NSColor {
        return textColor
    }
    override var grayText: NSColor {
        return secondaryLabelColor
    }
    override var listGrayText: NSColor {
        return secondaryLabelColor.darker(amount: 0.1)
    }
    override var listBackground: NSColor {
        return controlBackgroundColor.darker(amount: 0.05)
    }
    override var chatBackground: NSColor {
        return controlBackgroundColor
    }
    override var border: NSColor {
       return separatorColor
    }
    override var accentSelect: NSColor {
        return controlAccentColor.darker(amount: 0.2)
    }
    override var webPreviewActivity: NSColor {
        return controlAccentColor
    }
    override var fileActivityBackground: NSColor {
        return controlAccentColor
    }
    override var fileActivityForeground: NSColor {
        return underSelectedColor
    }
    override var waveformForeground: NSColor {
        return controlAccentColor
    }
    override var chatReplyTitle: NSColor {
        return controlAccentColor
    }
    override var chatReplyTextEnabled: NSColor {
        return textColor
    }
    override var chatReplyTextDisabled: NSColor {
        return disabledControlTextColor
    }
    override var chatReplyTextDisabledBubble_outgoing: NSColor {
        return NSColor.white.usingColorSpaceName(NSColorSpaceName.deviceRGB)!
    }
    override var groupPeerNameRed: NSColor {
        return NSColor.systemRed.usingColorSpaceName(NSColorSpaceName.deviceRGB)!
    }
    override var groupPeerNameBlue: NSColor {
        return NSColor.systemBlue.usingColorSpaceName(NSColorSpaceName.deviceRGB)!
    }
    override var groupPeerNameGreen: NSColor {
        return NSColor.systemGreen.usingColorSpaceName(NSColorSpaceName.deviceRGB)!
    }
    override var groupPeerNameOrange: NSColor {
        return NSColor.systemOrange.usingColorSpaceName(NSColorSpaceName.deviceRGB)!
    }
    override var bubbleBackgroundTop_outgoing: NSColor {
        return controlAccentColor.darker(amount: 0.2)
    }
    override var bubbleBackgroundBottom_outgoing: NSColor {
        return controlAccentColor.darker(amount: 0.2)
    }
    override var bubbleBorder_outgoing: NSColor {
        return controlAccentColor.darker(amount: 0.2)
    }
    override var bubbleBackground_incoming: NSColor {
        return windowBackgroundColor
    }
    override var bubbleBackgroundHighlight_incoming: NSColor {
        return windowBackgroundColor.lighter(amount: 0.2)
    }
    override var bubbleBackgroundHighlight_outgoing: NSColor {
        return controlAccentColor
    }
    override var linkBubble_outgoing: NSColor {
        return NSColor.white.usingColorSpaceName(NSColorSpaceName.deviceRGB)!
    }
    override var selectTextBubble_incoming: NSColor {
        return selectedTextBackgroundColor
    }
    override var selectTextBubble_outgoing: NSColor {
        return unemphasizedSelectedTextBackgroundColor
    }
    override var linkBubble_incoming: NSColor {
        return controlAccentColor
    }
    override var waveformForegroundBubble_outgoing: NSColor {
        return grayIconBubble_outgoing
    }
    override var fileActivityForegroundBubble_incoming: NSColor {
        return windowBackgroundColor
    }
    override var fileActivityForegroundBubble_outgoing: NSColor {
        return controlAccentColor
    }
}

public let systemPalette: ColorPalette = {
    
    let initializer: ColorPalette.Type
    if #available(macOS 10.14, *) {
        initializer = MojavePalette.self
    } else {
        initializer = ColorPalette.self
    }
    let palette = initializer.init(isNative: true, isDark: true,
                            tinted: false,
                            name: "system",
                            parent: .system,
                            wallpaper: .none,
                            copyright: "Telegram",
                            accentList: [],
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
                            accentSelect: NSColor(0x3d6a97),
                            selectText: NSColor(0x3e6b9b),
                            border: NSColor(0x3d474f),
                            grayBackground: NSColor(0x3e464c),
                            grayForeground: NSColor(0x3e464c),
                            grayIcon: NSColor(0xb1c3d5),
                            accentIcon: NSColor(0x2ea6ff),
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
                            bubbleBackgroundTop_outgoing: NSColor(0x3d6a97),
                            bubbleBackgroundBottom_outgoing: NSColor(0x3d6a97),
                            bubbleBorder_incoming: NSColor(0x4e5058),
                            bubbleBorder_outgoing: NSColor(0x3d6a97),
                            grayTextBubble_incoming: NSColor(0xb1c3d5),
                            grayTextBubble_outgoing: NSColor(0xEFFAFF, 0.8),
                            grayIconBubble_incoming: NSColor(0xb1c3d5),
                            grayIconBubble_outgoing: NSColor(0xb1c3d5),
                            accentIconBubble_incoming: NSColor(0xb1c3d5),
                            accentIconBubble_outgoing: NSColor(0xEFFAFF, 0.8),
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
                            listBackground: NSColor(0x131415),
                            listGrayText: NSColor(0xb1c3d5),
                            grayHighlight: NSColor(0x292a2f).darker(amount: 0.08),
                            focusAnimationColor: NSColor(0x68A8E2)
    )
    
   

    return palette
}()


/*
 public let darkPalette = ColorPalette(background: NSColor(0x282e33), text: NSColor(0xe9e9e9), grayText: NSColor(0x999999), link: NSColor(0x20eeda), accent: NSColor(0x20eeda), redUI: NSColor(0xec6657), greenUI:NSColor(0x63DA6E), blackTransparent: NSColor(0x000000, 0.6), grayTransparent: NSColor(0xf4f4f4, 0.4), grayUI: NSColor(0xFaFaFa), darkGrayText:NSColor(0x333333), blueText:NSColor(0x009687), accentSelect:NSColor(0x009687), selectText:NSColor(0xeaeaea), blueFill: NSColor(0x20eeda), border: NSColor(0x3d444b), grayBackground:NSColor(0x3d444b), grayForeground:NSColor(0xe4e4e4), grayIcon:NSColor(0x757676), accentIcon: NSColor(0x20eeda), badgeMuted:NSColor(0xd7d7d7), badge:NSColor(0x4ba3e2), indicatorColor: NSColor(0xffffff))
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


public extension ColorPalette {
    var appearance: NSAppearance {
        switch parent {
        case .system:
            if #available(macOS 10.14, *) {
                return NSAppearance(named: NSAppearance.Name.darkAqua)!
            } else {
                return NSAppearance(named: NSAppearance.Name.vibrantDark)!
            }
        default:
            if #available(macOS 10.14, *) {
                return isDark ? NSAppearance(named: NSAppearance.Name.darkAqua)! : NSAppearance(named: NSAppearance.Name.aqua)!
            } else {
                return isDark ? NSAppearance(named: NSAppearance.Name.vibrantDark)! : NSAppearance(named: NSAppearance.Name.aqua)!
            }
        }
    }
}
public extension PresentationTheme {
    var appearance: NSAppearance {
        return colors.appearance
    }
}
