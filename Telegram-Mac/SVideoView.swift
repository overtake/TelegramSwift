//
//  SVideoView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12/11/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac

enum SVideoControlsStyle : Equatable {
    case regular(pip: Bool, fullScreen: Bool, hideRewind: Bool)
    case compact(pip: Bool, fullScreen: Bool, hideRewind: Bool)
    
    func withUpdatedPip(_ pip: Bool) -> SVideoControlsStyle {
        switch self {
        case let .regular(_, fullScreen, hideRewind):
            return .regular(pip: pip, fullScreen: fullScreen, hideRewind: hideRewind)
        case let .compact(_, fullScreen, hideRewind):
            return .compact(pip: pip, fullScreen: fullScreen, hideRewind: hideRewind)
        }
    }
    
    func withUpdatedFullScreen(_ fullScreen: Bool) -> SVideoControlsStyle {
        switch self {
        case let .regular(pip, _, hideRewind):
            return .regular(pip: pip, fullScreen: fullScreen, hideRewind: hideRewind)
        case let .compact(pip, _, hideRewind):
            return .compact(pip: pip, fullScreen: fullScreen, hideRewind: hideRewind)
        }
    }
    
    func withUpdatedStyle(compact: Bool) -> SVideoControlsStyle {
        switch self {
        case let .regular(pip, fullScreen, hideRewind), let .compact(pip, fullScreen, hideRewind):
            return compact ? .compact(pip: pip, fullScreen: fullScreen, hideRewind: hideRewind) : .regular(pip: pip, fullScreen: fullScreen, hideRewind: hideRewind)
        }
    }
    func withUpdatedHideRewind(hideRewind: Bool) -> SVideoControlsStyle {
        switch self {
        case let .regular(pip, fullScreen, _):
            return .regular(pip: pip, fullScreen: fullScreen, hideRewind: hideRewind)
        case let .compact(pip, fullScreen, _):
            return .compact(pip: pip, fullScreen: fullScreen, hideRewind: hideRewind)
        }
    }
    
    var isPip: Bool {
        switch self {
        case let .regular(pip, _, _), let .compact(pip, _, _):
            return pip
        }
    }
    var isFullScreen: Bool {
        switch self {
        case let .regular(_, fullScreen, _), let .compact(_, fullScreen, _):
            return fullScreen
        }
    }
    var hideRewind: Bool {
        switch self {
        case let .regular(_, _, hideRewind), let .compact(_, _, hideRewind):
            return hideRewind
        }
    }
    
    var isCompact: Bool {
        switch self {
        case .compact:
            return true
        case .regular:
            return false
        }
    }
}


final class SVideoInteractions {
    let playOrPause: ()->Void
    let rewind:(Double)->Void
    let volume:(Float) -> Void
    let toggleFullScreen:() -> Void
    let togglePictureInPicture: ()->Void
    let closePictureInPicture: ()->Void
    init(playOrPause: @escaping()->Void, rewind: @escaping(Double)->Void, volume: @escaping(Float) -> Void, toggleFullScreen: @escaping()->Void, togglePictureInPicture: @escaping() -> Void, closePictureInPicture:@escaping()->Void) {
        self.playOrPause = playOrPause
        self.rewind = rewind
        self.volume = volume
        self.toggleFullScreen = toggleFullScreen
        self.togglePictureInPicture = togglePictureInPicture
        self.closePictureInPicture = closePictureInPicture
    }
}

private final class SVideoControlsView : Control {
    
    var bufferingRanges:[Range<CGFloat>] = [] {
        didSet {
            progress.set(fetchingProgressRanges: bufferingRanges, animated: oldValue != bufferingRanges)
        }
    }
    
    var scrubberInsideBuffering: Bool {
        for range in bufferingRanges {
            if range.contains(progress.currentValue) {
                return true
            }
        }
        return bufferingRanges.isEmpty
    }
    
    var controlStyle: SVideoControlsStyle = .regular(pip: false, fullScreen: false, hideRewind: false) {
        didSet {
            rewindBackward.isHidden = controlStyle.hideRewind
            rewindForward.isHidden = controlStyle.hideRewind
            volumeContainer.isHidden = controlStyle.isCompact
            togglePip.set(image: controlStyle.isPip ? theme.icons.videoPlayerPIPOut : theme.icons.videoPlayerPIPIn, for: .Normal)
            toggleFullscreen.set(image: controlStyle.isPip ? theme.icons.videoPlayerClose : controlStyle.isFullScreen ? theme.icons.videoPlayerExitFullScreen : theme.icons.videoPlayerEnterFullScreen, for: .Normal)
            layout()
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if progress.hasTemporaryState {
            progress.mouseUp(with: event)
        } else if volumeSlider.hasTemporaryState {
            volumeSlider.mouseUp(with: event)
        } else {
            super.mouseUp(with: event)
        }
    }
    
    
    override var mouseDownCanMoveWindow: Bool {
        return false
    }

    
    fileprivate func update(with status: MediaPlayerStatus, animated: Bool) {
        volumeSlider.set(progress: CGFloat(status.volume))
        volumeToggle.set(image: status.volume.isZero ? theme.icons.videoPlayerVolumeOff : theme.icons.videoPlayerVolume, for: .Normal)
        
        rewindForward.isEnabled = status.duration > 30 && !status.generationTimestamp.isZero
        rewindBackward.isEnabled = status.duration > 30 && !status.generationTimestamp.isZero
        rewindForward.layer?.opacity = rewindForward.isEnabled ? 1.0 : 0.3
        rewindBackward.layer?.opacity = rewindForward.isEnabled ? 1.0 : 0.3
        
        playOrPause.isEnabled = status.duration > 0
        progress.isEnabled = status.duration > 0
        
        switch status.status {
        case .playing:
            playOrPause.set(image: theme.icons.videoPlayerPause, for: .Normal)
            progress.set(progress: status.duration == 0 ? 0 : CGFloat(status.timestamp / status.duration), animated: animated, duration: status.duration, beginTime: status.generationTimestamp, offset: status.timestamp, speed: Float(status.baseRate))
        case .paused:
            playOrPause.set(image: status.generationTimestamp == 0 ? theme.icons.videoPlayerPause : theme.icons.videoPlayerPlay, for: .Normal)
            progress.set(progress: status.duration == 0 ? 0 : CGFloat(status.timestamp / status.duration), animated: false)
        case let .buffering(_, whilePlaying):
            playOrPause.set(image: whilePlaying ? theme.icons.videoPlayerPause : theme.icons.videoPlayerPlay, for: .Normal)
            progress.set(progress: status.duration == 0 ? 0 : CGFloat(status.timestamp / status.duration), animated: false)
        }
        let currentTimeAttr: NSAttributedString = .initialize(string: status.timestamp == 0 && status.duration == 0 ? "--:--" : String.durationTransformed(elapsed: Int(status.timestamp)), color: .white, font: .medium(11))
        let durationTimeAttr: NSAttributedString = .initialize(string: status.duration == 0 ? "--:--" : String.durationTransformed(elapsed: Int(status.duration)), color: .white, font: .medium(11))
        
        let currentTimeLayout = TextViewLayout(currentTimeAttr, alignment: .center)
        let durationLayout = TextViewLayout(durationTimeAttr, alignment: .center)
        currentTimeLayout.measure(width: .greatestFiniteMagnitude)
        durationLayout.measure(width: .greatestFiniteMagnitude)
        
        currentTimeView.setFrameSize(currentTimeLayout.layoutSize.width > 33 ? 40 : 33, currentTimeView.frame.height)
        durationView.setFrameSize(durationLayout.layoutSize.width > 33 ? 40 : 33, durationView.frame.height)

        
        currentTimeView.set(layout: currentTimeLayout)
        durationView.set(layout: durationLayout)
        
        currentTimeView.needsDisplay = true
        durationView.needsDisplay = true
    }
    
    var status: MediaPlayerStatus? {
        didSet {
            if let status = status {
                let animated = oldValue?.seekId == status.seekId && (oldValue?.timestamp ?? 0) <= status.timestamp && !status.generationTimestamp.isZero && status != oldValue
                update(with: status, animated: animated)
            } else {
                rewindForward.isEnabled = false
                rewindBackward.isEnabled = false
                playOrPause.isEnabled = false
            }
        }
    }
    
    let backgroundView: NSVisualEffectView = NSVisualEffectView()
    let playOrPause: ImageButton = ImageButton()
    let progress: LinearProgressControl = LinearProgressControl(progressHeight: 5)
    let rewindForward: ImageButton = ImageButton()
    let rewindBackward: ImageButton = ImageButton()
    let toggleFullscreen: ImageButton = ImageButton()
    let togglePip: ImageButton = ImageButton()
    
    let volumeContainer: View = View()
    let volumeToggle: ImageButton = ImageButton()
    let volumeSlider: LinearProgressControl = LinearProgressControl(progressHeight: 5)
    
    private let durationView: TextView = TextView()
    private let currentTimeView: TextView = TextView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(backgroundView)
        addSubview(playOrPause)
        addSubview(progress)
        addSubview(rewindForward)
        addSubview(rewindBackward)
        addSubview(toggleFullscreen)
        addSubview(togglePip)
        addSubview(durationView)
        addSubview(currentTimeView)
        
        togglePip.hideAnimated = true
        
        
        
        durationView.setFrameSize(33, 13)
        currentTimeView.setFrameSize(33, 13)
        
        durationView.userInteractionEnabled = false
        durationView.isSelectable = false
        durationView.backgroundColor = .clear
        
        currentTimeView.userInteractionEnabled = false
        currentTimeView.isSelectable = false
        currentTimeView.backgroundColor = .clear
        

        volumeContainer.addSubview(volumeToggle)
        volumeContainer.addSubview(volumeSlider)
        
        volumeToggle.autohighlight = false
        volumeToggle.set(image: theme.icons.videoPlayerVolume, for: .Normal)
        _ = volumeToggle.sizeToFit()
        volumeSlider.setFrameSize(NSMakeSize(60, 12))
        volumeContainer.setFrameSize(NSMakeSize(volumeToggle.frame.width + 60 + 16, volumeToggle.frame.height))
        
        volumeSlider.scrubberImage = theme.icons.videoPlayerSliderInteractor
        volumeSlider.roundCorners = true
        volumeSlider.alignment = .center
        volumeSlider.containerBackground = NSColor.grayBackground.withAlphaComponent(0.2)
        volumeSlider.style = ControlStyle(foregroundColor: .white, backgroundColor: .clear, highlightColor: .clear)
        volumeSlider.set(progress: 0.8)
        
        volumeSlider.insets = NSEdgeInsetsMake(0, 4.5, 0, 4.5)
        
        addSubview(volumeContainer)
        
        backgroundView.material = .ultraDark
        backgroundView.blendingMode = .withinWindow
        
        playOrPause.autohighlight = false
        rewindForward.autohighlight = false
        rewindBackward.autohighlight = false
        toggleFullscreen.autohighlight = false
        togglePip.autohighlight = false

        
        rewindForward.set(image: theme.icons.videoPlayerRewind15Forward, for: .Normal)
        rewindBackward.set(image: theme.icons.videoPlayerRewind15Backward, for: .Normal)
        
        playOrPause.set(image: theme.icons.videoPlayerPause, for: .Normal)
        
        toggleFullscreen.set(image: theme.icons.videoPlayerEnterFullScreen, for: .Normal)
        togglePip.set(image: theme.icons.videoPlayerPIPIn, for: .Normal)

        
        _ = rewindForward.sizeToFit()
        _ = rewindBackward.sizeToFit()
        _ = playOrPause.sizeToFit()
        _ = toggleFullscreen.sizeToFit()
        _ = togglePip.sizeToFit()

        progress.insets = NSEdgeInsetsMake(0, 4.5, 0, 4.5)
        progress.scrubberImage = theme.icons.videoPlayerSliderInteractor
        progress.roundCorners = true
        progress.alignment = .center
        progress.liveScrobbling = false
        progress.fetchingColor = NSColor.grayBackground.withAlphaComponent(0.6)
        progress.containerBackground = NSColor.grayBackground.withAlphaComponent(0.2)
        progress.style = ControlStyle(foregroundColor: .white, backgroundColor: .clear, highlightColor: .clear)
        progress.set(progress: 0, animated: false, duration: 0)
        wantsLayer = true
        layer?.cornerRadius = 15
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    override func layout() {
        super.layout()
        backgroundView.frame = bounds
        
        playOrPause.centerX(y: 16)
        
        rewindBackward.setFrameOrigin(playOrPause.frame.minX - rewindBackward.frame.width - 36, 16)
        rewindForward.setFrameOrigin(playOrPause.frame.maxX + 36, 16)
        
        toggleFullscreen.setFrameOrigin(frame.width - toggleFullscreen.frame.width - 16, 16)
        
        switch controlStyle {
        case .compact:
            togglePip.setFrameOrigin(16, 16)
        case .regular:
            togglePip.setFrameOrigin(toggleFullscreen.frame.minX - togglePip.frame.width - 24, 16)
        }
        
        
        
        volumeContainer.setFrameOrigin(16, 16)
        volumeToggle.centerY(x: 0)
        volumeSlider.centerY(x: volumeToggle.frame.maxX + 16)
        
        
        switch controlStyle {
        case .compact:
            progress.setFrameOrigin(16 + currentTimeView.frame.width + 16, frame.height - 20 - progress.frame.height + (progress.frame.height - progress.progressHeight) / 2)
        case .regular:
            progress.setFrameOrigin(volumeContainer.frame.minX + volumeSlider.frame.minX, frame.height - 20 - progress.frame.height + (progress.frame.height - progress.progressHeight) / 2)
        }
        progress.setFrameSize(NSMakeSize(frame.width - progress.frame.origin.x - 16 - 16 - durationView.frame.width, 12))
        
        currentTimeView.setFrameOrigin(16, progress.frame.minY)
        durationView.setFrameOrigin(frame.width - durationView.frame.width - 16, progress.frame.minY)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SVideoView: NSView {
    
    var controlsStyle:SVideoControlsStyle = .regular(pip: false, fullScreen: false, hideRewind: false) {
        didSet {
            if oldValue != controlsStyle {
                controls.controlStyle = controlsStyle
                
                if let status = status {
                    self.controls.update(with: status, animated: false)
                    self.controls.update(with: status, animated: true)
                }
                let bufferingStatus = self.bufferingStatus
                self.bufferingStatus = bufferingStatus
            }
        }
    }
    private let bufferingIndicatorValueDisposable = MetaDisposable()
    let bufferingIndicatorValue: Promise<Bool> = Promise(false)
    
    var interactions: SVideoInteractions?
    
    var isStreamable: Bool = true
    
    
    
    var status: MediaPlayerStatus? = nil {
        didSet {
            controls.status = status
            if let status = status {
                switch status.status {
                case .buffering:
                    bufferingIndicatorValue.set(.single(!isStreamable) |> delay(0.2, queue: Queue.mainQueue()))
                default:
                    bufferingIndicatorValue.set(.single(true))
                }
            } else {
                bufferingIndicatorValue.set(.single(!isStreamable))
            }
        }
    }
    var bufferingStatus: (IndexSet, Int)? {
        didSet {
            if let ranges = bufferingStatus {
                var bufRanges: [Range<CGFloat>] = []
                for range in ranges.0.rangeView {
                    let low = CGFloat(range.lowerBound) / CGFloat(ranges.1)
                    let high = CGFloat(range.upperBound) / CGFloat(ranges.1)
                    let br: Range<CGFloat> = Range<CGFloat>(uncheckedBounds: (lower: low, upper: high))
                    bufRanges.append(br)
                }
                controls.bufferingRanges = bufRanges
            } else {
                controls.bufferingRanges = [Range(uncheckedBounds: (lower: -1, upper: -1))]
            }
        }
    }
    private let bufferingIndicator: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 40, 40))
    private let controls: SVideoControlsView = SVideoControlsView(frame: NSZeroRect)
    let mediaPlayer: MediaPlayerView = MediaPlayerView()
    private let backgroundView: NSView = NSView()
    override func layout() {
        super.layout()
        mediaPlayer.frame = bounds
        mediaPlayer.updateLayout()
        self.controlsStyle = self.controlsStyle.withUpdatedStyle(compact: frame.width < 300).withUpdatedHideRewind(hideRewind: frame.width < 400)
        controls.setFrameSize(self.controlsStyle.isCompact ? 220 : min(frame.width - 10, 510), 94)
        let bufferingStatus = self.bufferingStatus
        self.bufferingStatus = bufferingStatus
        controls.centerX(y: frame.height - controls.frame.height - 24)
        bufferingIndicator.center()
        backgroundView.frame = bounds
    }
    
    func hideControls(_ hide: Bool, animated: Bool) {
        if !hide {
            controls.isHidden = false
        }
        controls._change(opacity: hide ? 0 : 1, animated: animated, duration: 0.2, timingFunction: .linear, completion: { [weak self] completed in
            if completed {
                self?.controls.isHidden = hide
            }
        })
    }
    
    
    override func mouseUp(with event: NSEvent) {
        let point = self.convert(event.locationInWindow, from: nil)
        if !NSPointInRect(point, controls.frame) {
            super.mouseUp(with: event)
        }
    }
    
    
    var insideControls: Bool {
        guard let window = window else {return false}
        let point = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        return NSPointInRect(point, controls.frame) && !controls.isHidden
    }
    
    private func updateLayout() {
        
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    func rewindBackward() {
        controls.rewindBackward.send(event: .Click)
    }
    func rewindForward() {
        controls.rewindForward.send(event: .Click)
    }
    
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(backgroundView)
        addSubview(mediaPlayer)
        addSubview(bufferingIndicator)
        addSubview(controls)
        
        backgroundView.wantsLayer = true
        backgroundView.background = .black
        
        bufferingIndicator.backgroundColor = .blackTransparent
        bufferingIndicator.layer?.cornerRadius = 20
        
        backgroundView.isHidden = true

        
        controls.playOrPause.set(handler: { [weak self] _ in
            self?.interactions?.playOrPause()
        }, for: .Click)
        
        controls.progress.onUserChanged = { [weak self] value in
            guard let `self` = self else {return}
            if let status = self.status {
                self.status = status.withUpdatedTimestamp(status.duration * Double(value))
                self.interactions?.rewind(status.duration * Double(value))
            }
        }
        
        controls.volumeSlider.onUserChanged = { [weak self] value in
            guard let `self` = self else {return}
            self.interactions?.volume(value)
        }
        controls.volumeToggle.set(handler: { [weak self] _ in
            guard let `self` = self else {return}
            if let status = self.status {
                self.interactions?.volume(status.volume == 0 ? 0.8 : 0)
            }
        }, for: .Click)
        
        controls.rewindForward.set(handler: { [weak self] _ in
            guard let `self` = self else {return}
            if let status = self.status {
                self.interactions?.rewind(min(status.timestamp + 15, status.duration))
            }
        }, for: .Click)
        
        controls.rewindBackward.set(handler: { [weak self] _ in
            guard let `self` = self else {return}
            if let status = self.status {
                self.interactions?.rewind(max(status.timestamp - 15, 0))
            }
        }, for: .Click)
        
        controls.toggleFullscreen.set(handler: { [weak self] _ in
            guard let `self` = self else {return}
            if self.controlsStyle.isPip {
                self.interactions?.closePictureInPicture()
            } else {
                self.interactions?.toggleFullScreen()
            }
        }, for: .Click)
        
        controls.togglePip.set(handler: { [weak self] _ in
            self?.interactions?.togglePictureInPicture()
        }, for: .Click)
        
        
        bufferingIndicatorValueDisposable.set(bufferingIndicatorValue.get().start(next: { [weak self] isHidden in
            self?.bufferingIndicator.isHidden = isHidden
        }))
    }
    
    deinit {
        bufferingIndicatorValueDisposable.dispose()
    }
    
    func set(isInPictureInPicture: Bool) {
        self.controlsStyle = self.controlsStyle.withUpdatedPip(isInPictureInPicture)
    }
    
    func set(isInFullScreen: Bool) {
        self.controlsStyle = self.controlsStyle.withUpdatedFullScreen(isInFullScreen)
        backgroundView.isHidden = !isInFullScreen
    }
}
