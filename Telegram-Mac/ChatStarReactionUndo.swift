//
//  ChatStarReactionUndo.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19.08.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import SwiftSignalKit

final class ChatStarReactionUndoView : Control {
    private let animationView: MediaAnimatedStickerView = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 30, 30))
    private let titleView = TextView()
    private let infoView = TextView()
    private let undo = TextView()
    private var timerAnimationView: InlineStickerView?
    
    private var timer: SwiftSignalKit.Timer?
    
    private var count: Int32 = 0
    private var messageId: EngineMessage.Id?
    private let visualEffect = NSVisualEffectView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(visualEffect)
        addSubview(animationView)
        addSubview(titleView)
        addSubview(infoView)
        addSubview(undo)
        
        visualEffect.material = .ultraDark
        visualEffect.blendingMode = .withinWindow
        visualEffect.state = .active
        
        
        self.layer?.cornerRadius = 10
        
        self.animationView.userInteractionEnabled = false
        self.titleView.userInteractionEnabled = false
        self.titleView.isSelectable = false
        self.infoView.userInteractionEnabled = false
        self.infoView.isSelectable = false
        self.undo.userInteractionEnabled = false
        self.undo.isSelectable = false
        
        let undo: TextViewLayout = .init(.initialize(string: strings().chatReactionUndo, color: darkAppearance.colors.accent, font: .medium(.title)), maximumNumberOfLines: 1)
        undo.measure(width: .greatestFiniteMagnitude)
        
        
        self.undo.update(undo)
        
        scaleOnClick = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    func update(context: AccountContext, messageId: EngineMessage.Id, count: Int32, animated: Bool, complete: @escaping()->Void, undo:@escaping()->Void) -> NSSize {
        
        
        
        self.animationView.update(with: LocalAnimatedSticker.star_currency_new.file, size: NSMakeSize(30, 30), context: context, table: nil, animated: animated)

        self.timerAnimationView?.removeFromSuperview()
        self.timerAnimationView = .init(account: context.account, file: LocalAnimatedSticker.countdown5s.file, size: NSMakeSize(30, 30), getColors: { _ in
            return [.init(keyPath: "", color: darkAppearance.colors.accent)]
        }, playPolicy: .onceEnd, controlContent: false)
        addSubview(self.timerAnimationView!)

        if self.messageId != messageId {
            self.count = count
        } else {
            self.count += count
        }
        
        self.messageId = messageId
        
        
        self.timer?.invalidate()
        self.timer = .init(timeout: 5, repeat: false, completion: complete, queue: .mainQueue())
        self.timer?.start()
        
        
        self.setSingle(handler: { [weak self] _ in
            undo()
            complete()
            self?.timer?.invalidate()
        }, for: .Click)
        
        let title: TextViewLayout = .init(.initialize(string: strings().chatReactionUndoStarsSent, color: .white, font: .medium(.text)), maximumNumberOfLines: 1)
        let info: TextViewLayout = .init(.initialize(string: strings().chatReactionUndoReactedCountable(Int(self.count)), color: NSColor.white.withAlphaComponent(0.7), font: .normal(.text)), maximumNumberOfLines: 1)
        
        title.measure(width: .greatestFiniteMagnitude)
        info.measure(width: .greatestFiniteMagnitude)
        
        self.titleView.update(title)
        self.infoView.update(info)
        
        let width = 10 + animationView.frame.width + 10 + max(titleView.frame.width, infoView.frame.width) + 10 + self.undo.frame.width + 5 + 30 + 10
        
        let size = NSMakeSize(width, 44)
        
        self.timerAnimationView?.centerY(x: size.width - 10 - 30)
        
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
        transition.updateFrame(view: animationView, frame: animationView.centerFrameY(x: 10))
        transition.updateFrame(view: titleView, frame: titleView.rect(NSMakePoint(animationView.frame.maxX + 10, 5)))
        transition.updateFrame(view: infoView, frame: infoView.rect(NSMakePoint(animationView.frame.maxX + 10, size.height - infoView.frame.height - 5)))
        if let timerAnimationView {
            transition.updateFrame(view: timerAnimationView, frame: timerAnimationView.centerFrameY(x: size.width - timerAnimationView.frame.width - 10))
            transition.updateFrame(view: undo, frame: undo.centerFrameY(x: timerAnimationView.frame.minX - undo.frame.width - 5))
        }
    }
}
