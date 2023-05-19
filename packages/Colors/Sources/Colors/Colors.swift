
import Foundation
import AppKit
import Strings

public extension NSColor {
    static func average(of colors: [NSColor]) -> NSColor {
           var sr: CGFloat = 0.0
           var sg: CGFloat = 0.0
           var sb: CGFloat = 0.0
           var sa: CGFloat = 0.0

           for color in colors {
               var r: CGFloat = 0.0
               var g: CGFloat = 0.0
               var b: CGFloat = 0.0
               var a: CGFloat = 0.0
               color.getRed(&r, green: &g, blue: &b, alpha: &a)
               sr += r
               sg += g
               sb += b
               sa += a
           }

           return NSColor(red: sr / CGFloat(colors.count), green: sg / CGFloat(colors.count), blue: sb / CGFloat(colors.count), alpha: sa / CGFloat(colors.count))
       }

    
    convenience init?(hexString: String) {
        let scanner = Scanner(string: hexString.prefix(7))
        if hexString.hasPrefix("#") {
            scanner.scanLocation = 1
        }
        var num: UInt32 = 0
        var alpha: CGFloat = 1.0
        let checkSet = CharacterSet(charactersIn: "#0987654321abcdef")
        for char in hexString.lowercased().unicodeScalars {
            if !checkSet.contains(char) {
                return nil
            }
        }
        if scanner.scanHexInt32(&num), hexString.length >= 7 && hexString.length <= 9 {
            if hexString.length == 9 {
                let scanner = Scanner(string: hexString)
                scanner.scanLocation = 7
                var intAlpha: UInt32 = 0
                scanner.scanHexInt32(&intAlpha)
                alpha = CGFloat(intAlpha) / 255
            }
            self.init(num, alpha)
        } else {
            return nil
        }
    }
    
    
    convenience init(_ rgbValue:UInt32, _ alpha:CGFloat = 1.0) {
        let r: CGFloat = ((CGFloat)((rgbValue & 0xFF0000) >> 16))
        let g: CGFloat = ((CGFloat)((rgbValue & 0xFF00) >> 8))
        let b: CGFloat = ((CGFloat)(rgbValue & 0xFF))
        self.init(srgbRed: r/255.0, green: g/255.0, blue: b/255.0, alpha: alpha)
       // self.init(deviceRed: r/255.0, green: g/255.0, blue: b/255.0, alpha: alpha)
    }
    
    var hexString: String {
        // Get the red, green, and blue components of the color
        var r :CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        
        
        let color = self.usingColorSpaceName(NSColorSpaceName.deviceRGB)!

        
        var rInt, gInt, bInt, aInt: Int
        var rHex, gHex, bHex: String
        
        var hexColor: String
        
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // println("R: \(r) G: \(g) B:\(b) A:\(a)")
        
        // Convert the components to numbers (unsigned decimal integer) between 0 and 255
        rInt = Int(round(r * 255.0))
        gInt = Int(round(g * 255.0))
        bInt = Int(round(b * 255.0))
        
        // Convert the numbers to hex strings
        rHex = rInt == 0 ? "00" : NSString(format:"%2X", rInt) as String
        gHex = gInt == 0 ? "00" : NSString(format:"%2X", gInt) as String
        bHex = bInt == 0 ? "00" : NSString(format:"%2X", bInt) as String
        
        rHex = rHex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        gHex = gHex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        bHex = bHex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        if rHex.length == 1 {
            rHex = "0\(rHex)"
        }
        if gHex.length == 1 {
            gHex = "0\(gHex)"
        }
        if bHex.length == 1 {
            bHex = "0\(bHex)"
        }
        
        hexColor = rHex + gHex + bHex
        if a < 1 {
            return "#" + hexColor + ":\(String(format: "%.2f", Double(a * 100 / 100)))"
        } else {
            return "#" + hexColor
        }
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


