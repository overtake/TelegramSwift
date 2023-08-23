//
//  ChatGradientModel.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02.01.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

private let maskInset: CGFloat = 1.0


final class ChatMessageBubbleBackdrop: NSView {
    private var backgroundContent: NSView?
    private let borderView: SImageView = SImageView()
    private var currentMaskMode: Bool?
    
    private var maskView: SImageView?
    
    
    init() {
        
        super.init(frame: NSZeroRect)
        autoresizingMask = []
        autoresizesSubviews = false
        wantsLayer = true
        self.layer?.masksToBounds = true
        self.addSubview(self.borderView)
        self.layer?.disableActions()
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        if let view = maskView {
            transition.updateFrame(view: view, frame: size.bounds)
        }
        transition.updateFrame(view: borderView, frame: size.bounds)
    }
    
    func setType(image: (CGImage, NSEdgeInsets)?, border: (CGImage, NSEdgeInsets)?, background: CGImage) {
        if let _ = image {
            let maskView: SImageView
            if let current = self.maskView {
                maskView = current
            } else {
                maskView = SImageView()
                maskView.frame = self.bounds
                self.maskView?.layer?.disableActions()
                self.maskView = maskView
                self.layer?.mask = maskView.layer
            }
        } else {
            if let _ = self.maskView {
                self.layer?.mask = nil
                self.maskView = nil
            }
        }
        self.borderView.data = border
        if image == nil {
            if let view = self.backgroundContent {
                performSubviewRemoval(view, animated: false)
            }
            self.backgroundContent = nil
        } else {
            let current: NSView
            if let view = self.backgroundContent {
                current = view
            } else {
                current = NSView()
                current.wantsLayer = true
                self.backgroundContent = current
                addSubview(current, positioned: .below, relativeTo: self.borderView)
            }
            current.layer?.contents = background
        }
        
        if let maskView = self.maskView {
            maskView.data = image
        }
    }
    
    func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition, rotated: Bool = false) {
        
        if let backgroundContent = backgroundContent {
            transition.updateFrame(view: backgroundContent, frame: CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize))
        }

        if rotated {
            backgroundContent?.rotate(byDegrees: 180)
        } else {
            backgroundContent?.rotate(byDegrees: 0)
        }
    }
}
