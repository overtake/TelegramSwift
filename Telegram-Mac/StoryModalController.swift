//
//  StoryModalController.swift
//  Telegram
//
//  Created by Mike Renoir on 24.04.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import ColorPalette
import TGModernGrowingTextView

private struct Reaction {
    let item: UpdateMessageReaction
    let fromRect: CGRect?
}


let storyTheme = generateTheme(palette: nightAccentPalette, cloudTheme: nil, bubbled: false, fontSize: 13, wallpaper: .init())


final class StoryInteraction : InterfaceObserver {
    struct State : Equatable {
        var inputs: [PeerId : ChatTextInputState] = [:]
        
        var input: ChatTextInputState {
            if let groupId = groupId {
                if let input = inputs[groupId] {
                    return input
                }
            }
            return ChatTextInputState()
        }
        
        var mouseDown: Bool = false
        var inputInFocus: Bool = false
        var hasPopover: Bool = false
        var hasMenu: Bool = false
        var hasModal: Bool = false
        var windowIsKey: Bool = false
        var inTransition: Bool = false
        var isRecording: Bool = false
        var hasReactions: Bool = false
        var isSpacePaused: Bool = false
        var playingReaction: Bool = false
        var isMuted: Bool = false
        var storyId: MessageId? = nil
        var groupId: PeerId? = nil
        var recordType: RecordingStateSettings = FastSettings.recordingState
        var isPaused: Bool {
            return mouseDown || inputInFocus || hasPopover || hasModal || !windowIsKey || inTransition || isRecording || hasMenu || hasReactions || playingReaction || isSpacePaused
        }
        
    }
    fileprivate(set) var presentation: State
    init(presentation: State = .init()) {
        self.presentation = presentation
    }
    
    func update(animated:Bool = true, _ f:(State)->State)->Void {
        let oldValue = self.presentation
        self.presentation = f(presentation)
        if oldValue != presentation {
            notifyObservers(value: presentation, oldValue:oldValue, animated: animated)
        }
    }
    
    func toggleMuted() {
        self.update { current in
            var current = current
            current.isMuted = !current.isMuted
            return current
        }
    }
    func flushPauses() {
        self.update { current in
            var current = current
            current.isSpacePaused = false
            return current
        }
    }
    
    func canBeMuted(_ story: Message) -> Bool {
        return story.media.first is TelegramMediaFile
    }
    
    func updateInput(with text:String) {
        let state = ChatTextInputState(inputText: text, selectionRange: text.length ..< text.length, attributes: [])
        self.update({ current in
            var current = current
            if let groupId = current.groupId {
                current.inputs[groupId] = state
            }
            return current
        })
    }
    func appendText(_ text: NSAttributedString, selectedRange:Range<Int>? = nil) -> Range<Int> {

        var selectedRange = selectedRange ?? presentation.input.selectionRange
        let inputText = presentation.input.attributedString(storyTheme).mutableCopy() as! NSMutableAttributedString
        
        
        if selectedRange.upperBound - selectedRange.lowerBound > 0 {

            inputText.replaceCharacters(in: NSMakeRange(selectedRange.lowerBound, selectedRange.upperBound - selectedRange.lowerBound), with: text)
            selectedRange = selectedRange.lowerBound ..< selectedRange.lowerBound
        } else {
            inputText.insert(text, at: selectedRange.lowerBound)
        }
        
        let nRange:Range<Int> = selectedRange.lowerBound + text.length ..< selectedRange.lowerBound + text.length
        let state = ChatTextInputState(inputText: inputText.string, selectionRange: nRange, attributes: chatTextAttributes(from: inputText))
        self.update({ current in
            var current = current
            if let groupId = current.groupId {
                current.inputs[groupId] = state
            }
            return current
        })
        
        return selectedRange.lowerBound ..< selectedRange.lowerBound + text.length
    }
//
//    func appendText(_ text:String, selectedRange:Range<Int>? = nil) -> Range<Int> {
//        return self.appendText(NSAttributedString(string: text, font: .normal(theme.fontSize)), selectedRange: selectedRange)
//    }

}

final class StoryArguments {
    let context: AccountContext
    let interaction: StoryInteraction
    let chatInteraction: ChatInteraction
    let showEmojiPanel:(Control)->Void
    let showReactionsPanel:(Control)->Void
    let attachPhotoOrVideo:(ChatInteraction.AttachMediaType?)->Void
    let attachFile:()->Void
    let nextStory:()->Void
    let prevStory:()->Void
    let close:()->Void
    let openPeerInfo:(PeerId)->Void
    let openChat:(PeerId)->Void
    let sendMessage:()->Void
    let toggleRecordType:()->Void
    init(context: AccountContext, interaction: StoryInteraction, chatInteraction: ChatInteraction, showEmojiPanel:@escaping(Control)->Void, showReactionsPanel:@escaping(Control)->Void, attachPhotoOrVideo:@escaping(ChatInteraction.AttachMediaType?)->Void, attachFile:@escaping()->Void, nextStory:@escaping()->Void, prevStory:@escaping()->Void, close:@escaping()->Void, openPeerInfo:@escaping(PeerId)->Void, openChat:@escaping(PeerId)->Void, sendMessage:@escaping()->Void, toggleRecordType:@escaping()->Void) {
        self.context = context
        self.interaction = interaction
        self.chatInteraction = chatInteraction
        self.showEmojiPanel = showEmojiPanel
        self.showReactionsPanel = showReactionsPanel
        self.attachPhotoOrVideo = attachPhotoOrVideo
        self.attachFile = attachFile
        self.nextStory = nextStory
        self.prevStory = prevStory
        self.close = close
        self.openPeerInfo = openPeerInfo
        self.openChat = openChat
        self.sendMessage = sendMessage
        self.toggleRecordType = toggleRecordType
    }
    
    func longDown() {
        self.interaction.update { current in
            var current = current
            current.mouseDown = true
            return current
        }
    }
    func longUp() {
        self.interaction.update { current in
            var current = current
            current.mouseDown = false
            return current
        }
    }
    func inputFocus() {
        self.interaction.update { current in
            var current = current
            current.inputInFocus = true
            current.isSpacePaused = true
            return current
        }
    }
    func inputUnfocus() {
        self.interaction.update { current in
            var current = current
            current.inputInFocus = false
            current.isSpacePaused = false
            return current
        }
    }
}


private final class StoryBgView: TransformImageView {
    private let bgView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bgView.frame = frameRect.size.bounds
        bgView.backgroundColor = .blackTransparent
        addSubview(bgView)
    }
    
    override func layout() {
        super.layout()
        bgView.frame = frame.size.bounds
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var message: Message? = nil
    
    func update(context: AccountContext, parent: Message) {
        
        let updated = self.message?.id != parent.id && self.message != nil
        var updateImageSignal: Signal<ImageDataTransformation, NoError>?
        self.message = parent
        
        
        if let media = parent.media.first {
            let size = frame.size
            var dimensions: NSSize = size
            
            if let image = media as? TelegramMediaImage {
                dimensions = image.representations.first?.dimensions.size ?? dimensions
            } else if let file = media as? TelegramMediaFile {
                dimensions = file.dimensions?.size ?? dimensions
            }
            
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: NSEdgeInsets(), resizeMode: .none)

            
            if let image = media as? TelegramMediaImage {

                if parent.containsSecretMedia {
                    updateImageSignal = chatSecretPhoto(account: context.account, imageReference: ImageMediaReference.message(message: MessageReference(parent), media: image), scale: backingScaleFactor, synchronousLoad: false)
                } else {
                    updateImageSignal = chatMessagePhoto(account: context.account, imageReference: ImageMediaReference.message(message: MessageReference(parent), media: image), scale: backingScaleFactor, synchronousLoad: false)
                }
            } else if let file = media as? TelegramMediaFile {
                
                let fileReference = FileMediaReference.message(message: MessageReference(parent), media: file)
                
               
                if parent.containsSecretMedia {
                    updateImageSignal = chatSecretMessageVideo(account: context.account, fileReference: fileReference, scale: backingScaleFactor)
                } else {
                    updateImageSignal = chatMessageVideo(postbox: context.account.postbox, fileReference: fileReference, scale: backingScaleFactor)
                }
            }
            
            self.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: backingScaleFactor, positionFlags: nil), clearInstantly: false, animate: updated)

            if let updateImageSignal = updateImageSignal, !isFullyLoaded {
                self.setSignal(updateImageSignal, animate: updated, cacheImage: { [weak media] result in
                    if let media = media {
                        cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale, positionFlags: nil)
                    }
                })
            }
            self.set(arguments: arguments)
            
        }
    }
}

private let next_chevron = NSImage(named: "Icon_StoryChevron")!.precomposed(NSColor.white.withAlphaComponent(0.53))
private let prev_chevron = NSImage(named: "Icon_StoryChevron")!.precomposed(NSColor.white.withAlphaComponent(0.53), flipHorizontal: true)

private let next_chevron_hover = NSImage(named: "Icon_StoryChevron")!.precomposed(NSColor.white.withAlphaComponent(1))
private let prev_chevron_hover = NSImage(named: "Icon_StoryChevron")!.precomposed(NSColor.white.withAlphaComponent(1), flipHorizontal: true)

private let close_image = NSImage(named: "Icon_StoryClose")!.precomposed(NSColor.white.withAlphaComponent(0.53))
private let close_image_hover = NSImage(named: "Icon_StoryClose")!.precomposed(NSColor.white.withAlphaComponent(1))


private func storyReactions(context: AccountContext, peerId: PeerId, react: @escaping(Reaction)->Void, onClose: @escaping()->Void) -> Signal<NSView?, NoError> {
    
    
    let builtin = context.reactions.stateValue
    let peerAllowed: Signal<PeerAllowedReactions?, NoError> = getCachedDataView(peerId: peerId, postbox: context.account.postbox)
    |> map { cachedData in
        if let cachedData = cachedData as? CachedGroupData {
            return cachedData.allowedReactions.knownValue
        } else if let cachedData = cachedData as? CachedChannelData {
            return cachedData.allowedReactions.knownValue
        } else {
            return nil
        }
    }
    |> take(1)
    
    var orderedItemListCollectionIds: [Int32] = []
    
    orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudRecentReactions)
    orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudTopReactions)

    let reactions:Signal<[RecentReactionItem], NoError> = context.diceCache.emojies_reactions |> map { view in
        
        var recentReactionsView: OrderedItemListView?
        var topReactionsView: OrderedItemListView?
        for orderedView in view.orderedItemListsViews {
            if orderedView.collectionId == Namespaces.OrderedItemList.CloudRecentReactions {
                recentReactionsView = orderedView
            } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudTopReactions {
                topReactionsView = orderedView
            }
        }
        var recentReactionsItems:[RecentReactionItem] = []
        var topReactionsItems:[RecentReactionItem] = []

        if let recentReactionsView = recentReactionsView {
            for item in recentReactionsView.items {
                guard let item = item.contents.get(RecentReactionItem.self) else {
                    continue
                }
                recentReactionsItems.append(item)
            }
        }
        if let topReactionsView = topReactionsView {
            for item in topReactionsView.items {
                guard let item = item.contents.get(RecentReactionItem.self) else {
                    continue
                }
                topReactionsItems.append(item)
            }
        }
        return topReactionsItems.filter { value in
            if context.isPremium {
                return true
            } else {
                if case .custom = value.content {
                    return false
                } else {
                    return true
                }
            }
        }
    }
    
    
    let signal = combineLatest(queue: .mainQueue(), builtin, peerAllowed, reactions)
    |> take(1)

    return signal |> map { builtin, peerAllowed, reactions in
        let enabled = builtin?.enabled ?? []

        var available:[ContextReaction] = []
        
        
        let accessToAll: Bool = true
        
        available = reactions.compactMap { value in
            switch value.content {
            case let .builtin(emoji):
                if let generic = enabled.first(where: { $0.value.string == emoji }) {
                    return .builtin(value: generic.value, staticFile: generic.staticIcon, selectFile: generic.selectAnimation, appearFile: generic.appearAnimation, isSelected: false)
                } else {
                    return nil
                }
            case let .custom(file):
                return .custom(value: .custom(file.fileId.id), fileId: file.fileId.id, file, isSelected: false)
            }
        }
        
        
        guard !available.isEmpty else {
            return nil
        }
        
        if accessToAll {
            available = Array(available.prefix(6))
        }
        
        let width = ContextAddReactionsListView.width(for: available.count, maxCount: 6, allowToAll: accessToAll)
        
        
        let rect = NSMakeRect(0, 0, width + 20 + (accessToAll ? 0 : 20), 40 + 20)
        
        
        let panel = Window(contentRect: rect, styleMask: [.fullSizeContentView], backing: .buffered, defer: false)
        panel._canBecomeMain = false
        panel._canBecomeKey = false
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        

        let reveal:((NSView & StickerFramesCollector)->Void)?
        
       
        
        reveal = { view in
            let window = ReactionsWindowController(context, peerId: peerId, selectedItems: [], react: { sticker, fromRect in
                let value: UpdateMessageReaction
                if let bundle = sticker.file.stickerText {
                    value = .builtin(bundle)
                } else {
                    value = .custom(fileId: sticker.file.fileId.id, file: sticker.file)
                }
                react(.init(item: value, fromRect: fromRect))
                onClose()
            }, onClose: onClose, presentation: storyTheme)
            window.show(view)
        }
        
        let view = ContextAddReactionsListView(frame: rect, context: context, list: available, add: { value, checkPrem, fromRect in
            react(.init(item: value.toUpdate(), fromRect: fromRect))
            onClose()
        }, radiusLayer: nil, revealReactions: reveal, presentation: storyTheme)
        
        return view
    } |> deliverOnMainQueue
}

private final class StoryViewController: Control, Notifable {
    
    class TooptipView : NSVisualEffectView {
        
        enum Source {
            case reaction(Reaction)
            case media([Media])
            case text
        }
        private let textView = TextView()
        private let button = TitleButton()
        private let media = View(frame: NSMakeRect(0, 0, 24, 24))
        
        required override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.wantsLayer = true
            self.state = .active
            self.material = .ultraDark
            self.blendingMode = .withinWindow
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            addSubview(textView)
            addSubview(button)
            addSubview(media)
            button.autohighlight = false
            button.scaleOnClick = true
            self.layer?.cornerRadius = 10
        }
        
        func update(source: Source, size: NSSize, context: AccountContext, callback: @escaping()->Void) {
            let title: String
            var mediaFile: TelegramMediaFile
            switch source {
            case .media:
                title = "Media Sent."
                mediaFile = MenuAnimation.menu_success.file
            case let .reaction(reaction):
                title = "Reaction Sent."
                var file: TelegramMediaFile?
                switch reaction.item {
                case let .custom(_, f):
                    file = f
                case let .builtin(string):
                    let reaction = context.reactions.available?.reactions.first(where: { $0.value.string == string })
                    file = reaction?.selectAnimation
                }
                if let file = file {
                    mediaFile = file
                } else {
                    mediaFile = MenuAnimation.menu_success.file
                }
            case .text:
                title = "Message Sent."
                mediaFile = MenuAnimation.menu_success.file
            }
            
            let mediaLayer = InlineStickerItemLayer(account: context.account, file: mediaFile, size: NSMakeSize(24, 24), playPolicy: .toEnd(from: 0), getColors: { file in
                if file == MenuAnimation.menu_success.file {
                    return []
                } else {
                    return []
                }
            })
            mediaLayer.isPlayable = true
            
            self.media.layer?.addSublayer(mediaLayer)
            
            let layout = TextViewLayout(.initialize(string: title, color: storyTheme.colors.text, font: .normal(.text)))
            
            
            self.button.set(font: .medium(.text), for: .Normal)
            self.button.set(color: storyTheme.colors.accent, for: .Normal)
            self.button.set(text: "View in Chat", for: .Normal)
            self.button.sizeToFit(NSMakeSize(10, 10), .zero, thatFit: false)
            
            layout.measure(width: size.width - 16 - 16 - self.button.frame.width - media.frame.width - 10 - 10)
            textView.update(layout)

            
            self.button.set(handler: { _ in
                callback()
            }, for: .Click)
            
            self.setFrameSize(size)
            self.updateLayout(size: size, transition: .immediate)
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            transition.updateFrame(view: media, frame: media.centerFrameY(x: 16))
            transition.updateFrame(view: textView, frame: textView.centerFrameY(x: media.frame.maxX + 10))
            transition.updateFrame(view: button, frame: button.centerFrameY(x: size.width - button.frame.width - 16))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
   
    private let bgImageView = StoryBgView(frame: .zero)
    private let visualEffect = NSVisualEffectView()
    private var current: StoryListView?
    private var arguments:StoryArguments?
    
    private let next_button: ImageButton = ImageButton()
    private let prev_button: ImageButton = ImageButton()
    private let close: ImageButton = ImageButton()

    private var groups:[[Message]] = []
    
    private func findStory(_ storyId: MessageId?) -> Message? {
        return groups.reduce([], { $0 + $1 }).first(where: { $0.id == storyId })
    }
    
    private var currentIndex: Int? = nil
    
    private let container = View()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(bgImageView)
        addSubview(visualEffect)
        addSubview(container)
        
        prev_button.autohighlight = false
        prev_button.scaleOnClick = true
        
        next_button.autohighlight = false
        next_button.scaleOnClick = true
        

        
        prev_button.set(image: prev_chevron, for: .Normal)
        next_button.set(image: next_chevron, for: .Normal)
        
        prev_button.set(image: prev_chevron_hover, for: .Hover)
        next_button.set(image: next_chevron_hover, for: .Hover)

        prev_button.set(image: prev_chevron_hover, for: .Highlight)
        next_button.set(image: next_chevron_hover, for: .Highlight)

        
        next_button.sizeToFit(.zero, NSMakeSize(100, 100), thatFit: true)
        prev_button.sizeToFit(.zero, NSMakeSize(100, 100), thatFit: true)

        next_button.controlOpacityEventIgnored = true
        prev_button.controlOpacityEventIgnored = true

        addSubview(prev_button)
        addSubview(next_button)
        
        
        close.set(image: close_image, for: .Normal)
        close.set(image: close_image_hover, for: .Hover)
        close.set(image: close_image_hover, for: .Highlight)
        close.sizeToFit(.zero, NSMakeSize(50, 50), thatFit: true)
        close.autohighlight = false
        close.scaleOnClick = true
        
        close.set(handler: { [weak self] _ in
            self?.arguments?.close()
        }, for: .Click)
        
        next_button.sizeToFit(.zero, NSMakeSize(100, 100), thatFit: true)
        prev_button.sizeToFit(.zero, NSMakeSize(100, 100), thatFit: true)

        
        addSubview(close)
        
        visualEffect.state = .active
        visualEffect.material = .ultraDark
        visualEffect.blendingMode = .withinWindow
        
        bgImageView.layer?.opacity = 0.2
        
        self.updateLayout(size: self.frame.size, transition: .immediate)
        
        prev_button.set(handler: { [weak self] _ in
            self?.processGroupResult(.moveBack, animated: true)
        }, for: .Click)
        
        next_button.set(handler: { [weak self] _ in
            self?.processGroupResult(.moveNext, animated: true)
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        self.updatePrevNextControls(event)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        self.updatePrevNextControls(event)
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        self.updatePrevNextControls(event)
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        guard let context = self.arguments?.context else {
            return
        }
        let value = value as? StoryInteraction.State
        let oldValue = oldValue as? StoryInteraction.State
        if value?.storyId != oldValue?.storyId, let story = findStory(value?.storyId) {
            self.bgImageView.update(context: context, parent: story)
        }
        if let event = NSApp.currentEvent {
            self.updatePrevNextControls(event)
        }
    }
    
    func isEqual(to other: Notifable) -> Bool {
        return self === other as? StoryViewController
    }
    
    var isPaused: Bool {
        return self.arguments?.interaction.presentation.isPaused ?? false
    }
    var isInputFocused: Bool {
        return self.arguments?.interaction.presentation.inputInFocus ?? false
    }
    
    var hasNextGroup: Bool {
        guard let currentIndex = self.currentIndex, !isPaused else {
            return false
        }
        return currentIndex < groups.count - 1
    }
    var hasPrevGroup: Bool {
        guard let currentIndex = self.currentIndex, !isPaused else {
            return false
        }
        return currentIndex > 0
    }
    
    private func updatePrevNextControls(_ event: NSEvent) {
        guard let current = self.current else {
            return
        }
        let point = self.convert(event.locationInWindow, from: nil)
        
        if point.x < current.contentRect.minX {
            self.prev_button.change(opacity: hasPrevGroup ? 1 : 0, animated: true)
            self.next_button.change(opacity: 0, animated: true)
        } else {
            self.prev_button.change(opacity: 0, animated: true)
        }
        
        if point.x > current.contentRect.maxX {
            self.next_button.change(opacity: hasNextGroup ? 1 : 0, animated: true)
            self.prev_button.change(opacity: 0, animated: true)
        } else {
            self.next_button.change(opacity: 0, animated: true)
        }
    }
    
    
    
    
    func update(context: AccountContext, messages: [Message], initial: MessageId) {
                
        var groups:[[Message]] = []
        
        if messages.isEmpty {
            return
        }
        
        for message in messages {
            let index = groups.firstIndex(where: { $0.contains(where: { $0.author?.id == message.author?.id })})
            if let index = index {
                groups[index].append(message)
            } else {
                groups.append([message])
            }
        }
        
        self.groups = groups
                
        let storyView = StoryListView(frame: bounds)
        storyView.setArguments(self.arguments)
        
        
        let initialGroupIndex = groups.firstIndex(where: { $0.contains(where: { $0.id == initial })}) ?? 0
        let group = groups[initialGroupIndex]
        let groupId = group[0].author!.id
        
        self.currentIndex = initialGroupIndex
        let initialIndex = group.firstIndex(where: { $0.id == initial }) ?? 0
        
        storyView.update(context: context, stories: group, selected: initialIndex)
        self.current = storyView
        
        
        container.addSubview(storyView)
        
        if let event = NSApp.currentEvent {
            self.updatePrevNextControls(event)
        }
        
        arguments?.interaction.update { current in
            var current = current
            current.groupId = groupId
            return current
        }
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    func previous() -> KeyHandlerResult {
        if isInputFocused {
            return .invokeNext
        }
        guard !inTransition, let result = self.current?.previous() else {
            return .invokeNext
        }
        self.processGroupResult(result, animated: true)
        return .invoked
    }
    func next() -> KeyHandlerResult {
        if isInputFocused {
            return .invokeNext
        }
        guard !inTransition, let result = self.current?.next() else {
            return .invokeNext
        }
        self.processGroupResult(result, animated: true)
        return .invoked
    }
    
    private var inTransition: Bool {
        get {
            return self.arguments?.interaction.presentation.inTransition ?? false
        }
        set {
            self.arguments?.interaction.update { current in
                var current = current
                current.inTransition = newValue
                return current
            }
        }
    }
    
    @discardableResult private func processGroupResult(_ result: StoryListView.UpdateIndexResult, animated: Bool, bySwipe: Bool = false) -> Int? {
        
        let previousIndex = self.currentIndex

        
        guard let currentIndex = self.currentIndex, let context = self.arguments?.context, !inTransition else {
            return previousIndex
        }
        
        
        if self.isInputFocused {
            self.resetInputView()
            return previousIndex
        }
        
        let nextGroupIndex: Int?
        switch result {
        case .invoked:
            nextGroupIndex = nil
        case .moveNext:
            nextGroupIndex = currentIndex + 1
        case .moveBack:
            nextGroupIndex = currentIndex - 1
        }
        
        if let nextGroupIndex = nextGroupIndex {
            if nextGroupIndex >= 0 && nextGroupIndex < self.groups.count {
                
                inTransition = true
                
                self.arguments?.interaction.flushPauses()
                
                let group = groups[nextGroupIndex]
                let groupId = group[0].author!.id
                
                
                let isNext = currentIndex < nextGroupIndex
                let initialIndex = !isNext ? group.count - 1 : 0
                self.currentIndex = nextGroupIndex
                
                self.arguments?.interaction.update { current in
                    var current = current
                    current.groupId = groupId
                    return current
                }
                
                let storyView = StoryListView(frame: bounds)
                storyView.setArguments(self.arguments)
                
                storyView.update(context: context, stories: group, selected: initialIndex)
                
                
                let previous = self.current
                self.current = storyView
                if isNext {
                    container.addSubview(storyView, positioned: .above, relativeTo: previous)
                } else {
                    container.addSubview(storyView, positioned: .below, relativeTo: previous)
                }
                
                if let previous = previous {
                    storyView.initAnimateTranslate(previous: previous, direction: isNext ? .left : .right)
                    if !bySwipe {
                        storyView.translate(progress: 0, finish: true, completion: { [weak self] completion, _ in
                            self?.inTransition = false
                        })
                    }
                }
                
            } else {
                current?.shake(beep: false)
            }
        }
        if let event = NSApp.currentEvent {
            self.updatePrevNextControls(event)
        }
        
        return previousIndex
    }

    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: self.visualEffect, frame: size.bounds)
        transition.updateFrame(view: self.bgImageView, frame: size.bounds)
        transition.updateFrame(view: container, frame: size.bounds)
        if let current = self.current {
            transition.updateFrame(view: current, frame: size.bounds)
            current.updateLayout(size: size, transition: transition)

            transition.updateFrame(view: prev_button, frame: NSMakeRect(0, 0, (size.width - current.contentRect.width) / 2, size.height))
            transition.updateFrame(view: next_button, frame: NSMakeRect((size.width - current.contentRect.width) / 2 + current.contentRect.width, 0, (size.width - current.contentRect.width) / 2, size.height))
            
        }
        if let overlay = self.reactionsOverlay {
            transition.updateFrame(view: overlay, frame: size.bounds)
        }
        transition.updateFrame(view: close, frame: NSMakeRect(size.width - close.frame.width, 0, 50, 50))
    }
    
    var inputView: NSTextView? {
        return self.current?.textView
    }
    var inputTextView: TGModernGrowingTextView? {
        return self.current?.inputTextView
    }
    func makeUrl() {
        self.current?.makeUrl()
    }
    
    func resetInputView() {
        self.current?.resetInputView()
    }
    func setArguments(_ arguments: StoryArguments?) -> Void {
        self.arguments = arguments
        self.current?.setArguments(arguments)
    }
    
    private var reactionsOverlay: Control? = nil
   
    func closeReactions() {
        if let view = self.reactionsOverlay {
            performSubviewRemoval(view, animated: true)
            self.reactionsOverlay = nil
        }
        
        self.arguments?.interaction.update { current in
            var current = current
            current.hasReactions = false
            return current
        }
    }
    
    func playReaction(_ reaction: Reaction) -> Void {
        
        guard let arguments = self.arguments else {
            return
        }
        
        let context = arguments.context
        
        var file: TelegramMediaFile?
        var effectFileId: Int64?
        var effectFile: TelegramMediaFile?
        switch reaction.item {
        case let .custom(_, f):
            file = f
            effectFileId = f?.fileId.id
        case let .builtin(string):
            let reaction = context.reactions.available?.reactions.first(where: { $0.value.string == string })
            file = reaction?.selectAnimation
            effectFile = reaction?.aroundAnimation
        }
        
        guard let icon = file else {
            return
        }
       
        
        arguments.interaction.update { current in
            var current = current
            current.playingReaction = true
            current.inTransition = true
            return current
        }
        let overlay = View(frame: NSMakeRect(0, 0, 300, 300))
        addSubview(overlay)
        overlay.center()
        
        let finish:()->Void = { [weak arguments, weak overlay] in
            arguments?.interaction.update { current in
                var current = current
                current.playingReaction = false
                current.inTransition = false
                return current
            }
            if let overlay = overlay {
                performSubviewRemoval(overlay, animated: true)
            }
        }
        
        let play:(NSView, TelegramMediaFile)->Void = { container, icon in
            
            let layer = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: icon.fileId.id, file: icon, emoji: ""), size: NSMakeSize(30, 30), playPolicy: .once)
            layer.isPlayable = true
            
            layer.frame = NSMakeRect((container.frame.width - layer.frame.width) / 2, (container.frame.height - layer.frame.height) / 2, layer.frame.width, layer.frame.height)
            container.layer?.addSublayer(layer)

            
            if let effectFileId = effectFileId {
                let player = CustomReactionEffectView(frame: NSMakeSize(300, 300).bounds, context: context, fileId: effectFileId)
                player.isEventLess = true
                player.triggerOnFinish = { [weak player] in
                    player?.removeFromSuperview()
                    finish()
                }
                let rect = CGRect(origin: CGPoint(x: 0, y: 0), size: player.frame.size)
                player.frame = rect
                container.addSubview(player)
            } else if let effectFile = effectFile {
                let player = InlineStickerItemLayer(account: context.account, file: effectFile, size: NSMakeSize(150, 150), playPolicy: .playCount(1))
                player.isPlayable = true
                player.frame = NSMakeRect(75, 75, 150, 150)
                container.layer?.addSublayer(player)
                player.triggerOnState = (.finished, { [weak player] state in
                    player?.removeFromSuperlayer()
                    finish()
                })
            }
            
        }
        
        let layer = InlineStickerItemLayer(account: context.account, file: icon, size: NSMakeSize(30, 30))

            let completed: (Bool)->Void = { [weak overlay] _ in
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
            DispatchQueue.main.async {
                if let container = overlay {
                    play(container, icon)
                }
            }
        }
        if let fromRect = reaction.fromRect {
            let toRect = overlay.convert(overlay.frame.size.bounds, to: nil)
            
            let from = fromRect.origin.offsetBy(dx: fromRect.width / 2, dy: fromRect.height / 2)
            let to = toRect.origin.offsetBy(dx: toRect.width / 2, dy: toRect.height / 2)
            parabollicReactionAnimation(layer, fromPoint: from, toPoint: to, window: context.window, completion: completed)
        } else {
            completed(true)
        }
        
    }
    
    func showReactions(_ view: NSView, control: Control) {
        
        guard let superview = control.superview else {
            return
        }
        
        let reactionsOverlay = Control(frame: bounds)
        reactionsOverlay.backgroundColor = NSColor.black.withAlphaComponent(0.2)
        reactionsOverlay.addSubview(view)
        addSubview(reactionsOverlay)
        
        
        reactionsOverlay.set(handler: { [weak self] _ in
            self?.closeReactions()
        }, for: .Click)
        
        self.reactionsOverlay = reactionsOverlay
        
        reactionsOverlay.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        
        
        let point = superview.convert(control.frame.origin, to: reactionsOverlay)
        
        view.setFrameOrigin(NSMakePoint(point.x - view.frame.width + 75, point.y - view.frame.height + 5))
        
        self.arguments?.interaction.update { current in
            var current = current
            current.hasReactions = true
            return current
        }
    }
    
    deinit {
        tooltipDisposable.dispose()
    }
    
    private var currentTooltip: TooptipView?
    private let tooltipDisposable = MetaDisposable()
    func showTooltip(_ source: TooptipView.Source) {
        
        self.resetInputView()
        
        if let view = currentTooltip {
            performSubviewRemoval(view, animated: true, scale: true)
            self.currentTooltip = nil
            self.tooltipDisposable.set(nil)
        }
        
        guard let arguments = self.arguments, let current = self.current, let groupId = arguments.interaction.presentation.groupId else {
            return
        }
        
        let tooltip = TooptipView(frame: .zero)
        
        tooltip.update(source: source, size: NSMakeSize(current.contentRect.width - 20, 40), context: arguments.context, callback: { [weak arguments] in
            arguments?.openChat(groupId)
        })
        
        self.addSubview(tooltip)
        tooltip.centerX(y: current.contentRect.maxY - 50 - 10 - tooltip.frame.height - 40)
        
        tooltip.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        tooltip.layer?.animatePosition(from: tooltip.frame.origin.offsetBy(dx: 0, dy: 20), to: tooltip.frame.origin)
        let signal = Signal<Void, NoError>.single(Void()) |> delay(3.5, queue: .mainQueue())
        self.tooltipDisposable.set(signal.start(completed: { [weak self] in
            if let view = self?.currentTooltip {
                performSubviewRemoval(view, animated: true)
                self?.currentTooltip = nil
            }
        }))
        
        self.currentTooltip = tooltip
    }
    
    private var scrollDeltaX: CGFloat = 0
    private var scrollDeltaY: CGFloat = 0

    private var previousIndex: Int? = nil
    
    private func returnGroupIndex(_ index: Int, previous: StoryListView) {
        self.currentIndex = index
        let groupId = self.groups[index][0].author!.id
        
        let cur = self.current
        self.current?.removeFromSuperview()
        
        self.current = previous
        
        let storyId = previous.storyId
        
        container.addSubview(previous, positioned: .above, relativeTo: cur)

        self.arguments?.interaction.update { current in
            var current = current
            current.groupId = groupId
            current.inTransition = false
            current.storyId = storyId
            return current
        }
    }
    
    override func scrollWheel(with theEvent: NSEvent) {
        
        
        let completeTransition:(Bool, StoryListView)->Void = { [weak self] completed, previous in
            if !completed, let previousIndex = self?.previousIndex {
                self?.returnGroupIndex(previousIndex, previous: previous)
            } else {
                self?.inTransition = false
            }
        }
        
        if theEvent.phase == .began {
            if self.inTransition {
                return
            }
            
            scrollDeltaX = theEvent.scrollingDeltaX
            if scrollDeltaX == 0 {
                scrollDeltaY = theEvent.scrollingDeltaY
            }
            
            if scrollDeltaX > 0 {
                previousIndex = self.processGroupResult(.moveBack, animated: true, bySwipe: true)
            } else if scrollDeltaX < 0 {
                previousIndex = self.processGroupResult(.moveNext, animated: true, bySwipe: true)
            }
        } else if theEvent.phase == .changed {
            let previous = self.scrollDeltaX
            if scrollDeltaX > 0, scrollDeltaX + theEvent.scrollingDeltaX <= 0 {
                scrollDeltaX = 1
            } else if scrollDeltaX < 0, scrollDeltaX + theEvent.scrollingDeltaX >= 0 {
                scrollDeltaX = -1
            } else {
                scrollDeltaX += theEvent.scrollingDeltaX
            }

            if scrollDeltaY != 0 {
                scrollDeltaY += theEvent.scrollingDeltaY
            }
            scrollDeltaX = min(max(scrollDeltaX, -300), 300)
            
            let autofinish = abs(abs(previous) - abs(scrollDeltaX)) > 30
            
            
            self.current?.translate(progress: min(abs(scrollDeltaX / 300), 1), finish: autofinish, completion: completeTransition)
        } else if theEvent.phase == .ended {
            let progress = min(abs(scrollDeltaX / 300), 1)
            self.current?.translate(progress: progress, finish: true, cancel: progress < 0.5, completion: completeTransition)
            if scrollDeltaY > 50 || scrollDeltaY < -50 {
                self.close.send(event: .Click)
            }
            scrollDeltaX = 0
            scrollDeltaY = 0
        } else if theEvent.phase == .cancelled {
            let progress = min(abs(scrollDeltaX / 300), 1)
            let cancel = progress < 0.5
            self.current?.translate(progress: cancel ? 0 : 1, finish: true, cancel: progress < 0.5, completion: completeTransition)
            scrollDeltaX = 0
            scrollDeltaY = 0
        }
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
}

final class StoryModalController : ModalViewController, Notifable {
    private let context: AccountContext
    private let messageId: MessageId
    private let entertainment: EntertainmentViewController
    private let interactions: StoryInteraction
    private let chatInteraction: ChatInteraction
    
    private let disposable = MetaDisposable()
    private let updatesDisposable = MetaDisposable()
    private var overlayTimer: SwiftSignalKit.Timer?
    
    init(context: AccountContext, messageId: MessageId) {
        self.entertainment = EntertainmentViewController(size: NSMakeSize(350, 350), context: context, mode: .stories, presentation: storyTheme)
        self.interactions = StoryInteraction()
        self.context = context
        self.messageId = messageId
        self.chatInteraction = ChatInteraction(chatLocation: .peer(PeerId(0)), context: context)
        super.init()
        self._frameRect = context.window.contentView!.bounds
        self.bar = .init(height: 0)
        self.entertainment.loadViewIfNeeded()
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func measure(size: NSSize) {
        self.modal?.resize(with: size, animated: false)
    }
    
    override func viewClass() -> AnyClass {
        return StoryViewController.self
    }
    
    override var cornerRadius: CGFloat {
        return 0
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? ChatPresentationInterfaceState {
            self.interactions.update({ current in
                var current = current
                if let groupId = current.groupId {
                    current.inputs[groupId] = value.effectiveInput
                }
                return current
            })
        }
        if let value = value as? StoryInteraction.State {
            self.chatInteraction.update({
                $0.withUpdatedEffectiveInputState(value.input)
            })
        }
    }
    
    func isEqual(to other: Notifable) -> Bool {
        return self === other as? StoryModalController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context
        let messageId = self.messageId
        let chatInteraction = self.chatInteraction
        let interactions = self.interactions
        
        self.chatInteraction.add(observer: self)
        interactions.add(observer: self)
        
        let arguments = StoryArguments(context: context, interaction: self.interactions, chatInteraction: chatInteraction, showEmojiPanel: { [weak self] control in
            if let panel = self?.entertainment {
                showPopover(for: control, with: panel, edge: .maxX, inset:NSMakePoint(0 + 38, 10), delayBeforeShown: 0.1)
            }
        }, showReactionsPanel: { [weak interactions, weak self] control in
            if let groupId = interactions?.presentation.groupId {
                _ = storyReactions(context: context, peerId: groupId, react: { [weak self] reaction in
                    self?.genericView.playReaction(reaction)
                    self?.genericView.showTooltip(.reaction(reaction))
                }, onClose: {
                    self?.genericView.closeReactions()
                }).start(next: { view in
                    if let view = view {
                        self?.genericView.showReactions(view, control: control)
                    }
                })

            }
        }, attachPhotoOrVideo: { type in
            chatInteraction.attachPhotoOrVideo(type)
        }, attachFile: {
            chatInteraction.attachFile(false)
        }, nextStory: { [weak self] in
            self?.next()
        }, prevStory: { [weak self] in
            self?.previous()
        }, close: { [weak self] in
            self?.close()
        }, openPeerInfo: { [weak self] peerId in
            context.bindings.rootNavigation().push(PeerInfoController(context: context, peerId: peerId))
            self?.close()
        }, openChat: { [weak self] peerId in
            context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(peerId)))
            self?.close()
        }, sendMessage: { [weak self] in
            self?.interactions.updateInput(with: "")
            self?.genericView.showTooltip(.text)
        }, toggleRecordType: { [weak self] in
            FastSettings.toggleRecordingState()
            self?.interactions.update { current in
                var current = current
                current.recordType = FastSettings.recordingState
                return current
            }
        })
        
        interactions.add(observer: self.genericView)
        
        entertainment.update(with: chatInteraction)
        
        chatInteraction.sendAppFile = { [weak self] file, silent, query, schedule, collectionId in
            self?.genericView.showTooltip(.media([file]))
        }
        chatInteraction.sendPlainText = { [weak self] text in
            _ = self?.interactions.appendText(.makeEmojiHolder(text, fromRect: nil))
            self?.applyFirstResponder()
        }
        chatInteraction.appendAttributedText = { [weak self] attr in
            _ = self?.interactions.appendText(attr)
            self?.applyFirstResponder()
        }
        
        
       
        chatInteraction.showPreviewSender = { urls, asMedia, attributedString in
            var updated:[URL] = []
            for url in urls {
                if url.path.contains("/T/TemporaryItems/") {
                    let newUrl = URL(fileURLWithPath: NSTemporaryDirectory() + url.path.nsstring.lastPathComponent)
                    try? FileManager.default.moveItem(at: url, to: newUrl)
                    if FileManager.default.fileExists(atPath: newUrl.path) {
                        updated.append(newUrl)
                    }
                } else {
                    if FileManager.default.fileExists(atPath: url.path) {
                        updated.append(url)
                    }
                }
            }
            if !updated.isEmpty {
                showModal(with: PreviewSenderController(urls: updated, chatInteraction: chatInteraction, asMedia: asMedia, attributedString: attributedString, presentation: storyTheme), for: context.window)
            }
        }
        
        chatInteraction.sendMedias = { [weak self] medias, caption, isCollage, additionText, silent, atDate, isSpoiler in
            self?.genericView.showTooltip(.media(medias))
        }
        chatInteraction.attachFile = { value in
            filePanel(canChooseDirectories: true, for: context.window, appearance: storyTheme.appearance, completion:{ result in
                if let result = result {
                    
                    let previous = result.count
                    var exceedSize: Int64?
                    let result = result.filter { path -> Bool in
                        if let size = fileSize(path) {
                            let exceed = fileSizeLimitExceed(context: context, fileSize: size)
                            if exceed {
                                exceedSize = size
                            }
                            return exceed
                        }
                        return false
                    }
                    
                    let afterSizeCheck = result.count
                    
                    if afterSizeCheck == 0 && previous != afterSizeCheck {
                        showFileLimit(context: context, fileSize: exceedSize)
                    } else {
                        chatInteraction.showPreviewSender(result.map{URL(fileURLWithPath: $0)}, false, nil)
                    }
                    
                }
            })
        }
        
        chatInteraction.attachPhotoOrVideo = { type in
            var exts:[String] = mediaExts
            if let type = type {
                switch type {
                case .photo:
                    exts = photoExts
                case .video:
                    exts = videoExts
                }
            }
            filePanel(with: exts, canChooseDirectories: true, for: context.window, appearance: storyTheme.appearance, completion:{ result in
                if let result = result {
                    let previous = result.count
                    var exceedSize: Int64?
                    let result = result.filter { path -> Bool in
                        if let size = fileSize(path) {
                            let exceed = fileSizeLimitExceed(context: context, fileSize: size)
                            if exceed {
                                exceedSize = size
                            }
                            return exceed
                        }
                        return false
                    }
                    let afterSizeCheck = result.count
                    if afterSizeCheck == 0 && previous != afterSizeCheck {
                        showFileLimit(context: context, fileSize: exceedSize)
                    } else {
                        chatInteraction.showPreviewSender(result.map{URL(fileURLWithPath: $0)}, true, nil)
                    }
                }
            })
        }

        
        let signal = context.account.viewTracker.aroundIdMessageHistoryViewForLocation(.peer(peerId: messageId.peerId, threadId: nil), count: 50, ignoreRelatedChats: false, messageId: messageId, tagMask: [.photoOrVideo], orderStatistics: [.combinedLocation], additionalData: []) |> take(1) |> deliverOnMainQueue

        disposable.set(signal.start(next: { [weak self] view in
            self?.genericView.update(context: context, messages: view.0.entries.map({
                $0.message
            }).reversed(), initial: messageId)
            
            self?.readyOnce()
        }))
        
        
        self.overlayTimer = SwiftSignalKit.Timer(timeout: 30 / 1000, repeat: true, completion: { [weak self] in
            DispatchQueue.main.async {
                self?.interactions.update { current in
                    var current = current
                    current.hasPopover = hasPopover(context.window)
                    current.hasMenu = contextMenuOnScreen()
                    current.hasModal = findModal(PreviewSenderController.self) != nil || findModal(InputDataModalController.self) != nil
                    return current
                }
            }
        }, queue: .concurrentDefaultQueue())
        
        self.overlayTimer?.start()
        
        updatesDisposable.set(context.window.keyWindowUpdater.start(next: { [weak interactions] windowIsKey in
            interactions?.update({ current in
                var current = current
                current.windowIsKey = windowIsKey
                return current
            })
        }))
        
        genericView.setArguments(arguments)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        window?.set(handler: { [weak self] _ in
            return self?.previous() ?? .invoked
        }, with: self, for: .LeftArrow, priority: .modal)
        
        window?.set(handler: { [weak self] _ in
            return self?.next() ?? .invoked
        }, with: self, for: .RightArrow, priority: .modal)
        
        window?.set(handler: { [weak self] _ in
            guard self?.genericView.isInputFocused == false else {
                return .rejected
            }
            self?.interactions.update { current in
                var current = current
                current.isSpacePaused = !current.isSpacePaused
                return current
            }
            return .invoked
        }, with: self, for: .Space, priority: .modal)
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.inputTextView?.boldWord()
            return .invoked
        }, with: self, for: .B, priority: .modal, modifierFlags: [.command])
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.inputTextView?.underlineWord()
            return .invoked
        }, with: self, for: .U, priority: .modal, modifierFlags: [.shift, .command])
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.inputTextView?.spoilerWord()
            return .invoked
        }, with: self, for: .P, priority: .modal, modifierFlags: [.shift, .command])
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.inputTextView?.strikethroughWord()
            return .invoked
        }, with: self, for: .X, priority: .modal, modifierFlags: [.shift, .command])
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.inputTextView?.removeAllAttributes()
            return .invoked
        }, with: self, for: .Backslash, priority: .modal, modifierFlags: [.command])
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.makeUrl()
            return .invoked
        }, with: self, for: .U, priority: .modal, modifierFlags: [.command])
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.genericView.inputTextView?.italicWord()
            return .invoked
        }, with: self, for: .I, priority: .modal, modifierFlags: [.command])
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeObserver(for: self)
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if self.genericView.inputView == window?.firstResponder {
            self.genericView.resetInputView()
            return .invoked
        } else if interactions.presentation.hasReactions {
            self.genericView.closeReactions()
            return .invoked
        } else {
            return super.escapeKeyAction()
        }
    }
    
    @discardableResult private func previous() -> KeyHandlerResult {
        return genericView.previous()
    }
    @discardableResult private func next() -> KeyHandlerResult {
        return genericView.next()
    }
    
    deinit {
        disposable.dispose()
        updatesDisposable.dispose()
    }
    
    override var containerBackground: NSColor {
        return .clear
    }
    
    private var genericView: StoryViewController {
        return self.view as! StoryViewController
    }
    
    override func firstResponder() -> NSResponder? {
        return self.genericView.inputView
    }
    
    private func applyFirstResponder() {
        _ = self.window?.makeFirstResponder(self.firstResponder())
    }
    
    override func becomeFirstResponder() -> Bool? {
        return false
    }
}
