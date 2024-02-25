//
//  StoryChannelInputView.swift
//  Telegram
//
//  Created by Mike Renoir on 31.08.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TGModernGrowingTextView


private let share_image = NSImage(named: "Icon_StoryShare")!.precomposed(NSColor.white)
private let delete_image = NSImage(named: "Icon_StoryDelete")!.precomposed(NSColor.white)
private let like_image = NSImage(named: "Icon_StoryLike_Count")!.precomposed(NSColor.white)

private let view_image = NSImage(named: "Icon_Story_Viewers")!.precomposed(NSColor.white)

private let repost_image = NSImage(named: "Icon_Story_Repost")!.precomposed(NSColor.white)

final class StoryChannelInputView : Control, StoryInput {
    
    func like(_ like: StoryReactionAction, resetIfNeeded: Bool) {
        guard let arguments = self.arguments, let story = self.story else {
            return
        }
        let state = arguments.interaction.presentation
        if story.storyItem.myReaction == like.item.reaction || (resetIfNeeded && story.storyItem.myReaction != nil) {
            self.arguments?.like(nil, state)
        } else {
            self.arguments?.like(like.item.reaction, state)
            self.likeAction.react(like, state: state, context: arguments.context)
        }
    }
    

    private var photos:[PeerId]? = nil

    
    private let share = ImageButton()
    private let repost = ImageButton()
    private let views = Control()
    private let viewsText = TextView()
    
    private let likeAction = StoryLikeActionButton(frame: NSMakeRect(0, 0, 50, 50))

    private var likeCount: DynamicCounterTextView?
    private var shareCount: DynamicCounterTextView?

    private var arguments: StoryArguments?
    private var story: StoryContentItem?
    
    
    private let viewsImage = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer?.cornerRadius = 10
        addSubview(likeAction)
        addSubview(repost)
        addSubview(share)
        addSubview(views)
        views.addSubview(viewsImage)
        views.addSubview(viewsText)
        
        viewsImage.image = view_image
        viewsImage.sizeToFit()
        
        self.layer?.masksToBounds = false
        
        viewsText.isSelectable = false
        
        repost.scaleOnClick = true
        repost.autohighlight = false

        
        share.scaleOnClick = true
        share.autohighlight = false
        
        likeAction.scaleOnClick = true
        
        share.set(image: share_image, for: .Normal)
        share.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)
                
        repost.set(image: repost_image, for: .Normal)
        repost.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)

        repost.set(handler: { [weak self] _ in
            if let story = self?.story {
                self?.arguments?.repost(story)
            }
        }, for: .Click)
        
        share.set(handler: { [weak self] _ in
            if let story = self?.story {
                self?.arguments?.share(story)
            }
        }, for: .Click)
        
        likeAction.set(handler: { [weak self] control in
            self?.like(.init(item: .builtin("❤️".withoutColorizer), fromRect: nil), resetIfNeeded: true)
        }, for: .Click)
        
        likeAction.set(handler: { [weak self] control in
            guard let arguments = self?.arguments, let story = self?.story else {
                return
            }
            arguments.showLikePanel(control, story)
        }, for: .RightDown)
        
        viewsText.set(handler: { [weak self ] _ in
            guard let arguments = self?.arguments, let story = self?.story else {
                return
            }
            arguments.showViewers(story)
        }, for: .Click)
        
        self.views.userInteractionEnabled = false
        self.views.scaleOnClick = true
    }
    
    var inputReactionsControl: Control? {
        return self.likeAction
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setArguments(_ arguments: StoryArguments?, groupId: PeerId?) {
        self.arguments = arguments
        
    }
    
    func update(_ story: StoryContentItem, animated: Bool) {
        self.story = story
        
        guard let arguments = self.arguments else {
            return
        }
        self.updateState(arguments.interaction.presentation, animated: animated)
    }
    
    func updateState(_ state: StoryInteraction.State, animated: Bool) {
        if let story = self.story, let arguments = self.arguments {
            
            let storyViews = story.storyItem.views
            var reactedCount = storyViews?.reactedCount ?? 0
            let forwardedCount = storyViews?.forwardCount ?? 0
            if story.storyItem.myReaction != nil, reactedCount == 0 {
                reactedCount = 1
            }
            let seenCount = storyViews?.seenCount ?? 0
            
            
            let text: NSAttributedString = .initialize(string: seenCount.prettyNumber, color: darkAppearance.colors.text, font: .normal(.header))
            let layout = TextViewLayout(text)
            layout.measure(width: .greatestFiniteMagnitude)
            self.viewsText.update(layout)
            
            
            self.likeAction.update(story, state: state, context: arguments.context, animated: animated)
            
            if reactedCount > 0 {
                let current: DynamicCounterTextView
                var isNew = false
                if let view = self.likeCount {
                    current = view
                } else {
                    current = DynamicCounterTextView(frame: .zero)
                    self.likeCount = current
                    self.addSubview(current)
                    isNew = true
                }
                let text = DynamicCounterTextView.make(for: reactedCount.prettyNumber, count: "\(reactedCount)", font: .normal(.header), textColor: .white, width: .greatestFiniteMagnitude)
                current.update(text, animated: animated && !isNew)
                current.change(size: text.size, animated: animated && !isNew)

                if isNew {
                    current.centerY(x: frame.width - current.frame.width - 16)
                }
            } else if let view = self.likeCount {
                performSubviewRemoval(view, animated: animated)
                self.likeCount = nil
            }
            
            if forwardedCount > 0 {
                let current: DynamicCounterTextView
                var isNew = false
                if let view = self.shareCount {
                    current = view
                } else {
                    current = DynamicCounterTextView(frame: .zero)
                    self.shareCount = current
                    self.addSubview(current)
                    isNew = true
                }
                let text = DynamicCounterTextView.make(for: forwardedCount.prettyNumber, count: "\(forwardedCount)", font: .normal(.header), textColor: .white, width: .greatestFiniteMagnitude)
                current.update(text, animated: animated && !isNew)
                current.change(size: text.size, animated: animated && !isNew)

                if isNew {
                    current.centerY(x: share.frame.maxX + 10)
                }
            } else if let view = self.shareCount {
                performSubviewRemoval(view, animated: animated)
                self.shareCount = nil
            }
        }
        
        
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        self.updateLayout(size: self.frame.size, transition: transition)
    }
    
    func updateInputText(_ state: ChatTextInputState, prevState: ChatTextInputState, animated: Bool) {
        
    }
    
    func updateInputState(animated: Bool) {
        guard let superview = self.superview else {
            return
        }
        updateInputSize(size: NSMakeSize(superview.frame.width, 30), animated: animated)
    }
    
    func installInputStateUpdate(_ f: ((StoryInputState) -> Void)?) {
        
    }
    
    func updateInputContext(with result:ChatPresentationInputQueryResult?, context: InputContextHelper, animated:Bool) {
        
    }
    
    
    func resetInputView() {
        
    }
    
    var isFirstResponder: Bool {
        return false
    }
    
    var text: UITextView? {
        return nil
    }
    
    var input: NSTextView? {
        return nil
    }
    
    
    private func updateInputSize(size: NSSize, animated: Bool) {
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        guard let superview = superview, let window = self.window else {
            return
        }
        
        let wSize = NSMakeSize(window.frame.width - 100, superview.frame.height - 110)
        let aspect = StoryLayoutView.size.aspectFitted(wSize)

        transition.updateFrame(view: self, frame: CGRect(origin: CGPoint(x: floorToScreenPixels(backingScaleFactor,  (superview.frame.width - size.width) / 2), y: aspect.height + 10 - size.height + 30), size: size))
        self.updateLayout(size: size, transition: transition)

    }

    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        if let likeCount = self.likeCount {
            transition.updateFrame(view: likeCount, frame: likeCount.centerFrameY(x: size.width - likeCount.frame.width - 16))
            transition.updateFrame(view: likeAction, frame: likeAction.centerFrameY(x: likeCount.frame.minX - likeAction.frame.width + 5))
        } else {
            transition.updateFrame(view: likeAction, frame: likeAction.centerFrameY(x: size.width - likeAction.frame.width))
        }
        if let shareCount = shareCount {
            transition.updateFrame(view: shareCount, frame: shareCount.centerFrameY(x: likeAction.frame.minX - shareCount.frame.width + 5))
            transition.updateFrame(view: repost, frame: repost.centerFrameY(x: shareCount.frame.minX - repost.frame.width - 5))
            transition.updateFrame(view: share, frame: share.centerFrameY(x: repost.frame.minX - share.frame.width - 10))
        } else {
            transition.updateFrame(view: repost, frame: repost.centerFrameY(x: likeAction.frame.minX - repost.frame.width))
            transition.updateFrame(view: share, frame: share.centerFrameY(x: repost.frame.minX - share.frame.width - 10))
        }
        
        
        
        let viewsRect = NSMakeRect(16, 0, viewsText.frame.width + 4 + viewsImage.frame.width, size.height)
        transition.updateFrame(view: views, frame: viewsRect)
        transition.updateFrame(view: viewsImage, frame: viewsImage.centerFrameY(x: 0))
        transition.updateFrame(view: viewsText, frame: viewsText.centerFrameY(x: viewsImage.frame.maxX + 4))
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
}
