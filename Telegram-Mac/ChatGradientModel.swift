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
    private let backgroundContent: NSView
    
    private var currentMaskMode: Bool?
    
    private var maskView: SImageView?
    
    override var frame: CGRect {
        didSet {
            if let maskView = self.maskView {
                let maskFrame = self.bounds
                if maskView.frame != maskFrame {
                    maskView.frame = maskFrame
                }
            }
        }
    }
    
    init() {
        self.backgroundContent = NSView()
        
        super.init(frame: NSZeroRect)
        self.backgroundContent.wantsLayer = true
        wantsLayer = true
        self.layer?.masksToBounds = true
        self.maskView?.wantsLayer = true
        self.addSubview(self.backgroundContent)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func setType(image: (CGImage, NSEdgeInsets)?, background: CGImage) {
        if let _ = image {
            let maskView: SImageView
            if let current = self.maskView {
                maskView = current
            } else {
                maskView = SImageView()
                maskView.frame = self.bounds
                self.maskView = maskView
                self.layer?.mask = maskView.layer
            }
        } else {
            if let _ = self.maskView {
                self.layer?.mask = nil
                self.maskView = nil
            }
        }
        self.backgroundContent.layer?.contents = background
        if let maskView = self.maskView {
            maskView.data = image
        }
        self.backgroundContent.isHidden = image == nil
    }
    

    func update(rect: CGRect, within containerSize: CGSize, animated: Bool) {
        self.backgroundContent.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
    }
}
