//
//  InlineAudioPlayerView.swift
//  TelegramMac
//
//  Created by keepcoder on 21/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit
import RangeSet
import TelegramMedia

private func effectivePlayingRate(for controller: APController) -> Double {
    if controller is APChatMusicController {
        return FastSettings.playingMusicRate
    } else {
        return FastSettings.playingRate
    }
}
private func setPlayingRate(_ rate: Double, for controller: APController) {
    if controller is APChatMusicController {
        FastSettings.setPlayingMusicRate(rate)
    } else {
        FastSettings.setPlayingRate(rate)
    }
}

func optionsRateImage(rate: String, color: NSColor, isLarge: Bool) -> CGImage {
    return generateImage(isLarge ? CGSize(width: 30, height: 30) : CGSize(width: 24.0, height: 24.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))

        let imageName: String = isLarge ? "playspeed_30" : "playspeed_24"
        
        if let image = NSImage(named: imageName )?.precomposed(color) {
            context.draw(image, in: size.bounds)
        }


        let string = NSMutableAttributedString(string: rate, font: NSFont.semibold(isLarge ? 11 : 10), textColor: color)

        var offset = CGPoint(x: 1.0, y: 0.0)
        if rate.count >= 3 {
            if rate == "0.5x" {
                string.addAttribute(.kern, value: -0.8 as NSNumber, range: NSRange(string.string.startIndex ..< string.string.endIndex, in: string.string))
                offset.x += -0.5
            } else {
                string.addAttribute(.kern, value: -0.5 as NSNumber, range: NSRange(string.string.startIndex ..< string.string.endIndex, in: string.string))
                offset.x += -0.3
            }
        } else {
            offset.x += -0.3
        }

        offset.x *= 0.5
        offset.y *= 0.5

        
        let layout = TextViewLayout(string, maximumNumberOfLines: 1, truncationType: .middle)
        layout.measure(width: size.width)
        let line = layout.lines[0]
        
        context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
        context.textPosition = size.bounds.focus(line.frame.size).origin.offsetBy(dx: 0, dy: isLarge ? 10 : 8)
        CTLineDraw(line.line, context)

        
//        let boundingRect = string.boundingRect(with: size, options: [], context: nil)
    //    string.draw(at: CGPoint(x: offset.x + floor((size.width - boundingRect.width) / 2.0), y: offset.y + floor((size.height - boundingRect.height) / 2.0)))

    })!
}



class InlineAudioPlayerView: NavigationHeaderView, APDelegate {


    struct ContextObject {
        let controller: APController
        let context: AccountContext
        let tableView: TableView?
        let supportTableView: TableView?
    }

    var contextValue: ContextObject? {
        return header?.contextObject as? ContextObject
    }
    var controller: APController? {
        return contextValue?.controller
    }
    var context: AccountContext? {
        return contextValue?.context
    }

    private let previous:ImageButton = ImageButton()
    private let next:ImageButton = ImageButton()
    
    private let playPause = Button()
    private let playPauseView = LottiePlayerView()

    private let dismiss:ImageButton = ImageButton()
    private let repeatControl:ImageButton = ImageButton()
    private let volumeControl: ImageButton = ImageButton()
    private let progressView:LinearProgressControl = LinearProgressControl(progressHeight: 2)
    private var artistNameView:TextView?
    private let trackNameView:TextView = TextView()
    private let textViewContainer = Control()
    private let containerView:Control
    private let separator:View = View()
    private let playingSpeed: ImageButton = ImageButton()



    private var message:Message?
    private(set) var instantVideoPip:InstantVideoPIP?
    private var ranges: (RangeSet<Int64>, Int64)?
    
    private var bufferingStatusDisposable: MetaDisposable = MetaDisposable()
    
   
    
    override init(_ header: NavigationHeader) {
        
        separator.backgroundColor = .border
        
        dismiss.disableActions()
        repeatControl.disableActions()
        
        trackNameView.isSelectable = false
        trackNameView.userInteractionEnabled = false
        containerView = Control(frame: NSMakeRect(0, 0, 0, header.height))
        
        super.init(header)

        dismiss.set(handler: { [weak self] _ in
            self?.stopAndHide(true)
        }, for: .Click)
        
        previous.set(handler: { [weak self] _ in
            self?.controller?.prev()
        }, for: .Click)
        
        next.set(handler: { [weak self] _ in
            self?.controller?.next()
        }, for: .Click)
        
        playPause.set(handler: { [weak self] _ in
            self?.controller?.playOrPause()
        }, for: .Click)
        
        repeatControl.set(handler: { [weak self] _ in
            if let controller = self?.controller {
                if self?.hasPlayerList == true {
                    self?.showAudioPlayerList()
                } else {
                    controller.nextRepeatState()
                }
            }
        }, for: .Click)
        
        repeatControl.scaleOnClick = true
        playPause.scaleOnClick = true
        next.scaleOnClick = true
        previous.scaleOnClick = true
        dismiss.scaleOnClick = true
        playingSpeed.scaleOnClick = true
        
        progressView.onUserChanged = { [weak self] progress in
            self?.controller?.set(trackProgress: progress)
            self?.progressView.set(progress: CGFloat(progress), animated: false)
        }
        
        var paused: Bool = false
        
        progressView.startScrobbling = { [weak self]  in
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
        
        progressView.endScrobbling = { [weak self]  in
            if paused {
                DispatchQueue.main.async {
                    _ = self?.controller?.play()
                }
            }
        }
        
        progressView.set(handler: { [weak self] control in
            let control = control as! LinearProgressControl
            if let strongSelf = self {
                strongSelf.controller?.set(trackProgress: control.interactiveValue)
                strongSelf.progressView.set(progress: CGFloat(control.interactiveValue), animated: false)
            }
        }, for: .Click)
        
        previous.autohighlight = false
        next.autohighlight = false
        playPause.autohighlight = false
        repeatControl.autohighlight = false
        volumeControl.autohighlight = false
        playingSpeed.autohighlight = false
        
        previous.scaleOnClick = true
        next.scaleOnClick = true
        playPause.scaleOnClick = true
        repeatControl.scaleOnClick = true
        volumeControl.scaleOnClick = true
        playingSpeed.scaleOnClick = true
        
        
        
        containerView.addSubview(previous)
        containerView.addSubview(next)
        
        playPause.addSubview(playPauseView)
        playPause.setFrameSize(NSMakeSize(34, 34))
        playPauseView.setFrameSize(playPause.frame.size)
        containerView.addSubview(playPause)
        
        containerView.addSubview(dismiss)
        containerView.addSubview(repeatControl)
        containerView.addSubview(textViewContainer)
        containerView.addSubview(playingSpeed)
        containerView.addSubview(volumeControl)
        addSubview(containerView)
        addSubview(separator)
        addSubview(progressView)
        
        textViewContainer.addSubview(trackNameView)

        trackNameView.userInteractionEnabled = false
        trackNameView.isEventLess = true
        
        
        
        
        textViewContainer.set(handler: { [weak self] _ in
            self?.gotoMessage()
        }, for: .SingleClick)
        
        
        playingSpeed.contextMenu = { [weak self] in
            
            let menu = ContextMenu()
            
            guard let controller = self?.controller else {
                return menu
            }

            let customItem = ContextMenuItem(String(format: "%.1fx", effectivePlayingRate(for: controller)), image: NSImage(cgImage: generateEmptySettingsIcon(), size: NSMakeSize(24, 24)))
            
            menu.addItem(SliderContextMenuItem(volume: effectivePlayingRate(for: controller), minValue: 0.2, maxValue: 2.5, midValue: 1, drawable: MenuAnimation.menu_speed, drawable_muted: MenuAnimation.menu_speed, { [weak self] value, _ in
                customItem.title = String(format: "%.1fx", value)
                if let controller = self?.controller {
                    setPlayingRate(value, for: controller)
                    self?.controller?.baseRate = effectivePlayingRate(for: controller)
                }
            }))
            
            
            menu.addItem(customItem)
            
            if effectivePlayingRate(for: controller) != 1.0 {
                menu.addItem(ContextSeparatorItem())
                menu.addItem(ContextMenuItem(strings().playbackSpeedSetToDefault, handler: { [weak self] in
                    if let controller = self?.controller {
                        setPlayingRate(1.0, for: controller)
                        controller.baseRate = effectivePlayingRate(for: controller)
                    }
                }, itemImage: MenuAnimation.menu_reset.value))
            }

            
            return menu
        }
        
//        playingSpeed.set(handler: { [weak self] control in
//            FastSettings.setPlayingRate(FastSettings.playingRate != 1 ? 1.0 : 1.75)
//            self?.controller?.baseRate = FastSettings.playingRate
//        }, for: .Click)
        
        
        volumeControl.set(handler: { [weak self] control in
            if control.popover == nil {
                showPopover(for: control, with: VolumeControllerPopover(initialValue: CGFloat(FastSettings.volumeRate), updatedValue: { updatedVolume in
                    FastSettings.setVolumeRate(Float(updatedVolume))
                    self?.controller?.volume = FastSettings.volumeRate
                }), edge: .maxY, inset: NSMakePoint(-5, -50))
            }
        }, for: .Hover)
        
        volumeControl.set(handler: { control in
            FastSettings.setVolumeRate(FastSettings.volumeRate > 0 ? 0 : 1.0)
            if let popover = control.popover?.controller as? VolumeControllerPopover {
                popover.value = CGFloat(FastSettings.volumeRate)
            }
        }, for: .Up)
        
        updateLocalizationAndTheme(theme: theme)

    }
    
    var hasPlayerList: Bool {
        if let controller = controller as? APChatMusicController, let song = controller.currentSong {
            switch song.stableId {
            case let .message(message):
                return true
            default:
                return false
            }
        }
        return false
    }
    
    private func showAudioPlayerList() {
        guard let window = _window, let context = self.context else {return}
        if let controller = controller as? APChatMusicController, let song = controller.currentSong {
            switch song.stableId {
            case let .message(message):
                showModal(with: PlayerListController(audioPlayer: self, context: controller.context, currentContext: context, messageIndex: MessageIndex(message), messages: controller.messages), for: context.window)
            default:
                break
            }
        }
    }
    
    func updateStatus(_ ranges: RangeSet<Int64>, _ size: Int64) {
        self.ranges = (ranges, size)
        
        if let ranges = self.ranges, !ranges.0.isEmpty, ranges.1 != 0 {
            for range in ranges.0.ranges {
                var progress = (CGFloat(range.count) / CGFloat(ranges.1))
                progress = progress == 1.0 ? 0 : progress
                progressView.set(fetchingProgress: progress, animated: progress > 0)
                
                break
            }
        }
    }
    
    
    private var playProgressStyle:ControlStyle {
        return ControlStyle(foregroundColor: theme.colors.accent, backgroundColor: .clear, highlightColor: .clear)
    }
    private var fetchProgressStyle:ControlStyle {
        return ControlStyle(foregroundColor: theme.colors.grayTransparent, backgroundColor: .clear, highlightColor: .clear)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        
        progressView.fetchingColor = theme.colors.accent.withAlphaComponent(0.5)

        
        backgroundColor = theme.colors.background
        containerView.backgroundColor = theme.colors.background
        artistNameView?.backgroundColor = theme.colors.background
        separator.backgroundColor = theme.colors.border
        
        controller?.notifyGlobalStateChanged(animated: false)
        
    }
    
    private func gotoMessage() {
        if let message = message, let context = context, context.peerId == controller?.context.peerId {
            if let controller = context.bindings.rootNavigation().controller as? ChatController, controller.chatInteraction.peerId == message.id.peerId {
                controller.chatInteraction.focusMessageId(nil, .init(messageId: message.id, string: nil), .center(id: 0, innerId: nil, animated: true, focus: .init(focus: false), inset: 0))
            } else {
                navigateToChat(navigation: context.bindings.rootNavigation(), context: context, chatLocation: .peer(message.id.peerId), focusTarget: .init(messageId: message.id))
            }
        }
    }

    override func update(with contextObject: Any) {
        super.update(with: contextObject)

        let contextObject = contextObject as! ContextObject

        let controller = contextObject.controller

        self.bufferingStatusDisposable.set((controller.bufferingStatus
            |> deliverOnMainQueue).start(next: { [weak self] status in
                if let status = status {
                    self?.updateStatus(status.0, status.1)
                }
            }))
        controller.baseRate = effectivePlayingRate(for: controller)


        controller.add(listener: self)
        self.ready.set(controller.ready.get())

        repeatControl.isHidden = !controller.canMakeRepeat
        if let tableView = contextObject.tableView {
            if self.instantVideoPip == nil {
                self.instantVideoPip = InstantVideoPIP(controller, context: controller.context, window: controller.context.window)
            }
            self.instantVideoPip?.updateTableView(tableView, context: controller.context, controller: controller)
            addGlobalAudioToVisible(tableView: tableView)
        }
        if let supportTableView = contextObject.supportTableView {
            addGlobalAudioToVisible(tableView: supportTableView)
        }
        if let song = controller.currentSong {
            songDidChanged(song: song, for: controller, animated: true)
        }
    }

    private func addGlobalAudioToVisible(tableView: TableView) {
        if let controller = controller {
            tableView.enumerateViews(with: { (view) in
                var contentView: NSView? = (view as? ChatRowView)?.contentView.subviews.last ?? (view as? PeerMediaMusicRowView)
                if let view = ((view as? ChatMessageView)?.webpageContent as? WPMediaContentView)?.contentNode {
                    contentView = view
                }
                
                if let view = view as? ChatGroupedView {
                    for content in view.contents {
                        controller.add(listener: content)
                    }
                } else if let view = contentView as? ChatAudioContentView {
                    controller.add(listener: view)
                } else if let view = contentView as? ChatVideoMessageContentView {
                    controller.add(listener: view)
                } else if let view = contentView as? WPMediaContentView {
                    if let contentNode = view.contentNode as? ChatAudioContentView {
                        controller.add(listener: contentNode)
                    }
                } else if let view = view as? PeerMediaMusicRowView {
                    controller.add(listener: view)
                } else if let view = view as? PeerMediaVoiceRowView {
                    controller.add(listener: view)
                } else if let view = view as? StorageUsageMediaItemView {
                    controller.add(listener: view)
                }
                return true
            })
            controller.notifyGlobalStateChanged(animated: false)
        }
    }
    
    deinit {
        bufferingStatusDisposable.dispose()
    }
    
    func attributedTitle(for song:APSongItem) -> (NSAttributedString, NSAttributedString?) {
        let trackName:NSAttributedString
        let artistName:NSAttributedString?

        if song.songName.isEmpty {
            trackName = .initialize(string: song.performerName, color: theme.colors.text, font: .normal(.text))
            artistName = nil
        } else {
            trackName = .initialize(string: song.songName, color: theme.colors.text, font: .normal(.text))
            if !song.performerName.isEmpty {
                artistName = .initialize(string: song.performerName, color: theme.colors.grayText, font: .normal(.text))
            } else {
                artistName = nil
            }
        }

        return (trackName, artistName)
    }
    
    
    private func update(_ song: APSongItem, controller: APController, animated: Bool) {
        
        
        dismiss.set(image: theme.icons.audioplayer_dismiss, for: .Normal)

        switch song.entry {
        case let .song(message):
            self.message = message
        default:
            self.message = nil
        }
        
        next.userInteractionEnabled = controller.nextEnabled
        previous.userInteractionEnabled = controller.prevEnabled

        switch controller.nextEnabled {
        case true:
            next.set(image: theme.icons.audioplayer_next, for: .Normal)
        case false:
            next.set(image: theme.icons.audioplayer_locked_next, for: .Normal)
        }
        
        switch controller.prevEnabled {
        case true:
            previous.set(image: theme.icons.audioplayer_prev, for: .Normal)
        case false:
            previous.set(image: theme.icons.audioplayer_locked_prev, for: .Normal)
        }
                
        let attr = attributedTitle(for: song)
        
        if trackNameView.textLayout?.attributedString != attr.0 {
            let artist = TextViewLayout(attr.0, maximumNumberOfLines:1, alignment: .left)
            self.trackNameView.update(artist)
        }
        if let attr = attr.1 {
            let current: TextView
            if self.artistNameView == nil {
                current = TextView()
                current.userInteractionEnabled = false
                current.isEventLess = true
                self.artistNameView = current
                textViewContainer.addSubview(current)
            } else {
                current = self.artistNameView!
            }
            if current.textLayout?.attributedString != attr {
                let artist = TextViewLayout(attr, maximumNumberOfLines:1, alignment: .left)
                current.update(artist)
            }
            
        } else {
            if let view = self.artistNameView {
                self.artistNameView = nil
                if animated {
                    view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                        view?.removeFromSuperview()
                    })
                } else {
                    view.removeFromSuperview()
                }
            }
        }
        
        playingSpeed.set(image: optionsRateImage(rate: String(format: "%.1fx", effectivePlayingRate(for: controller)), color: effectivePlayingRate(for: controller) == 1.0 ? theme.colors.grayIcon : theme.colors.accent, isLarge: true), for: .Normal)
        
        switch FastSettings.volumeRate {
        case 0:
            volumeControl.set(image: theme.icons.audioplayer_volume_off, for: .Normal)
        default:
            volumeControl.set(image: theme.icons.audioplayer_volume, for: .Normal)
        }
        
        
        if hasPlayerList {
            repeatControl.set(image: theme.icons.audioplayer_list, for: .Normal)
        } else {
            switch controller.state.repeatState {
            case .circle:
                repeatControl.set(image: theme.icons.audioplayer_repeat_circle, for: .Normal)
            case .one:
                repeatControl.set(image: theme.icons.audioplayer_repeat_one, for: .Normal)
            case .none:
                repeatControl.set(image: theme.icons.audioplayer_repeat_none, for: .Normal)
            }
            
        }
        
       
       
        
        switch song.state {
        case .waiting:
            progressView.style = playProgressStyle
        case .stoped:
            progressView.set(progress: 0, animated: animated)
        case let .playing(_, _, progress), let .paused(_, _, progress):
            progressView.style = playProgressStyle
            progressView.set(progress: CGFloat(progress.isNaN ? 0 : progress), animated: animated, duration: 0.2)
        case let .fetching(progress):
            progressView.style = fetchProgressStyle
            progressView.set(progress: CGFloat(progress), animated:animated)
        }
        
        switch controller.state.status {
        case .playing:
            play(animated: animated, sticker: LocalAnimatedSticker.playlist_play_pause)
        case .paused:
            play(animated: animated, sticker: LocalAnimatedSticker.playlist_pause_play)
        default:
            break
        }
        
        _ = previous.sizeToFit()
        _ = next.sizeToFit()
        _ = dismiss.sizeToFit()
        _ = repeatControl.sizeToFit()
        _ = playingSpeed.sizeToFit()
        _ = volumeControl.sizeToFit()
        
        needsLayout = true
    }
    
    func songDidChanged(song:APSongItem, for controller:APController, animated: Bool) {
        self.update(song, controller: controller, animated: animated)
    }
    
    func songDidChangedState(song: APSongItem, for controller: APController, animated: Bool) {
        self.update(song, controller: controller, animated: animated)
    }
    
    func songDidStartPlaying(song:APSongItem, for controller:APController, animated: Bool) {
        self.update(song, controller: controller, animated: animated)
    }
    func songDidStopPlaying(song:APSongItem, for controller:APController, animated: Bool) {
        self.update(song, controller: controller, animated: animated)
    }
    func playerDidChangedTimebase(song:APSongItem, for controller:APController, animated: Bool) {
        self.update(song, controller: controller, animated: animated)
    }
    
    func audioDidCompleteQueue(for controller:APController, animated: Bool) {
        stopAndHide(true)
    }
    
    override func layout() {
        super.layout()
        containerView.frame = bounds
        
        previous.centerY(x: 17)
        playPause.centerY(x: previous.frame.maxX + 5)
        next.centerY(x: playPause.frame.maxX + 5)


        dismiss.centerY(x: frame.width - 20 - dismiss.frame.width)
        
       
        progressView.frame = NSMakeRect(0, frame.height - 6, frame.width, 6)
        
        
        let textWidth = frame.width - (next.frame.maxX + dismiss.frame.width + repeatControl.frame.width + (playingSpeed.isHidden ? 0 : playingSpeed.frame.width + 10) + volumeControl.frame.width + 70)
        
        artistNameView?.resize(textWidth)
        trackNameView.resize(textWidth)
        
        let effectiveWidth = [artistNameView, trackNameView].compactMap { $0?.frame.width }.max(by: { $0 < $1 }) ?? 0
        
        textViewContainer.setFrameSize(NSMakeSize(effectiveWidth, 40))
        textViewContainer.centerY(x: next.frame.maxX + 20)
                
        
        if let artistNameView = artistNameView {
            trackNameView.setFrameOrigin(NSMakePoint(0, 4))
            artistNameView.setFrameOrigin(NSMakePoint(0, textViewContainer.frame.height - artistNameView.frame.height - 4))
        } else {
            trackNameView.centerY(x: 0)
        }
        
        let controls = [volumeControl, playingSpeed, repeatControl].filter { !$0.isHidden }
        
        var x: CGFloat = dismiss.frame.minX - 10
        for control in controls {
            x = x - control.frame.width
            control.centerY(x: x)
            x -= 10
        }
        
        separator.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
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
            let animation = LottieAnimation(compressed: data, key: .init(key: .bundle(sticker.rawValue), size: NSMakeSize(34, 34)), cachePurpose: .none, playPolicy: .toEnd(from: animated ? total - current : .max), colors: [.init(keyPath: "", color: theme.colors.accent)], runOnQueue: .mainQueue())
            playPauseView.set(animation)
        }
    }
    
    func stopAndHide(_ animated:Bool) -> Void {
        controller?.remove(listener: self)
        controller?.stop()
        controller?.cleanup()
        instantVideoPip?.hide()
        instantVideoPip = nil
        context?.sharedContext.endInlinePlayer(animated: animated)
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
