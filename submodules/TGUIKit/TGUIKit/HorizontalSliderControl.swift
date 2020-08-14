//
//  HorizontalSliderControl.swift
//  TGUIKit
//
//  Created by Mikhail Filimonov on 28/07/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa

private func + (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}
private func - (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x - right.x, y: left.y - right.y)
}


public class HorizontalSliderControl: Control {
    
    public struct HorizontalSliderControlTheme {
        let background: NSColor
        let foreground: NSColor
        let slider: NSColor
        let sliderBorder: NSColor
        let activeForeground: NSColor
        let sliderBorderInactive: NSColor
        public init(background: NSColor, foreground: NSColor, activeForeground: NSColor, slider: NSColor, sliderBorder: NSColor, sliderBorderInactive: NSColor) {
            self.background = background
            self.foreground = foreground
            self.activeForeground = activeForeground
            self.slider = slider
            self.sliderBorder = sliderBorder
            self.sliderBorderInactive = sliderBorderInactive
        }
    }
    
    public override func scrollWheel(with event: NSEvent) {
        var point = slider.frame.origin - NSMakePoint(0, event.scrollingDeltaY)
        let height = self.foreground.frame.height
        
        point.y = min(max(point.y, self.foreground.frame.minY - slider.frame.height / 2), self.foreground.frame.maxY - slider.frame.height / 2)
        
        slider.setFrameOrigin(point)
        let percent = (slider.frame.midY - self.foreground.frame.minY) / height
        self.value = 1 - min(max(0, percent), 1)
    }

    private var theme: HorizontalSliderControlTheme = HorizontalSliderControlTheme(background: presentation.colors.background, foreground: presentation.colors.grayBackground, activeForeground: presentation.colors.accent, slider: presentation.colors.background, sliderBorder: presentation.colors.accentIcon, sliderBorderInactive: presentation.colors.grayIcon) {
        didSet {
            needsLayout = true
            updateUI()
        }
    }
    
    
    private let slider: Control = Control()
    private let foreground: Control = Control()
    private let foregroundActive: Control = Control()

    public var value: CGFloat = 1.0 {
        didSet {
            self.updateInteractiveValue?(value)
            updateUI()
            needsLayout = true
        }
    }
    public var updateInteractiveValue: ((CGFloat)->Void)? = nil
    
    
    public func updateTheme(_ theme: HorizontalSliderControlTheme) {
        self.theme = theme
    }
    
    private func updateUI() {
        let sliderSize = NSMakeSize(18, 18)

        slider.backgroundColor = theme.slider
        slider.layer?.cornerRadius = sliderSize.height / 2
        slider.layer?.borderWidth = 2
        slider.layer?.borderColor = value == 0 ? theme.sliderBorderInactive.cgColor : theme.sliderBorder.cgColor
        backgroundColor = theme.background
        foreground.backgroundColor = theme.foreground
        foreground.layer?.cornerRadius = 2
        
        
        foregroundActive.backgroundColor = theme.activeForeground
        foregroundActive.layer?.cornerRadius = 2
        
        
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 5
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSMakeSize(0, 2)
        self.slider.shadow = shadow
        
        
    }
    
    
    public override func layout() {
        super.layout()
        
        foreground.frame = focus(NSMakeSize(4, frame.height - 40))
        
        
        let sliderSize = NSMakeSize(18, 18)
        let y: CGFloat = foreground.frame.minY - sliderSize.height / 2 + ((1 - value) * foreground.frame.height)
        slider.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, frame.width / 2 - sliderSize.width / 2), y, sliderSize.width, sliderSize.height)
        
        
        foregroundActive.frame = NSMakeRect(foreground.frame.minX, slider.frame.midY, foreground.frame.width, foreground.frame.height * value)

    }
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(foreground)
        addSubview(foregroundActive)
        addSubview(slider)
        updateUI()
        
        foregroundActive.userInteractionEnabled = false
        foregroundActive.isEventLess = true
        
        foreground.userInteractionEnabled = false
        foreground.isEventLess = true

        
        self.set(handler: { [weak self] _ in
            
            guard let control = self?.foreground else {
                return
            }
            
            let mouseLocation = control.window?.mouseLocationOutsideOfEventStream ?? .zero
            let point = control.convert(mouseLocation, from: nil)
            
            let percent = 1.0 - (round((point.y / control.frame.height) * 10.0) / 10.0)
            
            self?.value = min(max(0, percent), 1)
            
        }, for: .Click)
        
        
        var sliderStart: NSPoint? = nil
        
        slider.set(handler: { control in
            sliderStart = control.window?.mouseLocationOutsideOfEventStream ?? nil
        }, for: .Down)
        
        slider.set(handler: { _ in
            sliderStart = nil
        }, for: .Up)
        
        
        slider.set(handler: { [weak self] control in
            guard let `self` = self,
                let start = sliderStart,
                let current = control.window?.mouseLocationOutsideOfEventStream else {
                return
            }
            
            let difference = start - current
            
            let height = self.foreground.frame.height
            let newValue = control.frame.origin + difference

            control.setFrameOrigin(NSMakePoint(control.frame.minX, newValue.y))
            let percent = (control.frame.midY - self.foreground.frame.minY) / height
            
            self.value = 1 - min(max(0, percent), 1)
            
            sliderStart = current
            
        }, for: .MouseDragging)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
