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
    public static func normal(_ size:FontSize) ->NSFont {
        
        if #available(OSX 10.11, *) {
            return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.regular)
        } else {
            return NSFont(name: "HelveticaNeue", size: size)!
        }
    }
    
    public static func italic(_ size: FontSize) -> NSFont {
        return NSFontManager.shared.convert(.normal(size), toHaveTrait: .italicFontMask)
    }
    
    public static func avatar(_ size: FontSize) -> NSFont {
        
        if let font = NSFont(name: ".SFCompactRounded-Semibold", size: size) {
            return font
        } else {
            return .medium(size)
        }
    }
    
    public static func medium(_ size:FontSize) ->NSFont {
        
        if #available(OSX 10.11, *) {
            return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.medium)
        } else {
            return NSFont(name: "HelveticaNeue-Medium", size: size)!
        }
        
    }
    
    public static func bold(_ size:FontSize) ->NSFont {
        
        if #available(OSX 10.11, *) {
            return NSFont.systemFont(ofSize: size, weight: NSFont.Weight.bold)
        } else {
            return NSFont(name: "HelveticaNeue-Bold", size: size)!
        }
    }
    
    public static func code(_ size:FontSize) ->NSFont {
        return NSFont(name: "Menlo-Regular", size: size) ?? NSFont.systemFont(ofSize: 17.0)
    }
}

public typealias FontSize = CGFloat

public extension FontSize {
    public static let small: CGFloat = 11.0
    public static let short: CGFloat = 12.0
    public static let text: CGFloat = 13.0
    public static let title: CGFloat = 14.0
    public static let header: CGFloat = 15.0
    public static let huge: CGFloat = 18.0
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
