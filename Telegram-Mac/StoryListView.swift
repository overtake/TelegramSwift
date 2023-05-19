//
//  StoryContainerView.swift
//  Telegram
//
//  Created by Mike Renoir on 25.04.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import TGModernGrowingTextView



final class StoryListView : Control, Notifable {
    

    enum UpdateIndexResult {
        case invoked
        case moveBack
        case moveNext
    }
    
    struct TransitionData {
        let direction: TranslateDirection
        let animateContainer: LayerBackedView
        let view1: LayerBackedView
        let view2: LayerBackedView
        let previous: StoryListView
    }
    
    fileprivate var transition: TransitionData?

    var storyId: Int32? {
        if let selectedIndex = self.selectedIndex, let entry = entry {
            return entry.item.items[selectedIndex].id
        }
        return nil
    }
    var id: PeerId? {
        return self.entry?.id
    }
    
    private class Text : Control {
        
        enum State : Equatable {
            case concealed
            case revealed
        }
        
        var state: State = .concealed
        
        private let scrollView = ScrollView()
        private var textView: TextView?
        private let documentView = View()
        private let container = Control()
        
        private var inlineStickerItemViews: [InlineStickerItemLayer.Key: InlineStickerItemLayer] = [:]
        
        required init(frame frameRect: NSRect) {
            scrollView.background = NSColor.blackTransparent
            super.init(frame: frameRect)
            addSubview(container)
            container.addSubview(self.scrollView)
            self.scrollView.documentView = documentView
            
            
            self.layer?.cornerRadius = 10
        }
        
        override func layout() {
            super.layout()
            self.updateLayout(size: frame.size, transition: .immediate)
        }
        
        func update(text: String, entities: [MessageTextEntity], context: AccountContext, state: State, transition: ContainedViewLayoutTransition, toggleState: @escaping(State)->Void, arguments: StoryArguments?) -> NSSize {
            
            self.state = state
            
            let attributed = ChatMessageItem.applyMessageEntities(with: [TextEntitiesMessageAttribute(entities: entities)], for: text, message: nil, context: context, fontSize: storyTheme.fontSize, openInfo: { [weak arguments] peerId, toChat, messageId, initialAction in
                if toChat {
                    arguments?.openChat(peerId, messageId, initialAction)
                } else {
                    arguments?.openPeerInfo(peerId)
                }
            }, textColor: storyTheme.colors.text, linkColor: storyTheme.colors.link, monospacedPre: storyTheme.colors.text, monospacedCode: storyTheme.colors.text).mutableCopy() as! NSMutableAttributedString
            
            

            
            var spoilers:[TextViewLayout.Spoiler] = []
            for entity in entities {
                switch entity.type {
                case .Spoiler:
                    let color: NSColor = storyTheme.colors.text
                    let range = NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound)
                    if let range = attributed.range.intersection(range) {
                        attributed.addAttribute(.init(rawValue: TGSpoilerAttributeName), value: TGInputTextTag(uniqueId: arc4random64(), attachment: NSNumber(value: -1), attribute: TGInputTextAttribute(name: NSAttributedString.Key.foregroundColor.rawValue, value: color)), range: range)
                    }
                default:
                    break
                }
            }
            InlineStickerItem.apply(to: attributed, associatedMedia: [:], entities: entities, isPremium: context.isPremium)
            
            
            attributed.enumerateAttribute(.init(rawValue: TGSpoilerAttributeName), in: attributed.range, options: .init(), using: { value, range, stop in
                if let text = value as? TGInputTextTag {
                    if let color = text.attribute.value as? NSColor {
                        spoilers.append(.init(range: range, color: color, isRevealed: false))
                    }
                }
            })
            
            let layout: TextViewLayout = .init(attributed, maximumNumberOfLines: state == .revealed ? 0 : 2, selectText: NSColor.black, spoilers: spoilers)
            layout.measure(width: frame.width - 20)
            layout.interactions = globalLinkExecutor
            
            if !layout.isPerfectSized {
                container.set(cursor: NSCursor.pointingHand, for: .Hover)
                container.set(cursor: NSCursor.pointingHand, for: .Highlight)
            } else {
                container.set(cursor: NSCursor.arrow, for: .Hover)
                container.set(cursor: NSCursor.arrow, for: .Highlight)
            }
            
            if self.textView?.textLayout?.attributedString != layout.attributedString || self.textView?.textLayout?.lines.count != layout.lines.count {
                let textView = TextView(frame: CGRect(origin: NSMakePoint(10, 5), size: layout.layoutSize))
                textView.update(layout)
                
                if let current = self.textView {
                    performSubviewRemoval(current, animated: transition.isAnimated)
                    self.textView = nil
                }
                self.documentView.addSubview(textView)
                if transition.isAnimated {
                    textView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                self.textView = textView
            }
            
            
            self.removeAllHandlers()
            self.set(handler: { control in
                toggleState(.concealed)
            }, for: .Click)
            
            container.removeAllHandlers()
            container.set(handler: { control in
                toggleState(.revealed)
            }, for: .Click)
            
            let cantReveal = state == .concealed && layout.isPerfectSized
            
            self.container.userInteractionEnabled = state == .concealed || cantReveal
            self.userInteractionEnabled = state == .revealed && !cantReveal
            self.textView?.userInteractionEnabled = state == .revealed || cantReveal
            

//            self.container.isEventLess = !self.container.userInteractionEnabled
            self.isEventLess = !self.userInteractionEnabled
//            self.textView.isEventLess = !self.container.userInteractionEnabled
            
            if let textView = self.textView {
                self.updateInlineStickers(context: context, view: textView, textLayout: layout)
            }
            
            self.updateLayout(size: frame.size, transition: transition)
            
            return frame.size
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {

            if let textView = textView {
                let containerSize = NSMakeSize(frame.width, min(textView.frame.height + 10, 208 + 10))
                let rect = CGRect(origin: NSMakePoint(0, size.height - containerSize.height), size: containerSize)
                transition.updateFrame(view: container, frame: rect)

                transition.updateFrame(view: documentView, frame: NSMakeRect(0, 0, container.frame.width, textView.frame.height + 10))
                transition.updateFrame(view: scrollView.contentView, frame: documentView.bounds)
                transition.updateFrame(view: scrollView, frame: container.bounds)

                textView.resize(size.width - 20)
                transition.updateFrame(view: textView, frame: CGRect.init(origin: NSMakePoint(10, 5), size: textView.frame.size))
            }
        }
        
        func updateInlineStickers(context: AccountContext, view textView: TextView, textLayout: TextViewLayout) {
            

            let textColor = storyTheme.colors.text
            
            var validIds: [InlineStickerItemLayer.Key] = []
            var index: Int = textView.hashValue
            
            for item in textLayout.embeddedItems {
                if let stickerItem = item.value as? InlineStickerItem, case let .attribute(emoji) = stickerItem.source {
                    
                    let id = InlineStickerItemLayer.Key(id: emoji.fileId, index: index)
                    validIds.append(id)
                    
                    
                    let rect: NSRect
                    if textLayout.isBigEmoji {
                        rect = item.rect
                    } else {
                        rect = item.rect.insetBy(dx: -2, dy: -2)
                    }
                    
                    let view: InlineStickerItemLayer
                    if let current = self.inlineStickerItemViews[id], current.frame.size == rect.size {
                        view = current
                    } else {
                        self.inlineStickerItemViews[id]?.removeFromSuperlayer()
                        view = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: emoji, size: rect.size, textColor: textColor)
                        self.inlineStickerItemViews[id] = view
                        view.superview = textView
                        textView.addEmbeddedLayer(view)
                    }
                    index += 1
                    var isKeyWindow: Bool = false
                    if let window = window {
                        if !window.canBecomeKey {
                            isKeyWindow = true
                        } else {
                            isKeyWindow = window.isKeyWindow
                        }
                    }
                    view.isPlayable = NSIntersectsRect(rect, textView.visibleRect) && isKeyWindow
                    view.frame = rect
                }
            }
            
            var removeKeys: [InlineStickerItemLayer.Key] = []
            for (key, itemLayer) in self.inlineStickerItemViews {
                if !validIds.contains(key) {
                    removeKeys.append(key)
                    itemLayer.removeFromSuperlayer()
                }
            }
            for key in removeKeys {
                self.inlineStickerItemViews.removeValue(forKey: key)
            }
        }

        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private var stories: [StoryView?] = []
    private var entry: StoryListEntry? = nil
    private var current: StoryView?
    private var selectedIndex: Int? = nil
    private var arguments: StoryArguments?
    private var context: AccountContext?
    private let controls = StoryControlsView(frame: .zero)
    private let navigator = StoryListNavigationView(frame: .zero)
    private var text: Text?
    private let container = View()
    
    private var pauseOverlay: Control? = nil
        
    var storyDidUpdate:((Message)->Void)?
    
    private var inputView: (NSView & StoryInput)!
    
    var textView: NSTextView? {
        return self.inputView.input
    }
    var inputTextView: TGModernGrowingTextView? {
        return self.inputView.text
    }
    
    func makeUrl() {
        self.inputView.makeUrl()
    }
    
    func setArguments(_ arguments: StoryArguments?) -> Void {
        self.arguments = arguments
        arguments?.interaction.add(observer: self)
    }
    required init(frame frameRect: NSRect) {
        
        super.init(frame: frameRect)
        
        container.layer?.masksToBounds = false
        container.addSubview(self.controls)
        container.addSubview(self.navigator)

        
        
        addSubview(container)
        controls.layer?.cornerRadius = 10
        
        controls.set(handler: { [weak self] _ in
            self?.arguments?.longDown()
        }, for: .LongMouseDown)
        
        controls.set(handler: { [weak self] _ in
            self?.arguments?.longUp()
        }, for: .LongMouseUp)
        
        controls.set(handler: { [weak self] control in
            if let event = NSApp.currentEvent {
                let point = control.convert(event.locationInWindow, from: nil)
                if point.x < control.frame.width / 2 {
                    self?.arguments?.prevStory()
                } else {
                    self?.arguments?.nextStory()
                }
            }
        }, for: .Click)
             
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    

    func resetInputView() {
        self.inputView.resetInputView()
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        guard let value = value as? StoryInteraction.State, let oldValue = oldValue as? StoryInteraction.State else {
            return
        }
        guard let context = self.arguments?.context else {
            return
        }
        
        var isPaused: Bool = false

        if let current = current, current.isEqual(to: value.storyId) {
            if value.isPaused {
                current.pause()
                isPaused = true
            } else {
                current.play()
                isPaused = false
            }
        } else {
            current?.pause()
            isPaused = true
        }
        
        if oldValue.isMuted != value.isMuted {
            if value.isMuted {
                current?.mute()
            } else {
                current?.unmute()
            }
            controls.updateMuted(isMuted: value.isMuted)
        }
        if oldValue.readingText != value.readingText {
            if let story = self.current?.story {
                self.updateText(story, state: value.readingText ? .revealed : .concealed, animated: animated, context: context)
            }
        }
        
        if let groupId = self.entry?.id {
            let curInput = value.inputs[groupId]
            let prevInput = oldValue.inputs[groupId]
            if let curInput = curInput, let prevInput = prevInput {
                inputView.updateInputText(curInput, prevState: prevInput, animated: animated)
            }
            inputView.updateState(value, animated: animated)
        }
        
        if isPaused, let storyView = self.current, self.entry?.id == value.entryId, value.inputInFocus || value.inputRecording != nil {
            let current: Control
            if let view = self.pauseOverlay {
                current = view
            } else {
                current = Control(frame: storyView.frame)
                current.layer?.cornerRadius = 10
                self.container.addSubview(current, positioned: .above, relativeTo: navigator)
                self.pauseOverlay = current
                
                current.set(handler: { [weak self] _ in
                    self?.resetInputView()
                }, for: .Click)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.backgroundColor = NSColor.black.withAlphaComponent(0.25)
        } else if let view = self.pauseOverlay {
            performSubviewRemoval(view, animated: animated)
            self.pauseOverlay = nil
        }
        
    }
    
    func isEqual(to other: Notifable) -> Bool {
        return self === other as? StoryListView
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        
        let maxSize = NSMakeSize(frame.width - 100, frame.height - 110)
        let aspect = StoryView.size.aspectFitted(maxSize)

        if container.superview == self {
            transition.updateFrame(view: container, frame: CGRect(origin: CGPoint(x: floorToScreenPixels(backingScaleFactor, (frame.width - aspect.width) / 2), y: 20), size: NSMakeSize(aspect.width, size.height)))
        }

        
        if let current = self.current {
            let rect = CGRect(origin: CGPoint(x: 0, y: 0), size: aspect)
            transition.updateFrame(view: current, frame: rect)
            
            transition.updateFrame(view: controls, frame: rect)
            controls.updateLayout(size: rect.size, transition: transition)
                        
            transition.updateFrame(view: navigator, frame: CGRect(origin: CGPoint(x: rect.minX, y: rect.minY + 6), size: NSMakeSize(rect.width, 2)))
            navigator.updateLayout(size: rect.size, transition: transition)
            
            if let pauseOverlay = pauseOverlay {
                transition.updateFrame(view: pauseOverlay, frame: rect)
            }

        }
        inputView.updateInputState(animated: transition.isAnimated)
        
        if let text = self.text {
            var rect = text.bounds
            rect.size.width = container.frame.width
            rect.origin.x = 0
            rect.origin.y = controls.frame.maxY - text.frame.height
            transition.updateFrame(view: text, frame: rect)
        }
    }
    
    func animateAppearing(from control: NSView) {
        
        guard let superview = control.superview else {
            return
        }
        
        let newRect = container.frame
        let origin = self.convert(control.frame.origin, from: superview)
        let oldRect = CGRect(origin: origin, size: control.frame.size)
                
        
        container.layer?.animatePosition(from: oldRect.origin, to: newRect.origin, duration: 0.2, timingFunction: .default)
        container.layer?.animateScaleX(from: oldRect.width / newRect.width, to: 1, duration: 0.2, timingFunction: .default)
        container.layer?.animateScaleY(from: oldRect.height / newRect.height, to: 1, duration: 0.2, timingFunction: .default)
        
        current?.animateAppearing(disappear: false)
        
//        let mask = SimpleShapeLayer()
//        mask.frame = self.bounds
//        mask.backgroundColor = .black
//        let path = CGMutablePath()
//        path.addRoundedRect(in: oldRect, cornerWidth: control.frame.width / 2, cornerHeight: control.frame.height / 2)
//        path.closeSubpath()
//
//        mask.path = path
//
//        self.layer?.mask = mask
//
//        let toPath = CGMutablePath()
//        toPath.addRoundedRect(in: newRect, cornerWidth: 0, cornerHeight: 0)
//        toPath.closeSubpath()
//
//        let maskAnim = mask.makeAnimation(from: path, to: toPath, keyPath: "path", timingFunction: .default, duration: 5, removeOnCompletion: false, completion: { [weak self] _ in
//            self?.layer?.mask = nil
//        })
//        mask.add(maskAnim, forKey: "path")
    }
    
    func animateDisappearing(to control: NSView) {
        
        guard let superview = control.superview else {
            return
        }
        
        let oldRect = container.frame
        let origin = self.convert(control.frame.origin, from: superview)
        let newRect = CGRect(origin: origin, size: control.frame.size)
                
        current?.animateAppearing(disappear: true)
        
        container.layer?.animatePosition(from: oldRect.origin, to: newRect.origin, duration: 0.2, timingFunction: .default, removeOnCompletion: false)
        container.layer?.animateScaleX(from: 1, to: newRect.width / oldRect.width, duration: 0.2, timingFunction: .default, removeOnCompletion: false)
        container.layer?.animateScaleY(from: 1, to: newRect.height / oldRect.height, duration: 0.2, timingFunction: .default, removeOnCompletion: false)
        
    }

    func update(context: AccountContext, entry: StoryListEntry, selected: Int?) {
                
        
        self.context = context
        self.stories = Array(repeating: nil, count: entry.count)
        self.entry = entry
        self.navigator.initialize(count: stories.count)
        
        if self.inputView == nil {
            let maxSize = NSMakeSize(frame.width - 100, frame.height - 110)
            let aspect = StoryView.size.aspectFitted(maxSize)

            if entry.id == context.peerId {
                self.inputView = StoryMyInputView(frame: NSMakeRect(0, 0, aspect.width, 50))
            } else {
                self.inputView = StoryInputView(frame: NSMakeRect(0, 0, aspect.width, 50))
            }
            self.container.addSubview(self.inputView)
            
            inputView.installInputStateUpdate({ [weak self] state in
                switch state {
                case .focus:
                    self?.arguments?.inputFocus()
                case .none:
                    self?.arguments?.inputUnfocus()
                }
            })
            
            self.inputView.setArguments(self.arguments, groupId: entry.id)
        }
        
        if let selected = selected {
            self.select(at: selected)
        } else if let current = self.current, !entry.item.items.contains(where: { current.isEqual(to: $0.id) }) {
            let index = min((self.selectedIndex ?? 0), entry.count - 1)
            self.select(at: index)
        } else if let current = self.current, let story = current.story {
            self.updateStoryState(current.state)
            self.inputView.update(story, animated: true)
        }
        
        self.preloadAround()
        
       
    }
    
    func select(at index: Int) {
        guard let context = context, let arguments = self.arguments, let entry = self.entry else {
            return
        }
        let groupId = entry.id
        let previous = self.current
        

        let current: StoryView
        if let view = self.stories[index] {
            current = view
        } else {
            let size = NSMakeSize(frame.width - 100, frame.height - 110)
            let aspect = StoryView.size.aspectFitted(size)
            current = StoryView.makeView(for: entry.item.items[index], peerId: entry.id, peer: entry.item.peer?._asPeer(), context: context, frame: aspect.bounds)
            self.stories[index] = current
        }
                
        self.current = current
        
        if let previous = previous {
            previous.removeFromSuperview()
            previous.onStateUpdate = nil
            previous.disappear()
        }
        
        let story = entry.item.items[index]
        
        self.updateLayout(size: self.frame.size, transition: .immediate)


        self.controls.update(context: context, arguments: arguments, groupId: groupId, peer: entry.item.peer?._asPeer(), story: story, animated: false)
        
        self.selectedIndex = index
        container.addSubview(current, positioned: .below, relativeTo: self.controls)
        
        arguments.interaction.flushPauses()
        
        if !entry.isSeen(story) {
            arguments.markAsRead(groupId, story.id)
        }
        
        preloadAround()
        
                
        current.onStateUpdate = { [weak self] state in
            self?.updateStoryState(state)
        }
        
        current.appear(isMuted: arguments.interaction.presentation.isMuted)
        self.updateStoryState(current.state)

        
        self.arguments?.interaction.update { current in
            var current = current
            current.storyId = story.id
            current.entryState[groupId] = story.id
            return current
        }
        self.inputView.update(story, animated: false)
        
        self.updateText(story, state: .concealed, animated: false, context: context)
    }
    
    private func updateText(_ story: StoryListContext.Item, state: Text.State, animated: Bool, context: AccountContext) {
        
        let text = story.text//"Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."
        
        let entities: [MessageTextEntity] = story.entities//[.init(range: 0..<5, type: MessageTextEntityType.Bold), .init(range: 6..<10, type: MessageTextEntityType.Italic), .init(range: 40..<100, type: MessageTextEntityType.Spoiler)]
        
        
        if !text.isEmpty {
            let current: Text
            if let view = self.text {
                current = view
            } else {
                current = Text(frame: NSMakeRect(0, container.frame.maxY - 100, container.frame.width, controls.frame.height))
                self.text = current
                container.addSubview(current, positioned: .above, relativeTo: controls)
            }
            let transition: ContainedViewLayoutTransition
            if animated {
                transition = .animated(duration: 0.2, curve: .easeOut)
            } else {
                transition = .immediate
            }
            let size = current.update(text: text, entities: entities, context: context, state: state, transition: transition, toggleState: { [weak self] state in
                self?.arguments?.interaction.update { current in
                    var current = current
                    current.readingText = state == .revealed
                    current.isSpacePaused = false
                    return current
                }
            }, arguments: arguments)
            
            let rect = CGRect(origin: NSMakePoint(0, controls.frame.height - size.height), size: size)
            transition.updateFrame(view: current, frame: rect)
            
            
        } else if let view = self.text {
            performSubviewRemoval(view, animated: false)
            self.text = nil
        }
    }
    
    private func updateStoryState(_ state: StoryView.State) {
        guard let index = self.selectedIndex, let view = self.current else {
            return
        }
        switch state {
        case .playing:
            self.navigator.set(index, current: view.currentTimestamp, duration: view.duration, playing: true)
        case .finished:
            self.arguments?.nextStory()
        default:
            self.navigator.set(index, current: view.currentTimestamp, duration: view.duration, playing: false)
        }
    }
    
    var contentSize: NSSize {
        return self.container.frame.size
    }
    var contentRect: CGRect {
        return self.container.frame
    }
    var storyRect: CGRect {
        if let current = self.current {
            return NSMakeRect(self.container.frame.minX, 20, current.frame.width, current.frame.height)
        }
        return self.container.frame
    }
    
    private func preloadAround() {
        guard let index = self.selectedIndex, let context = self.context, let entry = self.entry else {
            return
        }
        let size = NSMakeSize(frame.width - 100, frame.height - 110)
        let aspect = StoryView.size.aspectFitted(size)

        for i in 0 ..< stories.count {
            if abs(i - index) > 2 {
                stories[i] = nil
            } else {
                if stories[i] == nil {
                    stories[i] = StoryView.makeView(for: entry.item.items[i], peerId: entry.id, peer: entry.item.peer?._asPeer(), context: context, frame: aspect.bounds)
                }
            }
        }
    }
    
    func previous() -> UpdateIndexResult {
        guard let index = self.selectedIndex else {
            return .invoked
        }
        if index > 0 {
            self.select(at: index - 1)
            return .invoked
        } else {
            return .moveBack
        }
    }
    
    func next() -> UpdateIndexResult {
        guard let index = self.selectedIndex else {
            return .invoked
        }
        if index < self.stories.count - 1 {
            self.select(at: index + 1)
            return .invoked
        } else {
            return .moveNext
        }
    }
    
    func restart() {
        self.select(at: 0)
    }
    
    func play() {
        self.current?.play()
    }
    func pause() {
        self.current?.pause()
    }
    
    deinit {
        arguments?.interaction.remove(observer: self)
        //self.current?.disappear()
    }
}

private var timer: DisplayLinkAnimator?

extension StoryListView {
    enum TranslateDirection {
        case left
        case right
    }
    
    
    func initAnimateTranslate(previous: StoryListView, direction: TranslateDirection) {
        
        
        let animateContainer = LayerBackedView()
        animateContainer.frame = container.frame
        animateContainer.layer?.masksToBounds = false

        addSubview(animateContainer, positioned: .above, relativeTo: container)

        let view1 = LayerBackedView()
        view1.layer?.isDoubleSided = false
        view1.layer?.masksToBounds = false
        previous.container.frame = animateContainer.bounds
        view1.addSubview(previous.container)

        let view2 = LayerBackedView()
        view2.layer?.isDoubleSided = false
        view2.layer?.masksToBounds = false
        self.container.frame = animateContainer.bounds
        view2.addSubview(self.container)

        view1.frame = animateContainer.bounds
        view2.frame = animateContainer.bounds
        animateContainer.addSubview(view1)
        animateContainer.addSubview(view2)


        animateContainer._anchorPoint = NSMakePoint(0.5, 0.5)
        view1._anchorPoint = NSMakePoint(1.0, 1.0)
        view2._anchorPoint = NSMakePoint(1.0, 1.0)

        var view2Transform:CATransform3D = CATransform3DMakeTranslation(0.0, 0.0, 0.0)
        switch direction {
        case .right:
            view2Transform = CATransform3DTranslate(view2Transform, -view2.bounds.size.width, 0, 0);
            view2Transform = CATransform3DRotate(view2Transform, CGFloat(-(Double.pi/2)), 0, 1, 0);
        case .left:
            view2Transform = CATransform3DRotate(view2Transform, CGFloat(Double.pi/2), 0, 1, 0);
            view2Transform = CATransform3DTranslate(view2Transform, view2.bounds.size.width, 0, 0);
        }

        view2._transformation = view2Transform

        var sublayerTransform:CATransform3D = CATransform3DIdentity
        sublayerTransform.m34 = CGFloat(1.0 / (-3500))
        animateContainer._sublayerTransform = sublayerTransform
        
        self.transition = .init(direction: direction, animateContainer: animateContainer, view1: view1, view2: view2, previous: previous)

    }
    
    func translate(progress: CGFloat, finish: Bool, cancel: Bool = false, completion:@escaping(Bool, StoryListView)->Void) {
            
        guard let transition = self.transition else {
            return
        }
        
        
        let animateContainer = transition.animateContainer
        let view1 = transition.view1
        let view2 = transition.view2
        let previous = transition.previous
        
        if finish {
            self.transition = nil
        }
        
        let completed: (Bool)->Void = { [weak self, weak previous, weak animateContainer, weak view1, weak view2] completed in
            
            view1?.removeFromSuperview()
            view2?.removeFromSuperview()
            
            if let previous = previous {
                if cancel {
                    previous.addSubview(previous.container)
                    previous.updateLayout(size: previous.frame.size, transition: .immediate)
                } else {
                    previous.removeFromSuperview()
                }
            }
            
            
            animateContainer?.removeFromSuperview()
            if !cancel {
                if let container = self?.container {
                    self?.addSubview(container, positioned: .below, relativeTo: nil)
                }
            }
            
            if let `self` = self {
                self.updateLayout(size: self.frame.size, transition: .immediate)
            }
            if let previous = previous {
                completion(!cancel, previous)
            }
            
        }
        
        if finish, progress != 1 {
            
            let duration = 0.25
            
            let rotation:CABasicAnimation
            let translation:CABasicAnimation
            let translationZ:CABasicAnimation

            let group:CAAnimationGroup = CAAnimationGroup()
            group.duration = duration
            group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            if !cancel {
                switch transition.direction {
                case .right:
                    let toValue:Float = Float(animateContainer.bounds.size.width / 2)
                    translation = CABasicAnimation(keyPath: "sublayerTransform.translation.x")
                    translation.toValue = NSNumber(value: toValue)
                    
                    rotation = CABasicAnimation(keyPath: "sublayerTransform.rotation.y")
                    rotation.toValue = NSNumber(value: (Double.pi/2))
                    
                    translationZ = CABasicAnimation(keyPath: "sublayerTransform.translation.z")
                    translationZ.toValue = NSNumber(value: -toValue)
                case .left:
                    let toValue:Float = Float(animateContainer.bounds.size.width / 2)
                    translation = CABasicAnimation(keyPath: "sublayerTransform.translation.x")
                    translation.toValue = NSNumber(value: -toValue)
                    
                    rotation = CABasicAnimation(keyPath: "sublayerTransform.rotation.y")
                    rotation.toValue = NSNumber(value: -(Double.pi/2))
                    
                    translationZ = CABasicAnimation(keyPath: "sublayerTransform.translation.z")
                    translationZ.toValue = NSNumber(value: -toValue)
                }
                view2._change(opacity: 1, duration: duration, timingFunction: .easeOut)
                view1._change(opacity: 0, duration: duration, timingFunction: .easeOut)
            } else {
                translation = CABasicAnimation(keyPath: "sublayerTransform.translation.x")
                translation.toValue = NSNumber(value: 0)
                
                rotation = CABasicAnimation(keyPath: "sublayerTransform.rotation.y")
                rotation.toValue = NSNumber(value: 0)
                
                translationZ = CABasicAnimation(keyPath: "sublayerTransform.translation.z")
                translationZ.toValue = NSNumber(value: 0)
                
                view2._change(opacity: 0, duration: duration, timingFunction: .easeOut)
                view1._change(opacity: 1, duration: duration, timingFunction: .easeOut)

            }
            
            group.animations = [rotation, translation, translationZ]
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false
            
            group.completion = completed
            
            animateContainer.layer?.add(group, forKey: "translate")
        } else {
            switch transition.direction {
            case .right:
                let toValue:CGFloat = CGFloat(animateContainer.bounds.size.width / 2)
                animateContainer.layer?.setValue(NSNumber(value: toValue * progress), forKeyPath: "sublayerTransform.translation.x")
                animateContainer.layer?.setValue(NSNumber(value: (Double.pi/2) * progress), forKeyPath: "sublayerTransform.rotation.y")
                animateContainer.layer?.setValue(NSNumber(value: -toValue * progress), forKeyPath: "sublayerTransform.translation.z")
                animateContainer._sublayerTransform = animateContainer.layer?.sublayerTransform
            case .left:
                let toValue:CGFloat = CGFloat(animateContainer.bounds.size.width / 2)
                animateContainer.layer?.setValue(NSNumber(value: -toValue * progress), forKeyPath: "sublayerTransform.translation.x")
                animateContainer.layer?.setValue(NSNumber(value: -(Double.pi/2) * progress), forKeyPath: "sublayerTransform.rotation.y")
                animateContainer.layer?.setValue(NSNumber(value: -toValue * progress), forKeyPath: "sublayerTransform.translation.z")
                animateContainer._sublayerTransform = animateContainer.layer?.sublayerTransform
            }
            view2.layer?.opacity = Float(1 * progress)
            view1.layer?.opacity = Float(1 - progress)

            if progress == 1, finish {
                completed(true)
            }
        }
    }

}
