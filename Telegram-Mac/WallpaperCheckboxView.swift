//
//  WallpaperCheckboxView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22.07.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit

private final class BlurCheckbox : View {
    
    var isFullFilled: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    private(set) var isSelected: Bool = false
    private var timer: SwiftSignalKit.Timer?
    func set(isSelected: Bool, animated: Bool) {
        self.isSelected = isSelected
        if animated {
            timer?.invalidate()
            
            let fps: CGFloat = 60

            let tick = isSelected ? ((1 - animationProgress) / (fps * 0.2)) : -(animationProgress / (fps * 0.2))
            timer = SwiftSignalKit.Timer(timeout: 0.016, repeat: true, completion: { [weak self] in
                guard let `self` = self else {return}
                self.animationProgress += tick
                
                if self.animationProgress <= 0 || self.animationProgress >= 1 {
                    self.timer?.invalidate()
                    self.timer = nil
                }
                
            }, queue: .mainQueue())
            
            timer?.start()
        } else {
            animationProgress = isSelected ? 1.0 : 0.0
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var animationProgress: CGFloat = 0.0 {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ layer: CALayer, in context: CGContext) {
        super.draw(layer, in: context)
        
        let borderWidth: CGFloat = 2.0
        
        context.setStrokeColor(.white)
        context.setLineWidth(borderWidth)
        context.strokeEllipse(in: bounds.insetBy(dx: borderWidth / 2.0, dy: borderWidth / 2.0))
        
        let progress: CGFloat = animationProgress
        let diameter = bounds.width
        let center = CGPoint(x: diameter / 2.0, y: diameter / 2.0)

        
        context.setFillColor(.white)
        context.fillEllipse(in: bounds.insetBy(dx: (diameter - borderWidth) * (1.0 - animationProgress), dy: (diameter - borderWidth) * (1.0 - animationProgress)))
        if !isFullFilled {
            let firstSegment: CGFloat = max(0.0, min(1.0, progress * 3.0))
            let s = CGPoint(x: center.x - 4.0, y: center.y + 1.0)
            let p1 = CGPoint(x: 3.0, y: 3.0)
            let p2 = CGPoint(x: 5.0, y: -6.0)
            
            if !firstSegment.isZero {
                if firstSegment < 1.0 {
                    context.move(to: CGPoint(x: s.x + p1.x * firstSegment, y: s.y + p1.y * firstSegment))
                    context.addLine(to: s)
                } else {
                    let secondSegment = (progress - 0.33) * 1.5
                    context.move(to: CGPoint(x: s.x + p1.x + p2.x * secondSegment, y: s.y + p1.y + p2.y * secondSegment))
                    context.addLine(to: CGPoint(x: s.x + p1.x, y: s.y + p1.y))
                    context.addLine(to: s)
                }
            }
            

            context.setBlendMode(.clear)
            context.setLineWidth(borderWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setMiterLimit(10.0)
            
            
            context.strokePath()
        }
        
    }
}


final class WallpaperCheckboxView : Control {
    
    final class ColorsListView : View {
        
        var colors:[NSColor] = [] {
            didSet {
                needsDisplay = true
            }
        }
        
        override func draw(_ layer: CALayer, in ctx: CGContext) {
            super.draw(layer, in: ctx)
            
            ctx.round(frame.size, frame.height / 2)
            
            if colors.count == 1 {
                ctx.setFillColor(colors[0].cgColor)
                ctx.fill(bounds)
            } else if colors.count == 2 {
                ctx.setFillColor(colors[0].cgColor)
                ctx.fill(NSMakeRect(0, 0, frame.width / 2, frame.height))
                ctx.setFillColor(colors[1].cgColor)
                ctx.fill(NSMakeRect(frame.width / 2, 0, frame.width / 2, frame.height))
            } else if colors.count == 3 {
                
            } else if colors.count == 4 {
                ctx.setFillColor(colors[0].cgColor)
                ctx.fill(NSMakeRect(0, 0, frame.width / 2, frame.height / 2))
                
                ctx.setFillColor(colors[1].cgColor)
                ctx.fill(NSMakeRect(frame.width / 2, 0, frame.width / 2, frame.height / 2))
                
                ctx.setFillColor(colors[2].cgColor)
                ctx.fill(NSMakeRect(0, frame.height / 2, frame.width / 2, frame.height / 2))
                
                ctx.setFillColor(colors[3].cgColor)
                ctx.fill(NSMakeRect(frame.width / 2, frame.height / 2, frame.width / 2, frame.height / 2))

            }
        }
    }
    
    private let title:(TextNodeLayout,TextNode)
    fileprivate let checkbox: BlurCheckbox = BlurCheckbox(frame: NSMakeRect(0, 0, 16, 16))
    
    override var isSelected: Bool {
        get {
            return checkbox.isSelected
        }
        set {
            checkbox.set(isSelected: newValue, animated: false)
        }
    }
    
    
    var isFullFilled: Bool = false {
        didSet {
            checkbox.isFullFilled = isFullFilled
        }
    }
    
    required init(frame frameRect: NSRect, title: String) {
        self.title = TextNode.layoutText(.initialize(string: title, color: .white, font: .medium(.text)), nil, 1, .end, NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude), nil, false, .left)
        super.init(frame: frameRect)
        addSubview(checkbox)
        layer?.cornerRadius = frameRect.height / 2
        setFrameSize(self.title.0.size.width + 10 + checkbox.frame.width + 10 + 10, frameRect.height)
        scaleOnClick = true
        
        self.set(handler: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.checkbox.set(isSelected: !strongSelf.checkbox.isSelected, animated: false)
                strongSelf.onChangedValue?(strongSelf.checkbox.isSelected)
            }
        }, for: .Click)

    }
    
    var onChangedValue:((Bool)->Void)?
    
    override func layout() {
        super.layout()
        checkbox.centerY(x: 10)
    }
    
    func update(by color: NSColor?) -> Void {
        if let color = color {
            backgroundColor = color
        } else {
            backgroundColor = theme.chatServiceItemColor
        }
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        let rect = focus(title.0.size)
        title.1.draw(NSMakeRect(frame.width - rect.width - 10, rect.minY, rect.width, rect.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: .clear)
    }
    
    deinit {
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}


final class WallpaperPlayRotateView : Control {
    
    
    private let imageView = ImageView()
    
    var onClick:(()->Void)?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.cornerRadius = frameRect.height / 2
        addSubview(imageView)
        scaleOnClick = true
        self.set(handler: { [weak self] _ in
            self?.onClick?()
        }, for: .Click)
    }
    
    func set(rotation: Int32?, animated: Bool) {
        if let layer = self.imageView.layer {
            if let rotation = rotation {
                if animated {
                    if let animatorLayer = self.imageView.animator().layer {
                        layer.position = CGPoint(x: layer.frame.midX, y: layer.frame.midY)
                        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                        
                        NSAnimationContext.beginGrouping()
                        NSAnimationContext.current.allowsImplicitAnimation = true
                        animatorLayer.transform = CATransform3DMakeRotation(CGFloat.pi * CGFloat(rotation) / 180.0, 0, 0, 1)
                        NSAnimationContext.endGrouping()
                    }
                } else {
                    layer.position = CGPoint(x: layer.frame.midX, y: layer.frame.midY)
                    layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                    layer.transform = CATransform3DMakeRotation(CGFloat.pi * CGFloat(rotation) / 180.0, 0, 0, 1)
                }
            }
        }
    }
    
    override func layout() {
        super.layout()
        imageView.center()
    }
    
    func update(_ image: CGImage) {
        self.imageView.image = image
        self.imageView.sizeToFit()
        self.imageView.center()
    }
    
    func update(by color: NSColor?) -> Void {
        if let color = color {
            backgroundColor = color
        } else {
            backgroundColor = theme.chatServiceItemColor
        }
    }
    
    deinit {
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
