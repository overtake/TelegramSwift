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
    
}
