//
//  EditImageCanvasColorPickerBackground.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 16/04/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit



class EditImageCanvasColorPickerBackground: Control {

    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        let rect = bounds
        
        let radius: CGFloat = rect.size.width > rect.size.height ? rect.size.height / 2.0 : rect.size.width / 2.0
        addRoundedRectToPath(ctx, bounds, radius, radius)
        ctx.clip()
        
        let colors = EditImageCanvasColorPickerBackground.colors
        var locations = EditImageCanvasColorPickerBackground.locations
        
        let colorSpc = CGColorSpaceCreateDeviceRGB()
        let gradient: CGGradient = CGGradient(colorsSpace: colorSpc, colors: colors as CFArray, locations: &locations)!
        
        if rect.size.width > rect.size.height {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: rect.size.height / 2.0), end: CGPoint(x: rect.size.width, y: rect.size.height / 2.0), options: .drawsAfterEndLocation)
        } else {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.size.width / 2.0, y: 0.0), end: CGPoint(x: rect.size.width / 2.0, y: rect.size.height), options: .drawsAfterEndLocation)
        }
        
        ctx.setBlendMode(.clear)
        ctx.setFillColor(.clear)

    }
    
    private func addRoundedRectToPath(_ context: CGContext, _ rect: CGRect, _ ovalWidth: CGFloat, _ ovalHeight: CGFloat) {
        var fw: CGFloat
        var fh: CGFloat
        if ovalWidth == 0 || ovalHeight == 0 {
            context.addRect(rect)
            return
        }
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: ovalWidth, y: ovalHeight)
        fw = rect.width / ovalWidth
        fh = rect.height / ovalHeight
        context.move(to: CGPoint(x: fw, y: fh / 2))
        context.addArc(tangent1End: CGPoint(x: fw, y: fh), tangent2End: CGPoint(x: fw / 2, y: fh), radius: 1)
        context.addArc(tangent1End: CGPoint(x: 0, y: fh), tangent2End: CGPoint(x: 0, y: fh / 2), radius: 1)
        context.addArc(tangent1End: CGPoint(x: 0, y: 0), tangent2End: CGPoint(x: fw / 2, y: 0), radius: 1)
        context.addArc(tangent1End: CGPoint(x: fw, y: 0), tangent2End: CGPoint(x: fw, y: fh / 2), radius: 1)
        context.closePath()
        context.restoreGState()
    }
    
    func color(for location: CGFloat) -> NSColor {
        let locations = EditImageCanvasColorPickerBackground.locations
        let colors = EditImageCanvasColorPickerBackground.colors
        
        if location < .ulpOfOne {
            return NSColor(cgColor: colors[0])!
        } else if location > 1 - .ulpOfOne {
            return NSColor(cgColor: colors[colors.count - 1])!
        }
        
        var leftIndex: Int = -1
        var rightIndex: Int = -1
        
        for (index, value) in locations.enumerated() {
            if index > 0 {
                if value > location {
                    leftIndex = index - 1
                    rightIndex = index
                    break
                }
            }
        }
        
        let leftLocation = locations[leftIndex]
        let leftColor = NSColor(cgColor: colors[leftIndex])!
        
        let rightLocation = locations[rightIndex]
        let rightColor = NSColor(cgColor: colors[rightIndex])!
        
        let factor = (location - leftLocation) / (rightLocation - leftLocation)
        
        return self.interpolateColor(color1: leftColor, color2: rightColor, factor: factor)
    }
    
    private func interpolateColor(color1: NSColor, color2: NSColor, factor: CGFloat) -> NSColor {
        let factor = min(max(factor, 0.0), 1.0)
        
        var r1: CGFloat = 0
        var r2: CGFloat = 0
        var g1: CGFloat = 0
        var g2: CGFloat = 0
        var b1: CGFloat = 0
        var b2: CGFloat = 0
        
        
        self.colorComponentsFor(color1, red: &r1, green: &g1, blue: &b1)
        self.colorComponentsFor(color2, red: &r2, green: &g2, blue: &b2)
        
        let r = r1 + (r2 - r1) * factor;
        let g = g1 + (g2 - g1) * factor;
        let b = b1 + (b2 - b1) * factor;
        
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    
    private func colorComponentsFor(_ color: NSColor, red:inout CGFloat, green:inout CGFloat, blue:inout CGFloat) {
        let componentsCount = color.cgColor.numberOfComponents
        let components = color.cgColor.components
        
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0
        
        if componentsCount == 4 {
            r = components?[0] ?? 0.0
            g = components?[1] ?? 0.0
            b = components?[2] ?? 0.0
            a = components?[3] ?? 0.0
        } else {
            b = components?[0] ?? 0.0
            g = b
            r = g
        }
        red = r
        green = g
        blue = b
    }

    
    static var colors: [CGColor] {
        return [NSColor(0xea2739).cgColor,
                NSColor(0xdb3ad2).cgColor,
                NSColor(0x3051e3).cgColor,
                NSColor(0x49c5ed).cgColor,
                NSColor(0x80c864).cgColor,
                NSColor(0xfcde65).cgColor,
                NSColor(0xfc964d).cgColor,
                NSColor(0x000000).cgColor,
                NSColor(0xffffff).cgColor
        ]
    }
    static var locations: [CGFloat] {
        return [ 0.0,  //red
                0.14, //pink
                0.24, //blue
                0.39, //cyan
                0.49, //green
                0.62, //yellow
                0.73, //orange
                0.85, //black
                1.0
        ]
    }
    
}

private final class PaintColorPickerKnobCircleView : View {
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var strokeIntensity: CGFloat = 0
    
    var strokesLowContrastColors: Bool = false

    
    override var needsLayout: Bool {
        didSet {
            needsDisplay = true
        }
    }
    
    var color: NSColor = .black {
        didSet {
            if strokesLowContrastColors {
                var strokeIntensity: CGFloat = 0.0
                var hue: CGFloat = 0
                var saturation: CGFloat = 0
                var brightness: CGFloat = 0
                var alpha: CGFloat = 0
                
                color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                if hue < CGFloat.ulpOfOne && saturation < CGFloat.ulpOfOne && brightness > 0.92 {
                    strokeIntensity = (brightness - 0.92) / 0.08
                }
                self.strokeIntensity = strokeIntensity
            }
            needsDisplay = true
        }
    }
    
    override func draw(_ layer: CALayer, in context: CGContext) {
        super.draw(layer, in: context)
        
        let rect = bounds
        
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect)
        
        if strokeIntensity > .ulpOfOne {
            context.setLineWidth(1.0)
            context.setStrokeColor(NSColor(white: 0.88, alpha: strokeIntensity).cgColor)
            context.strokeEllipse(in: rect.insetBy(dx: 1.0, dy: 1.0))
        }
        
    }
    

}

private let paintColorSmallCircle: CGFloat = 4.0
private let paintColorLargeCircle: CGFloat = 20.0
private let paintColorWeightGestureRange: CGFloat = 200
private let paintVerticalThreshold: CGFloat = 5
private let paintPreviewOffset: CGFloat = -60
private let paintPreviewScale: CGFloat = 2.0
private let paintDefaultBrushWeight: CGFloat = 0.22
private let oaintDefaultColorLocation: CGFloat = 1.0


private final class PaintColorPickerKnob: View {
    
    fileprivate var isZoomed: Bool = false
    
    fileprivate var weight: CGFloat = 0.5
    
    fileprivate func updateWeight(_ weight: CGFloat, animated: Bool) {
        self.weight = weight
        var diameter = circleDiameter(forBrushWeight: weight, zoomed: self.isZoomed)
        if Int(diameter) % 2 != 0 {
            diameter -= 1
        }
        colorView.setFrameSize(NSMakeSize(diameter, diameter))
        
        backgroundView.setFrameSize(NSMakeSize(24 * (isZoomed ? paintPreviewScale : 1), 24 * (isZoomed ? paintPreviewScale : 1)))
        backgroundView.center()

        
        if animated {
            if isZoomed {
                colorView.layer?.animateScaleSpring(from: 0.5, to: 1, duration: 0.3)
                backgroundView.layer?.animateScaleSpring(from: 0.5, to: 1, duration: 0.3)
            } else {
                colorView.layer?.animateScaleSpring(from: 2.0, to: 1, duration: 0.3)
                backgroundView.layer?.animateScaleSpring(from: 2.0, to: 1, duration: 0.3)
            }
        }
        
        needsLayout = true
    }
    
    fileprivate var color: NSColor = .random {
        didSet {
            colorView.color = color
        }
    }
    fileprivate var width: CGFloat {
        return circleDiameter(forBrushWeight: weight, zoomed: false) - 2
    }
    
    private let backgroundView = PaintColorPickerKnobCircleView(frame: .zero)
    private let colorView = PaintColorPickerKnobCircleView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        
        backgroundView.color = NSColor(0xffffff)
        
        colorView.color = NSColor.blue
        colorView.strokesLowContrastColors = true
        addSubview(backgroundView)
        addSubview(colorView)
    }

    
    func circleDiameter(forBrushWeight size: CGFloat, zoomed: Bool) -> CGFloat {
        var result = CGFloat(paintColorSmallCircle) + CGFloat((paintColorLargeCircle - paintColorSmallCircle)) * size
        result = CGFloat(zoomed ? result * paintPreviewScale : floor(result))
        return floorToScreenPixels(backingScaleFactor, result)
    }
    
    override func layout() {
        super.layout()
        backgroundView.setFrameSize(NSMakeSize(24 * (isZoomed ? paintPreviewScale : 1), 24 * (isZoomed ? paintPreviewScale : 1)))
        backgroundView.center()
        colorView.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

final class EditImageColorPicker: View {
    
    var arguments: EditImageCanvasArguments? {
        didSet {
            arguments?.updateColorAndWidth(knobView.color, knobView.width)
        }
    }
    
    private let knobView = PaintColorPickerKnob(frame: NSMakeRect(0, 0, 24 * paintPreviewScale, 24 * paintPreviewScale))
    let backgroundView = EditImageCanvasColorPickerBackground()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(backgroundView)
        addSubview(knobView)
        knobView.isEventLess = true
        
        backgroundView.set(handler: { [weak self] _ in
            self?.updateLocation(animated: false)
        }, for: .MouseDragging)
        
        backgroundView.set(handler: { [weak self] _ in
            self?.knobView.isZoomed = true
            self?.updateLocation(animated: true)
        }, for: .Down)
        
        backgroundView.set(handler: { [weak self] _ in
            self?.knobView.isZoomed = false
            self?.updateLocation(animated: true)
        }, for: .Up)
        
        let colorValue = UserDefaults.standard.value(forKey: "painterColorLocation") as? CGFloat
        let weightValue = UserDefaults.standard.value(forKey: "painterBrushWeight") as? CGFloat

        
        let colorLocation: CGFloat
        if let colorValue = colorValue {
            colorLocation = colorValue
        } else {
            colorLocation = CGFloat(arc4random()) / CGFloat(UInt32.max)
            UserDefaults.standard.setValue(colorLocation, forKey: "painterColorLocation")
        }
        self.location = colorLocation
        knobView.color = backgroundView.color(for: colorLocation)
        
        let weight = weightValue ?? paintDefaultBrushWeight
        knobView.updateWeight(weight, animated: false)
        
    }
    
    private var location: CGFloat = 0
    
    private func updateLocation(animated: Bool) {
        
        guard let window = self.window else {
            return
        }
        
        let location = backgroundView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        
        let colorLocation = max(0.0, min(1.0, location.x / backgroundView.frame.width))
        self.location = colorLocation
        
        
        knobView.color = backgroundView.color(for: colorLocation)
        
        let threshold = min(max(frame.height - backgroundView.frame.minY, frame.height - self.convert(window.mouseLocationOutsideOfEventStream, from: nil).y), paintColorWeightGestureRange + paintPreviewOffset)
        
        let weight = threshold / (paintColorWeightGestureRange + paintPreviewOffset);
        
        
        knobView.updateWeight(weight, animated: animated)
        
        arguments?.updateColorAndWidth(knobView.color, knobView.width)
        
        UserDefaults.standard.set(Double(colorLocation), forKey: "painterColorLocation")
        UserDefaults.standard.set(Double(weight), forKey: "painterBrushWeight")

        
        if animated {
            knobView.layer?.animatePosition(from: NSMakePoint(knobView.frame.minX - knobPosition.x, knobView.frame.minY - knobPosition.y), to: .zero, duration: 0.3, timingFunction: .spring, removeOnCompletion: true, additive: true)
        }
        
        needsLayout = true

        
    }
    
    override var isEventLess: Bool {
        get {
            guard let window = self.window else {
                return false
            }
            let point = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            
            if NSPointInRect(point, backgroundView.frame) || NSPointInRect(point, knobView.frame) {
                return false
            } else {
                return true
            }
        }
        set {
            super.isEventLess = newValue
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var knobPosition: NSPoint {
        
        guard let window = self.window else {
            return .zero
        }
        
        let threshold: CGFloat
        if knobView.isZoomed {
            threshold = min(max(0, frame.height - self.convert(window.mouseLocationOutsideOfEventStream, from: nil).y - (frame.height - backgroundView.frame.minY)), paintColorWeightGestureRange)
        } else {
            threshold = 0
        }
        let knobY: CGFloat = max(0, (backgroundView.frame.midY - knobView.frame.height / 2) + (knobView.isZoomed ? paintPreviewOffset : 0) + -threshold)
        let knobX: CGFloat = max(0, min(backgroundView.frame.width * location, self.frame.width - knobView.frame.width))
        return NSMakePoint(knobX, knobY)
    }
    
    override func layout() {
        super.layout()
        backgroundView.frame = NSMakeRect(24, frame.height - 24, frame.width - 48, 20)
        knobView.frame = CGRect(x: knobPosition.x, y: knobPosition.y, width: knobView.frame.size.width, height: knobView.frame.size.height)

    }
}
