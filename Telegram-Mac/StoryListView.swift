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


extension MediaArea {
    var title: String {
        switch self {
        case .venue:
            return strings().storyViewMediaAreaViewLocation
        }
    }
    var menu: MenuAnimation {
        switch self {
        case .venue:
            return MenuAnimation.menu_location
        }
    }
}


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
    
    fileprivate let ready: ValuePromise<Bool> = ValuePromise(false, ignoreRepeated: true)
    
    var getReady: Signal<Bool, NoError> {
        return self.ready.get() |> filter { $0 } |> take(1)
    }
    
    fileprivate var transition: TransitionData?

    var storyId: AnyHashable? {
        if let entry = entry {
            return entry.item.storyItem.id
        }
        return nil
    }
    var story: StoryContentItem? {
        if let entry = entry {
            return entry.item
        }
        return nil
    }
    var id: PeerId? {
        return self.entry?.peer.id
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
        private let shadowView = ShadowView()
        private var arguments: StoryArguments?
        private var inlineStickerItemViews: [InlineStickerItemLayer.Key: InlineStickerItemLayer] = [:]
        
        private var showMore: TextView?
        
        required init(frame frameRect: NSRect) {
            scrollView.background = .clear
            super.init(frame: frameRect)
            self.addSubview(shadowView)
            addSubview(container)
            container.addSubview(self.scrollView)
            self.scrollView.documentView = documentView
            
            shadowView.direction = .vertical(true)
            shadowView.shadowBackground = NSColor.black.withAlphaComponent(0.6)
            
            
            NotificationCenter.default.addObserver(forName: NSScrollView.boundsDidChangeNotification, object: scrollView.clipView, queue: nil, using: { [weak self] _ in
                self?.updateScroll()
            })
            
            scrollView.applyExternalScroll = { [weak self] event in
                if self?.arguments?.interaction.presentation.inTransition == true {
                    self?.superview?.scrollWheel(with: event)
                    return true
                }
                return false
            }
            
            
            self.layer?.cornerRadius = 10
        }
        
        
        private func updateScroll() {
            switch state {
            case .concealed:
                if container.userInteractionEnabled, scrollView.clipView.bounds.minY > 5 {
                    self.scrollView.clipView.scroll(to: .zero, animated: false)
                    self.container.send(event: .Click)
                }
            case .revealed:
                if self.userInteractionEnabled, scrollView.clipView.bounds.minY < -5 {
                    self.scrollView.clipView.scroll(to: .zero, animated: false)
                    self.send(event: .Click)
                }
            }
        }
        

        
        override func layout() {
            super.layout()
            self.updateLayout(size: frame.size, transition: .immediate)
        }
        
        func update(text: String, entities: [MessageTextEntity], context: AccountContext, state: State, transition: ContainedViewLayoutTransition, toggleState: @escaping(State)->Void, arguments: StoryArguments?) -> NSSize {
            
            self.state = state
            self.arguments = arguments
            
            let attributed = ChatMessageItem.applyMessageEntities(with: [TextEntitiesMessageAttribute(entities: entities)], for: text, message: nil, context: context, fontSize: storyTheme.fontSize, openInfo: { [weak arguments, weak self] peerId, toChat, messageId, initialAction in
                if toChat {
                    arguments?.openChat(peerId, messageId, initialAction)
                } else if let view = self {
                    arguments?.openPeerInfo(peerId, view)
                }
            }, hashtag: arguments?.hashtag ?? { _ in }, textColor: storyTheme.colors.text, linkColor: storyTheme.colors.text, monospacedPre: storyTheme.colors.text, monospacedCode: storyTheme.colors.text, underlineLinks: true).mutableCopy() as! NSMutableAttributedString
            
            

            
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
            
            let layout: TextViewLayout = .init(attributed, maximumNumberOfLines: state == .revealed ? 0 : 2, selectText: storyTheme.colors.grayText, spoilers: spoilers)
            layout.measure(width: frame.width - 20)
            layout.interactions = globalLinkExecutor
            
            
            
            if !layout.isPerfectSized {
                container.set(cursor: NSCursor.pointingHand, for: .Hover)
                container.set(cursor: NSCursor.pointingHand, for: .Highlight)
            } else {
                container.set(cursor: NSCursor.arrow, for: .Hover)
                container.set(cursor: NSCursor.arrow, for: .Highlight)
            }
            
            if !layout.isPerfectSized, state != .revealed {
                
                let current: TextView
                let isNew: Bool
                if let view = self.showMore {
                    current = view
                    isNew = false
                } else {
                    current = TextView()
                    self.showMore = current
                    self.documentView.addSubview(current)

                    current.set(handler: { control in
                        toggleState(.revealed)
                    }, for: .Click)
                   
                    isNew = true
                }
                let moreLayout = TextViewLayout.init(.initialize(string: strings().storyItemTextShowMore, color: storyTheme.colors.text, font: .bold(.text)))
                moreLayout.measure(width: .greatestFiniteMagnitude)
                current.update(moreLayout)
                
                layout.cutout = .init(topLeft: nil, topRight: nil, bottomRight: NSMakeSize(moreLayout.layoutSize.width, 10))
                layout.measure(width: frame.width - 20)
                
                if isNew {
                    current.setFrameOrigin(NSMakePoint(documentView.frame.width - current.frame.width - 10, documentView.frame.height - current.frame.height - 10))
                    if transition.isAnimated {
                        current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
                
            } else if let view = self.showMore {
                performSubviewRemoval(view, animated: transition.isAnimated)
                self.showMore = nil
            }
            
            if self.textView?.textLayout?.attributedString != layout.attributedString || self.textView?.textLayout?.lines.count != layout.lines.count {
                let textView = TextView(frame: CGRect(origin: NSMakePoint(10, 5), size: layout.layoutSize))
                textView.update(layout)
                
                if let current = self.textView {
                    performSubviewRemoval(current, animated: transition.isAnimated)
                    self.textView = nil
                }
                self.documentView.addSubview(textView, positioned: .below, relativeTo: showMore)
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
            
            self.container.userInteractionEnabled = state == .concealed && !cantReveal
            self.userInteractionEnabled = state == .revealed
            self.textView?.userInteractionEnabled = state == .revealed || cantReveal
            

//            self.container.isEventLess = !self.container.userInteractionEnabled
            self.isEventLess = !self.userInteractionEnabled
//            self.textView.isEventLess = !self.container.userInteractionEnabled
            
            if let textView = self.textView {
                self.updateInlineStickers(context: context, view: textView, textLayout: layout)
            }
            
            self.updateLayout(size: frame.size, transition: transition)
            
            switch state {
            case .concealed:
                self.shadowView.background = NSColor.clear
                if transition.isAnimated {
                    self.shadowView.layer?.animateBackground()
                }
            case .revealed:
                self.shadowView.background = NSColor.black.withAlphaComponent(0.9)
                if transition.isAnimated {
                    self.shadowView.layer?.animateBackground()
                }
            }
            
            return frame.size
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {

            if let textView = textView {
                let containerSize = NSMakeSize(frame.width, min(textView.frame.height + 20, 208 + 20))
                let rect = CGRect(origin: NSMakePoint(0, size.height - containerSize.height), size: containerSize)
                transition.updateFrame(view: container, frame: rect)

                transition.updateFrame(view: documentView, frame: NSMakeRect(0, 0, container.frame.width, textView.frame.height + 10))
                transition.updateFrame(view: scrollView.contentView, frame: documentView.bounds)
                transition.updateFrame(view: scrollView, frame: container.bounds)

                transition.updateFrame(view: shadowView, frame: container.frame)

                
                
                textView.resize(size.width - 20)
                transition.updateFrame(view: textView, frame: CGRect.init(origin: NSMakePoint(10, 10), size: textView.frame.size))
                
                if let view = self.showMore {
                    transition.updateFrame(view: view, frame: CGRect.init(origin: NSMakePoint(documentView.frame.width - view.frame.width - 10, documentView.frame.height - view.frame.height), size: view.frame.size))
                }
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
            
            updateAnimatableContent()
        }

        
        @objc func updateAnimatableContent() -> Void {
            var isKeyWindow: Bool = false
            if let window = window {
                if !window.canBecomeKey {
                    isKeyWindow = true
                } else {
                    isKeyWindow = window.isKeyWindow
                }
            }
            for layer in inlineStickerItemViews.values {
                layer.isPlayable = isKeyWindow
            }
        }
        
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            self.updateListeners()
            self.updateAnimatableContent()
        }
        
        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            self.updateListeners()
            self.updateAnimatableContent()
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        private func updateListeners() {
            let center = NotificationCenter.default
            if let window = window {
                center.removeObserver(self)
                center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didBecomeKeyNotification, object: window)
                center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didResignKeyNotification, object: window)
                center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.boundsDidChangeNotification, object: self.enclosingScrollView?.contentView)
                center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self.enclosingScrollView?.documentView)
                center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self)
            } else {
                center.removeObserver(self)
            }
        }
        
        
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private var entry: StoryContentContextState.FocusedSlice? = nil
    private let magnifyDispsosable = MetaDisposable()
    private var current: StoryView? {
        didSet {
            if let magnify = current?.magnify {
                controls.redirectView = magnify
                magnifyDispsosable.set(magnify.magnifyUpdaterValue.start(next: { [weak self] value in
                    self?.arguments?.interaction.updateMagnify(value)
                }))
            } else {
                self.arguments?.interaction.updateMagnify(1.0)
                magnifyDispsosable.set(nil)
                controls.redirectView = nil
            }
        }
    }
    private var arguments: StoryArguments?
    private var context: AccountContext?
    private let controls = StoryControlsView(frame: .zero)
    private let navigator = StoryListNavigationView(frame: .zero)
    private var text: Text?
    
    private var prevStoryView: ShadowView?
    private var nextStoryView: ShadowView?
    
    private var pauseOverlay: Control? = nil
    
    private var mediaAreaViewer: StoryViewMediaAreaViewer?
        
    var storyDidUpdate:((Message)->Void)?
    
    private(set) var inputView: (NSView & StoryInput)!
    let container = View()
    private let content = View()
    
    
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
        
        container.layer?.masksToBounds = true
        content.addSubview(self.controls)
        content.addSubview(self.navigator)
        container.layer?.masksToBounds = false
        
        container.addSubview(content)
        
        controls.controlOpacityEventIgnored = true
        
        addSubview(container)
        controls.layer?.cornerRadius = 10
        
        controls.set(handler: { [weak self] control in
            guard let arguments = self?.arguments, let story = self?.story, let peer = story.peer, let event = NSApp.currentEvent else {
                return
            }
            let peerId = peer.id
            if peer.isService {
                if let menu = arguments.storyContextMenu(story) {
                    AppMenu.show(menu: menu, event: event, for: control)
                }
            } else {
                let window = storyReactionsWindow(context: arguments.context, peerId: peerId, react: arguments.react, onClose: {
                
                }) |> deliverOnMainQueue
                
                _ = window.start(next: { [weak arguments] panel in
                    if let menu = arguments?.storyContextMenu(story) {
                        
                        menu.topWindow = panel
                        AppMenu.show(menu: menu, event: event, for: control)
                    }
                })
            }
        }, for: .RightDown)
        
        controls.set(handler: { [weak self] _ in
            self?.updateSides()
            self?.arguments?.down()
        }, for: .Down)
        
        controls.set(handler: { [weak self] _ in
            self?.updateSides()
            self?.arguments?.longDown()
        }, for: .LongMouseDown)
        
        
        controls.set(handler: { [weak self] _ in
            self?.arguments?.up()
            self?.updateSides()
        }, for: .Up)
        
        controls.set(handler: { [weak self] control in
            if let event = NSApp.currentEvent {
                let point = control.convert(event.locationInWindow, from: nil)
                if let value = self?.findMediaArea(point) {
                    self?.arguments?.activateMediaArea(value)
                } else {
                    if point.x < control.frame.width / 2 {
                        self?.arguments?.prevStory()
                    } else {
                        self?.arguments?.nextStory()
                    }
                    self?.updateSides()
                }
            }
        }, for: .Click)
        
        
        self.userInteractionEnabled = false
    }
    
    
    private func mediaAreaViewerRect(_ mediaArea: MediaArea) -> NSRect {
        let referenceSize = self.controls.frame.size
        let size = CGSize(width: 16.0, height: 16.0)
        var frame = CGRect(x: mediaArea.coordinates.x / 100.0 * referenceSize.width - size.width / 2.0, y: (mediaArea.coordinates.y - mediaArea.coordinates.height * 0.5)  / 100.0 * referenceSize.height - size.height / 2.0, width: size.width, height: size.height)
        frame = frame.offsetBy(dx: 0.0, dy: -8)

        return frame
    }
    
    func showMediaAreaViewer(_ mediaArea: MediaArea) {
        guard let event = NSApp.currentEvent else {
            return
        }
        if let viewer = self.mediaAreaViewer {
            performSubviewRemoval(viewer, animated: false)
            self.mediaAreaViewer = nil
        }
        
        let rect = self.mediaAreaViewerRect(mediaArea)
        
        let view = StoryViewMediaAreaViewer(frame: rect)
        self.mediaAreaViewer = view
        
        self.content.addSubview(view)
                
        var items: [ContextMenuItem] = []
        
        items.append(ContextMenuItem(mediaArea.title, handler: { [weak self] in
            self?.arguments?.invokeMediaArea(mediaArea)
        }, itemImage: mediaArea.menu.value))

        ContextMenu.show(items: items, view: view, event: event, onClose: { [weak self] in
            self?.arguments?.deactivateMediaArea(mediaArea)
        }, presentation: .current(storyTheme.colors))
    }
    
    func hideMediaAreaViewer() {
        if let viewer = self.mediaAreaViewer {
            performSubviewRemoval(viewer, animated: false)
            self.mediaAreaViewer = nil
        }
    }
    
    
    private func findMediaArea(_ point: NSPoint) -> MediaArea? {
        guard let story = self.story else {
            return nil
        }
        
        let point = NSMakePoint(point.x, point.y)
                
        let referenceSize = self.controls.frame.size
        
        var selectedMediaArea: MediaArea?
                                                
        func isPoint(_ point: CGPoint, in area: MediaArea) -> Bool {
            let tx = point.x - area.coordinates.x / 100.0 * referenceSize.width
            let ty = point.y - area.coordinates.y / 100.0 * referenceSize.height
            
            let rad = -area.coordinates.rotation * Double.pi / 180.0
            let cosTheta = cos(rad)
            let sinTheta = sin(rad)
            let rotatedX = tx * cosTheta - ty * sinTheta
            let rotatedY = tx * sinTheta + ty * cosTheta
            
            return abs(rotatedX) <= area.coordinates.width / 100.0 * referenceSize.width / 2.0 && abs(rotatedY) <= area.coordinates.height / 100.0 * referenceSize.height / 2.0
        }

        
        for area in story.storyItem.mediaAreas {
             if isPoint(point, in: area) {
                selectedMediaArea = area
                break
            }
        }
        return selectedMediaArea
    }
    
    private func updateSides(animated: Bool = true) {
        if let args = self.arguments {
            let isPrev: Bool?
            if !args.interaction.presentation.longDown, let event = NSApp.currentEvent, event.type == .leftMouseDown {
                let point = controls.convert(event.locationInWindow, from: nil)
                if point.x < controls.frame.width / 2 {
                    isPrev = true
                } else {
                    isPrev = false
                }
            } else {
                isPrev = nil
            }
            
            if let isPrev = isPrev {
                self.prevStoryView?.change(opacity: isPrev ? 1 : 0, animated: animated)
                self.nextStoryView?.change(opacity: !isPrev ? 1 : 0, animated: animated)
            } else {
                self.prevStoryView?.change(opacity: 0, animated: animated)
                self.nextStoryView?.change(opacity: 0, animated: animated)
            }
        }
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
        self.arguments?.interaction.update { current in
            var current = current
            current.hasReactions = false
            return current
        }
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
        
        if value.inputRecording != oldValue.inputRecording {
            self.updateLayout(size: frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
        }
        
        if let groupId = self.entry?.peer.id {
            let curInput = value.inputs[groupId]
            let prevInput = oldValue.inputs[groupId]
            if let curInput = curInput, let prevInput = prevInput {
                inputView.updateInputText(curInput, prevState: prevInput, animated: animated)
            }
            inputView.updateState(value, animated: animated)
        }
                

        
        if isPaused, let storyView = self.current, self.entry?.peer.id == value.entryId, value.inputInFocus || value.inputRecording != nil || value.hasReactions {
            let current: Control
            if let view = self.pauseOverlay {
                current = view
            } else {
                current = Control(frame: storyView.frame)
                current.layer?.cornerRadius = 10
                self.content.addSubview(current, positioned: .above, relativeTo: navigator)
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
            self.updateLayout(size: frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
            performSubviewRemoval(view, animated: animated)
            self.pauseOverlay = nil
        }
        
        self.controls.userInteractionEnabled = !value.magnified

   
        let isControlHid = value.longDown || value.magnified //|| value.isSpacePaused
        let prevIsControlHid = oldValue.longDown || oldValue.magnified //|| oldValue.isSpacePaused

        if isControlHid != prevIsControlHid {
            self.controls.change(opacity: isControlHid ? 0 : 1, animated: animated)
            self.navigator.change(opacity: isControlHid ? 0 : 1, animated: animated)
        }
        self.text?.change(opacity: isControlHid || value.inputInFocus ? 0 : 1, animated: animated)

        self.updateSides(animated: animated)
    }
    
    func isEqual(to other: Notifable) -> Bool {
        return self === other as? StoryListView
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        
        let maxSize = NSMakeSize(frame.width - 100, frame.height - 110)
        let aspect = StoryView.size.aspectFitted(maxSize)
        let containerSize: NSSize
        if let arguments = self.arguments, arguments.interaction.presentation.inputInFocus || arguments.interaction.presentation.inputRecording != nil {
            containerSize = NSMakeSize(min(aspect.width + 60, size.width - 20), aspect.height)
        } else {
            containerSize = aspect
        }
        if container.superview == self {
            transition.updateFrame(view: container, frame: CGRect(origin: CGPoint(x: floorToScreenPixels(backingScaleFactor, (frame.width - containerSize.width) / 2), y: 20), size: NSMakeSize(containerSize.width, size.height)))
        }

        
        if let current = self.current, self.content.superview == container {
            let rect = CGRect(origin: CGPoint(x: (containerSize.width - aspect.width) / 2, y: 0), size: aspect)
            transition.updateFrame(view: self.content, frame: rect)

            transition.updateFrame(view: current, frame: rect.size.bounds)
            
            transition.updateFrame(view: controls, frame: rect.size.bounds)
            controls.updateLayout(size: rect.size, transition: transition)
                        
            transition.updateFrame(view: navigator, frame: CGRect(origin: CGPoint(x: 0, y: 0 + 6), size: NSMakeSize(rect.width, 2)))
            navigator.updateLayout(size: rect.size, transition: transition)
            
            if let pauseOverlay = pauseOverlay {
                transition.updateFrame(view: pauseOverlay, frame: rect.size.bounds)
            }
            
            if let view = self.prevStoryView {
                transition.updateFrame(view: view, frame: NSMakeRect(0, 0, 40, rect.height))
            }
            if let view = self.nextStoryView {
                transition.updateFrame(view: view, frame: NSMakeRect(rect.width - 40, 0, 40, rect.height))
            }
        }
        inputView?.updateInputState(animated: transition.isAnimated)
        
        if let text = self.text {
            var rect = text.bounds
            rect.size.width = aspect.width
            rect.origin.x = 0
            rect.origin.y = controls.frame.maxY - text.frame.height
            transition.updateFrame(view: text, frame: rect)
            text.updateLayout(size: rect.size, transition: transition)
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
        
    }
    var contentView: NSView {
        return container
    }
    
    func animateDisappearing(to control: NSView) {
        
        guard let superview = control.superview else {
            return
        }
        
        
        let aspectSize = control.frame.size//oldRect.size.aspectFilled(control.frame.size)

        let point = self.convert(content.frame.origin, from: container)
        
        self.addSubview(content)
        content.setFrameOrigin(point)
        content.backgroundColor = .random
        let oldRect = content.frame

        
        let origin = self.convert(control.frame.origin, from: superview)
        let newRect = CGRect(origin: NSMakePoint(origin.x + (control.frame.width - aspectSize.width) / 2, origin.y + (control.frame.height - aspectSize.height) / 2), size: aspectSize)
                
                
        current?.animateAppearing(disappear: true)
        
        let duration: Double = 0.2
        
        guard let layer = content.layer else {
            return
        }
        layer.animatePosition(from: oldRect.origin, to: newRect.origin, duration: duration, timingFunction: .default, removeOnCompletion: false)
        layer.animateScaleX(from: 1, to: newRect.width / oldRect.width, duration: duration, timingFunction: .default, removeOnCompletion: false)
        layer.animateScaleY(from: 1, to: newRect.height / oldRect.height, duration: duration, timingFunction: .default, removeOnCompletion: false)
        
        
        
        if control is AvatarControl || control is AvatarStoryControl {
            let anim = layer.makeAnimation(from: NSNumber(value: content.layer!.cornerRadius), to: NSNumber(value: CGFloat(content.frame.width / 2)), keyPath: "cornerRadius", timingFunction: .default, duration: duration, removeOnCompletion: false)
            layer.add(anim, forKey: "cornerRadius")
        }
       
    }
    
    func zoomIn() {
        self.current?.magnify?.zoomIn()
    }
    func zoomOut() {
        self.current?.magnify?.zoomOut()
    }

    func update(context: AccountContext, entry: StoryContentContextState.FocusedSlice?) {
                
        
        self.context = context
        self.entry = entry
        self.controls.isHidden = entry == nil

        if let entry = entry {
            self.navigator.initialize(count: entry.item.dayCounters?.totalCount ?? entry.totalCount)
            
            if self.inputView == nil {
                let maxSize = NSMakeSize(frame.width - 100, frame.height - 110)
                let aspect = StoryView.size.aspectFitted(maxSize)
                
                if entry.peer.isService {
                    self.inputView = StoryNoReplyInput(frame: NSMakeRect(0, 0, aspect.width, 50))
                } else if entry.peer.id == context.peerId {
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
                    if let `self` = self {
                        self.updateLayout(size: self.frame.size, transition: .animated(duration: 0.2, curve: .easeOut))
                    }
                })
                
                self.inputView.update(entry.item, animated: false)
                self.inputView.setArguments(self.arguments, groupId: entry.peer.id)
            }
            
            if let current = self.current, !current.isEqual(to: entry.item.storyItem.id) {
                self.redraw()
            } else if let current = self.current, let arguments = arguments {
                self.updateStoryState(current.state)
                self.controls.update(context: context, arguments: arguments, groupId: entry.peer.id, peer: entry.peer._asPeer(), slice: entry, story: entry.item, animated: true)
                self.inputView.update(entry.item, animated: true)
                self.arguments?.markAsRead(entry.peer.id, entry.item.storyItem.id)
            } else {
                self.redraw()
            }
        } else {
            let size = NSMakeSize(frame.width - 100, frame.height - 110)
            let aspect = StoryView.size.aspectFitted(size)
            let current = StoryView(frame: aspect.bounds)
            self.current = current
            content.addSubview(current, positioned: .below, relativeTo: self.controls)
            self.updateLayout(size: frame.size, transition: .immediate)
        }
        
    }
    
    private let disposable = MetaDisposable()
    func redraw() {
        guard let context = context, let arguments = self.arguments, let entry = self.entry else {
            return
        }
        let groupId = entry.peer.id
        let previous = self.current
        
        let size = NSMakeSize(frame.width - 100, frame.height - 110)
        let aspect = StoryView.size.aspectFitted(size)
        let current = StoryView.makeView(for: entry.item.storyItem, peerId: entry.peer.id, peer: entry.peer._asPeer(), context: context, frame: aspect.bounds)
        
        self.current = current
        
        
        if let previous = previous {
            previous.onStateUpdate = nil
            previous.disappear()
        }
        
        let story = entry.item
        


        
        self.content.addSubview(current, positioned: .below, relativeTo: self.controls)
        
        
        if entry.previousItemId != nil {
            let current: ShadowView
            if let view = self.prevStoryView {
                current = view
            } else {
                current = ShadowView()
                current.isEventLess = true
                current.shadowBackground = NSColor.black.withAlphaComponent(0.15)
                current.layer?.opacity = 0
                self.prevStoryView = current
            }
            self.content.addSubview(current, positioned: .above, relativeTo: self.current)
            current.direction = .horizontal(false)
        } else if let view = self.prevStoryView {
            performSubviewRemoval(view, animated: false)
            self.prevStoryView = nil
        }
        if entry.nextItemId != nil {
            let current: ShadowView
            if let view = self.nextStoryView {
                current = view
            } else {
                current = ShadowView()
                current.isEventLess = true
                current.layer?.opacity = 0
                current.shadowBackground = NSColor.black.withAlphaComponent(0.2)
                self.nextStoryView = current
            }
            self.content.addSubview(current, positioned: .above, relativeTo: self.current)
            current.direction = .horizontal(true)
        } else if let view = self.nextStoryView {
            performSubviewRemoval(view, animated: false)
            self.nextStoryView = nil
        }
        
        self.updateLayout(size: self.frame.size, transition: .immediate)

        self.controls.update(context: context, arguments: arguments, groupId: groupId, peer: entry.peer._asPeer(), slice: entry, story: story, animated: false)

        
        arguments.interaction.flushPauses()
        if arguments.interaction.presentation.entryId == groupId {
            arguments.markAsRead(groupId, story.storyItem.id)
        }

        current.onStateUpdate = { [weak self] state in
            self?.updateStoryState(state)
        }
        
        current.appear(isMuted: arguments.interaction.presentation.isMuted)
        self.updateStoryState(current.state)

        self.inputView.update(entry.item, animated: false)
        
        self.updateText(story.storyItem, state: .concealed, animated: false, context: context)
        
        self.ready.set(true)
        
        
        let ready: Signal<Bool, NoError> = current.getReady
        
        _ = ready.start(next: { [weak previous, weak current] _ in
            previous?.removeFromSuperview()
            current?.backgroundColor = NSColor.black
        })
        
    }
    
    private func updateText(_ story: EngineStoryItem, state: Text.State, animated: Bool, context: AccountContext) {
        
        let text = story.text
        
        let entities: [MessageTextEntity] = story.entities
        
        if !text.isEmpty, !(story.media._asMedia() is TelegramMediaUnsupported) {
            let current: Text
            if let view = self.text {
                current = view
            } else {
                current = Text(frame: NSMakeRect(0, container.frame.maxY - 100, container.frame.width, controls.frame.height))
                self.text = current
                content.addSubview(current, positioned: .above, relativeTo: controls)
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
        guard let view = self.current, let entry = self.entry else {
            return
        }
        
        switch state {
        case .playing:
            self.navigator.set(entry.item.dayCounters?.position ?? entry.item.position ?? 0, state: view.state, duration: view.duration, animated: true)
        case .finished:
            self.arguments?.nextStory()
        default:
            self.navigator.set(entry.item.dayCounters?.position ?? entry.item.position ?? 0, state: view.state, duration: view.duration, animated: true)
        }
    }
    
    var contentSize: NSSize {
        return self.container.frame.size
    }
    var contentRect: CGRect {
        let maxSize = NSMakeSize(frame.width - 100, frame.height - 110)
        let aspect = StoryView.size.aspectFitted(maxSize)
        return CGRect(origin: CGPoint(x: floorToScreenPixels(backingScaleFactor, (frame.width - aspect.width) / 2), y: 20), size: NSMakeSize(aspect.width, frame.height))
    }
    var storyRect: CGRect {
        if let current = self.current {
            return NSMakeRect(contentRect.minX, 20, current.frame.width, current.frame.height)
        }
        return self.container.frame
    }
    
    
    func previous() -> UpdateIndexResult {
        guard let entry = self.entry else {
            return .invoked
        }
        if entry.previousItemId != nil {
            return .invoked
        } else {
            return .moveBack
        }
    }
    
    func next() -> UpdateIndexResult {
        guard let entry = self.entry else {
            return .invoked
        }
        if entry.nextItemId != nil {
            return .invoked
        } else {
            return .moveNext
        }
    }
    
    func restart() {
        self.current?.restart()
//        self.select(at: 0)
    }
    
    func play() {
        self.current?.play()
    }
    func pause() {
        self.current?.pause()
    }
    
    func showVoiceError() {
        if let control = (self.inputView as? StoryInputView)?.actionControl, let peer = self.story?.peer?._asPeer() {
            tooltip(for: control, text: strings().chatSendVoicePrivacyError(peer.compactDisplayTitle))
        }
    }
    
    func showShareError() {
        if let control = (self.inputView as? StoryInputView)?.actionControl {
            tooltip(for: control, text: "This story can't be shared")
        }
    }
    
    deinit {
        self.disposable.dispose()
        magnifyDispsosable.dispose()
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
    
    var hasInput: Bool {
        return self.textView != nil
    }

}
