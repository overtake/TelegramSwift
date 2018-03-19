//
//  ChatVoiceContentView.swift
//  TelegramMac
//
//  Created by keepcoder on 21/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import TelegramCoreMac
import TGUIKit
import SwiftSignalKitMac


class ChatVoiceContentView: ChatAudioContentView {

    var isIncomingConsumed:Bool {
        var isConsumed:Bool = false
        if let parent = parent {
            for attr in parent.attributes {
                if let attr = attr as? ConsumableContentMessageAttribute {
                    isConsumed = attr.consumed
                    break
                }
            }
        }
        return isConsumed
    }
    
    let waveformView:AudioWaveformView
    private var acceptDragging: Bool = false
    private var playAfterDragging: Bool = false
    required init(frame frameRect: NSRect) {
        waveformView = AudioWaveformView(frame: NSMakeRect(0, 20, 100, 20))
        super.init(frame: frameRect)
        durationView.userInteractionEnabled = false
        addSubview(waveformView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func open() {
        if let parameters = parameters as? ChatMediaVoiceLayoutParameters, let account = account, let parent = parent  {
            if let controller = globalAudio, let song = controller.currentSong, song.entry.isEqual(to: parent) {
                controller.playOrPause()
            } else {
                
                let controller:APController
                if parameters.isWebpage {
                    controller = APSingleResourceController(account: account, wrapper: APSingleWrapper(resource: parameters.resource, name: tr(L10n.audioControllerVoiceMessage), performer: parent.author?.displayTitle, id: parent.chatStableId), streamable: false)
                } else {
                    controller = APChatVoiceController(account: account, peerId: parent.id.peerId, index: MessageIndex(parent))
                }
                parameters.showPlayer(controller)
                controller.start()
                addGlobalAudioToVisible()
            }
        }
    }
    
    var wBackgroundColor:NSColor {
        if let parameters = parameters {
            return parameters.presentation.waveformBackground
        }
        return theme.colors.grayIcon.withAlphaComponent(0.7)
    } 
    var wForegroundColor:NSColor {
        if let parameters = parameters {
            return parameters.presentation.waveformForeground
        }
        return theme.colors.blueFill
    }
    
    override func checkState() {
        super.checkState()
   
        
        if  let parameters = parameters as? ChatMediaVoiceLayoutParameters {
            if let parent = parent, let controller = globalAudio, let song = controller.currentSong {
                if song.entry.isEqual(to: parent) {
                    

                    switch song.state {
                    case let .playing(data):
                        waveformView.set(foregroundColor: wForegroundColor, backgroundColor: wBackgroundColor)
                        let width = floorToScreenPixels(scaleFactor: backingScaleFactor, parameters.waveformWidth * CGFloat(data.progress))
                        waveformView.foregroundClipingView.change(size: NSMakeSize(width, waveformView.frame.height), animated: data.animated)
                        let layout = parameters.duration(for: data.current)
                        layout.measure(width: frame.width - 50)
                        durationView.update(layout)
                        break
                    case let .fetching(progress, animated):
                        waveformView.set(foregroundColor: wForegroundColor, backgroundColor: wBackgroundColor)
                        let width = floorToScreenPixels(scaleFactor: backingScaleFactor, parameters.waveformWidth * CGFloat(progress))
                        waveformView.foregroundClipingView.change(size: NSMakeSize(width, waveformView.frame.height), animated: animated)
                        durationView.update(parameters.durationLayout)
                    case .stoped, .waiting:
                        waveformView.set(foregroundColor: isIncomingConsumed ? wBackgroundColor : wForegroundColor, backgroundColor: wBackgroundColor)
                        waveformView.foregroundClipingView.change(size: NSMakeSize(parameters.waveformWidth, waveformView.frame.height), animated: false)
                        durationView.update(parameters.durationLayout)
                    case let .paused(data):
                        waveformView.set(foregroundColor: wForegroundColor, backgroundColor: wBackgroundColor)
                        let width = floorToScreenPixels(scaleFactor: backingScaleFactor, parameters.waveformWidth * CGFloat(data.progress))
                        waveformView.foregroundClipingView.change(size: NSMakeSize(width, waveformView.frame.height), animated: data.animated)
                        let layout = parameters.duration(for: data.current)
                        layout.measure(width: frame.width - 50)
                        durationView.update(layout)
                    }
                    
                } else {
                    waveformView.set(foregroundColor: isIncomingConsumed ? wBackgroundColor : wForegroundColor, backgroundColor: wBackgroundColor)
                    waveformView.foregroundClipingView.change(size: NSMakeSize(parameters.waveformWidth, waveformView.frame.height), animated: false)
                    durationView.update(parameters.durationLayout)
                }
            } else {
                waveformView.foregroundClipingView.change(size: NSMakeSize(parameters.waveformWidth, waveformView.frame.height), animated: false)
                durationView.update(parameters.durationLayout)
            }
            needsLayout = true

        }
        
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        
        if acceptDragging, let parent = parent, let controller = globalAudio, let song = controller.currentSong {
            if song.entry.isEqual(to: parent) {
                let point = waveformView.convert(event.locationInWindow, from: nil)
                let progress = Float(point.x/waveformView.frame.width)
                switch song.state {
                case .playing:
                    _ = controller.pause()
                    playAfterDragging = true
                default:
                    break
                }
                controller.set(trackProgress: progress)
            } else {
                super.mouseDragged(with: event)
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        acceptDragging = waveformView.mouseInside()
        if !acceptDragging {
            super.mouseDown(with: event)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if acceptDragging && playAfterDragging {
            _ = globalAudio?.play()
        }
        playAfterDragging = false
        acceptDragging = false
    }
    
    override func update(with media: Media, size: NSSize, account: Account, parent: Message?, table: TableView?, parameters: ChatMediaLayoutParameters?, animated: Bool = false, positionFlags: GroupLayoutPositionFlags? = nil) {
        super.update(with: media, size: size, account: account, parent: parent, table: table, parameters: parameters, animated: animated, positionFlags: positionFlags)
        
        
        var updatedStatusSignal: Signal<MediaResourceStatus, NoError>
        
        let file:TelegramMediaFile = media as! TelegramMediaFile
 
        if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
            updatedStatusSignal = combineLatest(chatMessageFileStatus(account: account, file: file), account.pendingMessageManager.pendingMessageStatus(parent.id))
                |> map { resourceStatus, pendingStatus -> MediaResourceStatus in
                    if let pendingStatus = pendingStatus {
                        return .Fetching(isActive: true, progress: pendingStatus.progress)
                    } else {
                        return resourceStatus
                    }
                } |> deliverOnMainQueue
        } else {
            updatedStatusSignal = chatMessageFileStatus(account: account, file: file) |> deliverOnMainQueue
        }
        
        self.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak self] status in
            if let strongSelf = self {
                strongSelf.fetchStatus = status
                
                switch status {
                case let .Fetching(_, progress):
                    strongSelf.progressView.state = .Fetching(progress: progress, force: false)
                case .Remote:
                    strongSelf.progressView.state = .Remote
                case .Local:
                    strongSelf.progressView.state = .Play
                }
            }
        }))
        
        if let parameters = parameters as? ChatMediaVoiceLayoutParameters {
            waveformView.waveform = parameters.waveform
            
            waveformView.set(foregroundColor: isIncomingConsumed ? wBackgroundColor : wForegroundColor, backgroundColor: wBackgroundColor)
            checkState()
        }
        
        
        
        needsLayout = true
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if let parent = parent,let parameters = parameters as? ChatMediaVoiceLayoutParameters  {
            for attr in parent.attributes {
                if let attr = attr as? ConsumableContentMessageAttribute {
                    if !attr.consumed {
                        let center = floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height / 2.0)
                        ctx.setFillColor(parameters.presentation.activityBackground.cgColor)
                        ctx.fillEllipse(in: NSMakeRect(leftInset + parameters.durationLayout.layoutSize.width + 3, center + 8, 5, 5))
                    }
                    break
                }
            }
        }
    }
    

    override func layout() {
        super.layout()
        let center = floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height / 2.0)
        if let parameters = parameters as? ChatMediaVoiceLayoutParameters {
            waveformView.setFrameSize(parameters.waveformWidth, waveformView.frame.height)
        }
        waveformView.setFrameOrigin(leftInset,center - waveformView.frame.height - 2)
        durationView.setFrameOrigin(leftInset,center + 2)
    }
    
}
