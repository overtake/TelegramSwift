//
//  PeerRatingView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11.07.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore

final class PeerRatingView : Control {
    private let levelView: TextView = TextView()
    private var levelCapView: TextView?
    private var nextLevelView: TextView?
    private let backgroundView = View()
    enum State {
        case short
        case full
        
        func toggle() -> State {
            return self == .short ? .full : .short
        }
    }
    
    
    private(set) var state: State = .short
    private var data: TelegramStarRating = .init(level: 0, currentLevelStars: 0, stars: 0, nextLevelStars: 0)
    
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        levelView.userInteractionEnabled = false
        levelView.isSelectable = false
                
        addSubview(backgroundView)
        addSubview(levelView)
        

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
//    func toggleState(animated: Bool) {
//        self.state = self.state.toggle()
//        let size = self.set(data: self.data, animated: animated)
//        
//        self.change(size: size, animated: true)
//        self.updateLayout(size: size, transition: .animated(duration: 0.2, curve: .easeOut))
//
//    }
//
    
    var smallSize: NSSize {
        return NSMakeSize(max(20, levelView.frame.width + 6), 20)
    }
    
    func set(data: TelegramStarRating, context: AccountContext, textColor: NSColor, state: State, animated: Bool) -> NSSize {
        
        
        
        self.data = data
        
        if state != self.state {
            if state == .full, let window = _window {
                if let nextLevelStars = data.nextLevelStars {
                    self.appTooltip = "\(data.currentLevelStars) / \(nextLevelStars)"
                } else {
                    self.appTooltip = nil
                }
                showModalText(
                    for: window,
                    text: strings().peerInfoRatingText,
                    button: strings().peerInfoRatingButton,
                    callback: { _ in
                        let url = context.appConfiguration.getStringValue("stars_rating_learnmore_url", orElse: "telegram.org")
                        execute(inapp: .external(link: url, false))
                    }
                )

            }
            
        }
        
        
        self.state = state
        
       
        
        backgroundView.backgroundColor = .white
        self.backgroundColor = NSColor.white.withAlphaComponent(0.35)
        
        let levelLayout = TextViewLayout(.initialize(string: "\(data.level)", color: textColor, font: .normal(.short)))
        levelLayout.measure(width: .greatestFiniteMagnitude)
        
        self.levelView.update(levelLayout)
        
        let size: NSSize
        
        switch state {
        case .short:
            size = NSMakeSize(max(20, levelLayout.layoutSize.width + 6), 20)
        case .full:
            size = NSMakeSize(200, 20)
        }
        
        
        if case .full = state {
            do {
                let current: TextView
                let isNew: Bool
                if let view = self.levelCapView {
                    current = view
                    isNew = false
                } else {
                    current = TextView()
                    current.isSelectable = false
                    current.userInteractionEnabled = false
                    self.addSubview(current)
                    self.levelCapView = current
                    isNew = true
                    
                }
                let capLayout = TextViewLayout(
                    .initialize(
                        string: strings().peerInfoRatingLevel,
                        color: textColor,
                        font: .normal(.short)
                    )
                )
                capLayout.measure(width: .greatestFiniteMagnitude)
                current.update(capLayout)
                
                if isNew {
                    current.centerY(x: 6)
                    if animated {
                        current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
            }
            do {
                if let nextLevelStars = data.nextLevelStars {
                    let current: TextView
                    let isNew: Bool
                    if let view = self.nextLevelView {
                        current = view
                        isNew = false
                    } else {
                        current = TextView()
                        current.isSelectable = false
                        current.userInteractionEnabled = false
                        self.addSubview(current)
                        self.nextLevelView = current
                        isNew = true
                        
                    }
                    let layout = TextViewLayout(.initialize(string: "\(data.level + 1)", color: textColor, font: .normal(.short)))
                    layout.measure(width: .greatestFiniteMagnitude)
                    current.update(layout)
                    
                    if isNew {
                        current.centerY(x: size.width - current.frame.width - 6)
                        if animated {
                            current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        }
                    }
                } else if let nextLevelView {
                    performSubviewRemoval(nextLevelView, animated: animated)
                    self.nextLevelView = nil
                }
                
            }
        } else {
            if let levelCapView {
                performSubviewRemoval(levelCapView, animated: animated)
                self.levelCapView = nil
            }
            if let nextLevelView {
                performSubviewRemoval(nextLevelView, animated: animated)
                self.nextLevelView = nil
            }
        }
        
       // let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        
      
        
        self.layer?.cornerRadius = size.height / 2
        
        self.backgroundView.layer?.cornerRadius = (size.height - 2) / 2
        
        return size
        
    }
    
    
    override func layout() {
        super.layout()
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        
        switch state {
        case .short:
            transition.updateFrame(view: self.levelView, frame: self.levelView.centerFrame())
            transition.updateFrame(view: backgroundView, frame: size.bounds.insetBy(dx: 1, dy: 1))
        case .full:
            var offset: CGFloat = 6
            if let levelCapView {
                transition.updateFrame(view: levelCapView, frame: levelCapView.centerFrameY(x: 6))
                offset = levelCapView.frame.maxX + 4
            }
            transition.updateFrame(view: self.levelView, frame: self.levelView.centerFrameY(x: offset))
            
            var bgRect = size.bounds.insetBy(dx: 1, dy: 1)
            if let nextLevelStars = data.nextLevelStars {
                bgRect.size.width = bgRect.size.width * (CGFloat(data.currentLevelStars) / CGFloat(nextLevelStars))
            }
            transition.updateFrame(view: backgroundView, frame: bgRect)
            
            if let nextLevelView {
                transition.updateFrame(view: nextLevelView, frame: nextLevelView.centerFrameY(x: size.width - nextLevelView.frame.width - 6))
            }

        }
    }
}
