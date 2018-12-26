//
//  InstantPageTextStyleStack.swift
//  Telegram
//
//  Created by keepcoder on 10/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

import TelegramCoreMac
import TGUIKit

enum InstantPageTextStyle {
    case fontSize(CGFloat)
    case lineSpacingFactor(CGFloat)
    case fontSerif(Bool)
    case fontFixed(Bool)
    case bold
    case italic
    case underline
    case strikethrough
    case textColor(NSColor)
    case `subscript`
    case superscript
    case markerColor(NSColor)
    case marker
    case anchor(String, Bool)
    case linkColor(NSColor)
    case linkMarkerColor(NSColor)
    case link(Bool)
}

extension NSAttributedString.Key {
    static let instantPageLineSpacingFactorAttribute = NSAttributedString.Key("InstantPageLineSpacingFactorAttribute")
    static let instantPageMarkerColorAttribute = NSAttributedString.Key("InstantPageMarkerColorAttribute")
    static let instantPageMediaIdAttribute = NSAttributedString.Key("InstantPageMediaIdAttribute")
    static let instantPageMediaDimensionsAttribute = NSAttributedString.Key("InstantPageMediaDimensionsAttribute")
    static let instantPageAnchorAttribute = NSAttributedString.Key("InstantPageAnchorAttribute")
}


final class InstantPageTextStyleStack {
    private var items: [InstantPageTextStyle] = []
    
    func push(_ item: InstantPageTextStyle) {
        items.append(item)
    }
    
    func pop() {
        if !items.isEmpty {
            items.removeLast()
        }
    }
    
    func textAttributes() -> [NSAttributedString.Key: Any] {
        var fontSize: CGFloat?
        var fontSerif: Bool?
        var fontFixed: Bool?
        var bold: Bool?
        var italic: Bool?
        var strikethrough: Bool?
        var underline: Bool?
        var color: NSColor?
        var lineSpacingFactor: CGFloat?
        var baselineOffset: CGFloat?
        var markerColor: NSColor?
        var marker: Bool?
        var anchor: Dictionary<String, Any>?
        var linkColor: NSColor?
        var linkMarkerColor: NSColor?
        var link: Bool?
        
        for item in self.items.reversed() {
            switch item {
            case let .fontSize(value):
                if fontSize == nil {
                    fontSize = value
                }
            case let .fontSerif(value):
                if fontSerif == nil {
                    fontSerif = value
                }
            case let .fontFixed(value):
                if fontFixed == nil {
                    fontFixed = value
                }
            case .bold:
                if bold == nil {
                    bold = true
                }
            case .italic:
                if italic == nil {
                    italic = true
                }
            case .strikethrough:
                if strikethrough == nil {
                    strikethrough = true
                }
            case .underline:
                if underline == nil {
                    underline = true
                }
            case let .textColor(value):
                if color == nil {
                    color = value
                }
            case let .lineSpacingFactor(value):
                if lineSpacingFactor == nil {
                    lineSpacingFactor = value
                }
            case .subscript:
                if baselineOffset == nil {
                    baselineOffset = 0.35
                    underline = false
                }
            case .superscript:
                if baselineOffset == nil {
                    baselineOffset = -0.35
                }
            case let .markerColor(color):
                if markerColor == nil {
                    markerColor = color
                }
            case .marker:
                if marker == nil {
                    marker = true
                }
            case let .anchor(name, empty):
                if anchor == nil {
                    anchor = ["name": name, "empty": empty]
                }
            case let .linkColor(color):
                if linkColor == nil {
                    linkColor = color
                }
            case let .linkMarkerColor(color):
                if linkMarkerColor == nil {
                    linkMarkerColor = color
                }
            case let .link(instant):
                if link == nil {
                    link = instant
                }
            }
        }
        
        var attributes: [NSAttributedString.Key: Any] = [:]
        
        var parsedFontSize: CGFloat
        if let fontSize = fontSize {
            parsedFontSize = fontSize
        } else {
            parsedFontSize = 16.0
        }
        
        if let baselineOffset = baselineOffset {
            attributes[.baselineOffset] = round(parsedFontSize * baselineOffset);
            parsedFontSize = round(parsedFontSize * 0.85)
        }
        
        if (bold != nil && bold!) && (italic != nil && italic!) {
            if fontSerif != nil && fontSerif! {
                attributes[.font] = NSFont(name: "Georgia-BoldItalic", size: parsedFontSize)
            } else if fontFixed != nil && fontFixed! {
                attributes[.font] = NSFont(name: "Menlo-BoldItalic", size: parsedFontSize)
            } else {
                attributes[.font] = systemMediumFont(parsedFontSize)
            }
        } else if bold != nil && bold! {
            if fontSerif != nil && fontSerif! {
                attributes[.font] = NSFont(name: "Georgia-Bold", size: parsedFontSize)
            } else if fontFixed != nil && fontFixed! {
                attributes[.font] = NSFont(name: "Menlo-Bold", size: parsedFontSize)
            } else {
                attributes[.font] = NSFont.bold(parsedFontSize)
            }
        } else if italic != nil && italic! {
            if fontSerif != nil && fontSerif! {
                attributes[.font] = NSFont(name: "Georgia-Italic", size: parsedFontSize)
            } else if fontFixed != nil && fontFixed! {
                attributes[.font] = NSFont(name: "Menlo-Italic", size: parsedFontSize)
            } else {
                attributes[.font] = NSFont.italic(parsedFontSize)
            }
        } else {
            if fontSerif != nil && fontSerif! {
                attributes[.font] = NSFont(name: "Georgia", size: parsedFontSize)
            } else if fontFixed != nil && fontFixed! {
                attributes[.font] = NSFont(name: "Menlo", size: parsedFontSize)
            } else {
                attributes[.font] = NSFont.normal(parsedFontSize)
            }
        }
        
        if strikethrough != nil && strikethrough! {
            attributes[.strikethroughStyle] = (NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDash.rawValue) as NSNumber
        }
        
        if underline != nil && underline! {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue as NSNumber
        }
        
        if let link = link, let linkColor = linkColor {
            attributes[.foregroundColor] = linkColor
            if link, let linkMarkerColor = linkMarkerColor {
                attributes[.instantPageMarkerColorAttribute] = linkMarkerColor
            }
        } else {
            if let color = color {
                attributes[.foregroundColor] = color
            } else {
                attributes[.foregroundColor] = NSColor.black
            }
        }
        
        if let lineSpacingFactor = lineSpacingFactor {
            attributes[.instantPageLineSpacingFactorAttribute] = lineSpacingFactor as NSNumber
        }
        
        if marker != nil && marker!, let markerColor = markerColor {
            attributes[.instantPageMarkerColorAttribute] = markerColor
        }
        
        if let anchor = anchor {
            attributes[.instantPageAnchorAttribute] = anchor
        }
        
        return attributes
    }
}
