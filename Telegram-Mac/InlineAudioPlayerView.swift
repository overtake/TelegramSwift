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
import SyncCore
import Postbox
import SwiftSignalKit



class InlineAudioPlayerView: NavigationHeaderView, APDelegate {

    private let previous:ImageButton = ImageButton()
    private let next:ImageButton = ImageButton()
    private let playOrPause:ImageButton = ImageButton()
    private let dismiss:ImageButton = ImageButton()
    private let repeatControl:ImageButton = ImageButton()
    private let progressView:LinearProgressControl = LinearProgressControl(progressHeight: .borderSize)
    private let textView:TextView = TextView()
    private let containerView:Control
    private let separator:View = View()
    private let playingSpeed: ImageButton = ImageButton()
    private var controller:APController? {
        didSet {
            if let controller = controller {
                self.bufferingStatusDisposable.set((controller.bufferingStatus
                    |> deliverOnMainQueue).start(next: { [weak self] status in
                        if let status = status {
                            self?.updateStatus(status.0, status.1)
                        }
                    }))
                controller.baseRate = (controller is APChatVoiceController) ? FastSettings.playingRate : 1.0
            } else {
                self.bufferingStatusDisposable.set(nil)
            }
            self.playingSpeed.isHidden = !(controller is APChatVoiceController)
        }
    }
    private var context: AccountContext?
    private var message:Message?
    private(set) var instantVideoPip:InstantVideoPIP?
    private var ranges: (IndexSet, Int)?
    
    private var bufferingStatusDisposable: MetaDisposable = MetaDisposable()
    
   
    
    override init(_ header: NavigationHeader) {
        
        separator.backgroundColor = .border
        
        dismiss.disableActions()
        repeatControl.disableActions()
        repeatControl.autohighlight = false
        textView.isSelectable = false
        
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
        
        playOrPause.set(handler: { [weak self] _ in
            self?.controller?.playOrPause()
        }, for: .Click)
        
        repeatControl.set(handler: { [weak self] control in
            let control = control as! ImageButton
            if let controller = self?.controller {
                controller.toggleRepeat()
                control.set(image: controller.needRepeat ? theme.icons.audioPlayerRepeatActive : theme.icons.audioPlayerRepeat, for: .Normal)
            }
            
        }, for: .Click)
        
        
        progressView.onUserChanged = { [weak self] progress in
            self?.controller?.set(trackProgress: progress)
            self?.progressView.set(progress: CGFloat(progress), animated: false)
        }
        
        var paused: Bool = false
        
        progressView.startScrobbling = { [weak self]  in
            _ = self?.controller?.pause()
            paused = true
        }
        
        progressView.endScrobbling = { [weak self]  in
            if paused {
                _ = self?.controller?.play()
            }
        }
        
        progressView.set(handler: { [weak self] control in
            let control = control as! LinearProgressControl
            if let strongSelf = self {
                strongSelf.controller?.set(trackProgress: control.interactiveValue)
                strongSelf.progressView.set(progress: CGFloat(control.interactiveValue), animated: false)
            }
        }, for: .Click)
        
        playingSpeed.autohighlight = false
        
        containerView.addSubview(previous)
        containerView.addSubview(next)
        containerView.addSubview(playOrPause)
        containerView.addSubview(dismiss)
        containerView.addSubview(repeatControl)
        containerView.addSubview(textView)
        containerView.addSubview(playingSpeed)
        addSubview(containerView)
        addSubview(separator)
        addSubview(progressView)
        
        textView.userInteractionEnabled = false
        textView.isEventLess = true
        
        updateLocalizationAndTheme(theme: theme)
        
        containerView.set(handler: { [weak self] _ in
            self?.showAudioPlayerList()
        }, for: .LongOver)
        
        containerView.set(handler: { [weak self] _ in
            self?.gotoMessage()
        }, for: .SingleClick)
        
        playingSpeed.set(handler: { [weak self] control in
            FastSettings.setPlayingRate(FastSettings.playingRate == 1.7 ? 1.0 : 1.7)
            self?.controller?.baseRate = FastSettings.playingRate
            (control as! ImageButton).set(image: FastSettings.playingRate == 1.7 ? theme.icons.playingVoice2x : theme.icons.playingVoice1x, for: .Normal)

        }, for: .Click)
    }
    
    private func showAudioPlayerList() {
        guard let window = kitWindow, let context = context else {return}
        let point = containerView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        if NSPointInRect(point, textView.frame) {
            if let song = controller?.currentSong, controller is APChatMusicController {
                switch song.stableId {
                case let .message(message):
                    showPopover(for: textView, with: PlayerListController(audioPlayer: self, context: context, messageIndex: MessageIndex(message)), edge: .minX, inset: NSMakePoint((300 - textView.frame.width) / 2, -60))
                default:
                    break
                }
            }
        }
    }
    
    func updateStatus(_ ranges: IndexSet, _ size: Int) {
        self.ranges = (ranges, size)
        
        if let ranges = self.ranges, !ranges.0.isEmpty, ranges.1 != 0 {
            for range in ranges.0.rangeView {
                var progress = (CGFloat(range.count) / CGFloat(ranges.1))
                progress = progress == 1.0 ? 0 : progress
                progressView.set(fetchingProgress: progress, animated: progress > 0)
                
                break
            }
        }
    }
    

    
    private var playProgressStyle:ControlStyle {
        return ControlStyle(foregroundColor: theme.colors.accent, backgroundColor: .clear)
    }
    private var fetchProgressStyle:ControlStyle {
        return ControlStyle(foregroundColor: theme.colors.grayTransparent, backgroundColor: .clear)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        playingSpeed.set(image: FastSettings.playingRate != 1.0 ? theme.icons.playingVoice2x : theme.icons.playingVoice1x, for: .Normal)
        previous.set(image: theme.icons.audioPlayerPrev, for: .Normal)
        next.set(image: theme.icons.audioPlayerNext, for: .Normal)
        playOrPause.set(image: theme.icons.audioPlayerPause, for: .Normal)
        dismiss.set(image: theme.icons.auduiPlayerDismiss, for: .Normal)
        
        progressView.fetchingColor = theme.colors.accent.withAlphaComponent(0.5)
        
        if let controller = controller {
            repeatControl.set(image: controller.needRepeat ? theme.icons.audioPlayerRepeatActive : theme.icons.audioPlayerRepeat, for: .Normal)
            if let song = controller.currentSong {
                songDidChanged(song: song, for: controller)
                songDidChangedState(song: song, for: controller)
            }
        } else {
            repeatControl.set(image: theme.icons.audioPlayerRepeat, for: .Normal)
        }
        
        _ = previous.sizeToFit()
        _ = next.sizeToFit()
        _ = playOrPause.sizeToFit()
        _ = dismiss.sizeToFit()
        _ = repeatControl.sizeToFit()
        _ = playingSpeed.sizeToFit()

        
        previous.centerY(x: 20)
        playOrPause.centerY(x: previous.frame.maxX + 5)
        next.centerY(x: playOrPause.frame.maxX + 5)
        
        backgroundColor = theme.colors.background
        containerView.backgroundColor = theme.colors.background
        textView.backgroundColor = theme.colors.background
        separator.backgroundColor = theme.colors.border
    }
    
    private func gotoMessage() {
        if let message = message, let context = context {
            if let controller = context.sharedContext.bindings.rootNavigation().controller as? ChatController, controller.chatInteraction.peerId == message.id.peerId {
                controller.chatInteraction.focusMessageId(nil, message.id, .center(id: 0, innerId: nil, animated: true, focus: .init(focus: false), inset: 0))
            } else {
                context.sharedContext.bindings.rootNavigation().push(ChatController(context: context, chatLocation: .peer(message.id.peerId), messageId: message.id))
            }
        }
    }
    
    func update(with controller:APController, context: AccountContext, tableView:TableView?, supportTableView: TableView? = nil) {
        self.controller?.remove(listener: self)
        self.controller = controller
        self.context = context
        self.controller?.add(listener: self)
        self.ready.set(controller.ready.get())
        
        repeatControl.isHidden = !(controller is APChatMusicController)
        if let tableView = tableView {
            if self.instantVideoPip == nil {
                self.instantVideoPip = InstantVideoPIP(controller, context: context, window: mainWindow)
            }
            self.instantVideoPip?.updateTableView(tableView, context: context, controller: controller)
            addGlobalAudioToVisible(tableView: tableView)
        }
        if let supportTableView = supportTableView {
            addGlobalAudioToVisible(tableView: supportTableView)
        }
        
    }
    
    private func addGlobalAudioToVisible(tableView: TableView) {
        if let controller = controller {
            tableView.enumerateViews(with: { (view) in
                var contentView: NSView? = (view as? ChatRowView)?.contentView.subviews.last ?? (view as? PeerMediaMusicRowView)
                if let view = ((view as? ChatMessageView)?.webpageContent as? WPMediaContentView)?.contentNode {
                    contentView = view
                }
                
                if let view = contentView as? ChatAudioContentView {
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
                }
                return true
            })
            controller.notifyGlobalStateChanged()
        }
    }
    
    deinit {
        controller?.remove(listener: self)
        controller?.stop()
        bufferingStatusDisposable.dispose()
    }
    
    func attributedTitle(for song:APSongItem) -> NSAttributedString {
        let attributed:NSMutableAttributedString = NSMutableAttributedString()
        if !song.performerName.isEmpty {
            _ = attributed.append(string: song.performerName, color: theme.colors.text, font: .normal(.text))
            _ = attributed.append(string: "\n")
        }
        _ = attributed.append(string: song.songName, color: theme.colors.grayText, font: .normal(.text))

        return attributed
    }
    
    func songDidChanged(song:APSongItem, for controller:APController) {
        next.set(image: controller.nextEnabled ? theme.icons.audioPlayerNext : theme.icons.audioPlayerLockedNext, for: .Normal)
        previous.set(image: controller.prevEnabled ? theme.icons.audioPlayerPrev : theme.icons.audioPlayerLockedPrev, for: .Normal)
        let layout = TextViewLayout(attributedTitle(for: song), maximumNumberOfLines:2, alignment: .center)
        self.textView.update(layout)
        self.needsLayout = true
        
        switch song.entry {
        case let .song(message):
            self.message = message
        default:
            break
        }
    }
    
    func songDidChangedState(song: APSongItem, for controller: APController) {
        switch song.state {
        case .waiting, .paused:
            progressView.style = playProgressStyle
            playOrPause.set(image: theme.icons.audioPlayerPlay, for: .Normal)
        case .stoped:
            playOrPause.set(image: theme.icons.audioPlayerPlay, for: .Normal)
            progressView.set(progress: 0, animated:true)
        case let .playing(data):
            progressView.style = playProgressStyle
            progressView.set(progress: CGFloat(data.progress == .nan ? 0 : data.progress), animated: data.animated, duration: 0.2)
            playOrPause.set(image: theme.icons.audioPlayerPause, for: .Normal)
            break
        case let .fetching(progress, animated):
            playOrPause.set(image: theme.icons.audioPlayerLockedPlay, for: .Normal)
            progressView.style = fetchProgressStyle
            progressView.set(progress: CGFloat(progress), animated:animated)
            break
        }
    }
    
    func songDidStartPlaying(song:APSongItem, for controller:APController) {
        
    }
    func songDidStopPlaying(song:APSongItem, for controller:APController) {
        
    }
    func playerDidChangedTimebase(song:APSongItem, for controller:APController) {
        
    }
    
    func audioDidCompleteQueue(for controller:APController) {
        stopAndHide(true)
    }
    
    override func layout() {
        super.layout()
        containerView.frame = bounds

        
        dismiss.centerY(x: frame.width - 20 - dismiss.frame.width)
        repeatControl.centerY(x: dismiss.frame.minX - 10 - repeatControl.frame.width)
        progressView.frame = NSMakeRect(0, frame.height - 6, frame.width, 6)
        textView.layout?.measure(width: frame.width - (next.frame.maxX + dismiss.frame.width + repeatControl.frame.width + 40 + (playingSpeed.isHidden ? 0 : playingSpeed.frame.width + 40)))
        textView.update(textView.layout)
        
        playingSpeed.centerY(x: dismiss.frame.minX - playingSpeed.frame.width - 20)

        
        let w = (repeatControl.isHidden ? dismiss.frame.minX : repeatControl.frame.minX) - next.frame.maxX
        
        textView.centerY(x: next.frame.maxX + floorToScreenPixels(backingScaleFactor, (w - textView.frame.width)/2))
        
        
        separator.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
    }
    
    func stopAndHide(_ animated:Bool) -> Void {
        header?.hide(true)
        controller?.remove(listener: self)
        controller?.stop()
        controller?.cleanup()
        controller = nil
        instantVideoPip?.hide()
        instantVideoPip = nil
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
