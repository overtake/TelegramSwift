//
//  VideoAvatarModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11/06/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import Postbox
import SyncCore
import AVKit
import SwiftSignalKit

private final class VideoAvatarModalView : View {
    private var avPlayer: AVPlayerView
    private var videoSize: NSSize = .zero
    private let playerContainer: View = View()
    
    private let controls: View = View()
    
    fileprivate let scrubberView: VideoEditorScrubblerControl = VideoEditorScrubblerControl(frame: .zero)
    fileprivate let selectionRectView: SelectionRectView
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    required init(frame frameRect: NSRect) {
        selectionRectView = SelectionRectView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        avPlayer = AVPlayerView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        super.init(frame: frameRect)
        playerContainer.addSubview(avPlayer)
        avPlayer.controlsStyle = .none
        
        playerContainer.addSubview(selectionRectView)
        controls.addSubview(scrubberView)
        selectionRectView.isCircleCap = true
        selectionRectView.dimensions = .square
        
        addSubview(playerContainer)
        addSubview(controls)
        layout()
        
        
    }
    
    var playerSize: NSSize {
        return playerContainer.frame.size
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    func update(_ player: AVPlayer, size: NSSize) {
        self.avPlayer.player = player
        self.videoSize = size
        layout()
        
        let size = NSMakeSize(200, 200).aspectFitted(playerContainer.frame.size - NSMakeSize(50, 50))
        let rect = playerContainer.focus(size)
        selectionRectView.applyRect(rect, force: true, dimensions: .square)
    }

    func play() {
        self.avPlayer.player?.play()

    }
    func stop() {
        self.avPlayer.player?.pause()
        self.avPlayer.player = nil
    }
    
    override func layout() {
        super.layout()
        
        let videoContainerSize = videoSize.aspectFitted(NSMakeSize(frame.width, frame.height - 100))
        
        playerContainer.setFrameSize(videoContainerSize)
        playerContainer.centerX(y: 8)
        
        avPlayer.frame = playerContainer.bounds
        selectionRectView.frame = playerContainer.bounds
        controls.frame = NSMakeRect(0, frame.height - 100, frame.width, 100)
        scrubberView.setFrameSize(NSMakeSize(300, 44))
        scrubberView.centerX(y: controls.frame.height - scrubberView.frame.height)
    }
}

struct VideoAvatarResult {
    let thumb: String
    let video: String
}

class VideoAvatarModalController: ModalViewController {
    private let context: AccountContext
    fileprivate let videoSize: NSSize
    fileprivate let player: AVPlayer
    fileprivate let item: AVPlayerItem
    fileprivate let asset: AVComposition
    fileprivate let track: AVAssetTrack
    
    private let updateThumbsDisposable = MetaDisposable()
    private let rectDisposable = MetaDisposable()
    private let valuesDisposable = MetaDisposable()
    
    fileprivate let scrubberValues:Atomic<VideoScrubberValues> = Atomic(value: VideoScrubberValues(movePos: 0, leftCrop: 0, rightCrop: 1.0, minDist: 0, maxDist: 1, paused: true))
    fileprivate let _scrubberValuesSignal: ValuePromise<VideoScrubberValues> = ValuePromise(ignoreRepeated: true)
    var scrubberValuesSignal: Signal<VideoScrubberValues, NoError> {
        return _scrubberValuesSignal.get() |> deliverOnMainQueue
    }
    
    fileprivate func updateValues(_ f: (VideoScrubberValues)->VideoScrubberValues) {
        _scrubberValuesSignal.set(scrubberValues.modify(f))
    }
    private var firstTime: Bool = true
    private var timeObserverToken: Any?
    
    private let completeHandler:((VideoAvatarResult)->Void)?
    
    init(context: AccountContext, asset: AVComposition, track: AVAssetTrack, completeHandler:((VideoAvatarResult)->Void)? = nil) {
        self.context = context
        self.asset = asset
        self.track = track
        self.completeHandler = completeHandler
        let size = track.naturalSize.applying(track.preferredTransform)
        self.videoSize = size
        self.item = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem: item)
        super.init(frame: CGRect(origin: .zero, size: context.window.contentView!.frame.size - NSMakeSize(80, 80)))
        self.bar = .init(height: 0)
    }
    
    override open func measure(size: NSSize) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with: contentSize - NSMakeSize(80, 80), animated: false)
        }
    }
    
    func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with: contentSize - NSMakeSize(80, 80), animated: animated)
        }
    }
    
    
    override var dynamicSize: Bool {
        return true
    }
    
    override var background: NSColor {
        return .clear
    }
    
    override var containerBackground: NSColor {
        return .clear
    }
    override var isVisualEffectBackground: Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return VideoAvatarModalView.self
    }
    
    private var genericView: VideoAvatarModalView {
        return self.view as! VideoAvatarModalView
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player.pause()
        
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality)!
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        let path = NSTemporaryDirectory() + "\(arc4random()).mp4"
        let thumbPath = NSTemporaryDirectory() + "\(arc4random()).jpg"
        exportSession.outputURL = URL(fileURLWithPath: path)
        
        exportSession.videoComposition = currentVideoComposition()
        
        let wholeDuration = CMTimeGetSeconds(asset.duration)
        
        let from = scrubberValues.with { TimeInterval($0.leftCrop) * wholeDuration }
        let to = scrubberValues.with { TimeInterval($0.rightCrop) * wholeDuration }
        
        let start = CMTimeMakeWithSeconds(from, preferredTimescale: 1000)
        let duration = CMTimeMakeWithSeconds(to - from, preferredTimescale: 1000)
        
        exportSession.timeRange = CMTimeRangeMake(start: start, duration: duration)

        exportSession.exportAsynchronously(completionHandler: { [weak self] in
            
            if exportSession.status == .completed, exportSession.error == nil {
                let asset = AVURLAsset(url: URL(fileURLWithPath: path), options: [:])
                
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.maximumSize = CGSize(width: 640, height: 640)
                imageGenerator.appliesPreferredTrackTransform = true
                let image = try! imageGenerator.copyCGImage(at: CMTime(seconds: 0.0, preferredTimescale: asset.duration.timescale), actualTime: nil)
                
                let options = NSMutableDictionary()
                options.setValue(640 as NSNumber, forKey: kCGImageDestinationImageMaxPixelSize as String)
                options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailWithTransform as String)
                
                let colorQuality: Float = 0.3
                options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                
                
                let mutableData: CFMutableData = NSMutableData() as CFMutableData
                let colorDestination = CGImageDestinationCreateWithData(mutableData, kUTTypeJPEG, 1, options)!
                CGImageDestinationSetProperties(colorDestination, nil)
                
                CGImageDestinationAddImage(colorDestination, image, options as CFDictionary)
                CGImageDestinationFinalize(colorDestination)
                
                
                try! (mutableData as Data).write(to: URL(fileURLWithPath: thumbPath))
                
                DispatchQueue.main.async { [weak self] in
                    self?.completeHandler?(.init(thumb: thumbPath, video: path))
                    self?.close()
                }
            }
            
        })

        
        return .invoked
    }
    
    
    private func currentVideoComposition() -> AVVideoComposition {
        let size = track.naturalSize.applying(track.preferredTransform)
        
        var selectedRect = self.genericView.selectionRectView.selectedRect
        let viewSize = self.genericView.playerSize
        let coefficient = NSMakeSize(size.width / viewSize.width, size.height / viewSize.height)
        
        
        selectedRect = selectedRect.apply(multiplier: coefficient)
        
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = selectedRect.size
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        
        
        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let instruction = AVMutableVideoCompositionInstruction()
        
        instruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: self.asset.duration)
        
        let transform1: CGAffineTransform = track.preferredTransform.translatedBy(x: -selectedRect.minX, y: -selectedRect.minY)
        
        transformer.setTransform(transform1, at: CMTime.zero)
        
        instruction.layerInstructions = [transformer]
        videoComposition.instructions = [instruction]
        
        

        return videoComposition
    }
    
    
    deinit {
        rectDisposable.dispose()
        updateThumbsDisposable.dispose()
        valuesDisposable.dispose()
        NotificationCenter.default.removeObserver(self.item)
        
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    private func updateUserInterface(_ firstTime: Bool) {
        let size = NSMakeSize(genericView.scrubberView.frame.height, genericView.scrubberView.frame.height)
        
        let signal = generateVideoScrubberThumbs(for: asset, composition: currentVideoComposition(), size: size, count: Int(ceil(genericView.scrubberView.frame.width / size.width)), gradually: true) |> delay(0.2, queue: .concurrentDefaultQueue()) |> deliverOnMainQueue
        
        updateThumbsDisposable.set(signal.start(next: { [weak self] images, completed in
            self?.genericView.scrubberView.render(images, size: size)
            self?.firstTime = !completed
        }))
    }
    private func applyValuesToPlayer(_ values: VideoScrubberValues) {
        if values.movePos > values.rightCrop - (0.026 + (0.026 / 2)), !values.paused {
            play()
        }
        if values.paused {
            player.rate = 0
            seekToNormal(values)
            player.pause()
        } else if player.rate == 0, !values.paused {
            player.rate = 1
            play()
        }
    }
    private func seekToNormal(_ values: VideoScrubberValues) {
        let duration = CMTimeGetSeconds(asset.duration)
        self.player.seek(to: CMTimeMakeWithSeconds(TimeInterval(values.leftCrop + 0.026) * duration, preferredTimescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func play() {
        player.pause()
        let duration = CMTimeGetSeconds(asset.duration)
        
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        
        _ = self.scrubberValues.modify { values in
            self.seekToNormal(values)
            return values.withUpdatedMove(values.leftCrop).withUpdatedPaused(false)
        }
        
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: 0.016, preferredTimescale: timeScale)

        
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self]  time in
            self?.updateValues { current in
                return current.withUpdatedMove(CGFloat(CMTimeGetSeconds(time) / duration))
            }
        }
        self.player.play()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        genericView.update(self.player, size: self.videoSize)
        
        let duration = CMTimeGetSeconds(asset.duration)
        
        let scrubberSize = genericView.scrubberView.frame.width
        
        let valueSec = (scrubberSize / CGFloat(duration)) / scrubberSize
        
        self.updateValues { values in
            return values.withUpdatedMinDist(valueSec).withUpdatedMaxDist(valueSec * 10.0).withUpdatedRightCrop(min(1, valueSec * 10.0))
        }
        
        genericView.scrubberView.updateValues = { [weak self] values in
            self?.updateValues { _ in
                return values
            }
        }
        
        rectDisposable.set(genericView.selectionRectView.updatedRect.start(next: { [weak self] rect in
            self?.genericView.selectionRectView.applyRect(rect, force: true, dimensions: .square)
            self?.updateUserInterface(self?.firstTime ?? false)
        }))
        
        valuesDisposable.set(self.scrubberValuesSignal.start(next: { [weak self] values in
            self?.genericView.scrubberView.apply(values: values)
            self?.applyValuesToPlayer(values)
        }))
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.item, queue: .main) { [weak self] _ in
            self?.play()
        }
        
        play()
        readyOnce()
    }
    
}



func selectVideoAvatar(_ f:@escaping(VideoAvatarResult)->Void, context: AccountContext) -> Void {
    filePanel(with: videoExts, allowMultiple: false, canChooseDirectories: false, for: context.window, completion: { paths in
        if let path = paths?.first {
            let asset = AVURLAsset(url: URL(fileURLWithPath: path))
            let track = asset.tracks(withMediaType: .video).first
            if let track = track {
                let composition = AVMutableComposition()
                guard let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    return
                }
                do {
                    try? compositionVideoTrack.insertTimeRange(CMTimeRangeMake(start: .zero, duration: asset.duration), of: track, at: .zero)
                    
                    showModal(with: VideoAvatarModalController(context: context, asset: composition, track: track, completeHandler: f), for: context.window)
                } catch {
                    
                }
            }
        }
    })
}
