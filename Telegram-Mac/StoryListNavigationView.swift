//
//  StoryListNavigationView.swift
//  Telegram
//
//  Created by Mike Renoir on 27.04.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit


final class StoryListNavigationView : View {
    
    private var parts:[View] = []
    private let selector = LinearProgressControl(progressHeight: 2)
    
    private var selected: Int? = nil
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        selector.layer?.cornerRadius = 1
        selector.backgroundColor = NSColor.white
        self.addSubview(selector)
        
        selector.insets = NSEdgeInsetsMake(0, 0, 0, 0)
        selector.roundCorners = true
        selector.alignment = .center
        selector.liveScrobbling = false
        selector.containerBackground = .clear
        selector.style = ControlStyle(foregroundColor: .white, backgroundColor: .clear, highlightColor: .clear)
        selector.set(progress: 0, animated: false, duration: 0)
        

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func initialize(count: Int) {
        for part in parts {
            part.removeFromSuperview()
        }
        parts.removeAll()
        for _ in 0 ..< count {
            let part = View(frame: NSMakeRect(0, 0, 0, 2))
            part.backgroundColor = NSColor.white.withAlphaComponent(0.3)
            part.layer?.cornerRadius = 1
            self.addSubview(part, positioned: .below, relativeTo: self.selector)
            parts.append(part)
        }
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    func set(_ index: Int, state: StoryView.State, duration: Double, animated: Bool) {
        self.selected = index
                
        CATransaction.begin()
        for (i, part) in parts.enumerated() {
            if i < index {
                part.backgroundColor = NSColor.white
            } else {
                part.backgroundColor = NSColor.white.withAlphaComponent(0.3)
            }
            if i == index {
                selector.frame = NSMakeRect(part.frame.minX, part.frame.minY, part.frame.width, 2)
                switch state {
                case let .playing(status):
                    selector.set(progress: duration == 0 ? 0 : CGFloat(status.timestamp / duration), animated: animated, duration: duration, beginTime: status.generationTimestamp, offset: status.timestamp, speed: Float(status.baseRate))
                default:
                    if let status = state.status {
                        selector.set(progress: duration == 0 ? 0 : CGFloat(status.timestamp / duration), animated: false)
                    } else {
                        selector.set(progress: 0, animated: false)
                    }
                }
                

            }
        }
        CATransaction.commit()
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        let partSize = (size.width - 12 - CGFloat(parts.count - 1) * 2) / CGFloat(parts.count)
        let itemSize = NSMakeSize(max(2, partSize), 2)
        
        
        var x: CGFloat = 6
        for part in parts {
            let rect = CGRect(origin: CGPoint(x: x, y: 0), size: itemSize)
            transition.updateFrame(view: part, frame: rect)
            x += itemSize.width + 2
        }
    }
}
