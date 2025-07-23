//
//  ChatMessagePhotoContent.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import Postbox
import TelegramCore
import TextRecognizing
import TGUIKit
import TelegramMedia
import TelegramMediaPlayer

extension AutoremoveTimeoutMessageAttribute : Equatable {
    public static func == (lhs: AutoremoveTimeoutMessageAttribute, rhs: AutoremoveTimeoutMessageAttribute) -> Bool {
        return lhs.timeout == rhs.timeout && lhs.countdownBeginTime == rhs.countdownBeginTime && lhs.associatedMessageIds == rhs.associatedMessageIds
    }
}



final class ChatVideoAutoplayView {
    let mediaPlayer: MediaPlayer
    let view: MediaPlayerView
    
    fileprivate var playTimer: SwiftSignalKit.Timer?
    var status: MediaPlayerStatus?

    private var timer: SwiftSignalKit.Timer? = nil
    
    init(mediaPlayer: MediaPlayer, view: MediaPlayerView) {
        self.mediaPlayer = mediaPlayer
        self.view = view
        mediaPlayer.actionAtEnd = .loop(nil)
        

    }
    
    func toggleVolume(_ enabled: Bool, animated: Bool) {
        if !animated {
            mediaPlayer.setVolume(enabled ? 1 : 0)
            timer?.invalidate()
            timer = nil
        } else {
            timer = nil
            
            let start:(Float) -> Void = { [weak self] volume in
                let fps = Float(1000 / 60)
                var current:Float = volume

                let tick = (enabled ? 1 - current : -current) / (fps * 0.3)
                
                self?.timer = SwiftSignalKit.Timer(timeout: abs(Double(tick)), repeat: true, completion: { [weak self] in
                    current += tick
                    self?.mediaPlayer.setVolume(min(1, max(0, current)))
                    
                    if current >= 1 || current <= 0 {
                        self?.timer?.invalidate()
                    }
                }, queue: .mainQueue())
                
                self?.timer?.start()
            }
            
            mediaPlayer.getVolume { volume in
                Queue.mainQueue().justDispatch {
                    start(volume)
                }
            }
        }
    }
    
    deinit {
        view.removeFromSuperview()
        timer?.invalidate()
        playTimer?.invalidate()
    }
}


final class CornerMaskLayer : SimpleShapeLayer {
    var positionFlags: LayoutPositionFlags? {
        didSet {
            if let positionFlags = positionFlags {
                let path = CGMutablePath()
                
                let minx:CGFloat = 0, midx = frame.width/2.0, maxx = frame.width
                let miny:CGFloat = 0, midy = frame.height/2.0, maxy = frame.height
                
                path.move(to: NSMakePoint(minx, midy))
                
                var topLeftRadius: CGFloat = .cornerRadius
                var bottomLeftRadius: CGFloat = .cornerRadius
                var topRightRadius: CGFloat = .cornerRadius
                var bottomRightRadius: CGFloat = .cornerRadius
                
                
                if positionFlags.contains(.top) && positionFlags.contains(.left) {
                    bottomLeftRadius = .cornerRadius * 3 + 2
                }
                if positionFlags.contains(.top) && positionFlags.contains(.right) {
                    bottomRightRadius = .cornerRadius * 3 + 2
                }
                if positionFlags.contains(.bottom) && positionFlags.contains(.left) {
                    topLeftRadius = .cornerRadius * 3 + 2
                }
                if positionFlags.contains(.bottom) && positionFlags.contains(.right) {
                    topRightRadius = .cornerRadius * 3 + 2
                }
                
                path.addArc(tangent1End: NSMakePoint(minx, miny), tangent2End: NSMakePoint(midx, miny), radius: bottomLeftRadius)
                path.addArc(tangent1End: NSMakePoint(maxx, miny), tangent2End: NSMakePoint(maxx, midy), radius: bottomRightRadius)
                path.addArc(tangent1End: NSMakePoint(maxx, maxy), tangent2End: NSMakePoint(midx, maxy), radius: topRightRadius)
                path.addArc(tangent1End: NSMakePoint(minx, maxy), tangent2End: NSMakePoint(minx, midy), radius: topLeftRadius)
                
                self.path = path
            }
        }
    }

}


final class CornerMaskLayerSimple : SimpleLayer {
    var positionFlags: LayoutPositionFlags? {
        didSet {
            if let positionFlags = positionFlags {
                
                let layer = SimpleShapeLayer()
                
                let path = CGMutablePath()
                
                let minx:CGFloat = 0, midx = frame.width/2.0, maxx = frame.width
                let miny:CGFloat = 0, midy = frame.height/2.0, maxy = frame.height
                
                path.move(to: NSMakePoint(minx, midy))
                
                var topLeftRadius: CGFloat = .cornerRadius
                var bottomLeftRadius: CGFloat = .cornerRadius
                var topRightRadius: CGFloat = .cornerRadius
                var bottomRightRadius: CGFloat = .cornerRadius
                
                
                
                if positionFlags.contains(.top) && positionFlags.contains(.left) {
                    bottomLeftRadius = .cornerRadius * 3 + 2
                }
                if positionFlags.contains(.top) && positionFlags.contains(.right) {
                    bottomRightRadius = .cornerRadius * 3 + 2
                }
                if positionFlags.contains(.bottom) && positionFlags.contains(.left) {
                    topLeftRadius = .cornerRadius * 3 + 2
                }
                if positionFlags.contains(.bottom) && positionFlags.contains(.right) {
                    topRightRadius = .cornerRadius * 3 + 2
                }
                
                path.addArc(tangent1End: NSMakePoint(minx, miny), tangent2End: NSMakePoint(midx, miny), radius: bottomLeftRadius)
                path.addArc(tangent1End: NSMakePoint(maxx, miny), tangent2End: NSMakePoint(maxx, midy), radius: bottomRightRadius)
                path.addArc(tangent1End: NSMakePoint(maxx, maxy), tangent2End: NSMakePoint(midx, maxy), radius: topRightRadius)
                path.addArc(tangent1End: NSMakePoint(minx, maxy), tangent2End: NSMakePoint(minx, midy), radius: topLeftRadius)
                
                layer.path = path
                
                self.mask = layer
            }
        }
    }

}



private let sensitiveImage = NSImage(resource: .iconMediaSensitiveContent).precomposed(.white)

final class MediaInkView : Control {
    
    private final class SensitiveView: NSVisualEffectView {
        private let textView = TextView()
        private let imageView = ImageView()
        required override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.wantsLayer = true
            self.material = .ultraDark
            self.blendingMode = .withinWindow
            self.state = .active
            
            addSubview(textView)
            addSubview(imageView)
            
            
            imageView.image = sensitiveImage
            imageView.sizeToFit()
            
            let textLayout = TextViewLayout(.initialize(string: strings().chatSensitiveContent, color: NSColor.white, font: .medium(.text)))
            textLayout.measure(width: .greatestFiniteMagnitude)
            
            textView.update(textLayout)
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            
            setFrameSize(NSMakeSize(textView.frame.width + 25 + imageView.frame.width, 30))
        }
        
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            self.imageView.centerY(x: 10)
            self.textView.centerY(x: imageView.frame.maxX + 5)
        }
    }
    
    private final class PaidContentView: NSVisualEffectView {
        private let textView = InteractiveTextView()
        required override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.wantsLayer = true
            self.material = .ultraDark
            self.blendingMode = .withinWindow
            self.state = .active
            
            addSubview(textView)
            
            textView.userInteractionEnabled = false
            textView.textView.isSelectable = false
            
        }
        
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(amount: Int64, context: AccountContext, short: Bool) {
            
            let attr = NSMutableAttributedString()
            attr.append(string: "\(clown)", color: .white, font: .medium(.text))
            attr.insertEmbedded(.embeddedAnimated(LocalAnimatedSticker.star_currency_new.file), for: clown)
            attr.append(string: " \(amount)", color: .white, font: .medium(.text))
            
            let textLayout = TextViewLayout(attr)
            textLayout.measure(width: .greatestFiniteMagnitude)

            self.textView.set(text: textLayout, context: context)
            
            self.setFrameSize(NSMakeSize(textView.frame.width + 20, 30))

        }
        
        override func layout() {
            super.layout()
            self.textView.centerY(x: 10)
        }
    }

    
    private let inkView: MediaDustView = MediaDustView()
    private var inkMaskView: CornerMaskLayer?

    private let preview: TransformImageView = TransformImageView()
    
    private var sensitiveView: SensitiveView?
    private var paidView: PaidContentView?

    private var isSensitive: Bool = false
    private var payAmount: Int64? = nil
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(preview)
        addSubview(inkView)
        
        inkView.update(revealed: false)

    }
    

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(isRevealed: Bool, updated: Bool, context: AccountContext, imageReference: ImageMediaReference, size: NSSize, positionFlags: LayoutPositionFlags?, synchronousLoad: Bool, isSensitive: Bool, payAmount: Int64?) {
        
        
        self.isSensitive = isSensitive
        self.payAmount = payAmount
        
        if isSensitive {
            let current: SensitiveView
            if let view = self.sensitiveView {
                current = view
            } else {
                current = SensitiveView(frame: NSMakeRect(0, 0, 100, 30))
                current.layer?.cornerRadius = current.frame.height / 2
                self.sensitiveView = current
                addSubview(current)
            }
        } else if let view = self.sensitiveView {
            performSubviewRemoval(view, animated: false)
            self.sensitiveView = nil
        }
        
        if let payAmount {
            let current: PaidContentView
            if let view = self.paidView {
                current = view
            } else {
                current = PaidContentView(frame: NSMakeRect(0, 0, 100, 30))
                self.paidView = current
                addSubview(current)
            }
            current.update(amount: payAmount, context: context, short: true)
            current.layer?.cornerRadius = current.frame.height / 2
        } else if let view = self.paidView {
            performSubviewRemoval(view, animated: false)
            self.paidView = nil
        }
                
        
        let signal = chatSecretPhoto(account: context.account, imageReference: imageReference, scale: System.backingScale, synchronousLoad: synchronousLoad)
        let arguments = TransformImageArguments(corners: .init(), imageSize: size, boundingSize: size, intrinsicInsets: .init())
        
        
        self.preview.setSignal(signal: cachedMedia(media: imageReference.media, arguments: arguments, scale: System.backingScale), clearInstantly: updated)
        
        if !self.preview.isFullyLoaded {
            self.preview.setSignal(signal, cacheImage: { result in
                cacheMedia(result, media: imageReference.media, arguments: arguments, scale: System.backingScale)
            })
        }
        
        
        self.preview.set(arguments: arguments)
        

        let inkRect = size.bounds.insetBy(dx: -20, dy: -20)
        
        let current = self.inkView
        current.frame = inkRect
        
        let path = CGMutablePath()
        path.addRect(inkRect.size.bounds)
        
        current.update(size: inkRect.size, color: NSColor.white, textColor: .black, mask: buttonPath(path))
       
        if let positionFlags = positionFlags {
            let mask: CornerMaskLayer
            if let layer = self.inkMaskView {
                mask = layer
            } else {
                mask = CornerMaskLayer()
                self.inkMaskView = mask
            }
            mask.frame = size.bounds
            mask.positionFlags = positionFlags
            self.layer?.mask = mask
        } else {
            inkMaskView = nil
            layer?.mask = nil
            layer?.cornerRadius = 4
        }
        preview.frame = size.bounds
        
        needsLayout = true

    }
    
    private func buttonPath(_ basic: CGPath) -> CGPath {
        let buttonPath = CGMutablePath()

        buttonPath.addPath(basic)
        
        if let view = self.sensitiveView {
            let buttonRect = view.frame
            buttonPath.addRoundedRect(in: buttonRect, cornerWidth: buttonRect.height / 2, cornerHeight: buttonRect.height / 2)
        }
        
        if let view = self.paidView {
            let buttonRect = view.frame
            buttonPath.addRoundedRect(in: buttonRect, cornerWidth: buttonRect.height / 2, cornerHeight: buttonRect.height / 2)
        }
                    
        return buttonPath
    }
    
    override func layout() {
        super.layout()
        preview.frame = bounds
        inkMaskView?.frame = bounds
        inkView.frame = bounds.insetBy(dx: -20, dy: -20)
        sensitiveView?.center()
        paidView?.center()
    }
}

private final class VideoTimestampView : View {
    let progress: LinearProgressControl = .init(progressHeight: 3)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(progress)
        self.isEventLess = true
        
        self.layer = CornerMaskLayerSimple()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        progress.frame = NSMakeRect(0, frame.height - 3, frame.width, 3)
    }
}

class ChatInteractiveContentView: ChatMediaContentView {

    private let image:TransformImageView = TransformImageView()
    private var videoAccessory: ChatMessageAccessoryView? = nil
    private var progressView:RadialProgressView?
    private var timableProgressView: TimableProgressView? = nil
    private let statusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    
    private var videoTimeProgress: VideoTimestampView?
    
    
    private let partDisposable = MetaDisposable()

    private var authenticFetchStatus: MediaResourceStatus?

    
    private let mediaPlayerStatusDisposable = MetaDisposable()
    private var autoplayVideoView: ChatVideoAutoplayView?
    
    private var inkView: MediaInkView?
    
    override var backgroundColor: NSColor {
        get {
            return super.backgroundColor
        }
        set {
            super.backgroundColor = .clear
        }
    }
    
    override func previewMediaIfPossible() -> Bool {
        guard let context = self.context, let window = self._window, let table = self.table, parent == nil || parent?.containsSecretMedia == false, fetchStatus == .Local else {return false}
        startModalPreviewHandle(table, window: window, context: context)
        return true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        //background = .random
        self.addSubview(image)
    }
    

    
    override func updateMouse() {
       
    }
    
    
    override func open() {
        if let parent = parent {
            let forceSpoiler = parameters?.forceSpoiler == true
            let messageSpoiler = parent.isMediaSpoilered
            let isSpoiler = (messageSpoiler || forceSpoiler) && (parameters?.isRevealed == false)
            if isSpoiler {
                parameters?.revealMedia(parent)
            } else {
                parameters?.showMedia(parent)
                autoplayVideoView?.toggleVolume(false, animated: false)
            }
        }
    }
    
    private func updateMediaStatus(_ status: MediaPlayerStatus, animated: Bool = false) {
        if let autoplayVideoView = autoplayVideoView, let media = self.media as? TelegramMediaFile {
            autoplayVideoView.status = status
            updateVideoAccessory(.Local, file: media, mediaPlayerStatus: status, animated: animated)
            
            switch status.status {
            case .playing:
                autoplayVideoView.playTimer?.invalidate()
                autoplayVideoView.playTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                    self?.updateVideoAccessory(.Local, file: media, mediaPlayerStatus: status, animated: animated)
                    }, queue: .mainQueue())
                
                autoplayVideoView.playTimer?.start()
            default:
                autoplayVideoView.playTimer?.invalidate()
            }

            
        }
    }
    

    override func interactionControllerDidFinishAnimation(interactive: Bool) {

    }
    
    override func addAccesoryOnCopiedView(view: NSView) {
        if let videoAccessory = videoAccessory?.copy() as? NSView {
            if effectiveVisibleRect.minY < videoAccessory.frame.midY && effectiveVisibleRect.minY + effectiveVisibleRect.height > videoAccessory.frame.midY {
                videoAccessory.frame.origin.y = frame.height - videoAccessory.frame.maxY
                view.addSubview(videoAccessory)
            }
           
        }
        if let progressView = progressView {
            let pView = RadialProgressView(theme: progressView.theme, twist: true)
            pView.state = progressView.state
            pView.frame = progressView.frame
            if effectiveVisibleRect.minY < progressView.frame.midY && effectiveVisibleRect.minY + effectiveVisibleRect.height > progressView.frame.midY {
                pView.frame.origin.y = frame.height - progressView.frame.maxY
                view.addSubview(pView)
            }
        }
        self.autoplayVideoView?.mediaPlayer.seek(timestamp: 0)
    }
    
    func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidUpdatedDynamicContent() {
        super.viewDidUpdatedDynamicContent()
        updatePlayerIfNeeded()
    }
    
    deinit {
        let deInit = {
            self.removeNotificationListeners()
            self.mediaPlayerStatusDisposable.dispose()
            self.partDisposable.dispose()
        }
        deInit()
    }
    
    private var lite: Bool {
        return (isGif && isLite(.gif)) || (!isGif && isLite(.video))

    }
    
    @objc func updatePlayerIfNeeded() {
        
        var accept = window != nil && window!.isKeyWindow && !NSIsEmptyRect(visibleRect) && !self.isDynamicContentLocked
        
        if lite {
            accept = accept && mouseInside()
        }
                        
        if let autoplayView = autoplayVideoView {
            if accept {
                autoplayView.mediaPlayer.play()
                self.progressView?.isHidden = true
            } else {
                autoplayView.mediaPlayer.pause()
                autoplayVideoView?.playTimer?.invalidate()
                self.progressView?.isHidden = false
            }
        }
    }
    
    var isGif: Bool {
        if let media = self.media as? TelegramMediaFile {
            return media.isVideo && media.isAnimated
        } else {
            return false
        }
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
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSWindow.didResignKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: table?.clipView)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.boundsDidChangeNotification, object: self)
            NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerIfNeeded), name: NSView.frameDidChangeNotification, object: table?.view)
        } else {
            removeNotificationListeners()
        }
    }
    override func willRemove() {
        super.willRemove()
        updateListeners()
        updatePlayerIfNeeded()
    }
    
    override func viewDidMoveToWindow() {
        updateListeners()
        self.updatePlayerIfNeeded()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        self.updatePlayerIfNeeded()
    }
    
    override func layout() {
        super.layout()
        
        progressView?.center()
        timableProgressView?.center()
        videoAccessory?.setFrameOrigin(8, 8)
        self.image.setFrameSize(frame.size)
        inkView?.frame = self.image.frame

        if let file = media as? TelegramMediaFile {
            let dimensions = file.dimensions?.size ?? frame.size
            let size = blurBackground ? dimensions.aspectFitted(frame.size) : frame.size
            self.autoplayVideoView?.view.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - size.width) / 2), floorToScreenPixels(backingScaleFactor, (frame.height - size.height) / 2), size.width, size.height)
            let positionFlags = self.autoplayVideoView?.view.positionFlags
            self.autoplayVideoView?.view.positionFlags = positionFlags

        }
        
        if let videoTimeProgress {
            videoTimeProgress.frame = bounds
        }
        
    }
    
    private func updateVideoAccessory(_ status: MediaResourceStatus, file: TelegramMediaFile, mediaPlayerStatus: MediaPlayerStatus? = nil, animated: Bool = false) {
        let maxWidth = frame.width - 10
        let text: String
        
        var isBuffering: Bool = false
        if let fetchStatus = self.fetchStatus, let status = mediaPlayerStatus {
            switch status.status {
            case .buffering:
                switch fetchStatus {
                case .Local:
                    break
                default:
                    isBuffering = true
                }
            default:
                break
            }
           
        }
        
        switch status {
        case let .Fetching(_, progress), let .Paused(progress):
            let current = String.prettySized(with: Int(Float(file.elapsedSize) * progress), afterDot: 1)
            var size = "\(current) / \(String.prettySized(with: file.elapsedSize))"
            if maxWidth < 150 || file.elapsedSize == 0 {
                size = "\(Int(progress * 100))%"
            }
            if file.isStreamable, parent?.groupingKey == nil, maxWidth > 150 {
                if let parent = parent {
                    if !parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                        size = String.durationTransformed(elapsed: file.videoDuration) + ", \(size)"
                    }
                } else {
                    size = String.durationTransformed(elapsed: file.videoDuration) + ", \(size)"
                } 
            }
            text = size
        case .Remote:
            var size = String.durationTransformed(elapsed: file.videoDuration)
            if file.isStreamable, parent?.groupingKey == nil, maxWidth > 100 {
                 size = size + ", " + String.prettySized(with: file.elapsedSize)
            }
            text = size
        case .Local:
            if file.isVideo && file.isAnimated {
                text = "GIF"
            } else {
                if let status = mediaPlayerStatus, status.generationTimestamp > 0, status.duration > 0 {
                    text = String.durationTransformed(elapsed: Int(status.duration - (status.timestamp + (CACurrentMediaTime() - status.generationTimestamp))))
                } else {
                    text = String.durationTransformed(elapsed: file.videoDuration)
                }
            }
        }
        
        let isStreamable: Bool
        if let parent = parent {
            isStreamable = !parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) && file.isStreamable && !isHLSVideo(file: file)
        } else {
            isStreamable = file.isStreamable && !isHLSVideo(file: file)
        }
        
        let isCompact = parent?.groupingKey != nil || file.isAnimated || frame.width < 200 || isHLSVideo(file: file)
        
        
        videoAccessory?.updateText(text, maxWidth: maxWidth, status: status, isStreamable: isStreamable, isCompact: isCompact, soundOffOnImage: nil, isBuffering: isBuffering, animated: animated, fetch: { [weak self] in
            self?.fetch(userInitiated: true)
        }, cancelFetch: { [weak self] in
            self?.cancelFetching()
        }, click: {
                
        })
        
    }
    
    override func executeInteraction(_ isControl: Bool) {
        
        
        if let progressView = progressView {
            switch progressView.state {
            case .Fetching:
                if isControl {
                    if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                        delete()
                    }
                    cancelFetching()
                }
            default:
                super.executeInteraction(isControl)
            }
        } else {
            if autoplayVideo {
                open()
            } else {
                super.executeInteraction(isControl)
            }
        }
    }
    
    var isStory: Bool {
        return parent?.media.first is TelegramMediaStory
    }
    
    var autoplayVideo: Bool {
        if let autoremoveAttribute = parent?.autoremoveAttribute, autoremoveAttribute.timeout <= 60 {
           return false
        }
        if parent?.media.first is TelegramMediaStory {
            return false
        }
        if let media = media as? TelegramMediaFile, media.videoCover != nil {
            return false
        }
        if parent == nil {
            return true
        }
        if let media = media as? TelegramMediaFile, let parameters = self.parameters {
            let autoplay = (media.isStreamable || authenticFetchStatus == .Local) && (autoDownload || authenticFetchStatus == .Local) && parameters.autoplay && (parent?.groupingKey == nil || self.frame.width == superview?.frame.width)
            return autoplay
        }
        return false
    }
    
    var blurBackground: Bool {
        let blur = ((parent != nil && parent?.groupingKey == nil) || parent == nil)
        if let fillContent = parameters?.fillContent, fillContent {
            return false
        }
        return blur
    }

    override func update(size: NSSize) {
        
        var topLeftRadius: CGFloat = .cornerRadius
        var bottomLeftRadius: CGFloat = .cornerRadius
        var topRightRadius: CGFloat = .cornerRadius
        var bottomRightRadius: CGFloat = .cornerRadius
        
        
        if let positionFlags = positionFlags {
            if positionFlags.contains(.top) && positionFlags.contains(.left) {
                topLeftRadius = topLeftRadius * 3 + 2
            }
            if positionFlags.contains(.top) && positionFlags.contains(.right) {
                topRightRadius = topRightRadius * 3 + 2
            }
            if positionFlags.contains(.bottom) && positionFlags.contains(.left) {
                bottomLeftRadius = bottomLeftRadius * 3 + 2
            }
            if positionFlags.contains(.bottom) && positionFlags.contains(.right) {
                bottomRightRadius = bottomRightRadius * 3 + 2
            }
        }
        
        var dimensions: NSSize = size
        
        if let image = media as? TelegramMediaImage {
            dimensions = image.representationForDisplayAtSize(PixelDimensions(size))?.dimensions.size ?? size
        } else if let file = media as? TelegramMediaFile {
            dimensions = file.dimensions?.size ?? size
        }
        
        let arguments = TransformImageArguments(corners: ImageCorners(topLeft: .Corner(topLeftRadius), topRight: .Corner(topRightRadius), bottomLeft: .Corner(bottomLeftRadius), bottomRight: .Corner(bottomRightRadius)), imageSize: blurBackground ? dimensions.aspectFitted(size) : dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: NSEdgeInsets(), resizeMode: blurBackground ? .blurBackground : .none)
        
        self.image.set(arguments: arguments)
        if self.image.isFullyLoaded {
            
        }
    }
    private var previousIsSpoiler: Bool? = nil

    override func update(with media: Media, size:NSSize, context:AccountContext, parent:Message?, table:TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool, positionFlags: LayoutPositionFlags? = nil, approximateSynchronousValue: Bool = false) {
        
        partDisposable.set(nil)
        
        var videoTimestamp: Int32?
        if let parent = parent {
            var storedVideoTimestamp: Int32?
            for attribute in parent.attributes {
                if let attribute = attribute as? ForwardVideoTimestampAttribute {
                    videoTimestamp = attribute.timestamp
                } else if let attribute = attribute as? DerivedDataMessageAttribute {
                    if let value = attribute.data["mps"]?.get(MediaPlaybackStoredState.self) {
                        storedVideoTimestamp = Int32(value.timestamp)
                    }
                }
            }
            if let storedVideoTimestamp {
                videoTimestamp = storedVideoTimestamp
            }

        }
        
        let versionUpdated = parent?.stableVersion != self.parent?.stableVersion && self.parent?.stableId == parent?.stableId
        
        let removeViewAnimated = self.parent == nil || self.parent?.media.first?.id == parent?.media.first?.id
        
        let forceSpoiler = parameters?.forceSpoiler == true
        let messageSpoiler = parent?.isMediaSpoilered ?? false
        
        
        let isSensitive: Bool
        if let parent = parent {
            isSensitive = parent.isSensitiveContent(platform: "ios") && !context.contentConfig.sensitiveContentEnabled
        } else {
            isSensitive = false
        }
        
        let isSpoiler = (messageSpoiler || forceSpoiler || isSensitive) && (parameters?.isRevealed == false)

        
        let mediaUpdated = self.media == nil || !media.isSemanticallyEqual(to: self.media!) || (parent?.autoremoveAttribute != self.parent?.autoremoveAttribute) || positionFlags != self.positionFlags || self.frame.size != size || previousIsSpoiler != isSpoiler
        
        self.previousIsSpoiler = isSpoiler

        if mediaUpdated, let rhs = media as? TelegramMediaFile, let lhs = self.media as? TelegramMediaFile  {
            if !lhs.isSemanticallyEqual(to: rhs) {
                self.autoplayVideoView = nil
            }
        }
        
        
        var clearInstantly: Bool = mediaUpdated
        if clearInstantly, parent?.stableId == self.parent?.stableId {
            clearInstantly = false
        }
        
        super.update(with: media, size: size, context: context, parent:parent, table: table, parameters:parameters, positionFlags: positionFlags)
        
        let isProtected = !isSpoiler && (parameters?.isProtected ?? false)
        

        
        
        self.image.preventsCapture = isProtected

        
        var topLeftRadius: CGFloat = .cornerRadius
        var bottomLeftRadius: CGFloat = .cornerRadius
        var topRightRadius: CGFloat = .cornerRadius
        var bottomRightRadius: CGFloat = .cornerRadius
        
        
        if let positionFlags = positionFlags {
            if positionFlags.contains(.top) && positionFlags.contains(.left) {
                topLeftRadius = topLeftRadius * 3 + 2
            }
            if positionFlags.contains(.top) && positionFlags.contains(.right) {
                topRightRadius = topRightRadius * 3 + 2
            }
            if positionFlags.contains(.bottom) && positionFlags.contains(.left) {
                bottomLeftRadius = bottomLeftRadius * 3 + 2
            }
            if positionFlags.contains(.bottom) && positionFlags.contains(.right) {
                bottomRightRadius = bottomRightRadius * 3 + 2
            }
        }
        
        var dimensions: NSSize = size
        
        if let image = media as? TelegramMediaImage {
            dimensions = image.representationForDisplayAtSize(PixelDimensions(size))?.dimensions.size ?? size
        } else if let file = media as? TelegramMediaFile {
            if let image = file.videoCover {
                dimensions = image.representationForDisplayAtSize(PixelDimensions(size))?.dimensions.size ?? size
            } else {
                dimensions = file.dimensions?.size ?? size
            }
        }
        

        var updateImageSignal: Signal<ImageDataTransformation, NoError>?
        var updatedStatusSignal: Signal<(MediaResourceStatus, MediaResourceStatus), NoError>?
        
        if mediaUpdated /*mediaUpdated*/ {
        
            
            let arguments = TransformImageArguments(corners: ImageCorners(topLeft: .Corner(topLeftRadius), topRight: .Corner(topRightRadius), bottomLeft: .Corner(bottomLeftRadius), bottomRight: .Corner(bottomRightRadius)), imageSize: blurBackground ? dimensions.aspectFitted(size) : dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: NSEdgeInsets(), resizeMode: blurBackground ? .blurBackground : .none)


            
            if let image = media as? TelegramMediaImage {
                
                autoplayVideoView = nil
                videoAccessory?.removeFromSuperview()
                videoAccessory = nil
                
                if let parent = parent, parent.containsSecretMedia || isSpoiler {
                    updateImageSignal = chatSecretPhoto(account: context.account, imageReference: ImageMediaReference.message(message: MessageReference(parent), media: image), scale: backingScaleFactor, synchronousLoad: approximateSynchronousValue)
                } else {
                    updateImageSignal = chatMessagePhoto(account: context.account, imageReference: parent != nil ? ImageMediaReference.message(message: MessageReference(parent!), media: image) : ImageMediaReference.standalone(media: image), scale: backingScaleFactor, synchronousLoad: approximateSynchronousValue)
                }
                
                if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                    updatedStatusSignal = combineLatest(chatMessagePhotoStatus(account: context.account, photo: image), context.account.pendingMessageManager.pendingMessageStatus(parent.id))
                        |> map { resourceStatus, pendingStatus in
                            if let pendingStatus = pendingStatus.0, parent.forwardInfo == nil || resourceStatus != .Local {
                                let progress: Float
                                progress = pendingStatus.progress.mediaProgress[image.imageId] ?? pendingStatus.progress.progress
                                return (.Fetching(isActive: true, progress: min(progress, progress * 85 / 100)), .Fetching(isActive: true, progress: min(progress, progress * 85 / 100)))
                            } else {
                                return (resourceStatus, resourceStatus)
                            }
                    } |> deliverOnMainQueue
                } else {
                    updatedStatusSignal = chatMessagePhotoStatus(account: context.account, photo: image, approximateSynchronousValue: approximateSynchronousValue) |> map {($0, $0)} |> deliverOnMainQueue
                }
            
            } else if let file = media as? TelegramMediaFile {
                
                
                let fileReference = parent != nil ? FileMediaReference.message(message: MessageReference(parent!), media: file) : FileMediaReference.standalone(media: file)
                
               
                
                if file.isVideo, size.height > 80 {
                    if videoAccessory == nil {
                        videoAccessory = ChatMessageAccessoryView(frame: NSMakeRect(5, 5, 0, 0))
                        addSubview(videoAccessory!)
                    }
                } else {
                    videoAccessory?.removeFromSuperview()
                    videoAccessory = nil
                }
                
                if let parent = parent, parent.containsSecretMedia || isSpoiler {
                    updateImageSignal = chatSecretMessageVideo(account: context.account, fileReference: fileReference, scale: backingScaleFactor)
                } else {
                    updateImageSignal = chatMessageVideo(account: context.account, fileReference: fileReference, scale: backingScaleFactor) //chatMessageVideo(account: account, video: file, scale: backingScaleFactor)
                }
                
                
                if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                    updatedStatusSignal = combineLatest(chatMessageFileStatus(context: context, message: parent, file: file), context.account.pendingMessageManager.pendingMessageStatus(parent.id))
                        |> map { resourceStatus, pendingStatus in
                            if let pendingStatus = pendingStatus.0 {
                                let progress: Float
                                progress = pendingStatus.progress.mediaProgress[file.fileId] ?? pendingStatus.progress.progress
                                return (.Fetching(isActive: true, progress: progress), .Fetching(isActive: true, progress: progress))
                            } else {
                                if file.isStreamable && parent.id.peerId.namespace != Namespaces.Peer.SecretChat {
                                    return (.Local, resourceStatus)
                                }
                                return (resourceStatus, resourceStatus)
                            }
                    } |> deliverOnMainQueue
                } else {
                    if file.resource is LocalFileVideoMediaResource {
                        updatedStatusSignal = .single((.Local, .Local))
                    } else {
                        let signal: Signal<MediaResourceStatus, NoError>
                        if let parent = parent {
                            signal = chatMessageFileStatus(context: context, message: parent, file: file, approximateSynchronousValue: approximateSynchronousValue)
                        } else {
                            signal = context.account.postbox.mediaBox.resourceStatus(file.resource)
                        }
                        updatedStatusSignal = signal |> deliverOnMainQueue |> map { [weak parent, weak file] status in
                            if let parent = parent, let file = file {
                                if file.isStreamable && parent.id.peerId.namespace != Namespaces.Peer.SecretChat {
                                    return (.Local, status)
                                }
                            }
                            return (status, status)
                        }
                    }
                }
            }
            
            self.image.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: backingScaleFactor, positionFlags: positionFlags), clearInstantly: clearInstantly)

            if let updateImageSignal = updateImageSignal {
                self.image.ignoreFullyLoad = mediaUpdated

                self.image.setSignal(updateImageSignal, animate: removeViewAnimated, cacheImage: { [weak media] result in
                    if let media = media {
                        cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale, positionFlags: positionFlags)
                    }
                }, isProtected: isProtected)
            }
            
            if let signal = updatedStatusSignal, let parent = parent, let parameters = parameters {
                updatedStatusSignal = combineLatest(signal, parameters.getUpdatingMediaProgress(parent.id)) |> map { value, updating in
                    if let progress = updating {
                        return (.Fetching(isActive: true, progress: progress), .Fetching(isActive: true, progress: progress))
                    } else {
                        return value
                    }
                }
            }
            
            self.image.set(arguments: arguments)
            
            self.image._change(size: size, animated: animated)
            
            if let positionFlags = positionFlags {
                autoplayVideoView?.view.positionFlags = positionFlags
            } else  {
                autoplayVideoView?.view.positionFlags = nil
                autoplayVideoView?.view.layer?.cornerRadius = .cornerRadius
            }
            

            
            if isSpoiler {
                let current: MediaInkView
                if let view = self.inkView {
                    current = view
                } else {
                    current = MediaInkView(frame: size.bounds)
                    self.inkView = current
                    
                    let aboveView = self.progressView ?? videoAccessory
                    if let view = aboveView {
                        self.addSubview(current, positioned: .below, relativeTo: view)
                    } else {
                        self.addSubview(current)
                    }
                    if animated {
                        current.layer?.animateAlpha(from: 0.3, to: 1, duration: 0.2)
                    }
                }
                current.removeAllHandlers()
                current.set(handler: { [weak self] current in
                    if let parent = self?.parent {
                        self?.parameters?.revealMedia(parent)
                    }
                }, for: .Click)
                
                current.userInteractionEnabled = parameters?.canReveal ?? true
                
               // self.image.layer?.opacity = 0
                self.autoplayVideoView?.view.layer?.opacity = 0
                
                let image: TelegramMediaImage
                if let current = media as? TelegramMediaImage {
                    image = current
                } else if let file = media as? TelegramMediaFile {
                    image = TelegramMediaImage(imageId: file.fileId, representations: file.previewRepresentations, immediateThumbnailData: file.immediateThumbnailData, reference: nil, partialReference: nil, flags: TelegramMediaImageFlags())
                } else {
                    fatalError()
                }
                
                let imageReference = parent != nil ? ImageMediaReference.message(message: MessageReference(parent!), media: image) : ImageMediaReference.standalone(media: image)

                
                current.update(isRevealed: false, updated: mediaUpdated, context: context, imageReference: imageReference, size: size, positionFlags: positionFlags, synchronousLoad: approximateSynchronousValue, isSensitive: isSensitive, payAmount: parameters?.payAmount)
                current.frame = size.bounds
            } else {
                if let view = self.inkView {
                    view.userInteractionEnabled = false
                    performSubviewRemoval(view, animated: removeViewAnimated)
                    self.inkView = nil
                }
                self.image.layer?.opacity = 1
                self.autoplayVideoView?.view.layer?.opacity = 1
            }

            var first: Bool = true
            
            if let updateStatusSignal = updatedStatusSignal {
                self.statusDisposable.set(updateStatusSignal.start(next: { [weak self] (status, authentic) in
                    
                    if let strongSelf = self {
                        
                        strongSelf.authenticFetchStatus = authentic
                        
                        
                        var authentic = authentic
                        if strongSelf.autoplayVideo {
                            strongSelf.fetchStatus = authentic
                            authentic = .Local
                        } else {
                            switch authentic {
                            case .Fetching:
                                strongSelf.fetchStatus = status
                            default:
                                strongSelf.fetchStatus = status
                            }
                        }
                        
                        
                        if let file = strongSelf.media as? TelegramMediaFile, strongSelf.autoplayVideo {
                            
                           
                            
                            if strongSelf.autoplayVideoView == nil, !isSpoiler {
                                let autoplay: ChatVideoAutoplayView
                                
                                var fileReference = parent != nil ? FileMediaReference.message(message: MessageReference(parent!), media: file) : FileMediaReference.standalone(media: file)
                                

//                                let isHLS: Bool = isHLSVideo(file: fileReference.media)
//                                
//                                if isHLS {
//                                    fileReference = HLSVideoContent.minimizedHLSQuality(file: fileReference)?.file ?? fileReference
//                                }
                                
                                autoplay = ChatVideoAutoplayView(mediaPlayer: MediaPlayer(postbox: context.account.postbox, userLocation: fileReference.userLocation, userContentType: fileReference.userContentType, reference: fileReference.resourceReference(fileReference.media.resource), streamable: file.isStreamable, video: true, preferSoftwareDecoding: false, enableSound: false, volume: 0.0, fetchAutomatically: false), view: MediaPlayerView(backgroundThread: true))
                                
                                strongSelf.autoplayVideoView = autoplay
                                if !strongSelf.blurBackground {
                                    strongSelf.autoplayVideoView?.view.setVideoLayerGravity(.resizeAspectFill)
                                } else {
                                    strongSelf.autoplayVideoView?.view.setVideoLayerGravity(.resize)
                                }
                            }
                            if let autoplay = strongSelf.autoplayVideoView {
                                let dimensions = (file.dimensions?.size ?? size)
                                let value = strongSelf.blurBackground ? dimensions.aspectFitted(size) : size
                                
                                autoplay.view.frame = NSMakeRect(0, 0, value.width, value.height)
                                if let positionFlags = positionFlags {
                                    autoplay.view.positionFlags = positionFlags
                                } else {
                                    autoplay.view.layer?.cornerRadius = .cornerRadius
                                }
                                strongSelf.addSubview(autoplay.view, positioned: .above, relativeTo: strongSelf.image)
                                autoplay.mediaPlayer.attachPlayerView(autoplay.view)
                                autoplay.view.center()
                                autoplay.view.preventsCapture = isProtected
                            }
                            
                        } else {
                            strongSelf.autoplayVideoView = nil
                        }
                        
                        if let autoplay = strongSelf.autoplayVideoView {
                            strongSelf.mediaPlayerStatusDisposable.set((autoplay.mediaPlayer.status |> deliverOnMainQueue).start(next: { [weak strongSelf] status in
                                strongSelf?.updateMediaStatus(status, animated: !first)
                            }))
                        }
                        
                        
                        strongSelf.updatePlayerIfNeeded()
                        
                        if let file = media as? TelegramMediaFile, strongSelf.autoplayVideoView == nil  {
                            strongSelf.updateVideoAccessory(parent == nil ? .Local : authentic, file: file, animated: !first)
                            first = false
                        }
                        var containsSecretMedia:Bool = false
                        
                        if let message = parent {
                            containsSecretMedia = message.containsSecretMedia
                        }
                        
                        if let autoremoveAttribute = parent?.autoremoveAttribute, autoremoveAttribute.timeout <= 60, autoremoveAttribute.countdownBeginTime != nil {
                            strongSelf.progressView?.removeFromSuperview()
                            strongSelf.progressView = nil
                            if strongSelf.timableProgressView == nil {
                                strongSelf.timableProgressView = TimableProgressView(size: NSMakeSize(parent?.groupingKey != nil ? 30 : 40.0, parent?.groupingKey != nil ? 30 : 40.0))
                                strongSelf.addSubview(strongSelf.timableProgressView!)
                            }
                        } else {
                            strongSelf.timableProgressView?.removeFromSuperview()
                            strongSelf.timableProgressView = nil
                            
                            switch status {
                            case .Local:
                                strongSelf.image.animatesAlphaOnFirstTransition = false
                            default:
                                strongSelf.image.animatesAlphaOnFirstTransition = false
                            }
                            
                            var removeProgress: Bool = strongSelf.autoplayVideo && !isSpoiler && strongSelf.lite == false
                            if case .Local = status, media is TelegramMediaImage, !containsSecretMedia {
                                removeProgress = true
                            }
                            if strongSelf.isStory || (isSensitive && isSpoiler) {
                                removeProgress = true
                            }
                            if let media = media as? TelegramMediaFile {
                                if isHLSVideo(file: media) {
                                    removeProgress = true
                                }
                            }
                            
                            if removeProgress {
                                 if let progressView = strongSelf.progressView {
                                    switch progressView.state {
                                    case .Fetching:
                                        progressView.state = .Fetching(progress:1.0, force: false)
                                    case .ImpossibleFetching:
                                        progressView.state = .ImpossibleFetching(progress:1.0, force: false)
                                    default:
                                        break
                                    }
                                    strongSelf.progressView = nil
                                     performSubviewRemoval(progressView, animated: removeViewAnimated)
                                }
                            } else {
                                strongSelf.progressView?.layer?.removeAllAnimations()
                                if strongSelf.progressView == nil {
                                    let progressView = RadialProgressView(theme:RadialProgressTheme(backgroundColor: .blackTransparent, foregroundColor: .white, icon: playerPlayThumb))
                                    progressView.frame = CGRect(origin: CGPoint(), size: CGSize(width: parent?.groupingKey != nil ? 30 : 40.0, height: parent?.groupingKey != nil ? 30 : 40.0))
                                    strongSelf.progressView = progressView
                                    strongSelf.addSubview(progressView, positioned: .above, relativeTo: strongSelf.inkView)
                                    strongSelf.progressView?.center()
                                    progressView.fetchControls = strongSelf.fetchControls
                                }
                            }
                        }
                        
                        
                        let progressStatus: MediaResourceStatus
                        if strongSelf.parent?.groupingKey != nil {
                            switch authentic {
                            case .Fetching:
                                progressStatus = authentic
                            default:
                                progressStatus = status
                            }
                        } else {
                            progressStatus = status
                        }
        
                        
                        switch progressStatus {
                        case let .Fetching(_, progress), let .Paused(progress):
                            
                            let sentGrouped = parent?.groupingKey != nil && (parent!.flags.contains(.Sending) || parent!.flags.contains(.Unsent))
                            
                            strongSelf.progressView?.state = parent == nil ? .ImpossibleFetching(progress: progress, force: false) : (progress == 1.0 && sentGrouped ? .Success : .Fetching(progress: progress, force: false))
                        case .Local:
                            var state: RadialProgressState = .None
                            if containsSecretMedia {
                                state = .Icon(image: parent?.groupingKey != nil ? theme.icons.chatSecretThumbSmall : theme.icons.chatSecretThumb)
                                
                                if let attribute = parent?.autoremoveAttribute, let countdownBeginTime = attribute.countdownBeginTime {
                                    let difference:TimeInterval = TimeInterval((countdownBeginTime + attribute.timeout)) - (CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                                    let start = difference / Double(attribute.timeout) * 100.0
                                    strongSelf.timableProgressView?.theme = TimableProgressTheme(outer: 3, seconds: difference, start: start, border: false)
                                    strongSelf.timableProgressView?.progress = 0
                                    strongSelf.timableProgressView?.startAnimation()
                                    
                                }
                            } else {
                                if let file = media as? TelegramMediaFile {
                                    if file.isVideo {
                                        state = .Play
                                    }
                                }
                            }
                            
                            strongSelf.progressView?.state = state
                        case .Remote:
                            strongSelf.progressView?.state = .Remote
                        }
                        
                        
                        strongSelf.updateVideoTimestamp(videoTimestamp, duration: (media as? TelegramMediaFile)?.duration, animated: animated)
                        
                        strongSelf.needsLayout = true
                    }
                }))
               
            }
        } else {
            self.updateVideoTimestamp(videoTimestamp, duration: (media as? TelegramMediaFile)?.duration, animated: animated)
            self.needsLayout = true
        }
    }
    
    private func updateVideoTimestamp(_ videoTimestamp: Int32?, duration: Double?, animated: Bool) {
        if let videoTimestamp, let duration, duration > 0 {
            let current: VideoTimestampView
            if let view = self.videoTimeProgress {
                current = view
            } else {
                current = VideoTimestampView(frame: bounds)
                self.videoTimeProgress = current
                addSubview(current)
            }
            current.progress.set(progress: Double(videoTimestamp) / duration, animated: animated)
            current.progress.fetchingColor = theme.colors.redUI
            current.progress.containerBackground = NSColor.grayBackground.withAlphaComponent(0.2)
            current.progress.style = ControlStyle(foregroundColor: theme.colors.accent, backgroundColor: .clear, highlightColor: .clear)
            
            (current.layer as? CornerMaskLayerSimple)?.positionFlags = positionFlags
            
        } else if let view = self.videoTimeProgress {
            performSubviewRemoval(view, animated: animated)
            self.videoTimeProgress = nil
        }
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        transition.updateFrame(view: image, frame: bounds)
        
    }
    
    
    override func clean() {
        statusDisposable.dispose()
    }
    
    override func cancel() {
        fetchDisposable.set(nil)
        statusDisposable.set(nil)
    }
    
    func effectiveImageResource(_ image: TelegramMediaImage) -> Void {
        
    }
    
   
    override func fetch(userInitiated: Bool) {
        if let context = context {
            if let media = media as? TelegramMediaFile, !media.isLocalResource {
                if let parent = parent {
                    fetchDisposable.set(messageMediaFileInteractiveFetched(context: context, messageId: parent.id, messageReference: .init(parent), file: media, userInitiated: userInitiated).start())
                } else {
                    fetchDisposable.set(freeMediaFileInteractiveFetched(context: context, fileReference: FileMediaReference.standalone(media: media)).start())
                }
            }  else if let media = media as? TelegramMediaImage, !media.isLocalResource {
                fetchDisposable.set(chatMessagePhotoInteractiveFetched(account: context.account, imageReference: parent != nil ? ImageMediaReference.message(message: MessageReference(parent!), media: media) : ImageMediaReference.standalone(media: media)).start())
            }
        }
    }
    
    
    
    override func preloadStreamblePart() {
        if let context = context {
            if let media = media as? TelegramMediaFile, let parent = parent {
                if isHLSVideo(file: media) {
                    let fetchSignal = HLSVideoContent.minimizedHLSQualityPreloadData(postbox: context.account.postbox, file: .message(message: MessageReference(parent), media: media), userLocation: .peer(parent.id.peerId), prefixSeconds: 10, autofetchPlaylist: true, initialQuality: FastSettings.videoQuality)
                    |> mapToSignal { fileAndRange -> Signal<Never, NoError> in
                        guard let fileAndRange else {
                            return .complete()
                        }
                        return freeMediaFileResourceInteractiveFetched(postbox: context.account.postbox, userLocation: .peer(parent.id.peerId), fileReference: fileAndRange.0, resource: fileAndRange.0.media.resource, range: (fileAndRange.1, .default))
                        |> ignoreValues
                        |> `catch` { _ -> Signal<Never, NoError> in
                            return .complete()
                        }
                    }
                    partDisposable.set(fetchSignal.start())
                } else {
                    let reference = FileMediaReference.message(message: MessageReference(parent), media: media)
                                    
                    let preload = preloadVideoResource(postbox: context.account.postbox, userLocation: .peer(parent.id.peerId), userContentType: .init(file: media), resourceReference: reference.resourceReference(media.resource), duration: 3.0)
                    partDisposable.set(preload.start())
                }
            }
        }
    }
    
    
    override func copy() -> Any {
        return image.copy()
    }
    override var contents: Any? {
        return image.layer?.contents
    }
    
}
