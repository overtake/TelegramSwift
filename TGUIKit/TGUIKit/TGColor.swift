//
//  Color.swift
//  TGUIKit
//
//  Created by keepcoder on 06/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Foundation

public struct TGColor {
    public static func colorFromRGB(rgbValue:UInt32) ->NSColor {
        
        return NSColor.init(deviceRed: ((CGFloat)((rgbValue & 0xFF0000) >> 16))/255.0, green: ((CGFloat)((rgbValue & 0xFF00) >> 8))/255.0, blue: ((CGFloat)(rgbValue & 0xFF))/255.0, alpha: 1.0)
        
    }
    
    public static func colorFromRGB(rgbValue:UInt32, alpha:CGFloat) ->NSColor {
        
        return NSColor.init(deviceRed: ((CGFloat)((rgbValue & 0xFF0000) >> 16))/255.0, green: ((CGFloat)((rgbValue & 0xFF00) >> 8))/255.0, blue: ((CGFloat)(rgbValue & 0xFF))/255.0, alpha:alpha)
        
    }
    
    public static var textColor:NSColor  {
        get {
            return NSColor.textColor
        }
    }
    
    public static var white:NSColor  {
        get {
            return NSColor.white
        }
    }
    
    public static var link:NSColor {
        return TGColor.colorFromRGB(rgbValue: 0x2481cc)
    }
    
    public static var blackTransparent:NSColor {
        return colorFromRGB(rgbValue: 0x000000, alpha: 0.6)
    }
    
    public static var cornerRadius:CGFloat {
        return 5
    }
    
    public static var blueText:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0x4ba3e2)
        }
    }
    
    
    
    public static var blueSelect:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0x4c91c7)
        }
    }
    
    public static var shadow:NSColor  {
        get {
            return .blue //colorFromRGB(rgbValue: 0x000000)
        }
    }
    
    public static var selectText:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0xeaeaea, alpha:1.0)
        }
    }
    
    public static var random:NSColor  {
        get {
            return colorFromRGB(rgbValue: arc4random_uniform(16000000))
        }
    }
    
    public static var blue:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0x4ba3e2)
        }
    }
    
    
    public static var clear:NSColor  {
        get {
            return NSColor.clear
        }
    }
    
    public static var border:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0xeaeaea)
        }
    }
    
    public static var borderSize:CGFloat  {
        get {
            return 1
        }
    }
    
    public static var grayBackground:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0xf4f4f4)
        }
    }
    
    public static var grayIcon:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0x9e9e9e)
        }
    }

    
    public static var hoverIcon:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0x0f8fe4)
        }
    }
    
    public static var grayText:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0x999999)
        }
    }
    
}


