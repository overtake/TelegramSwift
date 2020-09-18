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
import SyncCore
import Postbox
import SwiftSignalKit

/*
 func songDidStopPlaying(song:APSongItem, for controller:APController) {
 if song.stableId == parent?.chatStableId {
 updatePlayerIfNeeded()
 }
 }
 func playerDidChangedTimebase(song:APSongItem, for controller:APController) {
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

    private let stateThumbView = ImageView()
    private var player:GIFPlayerView = GIFPlayerView()
    private var progressView:RadialProgressView?
    private let playingProgressView: RadialProgressView = RadialProgressView(theme:RadialProgressTheme(backgroundColor: .clear, foregroundColor: NSColor.white.withAlphaComponent(0.8), lineWidth: 3), twist: false)
    private let statusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private let playerDisposable = MetaDisposable()
    private let updateMouseDisposable = MetaDisposable()
    
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
            return APSingleWrapper(resource: media.resource, mimeType: media.mimeType, name: L10n.audioControllerVideoMessage, performer: parent?.author?.displayTitle, id: media.fileId)
        }
        return nil
    }
    
    override func open() {
        if let parent = parent, let context = context {
            if let parameters = parameters as? ChatMediaVideoMessageLayoutParameters {
                if let controller = globalAudio, let song = controller.currentSong, song.entry.isEqual(to: parent) {
                    controller.playOrPause()
                } else {
                    let controller:APController
                    if parameters.isWebpage, let wrapper = singleWrapper {
                        controller = APSingleResourceController(context: context, wrapper: wrapper, streamable: false)
                    } else {
                        controller = APChatVoiceController(context: context, chatLocationInput: parameters.chatLocationInput(), index: MessageIndex(parent))
                    }
                    
                    parameters.showPlayer(controller)
                    controller.start()
                }
                
            }
        }
    }
    
    func songDidChanged(song: APSongItem, for controller: APController) {
       
    }
    func songDidChangedState(song: APSongItem, for controller: APController) {
        if let parent = parent, let controller = globalAudio, let song = controller.currentSong, let parameters = parameters as? ChatMediaVideoMessageLayoutParameters {
            var singleEqual: Bool = false
            if let single = singleWrapper {
                singleEqual = song.entry.isEqual(to: single)
            }
            if song.entry.isEqual(to: parent) || singleEqual {
                switch song.state {
                case let .playing(data):
                    playingProgressView.state = .ImpossibleFetching(progress: Float(data.progress), force: false)
                    durationView.updateText(String.durationTransformed(elapsed: Int(data.current)), maxWidth: 50, status: nil, isStreamable: false, isUnread: !isIncomingConsumed, animated: true, isVideoMessage: true)
                    stateThumbView.isHidden = true
                case .stoped, .waiting, .fetching:
                    playingProgressView.state = .None
                    durationView.updateText(String.durationTransformed(elapsed: parameters.duration), maxWidth: 50, status: nil, isStreamable: false, isUnread: !isIncomingConsumed, animated: true, isVideoMessage: true)
                    stateThumbView.isHidden = false
                case let .paused(data):
                    playingProgressView.state = .ImpossibleFetching(progress: Float(data.progress), force: true)
                    durationView.updateText(String.durationTransformed(elapsed: Int(data.current)), maxWidth: 50, status: nil, isStreamable: false, isUnread: !isIncomingConsumed, animated: true, isVideoMessage: true)
                    stateThumbView.isHidden = false
                }
                
            } else {
                playingProgressView.state = .None
                durationView.updateText(String.durationTransformed(elapsed: parameters.duration), maxWidth: 50, status: nil, isStreamable: false, isUnread: !isIncomingConsumed, animated: true, isVideoMessage: true)
                stateThumbView.isHidden = false
            }
        }
    }
    
    func songDidStartPlaying(song:APSongItem, for controller:APController) {
        if song.stableId == parent?.chatStableId {
            stateThumbView.isHidden = true
        } else if let wrapper = singleWrapper, song.entry.isEqual(to: wrapper) {
            stateThumbView.isHidden = true
        }
    }
    func songDidStopPlaying(song:APSongItem, for controller:APController) {
        if song.stableId == parent?.chatStableId {
            player.reset(with: nil)
            stateThumbView.isHidden = false
        } else if let wrapper = singleWrapper, song.entry.isEqual(to: wrapper) {
            player.reset(with: nil)
            stateThumbView.isHidden = false
        }
    }
    func playerDidChangedTimebase(song:APSongItem, for controller:APController) {
        if song.stableId == parent?.chatStableId {
            player.reset(with: controller.timebase)
        } else if let wrapper = singleWrapper, song.entry.isEqual(to: wrapper) {
            player.reset(with: controller.timebase)
        }
    }
    
    
    func audioDidCompleteQueue(for controller:APController) {
        if let parameters = parameters as? ChatMediaVideoMessageLayoutParameters {
            playingProgressView.state = .None
            durationView.updateText(String.durationTransformed(elapsed: parameters.duration), maxWidth: 50, status: nil, isStreamable: false, isUnread: !isIncomingConsumed, animated: true, isVideoMessage: true)
            stateThumbView.isHidden = false
        }
    }
    
    func checkState() {
        
    }
    
    
    override func cancelFetching() {
        if let context = context, let media = media as? TelegramMediaFile, let parent = parent {
            messageMediaFileCancelInteractiveFetch(context: context, messageId: parent.id, fileReference: FileMediaReference.message(message: MessageReference(parent), media: media))
        }
    }
    
    override func fetch() {
        if let context = context, let media = media as? TelegramMediaFile, let parent = parent {
            fetchDisposable.set(messageMediaFileInteractiveFetched(context: context, messageId: parent.id, fileReference: FileMediaReference.message(message: MessageReference(parent), media: media)).start())
        }
    }
    
    override func layout() {
        super.layout()
        player.frame = bounds
        videoCorner.frame = NSMakeRect(bounds.minX - 0.5, bounds.minY - 0.5, bounds.width + 1.0, bounds.height + 1.0)
        playingProgressView.frame = NSMakeRect(1.5, 1.5, bounds.width - 3, bounds.height - 3)
        progressView?.center()
        stateThumbView.centerX(y: 10)
        durationView.setFrameOrigin(0, frame.height - durationView.frame.height)
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
        let timebase:CMTimebase? = globalAudio?.currentSong?.stableId == parent?.chatStableId ? globalAudio?.timebase : nil
        player.set(data: acceptVisibility ? data : nil, timebase: timebase)
        
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
                durationView.updateText(String.durationTransformed(elapsed: parameters.duration), maxWidth: 50, status: nil, isStreamable: false, isUnread: !isIncomingConsumed, animated: animated, isVideoMessage: true)
            }
            
            
            if mediaUpdated {
                
                globalAudio?.add(listener: self)
                
                player.layer?.cornerRadius = size.height / 2
                data = nil
                var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?
                let arguments = TransformImageArguments(corners: ImageCorners(radius:size.width/2), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets())
                
                player.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: backingScaleFactor), clearInstantly: mediaUpdated)
                if player.hasImage {
                    var bp:Int = 0
                    bp += 1
                }
               
                player.setSignal(chatMessageVideo(postbox: context.account.postbox, fileReference: parent != nil ? FileMediaReference.message(message: MessageReference(parent!), media: media) : FileMediaReference.standalone(media: media), scale: backingScaleFactor), cacheImage: { [weak media] result in
                    if let media = media {
                        cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale)
                    }
                })

                
                player.set(arguments: arguments)
                
                if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                    updatedStatusSignal = combineLatest(chatMessageFileStatus(account: context.account, file: media), context.account.pendingMessageManager.pendingMessageStatus(parent.id))
                        |> map { resourceStatus, pendingStatus -> MediaResourceStatus in
                            if let pendingStatus = pendingStatus.0 {
                                return .Fetching(isActive: true, progress: pendingStatus.progress)
                            } else {
                                return resourceStatus
                            }
                        } |> deliverOnMainQueue
                } else {
                    updatedStatusSignal = chatMessageFileStatus(account: context.account, file: media, approximateSynchronousValue: approximateSynchronousValue)
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
                            
                            strongSelf.fetchStatus = status
                            if case .Local = status {
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
                            case let .Fetching(_, progress):
                                strongSelf.progressView?.state = .Fetching(progress: progress, force: false)
                            case .Local:
                                strongSelf.progressView?.state = .Play
                            case .Remote:
                                strongSelf.progressView?.state = .Remote
                            }
                        }
                    }))
                }
                                
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
