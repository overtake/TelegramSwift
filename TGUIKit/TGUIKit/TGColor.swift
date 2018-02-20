//
//  Color.swift
//  TGUIKit
//
//  Created by keepcoder on 06/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Foundation

public extension NSColor {
    
    public static func colorFromRGB(rgbValue:UInt32) ->NSColor {
         return NSColor.init(deviceRed: ((CGFloat)((rgbValue & 0xFF0000) >> 16))/255.0, green: ((CGFloat)((rgbValue & 0xFF00) >> 8))/255.0, blue: ((CGFloat)(rgbValue & 0xFF))/255.0, alpha: 1.0)
    }
    
    public static func colorFromRGB(rgbValue:UInt32, alpha:CGFloat) ->NSColor {
        return NSColor.init(deviceRed: ((CGFloat)((rgbValue & 0xFF0000) >> 16))/255.0, green: ((CGFloat)((rgbValue & 0xFF00) >> 8))/255.0, blue: ((CGFloat)(rgbValue & 0xFF))/255.0, alpha:alpha)
    }
    
    
    public static var link:NSColor {
        return .colorFromRGB(rgbValue: 0x2481cc)
    }
    
    public static var blueUI:NSColor {
        return .colorFromRGB(rgbValue: 0x2481cc)
    }
    
    public static var redUI:NSColor {
        return colorFromRGB(rgbValue: 0xff3b30)
    }
    
    public static var greenUI:NSColor {
        return colorFromRGB(rgbValue: 0x63DA6E)
    }
    
    public static var blackTransparent:NSColor {
        return colorFromRGB(rgbValue: 0x000000, alpha: 0.6)
    }
    
    public static var grayTransparent:NSColor {
        return colorFromRGB(rgbValue: 0xf4f4f4, alpha: 0.4)
    }
    
    public static var grayUI:NSColor {
        return colorFromRGB(rgbValue: 0xFaFaFa, alpha: 1.0)
    }
    
    public static var darkGrayText:NSColor {
        return NSColor(0x333333)
    }
    
    public static var text:NSColor {
        return NSColor.black
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
    
    public static var blueFill:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0x4ba3e2)
        }
    }
    
    
    public static var border:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0xeaeaea)
        }
    }
    
    
    
    public static var grayBackground:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0xf4f4f4)
        }
    }
    
    public static var grayForeground:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0xe4e4e4)
        }
    }
    
    
    
    public static var grayIcon:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0x9e9e9e)
        }
    }
    
    
    public static var blueIcon:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0x0f8fe4)
        }
    }
    
    public static var badgeMuted:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0xd7d7d7)
        }
    }
    
    public static var badge:NSColor  {
        get {
            return .blueFill
        }
    }
    
    public static var grayText:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0x999999)
        }
    }
}

public extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: 1.0)
    }
    
    convenience init(rgb: UInt32, alpha: CGFloat) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: alpha)
    }
    
    convenience init(argb: UInt32) {
        self.init(red: CGFloat((argb >> 16) & 0xff) / 255.0, green: CGFloat((argb >> 8) & 0xff) / 255.0, blue: CGFloat(argb & 0xff) / 255.0, alpha: CGFloat((argb >> 24) & 0xff) / 255.0)
    }
    
    var argb: UInt32 {
        
        let color = self.usingColorSpaceName(NSColorSpaceName.deviceRGB)!
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return (UInt32(alpha * 255.0) << 24) | (UInt32(red * 255.0) << 16) | (UInt32(green * 255.0) << 8) | (UInt32(blue * 255.0))
    }
    
    var rgb: UInt32 {
        
        let color = self.usingColorSpaceName(NSColorSpaceName.deviceRGB)
        if let color = color {
            let red: CGFloat = color.redComponent
            let green: CGFloat = color.greenComponent
            let blue: CGFloat = color.blueComponent
            
            return (UInt32(red * 255.0) << 16) | (UInt32(green * 255.0) << 8) | (UInt32(blue * 255.0))
        }
        return 0x000000
    }
}

public extension CGFloat {
    
    
    public static var cornerRadius:CGFloat {
        return 5
    }
    
    public static var borderSize:CGFloat  {
        get {
            return 1
        }
    }
    
   
    
}


