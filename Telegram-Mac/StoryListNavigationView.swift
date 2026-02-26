//
//  StoryListNavigationView.swift
//  Telegram
//
//  Created by Mike Renoir on 27.04.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit


private final class ListView : View {
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        let partSize = (frame.width - 12 - CGFloat(self.count - 1) * 2) / CGFloat(self.count)
        let itemSize = NSMakeSize(max(2, partSize), 2)
        
                
        var x: CGFloat = 6
        for i in 0 ..< count {
            let rect = CGRect(origin: CGPoint(x: x, y: 0), size: itemSize)
            
            let path = CGMutablePath()
            path.addRoundedRect(in: rect, cornerWidth: 1, cornerHeight: 1)
            
            let color: NSColor
            if i < selected {
                color = NSColor.white
            } else {
                color = NSColor.white.withAlphaComponent(0.3)
            }
            ctx.setFillColor(color.cgColor)

            ctx.addPath(path)
            ctx.fillPath()
            
            x += itemSize.width + 2
        }
        
        
    }
    func getRect(_ index: Int) -> NSRect {
        let partSize = (frame.width - 12 - CGFloat(self.count - 1) * 2) / CGFloat(self.count)
        let itemSize = NSMakeSize(max(2, partSize), 2)
        
        
        var x: CGFloat = 6
        for i in 0 ..< count {
            let rect = CGRect(origin: CGPoint(x: x, y: 0), size: itemSize)
            x += itemSize.width + 2
            if i == index {
                return rect
            }
        }
        return .zero
    }
    
    var count: Int = 0 {
        didSet {
            needsDisplay = true
        }
    }
    var selected: Int = 0 {
        didSet {
            needsDisplay = true
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layerContentsRedrawPolicy = .duringViewResize
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class StoryListNavigationView : Control {
    
    
    private var parts:[View] = []
    private let selector = LinearProgressControl(progressHeight: 2)
    
    private let listView: ListView
    
    var seek:((Float?)->Void)? = nil
    var seekStart:(()->Void)? = nil
    var seekFinish:(()->Void)? = nil

    private var selected: Int? = nil
    required init(frame frameRect: NSRect) {
        self.listView = ListView(frame: NSMakeRect(0, 0, frameRect.width, 2))
        super.init(frame: frameRect)
        selector.layer?.cornerRadius = 1
        selector.backgroundColor = NSColor.white
        self.addSubview(listView)
        self.addSubview(selector)
        
        selector.insets = NSEdgeInsetsMake(0, 0, 0, 0)
        selector.roundCorners = true
        selector.alignment = .center
        selector.liveScrobbling = false
        selector.containerBackground = .clear
        selector.progressHeight = 2
        selector.style = ControlStyle(foregroundColor: .white, backgroundColor: .clear, highlightColor: .clear)
        selector.set(progress: 0, animated: false, duration: 0)
        
        selector.onUserChanged = { [weak self] value in
            self?.seek?(value)
        }
        selector.onLiveScrobbling = { [weak self] value in
            self?.seek?(value)
        }
        
        selector.startScrobbling = { [weak self] in
            self?.seekStart?()
        }
        selector.endScrobbling = { [weak self] in
            self?.seekFinish?()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func initialize(count: Int) {
        for part in parts {
            part.removeFromSuperview()
        }
        
        listView.count = count
        
        self.selector.set(progress: 0, animated: false)
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    func set(_ index: Int, state: StoryLayoutView.State, canSeek: Bool, duration: Double, animated: Bool) {
        self.selected = index
        
        selector.isEnabled = canSeek
                
        CATransaction.begin()
        
        self.listView.selected = index
        var rect = listView.getRect(index)
        rect.size.height = frame.height
        selector.frame = rect
        switch state {
        case let .playing(status):
            selector.set(progress: status.timestamp == 0 ? 1 : CGFloat(status.timestamp / duration), animated: animated, duration: duration, beginTime: status.generationTimestamp, offset: status.timestamp, speed: Float(status.baseRate))
        default:
            if let status = state.status {
                selector.set(progress: duration == 0 ? 1 : CGFloat(status.timestamp / duration), animated: false)
            } else {
                selector.set(progress: 0, animated: false)
            }
        }
        CATransaction.commit()
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: listView, frame: NSMakeRect(0, 4, size.width, 2))
    }
}
