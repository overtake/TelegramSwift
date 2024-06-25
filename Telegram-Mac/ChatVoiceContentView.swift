//
//  ChatVoiceContentView.swift
//  TelegramMac
//
//  Created by keepcoder on 21/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import TelegramCore

import TGUIKit
import SwiftSignalKit


class ChatVoiceContentView: ChatAudioContentView {
    
    private var transcribeControl: VoiceTranscriptionControl?

    var isIncomingConsumed:Bool {
        var isConsumed:Bool = false
        if let parent = parent, let attr = parent.consumableContent {
            isConsumed = attr.consumed
        }
        return isConsumed
    }
    
    let waveformView:AudioWaveformView
    private var acceptDragging: Bool = false
    private var playAfterDragging: Bool = false
    private var transcribeAudio: TranscribeAudioTextView?

    private var downloadingView: RadialProgressView?
    
    private var unreadView: View?
    private var badgeView: SingleTimeVoiceBadgeView?
    
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
        if let parameters = parameters as? ChatMediaVoiceLayoutParameters, let context = context, let parent = parent  {
            if parent.autoclearTimeout != nil, parent.id.peerId.namespace != Namespaces.Peer.SecretChat {
                SingleTimeMediaViewer.show(context: context, message: parent)
            } else if let controller = context.sharedContext.getAudioPlayer(), controller.playOrPause(parent.id) {
                
            } else {
                let controller:APController
                if parameters.isWebpage {
                    controller = APSingleResourceController(context: context, wrapper: APSingleWrapper(resource: parameters.resource, name: strings().audioControllerVoiceMessage, performer: parent.author?.displayTitle, duration: parameters.duration, id: parent.chatStableId), streamable: false, volume: FastSettings.volumeRate)
                } else {
                    controller = APChatVoiceController(context: context, chatLocationInput: parameters.chatLocationInput(parent), mode: parameters.chatMode, index: MessageIndex(parent), volume: FastSettings.volumeRate)
                }
                parameters.showPlayer(controller)
                controller.start()
            }
        }
    }
    
    var wBackgroundColor:NSColor {
        if let parameters = parameters {
            return parameters.presentation.grayText.withAlphaComponent(0.4)
        }
        return theme.colors.grayIcon.withAlphaComponent(0.7)
    } 
    var wForegroundColor:NSColor {
        if let parameters = parameters {
            return parameters.presentation.waveformForeground
        }
        return theme.colors.accent
    }
    
    override func checkState(animated: Bool) {
        super.checkState(animated: animated)
   
        
        if  let parameters = parameters as? ChatMediaVoiceLayoutParameters {
            if let parent = parent, let controller = context?.sharedContext.getAudioPlayer(), let song = controller.currentSong {
                if song.entry.isEqual(to: parent) {
                    switch song.state {
                    case let .playing(current, _, progress):
                        waveformView.set(foregroundColor: wForegroundColor, backgroundColor: wBackgroundColor)
                        let width = floorToScreenPixels(backingScaleFactor, parameters.waveformWidth * CGFloat(progress))
                        waveformView.foregroundClipingView.change(size: NSMakeSize(width, waveformView.frame.height), animated: animated && !acceptDragging)
                        let layout = parameters.duration(for: current)
                        layout.measure(width: frame.width - 50)
                        durationView.update(layout)
                        break
                    case let .fetching(progress):
                        waveformView.set(foregroundColor: wForegroundColor, backgroundColor: wBackgroundColor)
                        let width = floorToScreenPixels(backingScaleFactor, parameters.waveformWidth * CGFloat(progress))
                        waveformView.foregroundClipingView.change(size: NSMakeSize(width, waveformView.frame.height), animated: animated && !acceptDragging)
                        durationView.update(parameters.durationLayout)
                    case .stoped, .waiting:
                        waveformView.set(foregroundColor: isIncomingConsumed ? wBackgroundColor : wForegroundColor, backgroundColor: wBackgroundColor)
                        waveformView.foregroundClipingView.change(size: NSMakeSize(parameters.waveformWidth, waveformView.frame.height), animated: false)
                        durationView.update(parameters.durationLayout)
                    case let .paused(current, _, progress):
                        waveformView.set(foregroundColor: wForegroundColor, backgroundColor: wBackgroundColor)
                        let width = floorToScreenPixels(backingScaleFactor, parameters.waveformWidth * CGFloat(progress))
                        waveformView.foregroundClipingView.change(size: NSMakeSize(width, waveformView.frame.height), animated: animated && !acceptDragging)
                        let layout = parameters.duration(for: current)
                        layout.measure(width: frame.width - 50)
                        durationView.update(layout)
                    }
                    
                } else {
                    waveformView.set(foregroundColor: isIncomingConsumed ? wBackgroundColor : wForegroundColor, backgroundColor: wBackgroundColor)
                    waveformView.foregroundClipingView.change(size: NSMakeSize(parameters.waveformWidth, waveformView.frame.height), animated: false)
                    durationView.update(parameters.durationLayout)
                }
            } else {
                waveformView.set(foregroundColor: isIncomingConsumed ? wBackgroundColor : wForegroundColor, backgroundColor: wBackgroundColor)
                waveformView.foregroundClipingView.change(size: NSMakeSize(parameters.waveformWidth, waveformView.frame.height), animated: false)
                parameters.durationLayout.measure(width: frame.width - 50)
                durationView.update(parameters.durationLayout)
            }
            needsLayout = true

        }
        
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        
        if acceptDragging, let parent = parent, let controller = context?.sharedContext.getAudioPlayer(), let song = controller.currentSong {
            if song.entry.isEqual(to: parent) {
                let point = waveformView.convert(event.locationInWindow, from: nil)
                let progress = Float(min(max(point.x, 0), waveformView.frame.width)/waveformView.frame.width)
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
            _ = context?.sharedContext.getAudioPlayer()?.play()
        }
        playAfterDragging = false
        acceptDragging = false
    }
    
    override func update(with media: Media, size: NSSize, context: AccountContext, parent: Message?, table: TableView?, parameters: ChatMediaLayoutParameters?, animated: Bool = false, positionFlags: LayoutPositionFlags? = nil, approximateSynchronousValue: Bool = false) {
        super.update(with: media, size: size, context: context, parent: parent, table: table, parameters: parameters, animated: animated, positionFlags: positionFlags)
        
        
        var updatedStatusSignal: Signal<MediaResourceStatus, NoError>
        
        let file:TelegramMediaFile = media as! TelegramMediaFile
        
      //  self.progressView.state = .None
 
        if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
            updatedStatusSignal = combineLatest(chatMessageFileStatus(context: context, message: parent, file: file), context.account.pendingMessageManager.pendingMessageStatus(parent.id))
                |> map { resourceStatus, pendingStatus -> MediaResourceStatus in
                    if let pendingStatus = pendingStatus.0 {
                        return .Fetching(isActive: true, progress: pendingStatus.progress.progress)
                    } else {
                        return resourceStatus
                    }
                }
        } else if let parent = parent {
            updatedStatusSignal = chatMessageFileStatus(context: context, message: parent, file: file, approximateSynchronousValue: approximateSynchronousValue)
        } else {
            updatedStatusSignal = context.account.postbox.mediaBox.resourceStatus(file.resource)
        }
        
        self.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak self] status in
            if let strongSelf = self {
                strongSelf.fetchStatus = status
                
//                var state: RadialProgressState? = nil
//                switch status {
//                case let .Fetching(_, progress):
//                    state = .Fetching(progress: progress, force: false)
//                case .Paused:
//                    state = .Remote
//                case .Remote:
//                    state = .Remote
//                case .Local:
//                    break
//                }
//                if let state = state {
//                    let current: RadialProgressView
//                    if let value = strongSelf.downloadingView {
//                        current = value
//                    } else {
//                        current = RadialProgressView(theme: strongSelf.progressView.theme, twist: true, size: NSMakeSize(40, 40))
//                        current.fetchControls = strongSelf.fetchControls
//                        strongSelf.downloadingView = current
//                     //   strongSelf.addSubview(current)
//                        current.frame = strongSelf.progressView.frame
//                        
//                        if !approximateSynchronousValue && animated {
//                            current.layer?.animateAlpha(from: 0.2, to: 1, duration: 0.3)
//                        }
//                    }
//                    current.state = state
//                } else if let download = strongSelf.downloadingView {
//                    download.state = .Fetching(progress: 1.0, force: false)
//                    strongSelf.downloadingView = nil
//                    download.layer?.animateAlpha(from: 1, to: 0.2, duration: 0.25, removeOnCompletion: false, completion: { [weak download] _ in
//                        download?.removeFromSuperview()
//                    })
//                }
                
                if let parent = parent, let _ = parent.autoclearTimeout, parent.id.namespace == Namespaces.Message.Cloud, status == .Local, let parameters = parameters {
                    let current: SingleTimeVoiceBadgeView
                    if let view = strongSelf.badgeView {
                        current = view
                    } else {
                        current = SingleTimeVoiceBadgeView(frame: NSMakeRect(strongSelf.progressView.frame.maxX - 15, strongSelf.waveformView.frame.maxY + 2, 20, 20))
                        strongSelf.addSubview(current)
                        strongSelf.badgeView = current
                        current.isEventLess = true
                        current.update(size: NSMakeSize(30, 30), text: "1", foreground: parameters.presentation.activityForeground, background: parameters.presentation.activityBackground, blendMode: parameters.presentation.blendingMode)
                        
                        if animated {
                            current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                            current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
                        }
                    }
                    strongSelf.progressView.badge = NSMakeRect(24, 19, 22, 22)
                } else if let view = strongSelf.badgeView {
                    performSubviewRemoval(view, animated: animated, scale: true)
                    strongSelf.badgeView = nil
                    strongSelf.progressView.badge = nil
                }
                strongSelf.needsLayout = true
            }
        }))
        
        
        if let parameters = parameters as? ChatMediaVoiceLayoutParameters {
            waveformView.waveform = parameters.waveform
            
            checkState(animated: animated)

            
            fillTranscribedAudio(parameters.transcribeData, parameters: parameters, animated: animated)
            
            if let parent = parent, let attr = parent.consumableContent, !attr.consumed  {
                let current: View
                if let view = self.unreadView {
                    current = view
                } else {
                    current = View(frame: NSMakeRect(leftInset + parameters.durationLayout.layoutSize.width + 3, waveformView.frame.maxY + 10, 5, 5))
                    current.isDynamicColorUpdateLocked = true
                    self.addSubview(current)
                    self.unreadView = current
                    
                    if animated {
                        current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
                    }
                }
                current.backgroundColor = parameters.presentation.activityBackground
                current.layer?.cornerRadius = current.frame.height / 2
            } else if let view = self.unreadView {
                performSubviewRemoval(view, animated: animated, scale: true)
                self.unreadView = nil
            }
            
           

        }
        

        
        needsLayout = true
    }
    
    func fillTranscribedAudio(_ data:ChatMediaVoiceLayoutParameters.TranscribeData?, parameters: ChatMediaVoiceLayoutParameters, animated: Bool) -> Void {
        if let data = data {
            var removeTransribeControl = true
            let controlState: VoiceTranscriptionControl.TranscriptionState?
            switch data.state {
            case .possible:
                controlState = .possible(false)
            case .locked:
                controlState = .locked
            case let .state(inner):
                switch inner {
                case .collapsed:
                    controlState = .collapsed(false)
                case .revealed:
                    controlState = .expanded(data.isPending)
                case .loading:
                    controlState = .possible(true)
                }
            }
            if let controlState = controlState {
                
                removeTransribeControl = false
                
                let control: VoiceTranscriptionControl
                if let view = self.transcribeControl {
                    control = view
                } else {
                    control = VoiceTranscriptionControl(frame: NSMakeRect(0, 0, 25, 25))
                    addSubview(control)
                    control.scaleOnClick = true
                    self.transcribeControl = control
                    
                    control.set(handler: { [weak self] _ in
                        if let parameters = self?.parameters as? ChatMediaVoiceLayoutParameters {
                            parameters.transcribe()
                        }
                    }, for: .Click)
                }
                control.update(state: controlState, color: data.backgroundColor, activityBackground: parameters.presentation.activityBackground, blurBackground: nil, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
            }
            
            if removeTransribeControl, let view = transcribeControl {
                self.transcribeControl = nil
                performSubviewRemoval(view, animated: animated)
            }
            
            
        }
        if let data = data, let size = data.size {
            let current: TranscribeAudioTextView
            if let view = self.transcribeAudio {
                current = view
            } else {
                current = TranscribeAudioTextView(frame: NSMakeRect(0, 45, size.width, size.height))
                self.transcribeAudio = current
                addSubview(current)
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            let transition: ContainedViewLayoutTransition
            if animated {
                transition = .animated(duration: 0.2, curve: .easeOut)
            } else {
                transition = .immediate
            }
            transition.updateFrame(view: current, frame: NSMakeRect(0, 45, size.width, size.height))
            current.update(data: data, animated: animated)
            current.updateLayout(size: size, transition: transition)
        } else if let view = self.transcribeAudio {
            performSubviewRemoval(view, animated: animated)
            self.transcribeAudio = nil
        }
    }
    
    
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        let center = floorToScreenPixels(backingScaleFactor, 40 / 2.0)
        if let parameters = parameters as? ChatMediaVoiceLayoutParameters {
            transition.updateFrame(view: waveformView, frame: NSMakeRect(leftInset, center - waveformView.frame.height - 2, parameters.waveformWidth, waveformView.frame.height))
            waveformView.setFrameSize(parameters.waveformWidth, waveformView.frame.height)
        }
        transition.updateFrame(view: durationView, frame: NSMakeRect(leftInset, center + 2, durationView.frame.width, durationView.frame.height))
        
        if let view = self.unreadView {
            transition.updateFrame(view: view, frame: NSMakeRect(durationView.frame.maxX + 3, waveformView.frame.maxY + 10, view.frame.width, view.frame.height))
        }
        
        if let view = self.badgeView {
            transition.updateFrame(view: view, frame: NSMakeRect(progressView.frame.maxX - 15, waveformView.frame.maxY + 2, view.frame.width, view.frame.height))
        }
        
        if let control = transcribeControl {
            transition.updateFrame(view: control, frame: NSMakeRect(waveformView.frame.maxX + 10, 0, control.frame.width, control.frame.height))
        }
        if let view = self.transcribeAudio {
            transition.updateFrame(view: view, frame: NSMakeRect(0, 45, view.frame.width, view.frame.height))
            view.updateLayout(size: view.frame.size, transition: transition)
        }
    }

    
}
