//
//  WallpaperColorPicker.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 29/01/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

private let shadowImage: CGImage = {
    return generateImage(CGSize(width: 45.0, height: 45.0), opaque: false, scale: System.backingScale, rotatedContext: { size, context in
        context.setBlendMode(.clear)
        context.setFillColor(NSColor.clear.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.normal)
        context.setShadow(offset: CGSize(width: 0.0, height: 1.5), blur: 4.5, color: NSColor(rgb: 0x000000, alpha: 0.5).cgColor)
        context.setFillColor(NSColor(rgb: 0x000000, alpha: 0.5).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: 3.0 + .borderSize, dy: 3.0 + .borderSize))
    })!
}()

private let smallShadowImage: CGImage = {
    return generateImage(CGSize(width: 24.0, height: 24.0), opaque: false, scale: System.backingScale, rotatedContext: { size, context in
        context.setBlendMode(.clear)
        context.setFillColor(NSColor.clear.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.normal)
        context.setShadow(offset: CGSize(width: 0.0, height: 1.5), blur: 4.5, color: NSColor(rgb: 0x000000, alpha: 0.65).cgColor)
        context.setFillColor(NSColor(rgb: 0x000000, alpha: 0.5).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: 3.0 + .borderSize, dy: 3.0 + .borderSize))
    })!
}()

private let pointerImage: CGImage = {
    return generateImage(CGSize(width: 12.0, height: 42.0), opaque: false, scale: System.backingScale, rotatedContext: { size, context in
        context.setBlendMode(.clear)
        context.setFillColor(NSColor.clear.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.normal)
        
        let lineWidth: CGFloat = 1.0
        context.setFillColor(NSColor.black.cgColor)
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        
        let pointerHeight: CGFloat = 6.0
        context.move(to: CGPoint(x: lineWidth / 2.0, y: lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width - lineWidth / 2.0, y: lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width / 2.0, y: lineWidth / 2.0 + pointerHeight))
        context.closePath()
        context.drawPath(using: .fillStroke)
        
        context.move(to: CGPoint(x: lineWidth / 2.0, y: size.height - lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width / 2.0, y: size.height - lineWidth / 2.0 - pointerHeight))
        context.addLine(to: CGPoint(x: size.width - lineWidth / 2.0, y: size.height - lineWidth / 2.0))
        context.closePath()
        context.drawPath(using: .fillStroke)
    })!
}()

private final class HSVParameter: NSObject {
    let hue: CGFloat
    let saturation: CGFloat
    let value: CGFloat
    
    init(hue: CGFloat, saturation: CGFloat, value: CGFloat) {
        self.hue = hue
        self.saturation = saturation
        self.value = value
        super.init()
    }
}

private final class IntensitySliderParameter: NSObject {
    let bordered: Bool
    let min: HSVParameter
    let max: HSVParameter
    
    init(bordered: Bool, min: HSVParameter, max: HSVParameter) {
        self.bordered = bordered
        self.min = min
        self.max = max
        super.init()
    }
}


private final class WallpaperColorHueSaturationView: View {
    var parameters: HSVParameter = HSVParameter(hue: 1.0, saturation: 1.0, value: 1.0) {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    var value: CGFloat = 1.0 {
        didSet {
            parameters = HSVParameter(hue: 1.0, saturation: 1.0, value: self.value)
        }
    }
    
    override init() {
        super.init()        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func draw(_ layer: CALayer, in context: CGContext) {
        
        
        let colorSpace = deviceColorSpace

        let colors = [NSColor(rgb: 0xff0000).cgColor, NSColor(rgb: 0xffff00).cgColor, NSColor(rgb: 0x00ff00).cgColor, NSColor(rgb: 0x00ffff).cgColor, NSColor(rgb: 0x0000ff).cgColor, NSColor(rgb: 0xff00ff).cgColor, NSColor(rgb: 0xff0000).cgColor]
        var locations: [CGFloat] = [0.0, 0.16667, 0.33333, 0.5, 0.66667, 0.83334, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: bounds.width, y: 0.0), options: CGGradientDrawingOptions())
        
        let overlayColors = [NSColor(rgb: 0xffffff, alpha: 0.0).cgColor, NSColor(rgb: 0xffffff).cgColor]
        var overlayLocations: [CGFloat] = [0.0, 1.0]
        let overlayGradient = CGGradient(colorsSpace: colorSpace, colors: overlayColors as CFArray, locations: &overlayLocations)!
        context.drawLinearGradient(overlayGradient, start: CGPoint(), end: CGPoint(x: 0.0, y: bounds.height), options: CGGradientDrawingOptions())
        
        context.setFillColor(NSColor(rgb: 0x000000, alpha: 1.0 - parameters.value).cgColor)
        context.fill(bounds)
    }
}


private final class WallpaperColorBrightnessView: View {
    var hsv: (CGFloat, CGFloat, CGFloat) = (0.0, 1.0, 1.0) {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    var parameters:HSVParameter {
        return HSVParameter(hue: self.hsv.0, saturation: self.hsv.1, value: self.hsv.2)
    }
    

    override func draw(_ layer: CALayer, in context: CGContext) {
        let colorSpace = deviceColorSpace
        
        context.setFillColor(NSColor(white: parameters.value, alpha: 1.0).cgColor)
        context.fill(bounds)
        
        
        
        let path = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2.0, yRadius: bounds.height / 2.0)
        context.addPath(path.cgPath)
        context.setFillColor(NSColor.white.cgColor)
        context.fillPath()
        
        let innerPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.0, dy: 1.0), xRadius: bounds.height / 2.0, yRadius: bounds.height / 2.0)
        context.addPath(innerPath.cgPath)
        context.clip()
        
        let color = NSColor(hue: parameters.hue, saturation: parameters.saturation, brightness: 1.0, alpha: 1.0)
        let colors = [color.cgColor, NSColor.black.cgColor]
        var locations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: bounds.width, y: 0.0), options: CGGradientDrawingOptions())
    }
    
}


private final class WallpaperColorKnobView: View {
    var hsv: (CGFloat, CGFloat, CGFloat) = (0.0, 0.0, 1.0) {
        didSet {
            if self.hsv != oldValue {
                self.setNeedsDisplay()
            }
        }
    }
    
    var parameters: HSVParameter {
        return HSVParameter(hue: self.hsv.0, saturation: self.hsv.1, value: self.hsv.2)
    }
    
    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func draw(_ layer: CALayer, in context: CGContext) {
       // if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(NSColor.clear.cgColor)
            context.fill(bounds)
      //  }
        
        let image = bounds.width > 30.0 ? shadowImage : smallShadowImage
        context.draw(image, in: bounds)
        
        context.setBlendMode(.normal)
        context.setFillColor(NSColor.white.cgColor)
        context.fillEllipse(in: bounds.insetBy(dx: 3.0, dy: 3.0))
        
        let color = NSColor(hue: parameters.hue, saturation: parameters.saturation, brightness: parameters.value, alpha: 1.0)
        context.setFillColor(color.cgColor)
        
        let borderWidth: CGFloat = bounds.width > 30.0 ? 5.0 : 5.0
        context.fillEllipse(in: bounds.insetBy(dx: borderWidth - .borderSize, dy: borderWidth - .borderSize))
    }
}

private enum PickerChangeValue {
    case color
    case brightness
}



final class WallpaperColorPickerView: View {
    private let brightnessView: WallpaperColorBrightnessView
    private let brightnessKnobView: ImageView
    private let colorView: WallpaperColorHueSaturationView

    
    private let colorKnobView: WallpaperColorKnobView
    
    private var pickerValue: PickerChangeValue?
    
    var colorHSV: (CGFloat, CGFloat, CGFloat) = (0.0, 1.0, 1.0)
    var color: NSColor {
        get {
            return NSColor(hue: self.colorHSV.0, saturation: self.colorHSV.1, brightness: self.colorHSV.2, alpha: 1.0)
        }
        set {
            var hue: CGFloat = 0.0
            var saturation: CGFloat = 0.0
            var value: CGFloat = 0.0
            
           
            newValue.getHue(&hue, saturation: &saturation, brightness: &value, alpha: nil)
            let newHSV: (CGFloat, CGFloat, CGFloat) = (hue, saturation, value)
            
            if newHSV != self.colorHSV {
                self.colorHSV = newHSV
                self.update()
            }
        }
    }
    var colorChanged: ((NSColor) -> Void)?
    var colorChangeEnded: ((NSColor) -> Void)?
    

    
    var adjustingPattern: Bool = false {
        didSet {
            let value = self.adjustingPattern
            self.brightnessView.isHidden = value
            self.brightnessKnobView.isHidden = value
            self.needsLayout = true
        }
    }
    
    override init() {
        self.brightnessView = WallpaperColorBrightnessView()
        //self.brightnessView.hitTestSlop = NSEdgeInsetsMake(-16.0, -16.0, -16.0, -16.0)
        self.brightnessKnobView = ImageView()
        self.brightnessKnobView.image = pointerImage
        self.colorView = WallpaperColorHueSaturationView()
      //  self.colorView.hitTestSlop = NSEdgeInsetsMake(-16.0, -16.0, -16.0, -16.0)
        self.colorKnobView = WallpaperColorKnobView()
        
        
        
        super.init()
        
        self.backgroundColor = .white
        
        self.addSubview(self.brightnessView)
        self.addSubview(self.colorView)
        self.addSubview(self.colorKnobView)
        self.addSubview(self.brightnessKnobView)

        let valueChanged: (CGFloat, Bool) -> Void = { [weak self] value, ended in
            if let strongSelf = self {
                let previousColor = strongSelf.color
                strongSelf.colorHSV.2 = 1.0 - value
                
                if strongSelf.color != previousColor || ended {
                    strongSelf.update()
                    if ended {
                        strongSelf.colorChangeEnded?(strongSelf.color)
                    } else {
                        strongSelf.colorChanged?(strongSelf.color)
                    }
                }
            }
        }
        
        self.update()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    
    private func update() {
        if self.adjustingPattern {
            self.backgroundColor = .white
        } else {
            self.backgroundColor = NSColor(white: self.colorHSV.2, alpha: 1.0)
        }
        self.colorView.value = self.colorHSV.2
        self.brightnessView.hsv = self.colorHSV
        self.colorKnobView.hsv = self.colorHSV
        
    }
    
    func updateKnobLayout(size: CGSize, panningColor: Bool) {
        let knobSize = CGSize(width: 45.0, height: 45.0)
        
        let colorHeight = size.height - 40
        var colorKnobFrame = CGRect(x: -knobSize.width / 2.0 + size.width * self.colorHSV.0, y: -knobSize.height / 2.0 + (colorHeight * (1.0 - self.colorHSV.1)), width: knobSize.width, height: knobSize.height)
        var origin = colorKnobFrame.origin
        if !panningColor {
            origin = CGPoint(x: max(0.0, min(origin.x, size.width - knobSize.width)), y: max(0.0, min(origin.y, colorHeight - knobSize.height)))
        } else {
            origin = origin.offsetBy(dx: 0.0, dy: -32.0)
        }
        colorKnobFrame.origin = origin
        self.colorKnobView.frame = colorKnobFrame
        
        let inset: CGFloat = 42.0
        let brightnessKnobSize = CGSize(width: 12.0, height: 42.0)
        let brightnessKnobFrame = CGRect(x: inset - brightnessKnobSize.width / 2.0 + (size.width - inset * 2.0) * (1.0 - self.colorHSV.2), y: size.height - 46.0, width: brightnessKnobSize.width, height: brightnessKnobSize.height)
        self.brightnessKnobView.frame = brightnessKnobFrame
    }
    
    override func layout() {
        super.layout()
        let size = frame.size
        let colorHeight = size.height - 40.0
        colorView.frame = CGRect(x: 0.0, y: 0.0, width: size.width, height: colorHeight)
        
        let inset: CGFloat = 42.0
        brightnessView.frame = CGRect(x: inset, y: size.height - 40, width: size.width - (inset * 2.0), height: 29.0)
        
        let slidersInset: CGFloat = 24.0
        
        self.updateKnobLayout(size: size, panningColor: false)
    }
    
    override func mouseDown(with event: NSEvent) {
        
        if brightnessView.mouseInside() || brightnessKnobView._mouseInside() {
            pickerValue = .brightness
        } else {
            pickerValue = .color
        }
        
        guard let pickerValue = pickerValue else { return }
        let size = frame.size
        let colorHeight = size.height - 40.0

        switch pickerValue {
        case .color:
            let location = self.convert(event.locationInWindow, from: nil)
            let newHue = max(0.0, min(1.0, location.x / size.width))
            let newSaturation = max(0.0, min(1.0, (1.0 - location.y / colorHeight)))
            self.colorHSV.0 = newHue
            self.colorHSV.1 = newSaturation
        case .brightness:
            let location = brightnessView.convert(event.locationInWindow, from: nil)
            let brightnessWidth: CGFloat = brightnessView.frame.width
            let newValue = max(0.0, min(1.0, 1.0 - location.x / brightnessWidth))
            self.colorHSV.2 = newValue
        }
        self.updateKnobLayout(size: size, panningColor: false)
        self.update()
        self.colorChanged?(self.color)
    }
    
    override func mouseDragged(with event: NSEvent) {
        let previousColor = self.color
        let size = frame.size
        let colorHeight = size.height - 40.0
        
        guard let pickerValue = pickerValue else { return }

        
        switch pickerValue {
        case .color:
            var location = self.convert(event.locationInWindow, from: nil)
            location.x = min(max(location.x, 1.0), frame.width)

            let newHue = max(0.0, min(1.0, location.x / size.width))
            let newSaturation = max(0.0, min(1.0, (1.0 - location.y / colorHeight)))
            self.colorHSV.0 = newHue
            self.colorHSV.1 = newSaturation
        case .brightness:
            let location = brightnessView.convert(event.locationInWindow, from: nil)
            let brightnessWidth: CGFloat = brightnessView.frame.width
            let newValue = max(0.0, min(1.0, 1.0 - location.x / brightnessWidth))
            self.colorHSV.2 = newValue
        }

        
         self.updateKnobLayout(size: size, panningColor: false)
        
        if self.color != previousColor {
            self.update()
            self.colorChanged?(self.color)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        self.updateKnobLayout(size: frame.size, panningColor: false)
        self.colorChanged?(self.color)
        self.colorChangeEnded?(self.color)
        pickerValue = nil
    }
}
