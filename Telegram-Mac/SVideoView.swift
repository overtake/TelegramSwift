//
//  SVideoView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12/11/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import ColorPalette
import RangeSet
import TelegramMedia
import TelegramMediaPlayer
import TelegramCore
import Postbox

final class SVideoAdsArguments {
    let context: AccountContext
    let removeAd: (Message, Bool, Bool)->Void
    let maybeNext:(Message)->Void
    let markAsSeen:(Message)->Void
    let invoke:(Message)->Void
    init(context: AccountContext, removeAd: @escaping(Message, Bool, Bool)->Void, maybeNext:@escaping(Message)->Void, markAsSeen:@escaping(Message)->Void, invoke:@escaping(Message)->Void) {
        self.context = context
        self.removeAd = removeAd
        self.maybeNext = maybeNext
        self.markAsSeen = markAsSeen
        self.invoke = invoke
    }
}

private func selectBestQualityIcon(for quality: UniversalVideoContentVideoQuality) -> NSImage {
    
    
    enum VideoIcon: Int {
        case auto = 0
        case hd = 1
        case sd = 2
    }

    let icons: [NSImage] = [
        NSImage(resource: .iconVideoSettingsAuto),
        NSImage(resource: .iconVideoSettingsHD),
        NSImage(resource: .iconVideoSettingsSD)
    ]
    
    switch quality {
    case .auto:
        return icons[VideoIcon.auto.rawValue]
    case let .quality(size):
        let quality = roundToStandardQuality(size: size)
        if quality >= 720 {
            return icons[VideoIcon.hd.rawValue]
        } else {
            return icons[VideoIcon.sd.rawValue]
        }
    }
    
}

func roundToStandardQuality(size: Int) -> Int {
    // List of standard video qualities
    let standardQualities = [360, 480, 720, 1080, 1440, 2160]
    
    // Find the closest value using `min` and a closure to calculate the absolute difference
    guard let closestQuality = standardQualities.min(by: { abs($0 - size) < abs($1 - size) }) else {
        return size // Return the original size if no standard qualities are found
    }
    
    return closestQuality
}




private final class SVideoPipControls : Control {
    
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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    fileprivate func update(with status: MediaPlayerStatus, animated: Bool) {
        
        
        self.forceMouseDownCanMoveWindow = true
        volumeSlider.userInteractionEnabled = true
        progress.userInteractionEnabled = true

        
        self.backgroundColor = NSColor.blackTransparent
        
        volumeSlider.set(progress: CGFloat(status.volume))
        volumeToggle.set(image: status.volume.isZero ? theme.icons.gallery_pip_muted : theme.icons.gallery_pip_unmuted, for: .Normal)
        
       
        playOrPause.isEnabled = status.duration > 0
        progress.isEnabled = status.duration > 0
        
        
        switch status.status {
        case .playing:
            playOrPause.set(image: theme.icons.gallery_pip_pause, for: .Normal)
            progress.set(progress: status.duration == 0 ? 0 : CGFloat(status.timestamp / status.duration), animated: animated, duration: status.duration, beginTime: status.generationTimestamp, offset: status.timestamp, speed: Float(status.baseRate))
        case .paused:
            playOrPause.set(image: status.generationTimestamp == 0 ? theme.icons.gallery_pip_pause : theme.icons.videoPlayerPlay, for: .Normal)
            progress.set(progress: status.duration == 0 ? 0 : CGFloat(status.timestamp / status.duration), animated: false)
        case let .buffering(_, whilePlaying):
            playOrPause.set(image: whilePlaying ? theme.icons.gallery_pip_pause : theme.icons.gallery_pip_play, for: .Normal)
            progress.set(progress: status.duration == 0 ? 0 : CGFloat(status.timestamp / status.duration), animated: false)
        }
        let currentTimeAttr: NSAttributedString = .initialize(string: status.timestamp == 0 && status.duration == 0 ? "--:--" : String.durationTransformed(elapsed: Int(status.timestamp)), color: .white, font: .medium(11))
        let durationTimeAttr: NSAttributedString = .initialize(string: status.duration == 0 ? "--:--" : String.durationTransformed(elapsed: Int(status.duration)), color: .white, font: .medium(11))
        
        let currentTimeLayout = TextViewLayout(currentTimeAttr, alignment: .right)
        let durationLayout = TextViewLayout(durationTimeAttr, alignment: .center)
        currentTimeLayout.measure(width: .greatestFiniteMagnitude)
        durationLayout.measure(width: .greatestFiniteMagnitude)
        
        currentTimeView.setFrameSize(currentTimeLayout.layoutSize.width, currentTimeView.frame.height)
        durationView.setFrameSize(durationLayout.layoutSize.width > 33 ? 40 : 33, durationView.frame.height)

        
        currentTimeView.set(layout: currentTimeLayout)
        durationView.set(layout: durationLayout)
        
        currentTimeView.needsDisplay = true
        durationView.needsDisplay = true
        
        needsLayout = true
        
    }
    
    var status: MediaPlayerStatus? {
        didSet {
            if let status = status {
                let animated = oldValue?.seekId == status.seekId && (oldValue?.timestamp ?? 0) <= status.timestamp && !status.generationTimestamp.isZero && status != oldValue
                update(with: status, animated: animated)
            } else {
                playOrPause.isEnabled = false
            }
        }
    }
    
    let playOrPause: ImageButton = ImageButton()
    let close: ImageButton = ImageButton()

    let progress: LinearProgressControl = LinearProgressControl(progressHeight: 2)
    let fullscreen: ImageButton = ImageButton()
    
    
    let volumeContainer: View = View()
    let volumeToggle: ImageButton = ImageButton()
    let volumeSlider: LinearProgressControl = LinearProgressControl(progressHeight: 2)
    
    private let durationView: TextView = TextView()
    private let currentTimeView: TextView = TextView()
        
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(playOrPause)
        addSubview(close)
        addSubview(progress)
        addSubview(durationView)
        addSubview(currentTimeView)
        addSubview(fullscreen)
        
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
        volumeToggle.set(image: theme.icons.gallery_pip_unmuted, for: .Normal)
        _ = volumeToggle.sizeToFit()
        volumeSlider.setFrameSize(NSMakeSize(60, 5))
        volumeContainer.setFrameSize(NSMakeSize(volumeToggle.frame.width + 60 + 5, volumeToggle.frame.height))
        
        volumeSlider.roundCorners = true
        volumeSlider.alignment = .center
        volumeSlider.containerBackground = NSColor.grayBackground.withAlphaComponent(0.2)
        volumeSlider.style = ControlStyle(foregroundColor: .white, backgroundColor: .clear, highlightColor: .clear)
        volumeSlider.set(progress: 0.8)
                
        addSubview(volumeContainer)
        
        
        playOrPause.autohighlight = false
        fullscreen.autohighlight = false

        playOrPause.scaleOnClick = true
        fullscreen.scaleOnClick = true
        
        fullscreen.set(image: theme.icons.gallery_pip_out, for: .Normal)
        playOrPause.set(image: theme.icons.gallery_pip_pause, for: .Normal)
        
        close.set(image: theme.icons.gallery_pip_close, for: .Normal)
        close.sizeToFit()
        close.autohighlight = false
        close.scaleOnClick = true

        
        _ = playOrPause.sizeToFit()
        _ = fullscreen.sizeToFit()
        
        progress.insets = NSEdgeInsetsMake(0, 0, 0, 0)
        progress.roundCorners = true
        progress.alignment = .center
        progress.liveScrobbling = false
        progress.fetchingColor = NSColor.grayBackground.withAlphaComponent(0.6)
        progress.containerBackground = NSColor.grayBackground.withAlphaComponent(0.2)
        progress.style = ControlStyle(foregroundColor: .white, backgroundColor: .clear, highlightColor: .clear)
        progress.set(progress: 0, animated: false, duration: 0)
        wantsLayer = true
    }
    
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    override func layout() {
        super.layout()
        
        playOrPause.center()
        
        close.setFrameOrigin(5, 5)
        fullscreen.setFrameOrigin(close.frame.maxX + 5, 5)

        
        volumeContainer.setFrameOrigin(frame.width - volumeContainer.frame.width - 5, 5)
        volumeToggle.centerY(x: 0)
        volumeSlider.centerY(x: volumeToggle.frame.maxX + 5)
        
        progress.setFrameSize(NSMakeSize(frame.width - 10, 5))

        progress.setFrameOrigin(5, frame.height - 5 - progress.frame.height)

        currentTimeView.setFrameOrigin(5, progress.frame.minY - 5 - currentTimeView.frame.height)
        durationView.setFrameOrigin(frame.width - durationView.frame.width - 5, progress.frame.minY - 5 - durationView.frame.height)

    }
}

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
    let scrobbling:(Double?)->Void
    let volume:(Float) -> Void
    let toggleFullScreen:() -> Void
    let togglePictureInPicture: ()->Void
    let closePictureInPicture: ()->Void
    let setBaseRate:(Double)->Void
    let pause:()->Void
    let play:()->Void
    init(playOrPause: @escaping()->Void, rewind: @escaping(Double)->Void, scrobbling: @escaping(Double?)->Void, volume: @escaping(Float) -> Void, toggleFullScreen: @escaping()->Void, togglePictureInPicture: @escaping() -> Void, closePictureInPicture:@escaping()->Void, setBaseRate:@escaping(Double)->Void, pause: @escaping()->Void, play: @escaping()->Void) {
        self.playOrPause = playOrPause
        self.rewind = rewind
        self.scrobbling = scrobbling
        self.volume = volume
        self.toggleFullScreen = toggleFullScreen
        self.togglePictureInPicture = togglePictureInPicture
        self.closePictureInPicture = closePictureInPicture
        self.setBaseRate = setBaseRate
        self.play = play
        self.pause = pause
    }
}

private class AdMessageView : Control {
    
    
    class AdView: Control {
        private let textView = TextView()
        private let imageView = ImageView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(textView)
            addSubview(imageView)
            imageView.image = NSImage(resource: .iconSearchAd).precomposed(NSColor.white)
            imageView.sizeToFit()
            
            let layout = TextViewLayout(.initialize(string: strings().searchAd, color: NSColor.white, font: .normal(.small)))
            layout.measure(width: .greatestFiniteMagnitude)
            self.textView.update(layout)
            
            self.textView.userInteractionEnabled = false
            self.textView.isSelectable = false
            
            set(background: NSColor.white.withAlphaComponent(0.2), for: .Normal)
            
            setFrameSize(NSMakeSize(textView.frame.width + 8 + imageView.frame.width, 16))
            
            self.layer?.cornerRadius = frame.height / 2
            
            scaleOnClick = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layout() {
            super.layout()
            textView.centerY(x: 5)
            imageView.centerY(x: textView.frame.maxX)
        }
        
    }
    
    private let avatarControl: AvatarControl = AvatarControl(font: .avatar(13))
    private let titleView = TextView()
    private let infoView = InteractiveTextView()
    private var progressContainer = Control(frame: NSMakeRect(0, 0, 40, 40))
    private let progress = FireTimerControl(frame: NSMakeRect(0, 0, 36, 36))
    private let close = ImageView()
    
    private let backgroundView = NSVisualEffectView()
    
    private var counterView: DynamicCounterTextView?
    
    private let adView = AdView(frame: .zero)
    
    private var timer: SwiftSignalKit.Timer?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        backgroundView.material = .dark
        backgroundView.blendingMode = .withinWindow
        backgroundView.wantsLayer = true

        addSubview(backgroundView)
        addSubview(titleView)
        addSubview(infoView)
        addSubview(avatarControl)
        progressContainer.addSubview(progress)
        progressContainer.addSubview(close)
        addSubview(progressContainer)
        
        addSubview(adView)
        
        
        
        
        progress.userInteractionEnabled = false
        close.isEventLess = true
        
        self.progressContainer.scaleOnClick = true
        self.scaleOnClick = true
                
        avatarControl.setFrameSize(NSMakeSize(36, 36))
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        infoView.userInteractionEnabled = false
        
        self.backgroundColor = NSColor.grayForeground.withAlphaComponent(0.35)
        self.layer?.cornerRadius = 10
        
        self.layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(message: Message, arguments: SVideoAdsArguments, width: CGFloat, animated: Bool) {
        
        setSingle(handler: { [weak arguments] _ in
            arguments?.invoke(message)
        }, for: .Click)
        
        let context: AccountContext = arguments.context
        
        let titleLayout = TextViewLayout(.initialize(string: message.author?.displayTitle, color: .white, font: .medium(.text)), maximumNumberOfLines: 1)
        titleLayout.measure(width: width - avatarControl.frame.maxX - 60)
        self.titleView.update(titleLayout)
        
        
        let attr = ChatMessageItem.applyMessageEntities(with: message.attributes, for: message.text, message: message, context: context, fontSize: 13, openInfo: { _, _, _, _ in }, textColor: .white, linkColor: darkPalette.accent, monospacedPre: .white, monospacedCode: .white, isDark: false, bubbled: false).mutableCopy() as! NSMutableAttributedString
        
        InlineStickerItem.apply(to: attr, associatedMedia: message.associatedMedia, entities: message.entities, isPremium: context.isPremium)
        

        let textViewLayout = TextViewLayout(attr)
        textViewLayout.measure(width: width - avatarControl.frame.maxX - 60)
        self.infoView.set(text: textViewLayout, context: arguments.context)

        close.image = NSImage(resource: .iconStoryClose).precomposed(NSColor.white)
        close.sizeToFit()
        
        self.avatarControl.setPeer(account: context.account, peer: message.author)
        
        let counterView = DynamicCounterTextView(frame: .zero)
        progressContainer.addSubview(counterView)
        self.counterView = counterView
        

        self.close.layer?.opacity = 0
              
        let duration: Double = Double(message.adAttribute?.minDisplayDuration ?? 15)
        let deadline = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
        
        progress.updateValue = { [weak counterView] current in
            let value = Int(floor(duration * Double(current)))
            let dynamicResult = DynamicCounterTextView.make(for: "\(value)", count: "\(value)", font: .normal(.text), textColor: .white, width: .greatestFiniteMagnitude)
            if let counterView {
                counterView.update(dynamicResult, animated: true)
                counterView.change(size: dynamicResult.size, animated: animated)
                counterView.change(pos: counterView.centerFrame().origin, animated: animated)
            }
        }

        progress.update(color: NSColor.white, timeout: duration, deadlineTimestamp: deadline + duration)
        
        progress.reachedTimeout = { [weak self] in
            self?.progress.change(opacity: 0, animated: true)
            if let counterView = self?.counterView {
                performSubviewRemoval(counterView, animated: animated)
                self?.counterView = nil
            }
            self?.close.change(opacity: 1, animated: true)
        }
        
        if let adAttribute = message.adAttribute {
            
            adView.contextMenu = { [weak self, weak arguments] in
                
                guard let window = self?.window as? Window, let arguments else {
                    return ContextMenu()
                }
                
                let menu = ContextMenu(presentation: .current(darkPalette))
                
                menu.onShow = { [weak self] _ in
                    self?.progress.isPaused = true
                }
                menu.onClose = {
                    self?.progress.isPaused = false
                }

                if let text = message.adAttribute?.sponsorInfo {
                    let submenu = ContextMenu(presentation: .current(darkPalette))
                    
                    let item = ContextMenuItem(strings().searchAdSponsorInfo, itemImage: MenuAnimation.menu_show_info.value)
                    
                    item.submenu = submenu
                    
                    submenu.addItem(ContextMenuItem(text, handler: {
                        copyToClipboard(text)
                        showModalText(for: window, text: strings().contextAlertCopied)
                    }, removeTail: false))
                    
                    if let text = message.adAttribute?.additionalInfo {
                        if !submenu.items.isEmpty {
                            submenu.addItem(ContextSeparatorItem())
                        }
                        submenu.addItem(ContextMenuItem(text, handler: {
                            copyToClipboard(text)
                            showModalText(for: window, text: strings().contextAlertCopied)
                        }, removeTail: false))
                    }
                    
                }
                
                menu.addItem(ContextMenuItem(strings().chatMessageSponsoredAbout, handler: {
                    showModal(with: SearchAdAboutController(context: context), for: window)
                }, itemImage: MenuAnimation.menu_show_info.value))

                
                menu.addItem(ContextMenuItem(strings().chatMessageSponsoredReport, handler: {
                    
                    _ = showModalProgress(signal: context.engine.messages.reportAdMessage(opaqueId: adAttribute.opaqueId, option: nil), for: window).startStandalone(next: { result in
                        switch result {
                        case .reported:
                            showModalText(for: window, text: strings().chatMessageSponsoredReportAready)
                        case .adsHidden:
                            break
                        case let .options(title, options):
                            showComplicatedReport(context: context, title: title, info: strings().chatMessageSponsoredReportLearnMore, header: strings().chatMessageSponsoredReport, data: .init(subject: .list(options.map { .init(string: $0.text, id: $0.option) }), title: strings().chatMessageSponsoredReportOptionTitle), report: { report in
                                return context.engine.messages.reportAdMessage(opaqueId: adAttribute.opaqueId, option: report.id) |> `catch` { error in
                                    return .single(.reported)
                                } |> deliverOnMainQueue |> map { result in
                                    switch result {
                                    case let .options(_, options):
                                        return .init(subject: .list(options.map { .init(string: $0.text, id: $0.option) }), title: report.string)
                                    case .reported:
                                        showModalText(for: window, text: strings().chatMessageSponsoredReportSuccess)
                                        arguments.removeAd(message, false, false)
                                        return nil
                                    case .adsHidden:
                                        return nil
                                    }
                                }
                                
                            }, window: window)
                        }
                    }, error: { error in
                        switch error {
                        case .premiumRequired:
                            prem(with: PremiumBoardingController(context: context, source: .no_ads, openFeatures: true), for: window)
                        case .generic:
                            break
                        }
                    })
                }, itemImage: MenuAnimation.menu_restrict.value))
                
                
                if !context.premiumIsBlocked {
                    menu.addItem(ContextSeparatorItem())

                    menu.addItem(ContextMenuItem(strings().searchAdRemoveAd, handler: {
                        arguments.removeAd(message, false, false)
                    }, itemImage: MenuAnimation.menu_clear_history.value))
                }

                return menu
            }
        }
        
        self.progressContainer.setSingle(handler: { [weak arguments, weak self] _ in
            arguments?.removeAd(message, true, self?.counterView != nil)
        }, for: .Click)
        
        let maxDuration = Double(message.adAttribute?.maxDisplayDuration ?? 30)

        self.timer = SwiftSignalKit.Timer(timeout: maxDuration, repeat: false, completion: { [weak arguments] in
            arguments?.maybeNext(message)
        }, queue: .mainQueue())
        
        self.timer?.start()
        
        self.setFrameSize(NSMakeSize(width, height))
    }
    
    func resize(width: CGFloat) {
        infoView.resize(width - avatarControl.frame.maxX - 60)
        titleView.resize(width - avatarControl.frame.maxX - 60)
    }
    
    var height: CGFloat {
        return 8 + titleView.frame.height + 2 + infoView.frame.height + 8
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        

        transition.updateFrame(view: backgroundView, frame: size.bounds)
        
        transition.updateFrame(view: avatarControl, frame: CGRect(origin: NSMakePoint(10, 7), size: avatarControl.frame.size))
        transition.updateFrame(view: titleView, frame: CGRect(origin: NSMakePoint(avatarControl.frame.maxX + 10, 8), size: titleView.frame.size))
        transition.updateFrame(view: infoView, frame: CGRect(origin: NSMakePoint(avatarControl.frame.maxX + 10, size.height - infoView.frame.height - 8), size: infoView.frame.size))
        
        transition.updateFrame(view: progressContainer, frame: progressContainer.centerFrameY(x: size.width - progressContainer.frame.width - 6))

        transition.updateFrame(view: progress, frame: progress.centerFrame())
        transition.updateFrame(view: close, frame: close.centerFrame())
        
        if let counterView {
            transition.updateFrame(view: counterView, frame: counterView.centerFrame())
        }

        
        transition.updateFrame(view: adView, frame: NSMakeRect(titleView.frame.maxX + 2, titleView.frame.minY, adView.frame.width, adView.frame.height))
    }
}

private final class SVideoControlsView : Control {
    
    fileprivate weak var mediaPlayer: (UniversalVideoContentView & NSView)?
    
    var isControlsLimited: Bool = false {
        didSet {
            let controlStyle = self.controlStyle
            self.controlStyle = controlStyle
        }
    }
    
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
            rewindBackward.isHidden = controlStyle.hideRewind || isControlsLimited
            rewindForward.isHidden = controlStyle.hideRewind || isControlsLimited
            volumeContainer.isHidden = controlStyle.isCompact
            togglePip.set(image: controlStyle.isPip ? theme.icons.videoPlayerPIPOut : theme.icons.videoPlayerPIPIn, for: .Normal)
            toggleFullscreen.set(image: controlStyle.isPip ? theme.icons.videoPlayerClose : controlStyle.isFullScreen ? theme.icons.videoPlayerExitFullScreen : theme.icons.videoPlayerEnterFullScreen, for: .Normal)
            menuItems.isHidden = controlStyle.isPip || isControlsLimited || controlStyle.isCompact
//            togglePip.isHidden = isControlsLimited || controlStyle.isCompact
            toggleFullscreen.isHidden = isControlsLimited || controlStyle.isCompact
            playOrPause.isHidden = isControlsLimited
            volumeContainer.isHidden = isControlsLimited || controlStyle.isCompact
            layout()
        }
    }
    private var downInside: Bool = false
    
    override func mouseUp(with event: NSEvent) {
        if progress.hasTemporaryState {
            progress.mouseUp(with: event)
        } else if volumeSlider.hasTemporaryState {
            volumeSlider.mouseUp(with: event)
        } else {
            let point = self.convert(event.locationInWindow, from: nil)
            let rect = NSMakeRect(self.progress.frame.minX, self.progress.frame.minY - 5, self.progress.frame.width, self.progress.frame.height + 10)
            if NSPointInRect(point, rect) {
                progress.mouseUp(with: event)
            } else {
                super.mouseUp(with: event)
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        let point = self.convert(event.locationInWindow, from: nil)

        let rect = NSMakeRect(self.progress.frame.minX, self.progress.frame.minY - 5, self.progress.frame.width, self.progress.frame.height + 10)
        
        self.downInside = NSPointInRect(point, rect)

    }
    
    private func updateLivePreview() {
        guard let window = window else {
            return
        }
        
        let live = (NSEvent.pressedMouseButtons & (1 << 0)) != 0 && self.progress.hasTemporaryState
        
        
        let point = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        
        let rect = NSMakeRect(self.progress.frame.minX, self.progress.frame.minY - 5, self.progress.frame.width, self.progress.frame.height + 10)
        
        if !self.volumeSlider.hasTemporaryState {
            if NSPointInRect(point, rect) || self.progress.hasTemporaryState {
                let point = self.progress.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                let result = max(min(point.x, self.progress.frame.width), 0) / self.progress.frame.width
                self.livePreview?(Float(result), live)
            } else {
                self.livePreview?(nil, live)
            }
        } else {
            var bp = 0
            bp += 1
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateLivePreview()
        
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateLivePreview()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateLivePreview()
    }
    
    
    override var mouseDownCanMoveWindow: Bool {
        return false
    }

    
    fileprivate func update(with status: MediaPlayerStatus, animated: Bool) {
        volumeSlider.set(progress: CGFloat(status.volume))
        volumeToggle.set(image: status.volume.isZero ? theme.icons.videoPlayerVolumeOff : theme.icons.videoPlayerVolume, for: .Normal)
        
        rewindForward.isHidden = rewindForward.isHidden || frame.width < 450
        rewindBackward.isHidden = rewindBackward.isHidden || frame.width < 450

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
        
        let currentTimeLayout = TextViewLayout(currentTimeAttr, alignment: .right)
        let durationLayout = TextViewLayout(durationTimeAttr, alignment: .center)
        currentTimeLayout.measure(width: .greatestFiniteMagnitude)
        durationLayout.measure(width: .greatestFiniteMagnitude)
        
        currentTimeView.setFrameSize(currentTimeLayout.layoutSize.width, currentTimeView.frame.height)
        durationView.setFrameSize(durationLayout.layoutSize.width > 33 ? 40 : 33, durationView.frame.height)

        
        currentTimeView.set(layout: currentTimeLayout)
        durationView.set(layout: durationLayout)
        
        currentTimeView.needsDisplay = true
        durationView.needsDisplay = true
        
        updateBaseRate()
        

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
    let menuItems: ImageButton = ImageButton()
    let togglePip: ImageButton = ImageButton()
    
    var livePreview: ((Float?, Bool)->Void)?
    
    let volumeContainer: View = View()
    let volumeToggle: ImageButton = ImageButton()
    let volumeSlider: LinearProgressControl = LinearProgressControl(progressHeight: 5)
    
    private let durationView: TextView = TextView()
    private let currentTimeView: TextView = TextView()
    
    private var controlMovePosition: NSPoint? = nil
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(backgroundView)
        addSubview(playOrPause)
        addSubview(progress)
        addSubview(rewindForward)
        addSubview(rewindBackward)
        addSubview(toggleFullscreen)
        addSubview(togglePip)
        addSubview(menuItems)
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
        
        volumeSlider.scrubberImage = generateImage(NSMakeSize(8, 8), contextGenerator: { size, ctx in
            let rect = CGRect(origin: .zero, size: size)
            ctx.clear(rect)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: rect)
        })
        volumeSlider.roundCorners = true
        volumeSlider.alignment = .center
        volumeSlider.containerBackground = NSColor.grayBackground.withAlphaComponent(0.2)
        volumeSlider.style = ControlStyle(foregroundColor: .white, backgroundColor: .clear, highlightColor: .clear)
        volumeSlider.set(progress: 0.8)
        
        volumeSlider.insets = NSEdgeInsetsMake(0, 4.5, 0, 4.5)
        
        addSubview(volumeContainer)
        
        backgroundView.material = .dark
        backgroundView.blendingMode = .withinWindow
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 15
        
        playOrPause.autohighlight = false
        rewindForward.autohighlight = false
        rewindBackward.autohighlight = false
        toggleFullscreen.autohighlight = false
        togglePip.autohighlight = false
        menuItems.autohighlight = false

        playOrPause.scaleOnClick = true
        rewindForward.scaleOnClick = true
        rewindBackward.scaleOnClick = true
        toggleFullscreen.scaleOnClick = true
        togglePip.scaleOnClick = true
        menuItems.scaleOnClick = true
        
      
        
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
        progress.scrubberImage = generateImage(NSMakeSize(8, 8), contextGenerator: { size, ctx in
            let rect = CGRect(origin: .zero, size: size)
            ctx.clear(rect)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: rect)
        })
        progress.roundCorners = true
        progress.alignment = .center
        progress.liveScrobbling = false
        progress.fetchingColor = NSColor.grayBackground.withAlphaComponent(0.6)
        progress.containerBackground = NSColor.grayBackground.withAlphaComponent(0.2)
        progress.style = ControlStyle(foregroundColor: .white, backgroundColor: .clear, highlightColor: .clear)
        progress.set(progress: 0, animated: false, duration: 0)
        wantsLayer = true
        layer?.cornerRadius = 15
        
        
        self.progress.onLiveScrobbling = { [weak self] _ in
            if let `self` = self {
                self.updateLivePreview()
            }
        }
                
        set(handler: { [weak self] control in
            guard let window = control.window, let superview = control.superview else {
                return
            }
            self?.controlMovePosition = superview.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        }, for: .Down)
        
       
        
        set(handler: { [weak self] control in
            guard let window = control.window, let superview = control.superview, let start = self?.controlMovePosition else {
                return
            }
            var mouse = superview.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            
            var dif = NSMakePoint(mouse.x - start.x, mouse.y - start.y)
            var point = NSMakePoint(control.frame.minX + dif.x, control.frame.minY + dif.y)
            
            if point.x < 2 || point.x > superview.frame.width - control.frame.width - 4  {
                mouse.x = start.x
            }
            if point.y < 2 || point.y > superview.frame.height - control.frame.height - 4  {
                mouse.y = start.y
            }
            self?.controlMovePosition = mouse

            dif = NSMakePoint(mouse.x - start.x, mouse.y - start.y)
            point = NSMakePoint(control.frame.minX + dif.x, control.frame.minY + dif.y)
            control.setFrameOrigin(point)
            

        }, for: .MouseDragging)
        
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let window = newWindow as? Window {
            window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
                self?.controlMovePosition = nil
                return .rejected
            }, with: self, for: .leftMouseUp)
        } else {
            (window as? Window)?.remove(object: self, for: .leftMouseUp)
        }
    }
    
    func updateBaseRate() {
        let image: CGImage
        
        
        if let mediaPlayer, let quality = mediaPlayer.videoQualityState(), !quality.available.isEmpty {
            image = selectBestQualityIcon(for: quality.preferred).precomposed(.white)
        } else {
            image = optionsRateImage(rate: String(format: "%.1fx", FastSettings.playingVideoRate), color: .white, isLarge: true)
        }
        menuItems.set(image: image, for: .Normal)
        self.menuItems.sizeToFit()
        
        needsLayout = true
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        var offset: CGFloat = 0
//        if let adMessageView {
//            offset = adMessageView.frame.height + 20
//        }
        let yOffset: CGFloat = 16 + offset
        
        
        let bgRect: NSRect
//        if let adMessageView {
//            bgRect = NSMakeRect(0, adMessageView.frame.height + 20, size.width, size.height - (adMessageView.frame.height + 20))
//        } else {
            bgRect = size.bounds
//        }
        
        transition.updateFrame(view: backgroundView, frame: bgRect)

        

        transition.updateFrame(view: playOrPause, frame: playOrPause.centerFrameX(y: yOffset))

        transition.updateFrame(
            view: rewindBackward,
            frame: NSRect(
                origin: NSPoint(x: playOrPause.frame.minX - rewindBackward.frame.width - 36, y: yOffset),
                size: rewindBackward.frame.size
            )
        )

        transition.updateFrame(
            view: rewindForward,
            frame: NSRect(
                origin: NSPoint(x: playOrPause.frame.maxX + 36, y: yOffset),
                size: rewindForward.frame.size
            )
        )

        transition.updateFrame(
            view: menuItems,
            frame: NSRect(
                origin: NSPoint(x: size.width - menuItems.frame.width - 16, y: yOffset),
                size: menuItems.frame.size
            )
        )

        let fullscreenX: CGFloat
        if menuItems.isHidden {
            fullscreenX = size.width - toggleFullscreen.frame.width - 16
        } else {
            fullscreenX = menuItems.frame.minX - toggleFullscreen.frame.width - 10
        }
        transition.updateFrame(
            view: toggleFullscreen,
            frame: NSRect(origin: NSPoint(x: fullscreenX, y: yOffset), size: toggleFullscreen.frame.size)
        )

        let pipX: CGFloat
        switch controlStyle {
        case .compact:
            pipX = 16
        case .regular:
            pipX = fullscreenX - togglePip.frame.width - 10
        }

        transition.updateFrame(
            view: togglePip,
            frame: NSRect(origin: NSPoint(x: pipX, y: yOffset), size: togglePip.frame.size)
        )

        transition.updateFrame(
            view: volumeContainer,
            frame: NSRect(origin: NSPoint(x: 16, y: yOffset), size: volumeContainer.frame.size)
        )

        transition.updateFrame(view: volumeToggle, frame: volumeToggle.centerFrameY(x: 0))
        transition.updateFrame(view: volumeSlider, frame: volumeSlider.centerFrameY(x: volumeToggle.frame.maxX + 16))

        let progressY = size.height - 20 - progress.frame.height + (progress.frame.height - progress.progressHeight) / 2

        let progressX: CGFloat
        switch controlStyle {
        case .compact:
            progressX = 16 + currentTimeView.frame.width + 16
        case .regular:
            progressX = volumeContainer.frame.minX + volumeSlider.frame.minX
        }

        let progressWidth = max(size.width - progressX - 16 - 16 - durationView.frame.width, 0)

        transition.updateFrame(
            view: progress,
            frame: NSRect(origin: NSPoint(x: progressX, y: progressY), size: NSSize(width: progressWidth, height: 12))
        )

        transition.updateFrame(
            view: currentTimeView,
            frame: NSRect(origin: NSPoint(x: 16, y: progressY), size: currentTimeView.frame.size)
        )

        transition.updateFrame(
            view: durationView,
            frame: NSRect(origin: NSPoint(x: size.width - durationView.frame.width - 16, y: progressY), size: durationView.frame.size)
        )
    }


    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
}

private final class PreviewView : View {
    fileprivate let imageView: ImageView = ImageView()
    fileprivate let duration: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(duration)
        background = .black
        duration.background = darkPalette.grayBackground.withAlphaComponent(0.85)
        duration.disableBackgroundDrawing = true
        duration.layer?.cornerRadius = 2
    }
    
    override func layout() {
        super.layout()
        self.imageView.frame = bounds
        self.duration.centerX(y: frame.height - self.duration.frame.height + 1)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class SVideoView: NSView {
    
    var initialedSize: NSSize = NSZeroSize
    
    
    var controlsStyle:SVideoControlsStyle = .regular(pip: false, fullScreen: false, hideRewind: false) {
        didSet {
            if oldValue != controlsStyle {
                controls.controlStyle = controlsStyle
                
                if let status = status {
                    self.controls.update(with: status, animated: false)
                    self.controls.update(with: status, animated: true)
                    if let controls = self.pipControls {
                        controls.update(with: status, animated: false)
                        controls.update(with: status, animated: true)

                    }
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
    
    private var previewView: PreviewView?
    private var overlayPreview: ImageView?
    
    private var adMessage: Message?
    private var adsArguments: SVideoAdsArguments?
    
    private var adMessageView: AdMessageView?
    
    
    func set(adMessage: Message?, arguments: SVideoAdsArguments?, animated: Bool) {
        self.adMessage = adMessage
        self.adsArguments = arguments
        
        if let adMessage, let arguments {
            let current: AdMessageView
            let isNew: Bool
            if let view = self.adMessageView {
                current = view
                isNew = false
            } else {
                current = AdMessageView(frame: NSMakeRect(10, 0, controls.frame.width, 50))
                self.adMessageView = current
                addSubview(current, positioned: .below, relativeTo: controls)
                isNew = true
            }
            
            let width: CGFloat
            if let _ = pipControls {
                width = frame.width - 40
            } else {
                width = controls.frame.width
            }
            
            current.set(message: adMessage, arguments: arguments, width: width, animated: animated)
            
            if isNew {
                current.centerX(y: frame.height - current.frame.height - 10)

                current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
        } else if let view = self.adMessageView {
            performSubviewRemoval(view, animated: animated)
            self.adMessageView = nil
        }
        
        if let adMessage {
            arguments?.markAsSeen(adMessage)
        }
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeOut)
        self.updateLayout(size: self.frame.size, transition: transition)
    }
    
    var status: MediaPlayerStatus? = nil {
        didSet {
            if status != oldValue {
                controls.status = status
                pipControls?.status = status
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
                if let status = status, status.status != oldValue?.status {
                    switch status.status {
                    case .playing, .paused:
                        self.hideScrubblerPreviewIfNeeded(live: true)
                    default:
                        break
                    }
                }
            }
            
        }
    }
    var bufferingStatus: (RangeSet<Int64>, Int64)? {
        didSet {
            if let ranges = bufferingStatus {
                var bufRanges: [Range<CGFloat>] = []
                guard ranges.1 != 0 else {
                    print("Warning: Division by zero avoided")
                    return
                }

                for range in ranges.0.ranges {
                    let low = CGFloat(range.lowerBound) / CGFloat(ranges.1)
                    let high = CGFloat(range.upperBound) / CGFloat(ranges.1)
                    
                    // Ensure lowerBound <= upperBound
                    let lower = min(low, high)
                    let upper = max(low, high)
                    
                    if lower < upper {
                        bufRanges.append(lower..<upper)
                    }
                }

                controls.bufferingRanges = bufRanges
                pipControls?.bufferingRanges = bufRanges
            } else {
                controls.bufferingRanges = [Range(uncheckedBounds: (lower: -1, upper: -1))]
                pipControls?.bufferingRanges = [Range(uncheckedBounds: (lower: -1, upper: -1))]
            }
        }
    }
    private let bufferingIndicator: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 40, 40))
  
    private let controls: SVideoControlsView = SVideoControlsView(frame: NSZeroRect)
    private var pipControls: SVideoPipControls?
    var isControlsLimited: Bool = false {
        didSet {
            controls.isControlsLimited = isControlsLimited
        }
    }

    let mediaPlayer: (NSView & UniversalVideoContentView)
    
    private let backgroundView: NSView = NSView()
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        let oldSize = mediaPlayer.frame.size
        transition.updateFrame(view: mediaPlayer, frame: NSRect(origin: .zero, size: size))
        mediaPlayer.updateLayout(size: size, transition: transition)

        let previousIsCompact = controlsStyle.isCompact
        self.controlsStyle = self.controlsStyle
            .withUpdatedStyle(compact: size.width < 300)
            .withUpdatedHideRewind(hideRewind: size.width < 400)

        let controlsWidth = self.controlsStyle.isCompact ? 220 : min(size.width - 10, 510)
        let controlsHeight: CGFloat = self.isControlsLimited ? 46 : 94
        
        var offset: CGFloat = 0
        
        if let adMessageView {
            let adWidth: CGFloat
            if let _ = pipControls {
                adWidth = size.width - 40
            } else {
                adWidth = controlsWidth
            }
            adMessageView.resize(width: adWidth)
            
            let x = focus(NSMakeSize(adWidth, adMessageView.height)).minX
            
            transition.updateFrame(view: adMessageView, frame: CGRect(origin: CGPoint(x: x, y: size.height - adMessageView.height - 20), size: NSMakeSize(adWidth, adMessageView.height)))
            adMessageView.updateLayout(size: adMessageView.frame.size, transition: transition)
            
            offset += adMessageView.frame.height
        }
        
        var controlsRect = CGRect(origin: NSMakePoint(floorToScreenPixels((size.width - controlsWidth) / 2), size.height - controlsHeight - 24 - offset), size: NSSize(width: controlsWidth, height: controlsHeight))

        let bufferingStatus = self.bufferingStatus
        self.bufferingStatus = bufferingStatus // possibly triggers side effects?

        transition.updateFrame(view: controls, frame: controlsRect)
        controls.updateLayout(size: controls.frame.size, transition: transition)


        transition.updateFrame(view: bufferingIndicator, frame: bufferingIndicator.centerFrame())
        bufferingIndicator.progressColor = .white

        transition.updateFrame(view: backgroundView, frame: NSRect(origin: .zero, size: size))

        if let pipControls = pipControls {
            transition.updateFrame(view: pipControls, frame: NSRect(origin: .zero, size: size))
        }
        

    }
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
    
    func hideControls(_ hide: Bool, animated: Bool) {
        
        var hide = hide
        
        
        if !hide {
            controls.isHidden = false
        }
        if hide {
            self.hideScrubblerPreviewIfNeeded(live: false)
        }
        
        controls._change(opacity: hide ? 0 : 1, animated: animated, duration: 0.2, timingFunction: .linear, completion: { [weak self] completed in
            if completed {
                self?.controls.isHidden = hide
            }
        })
        if let controls = pipControls {
            if !hide {
                controls.isHidden = false
            }
            controls.change(opacity: hide ? 0 : 1, animated: animated, duration: 0.2, timingFunction: .linear, completion: { [weak self] completed in
                if completed {
                    self?.pipControls?.isHidden = hide
                }
            })
        }
    }
    
    override var isOpaque: Bool {
        return true
    }
    
    func setMode(_ mode: PictureInPictureControlMode, animated: Bool) {
        switch mode {
        case .pip:
            let current: SVideoPipControls
            if let view = self.pipControls {
                current = view
            } else {
                current = SVideoPipControls(frame: self.bounds)
                addSubview(current)
                self.pipControls = current
                
                current.playOrPause.set(handler: { [weak self] _ in
                    self?.interactions?.playOrPause()
                    self?.hideScrubblerPreviewIfNeeded(live: true)
                }, for: .Click)
                
                current.progress.onUserChanged = { [weak self] value in
                    guard let `self` = self else {return}
                    if let status = self.status {
                        let result = min(status.duration * Double(value), status.duration)
                        self.status = status.withUpdatedTimestamp(result)
                        self.interactions?.rewind(result)
                    }
                }
                current.volumeSlider.onUserChanged = { [weak self] value in
                    guard let `self` = self else {return}
                    self.interactions?.volume(value)
                }
                current.volumeToggle.set(handler: { [weak self] _ in
                    guard let `self` = self else {return}
                    if let status = self.status {
                        self.interactions?.volume(status.volume == 0 ? 0.8 : 0)
                    }
                }, for: .Click)
                
                current.close.set(handler: { [weak self] _ in
                    self?.interactions?.closePictureInPicture()
                }, for: .Click)
                
                current.fullscreen.set(handler: { [weak self] _ in
                    self?.interactions?.togglePictureInPicture()
                }, for: .Click)
                
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            performSubviewRemoval(self.controls, animated: animated)
        case .normal:
            if let view = pipControls {
                performSubviewRemoval(view, animated: animated)
                self.pipControls = nil
            }
            self.addSubview(self.controls)
        }
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if initialedSize == NSZeroSize {
            self.initialedSize = newSize
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        let point = self.convert(event.locationInWindow, from: nil)
        if !NSPointInRect(point, controls.frame) {
            super.mouseUp(with: event)
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
    }
    
    
    var insideControls: Bool {
        guard let window = window else {return false}
        let point = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        if pipControls != nil {
            if NSPointInRect(point, bounds) {
                return !controls.isHidden
            }
        }
        if let adMessageView, NSPointInRect(point, adMessageView.frame) {
            return true
        }
        return NSPointInRect(point, controls.frame) && !controls.isHidden
    }
    
    private func updateLayout() {
        
    }
    
    override init(frame frameRect: NSRect) {
        fatalError("init(coder:) has not been implemented")
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
    
    init(frame frameRect: NSRect, mediaPlayer: (NSView & UniversalVideoContentView)) {
        self.mediaPlayer = mediaPlayer
        self.controls.mediaPlayer = mediaPlayer
        super.init(frame: frameRect)
        addSubview(backgroundView)
        addSubview(mediaPlayer)
        addSubview(bufferingIndicator)
        addSubview(controls)
        bufferingIndicator.innerInset = 8.0
        backgroundView.wantsLayer = true
        backgroundView.background = .black
        
        bufferingIndicator.backgroundColor = .blackTransparent
        bufferingIndicator.layer?.cornerRadius = 20
        
        backgroundView.isHidden = true
        
        
        controls.playOrPause.set(handler: { [weak self] _ in
            self?.interactions?.playOrPause()
        }, for: .Click)
        
        
        controls.livePreview = { [weak self] value, live in
            guard let `self` = self else {return}
            if let status = self.status {
                self.interactions?.scrobbling(value != nil ? status.duration * Double(value!) : nil)
                self.setCurrentScrubblingState(self.currentPreviewState, live: live)
            }
            if value != nil {
                if live {
                    self.interactions?.pause()
                    self.hideScrubblerPreviewIfNeeded(live: false)
                } else {
                    self.interactions?.play()
                }
            }
            
        }
        
        controls.progress.onUserChanged = { [weak self] value in
            guard let `self` = self else {return}
            if let status = self.status {
                let result = min(status.duration * Double(value), status.duration)
                self.status = status.withUpdatedTimestamp(result)
                self.interactions?.rewind(result)
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
        
        controls.menuItems.contextMenu = { [weak self] in
            let menu = ContextMenu(presentation: .current(darkPalette))
            
            menu.onShow = { _ in
                self?.isInMenu = true
            }
            menu.onClose = {
                self?.isInMenu = false
            }
            menu.delegate = menu
            
            let customItem = ContextMenuItem(String(format: "%.1fx", FastSettings.playingVideoRate), image: NSImage(cgImage: generateEmptySettingsIcon(), size: NSMakeSize(24, 24)))
            
            menu.addItem(SliderContextMenuItem(volume: FastSettings.playingVideoRate, minValue: 0.2, maxValue: 2.5, midValue: 1, drawable: MenuAnimation.menu_speed, drawable_muted: MenuAnimation.menu_speed, { [weak self] value, _ in
                customItem.title = String(format: "%.1fx", value)
                self?.interactions?.setBaseRate(value)
                self?.controls.updateBaseRate()
            }))
            
            menu.addItem(customItem)
            
            if FastSettings.playingVideoRate != 1.0 {
                menu.addItem(ContextSeparatorItem())
                menu.addItem(ContextMenuItem(strings().playbackSpeedSetToDefault, handler: { [weak self] in
                    self?.interactions?.setBaseRate(1.0)
                    self?.controls.updateBaseRate()
                }, itemImage: MenuAnimation.menu_reset.value))
            }
            
            menu.addItem(ContextSeparatorItem())

            
            if let mediaPlayer = self?.mediaPlayer, let quality = mediaPlayer.videoQualityState() {
                menu.addItem(ContextMenuItem(strings().videoQualityAuto, handler: { [weak mediaPlayer] in
                    FastSettings.videoQuality = .auto
                    mediaPlayer?.setVideoQuality(.auto)
                }, state: quality.preferred == .auto ? .on : nil))
                
                for value in quality.available {
                    menu.addItem(ContextMenuItem("\(roundToStandardQuality(size: value))p", handler: { [weak mediaPlayer] in
                        FastSettings.videoQuality = .quality(value)
                        mediaPlayer?.setVideoQuality(.quality(value))
                    }, state: quality.preferred == .quality(value) ? .on : nil))
                }
            }

            
            menu.appearance = darkPalette.appearance
            return menu
        }
        
        
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
    
    func showScrubblerPreviewIfNeeded(live: Bool) {
        if !live {
            if previewView == nil {
                previewView = PreviewView(frame: NSZeroRect)
                previewView?.background = .black
                addSubview(previewView!)
            }
            previewView?.setFrameSize(initialedSize.aspectFitted(NSMakeSize(150, 150)))
        }
        if live {
            if self.overlayPreview == nil {
                self.overlayPreview = ImageView(frame: self.mediaPlayer.frame)
                self.addSubview(overlayPreview!, positioned: .above, relativeTo: mediaPlayer)
                self.overlayPreview?.background = theme.colors.blackTransparent
            }
            if let _ = previewView {
                self.previewView?.removeFromSuperview()
                self.previewView = nil
            }
        }
    }
    
    var mouseDownIncontrols: Bool {
        return self.controls.progress.hasTemporaryState
    }
    
    private var currentPreviewState: MediaPlayerFramePreviewResult?
    
    func setCurrentScrubblingState(_ state: MediaPlayerFramePreviewResult?, live: Bool) {
        self.currentPreviewState = state
        guard let window = self.window, let status = self.status, !self.controls.isHidden else {
            self.previewView?.removeFromSuperview()
            self.previewView = nil
            return
        }
        let point = self.controls.progress.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        
        if let state = currentPreviewState {
            switch state {
            case let .image(image):
                previewView?.imageView.image = image
                previewView?.imageView.isHidden = false
                
                overlayPreview?.image = image
                
            case .waitingForData:
                break
            }
        }
        
        guard let previewView = self.previewView else {
            return
        }
        
        
        let progressPoint = NSMakePoint(max(0, min(point.x, self.controls.progress.frame.width)), 0)
        let converted = self.convert(progressPoint, from: self.controls.progress)
        previewView.setFrameOrigin(NSMakePoint(max(10, min(frame.width - previewView.frame.width - 10, converted.x - previewView.frame.width / 2)), self.controls.frame.minY - previewView.frame.height - 10))
        
        
        let currentTime = Int(round(progressPoint.x / self.controls.progress.frame.width * CGFloat(status.duration)))
        
        
        let duration = String.durationTransformed(elapsed: currentTime)
        let layout = TextViewLayout(.initialize(string: duration, color: .white, font: .medium(.text)), maximumNumberOfLines: 1, alignment: .center, alwaysStaticItems: true)
        
        layout.measure(width: .greatestFiniteMagnitude)
        
        previewView.duration.update(layout)
        previewView.duration.setFrameSize(NSMakeSize(layout.layoutSize.width + 10, layout.layoutSize.height + 10))
        previewView.duration.display()
        previewView.needsLayout = true
    }
    
    private(set) var isInMenu: Bool = false
    
    
    func hideScrubblerPreviewIfNeeded(live: Bool) {
        self.currentPreviewState = nil
        if live {
            if let _ = self.overlayPreview {
                self.overlayPreview?.removeFromSuperview()
                self.overlayPreview = nil
            }
        } else {
            if let _ = previewView {
                previewView?.removeFromSuperview()
                previewView = nil
            }
        }
    }
}
