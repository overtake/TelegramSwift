//
//  StoryVoiceRecordingView.swift
//  Telegram
//
//  Created by Mike Renoir on 16.05.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import ObjcUtils


private enum StoryRecordingOverlayState {
    case voice
    case video
    case fixed
}

private final class LockControl : View {
    private let head: ImageView = ImageView()
    private let body: ImageView = ImageView()
    private let arrow: ImageView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.cornerRadius = frameRect.width / 2
        addSubview(head)
        addSubview(arrow)
        addSubview(body)
        updateLocalizationAndTheme(theme: darkAppearance)
    }
    
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        backgroundColor = theme.colors.background
        head.image = theme.icons.chatOverlayLockerHeadRecording
        head.sizeToFit()
        body.image = theme.icons.chatOverlayLockerBodyRecording
        body.sizeToFit()
        arrow.image = theme.icons.chatOverlayLockArrowRecording
        arrow.sizeToFit()
        layer?.borderColor = theme.colors.accent.cgColor
        layer?.borderWidth = .borderSize
    }
    
    private var currentPercent: CGFloat = 1.0
    
    override func layout() {
        super.layout()
        arrow.centerX(y: frame.height - arrow.frame.height - 8)
        body.centerX(y: floorToScreenPixels(backingScaleFactor, (30 - body.frame.height)/2) + 3)
        head.centerX(y: 4)
    }
    
    fileprivate func updatePercent(_ percent: CGFloat) {
        arrow.change(opacity: percent, animated: true)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

private class StoryRecorderOverlayView : Control {
    private let innerContainer: Control = Control()
    private let outerContainer: Control = Control()
    private let stateView: ImageView = ImageView()
    private var currentLevel: Double = 1.0
    private var previousTime: Date = Date()
    private let playbackAudioLevelView: VoiceBlobView
    required init(frame frameRect: NSRect) {
        playbackAudioLevelView = VoiceBlobView(
            frame: NSMakeRect(0, 0, frameRect.width, frameRect.height),
            maxLevel: 0.3,
            smallBlobRange: (0, 0),
            mediumBlobRange: (0.7, 0.8),
            bigBlobRange: (0.8, 0.9)
        )

        super.init(frame: frameRect)
        layer?.cornerRadius = frameRect.width / 2
        backgroundColor = .clear

        addSubview(playbackAudioLevelView)

        playbackAudioLevelView.center()
        
        innerContainer.setFrameSize(NSMakeSize(frameRect.width - 40, frameRect.height - 40))
        innerContainer.backgroundColor = theme.colors.accent
        innerContainer.layer?.cornerRadius = innerContainer.frame.width / 2
        addSubview(innerContainer)
        innerContainer.center()
        addSubview(stateView)
//
        
        
        self.playbackAudioLevelView.startAnimating()
        
    }
    
    fileprivate func updateState(_ overlayState: StoryRecordingOverlayState) {
        switch overlayState {
        case .voice:
            stateView.image = darkAppearance.icons.chatOverlayVoiceRecording
        case .video:
            stateView.image = darkAppearance.icons.chatOverlayVideoRecording
        case .fixed:
            stateView.image = darkAppearance.icons.chatOverlaySendRecording
        }
        stateView.sizeToFit()
        stateView.center()
        
        updateInside()

    }
    
    func updatePeakLevel(_ peakLevel: Float) {
        //NSLog("\(peakLevel)")
        
        let power = mappingRange(Double(peakLevel), 0.3, 3, 0, 1);
        if (Date().timeIntervalSinceNow - previousTime.timeIntervalSinceNow) > 0.2  {
            playbackAudioLevelView.updateLevel(CGFloat(power))
            self.previousTime = Date()
        }
    }
    
    func updateInside() {
        innerContainer.backgroundColor = mouseInside() ? darkAppearance.colors.accent : darkAppearance.colors.redUI
        let animation = CABasicAnimation(keyPath: "backgroundColor")
        animation.duration = 0.1
        innerContainer.layer?.add(animation, forKey: "backgroundColor")
        
        self.playbackAudioLevelView.setColor(mouseInside() ? darkAppearance.colors.accent : darkAppearance.colors.redUI, animated: true)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class StoryRecorderOverlayWindowController : NSObject {
    let window: Window
    private let parent: Window
    private let disposable = MetaDisposable()
    private var state: StoryRecordingOverlayState
    private var startMouseLocation: NSPoint = .zero
    private let lockWindow: Window
    private let arguments: StoryArguments
    private let focusView: NSView
    init(parent: Window, focusView: NSView, state: ChatRecordingState, arguments: StoryArguments) {
        self.parent = parent
        self.state = state is ChatRecordingAudioState ? .voice : .video
        self.arguments = arguments
        self.focusView = focusView
        let size = NSMakeSize(120, 120)
        
        window = Window(contentRect: NSMakeRect(0, 0, size.width, size.height), styleMask: [], backing: .buffered, defer: true)
        window.backgroundColor = .clear
        window.contentView = StoryRecorderOverlayView(frame: NSMakeRect(0, 0, size.width, size.height))
        
        lockWindow = Window(contentRect: NSMakeRect(0, 0, 26, 50), styleMask: [], backing: .buffered, defer: true)
        lockWindow.contentView?.addSubview(LockControl(frame: NSMakeRect(0, 0, 26, 50)))
        lockWindow.backgroundColor = .clear
        super.init()
        self.view.updateState(self.state)
    }
    
    private var view: StoryRecorderOverlayView {
        return window.contentView as! StoryRecorderOverlayView
    }
    
    func stopAndSend() {
        if let recorder = arguments.interaction.presentation.inputRecording {
            recorder.stop()
            _ = (recorder.data |> deliverOnMainQueue).start(next: { [weak self] medias in
                self?.arguments.chatInteraction.sendMedia(medias)
            })
            closeModal(VideoRecorderModalController.self)
        }
        arguments.interaction.resetRecording()
    }
    
    func stopAndCancel() {
        let proccess = { [weak self] in
            guard let `self` = self else {return}
            if let recorder = self.arguments.interaction.presentation.inputRecording {
                recorder.stop()
                recorder.dispose()
                closeModal(VideoRecorderModalController.self)
            }
            self.arguments.interaction.resetRecording()
        }
        if state == .fixed {
            verifyAlert_button(for: parent, information: strings().chatRecordingCancel, ok: strings().alertDiscard, cancel: strings().alertNO, successHandler: { _ in
                proccess()
            })
        } else {
            proccess()
        }
    }
    
    var minX: CGFloat {
        let wrect = focusView.convert(self.focusView.bounds, to: nil)
        let rect = self.parent.convertToScreen(wrect)
        return rect.minX - window.frame.width / 2
    }
    
    var minY: CGFloat {
        let wrect = focusView.convert(self.focusView.bounds, to: nil)
        let rect = self.parent.convertToScreen(wrect)
        return rect.minY - window.frame.width / 2 + 1
    }
    
    private func moveWindow() -> Void {
        let location = window.mouseLocationOutsideOfEventStream
        let defaultY = self.minY
        window.setFrameOrigin(NSMakePoint(minX, max(window.frame.minY - (startMouseLocation.y - location.y), defaultY)))
        let dif = window.frame.minY - defaultY
        let maxDif: CGFloat = 100
        if dif > maxDif {
            hold(animated: false)
        } else {
            let view = self.lockControl
            let dh: CGFloat = 50
            let dm: CGFloat = 30
            let percent = 1.0 - dif / 100
            let h = max(dm, min(dh, dm + percent * dm))
            view.frame = NSMakeRect(0, view.superview!.frame.height - h, view.frame.width, h)
            view.updatePercent(percent)
        }
    }
    
    private func hold(animated: Bool) {
        
        arguments.interaction.presentation.inputRecording?.holdpromise.set(true)
        
        view.updateInside()
        
        let defaultY = self.minY
        
        self.state = .fixed
        view.updateState(.fixed)
        window.animator().setFrame(window.frame.offsetBy(dx: 0, dy: -(window.frame.minY - defaultY)), display: true)
        
        parent.remove(object: self, for: .leftMouseDown)
        parent.remove(object: self, for: .leftMouseUp)
        window.remove(object: self, for: .leftMouseUp)
        
        let proccessMouseUp:(NSEvent)->KeyHandlerResult = { [weak self] _ in
            guard let `self` = self else {return .rejected}
            if findModal(InputDataModalController.self) != nil {
                return .rejected
            }
            return self.proccessMouseUp()
        }
        parent.set(mouseHandler: proccessMouseUp, with: self, for: .leftMouseDown, priority: .modal)
        window.set(mouseHandler: proccessMouseUp, with: self, for: .leftMouseDown, priority: .modal)
        
        parent.removeChildWindow(lockWindow)
        
        lockControl.change(opacity: 0, animated: animated) { [weak self] _ in
            self?.lockWindow.orderOut(nil)
        }
    }
    
    private var lockControl: LockControl {
        return lockWindow.contentView!.subviews.first! as! LockControl
    }
    
    private func proccessMouseUp()-> KeyHandlerResult {
        if self.view.mouseInside() {
            self.stopAndSend()
        } else {
            self.stopAndCancel()
        }
        return .invoked
    }
    
    func show(animated: Bool) {
        
        
        window.setFrameOrigin(NSMakePoint(minX, minY))
        lockWindow.setFrameOrigin(NSMakePoint(window.frame.midX - 12.5, window.frame.minY + 160))

        guard let recorder = arguments.interaction.presentation.inputRecording else { return }
        

        
        parent.addChildWindow(lockWindow, ordered: .above)
        parent.addChildWindow(window, ordered: .above)
        
        
       
        disposable.set((recorder.micLevel |> deliverOnMainQueue).start(next: { [weak self] value in
            self?.view.updatePeakLevel(value)
        }))
       
        view.layer?.animateScaleSpring(from: 0.1, to: 1.0, duration: 0.4)
        view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        
        parent.set(mouseHandler: { [weak self] _ -> KeyHandlerResult in
            self?.view.updateInside()
            return .invoked
        }, with: self, for: .mouseMoved, priority: .modal)
        
        window.set(mouseHandler: { [weak self] _ -> KeyHandlerResult in
            self?.view.updateInside()
            return .invoked
        }, with: self, for: .mouseMoved, priority: .modal)
        
        parent.set(mouseHandler: { [weak self] _ -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            self.view.updateInside()
            if self.state != .fixed {
                self.moveWindow()
            }
            return .invoked
        }, with: self, for: .leftMouseDragged, priority: .modal)
        
        let proccessMouseUp:(NSEvent)->KeyHandlerResult = { [weak self] _ in
            guard let `self` = self else {return .rejected}
            return self.proccessMouseUp()
        }
        
        parent.set(mouseHandler: { _ in return .invoked}, with: self, for: .leftMouseDown, priority: .modal)

        parent.set(mouseHandler: proccessMouseUp, with: self, for: .leftMouseUp, priority: .modal)
        window.set(mouseHandler: proccessMouseUp, with: self, for: .leftMouseUp, priority: .modal)
        
        if recorder.autohold {
            hold(animated: false)
        }
        self.startMouseLocation = window.mouseLocationOutsideOfEventStream

        self.view.updateInside()

    }
    
    func hide(animated: Bool) {
        parent.removeChildWindow(window)
        parent.removeChildWindow(lockWindow)
        lockWindow.contentView?._change(opacity: 0, animated: true)
        var strongSelf:StoryRecorderOverlayWindowController? = self
        view.layer?.animateAlpha(from: 1.0, to: 0, duration: 0.2, removeOnCompletion: false, completion: { complete in
            strongSelf?.window.orderOut(nil)
            strongSelf?.lockWindow.orderOut(nil)
            strongSelf = nil
        })
        parent.removeAllHandlers(for: self)
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
}



class StoryRecordingView: View {

    private let descView:TextView = TextView()
    private let timerView:TextView = TextView()
    private let statusImage:ImageView = ImageView()
    private let recView: View = View(frame: NSMakeRect(0, 0, 14, 14))
    
    private let recorder:ChatRecordingState
    private var storyState: StoryInteraction.State?
    private let focusView = Control(frame: NSMakeRect(0, 0, 1, 1))
    
    private let disposable:MetaDisposable = MetaDisposable()
    private let overlay: StoryRecorderOverlayWindowController
    
    init(frame frameRect: NSRect, arguments: StoryArguments, state: StoryInteraction.State, recorder: ChatRecordingState) {
        self.recorder = recorder
        self.overlay = StoryRecorderOverlayWindowController(parent: arguments.context.window, focusView: focusView, state: recorder, arguments: arguments)
        super.init(frame: frameRect)
        
        
        statusImage.image = state.recordType == .voice ? darkAppearance.icons.chatVoiceRecording : darkAppearance.icons.chatVideoRecording
        statusImage.animates = true
        statusImage.sizeToFit()
        
        descView.userInteractionEnabled = false
        descView.isSelectable = false
        
        timerView.userInteractionEnabled = false
        timerView.isSelectable = false
        
        
        
        addSubview(descView)
        addSubview(timerView)
        addSubview(recView)
        
        addSubview(focusView)
        
        recView.layer?.cornerRadius = recView.frame.width / 2
        
        disposable.set(combineLatest(recorder.status |> deliverOnMainQueue, recorder.holdpromise.get() |> deliverOnMainQueue).start(next: { [weak self] state, hold in
            if case let .recording(duration) = state {
                self?.update(duration, true, hold)
            }
        }))
        updateLocalizationAndTheme(theme: darkAppearance)
        updateLayout(size: frameRect.size, transition: .immediate)
    }
    
    func updateState(_ state: StoryInteraction.State) {
        self.storyState = state
        updateLocalizationAndTheme(theme: darkAppearance)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        let theme = (theme as! TelegramPresentationTheme)
        
        self.statusImage.image = self.storyState?.recordType == .voice ? theme.icons.chatVoiceRecording : theme.icons.chatVideoRecording
        self.backgroundColor = NSColor.black
        self.recView.backgroundColor = theme.colors.accent
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let _ = newWindow as? Window {
            overlay.show(animated: true)
            let animate = CABasicAnimation(keyPath: "opacity")
            animate.fromValue = 1.0
            animate.toValue = 0.3
            animate.repeatCount = .infinity
            animate.duration = 1.5
            
            animate.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
            recView.layer?.add(animate, forKey: "opacity")
        } else {
            (window as? Window)?.removeAllHandlers(for: self)
            overlay.hide(animated: true)
            recView.layer?.removeAllAnimations()
        }
    }
    
    
    override func viewDidMoveToWindow() {
        update(0, false, false)
    }


    
    func update(_ duration:TimeInterval, _ animated:Bool, _ hold: Bool) {
        
        let intDuration:Int = Int(duration)
        let ms = duration - TimeInterval(intDuration);
        let transformed:String = String.durationTransformed(elapsed: intDuration)
        let timerLayout = TextViewLayout(.initialize(string:transformed  + ",\(Int(ms * 100))", color: darkAppearance.colors.text, font: .normal(.text)), maximumNumberOfLines: 1, alignment: .left)
        timerLayout.measure(width: .greatestFiniteMagnitude)
        timerView.update(timerLayout)
        
        let descLayout = TextViewLayout(.initialize(string: hold ? strings().audioRecordHelpFixed : strings().audioRecordHelpPlain, color: darkAppearance.colors.text, font: .normal(.text)), maximumNumberOfLines: 2, truncationType: .middle, alignment: .center)
        descLayout.measure(width: frame.width - 50 - 100 - 60)
        descView.update(descLayout)
        
        self.needsLayout = true
        
    }
    
    deinit {
        disposable.dispose()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    

    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        transition.updateFrame(view: recView, frame: recView.centerFrameY(x: 20))
        transition.updateFrame(view: timerView, frame: timerView.centerFrameY(x: recView.frame.maxX + 10))
        transition.updateFrame(view: statusImage, frame: statusImage.centerFrameY(x: size.width - statusImage.frame.width - 20))

        let max = (frame.width - (statusImage.frame.width + 20 + 50))
        transition.updateFrame(view: descView, frame: descView.centerFrameY(x:60 + floorToScreenPixels(backingScaleFactor, (max - descView.frame.width)/2)))
        
        transition.updateFrame(view: focusView, frame: focusView.centerFrameY(x: size.width - focusView.frame.width - 24))

    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
}
