//
//  CameraViews.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14/08/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import TelegramVoip

enum CameraState : Equatable {
    case notInited
    case initializing
    case inited
}

final class OutgoingVideoView : Control {
    
    private var progressIndicator: ProgressIndicator? = nil
    private let videoContainer = Control()
    var isMirrored: Bool = false {
        didSet {
            CATransaction.begin()
            if isMirrored {
                let rect = videoContainer.bounds
                var fr = CATransform3DIdentity
                fr = CATransform3DTranslate(fr, rect.width / 2, 0, 0)
                fr = CATransform3DScale(fr, -1, 1, 1)
                fr = CATransform3DTranslate(fr, -(rect.width / 2), 0, 0)
                videoContainer.layer?.sublayerTransform = fr
            } else {
                videoContainer.layer?.sublayerTransform = CATransform3DIdentity
            }
           
            CATransaction.commit()
        }
    }
    
    var isMoved: Bool = false
    
    var updateAspectRatio:((Float)->Void)? = nil
    
    let _cameraInitialized: ValuePromise<CameraState> = ValuePromise(.notInited, ignoreRepeated: true)
    
    var cameraInitialized: Signal<CameraState, NoError> {
        return _cameraInitialized.get()
    }
    
    var firstFrameHandler:(()->Void)? = nil
    
    var videoView: (OngoingCallContextPresentationCallVideoView?, Bool)? {
        didSet {
            self._cameraInitialized.set(.initializing)
            if let value = videoView, let videoView = value.0 {
                
                videoView.setVideoContentMode(.resizeAspectFill)
                
                videoContainer.addSubview(videoView.view)
                videoView.view.frame = self.bounds
                videoView.view.layer?.cornerRadius = .cornerRadius
                
                let oldView = oldValue?.0?.view
                
                videoView.setOnFirstFrameReceived({ [weak self, weak oldView] aspectRatio in
                    guard let `self` = self else {
                        return
                    }
                    self._cameraInitialized.set(.inited)
                    if !self._hidden {
                        self.backgroundColor = .clear
                        oldView?.removeFromSuperview()
                        if let progressIndicator = self.progressIndicator {
                            self.progressIndicator = nil
                            progressIndicator.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak progressIndicator] _ in
                                progressIndicator?.removeFromSuperview()
                            })
                        }
                        self.updateAspectRatio?(aspectRatio)
                    }
                    self.firstFrameHandler?()
                })
                
                if !value.1 {
                    self._cameraInitialized.set(.inited)
                }
            } else {
                self._cameraInitialized.set(.notInited)
            }
            
            
            needsLayout = true
        }
    }
    
    private var _hidden: Bool = false
    
    var isViewHidden: Bool {
        return _hidden
    }
    
    func unhideView(animated: Bool) {
        if let view = videoView?.0?.view, _hidden {
            subviews.enumerated().forEach { _, view in
                if !(view is Control) {
                    view.removeFromSuperview()
                }
            }
            videoContainer.addSubview(view, positioned: .below, relativeTo: self.subviews.first)
            view.layer?.animateScaleCenter(from: 0.2, to: 1.0, duration: 0.2)
            view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        }
        _hidden = false
    }
    
    func hideView(animated: Bool) {
        if let view = self.videoView?.0?.view, !_hidden {
            view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] completed in
                view?.removeFromSuperview()
                view?.layer?.removeAllAnimations()
            })
            view.layer?.animateScaleCenter(from: 1, to: 0.2, duration: 0.2)
        }
        _hidden = true
    }
    
    override var isEventLess: Bool {
        didSet {
            self.userInteractionEnabled = !isEventLess
            //overlay.isEventLess = isEventLess
        }
    }
    
    
    
    static var defaultSize: NSSize = NSMakeSize(floor(100 * System.aspectRatio), 100)
    
    enum ResizeDirection {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
    
    let overlay: Control = Control()
    
    
    private var disabledView: NSVisualEffectView?
    private var notAvailableView: TextView?
    
    private var animation:DisplayLinkAnimator? = nil
        
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.overlay.forceMouseDownCanMoveWindow = true
        self.layer?.cornerRadius = .cornerRadius
        self.layer?.masksToBounds = true
        self.addSubview(videoContainer)
        self.addSubview(overlay)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        self.videoContainer.frame = bounds
        self.overlay.frame = bounds
        self.videoView?.0?.view.frame = bounds
        self.progressIndicator?.center()
        self.disabledView?.frame = bounds
        let isMirrored = self.isMirrored
        self.isMirrored = isMirrored

        if let textView = notAvailableView {
            textView.resize(frame.width - 40)
            textView.center()
        }
    }
    
    func setIsPaused(_ paused: Bool, animated: Bool) {
        if paused {
            if disabledView == nil {
                let current = NSVisualEffectView()
                current.material = .dark
                current.state = .active
                current.blendingMode = .withinWindow
                current.wantsLayer = true
                current.layer?.cornerRadius = .cornerRadius
                current.frame = bounds
                self.disabledView = current
                self.addSubview(current, positioned: .below, relativeTo: overlay)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            } else {
                self.disabledView?.frame = bounds
            }
        } else {
            if let disabledView = self.disabledView {
                self.disabledView = nil
                if animated {
                    disabledView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak disabledView] _ in
                        disabledView?.removeFromSuperview()
                    })
                } else {
                    disabledView.removeFromSuperview()
                }
            }
        }
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    private(set) var savedFrame: NSRect? = nil
    
    func updateFrame(_ frame: NSRect, animated: Bool) {
        if self.savedFrame != frame && animation == nil {
            let duration: Double = 0.15
            
            if animated {
                                
                let fromFrame = self.frame
                let toFrame = frame
                
                
                let animation = DisplayLinkAnimator(duration: duration, from: 0.0, to: 1.0, update: { [weak self] value in
                    let x = fromFrame.minX - (fromFrame.minX - toFrame.minX) * value
                    let y = fromFrame.minY - (fromFrame.minY - toFrame.minY) * value
                    let w = fromFrame.width - (fromFrame.width - toFrame.width) * value
                    let h = fromFrame.height - (fromFrame.height - toFrame.height) * value
                    let updated = NSMakeRect(x, y, w, h)
                    self?.frame = updated
                }, completion: { [weak self] in
                    guard let `self` = self else {
                        return
                    }
                    self.animation = nil
                    self.frame = frame
                    self.savedFrame = frame
                })
                self.animation = animation
            } else {
                self.frame = frame
                self.animation = nil
            }
        }
        updateCursorRects()
        savedFrame = frame
    }
    
    private func updateCursorRects() {

    }
    
    override func cursorUpdate(with event: NSEvent) {
        super.cursorUpdate(with: event)
        updateCursorRects()
    }
    
    func runResizer(at point: NSPoint) -> ResizeDirection? {
        let rects: [(NSRect, ResizeDirection)] = [(NSMakeRect(0, frame.height - 10, 10, 10), .bottomLeft),
                                                  (NSMakeRect(frame.width - 10, 0, 10, 10), .topRight),
                                                  (NSMakeRect(0, 0, 10, 10), .topLeft),
                                                  (NSMakeRect(frame.width - 10, frame.height - 10, 10, 10), .bottomRight)]
        for rect in rects {
            if NSPointInRect(point, rect.0) {
                return rect.1
            }
        }
        return nil
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return isEventLess
    }
}

final class IncomingVideoView : Control {
    
    var updateAspectRatio:((Float)->Void)? = nil
    
    let _cameraInitialized: ValuePromise<CameraState> = ValuePromise(.notInited, ignoreRepeated: true)
    
    var cameraInitialized: Signal<CameraState, NoError> {
        return _cameraInitialized.get()
    }
    
    var firstFrameHandler:(()->Void)? = nil
    
    private var disabledView: NSVisualEffectView?
    var videoView: OngoingCallContextPresentationCallVideoView? {
        didSet {
            _cameraInitialized.set(.initializing)
            
            if let videoView = videoView {

                addSubview(videoView.view, positioned: .below, relativeTo: self.subviews.first)
                videoView.view.background = .clear
                
                videoView.setOnFirstFrameReceived({ [weak self, weak oldValue] aspectRatio in
                    if let videoView = oldValue {
                        videoView.view.removeFromSuperview()
                    }
                    self?._cameraInitialized.set(.inited)
                    self?.videoView?.view.background = .black
                    self?.updateAspectRatio?(aspectRatio)
                    self?.firstFrameHandler?()
                })
            } else {
                _cameraInitialized.set(.notInited)
                self.firstFrameHandler?()
            }
            needsLayout = true
        }
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer?.cornerRadius = .cornerRadius
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        for subview in subviews {
            subview.frame = bounds
        }
        
        if let textView = disabledView?.subviews.first as? TextView {
            let layout = textView.textLayout
            layout?.measure(width: frame.width - 40)
            textView.update(layout)
            textView.center()
        }
    }
    
    func setIsPaused(_ paused: Bool, peer: TelegramUser?, animated: Bool) {
        if paused {
            if disabledView == nil {
                let current = NSVisualEffectView()
                current.material = .dark
                current.state = .active
                current.blendingMode = .withinWindow
                current.wantsLayer = true
                current.frame = bounds
                
                self.disabledView = current
                addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            } else {
                self.disabledView?.frame = bounds
            }
        } else {
            if let disabledView = self.disabledView {
                self.disabledView = nil
                if animated {
                    disabledView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak disabledView] _ in
                        disabledView?.removeFromSuperview()
                    })
                } else {
                    disabledView.removeFromSuperview()
                }
            }
        }
        needsLayout = true
    }
    
    private var _hidden: Bool = false
    
    var isViewHidden: Bool {
        return _hidden
    }
    
    func unhideView(animated: Bool) {
        if let view = videoView?.view, _hidden {
            self.subviews.enumerated().forEach { _, view in
                if !(view is Control) {
                    view.removeFromSuperview()
                }
            }
            addSubview(view, positioned: .below, relativeTo: self.subviews.first)
            view._change(opacity: 1, animated: animated)
//            view.layer?.animateScaleCenter(from: 0.2, to: 1.0, duration: 0.2)
        }
        _hidden = false
    }
    
    func hideView(animated: Bool) {
        if let view = self.videoView?.view, !_hidden {
            view._change(opacity: 1, animated: animated, removeOnCompletion: false, completion: { [weak view] completed in
                view?.removeFromSuperview()
                view?.layer?.removeAllAnimations()
            })
           // view.layer?.animateScaleCenter(from: 1, to: 0.2, duration: 0.2)
        }
        _hidden = true
    }
    
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
}

