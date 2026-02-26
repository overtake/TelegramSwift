//
//  PlayerListController.swift
//  Telegram
//
//  Created by keepcoder on 26/06/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import TelegramMedia
import Postbox
import SwiftSignalKit
import RangeSet

private final class PlayerListArguments {
    let chatInteraction: ChatInteraction
    let music:(Message, GalleryAppearType)->Void
    init(chatInteraction: ChatInteraction, music:@escaping(Message, GalleryAppearType)->Void) {
        self.chatInteraction = chatInteraction
        self.music = music
    }
}

private enum PlayerListEntry: TableItemListNodeEntry {
    static func < (lhs: PlayerListEntry, rhs: PlayerListEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    var index: MessageIndex {
        switch self {
        case let .message(_, message):
            return MessageIndex(message)
        }
    }
    
    case message(sectionId: Int32, Message)
    
    var stableId: ChatHistoryEntryId {
        switch self {
        case let .message(_, message):
            return .message(message)
        }
    }
    
    func item(_ arguments: PlayerListArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .message(_, message):
            return PeerMediaMusicRowItem(initialSize, arguments.chatInteraction, .messageEntry(message, [], .defaultSettings, .singleItem), isCompactPlayer: true, music: arguments.music)
        }
    }
    
    static func ==(lhs: PlayerListEntry, rhs: PlayerListEntry) -> Bool {
        switch lhs {
        case let .message(_, lhsMessage):
            if case let .message(_, rhsMessage) = rhs {
                return isEqualMessages(lhsMessage, rhsMessage)
            } else {
                return false
            }
        }
    }
}


private func playerAudioEntries(_ update: PeerMediaUpdate, timeDifference: TimeInterval) -> [PlayerListEntry] {
    var entries: [PlayerListEntry] = []
    var sectionId: Int32 = 0
    
    for message in update.messages {
        entries.append(.message(sectionId: sectionId, message))
    }
    
    return entries
}
fileprivate func preparedAudioListTransition(from fromView:[PlayerListEntry], to toView:[PlayerListEntry], initialSize:NSSize, arguments: PlayerListArguments, animated:Bool, scroll:TableScrollState) -> TableUpdateTransition {
    let (removed,inserted,updated) = proccessEntries(fromView, right: toView, { (entry) -> TableRowItem in
        
        return entry.item(arguments, initialSize: initialSize)
        
    })
    
    for item in inserted {
        _ = item.1.makeSize(initialSize.width, oldWidth: initialSize.width)
    }
    for item in updated {
        _ = item.1.makeSize(initialSize.width, oldWidth: initialSize.width)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated:updated, animated:animated, state:scroll)
}



private final class PlayerListTrackView: View {
    private let cover: TransformImageView = TransformImageView()
    private let trackName: TextView = TextView()
    let artistName: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(cover)
        addSubview(trackName)
        addSubview(artistName)
        
        trackName.userInteractionEnabled = false
        trackName.isSelectable = false
        
        artistName.isSelectable = false
        
        artistName.set(handler: { control in
            control.alphaValue = 1
        }, for: .Hover)
        
        artistName.set(handler: { control in
            control.alphaValue = 1
        }, for: .Normal)
        
        artistName.set(handler: { control in
            control.alphaValue = 0.8
        }, for: .Highlight)
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        trackName.background = theme.colors.background
        artistName.background = theme.colors.background
    }
    
    func update(_ item: APSongItem) {
        let trackLayout = TextViewLayout(.initialize(string: item.songName.isEmpty ? item.performerName : item.songName, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        
        let artistLayout = TextViewLayout(.initialize(string: item.performerName, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)

        trackName.update(trackLayout)
        artistName.update(artistLayout)
        
        let imageCorners = ImageCorners(topLeft: .Corner(4.0), topRight: .Corner(4.0), bottomLeft: .Corner(4.0), bottomRight: .Corner(4.0))
        let arguments = TransformImageArguments(corners: imageCorners, imageSize: PeerMediaIconSize, boundingSize: PeerMediaIconSize, intrinsicInsets: NSEdgeInsets())
        
        cover.layer?.contents = theme.icons.playerMusicPlaceholder
        cover.layer?.cornerRadius = .cornerRadius
        if let imageMediaReference = item.coverImageMediaReference {
            cover.setSignal(chatMessagePhotoThumbnail(account: item.account, imageReference: imageMediaReference))
        }
        cover.set(arguments: arguments)
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        cover.setFrameSize(PeerMediaIconSize)
        
        trackName.resize(frame.width - 60)
        artistName.resize(frame.width - 60)

        trackName.setFrameOrigin(NSMakePoint(50, 2))
        artistName.setFrameOrigin(NSMakePoint(50, frame.height - artistName.frame.height - 2))
        
        cover.centerY(x: 0)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class PlayerListHandlingView: View {
    fileprivate let playPause = Button()
    private let playPauseView = LottiePlayerView()
    fileprivate let prev = ImageButton()
    fileprivate let next = ImageButton()
    fileprivate let order = ImageButton()
    fileprivate let iteration = ImageButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(playPause)
        addSubview(prev)
        addSubview(next)
        addSubview(order)
        addSubview(iteration)
        playPause.addSubview(playPauseView)
        playPause.setFrameSize(NSMakeSize(40, 40))
        
        playPauseView.setFrameSize(playPause.frame.size)
        
        prev.autohighlight = false
        next.autohighlight = false
        playPause.autohighlight = false
        iteration.autohighlight = false
        order.autohighlight = false

        prev.scaleOnClick = true
        next.scaleOnClick = true
        playPause.scaleOnClick = true
        iteration.scaleOnClick = true
        order.scaleOnClick = true

        updateLocalizationAndTheme(theme: theme)

    }
    
    override func layout() {
        super.layout()
        playPause.centerX()
        playPause.centerY(addition: -1)
        prev.centerY(x: playPause.frame.minX - prev.frame.width - 10)
        next.centerY(x: playPause.frame.maxX + 10)
        iteration.centerY(x: frame.width - iteration.frame.width)
        order.centerY(x: 0)
    }
        
    func update(_ item: APSongItem, controller: APController, animated: Bool) {
        
        next.userInteractionEnabled = controller.nextEnabled
        prev.userInteractionEnabled = controller.prevEnabled

        switch controller.nextEnabled {
        case true:
            next.set(image: theme.icons.playlist_next, for: .Normal)
        case false:
            next.set(image: theme.icons.playlist_next_locked, for: .Normal)
        }
        
        switch controller.prevEnabled {
        case true:
            prev.set(image: theme.icons.playlist_prev, for: .Normal)
        case false:
            prev.set(image: theme.icons.playlist_prev_locked, for: .Normal)
        }
        
        switch controller.state.status {
        case .playing:
            play(animated: animated, sticker: LocalAnimatedSticker.playlist_play_pause)
        case .paused:
            play(animated: animated, sticker: LocalAnimatedSticker.playlist_pause_play)
        default:
            break
        }
        
        switch controller.state.orderState {
        case .normal:
            order.set(image: theme.icons.playlist_order_normal, for: .Normal)
        case .reversed:
            order.set(image: theme.icons.playlist_order_reversed, for: .Normal)
        case .random:
            order.set(image: theme.icons.playlist_order_random, for: .Normal)
        }
        
        switch controller.state.repeatState {
        case .none:
            iteration.set(image: theme.icons.playlist_repeat_none, for: .Normal)
        case .one:
            iteration.set(image: theme.icons.playlist_repeat_one, for: .Normal)
        case .circle:
            iteration.set(image: theme.icons.playlist_repeat_circle, for: .Normal)
        }
        order.sizeToFit()
        iteration.sizeToFit()
        next.sizeToFit()
        prev.sizeToFit()
        needsLayout = true
    }
    private func play(animated: Bool, sticker: LocalAnimatedSticker) {
        let data = sticker.data
        if let data = data {
            
            let current: Int32
            let total: Int32
            if playPauseView.animation?.key.key != LottieAnimationKey.bundle(sticker.rawValue) {
                current = playPauseView.currentFrame ?? 0
                total = playPauseView.totalFrames ?? 0
            } else {
                current = 0
                total = playPauseView.currentFrame ?? 0
            }
            let animation = LottieAnimation(compressed: data, key: .init(key: .bundle(sticker.rawValue), size: NSMakeSize(46, 46)), cachePurpose: .none, playPolicy: .toEnd(from: animated ? total - current : .max), colors: [.init(keyPath: "", color: theme.colors.text)], runOnQueue: .mainQueue())
            playPauseView.set(animation)
        }
    }
        
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)

    }
}

private final class PlayerListControlsView : View {
    private let separator: View = View()
    fileprivate var trackView: PlayerListTrackView?
    fileprivate let progress: LinearProgressControl = LinearProgressControl(progressHeight: 5)
    private let playedView: TextView = TextView()
    private let restView: TextView = TextView()
    fileprivate let handlings: PlayerListHandlingView = PlayerListHandlingView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(progress)
        addSubview(playedView)
        addSubview(restView)
        addSubview(handlings)
        addSubview(separator)
        updateLocalizationAndTheme(theme: theme)
        separator.layer?.opacity = 0
        
    }
    
    var searchClick:((String)->Void)? = nil
    
    private var track: APSongItem?
    
    func update(_ track: APSongItem, controller: APController, animated: Bool) {
        if track != self.track {
            if let current = self.trackView {
                self.trackView = nil
                if animated {
                    current.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak current] _ in
                        current?.removeFromSuperview()
                    })
                } else {
                    current.removeFromSuperview()
                }
            }
            let trackView = PlayerListTrackView(frame: NSMakeRect(10, 10, frame.width - 20, 40))
            self.trackView = trackView
            addSubview(trackView)
            trackView.update(track)
            let trackName = track.performerName
            
            trackView.artistName.set(handler: { [weak self] _ in
                self?.searchClick?(trackName)
            }, for: .Click)
            
            if animated {
                trackView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
        }
        
        self.track = track
        
        var played: Int? = nil
        var rest: Int? = nil

        handlings.update(track, controller: controller, animated: animated)
        
        switch track.state {
        case .waiting:
            break
        case .stoped:
            self.progress.set(progress: 0, animated: animated)
        case let .playing(current, duration, progress), let .paused(current, duration, progress):
            self.progress.set(progress: CGFloat(progress == .nan ? 0 : progress), animated: animated, duration: 0.2)
            played = Int(current)
            rest = Int(duration - current)
        case let .fetching(progress):
            self.progress.set(progress: CGFloat(progress), animated: animated)
        }
        
        if let played = played, let rest = rest {
            let playedLayout = TextViewLayout.init(.initialize(string: timerText(played), color: theme.colors.grayText, font: .normal(.short)))
            let restLayout = TextViewLayout.init(.initialize(string: timerText(rest), color: theme.colors.grayText, font: .normal(.short)))

            playedLayout.measure(width: .greatestFiniteMagnitude)
            restLayout.measure(width: .greatestFiniteMagnitude)
            
            self.playedView.update(playedLayout)
            self.restView.update(restLayout)
        }
        needsLayout = true
    }
    

    
    override func layout() {
        separator.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
        trackView?.frame = NSMakeRect(10, 10, frame.width - 20, 40)
        progress.frame = NSMakeRect(10, 60, frame.width - 20, 12)
        
        playedView.setFrameOrigin(NSMakePoint(progress.frame.minX, progress.frame.maxY + 3))
        restView.setFrameOrigin(NSMakePoint(progress.frame.maxX - restView.frame.width, progress.frame.maxY + 3))
        
        handlings.frame = NSMakeRect(10, restView.frame.maxY, frame.width - 20, 40)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = theme as! TelegramPresentationTheme
        separator.backgroundColor = theme.colors.border
        
        progress.insets = NSEdgeInsetsMake(0, 0, 0, 0)
        progress.scrubberImage = generateImage(NSMakeSize(8, 8), contextGenerator: { size, ctx in
            let rect = CGRect(origin: .zero, size: size)
            ctx.clear(rect)
            ctx.setFillColor(theme.colors.accent.cgColor)
            ctx.fillEllipse(in: rect)
        })
        progress.roundCorners = true
        progress.alignment = .center
        progress.liveScrobbling = false
        progress.fetchingColor = theme.colors.grayIcon.withAlphaComponent(0.6)
        progress.containerBackground = theme.colors.grayIcon.withAlphaComponent(0.2)
        progress.style = ControlStyle(foregroundColor: theme.colors.accent, backgroundColor: .clear, highlightColor: .clear)
        progress.set(progress: 0, animated: false, duration: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func updateScroll(_ position: ScrollPosition, tableFrame: NSRect) {
        separator.change(opacity: position.rect.minY > tableFrame.height ? 1 : 0)
    }
}

final class PlayerListView : View, APDelegate {
    
    let tableView: TableView
    private let controls: PlayerListControlsView = PlayerListControlsView(frame: .zero)
    private let bufferingStatusDisposable = MetaDisposable()
    private var ranges: (RangeSet<Int64>, Int64)?
    private(set) var controller:APController? {
        didSet {
            oldValue?.remove(listener: self)
            controller?.add(listener: self)
            if let controller = controller {
                self.bufferingStatusDisposable.set((controller.bufferingStatus
                    |> deliverOnMainQueue).start(next: { [weak self] status in
                        if let status = status {
                            self?.updateStatus(status.0, status.1)
                        }
                    }))
            } else {
                self.bufferingStatusDisposable.set(nil)
            }
        }
    }
    
    func updateStatus(_ ranges: RangeSet<Int64>, _ size: Int64) {
        self.ranges = (ranges, size)
        if let ranges = self.ranges, !ranges.0.isEmpty, ranges.1 != 0 {
            for range in ranges.0.ranges {
                var progress = (CGFloat(range.count) / CGFloat(ranges.1))
                progress = progress == 1.0 ? 0 : progress
                controls.progress.set(fetchingProgress: progress, animated: progress > 0)
                break
            }
        }
    }
    
    required init(frame frameRect: NSRect) {
        tableView = TableView(frame: .zero)
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(controls)
        
        controls.progress.onUserChanged = { [weak self] progress in
            self?.controller?.set(trackProgress: progress)
            self?.controls.progress.set(progress: CGFloat(progress), animated: false)
        }
        
        var paused: Bool = false
        
        controls.progress.startScrobbling = { [weak self]  in
            guard let controller = self?.controller else {
                return
            }
            if controller.isPlaying {
                _ = self?.controller?.pause()
                paused = true
            } else {
                paused = false
            }
        }
        
        controls.progress.endScrobbling = { [weak self]  in
            if paused {
                DispatchQueue.main.async {
                    _ = self?.controller?.play()
                }
            }
        }
        
        controls.handlings.next.set(handler: { [weak self] _ in
            self?.controller?.next()
            self?.scrollToCurrent()
        }, for: .Click)
        
        controls.handlings.prev.set(handler: { [weak self] _ in
            self?.controller?.prev()
            self?.scrollToCurrent()
        }, for: .Click)
        
        controls.handlings.playPause.set(handler: { [weak self] _ in
            self?.controller?.playOrPause()
        }, for: .Click)

        controls.handlings.iteration.set(handler: { [weak self] _ in
            self?.controller?.nextRepeatState()
        }, for: .Click)
        
        controls.handlings.order.set(handler: { [weak self] _ in
            self?.controller?.nextOrderState()
        }, for: .Click)
        
        tableView.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            if let `self` = self {
                self.controls.updateScroll(position, tableFrame: self.tableView.frame)
            }
        }))
        
        controls.searchClick = { [weak self] text in
            let context = self?.controller?.context
            if let context = context {
                context.bindings.mainController().focusSearch(animated: true, text: text)
            }
        }
    }
    
    
    func setController(_ controller: APController?) {
        self.controller = controller
        if let controller = controller, let item = controller.currentSong {
            self.controls.update(item, controller: controller, animated: false)
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        controller?.notifyGlobalStateChanged(animated: false)
    }
    
    private func scrollToCurrent() {
        if let entry = controller?.currentSong?.entry {
            switch entry {
            case let .song(message):
                self.tableView.scroll(to: .center(id: PeerMediaSharedEntryStableId.messageId(message.id), innerId: nil, animated: true, focus: .init(focus: false), inset: 0))
            default:
                break
            }
        }
    }
    
    override func layout() {
        super.layout()
        controls.frame = NSMakeRect(0, 0, frame.width, 140)
        tableView.frame = NSMakeRect(0, controls.frame.maxY, frame.width, frame.height - controls.frame.height)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func songDidChanged(song: APSongItem, for controller: APController, animated: Bool) {
        self.controls.update(song, controller: controller, animated: true)
    }
    
    func songDidChangedState(song: APSongItem, for controller: APController, animated: Bool) {
        controls.update(song, controller: controller, animated: true)
    }
    
    func songDidStartPlaying(song: APSongItem, for controller: APController, animated: Bool) {
        controls.update(song, controller: controller, animated: true)
    }
    
    func songDidStopPlaying(song: APSongItem, for controller: APController, animated: Bool) {
        controls.update(song, controller: controller, animated: true)
    }
    
    func playerDidChangedTimebase(song: APSongItem, for controller: APController, animated: Bool) {
        controls.update(song, controller: controller, animated: true)
    }
    
    func audioDidCompleteQueue(for controller: APController, animated: Bool) {
    }
    
}


class PlayerListController: ModalViewController {
    private let audioPlayer: InlineAudioPlayerView
    private let chatInteraction: ChatInteraction
    private let disposable = MetaDisposable()
    private let messageIndex: MessageIndex
    private let messages: [Message]
    private let context: AccountContext
    init(audioPlayer: InlineAudioPlayerView, context: AccountContext, currentContext: AccountContext, messageIndex: MessageIndex, messages: [Message] = []) {
        self.chatInteraction = ChatInteraction(chatLocation: .peer(messageIndex.id.peerId), context: context)
        self.messageIndex = messageIndex
        self.audioPlayer = audioPlayer
        self.context = context
        self.messages = messages
        super.init(frame: NSMakeRect(0, 0, 300, 400))
        
        
        chatInteraction.inlineAudioPlayer = { [weak self] controller in
            let object = InlineAudioPlayerView.ContextObject(controller: controller, context: currentContext, tableView: self?.tableView, supportTableView: nil)
            self?.audioPlayer.update(with: object)
            self?.genericView.setController(controller)
        }
    }
    
    var genericView: PlayerListView {
        return self.view as! PlayerListView
    }
    
    override func viewClass() -> AnyClass {
        return PlayerListView.self
    }
    
    var tableView: TableView {
        return genericView.tableView
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        window?.set(handler: { [weak self] event in
            self?.genericView.controller?.prev()
            return .invoked
        }, with: self, for: .LeftArrow, priority: .modal)
        
        window?.set(handler: { [weak self] event in
            self?.genericView.controller?.next()
            return .invoked
        }, with: self, for: .RightArrow, priority: .modal)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeObserver(for: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let chatLocationInput = (self.audioPlayer.controller as? APChatController)?.chatLocationInput
        tableView.getBackgroundColor = {
            return theme.colors.background
        }
                
        let location = ValuePromise<ChatHistoryLocation>(ignoreRepeated: true)
        
        let historyViewUpdate = location.get() |> deliverOnMainQueue
            |> mapToSignal { [weak self] location -> Signal<(PeerMediaUpdate, TableScrollState?), NoError> in
                
                guard let `self` = self else {return .complete()}
                
                return chatHistoryViewForLocation(location, context: self.chatInteraction.context, chatLocation: self.chatInteraction.chatLocation, fixedCombinedReadStates: nil, tag: .tag(.music), additionalData: [], chatLocationInput: chatLocationInput) |> mapToQueue { view -> Signal<(PeerMediaUpdate, TableScrollState?), NoError> in
                    switch view {
                    case .Loading:
                        return .single((PeerMediaUpdate(), nil))
                    case let .HistoryView(view: view, _, scroll, _):
                        var messages:[Message] = []
                        for entry in view.entries {
                             messages.append(entry.message)
                        }
                        let laterId = view.laterId
                        let earlierId = view.earlierId

                        var state: TableScrollState?
                        if let scroll = scroll {
                            switch scroll {
                            case let .index(_, position, _, _):
                                state = position
                            default:
                                break
                            }
                        }
                        return .single((PeerMediaUpdate(messages: messages, updateType: .history, laterId: laterId, earlierId: earlierId), state))
                    }
                }
        }
        
        let animated: Atomic<Bool> = Atomic(value: false)
        let context = self.chatInteraction.context
        let previous:Atomic<[PlayerListEntry]> = Atomic(value: [])
        let updateView = Atomic<PeerMediaUpdate?>(value: nil)
        
        
        let arguments = PlayerListArguments(chatInteraction: chatInteraction, music: { message, _ in
            context.sharedContext.getAudioPlayer()?.playOrPause(message.id)
        })
        
        let historyViewTransition: Signal<TableUpdateTransition, NoError>
        if messages.isEmpty {
            historyViewTransition = historyViewUpdate |> deliverOnPrepareQueue |> map { update, scroll -> TableUpdateTransition in
                let animated = animated.swap(true)
                let scroll:TableScrollState = scroll ?? (animated ? .none(nil) : .saveVisible(.upper, false))
                
                let entries = playerAudioEntries(update, timeDifference: context.timeDifference)
                _ = updateView.swap(update)
                
                return preparedAudioListTransition(from: previous.swap(entries), to: entries, initialSize: NSMakeSize(300, 0), arguments: arguments, animated: animated, scroll: scroll)
                
                } |> deliverOnMainQueue
        } else {
            let update = PeerMediaUpdate(messages: messages, updateType: .search, laterId: nil, earlierId: nil, automaticDownload: .defaultSettings, searchState: .init(state: .None, request: nil))
            let entries = playerAudioEntries(update, timeDifference: context.timeDifference)
            _ = updateView.swap(update)
            let transition = preparedAudioListTransition(from: previous.swap(entries), to: entries, initialSize: NSMakeSize(300, 0), arguments: arguments, animated: false, scroll: .none(nil))
            historyViewTransition = .single(transition)
        }
        
        
        
        
        disposable.set(historyViewTransition.start(next: { [weak self] transition in
            guard let `self` = self else {return}
            self.tableView.merge(with: transition)
            if !self.didSetReady, !self.tableView.isEmpty {
                self.tableView.scroll(to: .top(id: PeerMediaSharedEntryStableId.messageId(self.messageIndex.id), innerId: nil, animated: false, focus: .init(focus: false), inset: -25))
                self.genericView.setController(self.audioPlayer.controller)
                self.readyOnce()
            }
        }))
        
        location.set(.Navigation(index: MessageHistoryAnchorIndex.message(messageIndex), anchorIndex: MessageHistoryAnchorIndex.message(messageIndex), count: 50, side: .upper))

        
        tableView.setScrollHandler { scroll in
            let view = updateView.modify({$0})
            if let view = view {
                var messageIndex:MessageIndex?
                switch scroll.direction {
                case .bottom:
                    messageIndex = view.earlierId
                case .top:
                    messageIndex = view.laterId
                case .none:
                    break
                }
                
                if let messageIndex = messageIndex {
                    let _ = animated.swap(false)
                    location.set(.Navigation(index: MessageHistoryAnchorIndex.message(messageIndex), anchorIndex: MessageHistoryAnchorIndex.message(messageIndex), count: 50, side: scroll.direction == .bottom ? .lower : .upper))
                }
            }
        }
    }
    
}
