//
//  SendingClockProgress.swift
//  Telegram-Mac
//
//  Created by keepcoder on 05/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit



fileprivate let minute_duration:Double = 1.2

class SendingClockProgress: View {
    
    private var isAnimating:Bool = false

    private let clockFrame:CALayer
    private let clockHour:CALayer
    private let clockMin:CALayer
    
    required init(frame frameRect: NSRect) {
        
        clockFrame = CALayer()
        clockFrame.contents = theme.icons.chatSendingOutFrame
        clockFrame.frame = theme.icons.chatSendingOutFrame.backingBounds
        
        clockHour = CALayer()
        clockHour.contents = theme.icons.chatSendingOutHour
        clockHour.frame = theme.icons.chatSendingOutHour.backingBounds
        
        clockMin = CALayer()
        clockMin.contents = theme.icons.chatSendingOutMin
        clockMin.frame = theme.icons.chatSendingOutMin.backingBounds
        
        super.init(frame: frameRect)
        self.backgroundColor = .clear

        self.layer?.addSublayer(clockFrame)
        self.layer?.addSublayer(clockHour)
        self.layer?.addSublayer(clockMin)
        
    }
    
    override func layout() {
        super.layout()
        
        clockMin.frame = focus(theme.icons.chatSendingOutMin.backingSize)
        clockHour.frame = focus(theme.icons.chatSendingOutHour.backingSize)
    }
    
    
    func set(frame: CGImage, hour: CGImage, minute: CGImage) {
        clockFrame.contents = frame
        clockHour.contents = hour
        clockMin.contents = minute
        viewDidMoveToWindow()
    }
    
    func applyGray() {
        clockFrame.contents = theme.icons.chatSendingOutFrame
        clockHour.contents = theme.icons.chatSendingOutHour
        clockMin.contents = theme.icons.chatSendingOutMin
        viewDidMoveToWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    public func startAnimating() -> Void {
        if isAnimating {
            return
        }
        
        clockHour.removeAllAnimations()
        clockMin.removeAllAnimations()
        isAnimating = true
        
        animateHour()
        animateMin()
    }
    
    private func animateHour() -> Void {
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.duration = 6
        animation.repeatCount = .infinity
        animation.fromValue = 0
        animation.toValue = (Double.pi * 2.0)
        animation.beginTime = 1.0
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        clockHour.add(animation, forKey: "clockFrameAnimation")
    }
    

    private func animateMin() -> Void {
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.duration = 1
        animation.repeatCount = .infinity
        animation.fromValue = 0
        animation.toValue = (Double.pi * 2.0)
        animation.beginTime = 1.0
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        clockMin.add(animation, forKey: "clockFrameAnimation")
    }
    
    public func stopAnimating() -> Void {
        if !isAnimating {
            return
        }
        
        isAnimating = false
        clockHour.removeAllAnimations()
        clockMin.removeAllAnimations()
    }
    
    
    override func viewDidMoveToSuperview() {
        if window != nil && superview != nil {
            startAnimating()
        } else {
            stopAnimating()
        }
    }
    override func viewDidMoveToWindow() {
        if window != nil && superview != nil {
            startAnimating()
        } else {
            stopAnimating()
        }
    }
    
}

