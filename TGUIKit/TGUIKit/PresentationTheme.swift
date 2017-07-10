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
    let backgroundColor: NSColor
    let searchImage:CGImage
    let clearImage:CGImage
    let placeholder:String
    let textColor: NSColor
    let placeholderColor: NSColor
    public init(_ backgroundColor: NSColor, _ searchImage:CGImage, _ clearImage:CGImage, _ placeholder:String, _ textColor: NSColor, _ placeholderColor: NSColor) {
        self.backgroundColor = backgroundColor
        self.searchImage = searchImage
        self.clearImage = clearImage
        self.placeholder = placeholder
        self.textColor = textColor
        self.placeholderColor = placeholderColor
    }
}

public struct ColorPallete {
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
    public init(background:NSColor, text: NSColor, grayText: NSColor, link: NSColor, blueUI:NSColor, redUI:NSColor, greenUI:NSColor, blackTransparent:NSColor, grayTransparent:NSColor, grayUI:NSColor, darkGrayText:NSColor, blueText:NSColor, blueSelect:NSColor, selectText:NSColor, blueFill:NSColor, border:NSColor, grayBackground:NSColor, grayForeground:NSColor, grayIcon:NSColor, blueIcon:NSColor, badgeMuted:NSColor, badge:NSColor, indicatorColor: NSColor) {
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
    }
}



open class PresentationTheme : Equatable {
    
    public let colors:ColorPallete
    public let search: SearchTheme
    
    public let resourceCache = PresentationsResourceCache()
    
    public init(colors: ColorPallete, search: SearchTheme) {
        self.colors = colors
        self.search = search
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
    return ControlStyle(font: .medium(.title), foregroundColor: presentation.colors.link, backgroundColor: presentation.colors.background, highlightColor: presentation.colors.blueUI)
}
public var switchViewAppearance: SwitchViewAppearance {
    return SwitchViewAppearance(backgroundColor: presentation.colors.background, stateOnColor: presentation.colors.blueUI, stateOffColor: presentation.colors.background, disabledColor: presentation.colors.grayTransparent, borderColor: presentation.colors.border)
}

public let whitePallete = ColorPallete(background: .white, text: NSColor(0x000000), grayText: NSColor(0x999999), link: NSColor(0x2481cc), blueUI: NSColor(0x2481cc), redUI: NSColor(0xff3b30), greenUI:NSColor(0x63DA6E), blackTransparent: NSColor(0x000000, 0.6), grayTransparent: NSColor(0xf4f4f4, 0.4), grayUI: NSColor(0xFaFaFa), darkGrayText:NSColor(0x333333), blueText:NSColor(0x4ba3e2), blueSelect:NSColor(0x4c91c7), selectText:NSColor(0xeaeaea), blueFill:NSColor(0x4ba3e2), border:NSColor(0xeaeaea), grayBackground:NSColor(0xf4f4f4), grayForeground:NSColor(0xe4e4e4), grayIcon:NSColor(0x9e9e9e), blueIcon:NSColor(0x0f8fe4), badgeMuted:NSColor(0xd7d7d7), badge:NSColor(0x4ba3e2), indicatorColor: .black)
//04afc8
//282b35
public let darkPallete = ColorPallete(background: NSColor(0x292b36), text: NSColor(0xe9e9e9), grayText: NSColor(0x8699a3), link: NSColor(0x04afc8), blueUI: NSColor(0x04afc8), redUI: NSColor(0xec6657), greenUI:NSColor(0x63DA6E), blackTransparent: NSColor(0x000000, 0.6), grayTransparent: NSColor(0xf4f4f4, 0.4), grayUI: NSColor(0x292b36), darkGrayText:NSColor(0x8699a3), blueText:NSColor(0x04afc8), blueSelect:NSColor(0x20889a), selectText: NSColor(0x464a57), blueFill: NSColor(0x04afc8), border: NSColor(0x464a57), grayBackground:NSColor(0x464a57), grayForeground:NSColor(0xe4e4e4), grayIcon: NSColor(0x8699a3), blueIcon: NSColor(0x04afc8), badgeMuted:NSColor(0x8699a3), badge:NSColor(0x04afc8), indicatorColor: .white)

/*
 public let darkPallete = ColorPallete(background: NSColor(0x282e33), text: NSColor(0xe9e9e9), grayText: NSColor(0x999999), link: NSColor(0x20eeda), blueUI: NSColor(0x20eeda), redUI: NSColor(0xec6657), greenUI:NSColor(0x63DA6E), blackTransparent: NSColor(0x000000, 0.6), grayTransparent: NSColor(0xf4f4f4, 0.4), grayUI: NSColor(0xFaFaFa), darkGrayText:NSColor(0x333333), blueText:NSColor(0x009687), blueSelect:NSColor(0x009687), selectText:NSColor(0xeaeaea), blueFill: NSColor(0x20eeda), border: NSColor(0x3d444b), grayBackground:NSColor(0x3d444b), grayForeground:NSColor(0xe4e4e4), grayIcon:NSColor(0x757676), blueIcon: NSColor(0x20eeda), badgeMuted:NSColor(0xd7d7d7), badge:NSColor(0x4ba3e2), indicatorColor: .white)
 */


private var _theme:Atomic<PresentationTheme> = Atomic(value: whiteTheme)

public let whiteTheme = PresentationTheme(colors: whitePallete, search: SearchTheme(.grayBackground, #imageLiteral(resourceName: "Icon_SearchField").precomposed(), #imageLiteral(resourceName: "Icon_SearchClear").precomposed(), localizedString("SearchField.Search"), .text, .grayText))



public var presentation:PresentationTheme {
    return _theme.modify {$0}
}

public func updateTheme(_ theme:PresentationTheme) {
    assertOnMainThread()
    _ = _theme.swap(theme)
}


