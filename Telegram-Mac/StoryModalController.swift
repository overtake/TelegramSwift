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


private final class ReadThrottledProcessingManager {
    
    struct Value : Equatable, Hashable {
        var peerId: PeerId
        var id: Int32
        func hash(into hasher: inout Hasher) {
            hasher.combine(peerId)
        }
    }
    
    private let queue = Queue()
    
    private let delay: Double
    
    private var currentIds = Set<Value>()
    
    var process: ((Set<Value>) -> Void)?
    
    private var timer: SwiftSignalKit.Timer?
    
    init(delay: Double = 5) {
        self.delay = delay
    }
    
    func setProcess(process: @escaping (Set<Value>) -> Void) {
        self.queue.async {
            self.process = process
        }
    }
    
    func flush() {
        self.queue.async {
            self.process?(self.currentIds)
            self.currentIds = Set()
        }
    }
    
    func addOrUpdate(_ id: Value) {
        self.queue.async {
            let previous = self.currentIds
            
            let prevValue = self.currentIds.remove(id)
            if let prevValue = prevValue {
                if prevValue.id < id.id {
                    self.currentIds.insert(id)
                } else {
                    self.currentIds.insert(prevValue)
                }
            } else {
                self.currentIds.insert(id)
            }
            
            if previous != self.currentIds {
                if self.timer == nil {
                    var completionImpl: (() -> Void)?
                    let timer = SwiftSignalKit.Timer(timeout: self.delay, repeat: false, completion: {
                        completionImpl?()
                    }, queue: self.queue)
                    completionImpl = { [weak self, weak timer] in
                        if let strongSelf = self {
                            if let timer = timer, strongSelf.timer === timer {
                                strongSelf.timer = nil
                            }
                            strongSelf.process?(strongSelf.currentIds)
                            strongSelf.currentIds = Set()
                        }
                    }
                    self.timer = timer
                    timer.start()
                }
            }
        }
    }
}


private struct Reaction {
    let item: UpdateMessageReaction
    let fromRect: CGRect?
}



private let storedTheme = generateTheme(palette: nightAccentPalette, cloudTheme: nil, bubbled: false, fontSize: 13, wallpaper: .init())

var storyTheme: TelegramPresentationTheme {
    if theme.colors.isDark {
        return theme
    } else {
        return storedTheme
    }
}


final class StoryInteraction : InterfaceObserver {
    struct State : Equatable {
        
        
        var inputs: [PeerId : ChatTextInputState] = [:]
        
        var input: ChatTextInputState {
            if let entryId = entryId {
                if let input = inputs[entryId] {
                    return input
                }
            }
            return ChatTextInputState()
        }
        
        func findInput(_ entryId: PeerId?) -> ChatTextInputState {
            if let entryId = entryId {
                if let input = inputs[entryId] {
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
        var _inTransition: Bool = false
        var lock: Bool = false
        var isRecording: Bool = false
        var hasReactions: Bool = false
        var isSpacePaused: Bool = false
        var playingReaction: Bool = false
        var readingText: Bool = false
        var isMuted: Bool = false
        var storyId: Int32? = nil
        var entryId: PeerId? = nil
        var closed: Bool = false
        
        var canRecordVoice: Bool = true
        var emojiState: EntertainmentState = FastSettings.entertainmentState
        var inputRecording: ChatRecordingState?
        var recordType: RecordingStateSettings = FastSettings.recordingState
        
        var isPaused: Bool {
            return mouseDown || inputInFocus || hasPopover || hasModal || !windowIsKey || inTransition || isRecording || hasMenu || hasReactions || playingReaction || isSpacePaused || readingText || inputRecording != nil || lock || closed
        }
        
        var inTransition: Bool {
            return _inTransition || lock
        }
        
    }
    fileprivate(set) var presentation: State
    init(presentation: State = .init(isMuted: FastSettings.storyIsMuted)) {
        self.presentation = presentation
    }
    
    func startRecording(context: AccountContext, autohold: Bool, sendMedia:@escaping([MediaSenderContainer])->Void) {
        let state: ChatRecordingState
        if self.presentation.recordType == .voice {
            state = ChatRecordingAudioState(context: context, liveUpload: false, autohold: autohold)
        } else {
            let videoState = ChatRecordingVideoState(context: context, liveUpload: false, autohold: autohold)
            state = videoState
            showModal(with: VideoRecorderModalController(state: state, pipeline: videoState.pipeline, sendMedia: { medias in
                sendMedia(medias)
            }, resetState: { [weak self] in
                self?.resetRecording()
            }), for: context.window)
        }
        state.start()
        

        self.update { current in
            var current = current
            current.inputRecording = state
            return current
        }
        
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
        FastSettings.storyIsMuted = self.presentation.isMuted
    }
    func flushPauses() {
        self.update { current in
            var current = current
            current.isSpacePaused = false
            return current
        }
    }
    
    func canBeMuted(_ story: EngineStoryItem) -> Bool {
        return story.media._asMedia() is TelegramMediaFile
    }
    
    func updateInput(with text:String, resetFocus: Bool = false) {
        let state = ChatTextInputState(inputText: text, selectionRange: text.length ..< text.length, attributes: [])
        self.update({ current in
            var current = current
            if let entryId = current.entryId {
                current.inputs[entryId] = state
            }
            if resetFocus {
                current.inputInFocus = false
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
            if let entryId = current.entryId {
                current.inputs[entryId] = state
            }
            return current
        })
        
        return selectedRange.lowerBound ..< selectedRange.lowerBound + text.length
    }
    
    func resetRecording() {
        update { current in
            var current = current
            current.inputRecording = nil
            return current
        }
    }
    
    deinit {
        var bp = 0
        bp += 1
    }

}

final class StoryArguments {
    let context: AccountContext
    let interaction: StoryInteraction
    let chatInteraction: ChatInteraction
    let showEmojiPanel:(Control)->Void
    let showReactionsPanel:()->Void
    let attachPhotoOrVideo:(ChatInteraction.AttachMediaType?)->Void
    let attachFile:()->Void
    let nextStory:()->Void
    let prevStory:()->Void
    let close:()->Void
    let openPeerInfo:(PeerId)->Void
    let openChat:(PeerId, MessageId?, ChatInitialAction?)->Void
    let sendMessage:(PeerId, Int32)->Void
    let toggleRecordType:()->Void
    let deleteStory:(StoryContentItem)->Void
    let markAsRead:(PeerId, Int32)->Void
    let showViewers:(StoryContentItem)->Void
    let share:(StoryContentItem)->Void
    let copyLink:(StoryContentItem)->Void
    let startRecording: (Bool)->Void
    let togglePinned:(StoryContentItem)->Void
    init(context: AccountContext, interaction: StoryInteraction, chatInteraction: ChatInteraction, showEmojiPanel:@escaping(Control)->Void, showReactionsPanel:@escaping()->Void, attachPhotoOrVideo:@escaping(ChatInteraction.AttachMediaType?)->Void, attachFile:@escaping()->Void, nextStory:@escaping()->Void, prevStory:@escaping()->Void, close:@escaping()->Void, openPeerInfo:@escaping(PeerId)->Void, openChat:@escaping(PeerId, MessageId?, ChatInitialAction?)->Void, sendMessage:@escaping(PeerId, Int32)->Void, toggleRecordType:@escaping()->Void, deleteStory:@escaping(StoryContentItem)->Void, markAsRead:@escaping(PeerId, Int32)->Void, showViewers:@escaping(StoryContentItem)->Void, share:@escaping(StoryContentItem)->Void, copyLink: @escaping(StoryContentItem)->Void, startRecording: @escaping(Bool)->Void, togglePinned:@escaping(StoryContentItem)->Void) {
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
        self.deleteStory = deleteStory
        self.markAsRead = markAsRead
        self.showViewers = showViewers
        self.share = share
        self.copyLink = copyLink
        self.startRecording = startRecording
        self.togglePinned = togglePinned
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
    
    deinit {
        var bp = 0
        bp += 1
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
            available = Array(available.prefix(7))
        }
        
        let width = ContextAddReactionsListView.width(for: available.count, maxCount: 7, allowToAll: accessToAll)
        
        
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
            onClose()
            react(.init(item: value.toUpdate(), fromRect: fromRect))
        }, radiusLayer: nil, revealReactions: reveal, presentation: storyTheme, hasBubble: false)
        
        return view
    } |> deliverOnMainQueue
}

private final class StoryViewController: Control, Notifable {
    
    class NavigationButton : Control {
        
        enum Result {
            case nextGroup
            case next
        }
        
        class Preview : Control {
            private let preview: StoryImageView
            private let overlay: View
            private let avatar = AvatarControl(font: .avatar(13))
            required init(frame frameRect: NSRect) {
                self.preview = StoryImageView(frame: frameRect.size.bounds)
                self.overlay = View(frame: frameRect.size.bounds)
                avatar.setFrameSize(NSMakeSize(40, 40))
                super.init(frame: frameRect)
                self.addSubview(preview)
                self.addSubview(overlay)
                self.addSubview(avatar)
                
                preview.userInteractionEnabled = false
                overlay.isEventLess = true
                avatar.userInteractionEnabled = false
                overlay.backgroundColor = NSColor.black.withAlphaComponent(0.6)
                
                self.layer?.cornerRadius = 10
            }
            
            func update(slice: StoryContentContextState.FocusedSlice, context: AccountContext) {
                self.avatar.setPeer(account: context.account, peer: slice.peer._asPeer())
                self.preview.update(context: context, peerId: slice.peer.id, story: slice.item.storyItem, peer: slice.peer._asPeer())
            }
            
            override func layout() {
                super.layout()
                avatar.center()
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
        }
        
        private let button = ImageButton()
        private var preview: Preview?
        private var slice: StoryContentContextState.FocusedSlice?
        private var isNext: Bool = false
        private var context: AccountContext?
        
        var handler:((Result)->Void)? = nil
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(self.button)
            self.scaleOnClick = true
            self.button.userInteractionEnabled = false
            
            set(handler: { [weak self] _ in
                self?.handler?(.next)
            }, for: .Click)
                       
        }
        
        override func mouseMoved(with event: NSEvent) {
            super.mouseMoved(with: event)
            self.updateVisibility()
        }
        override func mouseEntered(with event: NSEvent) {
            super.mouseEntered(with: event)
            self.updateVisibility()
        }
        override func mouseExited(with event: NSEvent) {
            super.mouseExited(with: event)
            self.updateVisibility()
        }
        
        func updateVisibility(animated: Bool = true) {
            if let preview = self.preview  {
                preview._change(opacity: preview._mouseInside() ? 1.0 : 0.0, animated: animated)
            }
            if button.mouseInside() || self.preview?._mouseInside() == true {
                button.change(opacity: 1.0, animated: animated)
            } else {
                button.change(opacity: 0.8, animated: animated)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        
        func update(with slice: StoryContentContextState.FocusedSlice?, context: AccountContext, isNext: Bool, animated: Bool) {
            self.isNext = isNext
            if slice != self.slice {
                
                let peerIsSame = slice?.peer.id == self.slice?.peer.id
                self.slice = slice
                self.context = context

                if let slice = slice {
                    
                    if let preview = self.preview, !peerIsSame {
                        performSubviewRemoval(preview, animated: animated, duration: 0.25, scale: true)
                        self.preview = nil
                    }
                    
                    if self.preview == nil {
                        let preview = Preview(frame: focus(StoryView.size.aspectFitted(NSMakeSize(150, 150))))
                        addSubview(preview)
                        self.preview = preview
                        
                        preview.scaleOnClick = true
                        preview.set(handler: { [weak self] _ in
                            self?.handler?(.nextGroup)
                        }, for: .Click)
                        
                        if animated, preview.mouseInside() {
                            preview.layer?.animateAlpha(from: 0, to: 1, duration: 0.25)
                            preview.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.25, bounce: false)
                        }
                    }
                    self.preview?.center()
                    preview?.layer?.opacity = 0
                    
                    preview?.update(slice: slice, context: context)
                    
                    if animated {
                       // photo.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        //photo.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
                    }
                } else {
                    if let preview = self.preview {
                        performSubviewRemoval(preview, animated: animated, duration: 0.25, scale: true)
                        self.preview = nil
                    }
                }
                if isNext {
                    button.set(image: next_chevron_hover, for: .Normal)
//                    button.set(image: next_chevron_hover, for: .Hover)
//                    button.set(image: next_chevron_hover, for: .Highlight)
                } else {
                    button.set(image: prev_chevron_hover, for: .Normal)
//                    button.set(image: prev_chevron_hover, for: .Hover)
//                    button.set(image: prev_chevron_hover, for: .Highlight)
                }
                
                button.sizeToFit(.zero, NSMakeSize(30, 30), thatFit: true)
                button.sizeToFit(.zero, NSMakeSize(30, 30), thatFit: true)
                
               

                button.controlOpacityEventIgnored = true
                button.controlOpacityEventIgnored = true

            }
            self.updateVisibility(animated: false)
            needsLayout = true
        }
        
        
        override func layout() {
            self.preview?.isHidden = frame.width < 200
            self.preview?.center()

            if let preview = self.preview, preview.isHidden {
                button.center()
            } else {
                let rect = focus(StoryView.size.aspectFitted(NSMakeSize(150, 150)))
                if isNext {
                    button.centerY(x: rect.minX - button.frame.width)
                } else {
                    button.centerY(x: rect.maxX)
                }
            }
        }
    }
    
    class TooptipView : NSVisualEffectView {
        
        enum Source {
            case reaction(Reaction)
            case media([Media])
            case text
            case addedToProfile
            case removedFromProfile
            case linkCopied
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
            let hasButton: Bool
            switch source {
            case let .media(medias):
                if medias.count > 1 {
                    title = "Media Sent."
                } else if let media = medias.first {
                    if let file = media as? TelegramMediaFile {
                        if file.isSticker || file.isAnimatedSticker || file.isVideoSticker {
                           title = "Sticker Sent.";
                        } else if file.isVideo && file.isAnimated {
                            title = "GIF Sent."
                        } else if file.isVideo {
                            title = "Video Sent."
                        } else if file.isMusic || file.isMusicFile {
                            title = "Audio Sent.";
                        } else {
                            title = "Media Sent."
                        }
                    } else if let _ = media as? TelegramMediaImage {
                        title = "Picture Sent."
                    } else {
                        title = "Media Sent."
                    }
                } else {
                    title = "Media Sent."
                }
                mediaFile = MenuAnimation.menu_success.file
                hasButton = true
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
                hasButton = true
            case .text:
                title = "Message Sent."
                mediaFile = MenuAnimation.menu_success.file
                hasButton = true
            case .addedToProfile:
                title = "Saved stories can be viewed by others on your profile until you remove them."
                mediaFile = MenuAnimation.menu_success.file
                hasButton = false
            case .removedFromProfile:
                title = "Story removed from your profile."
                mediaFile = MenuAnimation.menu_success.file
                hasButton = false
            case .linkCopied:
                title = "Copied to clipboard."
                mediaFile = MenuAnimation.menu_success.file
                hasButton = false
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
            
            self.button.isHidden = !hasButton
            
            self.button.set(font: .medium(.text), for: .Normal)
            self.button.set(color: storyTheme.colors.accent, for: .Normal)
            self.button.set(text: "View in Chat", for: .Normal)
            self.button.sizeToFit(NSMakeSize(10, 10), .zero, thatFit: false)
            
            layout.measure(width: size.width - 16 - (button.isHidden ? 0 : 16 + self.button.frame.width) - media.frame.width - 10 - 10)
            textView.update(layout)

            
            self.button.set(handler: { _ in
                callback()
            }, for: .Click)
            
            self.setFrameSize(NSMakeSize(size.width, max(size.height, layout.layoutSize.height + 10)))
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
    
    fileprivate let ready: Promise<Bool> = Promise(false)
    
    var getReady: Signal<Bool, NoError> {
        return self.ready.get()
    }
    
   
    fileprivate var current: StoryListView?
    private var arguments:StoryArguments?
    
    private let next_button: NavigationButton = NavigationButton(frame: .zero)
    private let prev_button: NavigationButton = NavigationButton(frame: .zero)
    private let close: ImageButton = ImageButton()

    private let leftTop = Control()
    private let leftBottom = Control()
    private let rightTop = Control()
    private let rightBottom = Control()
    
    private var storyContext: StoryContentContext?
    
    
    private let container = View()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(container)
        
        
        addSubview(prev_button)
        addSubview(next_button)
        
        addSubview(leftTop)
        addSubview(leftBottom)
        addSubview(rightTop)
        addSubview(rightBottom)

        next_button.controlOpacityEventIgnored = true
        prev_button.controlOpacityEventIgnored = true

        
        close.set(image: close_image, for: .Normal)
        close.set(image: close_image_hover, for: .Hover)
        close.set(image: close_image_hover, for: .Highlight)
        close.sizeToFit(.zero, NSMakeSize(50, 50), thatFit: true)
        close.autohighlight = false
        close.scaleOnClick = true
        
        close.set(handler: { [weak self] _ in
            self?.arguments?.close()
        }, for: .Click)
        
        leftTop.set(handler: { [weak self] _ in
            self?.close.send(event: .Click)
        }, for: .Click)
        
        leftBottom.set(handler: { [weak self] _ in
            self?.close.send(event: .Click)
        }, for: .Click)
        
        rightTop.set(handler: { [weak self] _ in
            self?.close.send(event: .Click)
        }, for: .Click)
        
        rightBottom.set(handler: { [weak self] _ in
            self?.close.send(event: .Click)
        }, for: .Click)
        
        
        addSubview(close)
       
                
        self.updateLayout(size: self.frame.size, transition: .immediate)
        
        prev_button.handler = { [weak self] result in
            switch result {
            case .nextGroup:
                self?.processGroupResult(.moveBack, animated: true)
            case .next:
                _ = self?.previous()
            }
        }
        
        next_button.handler = { [weak self] result in
            switch result {
            case .nextGroup:
                self?.processGroupResult(.moveNext, animated: true)
            case .next:
                _ = self?.next()
            }
        }
        
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
        if let event = NSApp.currentEvent {
            if !self.inTransition {
                self.updatePrevNextControls(event, animated: animated)
            }
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
    var isTextEmpty: Bool {
        return self.arguments?.interaction.presentation.input.inputText.isEmpty == true
    }
    
    var hasNextGroup: Bool {
        return self.storyContext?.stateValue?.nextSlice != nil
    }
    var hasPrevGroup: Bool {
        return self.storyContext?.stateValue?.previousSlice != nil
    }
    
    private func updatePrevNextControls(_ event: NSEvent, animated: Bool = true) {
        guard let current = self.current, let arguments = self.arguments else {
            return
        }
        
        let presentation = arguments.interaction.presentation
        let hasOverlay = presentation.hasModal || presentation.hasMenu || presentation.hasPopover || presentation.inTransition
        
        let nextEntry = hasOverlay ? nil : self.storyContext?.stateValue?.nextSlice
        let prevEntry = hasOverlay ? nil : self.storyContext?.stateValue?.previousSlice
        
        self.prev_button.update(with: prevEntry, context: arguments.context, isNext: false, animated: animated)
        self.next_button.update(with: nextEntry, context: arguments.context, isNext: true, animated: animated)

        let point = self.convert(event.locationInWindow, from: nil)
        
        if point.x < current.contentRect.minX, point.y > leftTop.frame.maxY, point.y < leftBottom.frame.minY {
            self.prev_button.change(opacity: hasPrevGroup ? 1 : 0, animated: animated)
            self.next_button.change(opacity: 0, animated: animated)
        } else {
            self.prev_button.change(opacity: 0, animated: animated)
        }
        
        if point.x > current.contentRect.maxX, point.y > rightTop.frame.maxY, point.y < rightBottom.frame.minY {
            self.next_button.change(opacity: hasNextGroup ? 1 : 0, animated: animated)
            self.prev_button.change(opacity: 0, animated: animated)
        } else {
            self.next_button.change(opacity: 0, animated: animated)
        }
        
        let close_rects = [leftTop.frame, leftBottom.frame, rightTop.frame, rightBottom.frame]
        
        if close_rects.contains(where: { NSPointInRect(point, $0) }) {
            close.set(image: close_image_hover, for: .Normal)
        } else {
            close.set(image: close_image, for: .Normal)
        }
        
        self.prev_button.isHidden = self.reactions != nil
        self.next_button.isHidden = self.reactions != nil
    }
    
    
    
    
    func update(context: AccountContext, storyContext: StoryContentContext, initial: StoryInitialIndex?) {
                
        
        guard let state = storyContext.stateValue else {
            return
        }
        
        
        self.storyContext = storyContext
       
        if let current = self.current {
            let slice: StoryContentContextState.FocusedSlice?
            if state.slice?.peer.id == current.id {
                slice = state.slice
            } else if state.nextSlice?.peer.id == current.id {
                slice = state.nextSlice
            } else if state.previousSlice?.peer.id == current.id {
                slice = state.previousSlice
            } else {
                slice = nil
            }
            if let entry = slice {
                current.update(context: context, entry: entry)
            }
        }
        
        if self.current == nil, let entry = state.slice {
            let storyView = StoryListView(frame: bounds)
            storyView.setArguments(self.arguments)
            let entryId = entry.peer.id
            storyView.update(context: context, entry: entry)
            self.current = storyView


            container.addSubview(storyView)
            
            self.ready.set(storyView.getReady)

            _ = (self.getReady |> filter { $0 } |> take(1)).start(next: { [weak storyView] _ in
                if let control = initial?.takeControl?(entryId, initial?.messageId, entry.item.storyItem.id) {
                    storyView?.animateAppearing(from: control)
                }
            })
            
        } else if state.slice == nil {
            self.close.send(event: .Click)
        }
        
        if let event = NSApp.currentEvent {
            self.updatePrevNextControls(event)
        }
        
        arguments?.interaction.update(animated: false, { current in
            var current = current
            current.entryId = state.slice?.peer.id
            current.storyId = state.slice?.item.storyItem.id
            return current
        })
    }
    
    func delete() -> KeyHandlerResult {
        if let story = self.current?.story, arguments?.interaction.presentation.inputInFocus == false {
            if self.arguments?.interaction.presentation.entryId == self.arguments?.context.peerId {
                self.arguments?.deleteStory(story)
                return .invoked
            }
        }
        return .rejected
    }
    
    func previous() -> KeyHandlerResult {
        if self.reactions != nil {
            self.closeReactions()
            return .invoked
        }
        if isInputFocused {
            return .invokeNext
        }
        guard !inTransition, let result = self.current?.previous() else {
            return .invokeNext
        }
        
        if result == .invoked {
            self.storyContext?.navigate(navigation: .item(.previous))
        } else if result == .moveBack {
            if self.storyContext?.stateValue?.previousSlice == nil {
                self.current?.restart()
            } else {
                self.processGroupResult(result, animated: true)
            }
        }

        return .invoked
    }
    func next() -> KeyHandlerResult {
        if self.reactions != nil {
            self.closeReactions()
            return .invoked
        }
        if isInputFocused {
            return .invokeNext
        }
        guard !inTransition, let result = self.current?.next() else {
            return .invokeNext
        }
        if result == .invoked {
            self.storyContext?.navigate(navigation: .item(.next))
        } else if result == .moveNext {
            if storyContext?.stateValue?.nextSlice == nil, result == .moveNext {
                self.close.send(event: .Click)
            } else {
                self.processGroupResult(result, animated: true)
            }
        }
       
        return .invoked
    }
    
    private var inTransition: Bool {
        get {
            return self.arguments?.interaction.presentation.inTransition ?? false
        }
        set {
            self.arguments?.interaction.update { current in
                var current = current
                current._inTransition = newValue
                return current
            }
        }
    }
    
    fileprivate func processGroupResult(_ result: StoryListView.UpdateIndexResult, animated: Bool, bySwipe: Bool = false) {
                
        
        guard let context = self.arguments?.context, !inTransition else {
            return
        }
        
        if self.reactions != nil {
            self.closeReactions()
            return
        } else  if self.isInputFocused {
            self.resetInputView()
            return
        }
        
        let nextGroup: StoryContentContextState.FocusedSlice?
        switch result {
        case .invoked:
            nextGroup = nil
        case .moveNext:
            nextGroup = self.storyContext?.stateValue?.nextSlice
        case .moveBack:
            nextGroup = self.storyContext?.stateValue?.previousSlice
        }
        let isNext = result == .moveNext

        if nextGroup != nil || bySwipe {
            inTransition = true
            self.arguments?.interaction.flushPauses()

            let entryId = nextGroup?.peer.id



            let storyView = StoryListView(frame: bounds)
            storyView.setArguments(self.arguments)

            storyView.update(context: context, entry: nextGroup)

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
                        self?.storyContext?.navigate(navigation: .peer(result == .moveNext ? .next : .previous))
                        self?.inTransition = false
                    })
                }
            }
        }
        
        
        
        if let event = NSApp.currentEvent {
            self.updatePrevNextControls(event)
        }
    }

    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: container, frame: size.bounds)
        if let current = self.current {
            transition.updateFrame(view: current, frame: size.bounds)
            current.updateLayout(size: size, transition: transition)

            let halfSize = (size.width - current.contentRect.width) / 2
            
            transition.updateFrame(view: prev_button, frame: NSMakeRect(0, 0, halfSize, size.height))
            transition.updateFrame(view: next_button, frame: NSMakeRect(halfSize + current.contentRect.width, 0, halfSize, size.height))
            
            transition.updateFrame(view: leftTop, frame: NSMakeRect(0, 0, halfSize, 50))
            transition.updateFrame(view: leftBottom, frame: NSMakeRect(0, frame.height - 50, halfSize, 50))
            
            transition.updateFrame(view: rightTop, frame: NSMakeRect(size.width - halfSize, 0, halfSize, 50))
            transition.updateFrame(view: rightBottom, frame: NSMakeRect(size.width - halfSize, size.height - 50, halfSize, 50))

            if let view = self.reactions {
                let point = NSMakePoint((size.width - view.frame.width) / 2, current.storyRect.maxY - view.frame.height + 15)
                transition.updateFrame(view: view, frame: CGRect(origin: point, size: view.frame.size))
            }
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
    
    private var reactions: NSView? = nil
    private var makeParabollic: Bool = true
    
    func closeReactions(reactByFirst: Bool = false) {
        
        if reactByFirst {
            if let view = self.reactions as? ContextAddReactionsListView {
                self.makeParabollic = false
                view.invokeFirst()
                return
            }
        }
        
        let hasReactions: Bool = self.reactions != nil
        if let view = self.reactions {
            performSubviewRemoval(view, animated: true)
            self.reactions = nil
        }
        var resetInput = false
        if self.arguments?.interaction.presentation.input.inputText.isEmpty == true, hasReactions {
            self.resetInputView()
            resetInput = true
        }
        
        self.arguments?.interaction.update { current in
            var current = current
            current.hasReactions = false
            if resetInput {
                current.inputInFocus = false
            }
            return current
        }
    }
    
    fileprivate func closeTooltip() {
        if let view = currentTooltip {
            performSubviewRemoval(view, animated: true, scale: true)
            self.currentTooltip = nil
            self.tooltipDisposable.set(nil)
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
       
        guard let current = self.current else {
            return
        }
        
        let overlay = View(frame: NSMakeRect(0, 0, 300, 300))
        overlay.isEventLess = true 
        current.contentView.addSubview(overlay)
        overlay.center()
        overlay.setFrameOrigin(NSMakePoint(overlay.frame.minX, overlay.frame.minY - 50))
        
        let finish:()->Void = { [weak overlay] in
            if let overlay = overlay {
                performSubviewRemoval(overlay, animated: true, scale: true)
            }
        }
        
        let parabollic: Bool = self.makeParabollic
        
        let play:(NSView, TelegramMediaFile)->Void = { container, icon in
            
            let layer = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: icon.fileId.id, file: icon, emoji: ""), size: NSMakeSize(100, 100), playPolicy: .once)
            layer.isPlayable = true
            
            layer.frame = NSMakeRect((container.frame.width - layer.frame.width) / 2, (container.frame.height - layer.frame.height) / 2, layer.frame.width, layer.frame.height)
            container.layer?.addSublayer(layer)

            
            if let effectFileId = effectFileId {
                let player = CustomReactionEffectView(frame: NSMakeSize(600, 600).bounds, context: context, fileId: effectFileId)
                player.isEventLess = true
                player.triggerOnFinish = { [weak player] in
                    player?.removeFromSuperview()
                    finish()
                }
                let rect = CGRect(origin: CGPoint(x: (container.frame.width - player.frame.width) / 2, y: (container.frame.height - player.frame.height) / 2), size: player.frame.size)
                player.frame = rect
                container.addSubview(player)
                
            } else if let effectFile = effectFile {
                let player = InlineStickerItemLayer(account: context.account, file: effectFile, size: NSMakeSize(300, 300), playPolicy: .playCount(1))
                player.isPlayable = true
                player.frame = NSMakeRect(0, 0, player.frame.width, player.frame.height)
                
                container.layer?.addSublayer(player)
                player.triggerOnState = (.finished, { [weak player] state in
                    player?.removeFromSuperlayer()
                    finish()
                })
            }
            if !parabollic {
                layer.animateScale(from: 0.1, to: 1, duration: 0.25)
            }
        }
        
        let layer = InlineStickerItemLayer(account: context.account, file: icon, size: NSMakeSize(50, 50))

        let completed: (Bool)->Void = { [weak overlay] _ in
            DispatchQueue.main.async {
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                DispatchQueue.main.async {
                    if let container = overlay {
                        play(container, icon)
                    }
                }
            }
        }
        if let fromRect = reaction.fromRect, makeParabollic {
            
            let toRect = overlay.convert(overlay.frame.size.bounds, to: nil)
            
            let from = fromRect.origin.offsetBy(dx: fromRect.width / 2, dy: fromRect.height / 2)
            let to = toRect.origin.offsetBy(dx: toRect.width / 2, dy: toRect.height / 2)
            parabollicReactionAnimation(layer, fromPoint: from, toPoint: to, window: context.window, completion: completed)
        } else {
            completed(true)
        }
        makeParabollic = true
    }
    
    func showReactions() {
        if self.arguments?.interaction.presentation.input.inputText.isEmpty == true {
            self.arguments?.showReactionsPanel()
        }
    }
    
    func showVoiceError() {
        self.current?.showVoiceError()
    }
    func showShareError() {
        self.current?.showShareError()
    }
    
    func showReactions(_ view: NSView) {
        
        guard let current = current, self.arguments?.interaction.presentation.hasReactions == false, self.reactions == nil else {
            return
        }
        
        view.setFrameOrigin(NSMakePoint((frame.width - view.frame.width) / 2, current.storyRect.maxY - view.frame.height + 15))
        addSubview(view)
        
        view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        view.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
        
        self.reactions = view
        
        self.arguments?.interaction.update { current in
            var current = current
            current.hasReactions = true
            return current
        }
    }
    
    func animateDisappear(_ initialId: StoryInitialIndex?) {
        if let current = self.current, let id = current.id, let control = initialId?.takeControl?(id, initialId?.messageId, current.storyId?.base as? Int32) {
            current.animateDisappearing(to: control)
        }
    }
    
    deinit {
        tooltipDisposable.dispose()
    }
    
    private var currentTooltip: TooptipView?
    private let tooltipDisposable = MetaDisposable()
    func showTooltip(_ source: TooptipView.Source) {
        
        self.resetInputView()
        
        self.closeTooltip()
        
        guard let arguments = self.arguments, let current = self.current, let entryId = arguments.interaction.presentation.entryId else {
            return
        }
        
        let tooltip = TooptipView(frame: .zero)
        
        tooltip.update(source: source, size: NSMakeSize(current.contentRect.width - 20, 40), context: arguments.context, callback: { [weak arguments] in
            arguments?.openChat(entryId, nil, nil)
        })
        
        self.addSubview(tooltip)
        tooltip.centerX(y: current.storyRect.maxY - tooltip.frame.height - 10)
        
        tooltip.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        tooltip.layer?.animatePosition(from: tooltip.frame.origin.offsetBy(dx: 0, dy: 20), to: tooltip.frame.origin)
        let signal = Signal<Void, NoError>.single(Void()) |> delay(4.5, queue: .mainQueue())
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

    
    private func returnGroupIndex(previous: StoryListView) {
        let cur = self.current
        self.current?.removeFromSuperview()

        self.current = previous
        
        container.addSubview(previous, positioned: .above, relativeTo: cur)

        self.arguments?.interaction.update { current in
            var current = current
            current._inTransition = false
            return current
        }
    }
    
    override func scrollWheel(with theEvent: NSEvent) {
        
        
        let result: StoryListView.UpdateIndexResult = self.scrollDeltaX > 0 ? .moveBack : .moveNext
        let value = min(abs(scrollDeltaX / 300), 1)

        let completeTransition:(Bool, StoryListView)->Void = { [weak self] completed, previous in
            if !completed {
                self?.returnGroupIndex(previous: previous)
                switch result {
                case .moveBack:
                    if self?.hasPrevGroup == false, value > 0.5 {
                        self?.close.send(event: .Click)
                    }
                case .moveNext:
                    if self?.hasNextGroup == false, value > 0.5 {
                        self?.close.send(event: .Click)
                    }
                default:
                    break
                }
            } else {
                self?.inTransition = false
                switch result {
                case .moveBack:
                    self?.storyContext?.navigate(navigation: .peer(.previous))
                case .moveNext:
                    self?.storyContext?.navigate(navigation: .peer(.next))
                default:
                    break
                }
                
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
                self.processGroupResult(.moveBack, animated: true, bySwipe: true)
            } else if scrollDeltaX < 0 {
                self.processGroupResult(.moveNext, animated: true, bySwipe: true)
            }
        } else if theEvent.phase == .changed {
            let previous = self.scrollDeltaX
            if scrollDeltaX > 0, scrollDeltaX + theEvent.scrollingDeltaX <= 0 {
                scrollDeltaX = 1
            } else if scrollDeltaX < 0, scrollDeltaX + theEvent.scrollingDeltaX >= 0 {
                scrollDeltaX = -1
            } else if scrollDeltaX != 0 {
                scrollDeltaX += theEvent.scrollingDeltaX
            }

            if scrollDeltaX == 0 {
                if scrollDeltaY > 0, scrollDeltaY + theEvent.scrollingDeltaY <= 0 {
                    scrollDeltaY = 1
                } else if scrollDeltaY < 0, scrollDeltaY + theEvent.scrollingDeltaY >= 0 {
                    scrollDeltaY = -1
                } else if scrollDeltaY != 0 {
                    scrollDeltaY += theEvent.scrollingDeltaY
                }
            }
           
            scrollDeltaX = min(max(scrollDeltaX, -300), 300)
            
            var autofinish = abs(abs(previous) - abs(scrollDeltaX)) > 60
            
            let delta: CGFloat
            let maxDelta: CGFloat = log(25.0)
            if scrollDeltaX > 0 {
                if !hasPrevGroup {
                    delta = log(scrollDeltaX) / maxDelta * 25
                    autofinish = false
                } else {
                    delta = scrollDeltaX
                }
            } else {
                if !hasNextGroup {
                    delta = -(log(abs(scrollDeltaX)) / maxDelta * 25)
                    autofinish = false
                } else {
                    delta = scrollDeltaX
                }
            }
            
            self.current?.translate(progress: min(abs(delta / 300), 1), finish: autofinish, completion: completeTransition)
            
           
            if scrollDeltaY != 0, let current = self.current {
                let dest: CGFloat = log(25)
                var delta: CGFloat = log(abs(scrollDeltaY)) / dest * 25
                if scrollDeltaY < 0 {
                    delta = -delta
                }
                current.setFrameOrigin(NSMakePoint(current.frame.minX, delta))
                if let overlay = self.reactions {
                    overlay.setFrameOrigin(NSMakePoint(overlay.frame.minX, current.storyRect.maxY - overlay.frame.height + 15 + delta))
                }
            }
        } else if theEvent.phase == .ended || theEvent.phase == .cancelled {
            if let current = current {
                current.change(pos: NSMakePoint(current.frame.minX, 0), animated: true)
                if let overlay = self.reactions {
                    overlay._change(pos: NSMakePoint(overlay.frame.minX, current.storyRect.maxY - overlay.frame.height + 15), animated: true)
                }
                if scrollDeltaY > 50 {
                    if inputView == self.window?.firstResponder {
                        if self.reactions != nil {
                            self.closeReactions()
                        } else {
                            self.resetInputView()
                        }
                    } else {
                        self.close.send(event: .Click)
                    }
                } else if scrollDeltaY < -50 {
                    if let peerId = current.id, peerId == arguments?.context.peerId, let story = current.story {
                        if let views = story.storyItem.views, views.seenCount > 0 {
                            arguments?.showViewers(story)
                        }
                    } else {
                        if self.reactions != nil {
                            self.closeReactions(reactByFirst: true)
                        } else {
                            if self.isInputFocused {
                                self.resetInputView()
                            } else {
                                self.window?.makeFirstResponder(self.inputView)
                                self.showReactions()
                            }
                        }
                    }
                }
            }
            
            var progress = value
            var cancelAnyway = false
            switch result {
            case .moveBack:
                if !self.hasPrevGroup, value > 0.5 {
//                    progress = 1.0
                    cancelAnyway = true
                }
            case .moveNext:
                if !self.hasNextGroup, value > 0.5 {
//                    progress = 1.0
                    cancelAnyway = true
                }
            default:
                break
            }
            
            self.current?.translate(progress: progress, finish: true, cancel: value < 0.5 || cancelAnyway, completion: completeTransition)
            resetDelta()
            
        }
    }
    

    private func resetDelta() {
        scrollDeltaX = 0
        scrollDeltaY = 0
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
}

final class StoryModalController : ModalViewController, Notifable {
    private let context: AccountContext
    private var initialId: StoryInitialIndex?
    private let stories: StoryContentContext
    private let entertainment: EntertainmentViewController
    private let interactions: StoryInteraction
    private let chatInteraction: ChatInteraction
    
    private let disposable = MetaDisposable()
    private let updatesDisposable = MetaDisposable()
    private let permissionDisposable = MetaDisposable()
    private var overlayTimer: SwiftSignalKit.Timer?
    
    private var arguments: StoryArguments?

    init(context: AccountContext, stories: StoryContentContext, initialId: StoryInitialIndex?) {
        self.entertainment = EntertainmentViewController(size: NSMakeSize(350, 350), context: context, mode: .stories, presentation: storyTheme)
        self.interactions = StoryInteraction()
        self.context = context
        self.initialId = initialId
        self.stories = stories
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
                if let entryId = current.entryId {
                    current.inputs[entryId] = value.effectiveInput
                }
                current.emojiState = value.isEmojiSection ? .emoji : .stickers
                return current
            })
        }
        if let value = value as? StoryInteraction.State, let oldValue = oldValue as? StoryInteraction.State {
            self.chatInteraction.update({
                $0.withUpdatedEffectiveInputState(value.input)
            })
            
            if value.input != oldValue.input || value.inputInFocus != oldValue.inputInFocus {
                if value.input.inputText.isEmpty, value.inputInFocus {
                    genericView.showReactions()
                } else {
                    self.genericView.closeReactions()
                }
            }
            if value.hasReactions != oldValue.hasReactions, !value.hasReactions {
                self.genericView.closeReactions()
            }
            if value.closed {
                self.genericView.closeReactions()
                self.genericView.closeTooltip()
            }
        }
    }
    

    
    func isEqual(to other: Notifable) -> Bool {
        return self === other as? StoryModalController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context
        let initialId = self.initialId
        let chatInteraction = self.chatInteraction
        let interactions = self.interactions
        
        let stories = self.stories
        
        
        
        let openPeerInfo:(PeerId)->Void = { [weak self] peerId in
            let controller = context.bindings.rootNavigation().controller as? PeerInfoController
            if peerId != context.peerId {
                if controller?.peerId != peerId {
                    context.bindings.rootNavigation().push(PeerInfoController(context: context, peerId: peerId))
                }
                self?.close()
            } else {
                context.bindings.rootNavigation().push(StoryMediaController(context: context, peerId: context.peerId, listContext: PeerStoryListContext(account: context.account, peerId: context.peerId, isArchived: false), standalone: true))
                self?.close()
            }
        }
        let openChat:(PeerId, MessageId?, ChatInitialAction?)->Void = { [weak self] peerId, messageId, initial in
            let controller = context.bindings.rootNavigation().controller as? ChatController
            if controller?.chatLocation.peerId != peerId {
                context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(peerId), messageId: messageId, initialAction: initial))
            }
            self?.close()
        }
        
        let beforeCompletion:()->Void = { [weak interactions] in
            interactions?.update({ current in
                var current = current
                current.lock = true
                return current
            })
        }
        
        let afterCompletion:()->Void = { [weak interactions] in
            interactions?.update({ current in
                var current = current
                current.lock = false
                return current
            })
        }
        
        
        
        let sendText: (ChatTextInputState, PeerId, Int32, StoryViewController.TooptipView.Source)->Void = { [weak self] input, peerId, id, source in
            beforeCompletion()
            _ = Sender.enqueue(input: input, context: context, peerId: peerId, replyId: nil, replyStoryId: .init(peerId: peerId, id: id), sendAsPeerId: nil).start(completed: {
                afterCompletion()
                self?.interactions.updateInput(with: "", resetFocus: true)
                self?.genericView.showTooltip(source)
            })
        }
        
        self.chatInteraction.add(observer: self)
        interactions.add(observer: self)
        
        let arguments = StoryArguments(context: context, interaction: self.interactions, chatInteraction: chatInteraction, showEmojiPanel: { [weak self] control in
            if let panel = self?.entertainment {
                showPopover(for: control, with: panel, edge: .maxX, inset:NSMakePoint(0 + 38, 10), delayBeforeShown: 0.1)
            }
        }, showReactionsPanel: { [weak interactions, weak self] in
            if let entryId = interactions?.presentation.entryId, let id = interactions?.presentation.storyId {
                _ = storyReactions(context: context, peerId: entryId, react: { [weak self] reaction in
                    
                    switch reaction.item {
                    case let .builtin(value):
                        sendText(.init(inputText: value.normalizedEmoji), entryId, id, .reaction(reaction))
                    case let .custom(fileId, file):
                        if let file = file, let text = file.customEmojiText {
                            sendText(.init(inputText: text, selectionRange: 0..<0, attributes: [.animated(0..<text.length, text, fileId, file, nil, nil)]), entryId, id, .reaction(reaction))
                        }
                    }
                    self?.genericView.playReaction(reaction)

                }, onClose: {
                    self?.genericView.closeReactions()
                }).start(next: { view in
                    if let view = view {
                        self?.genericView.showReactions(view)
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
        }, openPeerInfo: { peerId in
            openPeerInfo(peerId)
        }, openChat: { peerId, messageId, initial in
            openChat(peerId, messageId, initial)
        }, sendMessage: { [weak self] peerId, id in
            let input = self?.interactions.presentation.input
            if let input = input {
                sendText(input, peerId, id, .text)
            }
        }, toggleRecordType: { [weak self] in
            FastSettings.toggleRecordingState()
            self?.interactions.update { current in
                var current = current
                current.recordType = FastSettings.recordingState
                return current
            }
        }, deleteStory: { [weak self] story in
            confirm(for: context.window, information: "Are you sure you want to delete story?", successHandler: { _ in
                if let stateValue = self?.stories.stateValue, let slice = stateValue.slice {
                    if slice.nextItemId != nil {
                        self?.stories.navigate(navigation: .item(.next))
                    } else if slice.previousItemId != nil {
                        self?.stories.navigate(navigation: .item(.previous))
                    } else {
                        self?.close()
                    }
                    _ = context.engine.messages.deleteStories(ids: [slice.item.storyItem.id]).start()
                }

                
            }, appearance: storyTheme.appearance)
        }, markAsRead: { [weak self] peerId, storyId in
            self?.stories.markAsSeen(id: .init(peerId: peerId, id: storyId))
        }, showViewers: { story in
            if let peerId = story.peer?.id {
                showModal(with: StoryViewersModalController(context: context, peerId: peerId, story: story.storyItem, presentation: storyTheme, callback: openPeerInfo), for: context.window)
            }
        }, share: { [weak self] story in
            if let peerId = story.peerId, story.sharable {
                let signal = showModalProgress(signal: context.engine.messages.exportStoryLink(peerId: peerId, id: story.storyItem.id), for: context.window)
                
                _ = signal.start(next: { [weak self] link in
                    if let link = link {
                        showModal(with: ShareModalController(ShareLinkObject(context, link: link), presentation: storyTheme), for: context.window)
                    } else {
                        self?.genericView.showShareError()
                    }
                })
            } else {
                self?.genericView.showShareError()
            }
        }, copyLink: { [weak self] story in
            if let peerId = story.peerId, story.sharable {
                let signal = showModalProgress(signal: context.engine.messages.exportStoryLink(peerId: peerId, id: story.storyItem.id), for: context.window)
                
                _ = signal.start(next: { link in
                    if let link = link {
                        copyToClipboard(link)
                        self?.genericView.showTooltip(.linkCopied)
                    }
                })
            }
        }, startRecording: { [weak self] autohold in
            guard let `self` = self else {
                return
            }
            if !self.interactions.presentation.canRecordVoice {
                self.genericView.showVoiceError()
            } else {
                self.interactions.startRecording(context: context, autohold: autohold, sendMedia: self.chatInteraction.sendMedia)
            }
        }, togglePinned: { [weak self] story in
            _ = context.engine.messages.updateStoriesArePinned(ids: [story.storyItem.id : story.storyItem], isPinned: !story.storyItem.isPinned).start()
            self?.genericView.showTooltip(story.storyItem.isPinned ? .removedFromProfile : .addedToProfile)
        })
        
        self.arguments = arguments
        
        genericView.setArguments(arguments)
        interactions.add(observer: self.genericView)
        
        entertainment.update(with: chatInteraction)
        
        chatInteraction.sendAppFile = { [weak self] file, _, _, _, _ in
            guard let interactions = self?.interactions else {
                return
            }
            if let peerId = interactions.presentation.entryId, let id = interactions.presentation.storyId {
                beforeCompletion()
                _ = Sender.enqueue(media: file, context: context, peerId: peerId, replyId: nil, replyStoryId: .init(peerId: peerId, id: id)).start(completed: {
                    afterCompletion()
                    self?.genericView.showTooltip(.media([file]))
                })
            }
            
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
            guard let interactions = self?.interactions else {
                return
            }
            if let peerId = interactions.presentation.entryId, let id = interactions.presentation.storyId {
                beforeCompletion()
                _ = Sender.enqueue(media: medias, caption: caption, context: context, peerId: peerId, replyId: nil, replyStoryId: .init(peerId: peerId, id: id), isCollage: isCollage, additionText: additionText, silent: silent, atDate: atDate, isSpoiler: isSpoiler).start(completed: {
                    afterCompletion()
                    self?.genericView.showTooltip(.media(medias))
                })
            }
        }
        
        chatInteraction.sendMedia = { [weak self] container in
            if let peerId = interactions.presentation.entryId, let id = interactions.presentation.storyId {
                beforeCompletion()
                _ = Sender.enqueue(media: container, context: context, peerId: peerId, replyId: nil, replyStoryId: .init(peerId: peerId, id: id)).start(completed: {
                    afterCompletion()
                    self?.genericView.showTooltip(.media([]))
                })
            }
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
                        chatInteraction.showPreviewSender(result.map(URL.init(fileURLWithPath:)), true, nil)
                    }
                }
            })
        }

        
        let signal = stories.state |> deliverOnMainQueue

        
        var currentPeerId: PeerId? = nil
        
        disposable.set(combineLatest(signal, genericView.getReady).start(next: { [weak self] state, ready in
            if state.slice == nil {
                self?.initialId = nil
                self?.close()
            } else if let stories = self?.stories {
                self?.genericView.update(context: context, storyContext: stories, initial: initialId)
                if let slice = state.slice, currentPeerId != slice.peer.id {
                    let signal = context.account.viewTracker.peerView(slice.peer.id) |> deliverOnMainQueue
                    self?.permissionDisposable.set(signal.start(next: { view in
                        let cachedData = view.cachedData as? CachedUserData
                        self?.interactions.update { current in
                            var current = current
                            current.canRecordVoice = cachedData?.voiceMessagesAvailable ?? false
                            return current
                        }
                    }))
                    currentPeerId = slice.peer.id
                }
                if ready {
                    self?.readyOnce()
                }
            }
        }))
        
        
        self.overlayTimer = SwiftSignalKit.Timer(timeout: 30 / 1000, repeat: true, completion: { [weak self] in
            DispatchQueue.main.async {
                self?.interactions.update { current in
                    var current = current
                    current.hasPopover = hasPopover(context.window)
                    current.hasMenu = contextMenuOnScreen()
                    current.hasModal = findModal(PreviewSenderController.self) != nil || findModal(InputDataModalController.self) != nil || findModal(ShareModalController.self) != nil
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
        
    }
    
    private func openCurrentMedia() {
        if let peerId = self.interactions.presentation.entryId {
           // self.context.bindings.rootNavigation().push(StoryMediaController(context: context, peerId: peerId))
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let context = self.context
        
        window?.set(handler: { [weak self] _ in
            return self?.previous() ?? .invoked
        }, with: self, for: .LeftArrow, priority: .modal)
        
        window?.set(handler: { [weak self] _ in
            if let story = self?.genericView.current?.story, story.peerId == context.peerId {
                if story.storyItem.views?.seenCount != 0, findModal(InputDataModalController.self) == nil {
                    self?.arguments?.showViewers(story)
                    return .invoked
                }
            } else {
                if self?.genericView.isInputFocused == false {
                    self?.genericView.processGroupResult(.moveNext, animated: true)
                } else if self?.interactions.presentation.input.inputText.isEmpty == true {
                    self?.genericView.processGroupResult(.moveNext, animated: true)
                }
            }
            return .invokeNext
        }, with: self, for: .UpArrow, priority: .modal)
        
        window?.set(handler: { [weak self] _ in
            if self?.genericView.isInputFocused == true || self?.interactions.presentation.input.inputText.isEmpty == true {
                self?.genericView.processGroupResult(.moveBack, animated: true)
            }
            return .invokeNext
        }, with: self, for: .DownArrow, priority: .modal)
        
        
        window?.set(handler: { [weak self] _ in
            return self?.next() ?? .invoked
        }, with: self, for: .RightArrow, priority: .modal)
        
        window?.set(handler: { [weak self] _ in
            return self?.delete() ?? .invoked
        }, with: self, for: .Delete, priority: .modal)
        
        window?.set(handler: { [weak self] _ in
            guard self?.genericView.isInputFocused == false else {
                return .rejected
            }
            self?.interactions.update { current in
                var current = current
                if current.isPaused {
                    current.isSpacePaused = false
                } else {
                    current.isSpacePaused = !current.isSpacePaused
                }
                return current
            }
            return .invoked
        }, with: self, for: .Space, priority: .modal)
        
        
        window?.set(handler: { [weak self] _ in
            guard let `self` = self, self.genericView.isTextEmpty else {
                return .rejected
            }
            if !self.interactions.presentation.canRecordVoice {
                self.genericView.showVoiceError()
            } else {
                self.interactions.startRecording(context: context, autohold: true, sendMedia: self.chatInteraction.sendMedia)
            }
            return .invoked
        }, with: self, for: .R, priority: .modal, modifierFlags: [.command])
        
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
        
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.close()
            self?.openCurrentMedia()
            return .invoked
        }, with: self, for: .E, priority: .modal, modifierFlags: [.command])
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeObserver(for: self)
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if let _ = interactions.presentation.inputRecording {
           interactions.update { current in
               var current = current
               current.inputRecording = nil
               return current
           }
           return .invoked
       } else if interactions.presentation.readingText {
            interactions.update { current in
                var current = current
                current.readingText = false
                return current
            }
            return .invoked
        } else if let _ = interactions.presentation.inputRecording {
            interactions.update { current in
                var current = current
                current.inputRecording = nil
                return current
            }
            return .invoked
        } else if self.genericView.inputView == window?.firstResponder {
            if interactions.presentation.hasReactions {
                genericView.closeReactions()
            } else {
                self.genericView.resetInputView()
            }
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
    @discardableResult private func delete() -> KeyHandlerResult {
        return genericView.delete()
    }
    
    
    deinit {
        disposable.dispose()
        updatesDisposable.dispose()
        permissionDisposable.dispose()
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
    
    private var closed: Bool = false
    
    override func close(animationType: ModalAnimationCloseBehaviour = .common) {
        if !self.closed {
            super.close(animationType: .common)
            self.genericView.animateDisappear(initialId)
        }
        self.interactions.update({ current in
            var current = current
            current.closed = true
            return current
        })
        self.closed = true
    }

    override var isVisualEffectBackground: Bool {
        return true
    }
    
    static func ShowStories(context: AccountContext, includeHidden: Bool, initialId: StoryInitialIndex?) {
        let storyContent = StoryContentContextImpl(context: context, includeHidden: includeHidden, focusedPeerId: initialId?.peerId)
        let _ = (storyContent.state
        |> filter { $0.slice != nil }
        |> take(1)
        |> deliverOnMainQueue).start(next: { _ in
            showModal(with: StoryModalController(context: context, stories: storyContent, initialId: initialId), for: context.window, animationType: .animateBackground)
        
        })
    }
    static func ShowSingleStory(context: AccountContext, storyId: StoryId, initialId: StoryInitialIndex?, emptyCallback:(()->Void)? = nil) {
        let storyContent = SingleStoryContentContextImpl(context: context, storyId: storyId)
        let _ = (storyContent.state
        |> filter { $0.slice != nil }
        |> take(1)
        |> deliverOnMainQueue).start(next: { state in
            if state.slice != nil {
                showModal(with: StoryModalController(context: context, stories: storyContent, initialId: initialId), for: context.window, animationType: .animateBackground)
            } else {
                emptyCallback?()
            }
        
        })
    }
    static func ShowPeerStory(context: AccountContext, listContext: PeerStoryListContext, peerId: PeerId, initialId: StoryInitialIndex?) {
        let storyContent = PeerStoryListContentContextImpl(context: context, peerId: peerId, listContext: listContext, initialId: initialId?.id)
        let _ = (storyContent.state
        |> filter { $0.slice != nil }
        |> take(1)
        |> deliverOnMainQueue).start(next: { _ in
            showModal(with: StoryModalController(context: context, stories: storyContent, initialId: initialId), for: context.window, animationType: .animateBackground)
        
        })
    }
}



