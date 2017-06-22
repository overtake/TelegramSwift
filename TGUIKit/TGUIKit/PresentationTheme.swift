//
//  PresentationTheme.swift
//  Telegram
//
//  Created by keepcoder on 22/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac

public enum PresentationThemeParsingError: Error {
    case generic
}
//
//private func parseColor(_ decoder: Decoder, _ key: String) throws -> NSColor {
//    if let value = decoder.decodeOptionalInt32ForKey(key) {
//        return NSColor(argb: UInt32(bitPattern: value))
//    } else {
//        throw PresentationThemeParsingError.generic
//    }
//}


//
//    public let link:NSColor
//    public let blueUI:NSColor
//    public let redUI:NSColor
//    public let greenUI:NSColor
//    public let blackTransparent:NSColor
//    public let grayTransparent:NSColor
//    public let grayUI:NSColor
//    public let darkGrayText:NSColor
//    public let text:NSColor
//    public let blueText:NSColor
//    public let blueSelect:NSColor
//    public let selectText:NSColor
//    public let blueFill:NSColor
//    public let border:NSColor
//    public let grayBackground:NSColor
//    public let grayForeground:NSColor
//    public let grayIcon:NSColor
//    public let blueIcon:NSColor
//    public let badgeMuted:NSColor
//    public let badge:NSColor


public struct SearchTheme {
    let backgroundColor: NSColor
    let searchImage:CGImage
    let clearImage:CGImage
    let placeholder:String
    let textColor: NSColor
    public init(_ backgroundColor: NSColor, _ searchImage:CGImage, _ clearImage:CGImage, _ placeholder:String, _ textColor: NSColor) {
        self.backgroundColor = backgroundColor
        self.searchImage = searchImage
        self.clearImage = clearImage
        self.placeholder = placeholder
        self.textColor = textColor
    }
}

public struct ColorTheme {
    public let backgroundColor: NSColor
    public let textColor: NSColor
    public let grayTextColor:NSColor
    public let linkColor:NSColor
    
    init(backgroundColor:NSColor, textColor: NSColor, grayTextColor: NSColor, linkColor: NSColor) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.grayTextColor = grayTextColor
        self.linkColor = linkColor
    }
}



open class PresentationTheme : Equatable {
    
    public let colors:ColorTheme
    public let search: SearchTheme
    
    public let resourceCache = PresentationsResourceCache()
    
    public init(colors: ColorTheme, search: SearchTheme) {
        self.colors = colors
        self.search = search
    }
    
//    public init(decoder: Decoder) throws {
//        self.backgroundColor = try parseColor(decoder, "backgroundColor")
//        self.textColor = try parseColor(decoder, "textColor")
//        self.grayTextColor = try parseColor(decoder, "grayTextColor")
//        self.linkColor = try parseColor(decoder, "linkColor")
//    }
//    
//    public func encode(_ encoder: Encoder) {
//        for child in Mirror(reflecting: self).children {
//            if let label = child.label {
//                if let value = child.value as? NSColor {
//                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
//                } else {
//                    assertionFailure()
//                }
//            }
//        }
//    }
    
    public static func ==(lhs: PresentationTheme, rhs: PresentationTheme) -> Bool {
        return lhs === rhs
    }
    
    public func image(_ key: Int32, _ generate: (PresentationTheme) -> CGImage?) -> CGImage? {
        return self.resourceCache.image(key, self, generate)
    }
    
    public func object(_ key: Int32, _ generate: (PresentationTheme) -> AnyObject?) -> AnyObject? {
        return self.resourceCache.object(key, self, generate)
    }
}



public let whiteAppearanceColor = ColorTheme(backgroundColor: .white, textColor: NSColor(0x000000), grayTextColor: .grayText, linkColor: .link)

public let blackAppearanceColor = ColorTheme(backgroundColor: NSColor(0x252526), textColor: NSColor(0x000000), grayTextColor: .grayText, linkColor: .link)


private var _theme:PresentationTheme = whiteTheme

public let whiteTheme = PresentationTheme(colors: whiteAppearanceColor, search: SearchTheme(.grayBackground, #imageLiteral(resourceName: "Icon_SearchField").precomposed(), #imageLiteral(resourceName: "Icon_SearchClear").precomposed(), localizedString("SearchField.Search"), .grayText))



public var presentation:PresentationTheme {
    return _theme
}

public func updateTheme(_ theme:PresentationTheme) {
    assertOnMainThread()
    _ = _theme = theme
}


