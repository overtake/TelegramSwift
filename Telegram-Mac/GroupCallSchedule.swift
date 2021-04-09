//
//  GroupCallSchedule.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.04.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox


private final class GroupCallScheduleTimerView : View {
    private let counter = DynamicCounterTextView(frame: .zero)
    private var nextTimer: SwiftSignalKit.Timer?

    private let headerView = TextView()
    private let descView = TextView()
    
    private let maskImage: CGImage
    private let mask: View
    required init(frame frameRect: NSRect) {
        mask = View(frame: NSMakeRect(0, 0, frameRect.width, 64))
        let purple = NSColor(rgb: 0x3252ef)
        let pink = NSColor(rgb: 0xef436c)
        
        headerView.userInteractionEnabled = false
        headerView.isSelectable = false
        
        descView.userInteractionEnabled = false
        descView.isSelectable = false
        

        
        maskImage = generateImage(mask.frame.size, contextGenerator: { size, ctx in
            ctx.clear(size.bounds)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var locations:[CGFloat] = [0.0, 0.85, 1.0]
            let gradient = CGGradient(colorsSpace: colorSpace, colors: [pink.cgColor, purple.cgColor, purple.cgColor] as CFArray, locations: &locations)!
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0.0), end: CGPoint(x: size.width, y: size.height), options: [])
        })!
        super.init(frame: frameRect)
        addSubview(mask)
        addSubview(headerView)
        addSubview(descView)
        
        isEventLess = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(time timeValue: Int32, animated: Bool) {
        let time = Int(timeValue - Int32(Date().timeIntervalSince1970))
        
        let text = timerText(time)
        let value = DynamicCounterTextView.make(for: text, count: text, font: .avatar(50), textColor: .white, width: frame.width)
        
        counter.update(value, animated: animated, reversed: true)
        
        
        counter.change(size: value.size, animated: animated)
        counter.change(pos: focus(value.size).origin, animated: animated)
        
        self.nextTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: false, completion: { [weak self] in
            self?.update(time: timeValue, animated: true)
        }, queue: .mainQueue())
        
        
        let counterSubviews = counter.effectiveSubviews
        
        while mask.subviews.count > counterSubviews.count {
            mask.subviews.removeLast()
        }
        while mask.subviews.count < counterSubviews.count {
            let view = ImageView()
            view.image = maskImage
            view.sizeToFit()
            mask.addSubview(view)
        }
        
        for (i, mask) in mask.subviews.enumerated() {
            mask.layer?.mask = counterSubviews[i].layer
        }
        mask.setFrameSize(value.size)
        mask.change(pos: NSMakePoint(round((frame.width - value.size.width) / 2), focus(mask.frame.size).minY), animated: animated)
        self.nextTimer?.start()
        
        if time <= 5 {
            if mask.layer?.animation(forKey: "opacity") == nil {
                let animation: CABasicAnimation = CABasicAnimation(keyPath: "opacity")
                animation.timingFunction = .init(name: .easeInEaseOut)
                animation.fromValue = 1
                animation.toValue = 0.5
                animation.duration = 1.0
                animation.autoreverses = true
                animation.isRemovedOnCompletion = true
                animation.fillMode = CAMediaTimingFillMode.forwards
                
                mask.layer?.add(animation, forKey: "opacity")
            }
        } else {
            mask.layer?.removeAnimation(forKey: "opacity")
        }
        
        let headerText = time >= 0 ? L10n.voiceChatScheduledHeader : L10n.voiceChatScheduledHeaderLate
        
        let headerLayout = TextViewLayout.init(.initialize(string: headerText, color: GroupCallTheme.customTheme.textColor, font: .avatar(26)))
        headerLayout.measure(width: frame.width - 60)
        headerView.update(headerLayout)
        headerView.centerX(y: mask.frame.minY - headerView.frame.height)
        
        
        
        let descLayout = TextViewLayout.init(.initialize(string: stringForMediumDate(timestamp: timeValue), color: GroupCallTheme.customTheme.textColor, font: .avatar(26)))
        descLayout.measure(width: frame.width - 60)
        descView.update(descLayout)
        descView.centerX(y: mask.frame.maxY)

    }
    
    override func layout() {
        super.layout()
        mask.center()
    }
}


final class GroupCallScheduleView : View {
    private weak var currentView: View?
    private var timerView: GroupCallScheduleTimerView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEventLess = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(_ state: GroupCallUIState, arguments: GroupCallUIArguments?, animated: Bool) {
        if let scheduleTimestamp = state.state.scheduleTimestamp {
            let current: GroupCallScheduleTimerView
            if let timerView = timerView {
                current = timerView
            } else {
                current = GroupCallScheduleTimerView(frame: NSMakeRect(0, 0, frame.width, frame.height))
                self.timerView = current
                addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            if current != self.currentView {
                if let view = self.currentView {
                    if animated {
                        view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                            view?.removeFromSuperview()
                        })
                    } else {
                        view.removeFromSuperview()
                    }
                }
            }
            self.timerView?.update(time: scheduleTimestamp, animated: animated)
            self.currentView = current
        }
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        if let view = currentView {
            transition.updateFrame(view: view, frame: NSMakeRect(0, 0, size.width, size.height))
        }
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: self.frame.size, transition: .immediate)
    }
}
