//
//  MGalleryVideoItem.swift
//  TelegramMac
//
//  Created by keepcoder on 19/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

import TelegramCore

import Postbox
import SwiftSignalKit
import TGUIKit
import AVFoundation
import AVKit

class MGalleryVideoItem: MGalleryItem {
    var startTime: TimeInterval = 0
    private var playAfter:Bool = false
    private let controller: SVideoController
    var playerState: Signal<AVPlayerState, NoError> {
        return controller.status |> map { value in
            switch value.status {
            case .playing:
                return .playing(duration: value.duration)
            case .paused:
                return .paused(duration: value.duration)
            case let .buffering(initial, whilePlaying):
                if whilePlaying {
                    return .playing(duration: value.duration)
                } else if !whilePlaying && !initial {
                    return .paused(duration: value.duration)
                } else {
                    return .waiting
                }
            }
        } |> deliverOnMainQueue
    }
    override init(_ context: AccountContext, _ entry: GalleryEntry, _ pagerSize: NSSize) {
        controller = SVideoController(postbox: context.account.postbox, reference: entry.fileReference(entry.file!))
        super.init(context, entry, pagerSize)
        
        controller.togglePictureInPictureImpl = { [weak self] enter, control in
            guard let `self` = self else {return}
            let frame = control.view.window!.convertToScreen(control.view.convert(control.view.bounds, to: nil))
            if enter, let viewer = viewer {
                closeGalleryViewer(false)
                showPipVideo(control: control, viewer: viewer, item: self, origin: frame.origin, delegate: viewer.delegate, contentInteractions: viewer.contentInteractions, type: viewer.type)
            } else if !enter {
                exitPictureInPicture()
            }
        }
    }
    
    deinit {
        updateMagnifyDisposable.dispose()
    }
        
    override func singleView() -> NSView {
        return controller.genericView
        
    }
    private var isPausedGlobalPlayer: Bool = false
    private let updateMagnifyDisposable = MetaDisposable()
    
    override func appear(for view: NSView?) {
        super.appear(for: view)
        
        pausepip()
        
        if let pauseMusic = context.audioPlayer?.pause() {
            isPausedGlobalPlayer = pauseMusic
        }
        
        controller.play(startTime)
        controller.viewDidAppear(false)
        self.startTime = 0
        
        
        updateMagnifyDisposable.set((magnify.get() |> deliverOnMainQueue).start(next: { [weak self] value in
            if value < 1.0 {
                _ = self?.hideControls(forceHidden: true)
            } else {
                _ = self?.unhideControls(forceUnhidden: true)
            }
        }))
    }
    
    override var maxMagnify: CGFloat {
        return min(pagerSize.width / sizeValue.width, pagerSize.height / sizeValue.height)
    }
    
    override func disappear(for view: NSView?) {
        super.disappear(for: view)
        if isPausedGlobalPlayer {
            _ = context.audioPlayer?.play()
        }
        if controller.style != .pictureInPicture {
            controller.pause()
        }
        controller.viewDidDisappear(false)
        updateMagnifyDisposable.set(nil)
        playAfter = false
    }
    
    override var status:Signal<MediaResourceStatus, NoError> {
        if media.isStreamable {
            return .single(.Local)
        } else {
            return realStatus
        }
    }
    
    override var realStatus:Signal<MediaResourceStatus, NoError> {
        if let message = entry.message {
            return chatMessageFileStatus(context: context, message: message, file: media)
        } else {
            return context.account.postbox.mediaBox.resourceStatus(media.resource)
        }
    }
    
    var media:TelegramMediaFile {
        return entry.file!
    }
    private var examinatedSize: CGSize?
    var dimensions: CGSize? {
        
        if let examinatedSize = examinatedSize {
            return examinatedSize
        }
        if let dimensions = media.dimensions {
            return dimensions.size
        }
        let linked = link(path: context.account.postbox.mediaBox.resourcePath(media.resource), ext: "mp4")
        guard let path = linked else {
            return media.dimensions?.size
        }
        
        let url = URL(fileURLWithPath: path)
        guard let track = AVURLAsset(url: url).tracks(withMediaType: .video).first else {
            return media.dimensions?.size
        }
        try? FileManager.default.removeItem(at: url)
        let size = track.naturalSize.applying(track.preferredTransform)
        self.examinatedSize = NSMakeSize(abs(size.width), abs(size.height))
        
        return examinatedSize
        
    }
    
    override var notFittedSize: NSSize {
        if let size = dimensions {
            return size.fitted(pagerSize)
        }
        return pagerSize
    }
    
    override var sizeValue: NSSize {
        if let size = dimensions {
            
            var pagerSize = self.pagerSize
            
            
            var size = size
            
            if size.width == 0 || size.height == 0 {
                size = NSMakeSize(300, 300)
            }
            
            let aspectRatio = size.width / size.height
            let addition = max(300 - size.width, 300 - size.height)
            
            if addition > 0 {
                size.width += addition * aspectRatio
                size.height += addition
            }
            
//            let addition = max(400 - size.width, 400 - size.height)
//            if addition > 0 {
//                size.width += addition
//                size.height += addition
//            }
            
            size = size.fitted(pagerSize)

            return size
        }
        return pagerSize
    }
    
    func hideControls(forceHidden: Bool = false) -> Bool {
        return controller.hideControlsIfNeeded(forceHidden)
    }
    func unhideControls(forceUnhidden: Bool = true) -> Bool {
        return controller.unhideControlsIfNeeded(forceUnhidden)
    }
    
    override func toggleFullScreen() {
        controller.toggleFullScreen()
    }
    
    override func togglePlayerOrPause() {
        controller.togglePlayerOrPause()
    }
    
    override func rewindBack() {
        controller.rewindBackward()
    }
    override func rewindForward() {
        controller.rewindForward()
    }
    
    var isFullscreen: Bool {
        return controller.isFullscreen
    }
    
    
    override func request(immediately: Bool) {

        super.request(immediately: immediately)
        
        let signal:Signal<ImageDataTransformation,NoError> = chatMessageVideo(postbox: context.account.postbox, fileReference: entry.fileReference(media), scale: System.backingScale, synchronousLoad: true)
        
        let size = sizeValue
        
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: NSEdgeInsets(), resizeMode: .none)
        let result = signal |> mapToThrottled { data -> Signal<CGImage?, NoError> in
            return .single(data.execute(arguments, data.data)?.generateImage())
        }
        
        path.set(context.account.postbox.mediaBox.resourceData(media.resource) |> mapToSignal { (resource) -> Signal<String, NoError> in
            if resource.complete {
                return .single(link(path:resource.path, ext:kMediaVideoExt)!)
            }
            return .never()
        })
        self.image.set(media.previewRepresentations.isEmpty ? .single(GPreviewValueClass(.image(nil, nil))) |> deliverOnMainQueue : result |> map { GPreviewValueClass(.image($0 != nil ? NSImage(cgImage: $0!, size: $0!.backingSize) : nil, nil)) } |> deliverOnMainQueue)
        
        fetch()
    }
    
    
    override func fetch() -> Void {
        if !media.isStreamable {
            if let parent = entry.message {
                _ = messageMediaFileInteractiveFetched(context: context, messageId: parent.id, messageReference: .init(parent), file: media, userInitiated: true).start()
            } else {
                _ = freeMediaFileInteractiveFetched(context: context, fileReference: FileMediaReference.standalone(media: media)).start()
            }
        }
    }

}
