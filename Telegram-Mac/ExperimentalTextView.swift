//
//  ExperimentalTextView.swift
//  Telegram
//
//  Created by Mike Renoir on 06.10.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import InputView



final class ExperimentalTextView: Control {
    
    
    private let view: UITextView
    private let context: AccountContext
    required init(frame frameRect: NSRect, context: AccountContext, interactions: TextView_Interactions) {
        self.context = context
        self.view = UITextView(frame: frameRect.size.bounds, context: context, interactions: interactions)
        super.init(frame: frameRect)
        addSubview(view)
        
        
        interactions.inputDidUpdate = { [weak self] _ in
            guard let `self` = self else {
                return
            }
            self.updateLayout(size: self.frame.size, transition: .animated(duration: 0.2, curve: .easeOut))
        }
        
        set(handler: { [weak self] control in
            guard let `self` = self else {
                return
            }
            let context = self.context
            
            let controller = EmojiesController(context, mode: .emoji)
            let interactions = EntertainmentInteractions(.emoji, peerId: context.peerId)
            interactions.sendAnimatedEmoji = { [weak self] item, info, _, _ in
                                
                let emoji = NSMutableAttributedString(string: "🤡")
                emoji.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: info?.id, fileId: item.file.fileId.id, file: item.file, topicInfo: nil), range:emoji.range)
                
                self?.view.insertText(emoji)

            }
            interactions.sendEmoji = { [weak self] emoji, _ in
                self?.view.insertText(.init(string: emoji))
            }
            
            controller.update(with: interactions, chatInteraction: .init(chatLocation: .peer(context.peerId), context: context))
            
            showPopover(for: control, with: controller, edge: .maxY, inset: NSMakePoint(-80, -35), static: true, animationMode: .classic)

        }, for: .RightDown)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        let textHeight = view.height(for: size.width)
        let viewHeight = min(max(textHeight, 50), self.view.inputMaximumHeight())
        
        let viewRect = NSMakeRect(0, size.height - viewHeight, size.width, viewHeight)
        transition.updateFrame(view: view, frame: viewRect)
        view.updateLayout(size: viewRect.size, textHeight: textHeight, transition: transition)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}

private final class Arguments {
    let context: AccountContext
    let interactions: TextView_Interactions
    init(context: AccountContext, interactions: TextView_Interactions) {
        self.context = context
        self.interactions = interactions
    }
}


final class ExperimentalTextController : TelegramGenericViewController<ExperimentalTextView> {
    
    private let arguments: Arguments
    override init(_ context: AccountContext) {
        self.arguments = .init(context: context, interactions: .init(presentation: .init()))
        super.init(context)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.readyOnce()
    }
    
    override func initializer() -> ExperimentalTextView {
        return ExperimentalTextView(frame: _frameRect, context: self.context, interactions: arguments.interactions)
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    override func nextKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
}
