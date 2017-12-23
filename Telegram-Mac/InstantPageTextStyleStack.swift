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


func richPlainText(_ text:RichText) -> String {
    switch text {
    case .plain(let plain):
        return plain
    case .bold(let rich), .italic(let rich), .fixed(let rich), .strikethrough(let rich), .underline(let rich):
        return richPlainText(rich)
    case .email(let rich, _):
        return richPlainText(rich)
    case .url(let rich, _, _):
        return richPlainText(rich)
    case .concat(let richs):
        var string:String = ""
        for rich in richs {
            string += richPlainText(rich)
        }
        return string
    case .empty:
        return""
    }
}

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
    case link(RichText)
}

extension NSAttributedStringKey {
    static var instantPageLineSpacingFactor: NSAttributedStringKey {
        return NSAttributedStringKey.init(rawValue: "LineSpacingFactorAttribute")
    }
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
    
    func textAttributes() -> [NSAttributedStringKey: Any] {
        var fontSize: CGFloat?
        var fontSerif: Bool?
        var fontFixed: Bool?
        var bold: Bool?
        var italic: Bool?
        var strikethrough: Bool?
        var underline: Bool?
        var color: NSColor?
        var lineSpacingFactor: CGFloat?
        var link:RichText?
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
            case .link(let value):
                link = value
            }
        }
        
        var attributes: [NSAttributedStringKey: Any] = [:]
        
        var parsedFontSize: CGFloat
        if let fontSize = fontSize {
            parsedFontSize = fontSize
        } else {
            parsedFontSize = 16.0
        }
        
        if (bold != nil && bold!) && (italic != nil && italic!) {
            if fontSerif != nil && fontSerif! {
                attributes[NSAttributedStringKey.font] = NSFont(name: "Georgia-BoldItalic", size: parsedFontSize)
            } else if fontFixed != nil && fontFixed! {
                attributes[NSAttributedStringKey.font] = NSFont(name: "Menlo-BoldItalic", size: parsedFontSize)
            } else {
                attributes[NSAttributedStringKey.font] = NSFont.bold(parsedFontSize)
            }
        } else if bold != nil && bold! {
            if fontSerif != nil && fontSerif! {
                attributes[NSAttributedStringKey.font] = NSFont(name: "Georgia-Bold", size: parsedFontSize)
            } else if fontFixed != nil && fontFixed! {
                attributes[NSAttributedStringKey.font] = NSFont(name: "Menlo-Bold", size: parsedFontSize)
            } else {
                attributes[NSAttributedStringKey.font] = NSFont.bold(parsedFontSize)
            }
        } else if italic != nil && italic! {
            if fontSerif != nil && fontSerif! {
                attributes[NSAttributedStringKey.font] = NSFont(name: "Georgia-Italic", size: parsedFontSize)
            } else if fontFixed != nil && fontFixed! {
                attributes[NSAttributedStringKey.font] = NSFont(name: "Menlo-Italic", size: parsedFontSize)
            } else {
                attributes[NSAttributedStringKey.font] = NSFont.italic(parsedFontSize)
            }
        } else {
            if fontSerif != nil && fontSerif! {
                attributes[NSAttributedStringKey.font] = NSFont(name: "Georgia", size: parsedFontSize)
            } else if fontFixed != nil && fontFixed! {
                attributes[NSAttributedStringKey.font] = NSFont(name: "Menlo", size: parsedFontSize)
            } else {
                attributes[NSAttributedStringKey.font] = NSFont.normal(parsedFontSize)
            }
        }
        
        if strikethrough != nil && strikethrough! {
            attributes[NSAttributedStringKey.strikethroughStyle] = (NSUnderlineStyle.styleSingle.rawValue | NSUnderlineStyle.patternSolid.rawValue) as NSNumber
        }
        
        if underline != nil && underline! {
            attributes[NSAttributedStringKey.underlineStyle] = NSUnderlineStyle.styleSingle.rawValue as NSNumber
        }
        
        if let color = color {
            attributes[NSAttributedStringKey.foregroundColor] = color
        } else {
            attributes[NSAttributedStringKey.foregroundColor] = theme.colors.text
        }
        
        
        if let link = link {
            attributes[NSAttributedStringKey.link] = link
        }
        
        if let lineSpacingFactor = lineSpacingFactor {
            attributes[.instantPageLineSpacingFactor] = lineSpacingFactor as NSNumber
        }
        
        return attributes
    }
}
