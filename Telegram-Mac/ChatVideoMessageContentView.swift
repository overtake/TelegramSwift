//
//  ChatVideoMessageRowView.swift
//  Telegram
//
//  Created by keepcoder on 13/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

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
    ctx.draw(icon, in: NSMakeRect(floorToScreenPixels(scaleFactor: System.backingScale, (size.width - icon.backingSize.width) / 2), floorToScreenPixels(scaleFactor: System.backingScale, (size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height))
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
    
    private var durationView:ChatMessageAccessoryView = ChatMessageAccessoryView(frame: NSZeroRect)
    private let videoCorner: VideoMessageCorner = VideoMessageCorner()
    private var path:String? {
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
            return APSingleWrapper(resource: media.resource, mimeType: media.mimeType, name: tr(L10n.audioControllerVideoMessage), performer: parent?.author?.displayTitle, id: media.fileId)
        }
        return nil
    }
    
    override func open() {
        if let parent = parent, let account = account {
            if let parameters = parameters as? ChatMediaVideoMessageLayoutParameters {
                if let controller = globalAudio, let song = controller.currentSong, song.entry.isEqual(to: parent) {
                    controller.playOrPause()
                } else {
                    let controller:APController
                    if parameters.isWebpage, let wrapper = singleWrapper {
                        controller = APSingleResourceController(account: account, wrapper: wrapper, streamable: false)
                    } else {
                        controller = APChatVoiceController(account: account, peerId: parent.id.peerId, index: MessageIndex(parent))
                    }
                    
                    parameters.showPlayer(controller)
                    controller.start()
                    addGlobalAudioToVisible()
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
                    durationView.updateText(String.durationTransformed(elapsed: Int(data.current)), maxWidth: 50)
                    stateThumbView.isHidden = true
                case .stoped, .waiting, .fetching:
                    playingProgressView.state = .None
                    durationView.updateText(String.durationTransformed(elapsed: parameters.duration), maxWidth: 50)
                    stateThumbView.isHidden = false
                case let .paused(data):
                    playingProgressView.state = .ImpossibleFetching(progress: Float(data.progress), force: true)
                    durationView.updateText(String.durationTransformed(elapsed: Int(data.current)), maxWidth: 50)
                    stateThumbView.isHidden = false
                }
                
            } else {
                playingProgressView.state = .None
                durationView.updateText(String.durationTransformed(elapsed: parameters.duration), maxWidth: 50)
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
        
    }
    
    func checkState() {
        
    }
    
    
    override func cancelFetching() {
        if let account = account, let media = media as? TelegramMediaFile, let parent = parent {
            messageMediaFileCancelInteractiveFetch(account: account, messageId: parent.id, file: media)
        }
    }
    
    override func fetch() {
        if let account = account, let media = media as? TelegramMediaFile, let parent = parent {
            fetchDisposable.set(messageMediaFileInteractiveFetched(account: account, messageId: parent.id, file: media).start())
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
        return window != nil && window!.isKeyWindow && !NSIsEmptyRect(visibleRect)
    }
    
    @objc func updatePlayerIfNeeded() {
        let timebase:CMTimebase? = globalAudio?.currentSong?.stableId == parent?.chatStableId ? globalAudio?.timebase : nil
        player.set(path: acceptVisibility ? path : nil, timebase: timebase)
    }
    
    func updateListeners() {
        if let window = window {
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didResignKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: table?.clipView)
        } else {
            removeNotificationListeners()
        }
    }
    
    override func viewDidMoveToWindow() {
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    deinit {
        player.set(path: nil)
    }
    
    override func update(with media: Media, size: NSSize, account: Account, parent: Message?, table: TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool = false, positionFlags: GroupLayoutPositionFlags? = nil) {
        let mediaUpdated = self.media == nil || !self.media!.isEqual(media)
        
        
        super.update(with: media, size: size, account: account, parent:parent,table:table, parameters:parameters, animated: animated, positionFlags: positionFlags)
        
        
        updateListeners()
        
        if let media = media as? TelegramMediaFile {
            durationView.isUnread = !isIncomingConsumed
            if let parameters = parameters as? ChatMediaVideoMessageLayoutParameters {
                durationView.updateText(String.durationTransformed(elapsed: parameters.duration), maxWidth: 50)
            }
            
            
            
            if mediaUpdated {
                
                globalAudio?.add(listener: self)
                
                player.layer?.cornerRadius = size.height / 2
                path = nil
                
                let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: media.previewRepresentations, reference: nil)
                var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?
                
                player.setSignal( chatMessagePhoto(account: account, photo: image, scale: backingScaleFactor))
                let arguments = TransformImageArguments(corners: ImageCorners(radius:size.width/2), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets())
                player.set(arguments: arguments)
                
                if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                    updatedStatusSignal = combineLatest(chatMessageFileStatus(account: account, file: media), account.pendingMessageManager.pendingMessageStatus(parent.id))
                        |> map { resourceStatus, pendingStatus -> MediaResourceStatus in
                            if let pendingStatus = pendingStatus {
                                return .Fetching(isActive: true, progress: pendingStatus.progress)
                            } else {
                                return resourceStatus
                            }
                        } |> deliverOnMainQueue
                } else {
                    updatedStatusSignal = chatMessageFileStatus(account: account, file: media)
                }
                
                if let updatedStatusSignal = updatedStatusSignal {
                    
                    
                    self.statusDisposable.set((combineLatest(updatedStatusSignal, account.postbox.mediaBox.resourceData(media.resource)) |> deliverOnMainQueue).start(next: { [weak self] (status,resource) in
                        if let strongSelf = self {
                            
                            if resource.complete {
                                strongSelf.path = resource.path
                            } else {
                                strongSelf.path = nil
                            }
                            
                            strongSelf.fetchStatus = status
                            if case .Local = status {
                                if let progressView = strongSelf.progressView {
                                    progressView.removeFromSuperview()
                                    strongSelf.progressView = nil
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
