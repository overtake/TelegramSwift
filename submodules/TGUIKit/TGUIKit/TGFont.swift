//
//  TGFont.swift
//  TGUIKit
//
//  Created by keepcoder on 07/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa


public func systemFont(_ size:CGFloat) ->NSFont {
    
    if #available(OSX 10.11, *) {
        return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.regular)
    } else {
        return NSFont.init(name: "HelveticaNeue", size: size)!
    }
}

public func systemMediumFont(_ size:CGFloat) ->NSFont {
    
    if #available(OSX 10.11, *) {
        return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.semibold)
    } else {
        return NSFont.init(name: "HelveticaNeue-Medium", size: size)!
    }
    
}

public func systemBoldFont(_ size:CGFloat) ->NSFont {
    
    if #available(OSX 10.11, *) {
        return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.bold)
    } else {
        return NSFont.init(name: "HelveticaNeue-Bold", size: size)!
    }
}

public extension NSFont {
    static func normal(_ size:FontSize) ->NSFont {
        
        if #available(OSX 10.11, *) {
            return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.regular)
        } else {
            return NSFont(name: "HelveticaNeue", size: size)!
        }
    }
    
    static func light(_ size:FontSize) ->NSFont {
        
        if #available(OSX 10.11, *) {
            return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.light)
        } else {
            return NSFont(name: "HelveticaNeue", size: size)!
        }
    }
    static func ultraLight(_ size:FontSize) ->NSFont {
        
        if #available(OSX 10.11, *) {
            return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.ultraLight)
        } else {
            return NSFont(name: "HelveticaNeue", size: size)!
        }
    }
    
    static func italic(_ size: FontSize) -> NSFont {
        return NSFontManager.shared.convert(.normal(size), toHaveTrait: .italicFontMask)
    }
    
    static func boldItalic(_ size: FontSize) -> NSFont {
        return NSFontManager.shared.convert(.normal(size), toHaveTrait: [.italicFontMask, .boldFontMask])
    }
    
    static func avatar(_ size: FontSize) -> NSFont {
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
    
    static func medium(_ size:FontSize) ->NSFont {
        
        if #available(OSX 10.11, *) {
            return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.semibold)
        } else {
            return NSFont(name: "HelveticaNeue-Medium", size: size)!
        }
        
    }
    
    static func bold(_ size:FontSize) ->NSFont {
        
        if #available(OSX 10.11, *) {
            return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.bold)
        } else {
            return NSFont(name: "HelveticaNeue-Bold", size: size)!
        }
    }
    
    static func code(_ size:FontSize) ->NSFont {
        return NSFont(name: "Menlo-Regular", size: size) ?? NSFont.systemFont(ofSize: size)
    }
    static func blockchain(_ size: FontSize)->NSFont {
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
