//
//  Color.swift
//  TGUIKit
//
//  Created by keepcoder on 06/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Foundation
import AppKit
import ColorPalette

public class DashLayer : SimpleLayer {
    public override init() {
        super.init()
    }
    
    public override init(layer: Any) {
        super.init(layer: layer)
    }
    
    public var colors: PeerNameColors.Colors? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    public override func draw(in ctx: CGContext) {
        
        guard let colors = self.colors else {
            return
        }
        
        let radius: CGFloat = 3.0
        let lineWidth: CGFloat = 3.0

        
        let tintColor = colors.main
        let secondaryTintColor = colors.secondary
        let tertiaryTintColor = colors.tertiary
        
        
        ctx.setFillColor(tintColor.cgColor)
    
        let lineFrame = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: lineWidth, height: frame.height))
        ctx.move(to: CGPoint(x: lineFrame.minX, y: lineFrame.minY + radius))
        ctx.addArc(tangent1End: CGPoint(x: lineFrame.minX, y: lineFrame.minY), tangent2End: CGPoint(x: lineFrame.minX + radius, y: lineFrame.minY), radius: radius)
        ctx.addLine(to: CGPoint(x: lineFrame.minX + radius, y: lineFrame.maxY))
        ctx.addArc(tangent1End: CGPoint(x: lineFrame.minX, y: lineFrame.maxY), tangent2End: CGPoint(x: lineFrame.minX, y: lineFrame.maxY - radius), radius: radius)
        ctx.closePath()
        ctx.clip()
        
        if let secondaryTintColor = secondaryTintColor {
            let isMonochrome = secondaryTintColor.alpha == 0.2

            do {
                ctx.saveGState()
                
                let dashHeight: CGFloat = tertiaryTintColor != nil ? 6.0 : 9.0
                let dashOffset: CGFloat
                if let _ = tertiaryTintColor {
                    dashOffset = isMonochrome ? -2.0 : 0.0
                } else {
                    dashOffset = isMonochrome ? -4.0 : 5.0
                }
            
                if isMonochrome {
                    ctx.setFillColor(tintColor.withMultipliedAlpha(0.2).cgColor)
                    ctx.fill(lineFrame)
                    ctx.setFillColor(tintColor.cgColor)
                } else {
                    ctx.setFillColor(tintColor.cgColor)
                    ctx.fill(lineFrame)
                    ctx.setFillColor(secondaryTintColor.cgColor)
                }
                
                func drawDashes() {
                    ctx.translateBy(x: 0, y: 0 + dashOffset)
                    
                    var offset = 0.0
                    while offset < frame.height {
                        ctx.move(to: CGPoint(x: 0.0, y: 3.0))
                        ctx.addLine(to: CGPoint(x: lineWidth, y: 0.0))
                        ctx.addLine(to: CGPoint(x: lineWidth, y: dashHeight))
                        ctx.addLine(to: CGPoint(x: 0.0, y: dashHeight + 3.0))
                        ctx.closePath()
                        ctx.fillPath()
                        
                        ctx.translateBy(x: 0.0, y: 18.0)
                        offset += 18.0
                    }
                }
                
                drawDashes()
                ctx.restoreGState()
                
                if let tertiaryTintColor = tertiaryTintColor{
                    ctx.saveGState()
                    ctx.translateBy(x: 0.0, y: dashHeight)
                    if isMonochrome {
                        ctx.setFillColor(tintColor.withAlphaComponent(0.4).cgColor)
                    } else {
                        ctx.setFillColor(tertiaryTintColor.cgColor)
                    }
                    drawDashes()
                    ctx.restoreGState()
                }
            }
        } else {
            ctx.setFillColor(tintColor.cgColor)
            ctx.fill(lineFrame)
        }
        
        ctx.resetClip()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


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


