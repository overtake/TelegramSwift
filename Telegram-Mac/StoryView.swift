//
//  StoryView.swift
//  Telegram
//
//  Created by Mike Renoir on 24.04.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import SwiftSignalKit
import Postbox




class StoryView : Control {
    
    
    enum State : Equatable {
        case waiting
        case playing(MediaPlayerStatus)
        case paused(MediaPlayerStatus)
        case loading(MediaPlayerStatus)
        case finished
        
        var status: MediaPlayerStatus? {
            switch self {
            case let .playing(status), let .paused(status), let .loading(status):
                return status
            default:
                return nil
            }
        }
        
        func shouldBeUpdated(compared: State) -> Bool {
            switch self {
            case .paused:
                if case .paused = compared {
                    return false
                }
            case .playing:
                if case .playing = compared {
                    return true
                }
            case .waiting:
                if case .waiting = compared {
                    return false
                }
            case .loading:
                if case .loading = compared {
                    return false
                }
            case .finished:
                if case .finished = compared {
                    return false
                }
            }
            return true
        }
    }
    
    fileprivate var message: Message?
    fileprivate var context: AccountContext?
    
    func isEqual(to storyId: MessageId?) -> Bool {
        return self.message?.id == storyId
    }
    
    private(set) var state: State = .waiting
    private var timer: SwiftSignalKit.Timer?
    
    var onStateUpdate:((State)->Void)? = nil
    
    fileprivate func updateState(_ state: State) {
        if self.state != state, state.shouldBeUpdated(compared: self.state) {
            self.state = state
            self.onStateUpdate?(state)
            
            switch state {
            case let .playing(status):
                self.timer = SwiftSignalKit.Timer(timeout: status.duration - status.timestamp, repeat: false, completion: { [weak self] in
                    self?.updateState(.finished)
                }, queue: .mainQueue())
                self.timer?.start()
            default:
                self.timer?.invalidate()
                self.timer = nil
            }
        }
        
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.updateLayout(size: self.frame.size, transition: .immediate)
        self.layer?.cornerRadius = 10
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
    
    func update(context: AccountContext, message: Message) {
        self.context = context
        self.message = message
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    
    var currentTimestamp: Double {
        if let status = self.state.status {
            return status.timestamp
        } else {
            return 0
        }
    }
    
    var duration: Double {
        return 7
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
    }
    
    func restart() {
        self.updateState(.playing(.init(generationTimestamp: CACurrentMediaTime(), duration: self.duration, dimensions: .zero, timestamp: 0, baseRate: 1, volume: 1, seekId: 0, status: .playing)))
    }
    
    func appear(isMuted: Bool) {
        self.updateState(.waiting)
    }
    func disappear() {
        self.updateState(.waiting)
    }
    func preload() {
        
    }
    func pause() {
        if let current = state.status {
            self.updateState(.paused(.init(generationTimestamp: current.generationTimestamp, duration: self.duration, dimensions: .zero, timestamp: current.timestamp + (CACurrentMediaTime() - current.generationTimestamp), baseRate: 1, volume: 1, seekId: 0, status: .paused)))
        } else {
            self.updateState(.paused(.init(generationTimestamp: CACurrentMediaTime(), duration: self.duration, dimensions: .zero, timestamp: 0, baseRate: 1, volume: 1, seekId: 0, status: .paused)))
        }
    }
    func play() {
        if let current = state.status {
            self.updateState(.playing(.init(generationTimestamp: CACurrentMediaTime(), duration: self.duration, dimensions: .zero, timestamp: current.timestamp, baseRate: 1, volume: 1, seekId: 0, status: .playing)))
        } else {
            self.updateState(.playing(.init(generationTimestamp: CACurrentMediaTime(), duration: self.duration, dimensions: .zero, timestamp: 0, baseRate: 1, volume: 1, seekId: 0, status: .playing)))
        }
    }
    
    func mute() {
        
    }
    func unmute() {
        
    }
    
    
    static public var size: NSSize = NSMakeSize(9 * 40, 16 * 40)
    
    static func makeView(for message: Message, context: AccountContext, frame: NSRect) -> StoryView {
        let view: StoryView
        if message.media.first is TelegramMediaImage {
            view = StoryImageView(frame: frame)
        } else {
            view = StoryVideoView(frame: frame)
        }
        view.update(context: context, message: message)
        return view
    }
}



class StoryImageView : StoryView {
    private let imageView = TransformImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func update(context: AccountContext, message: Message) {
        
        let updated = self.message?.id != message.id
        
        super.update(context: context, message: message)
        
        var updateImageSignal: Signal<ImageDataTransformation, NoError>?
        self.message = message
        
        
        if let media = message.media.first {
            let size = frame.size
            var dimensions: NSSize = size
            
            if let image = media as? TelegramMediaImage {
                dimensions = image.representations.first?.dimensions.size ?? dimensions
            } else if let file = media as? TelegramMediaFile {
                dimensions = file.dimensions?.size ?? dimensions
            }
            
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: NSEdgeInsets(), resizeMode: .none)

            
            if let image = media as? TelegramMediaImage {
                updateImageSignal = chatMessagePhoto(account: context.account, imageReference: ImageMediaReference.message(message: MessageReference(message), media: image), scale: backingScaleFactor, synchronousLoad: false, autoFetchFullSize: true)
            } else if let file = media as? TelegramMediaFile {
                let fileReference = FileMediaReference.message(message: MessageReference(message), media: file)
                updateImageSignal = chatMessageVideo(postbox: context.account.postbox, fileReference: fileReference, scale: backingScaleFactor)
            }
            
//            self.imageView.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: backingScaleFactor, positionFlags: nil), clearInstantly: updated)

            if let updateImageSignal = updateImageSignal {
                //self.imageView.ignoreFullyLoad = updated
                self.imageView.setSignal(updateImageSignal, animate: updated, cacheImage: { [weak media] result in
                    if let media = media {
                       // cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale, positionFlags: nil)
                    }
                })
            }
            self.imageView.set(arguments: arguments)
            
        }
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: imageView, frame: size.bounds)
    }
}


class StoryVideoView : StoryImageView {
    private var mediaPlayer: MediaPlayer? = nil
    let view: MediaPlayerView
    
    private let statusDisposable = MetaDisposable()
        
    override func update(context: AccountContext, message: Message) {
        super.update(context: context, message: message)
        let file = message.media.first as! TelegramMediaFile
        let reference = FileMediaReference.message(message: MessageReference(message), media: file)
        let mediaPlayer = MediaPlayer(postbox: context.account.postbox, userLocation: .peer(message.id.peerId), userContentType: .video, reference: reference.resourceReference(file.resource), streamable: true, video: true, preferSoftwareDecoding: false, enableSound: true, fetchAutomatically: true)
        
        mediaPlayer.attachPlayerView(self.view)
        
        self.mediaPlayer = mediaPlayer
        mediaPlayer.actionAtEnd = .action({ [weak self] in
            DispatchQueue.main.async {
                self?.updateState(.finished)
            }
        })
        
        statusDisposable.set((mediaPlayer.status |> deliverOnMainQueue).start(next: { [weak self] status in
            if status.status == .playing {
                self?.updateState(.playing(status))
            } else if status.status == .paused {
                self?.updateState(.paused(status))
            } else if case .buffering = status.status {
                self?.updateState(.loading(status))
            }
        }))
    }
    
    deinit {
        statusDisposable.dispose()
    }
    
    override var currentTimestamp: Double {
        if let status = self.state.status {
            return status.timestamp
        } else {
            return 0
        }
    }
    
    override var duration: Double {
        let file = self.message?.media.first as? TelegramMediaFile
        return Double(file?.videoDuration ?? 5)
    }
    
    override func restart() {
        mediaPlayer?.seek(timestamp: 0)
    }
    override func mute() {
        mediaPlayer?.setVolume(0)
    }
    override func unmute() {
        mediaPlayer?.setVolume(1)
    }
    override func play() {
        mediaPlayer?.play()
    }
    override func pause() {
        mediaPlayer?.pause()
    }
    override func appear(isMuted: Bool) {
        mediaPlayer?.setVolume(isMuted ? 0 : 1)
    }
    override func disappear() {
        mediaPlayer?.pause()
        mediaPlayer?.seek(timestamp: 0)
    }

    required init(frame frameRect: NSRect) {
        self.view = MediaPlayerView()
        super.init(frame: frameRect)
        self.addSubview(view)
        self.view.frame = bounds
        self.view.setVideoLayerGravity(.resizeAspectFill)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        transition.updateFrame(view: view, frame: size.bounds)
    }
}
