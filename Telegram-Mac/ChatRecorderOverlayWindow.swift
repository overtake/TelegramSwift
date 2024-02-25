//
//  ChatRecorderOverlayWindow.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07/05/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import ObjcUtils
import SwiftSignalKit

private enum ChatRecordingOverlayState {
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
        updateLocalizationAndTheme(theme: theme)
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
        
//        let dh: CGFloat = 4
//        let dm: CGFloat = 7
//        let y = max(dm, min(dh, dm + percent * dm))
//        head.centerX(y: y)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}


private final class SingleTimeControl : Control {
    private let head: ImageView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.cornerRadius = frameRect.width / 2
        addSubview(head)
        updateLocalizationAndTheme(theme: theme)
        isSelected = false
        
        scaleOnClick = true
        set(handler: { control in
            control.isSelected = !control.isSelected
        }, for: .Click)
    }
    
    override var isSelected: Bool {
        didSet {
            head.animates = true
            head.image = NSImage(named: isSelected ? "Icon_OnceView_Filled" : "Icon_OnceView")?.precomposed(theme.colors.accent)
            head.sizeToFit()
            needsLayout = true
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        backgroundColor = theme.colors.background
        layer?.borderColor = theme.colors.grayIcon.withAlphaComponent(0.4).cgColor
        layer?.borderWidth = .borderSize
    }
    
    
    override func layout() {
        super.layout()
        head.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

private class ChatRecorderOverlayView : Control {
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
//
//        outerContainer.setFrameSize(NSMakeSize(frameRect.width - 30, frameRect.height - 30))
//        outerContainer.backgroundColor = theme.colors.accent.withAlphaComponent(0.5)
//        outerContainer.layer?.cornerRadius = outerContainer.frame.width / 2
//        addSubview(outerContainer)
//        outerContainer.center()
//      //  self.outerContainer.animates = true
//
        
        addSubview(playbackAudioLevelView)

        playbackAudioLevelView.center()
        
        innerContainer.setFrameSize(NSMakeSize(frameRect.width - 40, frameRect.height - 40))
        innerContainer.backgroundColor = theme.colors.accent
        innerContainer.layer?.cornerRadius = innerContainer.frame.width / 2
        addSubview(innerContainer)
        innerContainer.center()
       // self.innerContainer.animates = true
        addSubview(stateView)
//
        
        
        self.playbackAudioLevelView.startAnimating()
        
    }
    
    fileprivate func updateState(_ overlayState: ChatRecordingOverlayState) {
        switch overlayState {
        case .voice:
            stateView.image = theme.icons.chatOverlayVoiceRecording
        case .video:
            stateView.image = theme.icons.chatOverlayVideoRecording
        case .fixed:
            stateView.image = theme.icons.chatOverlaySendRecording
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
        innerContainer.backgroundColor = mouseInside() ? theme.colors.accent : theme.colors.redUI        
        let animation = CABasicAnimation(keyPath: "backgroundColor")
        animation.duration = 0.1
        innerContainer.layer?.add(animation, forKey: "backgroundColor")
        
        self.playbackAudioLevelView.setColor(mouseInside() ? theme.colors.accent : theme.colors.redUI, animated: true)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ChatRecorderOverlayWindowController : NSObject {
    let window: Window
    private let parent: Window
    private let disposable = MetaDisposable()
    private let chatInteraction: ChatInteraction
    private var state: ChatRecordingOverlayState
    private let startMouseLocation: NSPoint
    private let lockWindow: Window
    init(parent: Window, chatInteraction: ChatInteraction) {
        self.parent = parent
        self.chatInteraction = chatInteraction
        self.state = chatInteraction.presentation.recordingState is ChatRecordingAudioState ? .voice : .video
        let size = NSMakeSize(120, 120)
        
        window = Window(contentRect: NSMakeRect(parent.frame.maxX - size.width + 25, parent.frame.minY - 35, size.width, size.height), styleMask: [], backing: .buffered, defer: true)
        window.backgroundColor = .clear
        window.contentView = ChatRecorderOverlayView(frame: NSMakeRect(0, 0, size.width, size.height))
        
        lockWindow = Window(contentRect: NSMakeRect(window.frame.midX - 12.5 - 5, parent.frame.minY + 160, 36, 50), styleMask: [], backing: .buffered, defer: true)
        lockWindow.contentView?.wantsLayer = true
        lockWindow.contentView?.layer?.masksToBounds = false
        lockWindow.contentView?.addSubview(LockControl(frame: NSMakeRect(5, 0, 26, 50)))
        lockWindow.contentView?.addSubview(SingleTimeControl(frame: NSMakeRect(0, 0, 36, 36)))

        lockWindow.backgroundColor = .clear
        startMouseLocation = window.mouseLocationOutsideOfEventStream
        super.init()
        self.view.updateState(state)
        window.setFrameOrigin(NSMakePoint(minX, window.frame.minY))
        
        singleTimeControl.layer?.opacity = 0
    }
    
    private var view: ChatRecorderOverlayView {
        return window.contentView as! ChatRecorderOverlayView
    }
    
    func stopAndSend() {
        if let recorder = chatInteraction.presentation.recordingState {
            recorder.stop()
            recorder.isOneTime = singleTimeControl.isSelected
            delay(0.1, closure: {
                self.chatInteraction.mediaPromise.set(recorder.data)
                closeAllModals()
            })
        }
        chatInteraction.update({$0.withoutRecordingState()})
    }
    
    func stopAndCancel() {
        let proccess = { [weak self] in
            guard let `self` = self else {return}
            if let recorder = self.chatInteraction.presentation.recordingState {
                recorder.stop()
                recorder.dispose()
                closeAllModals()
            }
            self.chatInteraction.update({$0.withoutRecordingState()})
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
        let navigation = chatInteraction.context.bindings.rootNavigation()
        if navigation.genericView.state == .dual, let sidebar = navigation.sidebar {
            return parent.frame.maxX - window.frame.width - sidebar.frame.width + 35
        }
        return parent.frame.maxX - window.frame.width + 25
    }
    
    private func moveWindow() -> Void {
        let location = window.mouseLocationOutsideOfEventStream
        let defaultY = parent.frame.minY - 35
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
            view.frame = NSMakeRect(5, view.superview!.frame.height - h, view.frame.width, h)
            view.updatePercent(percent)
        }
    }
    
    private func hold(animated: Bool) {
        
        chatInteraction.presentation.recordingState?.holdpromise.set(true)
        
        view.updateInside()
        
        let defaultY = parent.frame.minY - 35
        
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
        
        
        lockWindow.setFrame(NSMakeRect(lockWindow.frame.minX, lockWindow.frame.minY - 40, lockWindow.frame.width, lockWindow.frame.height), display: true, animate: animated)
        
        singleTimeControl.change(opacity: 1, animated: animated)
        
        //parent.removeChildWindow(lockWindow)
        
        lockControl.change(opacity: 0, animated: animated) { [weak self] _ in
          //  self?.lockWindow.orderOut(nil)
        }
    }
    
    private var lockControl: LockControl {
        return lockWindow.contentView!.subviews.first! as! LockControl
    }
    private var singleTimeControl: SingleTimeControl {
        return lockWindow.contentView!.subviews.last! as! SingleTimeControl
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
        
        guard let recorder = chatInteraction.presentation.recordingState else { return }
        
        
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
        
    }
    
    func hide(animated: Bool) {
        parent.removeChildWindow(window)
        parent.removeChildWindow(lockWindow)
        lockWindow.contentView?._change(opacity: 0, animated: true)
        var strongSelf:ChatRecorderOverlayWindowController? = self
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
