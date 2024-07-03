//
//  TGFont.swift
//  TGUIKit
//
//  Created by keepcoder on 07/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
private var caches: [FontCacheKey: NSFont] = [:]


public struct FontCacheKey : Hashable {
    enum Font : Int32 {
        case normal
        case medium
        case bold
        case italic
        case light
        case ultralight
        case bolditalic
        case italicmonospace
        case semiboldItalicMonospace
        case semiboldMonospace
        case avatar
        case semibold
        case digitalRound
        case code
        case menlo
        case blockchain
        case roundTimer
        case normalMonospaced
    }
    let type: Font
    let size: CGFloat
    
    public static func initializeCache() {
        let all:[Font] = [.normal, .medium, .bold, .italic, .light, .ultralight, .bolditalic, .avatar, .semibold, .digitalRound, .code, .menlo, .blockchain, .italicmonospace, .semiboldItalicMonospace, .semiboldMonospace, .roundTimer, .normalMonospaced]
        for i in 10 ..< 20 {
            let fontSize = CGFloat(i)
            for type in all {
                switch type {
                case .normal:
                    caches[.init(type: type, size: fontSize)] = .normal(fontSize)
                case .medium:
                    caches[.init(type: type, size: fontSize)] = .medium(fontSize)
                case .bold:
                    caches[.init(type: type, size: fontSize)] = .bold(fontSize)
                case .italic:
                    caches[.init(type: type, size: fontSize)] = .italic(fontSize)
                case .light:
                    caches[.init(type: type, size: fontSize)] = .light(fontSize)
                case .ultralight:
                    caches[.init(type: type, size: fontSize)] = .ultraLight(fontSize)
                case .bolditalic:
                    caches[.init(type: type, size: fontSize)] = .boldItalic(fontSize)
                case .avatar:
                    caches[.init(type: type, size: fontSize)] = .avatar(fontSize)
                case .semibold:
                    caches[.init(type: type, size: fontSize)] = .semibold(fontSize)
                case .digitalRound:
                    caches[.init(type: type, size: fontSize)] = .digitalRound(fontSize)
                case .code:
                    caches[.init(type: type, size: fontSize)] = .code(fontSize)
                case .menlo:
                    caches[.init(type: type, size: fontSize)] = .menlo(fontSize)
                case .blockchain:
                    caches[.init(type: type, size: fontSize)] = .blockchain(fontSize)
                case .italicmonospace:
                    caches[.init(type: type, size: fontSize)] = .italicMonospace(fontSize)
                case .semiboldItalicMonospace:
                    caches[.init(type: type, size: fontSize)] = .semiboldItalicMonospace(fontSize)
                case .semiboldMonospace:
                    caches[.init(type: type, size: fontSize)] = .semiboldMonospace(fontSize)
                case .roundTimer:
                    caches[.init(type: type, size: fontSize)] = .roundTimer(fontSize)
                case .normalMonospaced:
                    caches[.init(type: type, size: fontSize)] = .normalMonospaced(fontSize)
                }
            }
        }
    }
}


public func systemFont(_ size:CGFloat) ->NSFont {
    if let font = caches[.init(type: .normal, size: size)] {
        return font
    }
    return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.regular)
}

public func systemMediumFont(_ size:CGFloat) ->NSFont {
    if let font = caches[.init(type: .medium, size: size)] {
        return font
    }
    return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.semibold)
}

public func systemBoldFont(_ size:CGFloat) ->NSFont {
    if let font = caches[.init(type: .bold, size: size)] {
        return font
    }
    return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.bold)
}

public extension NSFont {
    
    static func normal(_ size:FontSize) ->NSFont {
        if let font = caches[.init(type: .normal, size: size)] {
            return font
        }
        return NSFont.systemFont(ofSize: size)
    }
    
    static func normalMonospaced(_ size:FontSize) ->NSFont {
        if let font = caches[.init(type: .normal, size: size)] {
            return font
        }
        if #available(macOS 10.15, *) {
            if let descriptor =  NSFont.systemFont(ofSize: size).fontDescriptor.withDesign(.monospaced) {
                if let font = NSFont(descriptor: descriptor, size: size) {
                    return font
                }
            }
        }
        return .normal(size)
    }
    
    static func light(_ size:FontSize) ->NSFont {
        if let font = caches[.init(type: .light, size: size)] {
            return font
        }
        return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.light)
    }
    static func ultraLight(_ size:FontSize) ->NSFont {
        if let font = caches[.init(type: .ultralight, size: size)] {
            return font
        }
        return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.ultraLight)
    }
    
    static func italic(_ size: FontSize) -> NSFont {
        if let font = caches[.init(type: .italic, size: size)] {
            return font
        }
        return NSFontManager.shared.convert(.normal(size), toHaveTrait: .italicFontMask)
    }
    
    static func boldItalic(_ size: FontSize) -> NSFont {
        if let font = caches[.init(type: .bolditalic, size: size)] {
            return font
        }
        return NSFontManager.shared.convert(.medium(size), toHaveTrait: [.italicFontMask])
    }
    static func italicMonospace(_ size: FontSize) -> NSFont {
        if let font = caches[.init(type: .italicmonospace, size: size)] {
            return font
        }
        if #available(macOS 10.15, *) {
            return NSFontManager.shared.convert(.monospacedSystemFont(ofSize: size, weight: .regular), toHaveTrait: [.italicFontMask])
        } else {
            return NSFont(name: "Menlo-Italic", size: size) ?? .normal(size)
        }
    }
    static func semiboldItalicMonospace(_ size: FontSize) -> NSFont {
        if let font = caches[.init(type: .semiboldItalicMonospace, size: size)] {
            return font
        }
        if #available(macOS 10.15, *) {
            return NSFontManager.shared.convert(.monospacedSystemFont(ofSize: size, weight: .semibold), toHaveTrait: [.italicFontMask])
        } else {
            return NSFont(name: "Menlo-BoldItalic", size: size) ?? .normal(size)
        }
    }
    static func semiboldMonospace(_ size: FontSize) -> NSFont {
        if let font = caches[.init(type: .semiboldMonospace, size: size)] {
            return font
        }
        if #available(macOS 10.15, *) {
            return monospacedSystemFont(ofSize: size, weight: .semibold)
        } else {
            return NSFont(name: "Menlo-Bold", size: size) ?? .normal(size)
        }
    }
    
    
    static func avatar(_ size: FontSize) -> NSFont {
        if let font = caches[.init(type: .avatar, size: size)] {
            return font
        }
        if #available(OSX 10.15, *) {
            if let descriptor = NSFont.boldSystemFont(ofSize: size).fontDescriptor.withDesign(.rounded), let font = NSFont(descriptor: descriptor, size: size) {
                return font
            } else {
                return .systemFont(ofSize: size, weight: .heavy)
            }
        } else {
           if let font = NSFont(name: ".SFCompactRounded-Semibold", size: size) {
                return font
            } else {
                return .systemFont(ofSize: size, weight: .heavy)
            }
        }
    }
    
    static func roundTimer(_ size: FontSize) -> NSFont {
        if let font = caches[.init(type: .roundTimer, size: size)] {
            return font
        }
        if #available(OSX 10.15, *) {
            if let descriptor = NSFont.systemFont(ofSize: size).fontDescriptor.withDesign(.rounded), let font = NSFont(descriptor: descriptor, size: size) {
                return font
            } else {
                return .systemFont(ofSize: size, weight: .medium)
            }
        } else {
           if let font = NSFont(name: ".SFCompactRounded-Semibold", size: size) {
                return font
            } else {
                return .systemFont(ofSize: size, weight: .medium)
            }
        }
    }
    
    static func medium(_ size:FontSize) ->NSFont {
        if let font = caches[.init(type: .medium, size: size)] {
            return font
        }
        if #available(OSX 10.11, *) {
            return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.medium)
        } else {
            return NSFontManager.shared.convert(.normal(size), toHaveTrait: [.boldFontMask])
        }
        
    }
    static func semibold(_ size:FontSize) ->NSFont {
        if let font = caches[.init(type: .semibold, size: size)] {
            return font
        }
        return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.semibold)
    }
    
    
    
    static func bold(_ size:FontSize) ->NSFont {
        if let font = caches[.init(type: .bold, size: size)] {
            return font
        }
        return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.semibold)
    }
    
    static func digitalRound(_ size: FontSize) -> NSFont {
        if let font = caches[.init(type: .digitalRound, size: size)] {
            return font
        }
        if #available(OSX 10.15, *) {
            if let descriptor = NSFont.monospacedSystemFont(ofSize: size, weight: .bold).fontDescriptor.withDesign(.rounded), let font = NSFont(descriptor: descriptor, size: size) {
                return font
            } else {
                return .systemFont(ofSize: size, weight: .heavy)
            }
        } else {
            return .code(size)
        }
        
        
    }
    
    static func code(_ size:FontSize) ->NSFont {
        if let font = caches[.init(type: .code, size: size)] {
            return font
        }
        if #available(OSX 10.15, *) {
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        } else {
            return NSFont(name: "Menlo-Regular", size: size) ?? NSFont.systemFont(ofSize: size)
        }
    }
    
    static func menlo(_ size:FontSize) ->NSFont {
        if let font = caches[.init(type: .menlo, size: size)] {
            return font
        }
        return NSFont(name: "Menlo-Regular", size: size) ?? NSFont.systemFont(ofSize: size)
    }
    
    static func blockchain(_ size: FontSize)->NSFont {
        if let font = caches[.init(type: .blockchain, size: size)] {
            return font
        }
        return NSFont(name: "PT Mono", size: size) ?? NSFont.systemFont(ofSize: size)
    }
}

public typealias FontSize = CGFloat

public extension FontSize {
    static let small: CGFloat = 11.0
    static let short: CGFloat = 12.0
    static let text: CGFloat = 13.0
    static let title: CGFloat = 14.0
    static let header: CGFloat = 15.0
    static let huge: CGFloat = 18.0
}




public struct TGFont {

    public static var shortSize:CGFloat  {
        return 12
    }
    
    public static var textSize:CGFloat  {
        return 13
    }
    
    public static var headerSize:CGFloat  {
        return 15
    }
    
    public static var titleSize:CGFloat  {
        return 14
    }
    
    public static var hugeSize:CGFloat {
        return 18
    }
    
}
