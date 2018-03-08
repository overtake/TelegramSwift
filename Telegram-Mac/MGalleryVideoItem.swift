//
//  MGalleryVideoItem.swift
//  TelegramMac
//
//  Created by keepcoder on 19/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit
import AVFoundation
import AVKit

private class VideoPlayerView : AVPlayerView {
    
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateLayout()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateLayout()
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateLayout()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateLayout()
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateLayout()
    }
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        updateLayout()
    }
    
    private func updateLayout() {
        let controls = subviews.last?.subviews.last
        if let controls = controls {
            if let pip = controls.subviews.last as? ImageButton {
                pip.setFrameOrigin(controls.frame.width - pip.frame.width - 80, controls.frame.height - pip.frame.height - 20)
            }
            
            controls._change(opacity: _mouseInside() ? 1 : 0, animated: true)
            
        }
    }
    
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
        updateLayout()
    }
    
    override func layout() {
        super.layout()
        updateLayout()
    }
}

class MGalleryVideoItem: MGalleryItem {
    var startTime: TimeInterval = 0
    private var playAfter:Bool = false
    override init(_ account: Account, _ entry: GalleryEntry, _ pagerSize: NSSize) {
        super.init(account, entry, pagerSize)
        
        let pathSignal = combineLatest(path.get() |> distinctUntilChanged |> deliverOnMainQueue, view.get() |> distinctUntilChanged) |> map { path, view -> (AVPlayer?,AVPlayerView) in
            let url = URL(string: path) ?? URL(fileURLWithPath: path)
            let player = AVPlayer(url: url)
            return (player, view as! AVPlayerView)
        } 
        disposable.set(pathSignal.start(next: { [weak self] player, view in
            if let strongSelf = self {
                view.player = player
                if strongSelf.playAfter {
                    strongSelf.playAfter = false
                    player?.play()
                    if strongSelf.startTime > 0 {
                        player?.seek(to: CMTimeMake(Int64(strongSelf.startTime * 1000.0), 1000))
                    }
                    let controls = view.subviews.last?.subviews.last
                    if let controls = controls, let pip = strongSelf.pipButton {
                        controls.addSubview(pip)
                        view.needsLayout = true
                    }
                    
                }
            }
        }))
        
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    private var _cachedView: VideoPlayerView?
    private var pipButton: ImageButton?
    
    override func singleView() -> NSView {
        let view: VideoPlayerView
        if let _cachedView = _cachedView {
            view = _cachedView
        } else {
            view = VideoPlayerView()
        }
        view.showsFullScreenToggleButton = true
        view.showsFrameSteppingButtons = true
        view.controlsStyle = .floating
        view.autoresizingMask = []
        view.autoresizesSubviews = false
        
        let pip:ImageButton = ImageButton()
        pip.style = ControlStyle(highlightColor: .grayIcon)
        pip.set(image: #imageLiteral(resourceName: "Icon_PIPVideoEnable").precomposed(NSColor.white.withAlphaComponent(0.9)), for: .Normal)
        
        pip.set(handler: { [weak view, weak self] _ in
            if let view = view, let strongSelf = self, let viewer = viewer {
                let frame = view.window!.convertToScreen(view.convert(view.bounds, to: nil))
                if !viewer.pager.isFullScreen {
                    closeGalleryViewer(false)
                    showPipVideo(view, viewer: viewer, item: strongSelf, origin: frame.origin, delegate: viewer.delegate, contentInteractions: viewer.contentInteractions, type: viewer.type)
                }
            }
        }, for: .Down)
        
        _ = pip.sizeToFit()

        pipButton = pip
        
   

        _cachedView = view
        return view
        
    }
    private var isPausedGlobalPlayer: Bool = false
    
    override func appear(for view: NSView?) {
        super.appear(for: view)
        
        pausepip()
        
        if let pauseMusic = globalAudio?.pause() {
            isPausedGlobalPlayer = pauseMusic
        }
        
        if let view = view as? AVPlayerView {
            if let player = view.player {
                player.play()
            } else {
                playAfter = true
            }
        } else {
             playAfter = true
        }
    }
    
    override var maxMagnify: CGFloat {
        return min(pagerSize.width / sizeValue.width, pagerSize.height / sizeValue.height)
    }
    
    override func disappear(for view: NSView?) {
        super.disappear(for: view)
        if isPausedGlobalPlayer {
            _ = globalAudio?.play()
        }
        if let view = view as? AVPlayerView {
            view.player?.pause()
        }
        playAfter = false
    }
    
    override var status:Signal<MediaResourceStatus, Void> {
        return chatMessageFileStatus(account: account, file: media)
    }
    
    var media:TelegramMediaFile {
        switch entry {
        case .message(let entry):
            if let media = entry.message!.media[0] as? TelegramMediaFile {
                return media
            } else if let media = entry.message!.media[0] as? TelegramMediaWebpage {
                switch media.content {
                case let .Loaded(content):
                    return content.file!
                default:
                    fatalError("")
                }
            }
        case .instantMedia(let media):
            return media.media as! TelegramMediaFile
        default:
            fatalError()
        }
        
        fatalError("")
    }
    
    override var sizeValue: NSSize {
        if let size = media.dimensions {
            let size = size.fitted(pagerSize)
            return NSMakeSize(max(size.width, 320), max(size.height, 240))
        }
        return pagerSize
    }
    
    override func request(immediately: Bool) {

        let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: media.previewRepresentations, reference: nil)
        
        let signal:Signal<(TransformImageArguments) -> DrawingContext?,NoError> = chatMessagePhoto(account: account, photo: image, scale: System.backingScale)
        
        
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: sizeValue, boundingSize: sizeValue, intrinsicInsets: NSEdgeInsets())
        let result = signal |> deliverOn(account.graphicsThreadPool) |> mapToThrottled { transform -> Signal<CGImage?, NoError> in
            return .single(transform(arguments)?.generateImage())
        }
        
        path.set(account.postbox.mediaBox.resourceData(media.resource) |> mapToSignal { (resource) -> Signal<String, Void> in
            if resource.complete {
                return .single(link(path:resource.path, ext:kMediaVideoExt)!)
            }
            return .never()
        })
        
        self.image.set(media.previewRepresentations.isEmpty ? .single(nil) |> deliverOnMainQueue : result |> deliverOnMainQueue)
        
        fetch()
    }
    
    
    
    
    override func fetch() -> Void {
       
        _ = freeMediaFileInteractiveFetched(account: account, file: media).start()
    }

}
