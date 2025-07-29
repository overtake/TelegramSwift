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
import InAppSettings

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


struct StoryReactionAction {
    let item: UpdateMessageReaction
    let fromRect: CGRect?
}



private let storedTheme = generateTheme(palette: nightAccentPalette, cloudTheme: nil, bubbled: false, fontSize: 13, wallpaper: .init())

var darkAppearance: TelegramPresentationTheme {
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
        var longDown: Bool = false

        var inputInFocus: Bool = false
        var hasPopover: Bool = false
        var hasMenu: Bool = false
        var hasModal: Bool = false
        var windowIsKey: Bool = false
        var _inTransition: Bool = false
        var lock: Bool = false
        var isRecording: Bool = false
        var hasReactions: Bool = false
        var hasLikePanel: Bool = false
        var isSpacePaused: Bool = false
        var playingReaction: Bool = false
        var readingText: Bool = false
        var magnified: Bool = false
        var isMuted: Bool = false
        var storyId: Int32? = nil
        var entryId: PeerId? = nil
        var closed: Bool = false
        
        var volume: Float = FastSettings.volumeStoryRate
        
        var isSeeking = false
        
        var wideInput: Bool {
            let accept = self.entryId?.namespace == Namespaces.Peer.CloudUser || self.entryId?.namespace == Namespaces.Peer.CloudChannel
            return (inputInFocus || hasPopover) && accept
        }
        
        var isAreaActivated: Bool = false
        
        
        var canRecordVoice: Bool = true
        var isProfileIntended: Bool = false
        var emojiState: EntertainmentState = FastSettings.entertainmentState
        var inputRecording: ChatRecordingState?
        var recordType: RecordingStateSettings = FastSettings.recordingState
        var stealthMode: Stories.StealthModeState = .init(activeUntilTimestamp: nil, cooldownUntilTimestamp: nil)
        var slowMode: SlowMode?
        var canViewStats: Bool = false
        var reactions: AvailableReactions?
        var isPaused: Bool {
            return mouseDown || inputInFocus || hasPopover || hasModal || !windowIsKey || inTransition || isRecording || hasMenu || hasReactions || playingReaction || isSpacePaused || readingText || inputRecording != nil || lock || closed || magnified || longDown || isAreaActivated || hasLikePanel || isSeeking
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
    
    func activateArea() {
//        self.update { current in
//            var current = current
//            current.isAreaActivated = true
//            return current
//        }
    }
    
    func deactivateArea() {
//        self.update { current in
//            var current = current
//            current.isAreaActivated = false
//            return current
//        }
    }
    
    func updateMagnify(_ value: CGFloat) {
        self.update { current in
            var current = current
            current.magnified = value != 1.0
            return current
        }
    }
    
    func toggleMuted() {
        self.update { current in
            var current = current
            current.isMuted = !current.isMuted
            current.volume = current.isMuted ? 0 : 1
            return current
        }
        FastSettings.storyIsMuted = self.presentation.isMuted
        FastSettings.setStoryVolumeRate(self.presentation.volume)
    }
    
    func setVolume(_ volume: Float) {
        self.update { current in
            var current = current
            current.volume = volume
            current.isMuted = current.volume == 0
            return current
        }
        FastSettings.storyIsMuted = self.presentation.isMuted
        FastSettings.setStoryVolumeRate(self.presentation.volume)
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
    func hasNoSound(_ story: EngineStoryItem) -> Bool {
        if let media = story.media._asMedia() as? TelegramMediaFile {
            return media.hasNoSound
        }
        return true
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
        let inputText = presentation.input.attributedString().mutableCopy() as! NSMutableAttributedString
        
        
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
    let showLikePanel:(Control, StoryContentItem)->Void
    let react:(StoryReactionAction)->Void
    let likeAction:(StoryReactionAction)->Void
    let attachPhotoOrVideo:(ChatInteraction.AttachMediaType?)->Void
    let attachFile:()->Void
    let nextStory:()->Void
    let prevStory:()->Void
    let close:()->Void
    let openPeerInfo:(PeerId, NSView?)->Void
    let openChat:(PeerId, MessageId?, ChatInitialAction?)->Void
    let sendMessage:(PeerId, Int32)->Void
    let toggleRecordType:()->Void
    let deleteStory:(StoryContentItem)->Void
    let markAsRead:(PeerId, Int32)->Void
    let showViewers:(StoryContentItem)->Void
    let share:(StoryContentItem)->Void
    let repost:(StoryContentItem)->Void
    let copyLink:(StoryContentItem)->Void
    let startRecording: (Bool)->Void
    let togglePinned:(StoryContentItem)->Void
    let hashtag:(String)->Void
    let toggleHide:(Peer, Bool)->Void
    let showFriendsTooltip:(Control, StoryContentItem)->Void
    let showTooltipText:(String, MenuAnimation)->Void
    let storyContextMenu:(StoryContentItem)->ContextMenu?
    let activateMediaArea:(MediaArea)->Void
    let deactivateMediaArea:(MediaArea)->Void
    let invokeMediaArea:(MediaArea)->Void
    let like:(MessageReaction.Reaction?, StoryInteraction.State)->Void
    let setupPrivacy:(StoryContentItem)->Void
    let loadForward:(StoryId)->Promise<EngineStoryItem?>
    let openStory:(StoryId)->Void
    init(context: AccountContext, interaction: StoryInteraction, chatInteraction: ChatInteraction, showEmojiPanel:@escaping(Control)->Void, showReactionsPanel:@escaping()->Void, react:@escaping(StoryReactionAction)->Void, likeAction:@escaping(StoryReactionAction)->Void, attachPhotoOrVideo:@escaping(ChatInteraction.AttachMediaType?)->Void, attachFile:@escaping()->Void, nextStory:@escaping()->Void, prevStory:@escaping()->Void, close:@escaping()->Void, openPeerInfo:@escaping(PeerId, NSView?)->Void, openChat:@escaping(PeerId, MessageId?, ChatInitialAction?)->Void, sendMessage:@escaping(PeerId, Int32)->Void, toggleRecordType:@escaping()->Void, deleteStory:@escaping(StoryContentItem)->Void, markAsRead:@escaping(PeerId, Int32)->Void, showViewers:@escaping(StoryContentItem)->Void, share:@escaping(StoryContentItem)->Void, repost:@escaping(StoryContentItem)->Void, copyLink: @escaping(StoryContentItem)->Void, startRecording: @escaping(Bool)->Void, togglePinned:@escaping(StoryContentItem)->Void, hashtag:@escaping(String)->Void, toggleHide:@escaping(Peer, Bool)->Void, showFriendsTooltip:@escaping(Control, StoryContentItem)->Void, showTooltipText:@escaping(String, MenuAnimation)->Void, storyContextMenu:@escaping(StoryContentItem)->ContextMenu?, activateMediaArea:@escaping(MediaArea)->Void, deactivateMediaArea:@escaping(MediaArea)->Void, invokeMediaArea:@escaping(MediaArea)->Void, like:@escaping(MessageReaction.Reaction?, StoryInteraction.State)->Void, showLikePanel:@escaping(Control, StoryContentItem)->Void, setupPrivacy:@escaping(StoryContentItem)->Void, loadForward:@escaping(StoryId)->Promise<EngineStoryItem?>, openStory:@escaping(StoryId)->Void) {
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
        self.repost = repost
        self.copyLink = copyLink
        self.startRecording = startRecording
        self.togglePinned = togglePinned
        self.hashtag = hashtag
        self.toggleHide = toggleHide
        self.showFriendsTooltip = showFriendsTooltip
        self.showTooltipText = showTooltipText
        self.react = react
        self.likeAction = likeAction
        self.storyContextMenu = storyContextMenu
        self.activateMediaArea = activateMediaArea
        self.deactivateMediaArea = deactivateMediaArea
        self.invokeMediaArea = invokeMediaArea
        self.like = like
        self.showLikePanel = showLikePanel
        self.setupPrivacy = setupPrivacy
        self.loadForward = loadForward
        self.openStory = openStory
    }
    
    func longDown() {
        self.interaction.update { current in
            var current = current
            current.longDown = true
            return current
        }
    }
    func down() {
        self.interaction.update { current in
            var current = current
            current.mouseDown = true
            return current
        }
    }
    func up() {
        self.interaction.update { current in
            var current = current
            current.mouseDown = false
            current.longDown = false
            return current
        }
    }
    
    func inputFocus() {
        self.interaction.update { current in
            var current = current
            current.inputInFocus = true
            current.isSpacePaused = true
            current.readingText = false
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


func storyReactionsWindow(context: AccountContext, peerId: PeerId, react: @escaping(StoryReactionAction)->Void, onClose: @escaping()->Void, selectedItems: [EmojiesSectionRowItem.SelectedItem]) -> Signal<Window?, NoError> {
    return storyReactionsValues(context: context, peerId: peerId, react: react, onClose: onClose, name: "reactions", selectedItems: selectedItems) |> map { value in
        if let (panel, view) = value {
            panel._canBecomeMain = false
            panel._canBecomeKey = false
            panel.level = .popUpMenu
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.contentView?.addSubview(view)
            panel.contentView?.wantsLayer = true
            view.setFrameOrigin(.zero)
            view.autoresizingMask = [.width, .height]
            return panel
        } else {
            return nil
        }
    }
}

private func storyReactions(context: AccountContext, peerId: PeerId, react: @escaping(StoryReactionAction)->Void, onClose: @escaping()->Void, selectedItems: [EmojiesSectionRowItem.SelectedItem] = []) -> Signal<NSView?, NoError> {
    return storyReactionsValues(context: context, peerId: peerId, react: react, onClose: onClose, selectedItems: selectedItems) |> map { $0?.1 }
}

private func storyReactionsValues(context: AccountContext, peerId: PeerId, react: @escaping(StoryReactionAction)->Void, onClose: @escaping()->Void, name: String = "", selectedItems: [EmojiesSectionRowItem.SelectedItem] = []) -> Signal<(Window, NSView)?, NoError> {
    
    
    let builtin = context.reactions.stateValue
    let peerAllowed: Signal<PeerAllowedReactions?, NoError> = getCachedDataView(peerId: peerId, postbox: context.account.postbox)
    |> map { cachedData in
        if let cachedData = cachedData as? CachedGroupData {
            return cachedData.reactionSettings.knownValue?.allowedReactions
        } else if let cachedData = cachedData as? CachedChannelData {
            return cachedData.reactionSettings.knownValue?.allowedReactions
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
                    return .builtin(value: generic.value, staticFile: generic.staticIcon._parse(), selectFile: generic.selectAnimation._parse(), appearFile: generic.appearAnimation._parse(), isSelected: selectedItems.contains(where: { $0.source == .builtin(emoji) }))
                } else {
                    return nil
                }
            case let .custom(file):
                return .custom(value: .custom(file._parse().fileId.id), fileId: file._parse().fileId.id, file._parse(), isSelected: selectedItems.contains(where: { $0.source == .custom(file._parse().fileId.id) }))
            case .stars:
                return nil
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
       
        

        let reveal:((NSView & StickerFramesCollector)->Void)?
        
       
        
        reveal = { view in
            let window = ReactionsWindowController(context, peerId: peerId, selectedItems: selectedItems, react: { sticker, fromRect in
                let value: UpdateMessageReaction
                if let bundle = sticker.file._parse().stickerText {
                    value = .builtin(bundle)
                } else {
                    value = .custom(fileId: sticker.file._parse().fileId.id, file: sticker.file._parse())
                }
                react(.init(item: value, fromRect: fromRect))
                onClose()
            }, onClose: onClose, presentation: darkAppearance, name: name)
            window.show(view)
        }
                
        let view = ContextAddReactionsListView(frame: rect, context: context, list: available, add: { value, checkPrem, fromRect in
            onClose()
            react(.init(item: value.toUpdate(), fromRect: fromRect))
        }, radiusLayer: nil, revealReactions: reveal, presentation: darkAppearance, hasBubble: false, aboveText: nil)
        
        return (panel, view)
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
                        let preview = Preview(frame: focus(StoryLayoutView.size.aspectFitted(NSMakeSize(150, 150))))
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
            }
            if isNext {
                button.set(image: next_chevron_hover, for: .Normal)
            } else {
                button.set(image: prev_chevron_hover, for: .Normal)
            }
            
            button.sizeToFit(.zero, NSMakeSize(30, 30), thatFit: true)
            button.sizeToFit(.zero, NSMakeSize(30, 30), thatFit: true)

            button.controlOpacityEventIgnored = true
            button.controlOpacityEventIgnored = true
            self.updateVisibility(animated: false)
            needsLayout = true
        }
        
        
        override func layout() {
            self.preview?.isHidden = frame.width < 200
            self.preview?.center()

            if let preview = self.preview, preview.isHidden {
                button.center()
            } else {
                let rect = focus(StoryLayoutView.size.aspectFitted(NSMakeSize(150, 150)))
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
            case reaction(StoryReactionAction)
            case media([Media])
            case text
            case addedToProfile(Peer)
            case removedFromProfile(Peer)
            case linkCopied
            case justText(String)
            case tooltip(String, MenuAnimation)
        }
        private let bg = Control()
        private let textView = TextView()
        private let button = TextButton()
        private let media = View(frame: NSMakeRect(0, 0, 24, 24))
        
        private var close:(()->Void)?
        
        required override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.wantsLayer = true
            self.state = .active
            self.material = .ultraDark
            self.blendingMode = .withinWindow
            textView.isSelectable = false
            addSubview(textView)
            addSubview(media)
            addSubview(bg)
            addSubview(button)
            button.autohighlight = false
            button.scaleOnClick = true
            self.layer?.cornerRadius = 10
            
            bg.set(handler: { [weak self] _ in
                self?.close?()
            }, for: .Click)
        }
        
        func update(source: Source, size: NSSize, context: AccountContext, callback: @escaping()->Void, close: @escaping()->Void) {
            let title: String
            var mediaFile: TelegramMediaFile
            let hasButton: Bool
            self.close = close
            var colorAnimation: Bool = false
            switch source {
            case let .media(medias):
                if medias.count > 1 {
                    title = strings().storyTooltipReactionSent
                } else if let media = medias.first {
                    if let file = media as? TelegramMediaFile {
                        if file.isSticker || file.isAnimatedSticker || file.isVideoSticker {
                           title = strings().storyTooltipStickerSent
                        } else if file.isVideo && file.isAnimated {
                            title = strings().storyTooltipGifSent
                        } else if file.isVideo {
                            title = strings().storyTooltipVideoSent
                        } else if file.isMusic || file.isMusicFile {
                            title = strings().storyTooltipAudioSent
                        } else {
                            title = strings().storyTooltipMediaSent
                        }
                    } else if let _ = media as? TelegramMediaImage {
                        title = strings().storyTooltipPhotoSent
                    } else {
                        title = strings().storyTooltipMediaSent
                    }
                } else {
                    title = strings().storyTooltipMediaSent
                }
                mediaFile = MenuAnimation.menu_success.file
                hasButton = true
            case let .reaction(reaction):
                title = strings().storyTooltipReactionSent
                var file: TelegramMediaFile?
                switch reaction.item {
                case let .custom(_, f):
                    file = f
                case let .builtin(string):
                    let reaction = context.reactions.available?.reactions.first(where: { $0.value.string == string })
                    file = reaction?.selectAnimation._parse()
                case .stars:
                    break
                }
                if let file = file {
                    mediaFile = file
                } else {
                    mediaFile = MenuAnimation.menu_success.file
                }
                hasButton = true
            case .text:
                title = strings().storyTooltipMessageSent
                mediaFile = MenuAnimation.menu_success.file
                hasButton = true
            case let .addedToProfile(peer):
                title = peer.isChannel ? strings().storyTooltipSavedToProfileChannel : strings().storyTooltipSavedToProfile
                mediaFile = MenuAnimation.menu_success.file
                hasButton = false
            case let .removedFromProfile(peer):
                title = peer.isChannel ? strings().storyTooltipRemovedFromProfileChannel : strings().storyTooltipRemovedFromProfile
                mediaFile = MenuAnimation.menu_success.file
                hasButton = false
            case .linkCopied:
                title = strings().storyTooltipLinkCopied
                mediaFile = MenuAnimation.menu_success.file
                hasButton = false
            case let .justText(text):
                title = text
                mediaFile = MenuAnimation.menu_success.file
                hasButton = false
            case let .tooltip(text, animation):
                title = text
                mediaFile = animation.file
                hasButton = false
                colorAnimation = true
            }
            
            let mediaLayer = InlineStickerItemLayer(account: context.account, file: mediaFile, size: NSMakeSize(24, 24), playPolicy: .toEnd(from: 0), getColors: { file in
                if file == MenuAnimation.menu_success.file {
                    return []
                } else if colorAnimation {
                    return [.init(keyPath: "", color: NSColor(0xffffff))]
                } else {
                    return []
                }
            })
            mediaLayer.isPlayable = true
            mediaLayer.superview = self.media
            
            self.media.layer?.addSublayer(mediaLayer)
            
            let attr = NSMutableAttributedString()
            _ = attr.append(string: title, color: darkAppearance.colors.text, font: .normal(.text))
            attr.detectBoldColorInString(with: .medium(.text))
            let layout = TextViewLayout(attr)
            
            self.button.isHidden = !hasButton
            
            self.button.set(font: .medium(.text), for: .Normal)
            self.button.set(color: darkAppearance.colors.accent, for: .Normal)
            self.button.set(text: strings().storyTooltipButtonViewInChat, for: .Normal)
            self.button.sizeToFit(NSMakeSize(10, 10), .zero, thatFit: false)
            
            layout.measure(width: size.width - 16 - (button.isHidden ? 0 : 16 + self.button.frame.width) - media.frame.width - 10 - 10)
            textView.update(layout)

            
            layout.measure(width: size.width - 16 - (button.isHidden ? 0 : 16 + self.button.frame.width) - media.frame.width - 10 - 10)
            textView.update(layout)

            layout.interactions = .init(processURL: { url in
                if let url = url as? String {
                    if url == "premium" {
                        prem(with: PremiumBoardingController(context: context, source: .stories__save_to_gallery, presentation: darkAppearance), for: context.window)
                    }
                }
            })
            
            
            self.button.set(handler: { _ in
                callback()
            }, for: .Click)
            
            let width: CGFloat
            if hasButton {
                width = size.width
            } else {
                width = 16 + media.frame.width + 10 + layout.layoutSize.width + 16
            }
            
            self.setFrameSize(NSMakeSize(width, max(size.height, layout.layoutSize.height + 10)))
            self.updateLayout(size: size, transition: .immediate)
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            transition.updateFrame(view: bg, frame: size.bounds)
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
    
    fileprivate var storyContext: StoryContentContext?
    fileprivate var storyViewList: EngineStoryViewListContext?

    
    private var textInputSuggestionsView: InputSwapSuggestionsPanel?
    fileprivate var inputContextHelper: InputContextHelper!
    
    var hasEmojiSwap: Bool {
        return self.textInputSuggestionsView != nil
    }
    
    func updateTextInputSuggestions(_ files: [TelegramMediaFile], chatInteraction: ChatInteraction, range: NSRange, animated: Bool) {
        if !files.isEmpty, let textView = self.current?.inputTextView {
            let context = chatInteraction.context
            let current: InputSwapSuggestionsPanel
            let isNew: Bool
            if let view = self.textInputSuggestionsView {
                current = view
                isNew = false
            } else {
                current = InputSwapSuggestionsPanel(inputView: textView, textContent: textView.scrollView.contentView, relativeView: self, window: context.window, context: context, presentation: darkAppearance, highlightRect: { [weak textView] range, whole in
                    return textView?.highlight(for: range, whole: whole) ?? .zero
                })
                self.textInputSuggestionsView = current
                isNew = true
            }
            current.apply(files, range: range, animated: animated, isNew: isNew)
        } else if let view = self.textInputSuggestionsView {
            view.close(animated: animated)
            self.textInputSuggestionsView = nil
        }
    }

    
    private let container = View()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(leftTop)
        addSubview(leftBottom)
        addSubview(rightTop)
        addSubview(rightBottom)

        addSubview(container)
        

        addSubview(prev_button)
        addSubview(next_button)
        
        
//        leftBottom.backgroundColor = .random
//        rightTop.backgroundColor = .random
//        rightBottom.backgroundColor = .random
//        leftTop.backgroundColor = .random


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
        
        let processClose:(Control)->Void = { [weak self] control in
            guard let `self` = self else {
                return
            }
            if let event = NSApp.currentEvent {
                let point = self.convert(event.locationInWindow, from: nil)
                if NSPointInRect(point, control.frame) {
                    if self.isInputFocused {
                        self.resetInputView()
                    } else {
                        self.close.send(event: .Click)
                    }
                }
            }
        }
        
        leftTop.set(handler: { control in
            processClose(control)
        }, for: .Up)
        
        leftBottom.set(handler: { control in
            processClose(control)
        }, for: .Up)
        
        rightTop.set(handler: { control in
            processClose(control)
        }, for: .Up)
        
        rightBottom.set(handler: { control in
            processClose(control)
        }, for: .Up)

        
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
        return self.storyContext?.stateValue?.nextSlice != nil || self.storyContext?.stateValue?.slice?.nextItemId != nil
    }
    var hasPrevGroup: Bool {
        return self.storyContext?.stateValue?.previousSlice != nil || self.storyContext?.stateValue?.slice?.previousItemId != nil
    }
    
    var hasNextSlice: Bool {
        return self.storyContext?.stateValue?.nextSlice != nil
    }
    var hasPrevSlice: Bool {
        return self.storyContext?.stateValue?.previousSlice != nil
    }
    
    private func updatePrevNextControls(_ event: NSEvent, animated: Bool = true) {
        guard let arguments = self.arguments else {
            return
        }
        
        let presentation = arguments.interaction.presentation
        let hasOverlay = presentation.hasModal || presentation.hasMenu || presentation.hasPopover || presentation.inTransition
        
        let nextEntry = hasOverlay ? nil : self.storyContext?.stateValue?.nextSlice
        let prevEntry = hasOverlay ? nil : self.storyContext?.stateValue?.previousSlice
        
        self.prev_button.update(with: prevEntry, context: arguments.context, isNext: false, animated: animated)
        self.next_button.update(with: nextEntry, context: arguments.context, isNext: true, animated: animated)

        let point = self.convert(event.locationInWindow, from: nil)
        
        if prev_button.mouseInside() {
            self.prev_button.change(opacity: hasPrevGroup ? 1 : 0, animated: animated)
            self.next_button.change(opacity: 0, animated: animated)
        } else {
            self.prev_button.change(opacity: 0, animated: animated)
        }
        
        if next_button.mouseInside() {
            self.next_button.change(opacity: hasNextGroup ? 1 : 0, animated: animated)
            self.prev_button.change(opacity: 0, animated: animated)
        } else {
            self.next_button.change(opacity: 0, animated: animated)
        }
        
        self.prev_button.isHidden = self.reactions != nil || self.isInputFocused
        self.next_button.isHidden = self.reactions != nil || self.isInputFocused
        
        let close_rects = [leftTop.frame, leftBottom.frame, rightTop.frame, rightBottom.frame]
        
        if close_rects.contains(where: { NSPointInRect(point, $0) }) {
            close.set(image: close_image_hover, for: .Normal)
        } else {
            close.set(image: close_image, for: .Normal)
        }

        
    }
    
    
    
    
    func update(context: AccountContext, storyContext: StoryContentContext, initial: StoryInitialIndex?) {
                
        
        guard let state = storyContext.stateValue else {
            return
        }
        
        
        self.storyContext = storyContext
       
        let slice: StoryContentContextState.FocusedSlice?
        if let current = self.current {
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
        
        var updated: Bool = false
        arguments?.interaction.update(animated: false, { current in
            var current = current
            updated = current.storyId != state.slice?.item.storyItem.id
            current.entryId = state.slice?.peer.id
            current.storyId = state.slice?.item.storyItem.id
            current.canRecordVoice = state.slice?.additionalPeerData.areVoiceMessagesAvailable == true
            current.canViewStats = state.slice?.additionalPeerData.canViewStats == true
            current.isProfileIntended = false
            if updated {
                current.magnified = false
                current.readingText = false
                current.mouseDown = false
                current.longDown = false
                current.isAreaActivated = false
            }
            return current
        })
        
        if updated {
            self.closeTooltip()
            if let peerId = state.slice?.peer.id, let story = state.slice?.item.storyItem {
                let accept = state.slice?.peer.id == context.peerId || state.slice?.additionalPeerData.canViewStats == true
                let isChannel = state.slice?.peer.id.namespace == Namespaces.Peer.CloudChannel
                if accept {
                    self.storyViewList = context.engine.messages.storyViewList(peerId: peerId, id: story.id, views: story.views ?? .init(seenCount: 0, reactedCount: 0, forwardCount: 0, seenPeers: [], reactions: [], hasList: false), listMode: .everyone, sortMode: isChannel ? .repostsFirst : .reactionsFirst)
                    self.storyViewList?.loadMore()
                } else {
                    self.storyViewList = nil
                }
            } else {
                self.storyViewList = nil
            }
        }
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
        guard let arguments = self.arguments else {
            return .invokeNext
        }
        if arguments.interaction.presentation.hasPopover {
            return .invokeNext
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
        guard let arguments = self.arguments else {
            return .invokeNext
        }
        if arguments.interaction.presentation.hasPopover {
            return .invokeNext
        }
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
            let halfHeight = max(200, size.height / 3)
            transition.updateFrame(view: prev_button, frame: NSMakeRect(0, (size.height - halfHeight) / 2, halfSize, halfHeight))
            transition.updateFrame(view: next_button, frame: NSMakeRect(halfSize + current.contentRect.width, (size.height - halfHeight) / 2, halfSize, halfHeight))
            
            var chl: CGFloat
            var chr: CGFloat
            if prev_button.isHidden {
                chl = size.height / 2
            } else {
                chl = (size.height - prev_button.frame.height) / 2
            }
            if next_button.isHidden {
                chr = size.height / 2
            } else {
                chr = (size.height - prev_button.frame.height) / 2
            }
            
            transition.updateFrame(view: leftTop, frame: NSMakeRect(0, 0, halfSize, chl))
            transition.updateFrame(view: leftBottom, frame: NSMakeRect(0, prev_button.isHidden ? chl : prev_button.frame.maxY, halfSize, chl))
            
            transition.updateFrame(view: rightTop, frame: NSMakeRect(size.width - halfSize, 0, halfSize, chr))
            transition.updateFrame(view: rightBottom, frame: NSMakeRect(size.width - halfSize, next_button.isHidden ? chr : next_button.frame.maxY, halfSize, chr))

            if let view = self.reactions {
                let point = NSMakePoint((size.width - view.frame.width) / 2, current.storyRect.maxY - view.frame.height + 15)
                transition.updateFrame(view: view, frame: CGRect(origin: point, size: view.frame.size))
            }
        }

        transition.updateFrame(view: close, frame: NSMakeRect(size.width - close.frame.width, 0, 50, 50))
        
        if let overlay = self.likesOverlay {
            transition.updateFrame(view: overlay, frame: size.bounds)
        }
    }
    
    var inputView: NSTextView? {
        return self.current?.textView
    }
    var inputTextView: UITextView? {
        return self.current?.inputTextView
    }
    
    func zoomIn() {
        self.current?.zoomIn()
    }
    func zoomOut() {
        self.current?.zoomOut()
    }
    
    func resetInputView() {
        self.current?.resetInputView()
    }
    func setArguments(_ arguments: StoryArguments?) -> Void {
        self.arguments = arguments
        self.current?.setArguments(arguments)
    }
    
    private var reactions: NSView? = nil
    private var likes: NSView? = nil
    private var likesOverlay: NSView? = nil
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
            if self.arguments?.interaction.presentation.hasPopover == false {
                self.resetInputView()
                resetInput = true
            }
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
    
    func closeLikePanel() {
        
        if let view = self.likesOverlay {
            performSubviewRemoval(view, animated: true)
            self.likesOverlay = nil
        }
        if let view = self.likes {
            performSubviewRemoval(view, animated: true)
            self.likes = nil
        }
       
        self.arguments?.interaction.update { current in
            var current = current
            current.hasLikePanel = false
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
    
    func playReaction(_ reaction: StoryReactionAction) -> Void {
        
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
            let reaction = context.reactions.available?.reactions.first(where: { $0.value.string.withoutColorizer == string.withoutColorizer })
            file = reaction?.selectAnimation._parse()
            effectFile = reaction?.aroundAnimation?._parse()
        case .stars:
            break
        }
        
        guard let icon = file else {
            return
        }
       
        guard let current = self.current else {
            return
        }
        
        let overlay = View(frame: NSMakeRect(0, 0, 300, 300))
        overlay.isEventLess = true 
        current.addSubview(overlay)
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
                player.frame = NSMakeRect((container.frame.width - player.frame.width) / 2, (container.frame.height - player.frame.height) / 2, player.frame.width, player.frame.height)
                
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
    
    func showLikePanel(_ view: NSView, control: Control) {
        
        guard let current = current, self.likes == nil else {
            return
        }
        
        
        
        let overlay = Control(frame: bounds)
        self.likesOverlay = overlay
        addSubview(overlay)

        overlay.set(handler: { [weak self] _ in
            self?.closeLikePanel()
        }, for: .Click)
        
        view.setFrameOrigin(NSMakePoint((frame.width - view.frame.width) / 2, current.storyRect.maxY - view.frame.height + 15))
        overlay.addSubview(view)
        
        view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        view.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
        
        self.likes = view
        
        
        
        self.arguments?.interaction.update { current in
            var current = current
            current.hasLikePanel = true
            return current
        }
    }
    
    func like(_ like: StoryReactionAction) {
        self.current?.inputView.like(like, resetIfNeeded: false)
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
        
        let close:()->Void = { [weak self] in
            self?.tooltipDisposable.set(nil)
            if let view = self?.currentTooltip {
                performSubviewRemoval(view, animated: true)
                self?.currentTooltip = nil
            }
        }
        
        tooltip.update(source: source, size: NSMakeSize(current.contentRect.width - 20, 40), context: arguments.context, callback: { [weak arguments] in
            arguments?.openChat(entryId, nil, nil)
        }, close: close)
        
        self.addSubview(tooltip)
        tooltip.centerX(y: current.storyRect.maxY - tooltip.frame.height - 10)
        
        tooltip.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        tooltip.layer?.animatePosition(from: tooltip.frame.origin.offsetBy(dx: 0, dy: 20), to: tooltip.frame.origin)
        let signal = Signal<Void, NoError>.single(Void()) |> delay(4.5, queue: .mainQueue())
        self.tooltipDisposable.set(signal.start(completed: close))
        
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
                    if self?.hasPrevSlice == false, value > 0.5 {
                        self?.close.send(event: .Click)
                    }
                case .moveNext:
                    if self?.hasNextSlice == false, value > 0.5 {
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
            
            if scrollDeltaX != 0 || scrollDeltaY != 0 {
                self.inTransition = true
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
                if !hasPrevSlice {
                    delta = log(scrollDeltaX) / maxDelta * 25
                    autofinish = false
                } else {
                    delta = scrollDeltaX
                }
            } else {
                if !hasNextSlice {
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
                    if let peerId = current.id, let story = current.story {
                        let peer = self.storyContext?.stateValue?.slice?.peer._asPeer()
                        if peerId == arguments?.context.peerId {
                            arguments?.showViewers(story)
                        } else if peer?.isChannel == true {
                            arguments?.showViewers(story)
                        } else if current.hasInput {
                            self.window?.makeFirstResponder(self.inputView)
                            self.showReactions()
                            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                        }
                        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                    } else {
                        if self.reactions != nil {
                            self.closeReactions(reactByFirst: true)
                        } else {
                            if self.isInputFocused {
                                self.resetInputView()
                            } else {
                                if current.hasInput {
                                    self.window?.makeFirstResponder(self.inputView)
                                    self.showReactions()
                                    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                                } else {
                                    NSSound.beep()
                                }
                            }
                        }
                    }
                }
            }
            
            if scrollDeltaY != 0 {
                self.inTransition = false
            }
            
            let progress = value
            var cancelAnyway = false
            switch result {
            case .moveBack:
                if !self.hasPrevSlice, value > 0.5 {
//                    progress = 1.0
                    cancelAnyway = true
                }
            case .moveNext:
                if !self.hasNextSlice, value > 0.5 {
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
    
    private var contextQueryState: (ChatPresentationInputQuery?, Disposable)?

    private let context: AccountContext
    private var initialId: StoryInitialIndex?
    private let stories: StoryContentContext
    private let entertainment: EntertainmentViewController
    private let interactions: StoryInteraction
    private let chatInteraction: ChatInteraction
    
    private let disposable = MetaDisposable()
    private let actionsDisposable = DisposableSet()
    private let updatesDisposable = MetaDisposable()
    private let inputSwapDisposable = MetaDisposable()
    private let slowModeDisposable = MetaDisposable()
    private var overlayTimer: SwiftSignalKit.Timer?
    
    private var arguments: StoryArguments?

    init(context: AccountContext, stories: StoryContentContext, initialId: StoryInitialIndex?) {
        self.entertainment = EntertainmentViewController(size: NSMakeSize(350, 350), context: context, mode: .stories, presentation: darkAppearance)
        self.interactions = StoryInteraction()
        self.context = context
        self.initialId = initialId
        self.stories = stories
        self.chatInteraction = ChatInteraction(chatLocation: .peer(PeerId(0)), context: context)
        super.init()
        self._frameRect = context.window.contentView!.bounds
        self.bar = .init(height: 0)
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
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            self.interactions.update({ current in
                var current = current
                if let entryId = current.entryId {
                    current.inputs[entryId] = value.effectiveInput
                }
                current.emojiState = value.isEmojiSection ? .emoji : .stickers
                return current
            })
            if let current = genericView.current {
                if value.inputQueryResult != oldValue.inputQueryResult {
                    current.inputView.updateInputContext(with: value.inputQueryResult, context: genericView.inputContextHelper, animated: animated)
                    //genericView.inputContextHelper.context(with: value.inputQueryResult, for: current.container, relativeView: current.inputView, animated: animated)
                }
            }
            
            
           
            
            if value.inputQueryResult != oldValue.inputQueryResult || value.effectiveInput != oldValue.effectiveInput || value.state != oldValue.state {
                if let (updatedContextQueryState, updatedContextQuerySignal) = contextQueryResultStateForChatInterfacePresentationState(value, context: self.context, currentQuery: self.contextQueryState?.0) {
                    self.contextQueryState?.1.dispose()
                    var inScope = true
                    var inScopeResult: ((ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?)?
                    self.contextQueryState = (updatedContextQueryState, (updatedContextQuerySignal |> deliverOnMainQueue).start(next: { [weak self] result in
                        if let strongSelf = self {
                            if Thread.isMainThread && inScope {
                                inScope = false
                                inScopeResult = result
                            } else {
                                strongSelf.chatInteraction.update(animated: animated, {
                                    $0.updatedInputQueryResult { previousResult in
                                        return result(previousResult)
                                    }
                                })
                                
                            }
                        }
                    }))
                    inScope = false
                    if let inScopeResult = inScopeResult {
                        chatInteraction.update(animated: animated, {
                            $0.updatedInputQueryResult { previousResult in
                                return inScopeResult(previousResult)
                            }
                        })
                        
                    }
                }
            }
            
            if let until = value.slowMode?.validUntil, until > self.context.timestamp {
                let signal = Signal<Void, NoError>.single(Void()) |> then(.single(Void()) |> delay(0.2, queue: .mainQueue()) |> restart)
                slowModeDisposable.set(signal.start(next: { [weak self] in
                    if let `self` = self {
                        if until < self.context.timestamp {
                            self.arguments?.interaction.update { current in
                                var current = current
                                current.slowMode = value.slowMode?.withUpdatedTimeout(nil)
                                return current
                            }
                        } else {
                            self.arguments?.interaction.update { current in
                                var current = current
                                current.slowMode = value.slowMode?.withUpdatedTimeout(until - self.context.timestamp)
                                return current
                            }
                        }
                    }
                }))
                
            } else {
                self.slowModeDisposable.set(nil)
                if let slowMode = value.slowMode, slowMode.timeout != nil {
                    DispatchQueue.main.async { [weak self] in
                        self?.arguments?.interaction.update { current in
                            var current = current
                            current.slowMode = value.slowMode?.withUpdatedTimeout(nil)
                            return current
                        }
                    }
                }
            }
            
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
                if value.inputInFocus {
                    self.chatInteraction.update({
                        $0.withoutSelectionState()
                    })
                } else {
                    self.chatInteraction.update({
                        $0.withSelectionState()
                    })
                }
            }
            if value.hasReactions != oldValue.hasReactions, !value.hasReactions {
                self.genericView.closeReactions()
            }
            if value.closed {
                self.genericView.closeReactions()
                self.genericView.closeTooltip()
            }
            
            if value.input != oldValue.input || value.inputInFocus != oldValue.inputInFocus {
                
                let input = value.input
                let textInputContextState = textInputStateContextQueryRangeAndType(input, includeContext: false)
                
                var cleanup = true
                
                if let textInputContextState = textInputContextState {
                    if textInputContextState.1.contains(.swapEmoji), value.inputInFocus {
                        let stringRange = textInputContextState.0
                        let range = NSRange(string: input.inputText, range: stringRange)
                        if !input.isAnimatedEmoji(at: range) {
                            let query = String(input.inputText[stringRange])
                            let signal = InputSwapSuggestionsPanelItems(query, peerId: chatInteraction.peerId, context: chatInteraction.context)
                            |> deliverOnMainQueue
                            self.inputSwapDisposable.set(signal.start(next: { [weak self] files in
                                if let chatInteraction = self?.chatInteraction {
                                    self?.genericView.updateTextInputSuggestions(files, chatInteraction: chatInteraction, range: range, animated: animated)
                                }
                            }))
                            cleanup = false
                        }
                    }
                }
                if cleanup {
                    self.genericView.updateTextInputSuggestions([], chatInteraction: chatInteraction, range: NSMakeRange(0, 0), animated: animated)
                    self.inputSwapDisposable.set(nil)
                }
            }
            
        }
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        genericView.updateLayout(size: frame.size, transition: transition)
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
        
        genericView.inputContextHelper = .init(chatInteraction: chatInteraction, hasSeparator: false)
        
        genericView.inputContextHelper.didScroll = { [weak self] in
            self?.genericView.updateTextInputSuggestions([], chatInteraction: chatInteraction, range: NSMakeRange(0, 0), animated: true)
        }
        
        let openChat:(PeerId, MessageId?, ChatInitialAction?)->Void = { [weak self] peerId, messageId, initial in
            
            let open:()->Void = { [weak self] in
                let controller = context.bindings.rootNavigation().controller as? ChatController
                if controller?.chatLocation.peerId != peerId {
                    context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(peerId), focusTarget: .init(messageId: messageId), initialAction: initial))
                } else {
                    if let target = ChatFocusTarget(messageId: messageId) {
                        controller?.chatInteraction.focusMessageId(nil, target, .CenterEmpty)
                    }
                }
                self?.close()
            }
            
            if let messageId = messageId {
                let _ = ((context.engine.messages.getMessagesLoadIfNecessary([messageId], strategy: .cloud(skipLocal: false))
                          |> mapToSignal { result -> Signal<Message?, GetMessagesError> in
                              if case let .result(messages) = result {
                                  return .single(messages.first)
                              } else {
                                  return .never()
                              }
                          })
                          |> deliverOnMainQueue).startStandalone(next: { message in
                              if let _ = message {
                                  open()
                              } else {
                                  showModalText(for: context.window, text: strings().chatOpenMessageNotExist)
                              }
                          })
            } else {
                open()
            }
        }
        
        let openPeerInfo:(PeerId, NSView?)->Void = { [weak self] peerId, view in
            if peerId != context.peerId {
                
                let openforce:()->Void = {
                    let controller = context.bindings.rootNavigation().controller as? PeerInfoController

                    if controller?.peerId != peerId {
                        PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: peerId)
                    }
                    self?.close()
                    closeAllModals(window: context.window)
                }
                
                if let view = view, let event = NSApp.currentEvent {
                    
                    let data = context.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
                        TelegramEngine.EngineData.Item.Peer.AboutText(id: peerId)
                    ) |> take(1) |> deliverOnMainQueue
                    
                    _ = data.start(next: { [weak view] data in
                        
                        guard let peer = data.0, let view = view else {
                            return
                        }
                        
                        var firstBlock:[ContextMenuItem] = []
                        var secondBlock:[ContextMenuItem] = []
                        let thirdBlock: [ContextMenuItem] = []
                        
                        firstBlock.append(GroupCallAvatarMenuItem(peer._asPeer(), context: context))
                        
                        firstBlock.append(ContextMenuItem(peer._asPeer().displayTitle, handler: {
                            openforce()
                        }, itemImage: MenuAnimation.menu_open_profile.value))
                        
                        if let username = peer.addressName {
                            firstBlock.append(ContextMenuItem("\(username)", handler: {
                                openforce()
                            }, itemImage: MenuAnimation.menu_atsign.value))
                        }
                        
                        switch data.1 {
                        case let .known(about):
                            if let about = about, !about.isEmpty {
                                firstBlock.append(ContextMenuItem(about, handler: {
                                    openforce()
                                }, itemImage: MenuAnimation.menu_bio.value, removeTail: false, overrideWidth: 200))
                            }
                        default:
                            break
                        }
                        
                        let chatText = peer._asPeer().isChannel ? strings().storyAvatarContextOpenChannel : strings().storyAvatarContextSendMessage
                        
                        secondBlock.append(ContextMenuItem(chatText, handler: {
                            openChat(peerId, nil, nil)
                        }, itemImage: MenuAnimation.menu_read.value))
                        
                        let blocks:[[ContextMenuItem]] = [firstBlock,
                                                          secondBlock,
                                                          thirdBlock].filter { !$0.isEmpty }
                        var items: [ContextMenuItem] = []

                        for (i, block) in blocks.enumerated() {
                            if i != 0 {
                                items.append(ContextSeparatorItem())
                            }
                            items.append(contentsOf: block)
                        }
                        
                        let menu = ContextMenu(presentation: AppMenu.Presentation(colors: darkAppearance.colors))
                        
                        for item in items {
                            menu.addItem(item)
                        }
                        AppMenu.show(menu: menu, event: event, for: view)
                    })
                } else {
                    openforce()
                }
            } else {
                StoryMediaController.push(context: context, peerId: context.peerId, listContext: PeerStoryListContext(account: context.account, peerId: context.peerId, isArchived: false, folderId: nil), standalone: true)
                self?.close()
            }
        }
        
        let copyLink:(StoryContentItem)->Void = { [weak self] story in
            if let peerId = story.peerId, story.sharable {
                let signal = showModalProgress(signal: context.engine.messages.exportStoryLink(peerId: peerId, id: story.storyItem.id), for: context.window)
                
                _ = signal.start(next: { link in
                    if let link = link {
                        copyToClipboard(link)
                        self?.genericView.showTooltip(.linkCopied)
                    }
                })
            }
        }
        
        let repost:(StoryContentItem)->Void = { story in
            showModal(with: StoryPrivacyModalController(context: context, presentation: darkAppearance, reason: .share(story)), for: context.window)
        }

        let share:(StoryContentItem)->Void = { [weak self] story in
            if let peerId = story.peerId, story.sharable {
                let media = TelegramMediaStory(storyId: .init(peerId: peerId, id: story.storyItem.id), isMention: false)
                
                let additionTopItems: ShareAdditionItems = .init(items: [.init(peer: TelegramStoryRepostPeerObject(), status: strings().storyRepostToMy)], topSeparator: "", bottomSeparator: "", selectable: false)
                
                showModal(with: ShareModalController(ShareStoryObject(context, media: media, hasLink: story.canCopyLink, storyId: .init(peerId: peerId, id: story.storyItem.id), additionTopItems: additionTopItems, repostAction: {
                    repost(story)
                }), presentation: darkAppearance), for: context.window)
            } else {
                self?.genericView.showShareError()
            }
        }
        
        let statisticsStory:(StoryContentItem)->Void = { [weak self] story in
            if let peer = story.peer {
                context.bindings.rootNavigation().push(MessageStatsController(context, subject: .story(story.storyItem, peer)))
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
        
        let canAvoidGroupRestrictions:()->Bool = { [weak self] in
            return self?.genericView.storyContext?.stateValue?.slice?.additionalPeerData.canAvoidRestrictions == true
        }
        
        
        
        let sendText: (ChatTextInputState, PeerId, Int32, StoryViewController.TooptipView.Source)->Void = { [weak self, weak interactions] input, peerId, id, source in
            
            
            let locked = interactions?.presentation.lock ?? true
            
            if locked {
                return
            }
            
            if let timeout = self?.arguments?.interaction.presentation.slowMode?.timeout {
                self?.genericView.showTooltip(.tooltip(slowModeTooltipText(timeout), MenuAnimation.menu_clear_history))
                return
            }
            
            let slice = self?.genericView.storyContext?.stateValue?.slice
            
            let restrictionText = permissionText(from: self?.genericView.storyContext?.stateValue?.slice?.peer._asPeer(), for: .banSendText)
            
            if let restrictionText, !canAvoidGroupRestrictions() {
                self?.genericView.showTooltip(.tooltip(restrictionText, MenuAnimation.menu_clear_history))
                return
            }
            
            let invoke:()->Void = {
                beforeCompletion()
                _ = Sender.enqueue(input: input, context: context, peerId: peerId, replyId: nil, threadId: nil, replyStoryId: .init(peerId: peerId, id: id), sendAsPeerId: nil, sendPaidMessageStars: slice?.additionalPeerData.paidMessage).start(completed: {
                    afterCompletion()
                    self?.interactions.updateInput(with: "", resetFocus: true)
                    self?.genericView.showTooltip(source)
                })
            }
            
            guard let self else {
                return
            }
            
            let presentation = self.chatInteraction.presentation
            
            if let payStars = presentation.sendPaidMessageStars, let peer = presentation.peer, let starsState = presentation.starsState {
                let starsPrice = Int(payStars.value )
                let amount = strings().starListItemCountCountable(starsPrice)
                let messagesCount = 1
                
                if !presentation.alwaysPaidMessage {
                    
                    let messageCountText = strings().chatPayStarsConfirmMessagesCountable(messagesCount)
                    
                    verifyAlert(for: chatInteraction.context.window, header: strings().chatPayStarsConfirmTitle, information: strings().chatPayStarsConfirmText(peer.displayTitle, amount, amount, messageCountText), ok: strings().chatPayStarsConfirmPayCountable(messagesCount), option: strings().chatPayStarsConfirmCheckbox, optionIsSelected: false, successHandler: { result in
                        
                        if starsState.balance.value > starsPrice {
                            chatInteraction.update({ current in
                                return current
                                    .withUpdatedAlwaysPaidMessage(result == .thrid)
                            })
                            if result == .thrid {
                                FastSettings.toggleCofirmPaid(peer.id, price: starsPrice)
                            }
                            invoke()
                        } else {
                            showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: Int64(starsPrice))), for: context.window)
                        }
                    })
                    
                } else {
                    if starsState.balance.value > starsPrice {
                        invoke()
                    } else {
                        showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: Int64(starsPrice))), for: context.window)
                    }
                }
            } else {
                invoke()
            }
            
        }
        

        
        let toggleHide:(Peer, Bool)->Void = { [weak self] peer, value in
            context.engine.peers.updatePeerStoriesHidden(id: peer.id, isHidden: value)
            let text: String
            if !value {
                text = strings().storyTooltipUnarchive(peer.compactDisplayTitle)
            } else {
                text = strings().storyTooltipArchive(peer.compactDisplayTitle)
            }
            self?.genericView.showTooltip(.justText(text))
        }
        
        let saveGalleryPremium:()->Void = { [weak self] in
            self?.genericView.showTooltip(.tooltip(strings().storyTooltipSaveToGalleryPremium, MenuAnimation.menu_save_as))
        }
        
        let enableStealth:()->Void = { [weak self] in
            _ = context.engine.messages.enableStoryStealthMode().start()
            self?.genericView.showTooltip(.tooltip(strings().storyTooltipStealthModeActivate("5", "25"), MenuAnimation.menu_eye_slash))
        }
        let activeStealthMode:()->Void = { [weak self] in
            if let timestamp = self?.interactions.presentation.stealthMode.activeUntilTimestamp {
                self?.genericView.showTooltip(.tooltip(strings().storyTooltipStealthModeActive(smartTimeleftText(Int(timestamp - context.timestamp))), MenuAnimation.menu_eye_slash))
            }
        }
        
        let activateMediaArea:(MediaArea)->Void = { [weak self] area in
            self?.arguments?.interaction.activateArea()
            self?.genericView.current?.showMediaAreaViewer(area)
        }
        
        let deactivateMediaArea:(MediaArea)->Void = { [weak self] area in
            self?.arguments?.interaction.deactivateArea()
            self?.genericView.current?.hideMediaAreaViewer()
        }
        
        let like:(StoryReactionAction)->Void = { [weak self] reaction in
            switch reaction.item {
            case .builtin:
                self?.genericView.like(reaction)
            case let .custom(_, file):
                if let file = file, file.isPremiumEmoji, !context.isPremium {
                    showModalText(for: context.window, text: strings().emojiPackPremiumAlert, callback: { _ in
                        prem(with: PremiumBoardingController(context: context, source: .premium_stickers, presentation: darkAppearance), for: context.window)
                    })
                } else {
                    self?.genericView.like(reaction)
                }
            case .stars:
                break
            }
        }

        let react:(StoryReactionAction)->Void = { [weak self, weak interactions] reaction in
            
            if let entryId = interactions?.presentation.entryId, let id = interactions?.presentation.storyId {
                switch reaction.item {
                case let .builtin(value):
                    sendText(.init(inputText: value.normalizedEmoji), entryId, id, .reaction(reaction))
                    self?.genericView.playReaction(reaction)
                case let .custom(fileId, file):
                    if let file = file, let text = file.customEmojiText {
                        if file.isPremiumEmoji, !context.isPremium {
                            showModalText(for: context.window, text: strings().emojiPackPremiumAlert, callback: { _ in
                                prem(with: PremiumBoardingController(context: context, source: .premium_stickers, presentation: darkAppearance), for: context.window)
                            })
                        } else {
                            sendText(.init(inputText: text, selectionRange: 0..<0, attributes: [.animated(0..<text.length, text, fileId, file, nil)]), entryId, id, .reaction(reaction))
                            self?.genericView.playReaction(reaction)
                        }
                    }
                case .stars:
                    break
                }
            }
        }
        
        let deleteStory:(StoryContentItem)->Void = { [weak self] story in
            verifyAlert_button(for: context.window, information: strings().storyConfirmDelete, ok: strings().modalDelete, successHandler: { _ in
                if let stateValue = self?.stories.stateValue, let slice = stateValue.slice {
                    if slice.nextItemId != nil {
                        self?.stories.navigate(navigation: .item(.next))
                    } else if slice.previousItemId != nil {
                        self?.stories.navigate(navigation: .item(.previous))
                    } else {
                        self?.close()
                    }
                    _ = context.engine.messages.deleteStories(peerId: slice.peer.id, ids: [slice.item.storyItem.id]).start()
                }
            }, presentation: darkAppearance)
        }
        
        self.chatInteraction.add(observer: self)
        interactions.add(observer: self)
        
        let arguments = StoryArguments(context: context, interaction: self.interactions, chatInteraction: chatInteraction, showEmojiPanel: { [weak self] control in
            if let panel = self?.entertainment {
                showPopover(for: control, with: panel, edge: .maxX, inset:NSMakePoint(0 + 38, 10), delayBeforeShown: 0)
            }
        }, showReactionsPanel: { [weak self, weak interactions] in
            if let entryId = interactions?.presentation.entryId {
                _ = storyReactions(context: context, peerId: entryId, react: react, onClose: {
                    self?.genericView.closeReactions()
                }).start(next: { view in
                    if let view = view {
                        self?.genericView.showReactions(view)
                    }
                })
            }
        }, react: react, likeAction: like, attachPhotoOrVideo: { type in
            chatInteraction.attachPhotoOrVideo(type)
        }, attachFile: {
            chatInteraction.attachFile(false)
        }, nextStory: { [weak self] in
            self?.next()
        }, prevStory: { [weak self] in
            self?.previous()
        }, close: { [weak self] in
            self?.close()
        }, openPeerInfo: { peerId, view in
            openPeerInfo(peerId, view)
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
        }, deleteStory: deleteStory, markAsRead: { [weak self] peerId, storyId in
            self?.stories.markAsSeen(id: .init(peerId: peerId, id: storyId))
        }, showViewers: { [weak self] story in
            if story.storyItem.views?.seenCount == 0 {
                self?.genericView.showTooltip(.tooltip(strings().storyAlertNoViews, MenuAnimation.menu_clear_history))
            } else {
                if let peerId = story.peer?.id {
                    if let list = self?.genericView.storyViewList {
                        showModal(with: StoryViewersModalController(context: context, list: list, peerId: peerId, isChannel: story.peer?._asPeer().isChannel == true, story: story.storyItem, presentation: darkAppearance, callback: { peerId in
                            openPeerInfo(peerId, nil)
                        }), for: context.window)
                    }
                }
            }
            
        }, share: share, repost: { story in
            repost(story)
        }, copyLink: copyLink, startRecording: { [weak self] autohold in
            guard let `self` = self else {
                return
            }
            if self.context.peerId == self.interactions.presentation.entryId {
                return
            }
            if !self.interactions.presentation.canRecordVoice {
                self.genericView.showVoiceError()
            } else {
                self.interactions.startRecording(context: context, autohold: autohold, sendMedia: self.chatInteraction.sendMedia)
            }
        }, togglePinned: { [weak self] story in
            if let peerId = story.peerId, let peer = story.peer {
                _ = context.engine.messages.updateStoriesArePinned(peerId: peerId, ids: [story.storyItem.id : story.storyItem], isPinned: !story.storyItem.isPinned).start()
                
                self?.genericView.showTooltip(story.storyItem.isPinned ? .removedFromProfile(peer._asPeer()) : .addedToProfile(peer._asPeer()))
            }
        }, hashtag: { string in
            showModal(with: StoryFoundListController(context: context, source: .hashtag(nil, string), presentation: darkAppearance), for: context.window)
        },
        toggleHide: toggleHide,
        showFriendsTooltip: { [weak self] _, story in
            guard let peer = story.peer?._asPeer() else {
                return
            }
            let text: String
            let icon: MenuAnimation
            if story.storyItem.isCloseFriends {
                text = strings().storyTooltipCloseFriends(peer.compactDisplayTitle)
                icon = MenuAnimation.menu_add_to_favorites
            } else if story.storyItem.isContacts {
                text = strings().storyTooltipContacts(peer.compactDisplayTitle)
                icon = MenuAnimation.menu_create_group
            } else {
                icon = MenuAnimation.menu_create_group
                text = strings().storyTooltipSelectedContacts(peer.compactDisplayTitle)
            }
            self?.genericView.showTooltip(.tooltip(text, icon))
        }, showTooltipText: { [weak self] text, animation in
            self?.genericView.showTooltip(.tooltip(text, animation))
        }, storyContextMenu: { [weak self] story in
            guard let peer = story.peer else {
                return nil
            }
            let menu = ContextMenu(presentation: .current(darkAppearance.colors))

            if peer.id != context.peerId {
                let stealthModeState = self?.arguments?.interaction.presentation.stealthMode
                
                let peerId = peer.id
                
                if story.canCopyLink {
                    menu.addItem(ContextMenuItem(strings().storyControlsMenuCopyLink, handler: {
                        copyLink(story)
                    }, itemImage: MenuAnimation.menu_copy_link.value))
                }
                if story.sharable && !story.storyItem.isForwardingDisabled {
                    menu.addItem(ContextMenuItem(strings().storyControlsMenuShare, handler: {
                        share(story)
                    }, itemImage: MenuAnimation.menu_share.value))
                }
                
                if self?.arguments?.interaction.presentation.canViewStats == true {
                    menu.addItem(ContextMenuItem(strings().storyControlsMenuStatistics, handler: {
                        statisticsStory(story)
                    }, itemImage: MenuAnimation.menu_statistics.value))
                }
                
                if let presentaion = self?.arguments?.interaction.presentation {
                    if context.isPremium {
                        
                        let hq = self?.genericView.storyContext?.stateValue?.slice?.additionalPeerData.preferHighQualityStories ?? false
                        
                        menu.addItem(ContextMenuItem.init(hq ? strings().storyContextLowerQuality : strings().storyContextIncreaseQuality, handler: {
                            
                            _ = updateBaseAppSettingsInteractively(accountManager: context.sharedContext.accountManager, {
                                $0.withUpdatedStoriesQuaility(!hq)
                            }).startStandalone()
                            
                            let title: String
                            let text: String
                            if hq {
                                title = strings().storyContextLowerQualityTooltipTitle
                                text = strings().storyContextLowerQualityTooltipText
                            } else {
                                title = strings().storyContextIncreaseQualityTooltipTitle
                                text = strings().storyContextIncreaseQualityTooltipText
                            }
                            showModalText(for: context.window, text: text, title: title)
                        }, itemImage: hq ? MenuAnimation.menu_sd.value : MenuAnimation.menu_hd.value))
                    } else {
                        menu.addItem(ContextMenuItem(strings().storyContextIncreaseQuality, handler: {
                            prem(with: PremiumBoardingController(context: context, source: .stories_quality, openFeatures: true, presentation: darkAppearance), for: context.window)
                        }, itemImage: MenuAnimation.menu_hd_lock.value))
                    }
                }
                
                if !story.storyItem.isForwardingDisabled {
                    let resource: TelegramMediaFile?
                    if let media = story.storyItem.media._asMedia() as? TelegramMediaImage {
                        if let res = media.representations.last?.resource {
                            resource = .init(fileId: .init(namespace: 0, id: 0), partialReference: nil, resource: res, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "image/jpeg", size: nil, attributes: [.FileName(fileName: "Story \(stringForFullDate(timestamp: story.storyItem.timestamp)).jpeg")], alternativeRepresentations: [])
                        } else {
                            resource = nil
                        }
                        
                    } else if let media = story.storyItem.media._asMedia() as? TelegramMediaFile {
                        resource = media
                    } else {
                        resource = nil
                    }
                    
                    
                    if let resource = resource {
                        menu.addItem(ContextMenuItem(strings().storyMyInputSaveMedia, handler: {
                            if context.isPremium {
                                saveAs(resource, account: context.account)
                            } else {
                                saveGalleryPremium()
                            }
                        }, itemImage: MenuAnimation.menu_save_as.value))
                    }
                }
                if !peer.isService {
                    
                    if let peer = peer._asPeer() as? TelegramChannel, peer.hasPermission(.postStories) {
                        if !story.storyItem.isPinned {
                            menu.addItem(ContextMenuItem(strings().storyChannelInputSaveToProfile, handler: {
                                self?.arguments?.togglePinned(story)
                            }, itemImage: MenuAnimation.menu_save_to_profile.value))
                        } else {
                            menu.addItem(ContextMenuItem(strings().storyChannelInputRemoveFromProfile, handler: {
                                self?.arguments?.togglePinned(story)
                            }, itemImage: MenuAnimation.menu_clear_history.value))
                        }
                    }
                    
                    menu.addItem(ContextMenuItem(strings().storyControlsMenuStealtMode, handler: {
                        if stealthModeState?.activeUntilTimestamp != nil {
                            activeStealthMode()
                        } else {
                            showModal(with: StoryStealthModeController(context, enableStealth: enableStealth, presentation: darkAppearance), for: context.window)
                        }
                    }, itemImage: MenuAnimation.menu_eye_slash.value))
                    
                    if peer._asPeer().storyArchived {
                        menu.addItem(ContextMenuItem(strings().storyControlsMenuUnarchive, handler: {             toggleHide(peer._asPeer(), false)
                        }, itemImage: MenuAnimation.menu_unarchive.value))

                    } else {
                        menu.addItem(ContextMenuItem(strings().storyControlsMenuArchive, handler: {
                            toggleHide(peer._asPeer(), true)
                        }, itemImage: MenuAnimation.menu_archive.value))
                    }
                    if let peer = peer._asPeer() as? TelegramChannel, peer.hasPermission(.deleteStories) || story.storyItem.isMy {
                        menu.addItem(ContextSeparatorItem())
                        menu.addItem(ContextMenuItem(strings().messageContextDelete, handler: {
                            deleteStory(story)
                        }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                    } else {
                        let reportItem = ContextMenuItem(strings().storyControlsMenuReport, handler: {
                            reportComplicated(context: context, subject: .stories(peer.id, [story.storyItem.id]), title: strings().reportComplicatedStoryTitle)
                        }, itemImage: MenuAnimation.menu_report.value)
                        
                        menu.addItem(reportItem)
                    }
                }
            } else {
                if !story.storyItem.isPinned {
                    menu.addItem(ContextMenuItem(strings().storyMyInputSaveToProfile, handler: {
                        self?.arguments?.togglePinned(story)
                    }, itemImage: MenuAnimation.menu_save_to_profile.value))
                } else {
                    menu.addItem(ContextMenuItem(strings().storyMyInputRemoveFromProfile, handler: {
                        self?.arguments?.togglePinned(story)
                    }, itemImage: MenuAnimation.menu_clear_history.value))
                }
                let resource: TelegramMediaFile?
                if let media = story.storyItem.media._asMedia() as? TelegramMediaImage {
                    if let res = media.representations.last?.resource {
                        resource = .init(fileId: .init(namespace: 0, id: 0), partialReference: nil, resource: res, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "image/jpeg", size: nil, attributes: [.FileName(fileName: "My Story \(stringForFullDate(timestamp: story.storyItem.timestamp)).jpeg")], alternativeRepresentations: [])
                    } else {
                        resource = nil
                    }
                    
                } else if let media = story.storyItem.media._asMedia() as? TelegramMediaFile {
                    resource = media
                } else {
                    resource = nil
                }
                
                if let resource = resource {
                    menu.addItem(ContextMenuItem(strings().storyMyInputSaveMedia, handler: {
                        saveAs(resource, account: context.account)
                    }, itemImage: MenuAnimation.menu_save_as.value))
                }
                
                if story.sharable {
                    if !story.storyItem.isForwardingDisabled {
                        menu.addItem(ContextMenuItem(strings().storyMyInputShare, handler: {
                            self?.arguments?.share(story)
                        }, itemImage: MenuAnimation.menu_share.value))
                    }
                    
                    if story.canCopyLink {
                        menu.addItem(ContextMenuItem(strings().storyMyInputCopyLink, handler: {
                            self?.arguments?.copyLink(story)
                        }, itemImage: MenuAnimation.menu_copy_link.value))
                    }
                }
            }
           
            return menu
        }, activateMediaArea: { area in
            activateMediaArea(area)
        }, deactivateMediaArea: { area in
            deactivateMediaArea(area)
        }, invokeMediaArea: { [weak self] area in
            switch area {
            case let .venue(_, venue):
                showModal(with: StoryFoundListController(context: context, source: .mediaArea(area), presentation: darkAppearance), for: context.window)
            case let .channelMessage(_, messageId):
                openChat(messageId.peerId, messageId, nil)
            case let .link(_, url):
                let link = inApp(for: url.nsstring, context: context, openInfo: { peerId, toChat, messageId, initialAction in
                    if toChat {
                        openChat(peerId, messageId, initialAction)
                    } else {
                        openPeerInfo(peerId, nil)
                    }
                })
                let previous = context.bindings.rootNavigation().controller

                execute(inapp: link, afterComplete: { [weak self, weak previous] _ in
                    let current = context.bindings.rootNavigation().controller
                    if current != previous {
                        self?.close()
                    }
                })
            default:
                break
            }
        }, like: { current, state in
            guard let peerId = state.entryId, let story = state.storyId else {
                return
            }
            _ = context.engine.messages.setStoryReaction(peerId: peerId, id: story, reaction: current).start()
        }, showLikePanel: { [weak self, weak interactions] control, story in
            if let entryId = interactions?.presentation.entryId {
                
                var selectedItems: [EmojiesSectionRowItem.SelectedItem] = []
                if let reaction = story.storyItem.myReaction {
                    switch reaction {
                    case let .builtin(emoji):
                        selectedItems.append(.init(source: .builtin(emoji), type: .transparent))
                    case let .custom(fileId):
                        selectedItems.append(.init(source: .custom(fileId), type: .transparent))
                    case .stars:
                        break
                    }
                }
                _ = storyReactions(context: context, peerId: entryId, react: like, onClose: {
                    self?.genericView.closeLikePanel()
                }, selectedItems: selectedItems).start(next: { view in
                    if let view = view {
                        self?.genericView.showLikePanel(view, control: control)
                    }
                })
            }
        }, setupPrivacy: { story in
            showModal(with: StoryPrivacyModalController(context: context, presentation: darkAppearance, reason: .settings(story)), for: context.window)
        }, loadForward: { [weak self] storyId in
            guard let state = self?.genericView.storyContext?.stateValue else {
                return Promise(nil)
            }
            if let promise = state.slice?.forwardInfoStories[storyId] {
                return promise
            } else {
                return .init(nil)
            }
        }, openStory: { storyId in
            StoryModalController.ShowSingleStory(context: context, storyId: storyId, initialId: nil)
        })
        

        
        self.arguments = arguments
        
        genericView.setArguments(arguments)
        interactions.add(observer: self.genericView)
        
        entertainment.update(with: chatInteraction)
        
        chatInteraction.sendAppFile = { [weak self] file, _, _, _, _ in
            guard let interactions = self?.interactions else {
                return
            }
            
            if let timeout = self?.arguments?.interaction.presentation.slowMode?.timeout {
                self?.genericView.showTooltip(.tooltip(slowModeTooltipText(timeout), MenuAnimation.menu_clear_history))
                return
            }
            
            let slice = self?.genericView.storyContext?.stateValue?.slice
            
            let restrictionText = permissionText(from: self?.genericView.storyContext?.stateValue?.slice?.peer._asPeer(), for: .banSendFiles)
            
            if let restrictionText, !canAvoidGroupRestrictions() {
                self?.genericView.showTooltip(.tooltip(restrictionText, MenuAnimation.menu_clear_history))
                return
            }
            
            let invoke:()->Void = {
                if let peerId = interactions.presentation.entryId, let id = interactions.presentation.storyId {
                    beforeCompletion()
                    _ = Sender.enqueue(media: file, context: context, peerId: peerId, replyId: nil, threadId: nil, replyStoryId: .init(peerId: peerId, id: id), sendPaidMessageStars: slice?.additionalPeerData.paidMessage).start(completed: {
                        afterCompletion()
                        self?.genericView.showTooltip(.media([file]))
                    })
                }
            }
            
            guard let self else {
                return
            }
            
            let presentation = self.chatInteraction.presentation
            
            if let payStars = presentation.sendPaidMessageStars, let peer = presentation.peer, let starsState = presentation.starsState {
                let starsPrice = Int(payStars.value )
                let amount = strings().starListItemCountCountable(starsPrice)
                let messagesCount = 1
                
                if !presentation.alwaysPaidMessage {
                    
                    let messageCountText = strings().chatPayStarsConfirmMessagesCountable(messagesCount)
                    
                    verifyAlert(for: chatInteraction.context.window, header: strings().chatPayStarsConfirmTitle, information: strings().chatPayStarsConfirmText(peer.displayTitle, amount, amount, messageCountText), ok: strings().chatPayStarsConfirmPayCountable(messagesCount), option: strings().chatPayStarsConfirmCheckbox, optionIsSelected: false, successHandler: { result in
                        
                        if starsState.balance.value > starsPrice {
                            chatInteraction.update({ current in
                                return current
                                    .withUpdatedAlwaysPaidMessage(result == .thrid)
                            })
                            if result == .thrid {
                                FastSettings.toggleCofirmPaid(peer.id, price: starsPrice)
                            }
                            invoke()
                        } else {
                            showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: Int64(starsPrice))), for: context.window)
                        }
                    })
                    
                } else {
                    if starsState.balance.value > starsPrice {
                        invoke()
                    } else {
                        showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: Int64(starsPrice))), for: context.window)
                    }
                }
            } else {
                invoke()
            }
            
        }
        chatInteraction.sendPlainText = { [weak self] text in
            _ = self?.interactions.appendText(.initialize(string: text))
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
                showModal(with: PreviewSenderController(urls: updated, chatInteraction: chatInteraction, asMedia: asMedia, attributedString: attributedString, presentation: darkAppearance), for: context.window)
            }
        }
        
        chatInteraction.sendMedias = { [weak self] medias, caption, isCollage, additionText, silent, atDate, isSpoiler, messageEffect, leadingText in
            guard let interactions = self?.interactions else {
                return
            }
            
            if let timeout = self?.arguments?.interaction.presentation.slowMode?.timeout {
                self?.genericView.showTooltip(.tooltip(slowModeTooltipText(timeout), MenuAnimation.menu_clear_history))
                return
            }
            
            let slice = self?.genericView.storyContext?.stateValue?.slice
            
            let restrictionText = permissionText(from: self?.genericView.storyContext?.stateValue?.slice?.peer._asPeer(), for: .banSendMedia)
            
            if let restrictionText, !canAvoidGroupRestrictions() {
                self?.genericView.showTooltip(.tooltip(restrictionText, MenuAnimation.menu_clear_history))
                return
            }
            
            if let peerId = interactions.presentation.entryId, let id = interactions.presentation.storyId {
                beforeCompletion()
                _ = Sender.enqueue(media: medias, caption: caption, context: context, peerId: peerId, replyId: nil, threadId: nil, replyStoryId: .init(peerId: peerId, id: id), isCollage: isCollage, additionText: additionText, silent: silent, atDate: atDate, isSpoiler: isSpoiler, messageEffect: messageEffect, leadingText: leadingText, sendPaidMessageStars: slice?.additionalPeerData.paidMessage).start(completed: {
                    afterCompletion()
                    self?.genericView.showTooltip(.media(medias))
                })
            }
        }
        
        chatInteraction.sendMedia = { [weak self] container in
            
            if let timeout = self?.arguments?.interaction.presentation.slowMode?.timeout {
                self?.genericView.showTooltip(.tooltip(slowModeTooltipText(timeout), MenuAnimation.menu_clear_history))
                return
            }
            
            let slice = self?.genericView.storyContext?.stateValue?.slice
            
            let restrictionText = permissionText(from: self?.genericView.storyContext?.stateValue?.slice?.peer._asPeer(), for: .banSendMedia)
            
            if let restrictionText, !canAvoidGroupRestrictions() {
                self?.genericView.showTooltip(.tooltip(restrictionText, MenuAnimation.menu_clear_history))
                return
            }
            
            let invoke:()->Void = {
                if let peerId = interactions.presentation.entryId, let id = interactions.presentation.storyId {
                    beforeCompletion()
                    _ = Sender.enqueue(media: container, context: context, peerId: peerId, replyId: nil, threadId: nil, replyStoryId: .init(peerId: peerId, id: id), sendPaidMessageStars: slice?.additionalPeerData.paidMessage).start(completed: {
                        afterCompletion()
                        self?.genericView.showTooltip(.media([]))
                    })
                }
            }
            
            
            guard let self else {
                return
            }
            
            let presentation = self.chatInteraction.presentation
            
            if let payStars = presentation.sendPaidMessageStars, let peer = presentation.peer, let starsState = presentation.starsState {
                let starsPrice = Int(payStars.value )
                let amount = strings().starListItemCountCountable(starsPrice)
                let messagesCount = 1
                
                if !presentation.alwaysPaidMessage {
                    
                    let messageCountText = strings().chatPayStarsConfirmMessagesCountable(messagesCount)
                    
                    verifyAlert(for: chatInteraction.context.window, header: strings().chatPayStarsConfirmTitle, information: strings().chatPayStarsConfirmText(peer.displayTitle, amount, amount, messageCountText), ok: strings().chatPayStarsConfirmPayCountable(messagesCount), option: strings().chatPayStarsConfirmCheckbox, optionIsSelected: false, successHandler: { result in
                        
                        if starsState.balance.value > starsPrice {
                            chatInteraction.update({ current in
                                return current
                                    .withUpdatedAlwaysPaidMessage(result == .thrid)
                            })
                            FastSettings.toggleCofirmPaid(peer.id, price: starsPrice)
                            invoke()
                        } else {
                            showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: Int64(starsPrice))), for: context.window)
                        }
                    })
                    
                } else {
                    if starsState.balance.value > starsPrice {
                        invoke()
                    } else {
                        showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: Int64(starsPrice))), for: context.window)
                    }
                }
            } else {
                invoke()
            }
        }
        
        chatInteraction.attachFile = { value in
            filePanel(canChooseDirectories: true, for: context.window, appearance: darkAppearance.appearance, completion:{ result in
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
            filePanel(with: exts, canChooseDirectories: true, for: context.window, appearance: darkAppearance.appearance, completion:{ result in
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

                
        let stealthData = context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Configuration.StoryConfigurationState()
        ) |> deliverOnMainQueue
        
        actionsDisposable.add(stealthData.start(next: { [weak self] data in
            self?.interactions.update({ current in
                var current = current
                current.stealthMode = data.stealthModeState
                return current
            })
        }))
        
        
        
        
        actionsDisposable.add(context.reactions.stateValue.start(next: { [weak self] reactions in
            self?.interactions.update({ current in
                var current = current
                current.reactions = reactions
                return current
            })
        }))
        
        actionsDisposable.add((context.starsContext.state |> deliverOnMainQueue).start(next: { [weak self] starsState in
            self?.chatInteraction.update({ current in
                return current.withUpdatedStarsState(starsState)
            })
        }))
        
        disposable.set(combineLatest(signal, genericView.getReady).start(next: { [weak self] state, ready in
            if state.slice == nil {
                self?.initialId = nil
                self?.close()
            } else if let stories = self?.stories {
                self?.genericView.update(context: context, storyContext: stories, initial: initialId)
                if ready {
                    self?.readyOnce()
                }
                if let chatInteraction = self?.chatInteraction {
                    chatInteraction.update({ current in
                        var current = current
                        current = current.updatedPeer { _ in
                            return state.slice?.peer._asPeer()
                        }
                        
                        if let slice = state.slice {
                            let paidMessge = state.slice?.additionalPeerData.paidMessage
                            current = current.withUpdatedSendPaidMessageStars(paidMessge).withUpdatedAlwaysPaidMessage(FastSettings.needConfirmPaid(slice.peer.id, price: Int(paidMessge?.value ?? 0)))
                        }
                        
                        if let slowmode = state.slice?.additionalPeerData.slowModeTimeout, state.slice?.additionalPeerData.canAvoidRestrictions == false {
                            let slowmodeValidUntilTimeout = state.slice?.additionalPeerData.slowModeValidUntilTimestamp
                            current = current.updateSlowMode({ value in
                                var value = value ?? SlowMode()
                                value = value.withUpdatedValidUntil(slowmodeValidUntilTimeout)
                                if let timeout = slowmodeValidUntilTimeout {
                                    if timeout > context.timestamp {
                                        value = value.withUpdatedTimeout(timeout - context.timestamp)
                                    } else {
                                        value = value.withUpdatedTimeout(nil)
                                    }
                                }
                                return value
                            })
                        } else {
                            current = current.updateSlowMode({ _ in
                                nil
                            })
                        }
                        return current
                    })
                    self?.entertainment.update(with: chatInteraction)
                }
            }
        }))
        
        
        self.overlayTimer = SwiftSignalKit.Timer(timeout: 30 / 1000, repeat: true, completion: { [weak self] in
            DispatchQueue.main.async {
                self?.interactions.update { current in
                    var current = current
                                        
                    current.hasMenu = contextMenuOnScreen(filterNames: ["volume"]) || NSApp.windows.contains(where: { ($0 as? Window)?.name == "reactions" })
                    current.hasModal = findModal(PreviewSenderController.self, isAboveTo: self) != nil
                    || findModal(InputDataModalController.self, isAboveTo: self) != nil
                    || findModal(ShareModalController.self, isAboveTo: self) != nil
                    || findModal(StoryStealthModeController.self, isAboveTo: self) != nil
                    || findModal(PremiumBoardingController.self, isAboveTo: self) != nil
                    || findModal(StoryModalController.self, isAboveTo: self) != nil
                    current.hasPopover = hasPopover(context.window) && !current.hasModal
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
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let context = self.context
        
        window?.set(handler: { [weak self] _ in
            if self?.isNotMainScreen == true {
                return .rejected
            }
            return self?.previous() ?? .invoked
        }, with: self, for: .LeftArrow, priority: .modal)
        
        window?.set(handler: { [weak self] _ in
            if self?.isNotMainScreen == true {
                return .rejected
            }
            if let story = self?.genericView.current?.story, story.peerId == context.peerId {
                if findModal(InputDataModalController.self) == nil {
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
            if self?.isNotMainScreen == true {
                return .rejected
            }
            if self?.genericView.isInputFocused == true || self?.interactions.presentation.input.inputText.isEmpty == true {
                self?.genericView.processGroupResult(.moveBack, animated: true)
            }
            return .invokeNext
        }, with: self, for: .DownArrow, priority: .modal)
        
        
        window?.set(handler: { [weak self] _ in
            if self?.isNotMainScreen == true {
                return .rejected
            }
            return self?.next() ?? .invoked
        }, with: self, for: .RightArrow, priority: .modal)
        
        window?.set(handler: { [weak self] _ in
            if self?.isNotMainScreen == true {
                return .rejected
            }
            return self?.delete() ?? .invoked
        }, with: self, for: .Delete, priority: .modal)
        
        
        var timer: SwiftSignalKit.Timer?
        var spaceIsLong = false
        
        window?.set(handler: { [weak self] _ in
            if self?.isNotMainScreen == true {
                return .rejected
            }
            guard self?.genericView.isInputFocused == false else {
                return .rejected
            }
            if self?.interactions.presentation.hasModal == true {
                return .rejected
            }
            if timer == nil {
                self?.interactions.update { current in
                    var current = current
                    if current.isPaused {
                        current.isSpacePaused = false
                    } else {
                        current.isSpacePaused = !current.isSpacePaused
                    }
                    return current
                }
                timer = .init(timeout: 0.35, repeat: false, completion: {
                    spaceIsLong = true
                }, queue: .mainQueue())
                
                timer?.start()
            }
            return .invoked
        }, with: self, for: .Space, priority: .modal)
        
        window?.keyUpHandler = { [weak self] event in
            if self?.isNotMainScreen == true {
                return
            }
            timer?.invalidate()
            timer = nil
            if spaceIsLong, self?.arguments?.interaction.presentation.isSpacePaused == true {
                self?.interactions.update { current in
                    var current = current
                    current.isSpacePaused = false
                    return current
                }
            }
            spaceIsLong = false
        }
        
        
        window?.set(handler: { [weak self] _ in
            if self?.isNotMainScreen == true {
                return .rejected
            }
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
            if self?.isNotMainScreen == true {
                return .rejected
            }
            self?.genericView.zoomIn()
            return .invoked
        }, with: self, for: .Equal, priority: .modal, modifierFlags: [.command])
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            if self?.isNotMainScreen == true {
                return .rejected
            }
            self?.genericView.zoomOut()
            return .invoked
        }, with: self, for: .Minus, priority: .modal, modifierFlags: [.command])
        
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            if self?.isNotMainScreen == true {
                return .rejected
            }
            self?.genericView.inputTextView?.inputApplyTransform(.attribute(TextInputAttributes.bold))
            return .invoked
        }, with: self, for: .B, priority: .modal, modifierFlags: [.command])

        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            if self?.isNotMainScreen == true {
                return .rejected
            }
            self?.genericView.inputTextView?.inputApplyTransform(.attribute(TextInputAttributes.underline))
            return .invoked
        }, with: self, for: .U, priority: .modal, modifierFlags: [.shift, .command])
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            if self?.isNotMainScreen == true {
                return .rejected
            }
            self?.genericView.inputTextView?.inputApplyTransform(.attribute(TextInputAttributes.spoiler))
            return .invoked
        }, with: self, for: .P, priority: .modal, modifierFlags: [.shift, .command])
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            if self?.isNotMainScreen == true {
                return .rejected
            }
            self?.genericView.inputTextView?.inputApplyTransform(.attribute(TextInputAttributes.strikethrough))
            return .invoked
        }, with: self, for: .X, priority: .modal, modifierFlags: [.shift, .command])
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            if self?.isNotMainScreen == true {
                return .rejected
            }
            self?.genericView.inputTextView?.inputApplyTransform(.clear)
            return .invoked
        }, with: self, for: .Backslash, priority: .modal, modifierFlags: [.command])
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            if self?.isNotMainScreen == true {
                return .rejected
            }
            self?.genericView.inputTextView?.inputApplyTransform(.url)
            return .invoked
        }, with: self, for: .U, priority: .modal, modifierFlags: [.command])
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            if self?.isNotMainScreen == true {
                return .rejected
            }
            self?.genericView.inputTextView?.inputApplyTransform(.attribute(TextInputAttributes.italic))
            return .invoked
        }, with: self, for: .I, priority: .modal, modifierFlags: [.command])
        
    }
    
    private var isNotMainScreen: Bool {
        return interactions.presentation.hasModal || interactions.presentation.hasPopover || interactions.presentation.hasMenu
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeObserver(for: self)
        window?.keyUpHandler = nil
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        return .invokeNext
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
        } else if interactions.presentation.hasLikePanel {
            self.genericView.closeLikePanel()
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
        inputSwapDisposable.dispose()
        actionsDisposable.dispose()
        slowModeDisposable.dispose()
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
    
    override var shouldCloseAllTheSameModals: Bool {
        return false
    }

    override var isVisualEffectBackground: Bool {
        return true
    }
    
    static func ShowStories(context: AccountContext, isHidden: Bool, initialId: StoryInitialIndex?, singlePeer: Bool = false) {
        let storyContent = StoryContentContextImpl(context: context, isHidden: isHidden, focusedPeerId: initialId?.peerId, singlePeer: singlePeer)
        
        let signal = storyContent.state
        |> deliverOn(prepareQueue)
        |> take(1)
        |> mapToSignal { state -> Signal<StoryContentContextState, NoError> in
            if let slice = state.slice {
                return waitUntilStoryMediaPreloaded(context: context, peerId: slice.peer.id, storyItem: slice.item.storyItem)
                |> timeout(4.0, queue: .mainQueue(), alternate: .complete())
                |> map { _ -> StoryContentContextState in
                }
                |> then(.single(state))
            } else {
                return .single(state)
            }
        }
        |> deliverOnMainQueue
        |> map { state in
            if state.slice == nil {
                return
            }
            showModal(with: StoryModalController(context: context, stories: storyContent, initialId: initialId), for: context.window, animationType: .animateBackground)
        }
        |> afterDisposed {
            
        }
        |> ignoreValues
        
        if let setProgress = initialId?.setProgress {
            setProgress(signal)
        } else {
            _ = signal.start()
        }

    }
    static func ShowSingleStory(context: AccountContext, storyId: StoryId, initialId: StoryInitialIndex?, readGlobally: Bool = true, emptyCallback:(()->Void)? = nil) {
        
        var initialSignal: Signal<StoryId?, NoError> = context.account.postbox.transaction { transaction -> StoryId? in
            if let _ = transaction.getStory(id: storyId)?.get(Stories.StoredItem.self) {
                return storyId
            } else {
                return nil
            }
        } |> mapToSignal { id in
            if let _ = id {
                return .single(Optional(storyId))
            } else {
                return context.engine.messages.refreshStories(peerId: storyId.peerId, ids: [storyId.id])
                |> map { _ -> StoryId? in
                }
                |> then(.single(storyId))
            }
        }
        
                
        initialSignal = initialSignal |> mapToSignal { storyId in
            if let storyId = storyId {
                return context.account.postbox.transaction { transaction -> StoryId? in
                    if let _ = transaction.getStory(id: storyId)?.get(Stories.StoredItem.self) {
                        return storyId
                    } else {
                        return nil
                    }
                }
            } else {
                return .single(nil)
            }
        }
        
        
        _ = showModalProgress(signal: initialSignal, for: context.window).start(next: { storyId in
            if let storyId = storyId {
                let storyContent = SingleStoryContentContextImpl(context: context, storyId: storyId, readGlobally: readGlobally)
                let _ = (storyContent.state
                |> filter { $0.slice != nil }
                |> take(1)
                |> deliverOnMainQueue).start(next: { state in
                    showModal(with: StoryModalController(context: context, stories: storyContent, initialId: initialId), for: context.window, animationType: .animateBackground)
                })
            } else {
                emptyCallback?()
            }
        })
        
        
    }
    static func ShowListStory(context: AccountContext, listContext: StoryListContext, peerId: PeerId, initialId: StoryInitialIndex?) {
        let storyContent = PeerStoryListContentContextImpl(context: context, peerId: peerId, listContext: listContext, initialId: initialId?.id)
        let _ = (storyContent.state
        |> filter { $0.slice != nil }
        |> take(1)
        |> deliverOnMainQueue).start(next: { _ in
            showModal(with: StoryModalController(context: context, stories: storyContent, initialId: initialId), for: context.window, animationType: .animateBackground)
        
        })
    }
}


