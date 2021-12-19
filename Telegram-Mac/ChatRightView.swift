//
//  RIghtView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 22/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore





class ChatRightView: View, ViewDisplayDelegate {
    
    
    struct Frames {
        private(set) var state:NSRect?
        private(set) var read:NSRect?
        private(set) var sending:NSRect?
        private(set) var reactions: NSRect?
        private(set) var replyCount: NSRect?
        private(set) var viewsCount: NSRect?
        private(set) var viewsImage: NSRect?
        private(set) var postAuthor: NSRect?
        private(set) var pin: NSRect?
        private(set) var edit: NSRect?
        private(set) var date: NSRect?
        private let isStateOverlay: Bool
        init(_ item: ChatRowItem, size: NSSize) {
            
            self.isStateOverlay = item.isStateOverlayLayout
            let stateIsEnd = item.isBubbled && !item.isIncoming
                        
            var x: CGFloat = item.isStateOverlayLayout ? 4 : 0
            
            if let reactions = item.reactionsLayout {
                switch reactions.mode {
                case .short:
                    var rect = size.bounds.focus(reactions.size)
                    rect.origin.y -= 1
                    rect.origin.x = x
                    self.reactions = rect
                    x = rect.maxX
                default:
                    break
                }
            }
            
            if item.isPinned {
                var rect = size.bounds.focus(item.presentation.chat.messagePinnedIcon(item).backingSize)
                rect.origin.x = x + 2
                self.pin = rect
                x = rect.maxX
            }
            
            if let views = item.channelViews {
                var rect_i = size.bounds.focus(item.presentation.chat.channelViewsIcon(item).backingSize)
                rect_i.origin.x = x + 2
                x = rect_i.maxX
                var rect_t = size.bounds.focus(views.layoutSize)
                rect_t.origin.x = x + 2
                x = rect_t.maxX
                
                self.viewsImage = rect_i
                self.viewsCount = rect_t
            }
            
            if let postAuthor = item.postAuthor {
                var rect = size.bounds.focus(postAuthor.layoutSize)
                rect.origin.x = x + 2
                self.postAuthor = rect
                x = rect.maxX
            }
            
            if let editLabel = item.editedLabel {
                var rect = size.bounds.focus(editLabel.layoutSize)
                rect.origin.x = x + 2
                self.edit = rect
                x = rect.maxX
            }
            
            if stateIsEnd {
                self.date = makeDate(item, size, &x)
            }
            
            self.state = makeState(item, size, &x)
            self.read = makeRead(item, size, &x)
            self.sending = makeSending(item, size, &x)
            
            if !stateIsEnd {
                if self.read == nil {
                    x += 4
                }
                self.date = makeDate(item, size, &x)
            }
        }
        
        private func makeDate(_ item: ChatRowItem, _ size: NSSize, _ x: inout CGFloat) -> NSRect? {
            if let date = item.date {
                var rect = size.bounds.focus(date.layoutSize)
                rect.origin.x = x + 2
                x = rect.maxX
                return rect
            }
            return nil
        }
        
        private func makeState(_ item: ChatRowItem, _ size: NSSize, _ x: inout CGFloat) -> CGRect? {
            let hasState = !item.isIncoming && !item.isUnsent && !item.isFailed && !item.chatInteraction.isLogInteraction
            if hasState {
                var rect = size.bounds.focus(item.presentation.chat.stateStateIcon(item).backingSize)
                rect.origin.x = x + 2
                x = rect.maxX
                return rect
            }
            return nil
        }
        private func makeRead(_ item: ChatRowItem, _ size: NSSize, _ x: inout CGFloat) -> CGRect? {
            let hasState = !item.isIncoming && !item.isUnsent && !item.isFailed && !item.chatInteraction.isLogInteraction
            let hasRead = hasState && item.isRead && !item.hasSource
            if hasRead {
                var rect = size.bounds.focus(item.presentation.chat.readStateIcon(item).backingSize)
                rect.origin.x = x - 8
                x = rect.maxX
                return rect
            }
            return nil
        }
        private func makeSending(_ item: ChatRowItem, _ size: NSSize, _ x: inout CGFloat) -> CGRect? {
            let isSending = item.isUnsent && !item.isFailed
            if isSending {
                var rect = size.bounds.focus(NSMakeSize(12, 12))
                rect.origin.x = x + 2
                x = rect.maxX
                return rect
            }
            return nil
        }
        
        var width: CGFloat {
            let rects = [self.state,
                         self.read,
                         self.sending,
                         self.reactions,
                         self.replyCount,
                         self.viewsCount,
                         self.viewsImage,
                         self.postAuthor,
                         self.pin,
                         self.edit,
                         self.date].compactMap { $0 }
            
            var max = rects.max(by: { $0.maxX < $1.maxX }) ?? .zero
            if max == self.state || max == self.sending {
                max.origin.x += 4
            }
            if isStateOverlay {
                return max.maxX + 6
            } else {
                return max.maxX
            }
                
        }
    }
    
    private var visualEffect: VisualEffect? = nil
    public var blurBackground: NSColor? = nil {
        didSet {
            updateBackgroundBlur()
            if blurBackground != nil {
                self.backgroundColor = .clear
            }
        }
    }
    
    private func updateBackgroundBlur() {
        if let blurBackground = blurBackground {
            if self.visualEffect == nil {
                self.visualEffect = VisualEffect(frame: self.bounds)
                addSubview(self.visualEffect!, positioned: .below, relativeTo: self.subviews.first)
            }
            self.visualEffect?.bgColor = blurBackground
        } else {
            self.visualEffect?.removeFromSuperview()
            self.visualEffect = nil
        }
        needsLayout = true
    }
    
    private var stateView:ImageView?
    private var readImageView:ImageView?
    private var sendingView:SendingClockProgress?
    private var reactionsView: ChatReactionsView?
    private var replyCountView: TextView?
    private var viewsCountView: TextView?
    private var viewsImageView: ImageView?
    private var postAuthorView: TextView?
    private var pinView: ImageView?
    private var editView: TextView?
    private var dateView: TextView?
    
    private weak var item:ChatRowItem?
    
    var isReversed: Bool {
        guard let item = item else {return false}
        return item.isBubbled && !item.isIncoming
    }
    
    private var stacked: [Frames] = []
    
    func set(item:ChatRowItem, animated:Bool) {
                
        self.item = item
        self.toolTip = item.fullDate
        item.updateTooltip = { [weak self] value in
            self?.toolTip = value
        }
        
        guard let frames = item.rightFrames else {
            return
        }
        
        let findState:([Frames])->NSRect? = { stake in
            for value in stake.reversed() {
                if value.state != nil {
                    return value.state
                }
            }
            return nil
        }
        let findSending:([Frames])->NSRect? = { stake in
            for value in stake.reversed() {
                if value.sending != nil {
                    return value.sending
                }
            }
            return nil
        }
        
        
        if let reactionsLayout = item.reactionsLayout, reactionsLayout.mode == .short, let reactionsRect = frames.reactions {
            if self.reactionsView == nil {
                self.reactionsView = ChatReactionsView(frame: reactionsRect)
                addSubview(self.reactionsView!)
                if animated {
                    self.reactionsView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    self.reactionsView?.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
                }
            }
            self.reactionsView?.update(with: reactionsLayout, animated: animated)
        } else {
            if let view = self.reactionsView {
                self.reactionsView = nil
                performSubviewRemoval(view, animated: animated)
                view.layer?.animateScaleCenter(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
            }
        }
        if let sendingRect = frames.sending {
            if self.sendingView == nil {
                self.sendingView = SendingClockProgress(frame: findState(stacked) ?? sendingRect)
                addSubview(sendingView!)
                if animated {
                    self.sendingView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    self.sendingView?.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
                }
            }
            let f = item.presentation.chat.sendingFrameIcon(item)
            let h = item.presentation.chat.sendingHourIcon(item)
            let m = item.presentation.chat.sendingMinIcon(item)

            self.sendingView?.set(frame: f, hour: h, minute: m)
        } else {
            if let view = self.sendingView {
                self.sendingView = nil
                performSubviewRemoval(view, animated: animated)
                view.layer?.animateScaleCenter(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
            }
        }
        
                
        if let stateRect = frames.state {
            if self.stateView == nil {
                stateView = ImageView(frame: findSending(stacked) ?? stateRect)
                self.addSubview(stateView!)
                if animated {
                    self.stateView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    self.stateView?.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
                }
            }
            let stateImage = item.presentation.chat.stateStateIcon(item)
            stateView?.image = stateImage
            stateView?.sizeToFit()
        } else {
            if let view = self.stateView {
                self.stateView = nil
                performSubviewRemoval(view, animated: animated)
                view.layer?.animateScaleCenter(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
            }
        }
        if let readRect = frames.read {
            if readImageView == nil {
                readImageView = ImageView(frame: readRect)
                addSubview(readImageView!)
                if animated {
                    self.readImageView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    self.readImageView?.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
                }
            }
            self.readImageView?.image = item.presentation.chat.readStateIcon(item)
            self.readImageView?.sizeToFit()
        } else {
            if let view = self.readImageView {
                self.readImageView = nil
                performSubviewRemoval(view, animated: animated)
                view.layer?.animateScaleCenter(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
            }
        }
        
        if let pinRect = frames.pin {
            if self.pinView == nil {
                self.pinView = ImageView(frame: pinRect)
                addSubview(self.pinView!)
                if animated {
                    self.pinView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    self.pinView?.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
                }
            }
            self.pinView?.image = item.presentation.chat.messagePinnedIcon(item)
            self.pinView?.sizeToFit()
        } else {
            if let view = self.pinView {
                self.pinView = nil
                performSubviewRemoval(view, animated: animated)
                view.layer?.animateScaleCenter(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
            }
        }
        
        if let date = item.date, let dateRect = frames.date {
            if self.dateView == nil {
                self.dateView = TextView(frame: dateRect)
                self.dateView?.userInteractionEnabled = false
                self.dateView?.isSelectable = false
                addSubview(self.dateView!)
                if animated {
                    self.dateView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    self.dateView?.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
                }
            }
            self.dateView?.update(date)
        } else {
            if let view = self.dateView {
                self.dateView = nil
                performSubviewRemoval(view, animated: animated)
                view.layer?.animateScaleCenter(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
            }
        }
        
        if let editedLabel = item.editedLabel, let editRect = frames.edit {
            if self.editView == nil {
                self.editView = TextView(frame: editRect)
                self.editView?.userInteractionEnabled = false
                self.editView?.isSelectable = false
                addSubview(self.editView!)
                if animated {
                    self.editView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    self.editView?.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
                }
            }
            self.editView?.update(editedLabel)
        } else {
            if let view = self.editView {
                self.editView = nil
                performSubviewRemoval(view, animated: animated)
                view.layer?.animateScaleCenter(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
            }
        }
        if let channelViews = item.channelViews, let viewsImageRect = frames.viewsImage, let viewsCountRect = frames.viewsCount {
            if self.viewsCountView == nil {
                self.viewsCountView = TextView(frame: viewsCountRect)
                self.viewsCountView?.userInteractionEnabled = false
                self.viewsCountView?.isSelectable = false
                addSubview(self.viewsCountView!)
                if animated {
                    self.viewsCountView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    self.viewsCountView?.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
                }
            }
            self.viewsCountView?.update(channelViews)
            
            if self.viewsImageView == nil {
                self.viewsImageView = ImageView(frame: viewsImageRect)
                addSubview(self.viewsImageView!)
                if animated {
                    self.viewsImageView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    self.viewsImageView?.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
                }
            }
            self.viewsImageView?.image = item.presentation.chat.channelViewsIcon(item)
            self.viewsImageView?.sizeToFit()
            
        } else {
            if let view = self.viewsCountView {
                self.viewsCountView = nil
                performSubviewRemoval(view, animated: animated)
                view.layer?.animateScaleCenter(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
            }
            if let view = self.viewsImageView {
                self.viewsImageView = nil
                performSubviewRemoval(view, animated: animated)
                view.layer?.animateScaleCenter(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
            }
        }
        
        if let postAuthor = item.postAuthor, let postAuthorRect = frames.postAuthor {
            if self.postAuthorView == nil {
                self.postAuthorView = TextView(frame: postAuthorRect)
                self.postAuthorView?.userInteractionEnabled = false
                self.postAuthorView?.isSelectable = false
                addSubview(self.postAuthorView!)
                if animated {
                    self.postAuthorView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    self.postAuthorView?.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
                }
            }
            self.postAuthorView?.update(postAuthor)
        } else {
            if let view = self.postAuthorView {
                self.postAuthorView = nil
                performSubviewRemoval(view, animated: animated)
                view.layer?.animateScaleCenter(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
            }
        }
        
        stacked.append(frames)
        
    }
    
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        if let visualEffect = visualEffect {
            transition.updateFrame(view: visualEffect, frame: size.bounds)
        }
        if let visualEffect = visualEffect {
            transition.updateFrame(view: visualEffect, frame: size.bounds)
        }
        
        guard let item = self.item else {
            return
        }
        
        guard let frames = item.rightFrames else {
            return
        }
        
        
        if let frame = frames.reactions, let view = reactionsView {
            transition.updateFrame(view: view, frame: frame)
        }
        if let frame = frames.pin, let view = pinView {
            transition.updateFrame(view: view, frame: frame)
        }
        if let frame = frames.edit, let view = editView {
            transition.updateFrame(view: view, frame: frame)
        }
        if let frame = frames.state, let view = stateView {
            transition.updateFrame(view: view, frame: frame)
        }
        if let frame = frames.read, let view = readImageView {
            transition.updateFrame(view: view, frame: frame)
        }
        if let frame = frames.date, let view = dateView {
            transition.updateFrame(view: view, frame: frame)
        }
        if let frame = frames.postAuthor, let view = postAuthorView {
            transition.updateFrame(view: view, frame: frame)
        }
        if let frame = frames.sending, let view = sendingView {
            transition.updateFrame(view: view, frame: frame)
        }
        if let frame = frames.viewsImage, let view = viewsImageView {
            transition.updateFrame(view: view, frame: frame)
        }
        if let frame = frames.viewsCount, let view = viewsCountView {
            transition.updateFrame(view: view, frame: frame)
        }
        if let frame = frames.viewsImage, let view = viewsImageView {
            transition.updateFrame(view: view, frame: frame)
        }
        if let frame = frames.replyCount, let view = replyCountView {
            transition.updateFrame(view: view, frame: frame)
        }
    }

    override func layout() {
        super.layout()
        
        updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    
    
    override func mouseUp(with event: NSEvent) {
        superview?.mouseUp(with: event)
    }
    
}
