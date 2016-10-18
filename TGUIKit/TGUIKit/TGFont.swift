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
        return NSFont.systemFont(ofSize: size, weight: NSFontWeightRegular)
    } else {
        return NSFont.init(name: "HelveticaNeue", size: size)!
    }
}

public func systemMediumFont(_ size:CGFloat) ->NSFont {
    
    if #available(OSX 10.11, *) {
        return NSFont.systemFont(ofSize: size, weight: NSFontWeightSemibold)
    } else {
        return NSFont.init(name: "HelveticaNeue-Medium", size: size)!
    }
    
}

public func systemBoldFont(_ size:CGFloat) ->NSFont {
    
    if #available(OSX 10.11, *) {
        return NSFont.systemFont(ofSize: size, weight: NSFontWeightBold)
    } else {
        return NSFont.init(name: "HelveticaNeue-Bold", size: size)!
    }
}

public extension NSFont {
    public static func normal(_ size:FontSize) ->NSFont {
        
        if #available(OSX 10.11, *) {
            return NSFont.systemFont(ofSize: convert(from:size), weight: NSFontWeightRegular)
        } else {
            return NSFont.init(name: "HelveticaNeue", size: convert(from:size))!
        }
    }
    
    public static func medium(_ size:FontSize) ->NSFont {
        
        if #available(OSX 10.11, *) {
            return NSFont.systemFont(ofSize: convert(from:size), weight: NSFontWeightSemibold)
        } else {
            return NSFont.init(name: "HelveticaNeue-Medium", size: convert(from:size))!
        }
        
    }
    
    public static func bold(_ size:FontSize) ->NSFont {
        
        if #available(OSX 10.11, *) {
            return NSFont.systemFont(ofSize: convert(from:size), weight: NSFontWeightBold)
        } else {
            return NSFont(name: "HelveticaNeue-Bold", size: convert(from:size))!
        }
    }
}

public enum FontSize {
    case short
    case text
    case title
    case header
    case huge
    case custom(CGFloat)
}

fileprivate func convert(from s:FontSize) -> CGFloat {
    switch s {
    case .short:
        return 12.0
    case .text:
        return 13.0
    case .title:
        return 14.0
    case .header:
        return 15.0
    case .huge:
        return 18.0
    case let .custom(size):
        return size
    }
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
