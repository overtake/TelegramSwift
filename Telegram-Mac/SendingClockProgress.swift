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
    
    override init() {
        
        clockFrame = CALayer()
        clockFrame.contents = theme.icons.chatSendingOutFrame
        clockFrame.frame = theme.icons.chatSendingOutFrame.backingBounds
        
        clockHour = CALayer()
        clockHour.contents = theme.icons.chatSendingOutHour
        clockHour.frame = theme.icons.chatSendingOutHour.backingBounds
        
        clockMin = CALayer()
        clockMin.contents = theme.icons.chatSendingOutMin
        clockMin.frame = theme.icons.chatSendingOutMin.backingBounds
        
        super.init(frame:NSMakeRect(0, 0, 12, 12))
        self.backgroundColor = .clear

        self.layer?.addSublayer(clockFrame)
        self.layer?.addSublayer(clockHour)
        self.layer?.addSublayer(clockMin)
    }
    
    
    func set(item: ChatRowItem) {
        clockFrame.contents = theme.chat.sendingFrameIcon(item)
        clockHour.contents = theme.chat.sendingHourIcon(item)
        clockMin.contents = theme.chat.sendingMinIcon(item)
        viewDidMoveToWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
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
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animation.duration = (minute_duration * 4.0) + 0.6
        animation.repeatCount = .greatestFiniteMagnitude
        animation.toValue = (Double.pi * 2.0) as NSNumber
        animation.isRemovedOnCompletion = false
        clockHour.add(animation, forKey: "rotate")
    }
    

    private func animateMin() -> Void {
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animation.duration = minute_duration
        animation.repeatCount = .greatestFiniteMagnitude
        animation.toValue = (Double.pi * 2.0) as NSNumber
        animation.isRemovedOnCompletion = false
        clockMin.add(animation, forKey: "rotate")
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

