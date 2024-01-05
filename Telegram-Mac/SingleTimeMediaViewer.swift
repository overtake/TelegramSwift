//
//  SingleTimeMediaViewer.swift
//  Telegram
//
//  Created by Mike Renoir on 30.12.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import DustLayer
import TelegramUI


private final class VoiceView : View, APDelegate {
    let hood = View(frame: NSMakeRect(0, 0, 40, 40))
    let durationView = DynamicCounterTextView()
    let waveformView = AudioWaveformView(frame: NSMakeRect(0, 0, 170, 20))
    var fireView: InlineStickerView?
    let progress: SimpleShapeLayer = SimpleShapeLayer()
    private let fireControl: FireTimerControl = FireTimerControl(frame: NSMakeRect(0, 0, 45, 45))

    private let sparkView = SparksView(frame: .zero)
    private var player: APController?
    
    private var sparksAnimator: ConstantDisplayLinkAnimator?
    
    private var activityColor: NSColor = .clear
    private var activityBackground: NSColor = .clear
    fileprivate var didFinish:((NSView)->Void)? = nil

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(hood)
        addSubview(durationView)
        addSubview(sparkView)
        addSubview(waveformView)
        hood.addSubview(fireControl)
        
        hood.layer?.masksToBounds = false
        
        hood.layer?.cornerRadius = hood.frame.height / 2
//        hood.layer?.addSublayer(progress)
        layer?.cornerRadius = 20
//        progress.lineWidth = 2
//        progress.lineCap = .round
//        progress.frame = hood.bounds.insetBy(dx: 2, dy: 2)
//        progress.fillColor = .clear
        sparkView.frame = NSMakeRect(60, 10, 100, 20)
        
    }
    
    func songDidChanged(song:APSongItem, for controller:APController, animated: Bool) {
        
    }
    private var once: Bool = false
    func songDidChangedState(song:APSongItem, for controller:APController, animated: Bool) {
        switch song.state {
        case let .playing(current, duration, _):
            let text = String.durationTransformed(elapsed: duration - current)
            
            let value = DynamicCounterTextView.make(for: text, count: text, font: .normal(.short), textColor: theme.colors.grayText, width: .greatestFiniteMagnitude)
            self.durationView.update(value, animated: true)
            self.durationView.change(size: value.size, animated: true)
        case let .paused(current, duration, _):
            
            let path = CGMutablePath()
            let endAngle = -CGFloat.pi / 2.0
            let startAngle = CGFloat(0.01) * 2.0 * CGFloat.pi + endAngle

            path.addArc(center: CGPointMake(self.progress.frame.width / 2, self.progress.frame.height / 2), radius: self.progress.frame.height / 2, startAngle: -(.pi / 2), endAngle: (.pi * 2) - (.pi / 2), clockwise: false)
            
            self.progress.path = path
            self.progress.transform = CATransform3DScale(CATransform3DIdentity, -1, 1, 1)

            setProgressWithAnimation(duration: duration, value: 0)
            
            let tickValue = 1 / 60 / duration
            
            self.sparksAnimator = ConstantDisplayLinkAnimator(update: { [weak self] in
                guard let `self` = self else {
                    return
                }
                progressValue += tickValue
                
                let width = self.sparkView.frame.width
                
                self.sparkView.update(position: NSMakePoint(5 + width * (1 - progressValue), 18), sampleHeight: 5, color: self.activityBackground)
                
                self.waveformView.foregroundClipingView.setFrameSize(NSMakeSize(width * (1 - progressValue), 20))
            })
            sparksAnimator?.isPaused = false
            
            let text = String.durationTransformed(elapsed: duration - current)
            
            let value = DynamicCounterTextView.make(for: text, count: text, font: .normal(.short), textColor: theme.colors.grayText, width: .greatestFiniteMagnitude)
            self.durationView.update(value, animated: true)
            self.durationView.change(size: value.size, animated: true)
            
            let deadline = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            
            fireControl.update(color: activityColor, timeout: duration, deadlineTimestamp: deadline + duration)
            
        default:
            break
        }
        needsLayout = true
    }
    func songDidStartPlaying(song:APSongItem, for controller:APController, animated: Bool) {
        
    }
    func songDidStopPlaying(song:APSongItem, for controller:APController, animated: Bool) {
        
    }
    func playerDidChangedTimebase(song:APSongItem, for controller:APController, animated: Bool) {
        
    }
    func audioDidCompleteQueue(for controller:APController, animated: Bool) {
        self.sparksAnimator?.isPaused = true
        didFinish?(self)
    }
    
    func stopAndClose() {
        self.player?.stop()
        self.sparksAnimator?.isPaused = true
        didFinish?(self)
    }

    private func setProgressWithAnimation(duration: TimeInterval, value: Float) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.duration = duration
        animation.fromValue = self.progress.strokeEnd
        animation.toValue = value
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        progress.strokeEnd = CGFloat(value)
        progress.add(animation, forKey: "animateprogress")
    }
    
    private var progressValue: Double = 0
    
    func set(media: TelegramMediaFile, isIncoming: Bool, context: AccountContext) {
        
        let activityColor = theme.chat.activityForeground(isIncoming, true)
        let activityBackground = theme.chat.activityBackground(isIncoming, true)
        
        self.activityColor = activityColor
        self.activityBackground = activityBackground
        
        
        let waveformBase64 = "DAAOAAkACQAGAAwADwAMABAADQAPABsAGAALAA0AGAAfABoAHgATABgAGQAYABQADAAVABEAHwANAA0ACQAWABkACQAOAAwACQAfAAAAGQAVAAAAEwATAAAACAAfAAAAHAAAABwAHwAAABcAGQAAABQADgAAABQAHwAAAB8AHwAAAAwADwAAAB8AEwAAABoAFwAAAB8AFAAAAAAAHwAAAAAAHgAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAAAA="
        
        var waveform: AudioWaveform = AudioWaveform(bitstream: Data(base64Encoded: waveformBase64)!, bitsPerSample: 5)
        for attr in media.attributes {
            switch attr {
            case let .Audio(_, _, _, _, _data):
                if let data = _data {
                    waveform = AudioWaveform(bitstream: data, bitsPerSample: 5)
                }
            default:
                break
            }
        }
        
        waveformView.set(foregroundColor: activityBackground, backgroundColor: .clear)
        waveformView.waveform = waveform
        
        let fireView = InlineStickerView(account: context.account, file: LocalAnimatedSticker.single_voice_fire.file, size: NSMakeSize(30, 30), getColors: { _ in
            return [.init(keyPath: "", color: activityColor)]
        })
        hood.addSubview(fireView)
        self.fireView = fireView
        
        hood.backgroundColor = activityBackground
        progress.strokeColor = activityColor.cgColor

        backgroundColor = theme.chat.bubbleBackgroundColor(isIncoming, true)
        
        sparkView.layer?.masksToBounds = false
        
        let player = APSingleResourceController(context: context, wrapper: .init(resource: media.resource, name: "", performer: "", duration: media.duration, id: 0), streamable: false)
        player.start()
        
        player.add(listener: self)
        
        self.player = player
        
        needsLayout = true

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        hood.centerY(x: 10)
        fireView?.center()
        fireControl.center()
        
        sparkView.frame = NSMakeRect(hood.frame.maxX + 10, floorToScreenPixels((frame.height - 20) / 2) - 10, frame.width - (hood.frame.maxX + 10) - 10, 20)
        
        waveformView.frame = NSMakeRect(hood.frame.maxX + 10, floorToScreenPixels((frame.height - 20) / 2) - 10, frame.width - (hood.frame.maxX + 10) - 10, 20)
        
        durationView.setFrameOrigin(NSMakePoint(hood.frame.maxX + 10, waveformView.frame.maxY + 4))
    }
}

private final class SingleTimeMediaView : View {
    fileprivate var voiceView: VoiceView?
    fileprivate let close = TextButton()
    func update(context: AccountContext, message: Message) {
        let media = message.media.first! as! TelegramMediaFile
        
        if media.isVoice {
            let voiceView = VoiceView(frame: NSMakeRect(0, 0, 220, 60))
            addSubview(voiceView)
            self.voiceView = voiceView
            
            voiceView.set(media: media, isIncoming: message.isIncoming(context.account, true), context: context)
        }
        close.set(font: .medium(.text), for: .Normal)
        close.set(color: theme.colors.text, for: .Normal)
        close.set(background: NSColor.black.withAlphaComponent(0.6), for: .Normal)
        close.set(text: strings().navigationClose, for: .Normal)
        close.scaleOnClick = true
        close.sizeToFit(NSMakeSize(20, 20))
        close.layer?.cornerRadius = close.frame.height / 2
        addSubview(close)
        needsLayout = true
    }
    
    func stopAndClose() {
        self.voiceView?.stopAndClose()
    }
    
    override func layout() {
        super.layout()
        voiceView?.center()
        close.centerX(y: frame.height - close.frame.height - 40)
    }
}

final class SingleTimeMediaViewer : ModalViewController {
    override var isVisualEffectBackground: Bool {
        return true
    }
    
    override var background: NSColor {
        return .clear
    }
    
    override var containerBackground: NSColor {
        return .clear
    }
    
    override func viewClass() -> AnyClass {
        return SingleTimeMediaView.self
    }
    
    override var isFullScreen: Bool {
        return true
    }
    
    private let context: AccountContext
    private let message: Message
    
    init(context: AccountContext, message: Message) {
        self.context = context
        self.message = message
        super.init()
    }
    
    private var genericView: SingleTimeMediaView {
        return self.view as! SingleTimeMediaView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.update(context: context, message: message)
        
        genericView.voiceView?.didFinish = { [weak self] view in
            self?.close()
        }
        genericView.close.set(handler: { [weak self] _ in
            self?.genericView.stopAndClose()
        }, for: .Click)
        
        _ = context.engine.messages.markMessageContentAsConsumedInteractively(messageId: message.id).start()

        readyOnce()
    }
    
    override func close(animationType: ModalAnimationCloseBehaviour = .common) {
        super.close(animationType: animationType)
        if let view = genericView.voiceView {
            ApplyDustAnimation(for: view)
        }
    }
    
    override var hasBorder: Bool {
        return false
    }
    
    static func show(context: AccountContext, message: Message) {
        showModal(with: SingleTimeMediaViewer(context: context, message: message), for: context.window, animationType: .animateBackground)
    }
}


