//
//  ShareStoryController.swift
//  Telegram
//
//  Created by Mike Renoir on 22.11.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import SwiftSignalKit
import TGUIKit
import Postbox
import InputView

private final class RepostStoryView : Control {
    private var layoutView: StoryLayoutView!
    private let headerView = View(frame: NSMakeRect(0, 0, 50, 50))
    
    fileprivate let dismiss = ImageButton()
    fileprivate let privacy = TextButton()
    
    fileprivate let textView = UITextView(frame: .zero)
    private let bottomView = View(frame: NSMakeRect(0, 0, 50, 50))
    
    fileprivate let actionsContainerView: View = View()
    fileprivate let sendButton = ImageButton()
    fileprivate let emojiButton = ImageButton()
    private let bottomBorder = View()

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        headerView.addSubview(dismiss)
        headerView.addSubview(privacy)
        addSubview(headerView)
        bottomView.addSubview(textView)
        addSubview(bottomView)
        
        bottomView.addSubview(bottomBorder)
        
        
        textView.placeholder = strings().previewSenderCaptionPlaceholder
        
        _ = emojiButton.sizeToFit()
        
        
        actionsContainerView.addSubview(sendButton)
        actionsContainerView.addSubview(emojiButton)
        
        
        self.addSubview(actionsContainerView)
        
        privacy.autohighlight = false
        privacy.scaleOnClick = true
        
        dismiss.autohighlight = false
        dismiss.scaleOnClick = true
        
        textView.interactions.max_height = 180
        textView.interactions.min_height = 50

        emojiButton.autohighlight = false
        emojiButton.scaleOnClick = true
        
        sendButton.autohighlight = false
        sendButton.scaleOnClick = true

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func initalize(context: AccountContext, story: StoryContentItem, presentation: TelegramPresentationTheme) {
        guard let peerId = story.peerId else {
            return
        }
        
        textView.inputTheme = presentation.inputTheme
        
        let size = NSMakeSize(context.window.frame.width - 200, context.window.frame.height - 200)
        let aspect = StoryLayoutView.size.aspectFitted(size)
        
        self.layoutView = StoryLayoutView.makeView(for: story.storyItem, peerId: peerId, peer: story.peer?._asPeer(), context: context, frame: aspect.bounds)
        
        addSubview(self.layoutView, positioned: .below, relativeTo: headerView)

        
        dismiss.set(image: presentation.icons.modalClose, for: .Normal)
        dismiss.sizeToFit()
        
        
        privacy.set(font: .medium(.title), for: .Normal)
        privacy.set(background: presentation.colors.accent.withAlphaComponent(0.2), for: .Normal)
        privacy.set(color: presentation.colors.accent, for: .Normal)
        privacy.set(text: "Everyone", for: .Normal)
        privacy.sizeToFit(NSMakeSize(20, 10))
        privacy.layer?.cornerRadius = privacy.frame.height / 2
        
        bottomView.backgroundColor = presentation.colors.background
        bottomBorder.backgroundColor = presentation.colors.border
        
        
        sendButton.set(image: presentation.icons.chatSendMessage, for: .Normal)
        _ = sendButton.sizeToFit()
        
        emojiButton.set(image: presentation.icons.chatEntertainment, for: .Normal)
        emojiButton.sizeToFit()
        
        actionsContainerView.setFrameSize(sendButton.frame.width + emojiButton.frame.width + 40, 50)
        
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: headerView, frame: CGRect(x: 0, y: 0, width: size.width, height: 50))
        transition.updateFrame(view: dismiss, frame: dismiss.centerFrameY(x: 10))
        transition.updateFrame(view: privacy, frame: privacy.centerFrameY(x: size.width - privacy.frame.width - 10))
        
        let heights = headerView.frame.height + 50 + 10
        let aspect = StoryLayoutView.size.aspectFitted(NSMakeSize(min(350, size.width), size.height - heights))
        transition.updateFrame(view: self.layoutView, frame: CGRect(origin: NSMakePoint((size.width - aspect.width) / 2, headerView.frame.maxY), size: aspect))
        
        
        
        let (textSize, textHeight) = textViewSize()
        
        let textContainerRect = NSMakeRect(0, size.height - textSize.height, size.width, textSize.height)
        transition.updateFrame(view: bottomView, frame: textContainerRect)
        
        transition.updateFrame(view: bottomBorder, frame: CGRect(origin: .zero, size: CGSize.init(width: size.width, height: .borderSize)))
        
        transition.updateFrame(view: textView, frame: CGRect(origin: CGPoint(x: 10, y: 0), size: textSize))
        textView.updateLayout(size: textSize, textHeight: textHeight, transition: transition)


        
        transition.updateFrame(view: actionsContainerView, frame: CGRect(origin: NSMakePoint(size.width - actionsContainerView.frame.width, size.height - actionsContainerView.frame.height), size: actionsContainerView.frame.size))
        transition.updateFrame(view: emojiButton, frame: emojiButton.centerFrameY(x: 0))
        transition.updateFrame(view: sendButton, frame: sendButton.centerFrameY(x: emojiButton.frame.maxX + 20))
    }
    
    func size(_ size: NSSize) -> NSSize {
        let heights = headerView.frame.height + 60
        let aspect = StoryLayoutView.size.aspectFitted(NSMakeSize(min(320, size.width), size.height - heights - 100))
        return NSMakeSize(aspect.width + 20, aspect.height + heights)
    }
    
    func textViewSize() -> (NSSize, CGFloat) {
        let w = textWidth
        let height = self.textView.height(for: w)
        return (NSMakeSize(w, min(max(height, textView.min_height), textView.max_height)), height)
    }
    var textWidth: CGFloat {
        return frame.width - 10 - actionsContainerView.frame.width
    }
}

final class ShareStoryController : ModalViewController, Notifable {
    private let context: AccountContext
    private let story: StoryContentItem
    private let presentation: TelegramPresentationTheme
    private let contextChatInteraction: ChatInteraction
    private let emoji: EmojiesController

    init(context: AccountContext, story: StoryContentItem, presentation: TelegramPresentationTheme) {
        self.context = context
        self.story = story
        self.presentation = presentation
        self.contextChatInteraction = .init(chatLocation: .peer(context.peerId), context: context)
        self.emoji = EmojiesController(context, presentation: presentation)
        super.init()
        
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? ShareStoryController {
            return other === self
        } else {
            return false
        }
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
           
           if value.effectiveInput != oldValue.effectiveInput {
               let input = value.effectiveInput
               genericView.textView.set(input)
               
               self.genericView.textView.scrollToCursor()
           }
       }
    }
    
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func measure(size: NSSize) {
        self.modal?.resize(with: genericView.size(size), animated: false)
    }
    
    public func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with: genericView.size(contentSize), animated: animated)
        }
    }
    override var modalTheme: ModalViewController.Theme {
        return .init(presentation: presentation)
    }
    override var containerBackground: NSColor {
        return presentation.colors.background
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let context = self.context
        let presentation = self.presentation
        let story = self.story
        
        contextChatInteraction.add(observer: self)
        
        let interactions = EntertainmentInteractions(.emoji, peerId: contextChatInteraction.peerId)
        
        interactions.sendEmoji = { [weak self] emoji, fromRect in
            _ = self?.contextChatInteraction.appendText(.initialize(string: emoji))
            _ = self?.window?.makeFirstResponder(self?.genericView.textView.inputView)
        }
        interactions.sendAnimatedEmoji = { [weak self] sticker, _, _, fromRect in
            let text = (sticker.file.customEmojiText ?? sticker.file.stickerText ?? clown).fixed
            _ = self?.contextChatInteraction.appendText(.makeAnimated(sticker.file, text: text))
            _ = self?.window?.makeFirstResponder(self?.genericView.textView.inputView)
        }
        
        emoji.update(with: interactions, chatInteraction: contextChatInteraction)

        
        genericView.initalize(context: context, story: story, presentation: presentation)
        
        self.genericView.textView.interactions.inputDidUpdate = { [weak self] state in
            guard let `self` = self else {
                return
            }
            self.set(state)
            self.inputDidUpdateLayout(animated: true)
        }
        
        self.genericView.textView.interactions.processAttriburedCopy = { attributedString in
            return globalLinkExecutor.copyAttributedString(attributedString)
        }
        
        self.genericView.emojiButton.set(handler: { [weak self] control in
            if let emoji = self?.emoji {
                showPopover(for: control, with: emoji)
            }
        }, for: .Hover)
        
        self.genericView.sendButton.set(handler: { [weak self] _ in
            
        }, for: .SingleClick)
        
        self.genericView.privacy.set(handler: { _ in
            showModal(with: StoryPrivacyModalController(context: context, presentation: presentation, reason: .share(story)), for: context.window)
        }, for: .Click)
        
        readyOnce()
    }
    
   
    
    
    private func set(_ state: Updated_ChatTextInputState) {
        self.contextChatInteraction.update({
            $0.withUpdatedEffectiveInputState(state.textInputState())
        })
    }
    
    private func inputDidUpdateLayout(animated: Bool) {
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        self.genericView.updateLayout(size: self.genericView.frame.size, transition: transition)
    }
    

    override var hasBorder: Bool {
        return false
    }
    
    override func viewClass() -> AnyClass {
        return RepostStoryView.self
    }
    private var genericView: RepostStoryView {
        return self.view as! RepostStoryView
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.textView.inputView
    }
}
