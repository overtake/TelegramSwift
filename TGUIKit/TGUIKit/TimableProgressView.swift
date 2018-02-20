//
//  TimableProgressView.swift
//  TGUIKit
//
//  Created by keepcoder on 13/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac

public final class TimableProgressTheme {
    let backgroundColor: NSColor
    let foregroundColor: NSColor
    let animated: Bool
    let outer: CGFloat
    let seconds: TimeInterval
    let border: Bool
    let borderWidth: CGFloat
    let start:Double
    public init(backgroundColor: NSColor = presentation.colors.blackTransparent, foregroundColor: NSColor = .white, animated: Bool = true, outer: CGFloat = 5, seconds: TimeInterval = 10, start: Double = 100, border: Bool = true, borderWidth: CGFloat = 3) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.animated = animated
        self.outer = outer
        self.seconds = seconds
        self.border = border
        self.borderWidth = borderWidth
        self.start = start
    }
}

public class TimableProgressView: View {

    public var theme: TimableProgressTheme = TimableProgressTheme() {
        didSet {
            self._progress = theme.start
            progress = Int32(round(theme.start))
            stopAnimation()
            needsDisplay = true
        }
    }
    
    public var progress: Int32 = 100 {
        didSet {
            assert(progress <= 100 && progress >= 0)
        }
    }
    private var _progress: Double = 100
    
    private var timer: SwiftSignalKitMac.Timer?
    
    public func startAnimation() {
        timer?.invalidate()
        let duration = self.theme.seconds
        let fps: TimeInterval = 60
        let difference = Double(progress) - _progress
        let tick: Double = Double(difference / (fps * duration))
        timer = SwiftSignalKitMac.Timer(timeout: 1 / fps, repeat: true, completion: { [weak self] in
            if let strongSelf = self {
                strongSelf._progress += tick
                strongSelf.needsDisplay = true
                if Int32(floor(strongSelf._progress)) == strongSelf.progress || strongSelf._progress < 0 || strongSelf._progress > 100 {
                    strongSelf.stopAnimation()
                }
            }
        }, queue: Queue.mainQueue())
        
        timer?.start()
    }
    public func stopAnimation() {
        timer?.invalidate()
        timer = nil
        _progress = Double(progress)
        needsDisplay = true
    }
    
    deinit {
         timer?.invalidate()
    }
   
    
    private func radians(_ degrees: CGFloat) -> CGFloat {
        return ((degrees) / 180 * .pi)
    }
    
    public override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        ctx.round(frame.size, floorToScreenPixels(scaleFactor: backingScaleFactor, frame.width/2))
        
        ctx.setFillColor(theme.backgroundColor.cgColor)
        ctx.fill(bounds)
        
        let center = NSMakePoint(floorToScreenPixels(scaleFactor: backingScaleFactor, frame.width/2), floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height/2))
        
        let startAngle: CGFloat = 90
        
        ctx.translateBy(x: frame.width / 2.0, y: frame.height / 2.0)
        ctx.scaleBy(x: 1.0, y: -1.0)
        ctx.translateBy(x: -frame.width / 2.0, y: -frame.height / 2.0)
        
        let radius: CGFloat = floorToScreenPixels(scaleFactor: backingScaleFactor, frame.width/2) - theme.outer
        let angle = CGFloat(_progress / 100 * 360)
      
        if theme.border {
            ctx.setStrokeColor(theme.foregroundColor.cgColor)
            ctx.setLineWidth(theme.borderWidth)
            ctx.strokeEllipse(in: NSMakeRect(1, 1, frame.width - 2, frame.height - 2))
        }
        
        
        ctx.move(to: center)

        ctx.setFillColor(theme.foregroundColor.cgColor)
        ctx.addArc(center: center, radius: radius, startAngle: radians(startAngle), endAngle: radians(startAngle + angle), clockwise: false)
        ctx.closePath()
        ctx.clip()
        ctx.fill(bounds)
        
        
       // ctx.move(to: center)

    }
    
    public init(_ theme: TimableProgressTheme = TimableProgressTheme()) {
        self.theme = theme
        super.init(frame: NSMakeRect(0, 0, 40, 40))
    }
    
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
