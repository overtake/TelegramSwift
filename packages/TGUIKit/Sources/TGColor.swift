//
//  Color.swift
//  TGUIKit
//
//  Created by keepcoder on 06/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Foundation
import AppKit

public extension NSColor {
    
    static func ==(lhs: NSColor, rhs: NSColor) -> Bool {
        return lhs.argb == rhs.argb
    }
    
    static func colorFromRGB(rgbValue:UInt32) ->NSColor {
         return NSColor.init(srgbRed: ((CGFloat)((rgbValue & 0xFF0000) >> 16))/255.0, green: ((CGFloat)((rgbValue & 0xFF00) >> 8))/255.0, blue: ((CGFloat)(rgbValue & 0xFF))/255.0, alpha: 1.0)
    }
    
    static func colorFromRGB(rgbValue:UInt32, alpha:CGFloat) ->NSColor {
        return NSColor.init(srgbRed: ((CGFloat)((rgbValue & 0xFF0000) >> 16))/255.0, green: ((CGFloat)((rgbValue & 0xFF00) >> 8))/255.0, blue: ((CGFloat)(rgbValue & 0xFF))/255.0, alpha:alpha)
    }
    
    var highlighted: NSColor {
        return self.withAlphaComponent(0.8)
    }
    
    var alpha: CGFloat {
        var alpha: CGFloat = 0
        self.getHue(nil, saturation: nil, brightness: nil, alpha: &alpha)
        return alpha
    }
    
    var hsv: (CGFloat, CGFloat, CGFloat) {
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var value: CGFloat = 0.0
        self.getHue(&hue, saturation: &saturation, brightness: &value, alpha: nil)
        return (hue, saturation, value)
    }
    
    func isTooCloseHSV(to color: NSColor) -> Bool {
        let hsv1 = abs(self.hsv.0) + abs(self.hsv.1) + abs(self.hsv.2)
        let hsv2 = abs(color.hsv.0) + abs(color.hsv.1) + abs(color.hsv.2)

        let dif = abs(hsv1 - hsv2)
        return dif < 0.005
    }

    var lightness: CGFloat {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        self.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }
    
    var hsb: (CGFloat, CGFloat, CGFloat) {
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        return (hue, saturation, brightness)
    }

    
    var brightnessAdjustedColor: NSColor{
        if lightness > 0.7 {
            return NSColor(0x000000)
        } else {
            return NSColor(0xffffff)
        }
        var components = self.cgColor.components
        let alpha = components?.last
        components?.removeLast()
        let color = CGFloat(1-(components?.max())! >= 0.5 ? 1.0 : 0.0)
        return NSColor(red: color, green: color, blue: color, alpha: alpha!)
    }
    
    func withMultipliedBrightnessBy(_ factor: CGFloat) -> NSColor {
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return NSColor(hue: hue, saturation: saturation, brightness: max(0.0, min(1.0, brightness * factor)), alpha: alpha)
    }
    
    func withMultiplied(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) -> NSColor {
        var hueValue: CGFloat = 0.0
        var saturationValue: CGFloat = 0.0
        var brightnessValue: CGFloat = 0.0
        var alphaValue: CGFloat = 0.0
        self.getHue(&hueValue, saturation: &saturationValue, brightness: &brightnessValue, alpha: &alphaValue)
        
        return NSColor(hue: max(0.0, min(1.0, hueValue * hue)), saturation: max(0.0, min(1.0, saturationValue * saturation)), brightness: max(0.0, min(1.0, brightnessValue * brightness)), alpha: alphaValue)
    }
    
    func withMultipliedAlpha(_ alpha: CGFloat) -> NSColor {
        var r1: CGFloat = 0.0
        var g1: CGFloat = 0.0
        var b1: CGFloat = 0.0
        var a1: CGFloat = 0.0
        self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        return NSColor(red: r1, green: g1, blue: b1, alpha: max(0.0, min(1.0, a1 * alpha)))
    }
    
    func mixedWith(_ other: NSColor, alpha: CGFloat) -> NSColor {
        
            if let blended = self.blended(withFraction: alpha, of: other) {
                return blended
            }
        
            let alpha = min(1.0, max(0.0, alpha))
            let oneMinusAlpha = 1.0 - alpha
            
            var r1: CGFloat = 0.0
            var r2: CGFloat = 0.0
            var g1: CGFloat = 0.0
            var g2: CGFloat = 0.0
            var b1: CGFloat = 0.0
            var b2: CGFloat = 0.0
            var a1: CGFloat = 0.0
            var a2: CGFloat = 0.0
            self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            let r = r1 * oneMinusAlpha + r2 * alpha
            let g = g1 * oneMinusAlpha + g2 * alpha
            let b = b1 * oneMinusAlpha + b2 * alpha
            let a = a1 * oneMinusAlpha + a2 * alpha
            return NSColor(red: r, green: g, blue: b, alpha: a)
        }



    func interpolateTo(_ color: NSColor, fraction: CGFloat) -> NSColor? {
           let f = min(max(0, fraction), 1)

           var r1: CGFloat = 0.0
           var r2: CGFloat = 0.0
           var g1: CGFloat = 0.0
           var g2: CGFloat = 0.0
           var b1: CGFloat = 0.0
           var b2: CGFloat = 0.0
           var a1: CGFloat = 0.0
           var a2: CGFloat = 0.0
           self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
           color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
           let r: CGFloat = CGFloat(r1 + (r2 - r1) * f)
           let g: CGFloat = CGFloat(g1 + (g2 - g1) * f)
           let b: CGFloat = CGFloat(b1 + (b2 - b1) * f)
           let a: CGFloat = CGFloat(a1 + (a2 - a1) * f)
           return NSColor(red: r, green: g, blue: b, alpha: a)
       }


    
    static var link:NSColor {
        return .colorFromRGB(rgbValue: 0x2481cc)
    }
    
    static var accent:NSColor {
        return .colorFromRGB(rgbValue: 0x2481cc)
    }
    
    static var redUI:NSColor {
        return colorFromRGB(rgbValue: 0xff3b30)
    }
    
    static var greenUI:NSColor {
        return colorFromRGB(rgbValue: 0x63DA6E)
    }
    
    static var blackTransparent:NSColor {
        return colorFromRGB(rgbValue: 0x000000, alpha: 0.6)
    }
    
    static var grayTransparent:NSColor {
        return colorFromRGB(rgbValue: 0xf4f4f4, alpha: 0.4)
    }
    
    static var grayUI:NSColor {
        return colorFromRGB(rgbValue: 0xFaFaFa, alpha: 1.0)
    }
    
    static var darkGrayText:NSColor {
        return NSColor(0x333333)
    }
    
    static var text:NSColor {
        return NSColor.black
    }
    
    
    static var blueText:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0x4ba3e2)
        }
    }
    
    static var accentSelect:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0x4c91c7)
        }
    }
    
    
    func lighter(amount : CGFloat = 0.15) -> NSColor {
        return hueColorWithBrightnessAmount(1 + amount)
    }
    
    func darker(amount : CGFloat = 0.15) -> NSColor {
        return hueColorWithBrightnessAmount(1 - amount)
    }
    
    private func hueColorWithBrightnessAmount(_ amount: CGFloat) -> NSColor {
        var hue         : CGFloat = 0
        var saturation  : CGFloat = 0
        var brightness  : CGFloat = 0
        var alpha       : CGFloat = 0
        
        let color = self.usingColorSpaceName(NSColorSpaceName.deviceRGB)!
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return NSColor( hue: hue,
                        saturation: saturation,
                        brightness: brightness * amount,
                        alpha: alpha )
    }
    
    
    static var selectText:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0xeaeaea, alpha:1.0)
        }
    }
    
    static var random:NSColor  {
        get {
            return colorFromRGB(rgbValue: arc4random_uniform(16000000))
        }
    }
    
    static var blueFill:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0x4ba3e2)
        }
    }
    
    
    static var border:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0xeaeaea)
        }
    }
    
    
    
    static var grayBackground:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0xf4f4f4)
        }
    }
    
    static var grayForeground:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0xe4e4e4)
        }
    }
    
    
    
    static var grayIcon:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0x9e9e9e)
        }
    }
    
    
    static var accentIcon:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0x0f8fe4)
        }
    }
    
    static var badgeMuted:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0xd7d7d7)
        }
    }
    
    static var badge:NSColor  {
        get {
            return .blueFill
        }
    }
    
    static var grayText:NSColor  {
        get {
            return colorFromRGB(rgbValue: 0x999999)
        }
    }
}

public extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(deviceRed: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: 1.0)
    }
    
    convenience init(rgb: UInt32, alpha: CGFloat) {
        self.init(deviceRed: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: alpha)
    }
    
    convenience init(argb: UInt32) {
        self.init(deviceRed: CGFloat((argb >> 16) & 0xff) / 255.0, green: CGFloat((argb >> 8) & 0xff) / 255.0, blue: CGFloat(argb & 0xff) / 255.0, alpha: CGFloat((argb >> 24) & 0xff) / 255.0)
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


