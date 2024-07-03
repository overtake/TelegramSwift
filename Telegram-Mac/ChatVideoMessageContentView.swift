//
//  ChatVideoMessageRowView.swift
//  Telegram
//
//  Created by keepcoder on 13/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import TelegramMedia
import Postbox
import SwiftSignalKit

/*
 func songDidStopPlaying(song:APSongItem, for controller:APController, animated: Bool) {
 if song.stableId == parent?.chatStableId {
 updatePlayerIfNeeded()
 }
 }
 func playerDidChangedTimebase(song:APSongItem, for controller:APController, animated: Bool) {
 if song.stableId == parent?.chatStableId {
 if acceptVisibility && !player.isHasPath {
 player.set(path: path, timebase: controller.timebase)
 } else {
 player.reset(with: controller.timebase)
 }
 }
 }
 */


private let instantVideoMutedThumb = generateImage(NSMakeSize(30, 30), contextGenerator: { size, ctx in
    ctx.clear(NSMakeRect(0, 0, 30, 30))
    ctx.setFillColor(NSColor.blackTransparent.cgColor)
    ctx.round(size, size.width / 2.0)
    ctx.fill(CGRect(origin: CGPoint(), size: size))
    let icon = #imageLiteral(resourceName: "Icon_VideoMessageMutedIcon").precomposed()
    ctx.draw(icon, in: NSMakeRect(floorToScreenPixels(System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height))
})

final class VideoMessageCorner : View {
    
    override var backgroundColor: NSColor {
        set {
            super.backgroundColor = .clear
            borderBackground = newValue
        }
        get {
            return super.backgroundColor
        }
    }
    private var borderBackground: NSColor = .black {
        didSet {
            needsLayout = true
        }
    }
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        //ctx.round(frame.size, frame.size.height / 2)
        ctx.setStrokeColor(theme.colors.background.cgColor)
        ctx.setLineWidth(2.0)
        ctx.setLineCap(.round)
        
        ctx.strokeEllipse(in: NSMakeRect(1, 1, bounds.width - 2, bounds.height - 2))
    }
}


class ChatVideoMessageContentView: ChatMediaContentView, APDelegate {

    private var transcribeControl: VoiceTranscriptionControl?

    
    private let stateThumbView = ImageView()
    private var player:GIFPlayerView = GIFPlayerView()
    private var progressView:RadialProgressView?
    private let playingProgressView: RadialProgressView = RadialProgressView(theme:RadialProgressTheme(backgroundColor: .clear, foregroundColor: NSColor.white.withAlphaComponent(0.8), lineWidth: 3), twist: false)
    private let statusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private let playerDisposable = MetaDisposable()
    private let updateMouseDisposable = MetaDisposable()
    
    private var inkView: MediaInkView? = nil
    
    private var badgeView: SingleTimeVoiceBadgeView?
    
    private var durationView:ChatMessageAccessoryView = ChatMessageAccessoryView(frame: NSZeroRect)
    private let videoCorner: VideoMessageCorner = VideoMessageCorner()
    private var data:AVGifData? {
        didSet {
            updatePlayerIfNeeded()
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(player)
        videoCorner.userInteractionEnabled = false
        playingProgressView.userInteractionEnabled = false
        stateThumbView.image = instantVideoMutedThumb
        stateThumbView.sizeToFit()
        player.addSubview(stateThumbView)
        player.addSubview(videoCorner)
        addSubview(playingProgressView)
        addSubview(durationView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
    
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
    
    
    override func clean() {
        statusDisposable.dispose()
        playerDisposable.dispose()
        removeNotificationListeners()
    }
    
    
    override func cancel() {
        fetchDisposable.set(nil)
        statusDisposable.set(nil)
    }
    
    private var singleWrapper:APSingleWrapper? {
        if let media = media as? TelegramMediaFile {
            return APSingleWrapper(resource: media.resource, mimeType: media.mimeType, name: strings().audioControllerVideoMessage, performer: parent?.author?.displayTitle, duration: media.duration, id: media.fileId)
        }
        return nil
    }
    
    override func open() {
        if let parent = parent, let context = context {
            if let parameters = parameters as? ChatMediaVideoMessageLayoutParameters {
                if parent.autoclearTimeout != nil, parent.id.peerId.namespace != Namespaces.Peer.SecretChat {
                    SingleTimeMediaViewer.show(context: context, message: parent)
                } else if let controller = context.sharedContext.getAudioPlayer(), controller.playOrPause(parent.id) {
                } else {
                    let controller:APController
                    if parameters.isWebpage, let wrapper = singleWrapper {
                        controller = APSingleResourceController(context: context, wrapper: wrapper, streamable: false)
                    } else {
                        controller = APChatVoiceController(context: context, chatLocationInput: parameters.chatLocationInput(parent), mode: parameters.chatMode, index: MessageIndex(parent), volume: FastSettings.volumeRate)
                    }
                    
                    parameters.showPlayer(controller)
                    controller.start()
                }
                
            }
        }
    }
    
    func songDidChanged(song: APSongItem, for controller: APController, animated: Bool) {
        updateSongState()
    }
    func songDidChangedState(song: APSongItem, for controller: APController, animated: Bool) {
       updateSongState()
    }
    
    private func updateSongState() {
        if let parent = parent, let controller = context?.sharedContext.getAudioPlayer(), let song = controller.currentSong, let parameters = parameters as? ChatMediaVideoMessageLayoutParameters {
            var singleEqual: Bool = false
            if let single = singleWrapper {
                singleEqual = song.entry.isEqual(to: single)
            }
            if song.entry.isEqual(to: parent) || singleEqual {
                switch song.state {
                case let .playing(current, _, progress):
                    playingProgressView.state = .ImpossibleFetching(progress: Float(progress), force: false)
                    durationView.updateText(String.durationTransformed(elapsed: Int(current)), maxWidth: 50, status: nil, isStreamable: false, isUnread: !isIncomingConsumed, animated: true, isVideoMessage: true)
                    stateThumbView.isHidden = true
                case .stoped, .waiting, .fetching:
                    playingProgressView.state = .None
                    durationView.updateText(String.durationTransformed(elapsed: parameters.duration), maxWidth: 50, status: nil, isStreamable: false, isUnread: !isIncomingConsumed, animated: true, isVideoMessage: true)
                    stateThumbView.isHidden = false
                case let .paused(current, _, progress):
                    playingProgressView.state = .ImpossibleFetching(progress: Float(progress), force: true)
                    durationView.updateText(String.durationTransformed(elapsed: Int(current)), maxWidth: 50, status: nil, isStreamable: false, isUnread: !isIncomingConsumed, animated: true, isVideoMessage: true)
                    stateThumbView.isHidden = false
                }
                
            } else {
                playingProgressView.state = .None
                durationView.updateText(String.durationTransformed(elapsed: parameters.duration), maxWidth: 50, status: nil, isStreamable: false, isUnread: !isIncomingConsumed, animated: true, isVideoMessage: true)
                stateThumbView.isHidden = false
            }
        } else if let parameters = parameters as? ChatMediaVideoMessageLayoutParameters {
            playingProgressView.state = .None
            durationView.updateText(String.durationTransformed(elapsed: parameters.duration), maxWidth: 50, status: nil, isStreamable: false, isUnread: !isIncomingConsumed, animated: true, isVideoMessage: true)
            stateThumbView.isHidden = false
        }
    }
    
    func songDidStartPlaying(song:APSongItem, for controller:APController, animated: Bool) {
        if song.stableId == parent?.chatStableId {
            stateThumbView.isHidden = true
        } else if let wrapper = singleWrapper, song.entry.isEqual(to: wrapper) {
            stateThumbView.isHidden = true
        }
    }
    func songDidStopPlaying(song:APSongItem, for controller:APController, animated: Bool) {
        if song.stableId == parent?.chatStableId {
            player.reset(with: nil)
            stateThumbView.isHidden = false
        } else if let wrapper = singleWrapper, song.entry.isEqual(to: wrapper) {
            player.reset(with: nil)
            stateThumbView.isHidden = false
        }
    }
    func playerDidChangedTimebase(song:APSongItem, for controller:APController, animated: Bool) {
        if song.stableId == parent?.chatStableId {
            player.reset(with: controller.timebase)
        } else if let wrapper = singleWrapper, song.entry.isEqual(to: wrapper) {
            player.reset(with: controller.timebase)
        }
    }
    
    
    func audioDidCompleteQueue(for controller:APController, animated: Bool) {
        if let parameters = parameters as? ChatMediaVideoMessageLayoutParameters {
            playingProgressView.state = .None
            durationView.updateText(String.durationTransformed(elapsed: parameters.duration), maxWidth: 50, status: nil, isStreamable: false, isUnread: !isIncomingConsumed, animated: true, isVideoMessage: true)
            stateThumbView.isHidden = false
        }
    }
    
    func checkState(animated: Bool) {
        
    }
    
    
    
    
    override func fetch(userInitiated: Bool) {
        if let context = context, let media = media as? TelegramMediaFile, let parent = parent {
            fetchDisposable.set(messageMediaFileInteractiveFetched(context: context, messageId: parent.id, messageReference: .init(parent), file: media, userInitiated: false).start())
        }
    }
    
    override func layout() {
        super.layout()
        player.frame = bounds
        videoCorner.frame = NSMakeRect(bounds.minX - 0.5, bounds.minY - 0.5, bounds.width + 1.0, bounds.height + 1.0)
        playingProgressView.frame = NSMakeRect(1.5, 1.5, bounds.width - 3, bounds.height - 3)
        progressView?.center()
        stateThumbView.centerX(y: 10)
        
        if let control = transcribeControl, let presentation = self.parameters?.presentation {
            if presentation.isBubble {
                if presentation.isIncoming {
                    control.setFrameOrigin(NSMakePoint(player.frame.maxX - control.frame.width, player.frame.maxY - control.frame.height))
                    durationView.setFrameOrigin(0, frame.height - durationView.frame.height)
                } else {
                    control.setFrameOrigin(NSMakePoint(0, player.frame.maxY - control.frame.height))
                    durationView.setFrameOrigin(control.frame.maxX + 2, frame.height - durationView.frame.height)
                }
            } else {
                control.setFrameOrigin(NSMakePoint(player.frame.maxX - control.frame.width, player.frame.maxY - control.frame.height))
                durationView.setFrameOrigin(0, frame.height - durationView.frame.height)
            }
        } else {
            durationView.setFrameOrigin(0, frame.height - durationView.frame.height)
        }
    }
    
    
    
    func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    var acceptVisibility:Bool {
        return window != nil && window!.isKeyWindow && !NSIsEmptyRect(visibleRect) && !isDynamicContentLocked
    }
    
    override func viewDidUpdatedDynamicContent() {
        super.viewDidUpdatedDynamicContent()
        updatePlayerIfNeeded()
    }
    
    @objc func updatePlayerIfNeeded() {
        let timebase:CMTimebase? = context?.sharedContext.getAudioPlayer()?.currentSong?.stableId == parent?.chatStableId ? context?.sharedContext.getAudioPlayer()?.timebase : nil
        
        var accept = acceptVisibility
        if isLite(.video) && timebase == nil {
            accept = accept && mouseInside()
        }
        
        player.set(data: accept ? data : nil, timebase: timebase)
        
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        self.updatePlayerIfNeeded()
    }
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        self.updatePlayerIfNeeded()
    }
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        self.updatePlayerIfNeeded()
    }
    
    func updateListeners() {
        if let window = window {
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didResignKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: table?.clipView)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.frameDidChangeNotification, object: table?.view)

        } else {
            removeNotificationListeners()
        }
    }
    
    override func viewDidMoveToWindow() {
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    deinit {
        player.set(data: nil)
        updateMouseDisposable.dispose()
        
    }
    
    override func update(with media: Media, size: NSSize, context: AccountContext, parent: Message?, table: TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool = false, positionFlags: LayoutPositionFlags? = nil, approximateSynchronousValue: Bool = false) {
        let mediaUpdated = self.media == nil || !self.media!.isSemanticallyEqual(to: media)
        
        
        super.update(with: media, size: size, context: context, parent:parent,table:table, parameters:parameters, animated: animated, positionFlags: positionFlags)

        updateListeners()
        
        if let media = media as? TelegramMediaFile {
            if let parameters = parameters as? ChatMediaVideoMessageLayoutParameters {
                updateSongState()
                fillTranscribedAudio(parameters.transcribeData, parameters: parameters, animated: animated)
            }
            

            
            if mediaUpdated {
                
                context.sharedContext.getAudioPlayer()?.add(listener: self)
                
                player.layer?.cornerRadius = size.height / 2
                data = nil
                var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?
                let arguments = TransformImageArguments(corners: ImageCorners(radius:0), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets())
                
                player.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: backingScaleFactor), clearInstantly: mediaUpdated)

                player.setSignal(chatMessageVideo(postbox: context.account.postbox, fileReference: parent != nil ? FileMediaReference.message(message: MessageReference(parent!), media: media) : FileMediaReference.standalone(media: media), scale: backingScaleFactor), cacheImage: { [weak media] result in
                    if let media = media {
                        cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale)
                    }
                })

                
                player.set(arguments: arguments)
                
                if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                    updatedStatusSignal = combineLatest(chatMessageFileStatus(context: context, message: parent, file: media), context.account.pendingMessageManager.pendingMessageStatus(parent.id))
                        |> map { resourceStatus, pendingStatus -> MediaResourceStatus in
                            if let pendingStatus = pendingStatus.0 {
                                return .Fetching(isActive: true, progress: pendingStatus.progress.progress)
                            } else {
                                return resourceStatus
                            }
                        } |> deliverOnMainQueue
                } else {
                    if let parent = parent {
                        updatedStatusSignal = chatMessageFileStatus(context: context, message: parent, file: media, approximateSynchronousValue: approximateSynchronousValue)
                    } else {
                        updatedStatusSignal = context.account.postbox.mediaBox.resourceStatus(media.resource)
                    }
                }
                
                if let updatedStatusSignal = updatedStatusSignal {
                    
                    
                    self.statusDisposable.set((combineLatest(updatedStatusSignal, context.account.postbox.mediaBox.resourceData(media.resource)) |> deliverOnResourceQueue |> map {  status, resource -> (MediaResourceStatus, AVGifData?) in
                        if resource.complete {
                            return (status, AVGifData.dataFrom(resource.path))
                        } else if status == .Local, let resource = media.resource as? LocalFileReferenceMediaResource {
                            return (status, AVGifData.dataFrom(resource.localFilePath))
                        } else {
                            return (status, nil)
                        }
                    } |> deliverOnMainQueue).start(next: { [weak self] status,data in
                        if let strongSelf = self {
                            
                            strongSelf.data = data
                            
                            let isSpoiler = parent?.autoclearTimeout != nil && parent?.id.peerId.isSecretChat == false
                            
                            strongSelf.fetchStatus = status
                            if case .Local = status, !isSpoiler {
                                if let progressView = strongSelf.progressView {
                                    progressView.state = .Fetching(progress: 1.0, force: false)
                                    strongSelf.progressView = nil
                                    progressView.layer?.animateAlpha(from: 1, to: 0, duration: 0.25, timingFunction: .linear, removeOnCompletion: false, completion: { [weak progressView] completed in
                                        if completed {
                                            progressView?.removeFromSuperview()
                                        }
                                    })
                                }
                                
                            } else {
                                if strongSelf.progressView == nil {
                                    let progressView = RadialProgressView()
                                    progressView.frame = CGRect(origin: CGPoint(), size: CGSize(width: 40.0, height: 40.0))
                                    strongSelf.progressView = progressView
                                    strongSelf.addSubview(progressView)
                                    strongSelf.progressView?.center()
                                    strongSelf.progressView?.fetchControls = strongSelf.fetchControls
                                }
                            }
                            
                            switch status {
                            case let .Fetching(_, progress), let .Paused(progress):
                                strongSelf.progressView?.state = .Fetching(progress: progress, force: false)
                            case .Local:
                                strongSelf.progressView?.state = .Play
                            case .Remote:
                                strongSelf.progressView?.state = .Remote
                            }
                            
                            if isSpoiler {
                                let current: MediaInkView
                                if let view = strongSelf.inkView {
                                    current = view
                                } else {
                                    current = MediaInkView(frame: size.bounds)
                                    strongSelf.inkView = current
                                    
                                    let aboveView = strongSelf.progressView
                                    if let view = aboveView {
                                        strongSelf.addSubview(current, positioned: .below, relativeTo: view)
                                    } else {
                                        strongSelf.addSubview(current)
                                    }
                                    if animated {
                                        current.layer?.animateAlpha(from: 0.3, to: 1, duration: 0.2)
                                    }
                                }
                                
                                let image: TelegramMediaImage = TelegramMediaImage.init(imageId: media.fileId, representations: media.previewRepresentations, immediateThumbnailData: media.immediateThumbnailData, reference: nil, partialReference: nil, flags: TelegramMediaImageFlags())
                                let imageReference = parent != nil ? ImageMediaReference.message(message: MessageReference(parent!), media: image) : ImageMediaReference.standalone(media: image)
                                current.update(isRevealed: false, updated: mediaUpdated, context: context, imageReference: imageReference, size: size, positionFlags: nil, synchronousLoad: approximateSynchronousValue, isSensitive: false, payAmount: nil)
                                current.frame = size.bounds.insetBy(dx: 2, dy: 2)
                                current.layer?.cornerRadius = current.frame.height / 2
                                
                                current.isEventLess = true
                                current.userInteractionEnabled = false
                            } else if let view = strongSelf.inkView {
                                performSubviewRemoval(view, animated: animated)
                                strongSelf.inkView = nil
                            }
                            
                            if isSpoiler, let progressView = strongSelf.progressView, parent?.id.namespace == Namespaces.Message.Cloud {
                                let current: SingleTimeVoiceBadgeView
                                if let view = strongSelf.badgeView {
                                    current = view
                                } else {
                                    current = SingleTimeVoiceBadgeView(frame: NSMakeRect(progressView.frame.maxX - 15, progressView.frame.midY, 20, 20))
                                    strongSelf.addSubview(current)
                                    strongSelf.badgeView = current
                                    current.isEventLess = true
                                    current.update(size: NSMakeSize(30, 30), text: "1", foreground: .white, background: .blackTransparent, blendMode: .normal)
                                    
                                    if animated {
                                        current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                                        current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
                                    }
                                }
                                progressView.badge = NSMakeRect(24, 19, 22, 22)
                            } else if let view = strongSelf.badgeView {
                                performSubviewRemoval(view, animated: animated, scale: true)
                                strongSelf.badgeView = nil
                                strongSelf.progressView?.badge = nil
                            }
                        }
                    }))
                }
                
            }
            
        }
    }
    
    
    func fillTranscribedAudio(_ data:ChatMediaVoiceLayoutParameters.TranscribeData?, parameters: ChatMediaVideoMessageLayoutParameters, animated: Bool) -> Void {
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
                        if let parameters = self?.parameters as? ChatMediaVideoMessageLayoutParameters {
                            parameters.transcribe()
                        }
                    }, for: .Click)
                }
                control.update(state: controlState, color: data.backgroundColor, activityBackground: data.fontColor, blurBackground: parameters.presentation.isBubble && parameters.presentation.presentation.hasWallpaper ? theme.blurServiceColor : nil, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
            }
            
            if removeTransribeControl, let view = transcribeControl {
                self.transcribeControl = nil
                performSubviewRemoval(view, animated: animated)
            }
        }
    }
    
    override var contents: Any? {
        return player.layer?.contents
    }
    
    override func copy() -> Any {
        let view = View()
        view.backgroundColor = .clear
        let layer:CALayer = CALayer()
        layer.frame = NSMakeRect(0, visibleRect.minY == 0 ? 0 :  player.visibleRect.height - player.frame.height, player.frame.width,  player.frame.height)
        layer.contents = player.layer?.contents
        layer.masksToBounds = true
        view.frame = player.visibleRect
        layer.shouldRasterize = true
        layer.rasterizationScale = backingScaleFactor
        view.layer?.addSublayer(layer)
        return view
    }
    
    
}
