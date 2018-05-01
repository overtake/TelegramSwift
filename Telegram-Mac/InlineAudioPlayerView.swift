//
//  InlineAudioPlayerView.swift
//  TelegramMac
//
//  Created by keepcoder on 21/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac



class InlineAudioPlayerView: NavigationHeaderView, APDelegate {

    let previous:ImageButton = ImageButton()
    let next:ImageButton = ImageButton()
    let playOrPause:ImageButton = ImageButton()
    let dismiss:ImageButton = ImageButton()
    let repeatControl:ImageButton = ImageButton()
    let progressView:LinearProgressControl = LinearProgressControl(progressHeight: .borderSize)
    let textView:TextView = TextView()
    let containerView:View
    let separator:View = View()
    private var controller:APController? {
        didSet {
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
    private var message:Message?
    private(set) var instantVideoPip:InstantVideoPIP?
    private var ranges: (IndexSet, Int)?
    
    private var bufferingStatusDisposable: MetaDisposable = MetaDisposable()
    
   
    
    override init(_ header: NavigationHeader) {
        
        separator.backgroundColor = .border
        
        dismiss.disableActions()
        repeatControl.disableActions()
        
        textView.isSelectable = false
        
        containerView = View(frame: NSMakeRect(0, 0, 0, header.height))
        
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
        
        progressView.set(handler: { [weak self] control in
            let control = control as! LinearProgressControl
            if let strongSelf = self {
                strongSelf.controller?.set(trackProgress: control.interactiveValue)
                strongSelf.progressView.set(progress: CGFloat(control.interactiveValue), animated: false)
            }
        }, for: .Click)
        
        containerView.addSubview(previous)
        containerView.addSubview(next)
        containerView.addSubview(playOrPause)
        containerView.addSubview(dismiss)
        containerView.addSubview(repeatControl)
        containerView.addSubview(textView)
        addSubview(containerView)
        addSubview(separator)
        addSubview(progressView)
        
        textView.userInteractionEnabled = false
     
        
        updateLocalizationAndTheme()
        
        
        
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
        return ControlStyle(foregroundColor: theme.colors.blueUI, backgroundColor: .clear)
    }
    private var fetchProgressStyle:ControlStyle {
        return ControlStyle(foregroundColor: theme.colors.grayTransparent, backgroundColor: .clear)
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        
        previous.set(image: theme.icons.audioPlayerPrev, for: .Normal)
        next.set(image: theme.icons.audioPlayerNext, for: .Normal)
        playOrPause.set(image: theme.icons.audioPlayerPause, for: .Normal)
        dismiss.set(image: theme.icons.auduiPlayerDismiss, for: .Normal)
        
        progressView.fetchingColor = theme.colors.blueUI.withAlphaComponent(0.5)
        
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
        
        
        previous.centerY(x: 20)
        playOrPause.centerY(x: previous.frame.maxX + 5)
        next.centerY(x: playOrPause.frame.maxX + 5)

        
        backgroundColor = theme.colors.background
        containerView.backgroundColor = theme.colors.background
        textView.backgroundColor = theme.colors.background
        separator.backgroundColor = theme.colors.border
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if let message = message, let controller = controller, let navigation = controller.account.context.mainNavigation {
            if let controller = navigation.controller as? ChatController, controller.chatInteraction.peerId == message.id.peerId {
                controller.chatInteraction.focusMessageId(nil, message.id, .center(id: 0, innerId: nil, animated: true, focus: false, inset: 0))
            } else {
                navigation.push(ChatController(account: controller.account, chatLocation: .peer(message.id.peerId), messageId: message.id))
            }
        }
    }
    
    func update(with controller:APController, tableView:TableView) {
        self.controller?.remove(listener: self)
        self.controller = controller
        self.controller?.add(listener: self)
        self.ready.set(controller.ready.get())
        
        repeatControl.isHidden = !(controller is APChatMusicController)
        self.instantVideoPip = InstantVideoPIP(controller, window: mainWindow)
        self.instantVideoPip?.updateTableView(tableView)
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
            progressView.set(progress: CGFloat(data.progress), animated: data.animated)
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
        textView.layout?.measure(width: frame.width - (next.frame.maxX + dismiss.frame.width + repeatControl.frame.width + 20))
        textView.update(textView.layout)
        
        let w = (repeatControl.isHidden ? dismiss.frame.minX : repeatControl.frame.minX) - next.frame.maxX
        
        textView.centerY(x: next.frame.maxX + floorToScreenPixels(scaleFactor: backingScaleFactor, (w - textView.frame.width)/2), addition: -2)
        
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
