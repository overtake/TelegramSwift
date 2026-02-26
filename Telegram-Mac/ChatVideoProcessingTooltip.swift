//
//  ChatVideoProcessingTooltip.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25.10.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//



import Foundation
import TGUIKit
import TelegramCore
import SwiftSignalKit
import Postbox

final class ChatVideoProcessingTooltip : Control {
    enum Source {
        case proccessing(Message)
        case published(Message)
    }
    
    private let titleView = TextView()
    
    private var timer: SwiftSignalKit.Timer?
    
    private let visualEffect = NSVisualEffectView()
    
    private var imageView: TransformImageView?
    private var animationView: MediaAnimatedStickerView?
    private var infoView: TextView?
    private var viewMessage: TextButton?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(visualEffect)
        addSubview(titleView)
        
        visualEffect.material = .ultraDark
        visualEffect.blendingMode = .withinWindow
        visualEffect.state = .active
        
        
        self.layer?.cornerRadius = 10
        
        self.titleView.userInteractionEnabled = false
        self.titleView.isSelectable = false
                
        scaleOnClick = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    func update(context: AccountContext, source: Source, animated: Bool, complete: @escaping()->Void) -> NSSize {
                
        self.timer?.invalidate()
        self.timer = .init(timeout: 5, repeat: false, completion: complete, queue: .mainQueue())
        self.timer?.start()
        
        
        self.setSingle(handler: { [weak self] _ in
            complete()
            self?.timer?.invalidate()
        }, for: .Click)
        
        
        switch source {
        case let .proccessing(message):
            
            if let view = imageView {
                performSubviewRemoval(view, animated: animated)
                self.imageView = view
            }
            
            if let view = viewMessage {
                performSubviewRemoval(view, animated: animated)
                self.viewMessage = view
            }
            
            do {
                let current: MediaAnimatedStickerView
                if let view = self.animationView {
                    current = view
                } else {
                    current = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 30, 30))
                    current.userInteractionEnabled = false
                    self.animationView = current
                    addSubview(current)
                    current.centerY(x: 10)
                }

                let params = LocalAnimatedSticker.improving_video.parameters
                params.colors = [.init(keyPath: "", color: NSColor(0xffffff))];
                current.update(with: LocalAnimatedSticker.improving_video.file, size: NSMakeSize(30, 30), context: context, table: nil, parameters: params, animated: animated)
            }
            
            do {
                let current: TextView
                if let view = self.infoView {
                    current = view
                } else {
                    current = TextView()
                    current.userInteractionEnabled = false
                    current.isSelectable = false
                    self.infoView = current
                    addSubview(current)
                    current.centerY(x: 50)
                }
                
                let text: String
                if message.forwardInfo != nil {
                    text = strings().chatVideoProccessingImprovingInfoForward
                } else {
                    text = strings().chatVideoProccessingImprovingInfo
                }
                
                let info: TextViewLayout = .init(.initialize(string: text, color: NSColor.white.withAlphaComponent(0.85), font: .normal(.text)))
                info.measure(width: 300)

                current.update(info)

                let title: TextViewLayout = .init(.initialize(string: strings().chatVideoProccessingImproving, color: .white, font: .medium(.text)), maximumNumberOfLines: 1)
                title.measure(width: 300)
                self.titleView.update(title)

            }
        case let  .published(message):
            if let view = animationView {
                performSubviewRemoval(view, animated: animated)
                self.animationView = view
            }
            if let view = infoView {
                performSubviewRemoval(view, animated: animated)
                self.infoView = view
            }
            
            do {
                let current: TransformImageView
                if let view = self.imageView {
                    current = view
                } else {
                    current = TransformImageView(frame: NSMakeRect(0, 0, 30, 30))
                    self.imageView = current
                    addSubview(current)
                    current.centerY(x: 10)
                }
                
                if let file = message.media.first as? TelegramMediaFile {
                    current.set(arguments: .init(corners: .init(radius: 4), imageSize: file.dimensions?.size ?? current.frame.size, boundingSize: current.frame.size, intrinsicInsets: .init()))
                    
                    current.setSignal(chatMessageVideo(account: context.account, fileReference: FileMediaReference.message(message: MessageReference(message), media: file), scale: backingScaleFactor))
                }
            }
            
            do {
                let current: TextButton
                if let view = self.viewMessage {
                    current = view
                } else {
                    current = TextButton()
                    self.viewMessage = current
                    current.autohighlight = false
                    current.scaleOnClick = true
                    addSubview(current)
                    current.centerY(x: 50)
                }
                
                current.set(font: .medium(.title), for: .Normal)
                current.set(color: theme.colors.accent, for: .Normal)
                current.set(text: strings().chatVideoProccessingPublishedView, for: .Normal)
                
                current.setSingle(handler: { _ in
                    if context.bindings.rootNavigation().controller is ChatScheduleController {
                        context.bindings.rootNavigation().back()
                    }
                    let controller = context.bindings.rootNavigation().controller as? ChatController
                    controller?.chatInteraction.focusMessageId(message.id, .init(messageId: message.id, string: nil), .CenterEmpty)
                }, for: .Click)
            }
            
            let title: TextViewLayout = .init(.initialize(string: strings().chatVideoProccessingPublished, color: .white, font: .medium(.text)), maximumNumberOfLines: 1)
            title.measure(width: 300)
            self.titleView.update(title)

        }
        
        var width: CGFloat = 10 + 30 + 10 + 10
        
        if let infoView {
            width += max(titleView.frame.width, infoView.frame.width)
        } else {
            width += titleView.frame.width
        }
        
        if let viewMessage {
            width += viewMessage.frame.width + 10
        }
        
        var height: CGFloat = 7 + 7 + titleView.frame.height
        if let infoView {
            height += infoView.frame.height + 3
        }
        
        let size = NSMakeSize(max(300, width), max(44, height))
                
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        
        
        updateLayout(size: size, transition: transition)
        
        return size
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: visualEffect, frame: size.bounds)
                
        if let animationView {
            transition.updateFrame(view: animationView, frame: animationView.centerFrameY(x: 10))
        }
        if let imageView {
            transition.updateFrame(view: imageView, frame: imageView.centerFrameY(x: 10))
        }
        
        if let infoView {
            transition.updateFrame(view: titleView, frame: titleView.rect(NSMakePoint(50, 7)))
            transition.updateFrame(view: infoView, frame: infoView.rect(NSMakePoint(50, size.height - infoView.frame.height - 7)))
        } else {
            transition.updateFrame(view: titleView, frame: titleView.centerFrameY(x: 50))
        }
        
        if let viewMessage {
            transition.updateFrame(view: viewMessage, frame: viewMessage.centerFrameY(x: size.width - 10 - viewMessage.frame.width))
        }
        
        
    }
}
