//
//  MGalleryVideoItem.swift
//  TelegramMac
//
//  Created by keepcoder on 19/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

import TelegramCore
import SyncCore
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
        var bp:Int = 0
        bp += 1
    }
        
    override func singleView() -> NSView {
        return controller.genericView
        
    }
    private var isPausedGlobalPlayer: Bool = false
    
    override func appear(for view: NSView?) {
        super.appear(for: view)
        
        pausepip()
        
        if let pauseMusic = globalAudio?.pause() {
            isPausedGlobalPlayer = pauseMusic
        }
        
        controller.play(startTime)
        controller.viewDidAppear(false)
        self.startTime = 0
    }
    
    override var maxMagnify: CGFloat {
        return min(pagerSize.width / sizeValue.width, pagerSize.height / sizeValue.height)
    }
    
    override func disappear(for view: NSView?) {
        super.disappear(for: view)
        if isPausedGlobalPlayer {
            _ = globalAudio?.play()
        }
        if controller.style != .pictureInPicture {
            controller.pause()
        }
        controller.viewDidDisappear(false)
        playAfter = false
    }
    
    override var status:Signal<MediaResourceStatus, NoError> {
        if media.isStreamable {
            return .single(.Local)
        } else {
            return chatMessageFileStatus(account: context.account, file: media)
        }
    }
    
    override var realStatus:Signal<MediaResourceStatus, NoError> {
        return chatMessageFileStatus(account: context.account, file: media)
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
        self.examinatedSize = track.naturalSize.applying(track.preferredTransform)
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
            
            pagerSize.height -= (caption != nil ? caption!.layoutSize.height + 80 : 0)
            
            let size = NSMakeSize(max(size.width, 200), max(size.height, 200)).fitted(pagerSize)
            
            
            return size
        }
        return pagerSize
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
    
    
    
    override func request(immediately: Bool) {

        
        let signal:Signal<ImageDataTransformation,NoError> = chatMessageVideo(postbox: context.account.postbox, fileReference: entry.fileReference(media), scale: System.backingScale, synchronousLoad: true)
        
        
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: media.dimensions?.size.fitted(pagerSize) ?? sizeValue, boundingSize: sizeValue, intrinsicInsets: NSEdgeInsets(), resizeMode: .fill(.black))
        let result = signal |> mapToThrottled { data -> Signal<CGImage?, NoError> in
            return .single(data.execute(arguments, data.data)?.generateImage())
        }
        
        path.set(context.account.postbox.mediaBox.resourceData(media.resource) |> mapToSignal { (resource) -> Signal<String, NoError> in
            if resource.complete {
                return .single(link(path:resource.path, ext:kMediaVideoExt)!)
            }
            return .never()
        })
        
        self.image.set(media.previewRepresentations.isEmpty ? .single(.image(nil)) |> deliverOnMainQueue : result |> map { .image($0 != nil ? NSImage(cgImage: $0!, size: $0!.backingSize) : nil) } |> deliverOnMainQueue)
        
        fetch()
    }
    
    
    
    
    override func fetch() -> Void {
        if !media.isStreamable {
            if let parent = entry.message {
                _ = messageMediaFileInteractiveFetched(context: context, messageId: parent.id, fileReference: FileMediaReference.message(message: MessageReference(parent), media: media)).start()
            } else {
                _ = freeMediaFileInteractiveFetched(context: context, fileReference: FileMediaReference.standalone(media: media)).start()
            }
        }
    }

}
