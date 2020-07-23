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


private var magicNumber: CGFloat {
    return 8 / 280
}

private final class VideoAvatarKeyFramePreviewView: Control {
    private let imageView: ImageView = ImageView()
    private let flash: View = View()
    fileprivate var keyFrame: CGFloat?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(flash)
        flash.backgroundColor = .white
        flash.frame = bounds
        imageView.frame = bounds
        imageView.animates = true
        layout()
    }
    
    func update(with image: CGImage?, value: CGFloat?, animated: Bool, completion: @escaping(Bool)->Void) {
        imageView.image = image
        self.keyFrame = value
        if animated {
            flash.layer?.animateAlpha(from: 1, to: 0, duration: 0.6, timingFunction: .easeIn, removeOnCompletion: false, completion: { [weak self] completed in
                self?.flash.removeFromSuperview()
                completion(completed)
            })
        } else {
            flash.removeFromSuperview()
        }
    }
    
    
    
    override func layout() {
        super.layout()
        imageView.frame = bounds
        layer?.cornerRadius = frame.width / 2
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class VideoAvatarModalView : View {
    private var avPlayer: AVPlayerView
    private var videoSize: NSSize = .zero
    private let playerContainer: View = View()
    private var keyFramePreview: VideoAvatarKeyFramePreviewView?
    private var keyFrameDotView: View?
    private let controls: View = View()
    
    fileprivate let ok: ImageButton = ImageButton()
    fileprivate let cancel: ImageButton = ImageButton()

    fileprivate let scrubberView: VideoEditorScrubblerControl = VideoEditorScrubblerControl(frame: .zero)
    fileprivate let selectionRectView: SelectionRectView
    

    private let descView: TextView = TextView()
    
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
        
        
        controls.border = [.Left, .Right]
        controls.borderColor = NSColor.black.withAlphaComponent(0.2)
        controls.backgroundColor = NSColor(0x303030)
        controls.layer?.cornerRadius = .cornerRadius
        addSubview(playerContainer)
        addSubview(controls)
        
        controls.addSubview(ok)
        controls.addSubview(cancel)
        
        addSubview(descView)
        
        descView.userInteractionEnabled = false
        descView.isSelectable = false
        descView.disableBackgroundDrawing = true

        cancel.set(image: NSImage(named: "Icon_VideoPlayer_Close")!.precomposed(.white), for: .Normal)
        ok.set(image: NSImage(named: "Icon_SaveEditedMessage")!.precomposed(.accent), for: .Normal)

        setFrameSize(frame.size)
        layout()
        
        
    }
    
    func updateKeyFrameImage(_ image: CGImage?) {
        keyFramePreview?.update(with: image, value: keyFramePreview?.keyFrame, animated: false, completion: { _ in })
    }
    
    func setKeyFrame(value: CGFloat?, highRes: CGImage? = nil, lowRes: CGImage? = nil, animated: Bool, completion: @escaping(Bool)->Void = { _ in}) -> Void {
        if let keyFramePreview = self.keyFramePreview {
            self.keyFramePreview = nil
            keyFramePreview.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak keyFramePreview] _ in
                keyFramePreview?.removeFromSuperview()
            })
        }
        if let keyFrameDotView = self.keyFrameDotView {
            self.keyFrameDotView = nil
            keyFrameDotView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak keyFrameDotView] _ in
                keyFrameDotView?.removeFromSuperview()
            })
        }
        if let value = value {
            let point = self.convert(selectionRectView.selectedRect.origin, from: selectionRectView)
            let size = selectionRectView.selectedRect.size
            let keyFramePreview = VideoAvatarKeyFramePreviewView(frame: CGRect(origin: point, size: size))
 
            
            keyFramePreview.update(with: highRes, value: value, animated: animated, completion: { [weak self, weak keyFramePreview] completed in
                
                if !completed {
                    keyFramePreview?.removeFromSuperview()
                    completion(completed)
                    return
                }
                
                guard let `self` = self, let keyFramePreview = keyFramePreview else {
                    return
                }
                
                let keyFrameDotView = View()
                
               
                self.addSubview(keyFrameDotView)
                keyFrameDotView.backgroundColor = .white
                keyFrameDotView.layer?.cornerRadius = 3
                
                
                let point = NSMakePoint(self.controls.frame.minX + self.scrubberView.frame.minX + value * self.scrubberView.frame.width - 15 + 2, self.controls.frame.maxY - self.scrubberView.frame.height - 30 - 14)
                
                keyFrameDotView.frame = NSMakeRect(self.controls.frame.minX + self.scrubberView.frame.minX + (value * self.scrubberView.frame.width) - 3 + 2, self.controls.frame.maxY - self.scrubberView.frame.height - 10, 6, 6)
                
                keyFramePreview.layer?.animateScale(from: 1, to: 30 / keyFramePreview.frame.width, duration: 0.23, removeOnCompletion: false)
                keyFramePreview.layer?.animatePosition(from: keyFramePreview.frame.origin, to: point, duration: 0.3, removeOnCompletion: false, completion: { [weak self, weak keyFramePreview, weak keyFrameDotView] complete in
                    
                    keyFramePreview?.update(with: lowRes, value: value, animated: false, completion: { _ in })
                    keyFramePreview?.frame = CGRect(origin: point, size: NSMakeSize(30, 30))
                    keyFramePreview?.layer?.removeAllAnimations()
                    
                    self?.keyFrameDotView = keyFrameDotView
                    self?.keyFramePreview = keyFramePreview
                    
                    if !complete {
                        keyFrameDotView?.removeFromSuperview()
                        keyFramePreview?.removeFromSuperview()
                    }
                    
                    completion(complete)
                })
                
               
                
                keyFrameDotView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            })
            self.addSubview(keyFramePreview)
        }
    }
    
    var playerSize: NSSize {
        return playerContainer.frame.size
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    private var localize: String?
    
    func update(_ player: AVPlayer, localize: String, size: NSSize) {
        self.avPlayer.player = player
        self.videoSize = size
        self.localize = localize
        setFrameSize(frame.size)
        layout()
        
        let size = NSMakeSize(200, 200).aspectFitted(playerContainer.frame.size)
        let rect = playerContainer.focus(size)
        selectionRectView.minimumSize = size.aspectFitted(NSMakeSize(150, 150))
        selectionRectView.applyRect(rect, force: true, dimensions: .square)
    }

    func play() {
        self.avPlayer.player?.play()

    }
    func stop() {
        self.avPlayer.player?.pause()
        self.avPlayer.player = nil
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        let oldSize = self.frame.size
        super.setFrameSize(newSize)
        
        let videoContainerSize = videoSize.aspectFitted(NSMakeSize(frame.width, frame.height - 120))
        let oldVideoContainerSize = playerContainer.frame.size
        playerContainer.setFrameSize(videoContainerSize)

        
        if oldSize != newSize, oldSize != NSZeroSize, inLiveResize {
            let multiplier = NSMakeSize(videoContainerSize.width / oldVideoContainerSize.width, videoContainerSize.height / oldVideoContainerSize.height)
            selectionRectView.applyRect(selectionRectView.selectedRect.apply(multiplier: multiplier))
        }
        
        avPlayer.frame = playerContainer.bounds
        selectionRectView.frame = playerContainer.bounds
        controls.setFrameSize(NSMakeSize(370, 44))
        scrubberView.setFrameSize(NSMakeSize(280, 44))

        ok.setFrameSize(NSMakeSize(controls.frame.height, controls.frame.height))
        cancel.setFrameSize(NSMakeSize(controls.frame.height, controls.frame.height))
        
        
        if let localize = localize {
            let descLayout = TextViewLayout.init(.initialize(string: localize, color: .white, font: .normal(.text)), maximumNumberOfLines: 1)
            descLayout.measure(width: frame.width)
            descView.update(descLayout)
        }
    }
    
    override func layout() {
        super.layout()
        
        playerContainer.centerX(y: 8)
        controls.centerX(y: frame.height - controls.frame.height - 20)
        scrubberView.centerX(y: controls.frame.height - scrubberView.frame.height)
        
        ok.setFrameOrigin(NSMakePoint(controls.frame.width - controls.frame.height, 0))
        cancel.setFrameOrigin(.zero)

        descView.centerX(y: frame.maxY - descView.frame.height)
        
        
        if let keyFramePreview = keyFramePreview, let keyFrameDotView = keyFrameDotView, let value = keyFramePreview.keyFrame {
            let point = NSMakePoint(self.controls.frame.minX + self.scrubberView.frame.minX + value * self.scrubberView.frame.width - 15 + 2, self.controls.frame.maxY - self.scrubberView.frame.height - 30 - 14)
            
            keyFrameDotView.frame = NSMakeRect(self.controls.frame.minX + self.scrubberView.frame.minX + (value * self.scrubberView.frame.width) - 3 + 2, self.controls.frame.maxY - self.scrubberView.frame.height - 10, 6, 6)
            keyFramePreview.frame = CGRect(origin: point, size: NSMakeSize(30, 30))

        }
        
    }
}


enum VideoAvatarGeneratorState : Equatable {
    case start(thumb: String)
    case progress(Float)
    case complete(thumb: String, video: String, keyFrame: Double?)
    case error
}


class VideoAvatarModalController: ModalViewController {
    private let context: AccountContext
    fileprivate let videoSize: NSSize
    fileprivate let player: AVPlayer
    fileprivate let item: AVPlayerItem
    fileprivate let asset: AVComposition
    fileprivate let track: AVAssetTrack
    fileprivate var appliedKeyFrame: CGFloat? = nil
    
    private let updateThumbsDisposable = MetaDisposable()
    private let rectDisposable = MetaDisposable()
    private let valuesDisposable = MetaDisposable()
    private let keyFrameGeneratorDisposable = MetaDisposable()
    
    fileprivate let scrubberValues:Atomic<VideoScrubberValues> = Atomic(value: VideoScrubberValues(movePos: 0, keyFrame: nil, leftTrim: 0, rightTrim: 1.0, minDist: 0, maxDist: 1, paused: true, suspended: false))
    fileprivate let _scrubberValuesSignal: ValuePromise<VideoScrubberValues> = ValuePromise(ignoreRepeated: true)
    var scrubberValuesSignal: Signal<VideoScrubberValues, NoError> {
        return _scrubberValuesSignal.get() |> deliverOnMainQueue
    }
    
    fileprivate func updateValues(_ f: (VideoScrubberValues)->VideoScrubberValues) {
        _scrubberValuesSignal.set(scrubberValues.modify(f))
    }
    private var firstTime: Bool = true
    private var timeObserverToken: Any?
    
    var completeState: Signal<VideoAvatarGeneratorState, NoError> {
        return state.get()
    }
    
    private var state: Promise<VideoAvatarGeneratorState> = Promise()
    private let localize: String
    init(context: AccountContext, asset: AVComposition, track: AVAssetTrack, localize: String) {
        self.context = context
        self.asset = asset
        self.track = track
        let size = track.naturalSize.applying(track.preferredTransform)
        self.videoSize = NSMakeSize(abs(size.width), abs(size.height))
        self.item = AVPlayerItem(asset: asset)
        
        self.player = AVPlayer(playerItem: item)
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: self.asset.duration)
        let transform1: CGAffineTransform = track.preferredTransform
        transformer.setTransform(transform1, at: CMTime.zero)
        instruction.layerInstructions = [transformer]
        videoComposition.instructions = [instruction]
        self.item.videoComposition = videoComposition
        
        self.localize = localize
        super.init(frame: CGRect(origin: .zero, size: context.window.contentView!.frame.size - NSMakeSize(50, 50)))
        self.bar = .init(height: 0)
    }
    
    override open func measure(size: NSSize) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with: contentSize - NSMakeSize(50, 50), animated: false)
        }
    }
    
    func updateSize(_ animated: Bool) {
        if let contentSize = self.modal?.window.contentView?.frame.size {
            self.modal?.resize(with: contentSize - NSMakeSize(50, 50), animated: animated)
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
        self.state.set(generateVideo(asset, composition: self.currentVideoComposition(), values: self.scrubberValues.with { $0 }))
        close()
        
        return .invoked
    }
    
    
    private func currentVideoComposition() -> AVVideoComposition {
        let size = self.videoSize
        let naturalSize = self.asset.naturalSize
        
        enum Orientation {
            case up, down, right, left
        }
        
        func orientation(for track: AVAssetTrack) -> Orientation {
            let t = track.preferredTransform
            
            if(t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0) {
                return .up
            } else if(t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0) {
                return .down
            } else if(t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0) {
                return .right
            } else if(t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0) {
                return .left
            } else {
                return .up
            }
        }
        
        let rotation: Orientation = orientation(for: track)
        
        var selectedRect = self.genericView.selectionRectView.selectedRect
        let viewSize = self.genericView.playerSize
        let coefficient = NSMakeSize(size.width / viewSize.width, size.height / viewSize.height)
        
        selectedRect = selectedRect.apply(multiplier: coefficient)
        
        selectedRect.size = NSMakeSize(min(selectedRect.width, selectedRect.height), min(selectedRect.width, selectedRect.height))
        
        let videoComposition = AVMutableVideoComposition()
        
        videoComposition.renderSize = selectedRect.size
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        
        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let instruction = AVMutableVideoCompositionInstruction()
        
        instruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: self.asset.duration)
        
        let point = selectedRect.origin
        var finalTransform: CGAffineTransform = CGAffineTransform.identity
        
        switch rotation {
        case .down:
            finalTransform = finalTransform
                .translatedBy(x: -point.x, y: naturalSize.width - point.y)
                .rotated(by: -.pi / 2)
        case .left:
            finalTransform = finalTransform
                .translatedBy(x: naturalSize.width - point.x, y: naturalSize.height - point.y)
                .rotated(by: .pi)
        case .right:
            finalTransform = finalTransform
                .translatedBy(x: -point.x, y: -point.y)
                .rotated(by: 0)
        case .up:
            finalTransform = finalTransform
                .translatedBy(x: naturalSize.height - point.x, y: -point.y)
                .rotated(by: .pi / 2)
        }
        
        transformer.setTransform(finalTransform, at: CMTime.zero)
        
        instruction.layerInstructions = [transformer]
        videoComposition.instructions = [instruction]
        
        return videoComposition
    }
    
    
    deinit {
        rectDisposable.dispose()
        updateThumbsDisposable.dispose()
        valuesDisposable.dispose()
        keyFrameGeneratorDisposable.dispose()
        NotificationCenter.default.removeObserver(self.item)
        
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    private var generatedRect: NSRect? = nil
    
    private func updateUserInterface(_ firstTime: Bool) {
        let size = NSMakeSize(genericView.scrubberView.frame.height, genericView.scrubberView.frame.height)
        
        let signal = generateVideoScrubberThumbs(for: asset, composition: currentVideoComposition(), size: size, count: Int(ceil(genericView.scrubberView.frame.width / size.width)), gradually: true, blur: true)
            |> delay(0.2, queue: .concurrentDefaultQueue())
        
        
        let duration = CMTimeGetSeconds(asset.duration)
        
        let keyFrame = scrubberValues.with { $0.keyFrame }
        
        let keyFrameSignal: Signal<CGImage?, NoError>
            
        if let keyFrame = keyFrame {
            keyFrameSignal = generateVideoAvatarPreview(for: asset, composition: self.currentVideoComposition(), highSize: genericView.selectionRectView.selectedRect.size, lowSize: NSMakeSize(30, 30), at: Double(keyFrame) * duration)
                |> delay(0.2, queue: .concurrentDefaultQueue())
                |> map { $0.0 }
        } else {
            keyFrameSignal = .single(nil)
        }
        
        var selectedRect = self.genericView.selectionRectView.selectedRect
        let viewSize = self.genericView.playerSize
        let coefficient = NSMakeSize(size.width / viewSize.width, size.height / viewSize.height)
        
        selectedRect = selectedRect.apply(multiplier: coefficient)

        if generatedRect != selectedRect {
            updateThumbsDisposable.set(combineLatest(queue: .mainQueue(), signal, keyFrameSignal).start(next: { [weak self] images, keyFrame in
                self?.genericView.scrubberView.render(images.0, size: size)
                self?.genericView.updateKeyFrameImage(keyFrame)
                if self?.firstTime == true {
                    self?.firstTime = !images.1
                }
                self?.generatedRect = selectedRect
            }))
        }
    }
    private func applyValuesToPlayer(_ values: VideoScrubberValues) {
        if values.movePos > values.rightTrim - (magicNumber + (magicNumber / 2)), !values.paused {
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
        if let keyFrame = values.keyFrame, appliedKeyFrame != keyFrame {
            self.runKeyFrameUpdater(keyFrame)
            seekToNormal(values)
        } else if appliedKeyFrame != nil && values.keyFrame == nil {
            self.genericView.setKeyFrame(value: nil, animated: true)
            self.appliedKeyFrame = nil
        }
    }
    @discardableResult private func seekToNormal(_ values: VideoScrubberValues) -> CGFloat? {
        let duration = CMTimeGetSeconds(asset.duration)
        if values.suspended {
            self.player.seek(to: CMTimeMakeWithSeconds(TimeInterval(values.movePos) * duration, preferredTimescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
            return values.keyFrame
        } else {
            self.player.seek(to: CMTimeMakeWithSeconds(TimeInterval(values.leftTrim + magicNumber) * duration, preferredTimescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
            return nil
        }
    }
    
    private func play() {
        player.pause()
        let duration = CMTimeGetSeconds(asset.duration)
        
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        
        _ = self.scrubberValues.modify { values in
            let values = values.withUpdatedPaused(false)
            if let result = self.seekToNormal(values) {
                return values.withUpdatedMove(result)
            } else {
                return values.withUpdatedMove(values.leftTrim)
            }
        }
        
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: 0.016 * 2, preferredTimescale: timeScale)

        
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self]  time in
            self?.updateValues { current in
                if !current.suspended {
                    return current.withUpdatedMove(CGFloat(CMTimeGetSeconds(time) / duration))
                } else {
                    return current
                }
            }
        }
        
        
        self.player.play()
    }
    
    private func runKeyFrameUpdater(_ keyFrame: CGFloat) {
        let duration = CMTimeGetSeconds(asset.duration)

        let size = genericView.selectionRectView.selectedRect.size
        
        let signal = generateVideoAvatarPreview(for: self.asset, composition: self.currentVideoComposition(), highSize: size, lowSize: NSMakeSize(30, 30), at: Double(keyFrame) * duration)
            |> deliverOnMainQueue
        
        keyFrameGeneratorDisposable.set(signal.start(next: { [weak self] highRes, lowRes in
            self?.genericView.setKeyFrame(value: keyFrame, highRes: highRes, lowRes: lowRes, animated: true, completion: { completed in
                if completed {
                    self?.updateValues {
                        $0.withUpdatedPaused(false)
                            .withUpdatedMove(keyFrame)
                    }
                    self?.updateValues {
                        $0.withUpdatedSuspended(false)
                    }
                } else {
                    self?.updateValues {
                        $0.withUpdatedSuspended(false)
                        .withUpdatedPaused(false)
                    }
                }

            })
            self?.appliedKeyFrame = keyFrame
        }))
    }
    
    override var closable: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        genericView.update(self.player, localize: self.localize, size: self.videoSize)
        
        genericView.cancel.set(handler: { [weak self] _ in
            self?.close()
        }, for: .Click)
        
        genericView.ok.set(handler: { [weak self] _ in
            _ = self?.returnKeyAction()
        }, for: .Click)
        
        let duration = CMTimeGetSeconds(asset.duration)
        
        let scrubberSize = genericView.scrubberView.frame.width
        
        let valueSec = (scrubberSize / CGFloat(duration)) / scrubberSize
        
        self.updateValues { values in
            return values.withUpdatedMinDist(valueSec).withUpdatedMaxDist(valueSec * 10.0).withUpdatedrightTrim(min(1, valueSec * 10.0))
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



func selectVideoAvatar(context: AccountContext, path: String, localize: String, signal:@escaping(Signal<VideoAvatarGeneratorState, NoError>)->Void) {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let track = asset.tracks(withMediaType: .video).first
    if let track = track {
        let composition = AVMutableComposition()
        guard let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return
        }
        do {
            try compositionVideoTrack.insertTimeRange(CMTimeRangeMake(start: .zero, duration: asset.duration), of: track, at: .zero)
            let controller = VideoAvatarModalController(context: context, asset: composition, track: track, localize: localize)
            showModal(with: controller, for: context.window)
            signal(controller.completeState)
        } catch {
            
        }
    }
}


private func generateVideo(_ asset: AVComposition, composition: AVVideoComposition, values: VideoScrubberValues) -> Signal<VideoAvatarGeneratorState, NoError> {
    return Signal { subscriber in
        
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality)!
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        let videoPath = NSTemporaryDirectory() + "\(arc4random()).mp4"
        let thumbPath = NSTemporaryDirectory() + "\(arc4random()).jpg"
        
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.maximumSize = CGSize(width: 640, height: 640)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        
        
        imageGenerator.videoComposition = composition
        let image = try? imageGenerator.copyCGImage(at: CMTimeMakeWithSeconds(Double(values.keyFrame ?? values.leftTrim) * asset.duration.seconds, preferredTimescale: 1000), actualTime: nil)
        if let image = image {
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
            
            try? (mutableData as Data).write(to: URL(fileURLWithPath: thumbPath))
            
            subscriber.putNext(.start(thumb: thumbPath))
            
        }
        
        exportSession.outputURL = URL(fileURLWithPath: videoPath)
        
        exportSession.videoComposition = composition
        
        
        
        let wholeDuration = CMTimeGetSeconds(asset.duration)
        
        let from = TimeInterval(values.leftTrim) * wholeDuration
        let to = TimeInterval(values.rightTrim) * wholeDuration
        
        let start = CMTimeMakeWithSeconds(from, preferredTimescale: 1000)
        let duration = CMTimeMakeWithSeconds(to - from, preferredTimescale: 1000)
        
        if #available(OSX 10.14, *) {
            exportSession.fileLengthLimit = 2 * 1024 * 1024
        }
        
        let timer = SwiftSignalKit.Timer(timeout: 0.05, repeat: true, completion: {
            subscriber.putNext(.progress(exportSession.progress))
        }, queue: .concurrentBackgroundQueue())
        
        exportSession.timeRange = CMTimeRangeMake(start: start, duration: duration)
        
        
        exportSession.exportAsynchronously(completionHandler: { [weak exportSession] in
            
            timer.invalidate()
            
            if let exportSession = exportSession, exportSession.status == .completed, exportSession.error == nil {
                subscriber.putNext(.complete(thumb: thumbPath, video: videoPath, keyFrame: values.keyFrame != nil ? Double(values.keyFrame!) * asset.duration.seconds : nil))
                subscriber.putCompletion()
                
            } else {
                subscriber.putNext(.error)
                subscriber.putCompletion()
            }
            
        })

      
        
        timer.start()
        
        return ActionDisposable {
            exportSession.cancelExport()
            timer.invalidate()
        }
    } |> runOn(.concurrentBackgroundQueue())
}



/*
 - (UIImageOrientation)getVideoOrientationFromAsset:(AVAsset *)asset
 {
 AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
 CGSize size = [videoTrack naturalSize];
 CGAffineTransform txf = [videoTrack preferredTransform];
 
 if (size.width == txf.tx && size.height == txf.ty)
 return UIImageOrientationLeft; //return UIInterfaceOrientationLandscapeLeft;
 else if (txf.tx == 0 && txf.ty == 0)
 return UIImageOrientationRight; //return UIInterfaceOrientationLandscapeRight;
 else if (txf.tx == 0 && txf.ty == size.width)
 return UIImageOrientationDown; //return UIInterfaceOrientationPortraitUpsideDown;
 else
 return UIImageOrientationUp;  //return UIInterfaceOrientationPortrait;
 }
 */
