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
import SyncCore

enum CameraState : Equatable {
    case notInited
    case initializing
    case inited
}

final class OutgoingVideoView : Control {
    
    private var progressIndicator: ProgressIndicator? = nil
    
    var isMoved: Bool = false
    
    var updateAspectRatio:((Float)->Void)? = nil
    
    let _cameraInitialized: ValuePromise<CameraState> = ValuePromise(.notInited, ignoreRepeated: true)
    
    var cameraInitialized: Signal<CameraState, NoError> {
        return _cameraInitialized.get()
    }
    
    var firstFrameHandler:(()->Void)? = nil
    
    var videoView: (OngoingCallContextVideoView?, Bool)? {
        didSet {
            self._cameraInitialized.set(.initializing)
            if videoView?.1 == false {
                self.backgroundColor = .black
                if notAvailableView == nil {
                    let current = TextView()
                    self.notAvailableView = current
                    let text = L10n.callCameraUnavailable
                    let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(13), textColor: .white), bold: MarkdownAttributeSet(font: .bold(13), textColor: .white), link: MarkdownAttributeSet(font: .normal(13), textColor: .link), linkAttribute: { contents in
                        return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, { _ in
                            openSystemSettings(.camera)
                        }))
                    })).mutableCopy() as! NSMutableAttributedString
                    
                    let layout = TextViewLayout(attributedText, maximumNumberOfLines: 2, alignment: .center)
                    layout.interactions = globalLinkExecutor
                    current.isSelectable = false
                    current.update(layout)
                    
                    self.notAvailableView = current
                    addSubview(current, positioned: .below, relativeTo: overlay)
                    self._cameraInitialized.set(.inited)
                    self.firstFrameHandler?()
                }
            } else {
                if let videoView = videoView?.0 {
                    addSubview(videoView.view, positioned: .below, relativeTo: self.overlay)
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
                } else {
                    self._cameraInitialized.set(.notInited)
                }
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
            self.subviews.enumerated().forEach { _, view in
                if !(view is Control) {
                    view.removeFromSuperview()
                }
            }
            addSubview(view, positioned: .below, relativeTo: self.subviews.first)
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
            overlay.isEventLess = isEventLess
        }
    }
    
    static var defaultSize: NSSize = NSMakeSize(floor(100 * System.cameraAspectRatio), 100)
    
    enum ResizeDirection {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
    
    let overlay: Control = Control()
    
    
    private var disabledView: NSVisualEffectView?
    private var notAvailableView: TextView?
    
    
    private let maskLayer = CAShapeLayer()
    
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        super.addSubview(overlay)
        self.layer?.cornerRadius = .cornerRadius
        self.layer?.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        self.overlay.frame = bounds
        self.videoView?.0?.view.frame = bounds
        self.progressIndicator?.center()
        self.disabledView?.frame = bounds
        
        if let textView = notAvailableView {
            let layout = textView.layout
            layout?.measure(width: frame.width - 40)
            textView.update(layout)
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
                addSubview(current, positioned: .below, relativeTo: overlay)
                
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
    
    func updateFrame(_ frame: NSRect, animated: Bool) {
        if self.frame != frame {
            let duration: Double = 0.18
            
            self.videoView?.0?.view.subviews.first?._change(size: frame.size, animated: animated, duration: duration)
            self.videoView?.0?.view._change(size: frame.size, animated: animated, duration: duration)
            self.overlay._change(size: frame.size, animated: animated, duration: duration)
            self.progressIndicator?.change(pos: frame.focus(NSMakeSize(40, 40)).origin, animated: animated, duration: duration)
            
            self.disabledView?._change(size: frame.size, animated: animated, duration: duration)
            
            if let textView = notAvailableView, let layout = textView.layout {
                layout.measure(width: frame.width - 40)
                textView.update(layout)
                textView.change(pos: frame.focus(layout.layoutSize).origin, animated: animated, duration: duration)
            }
            self.change(size: frame.size, animated: animated)
            self.change(pos: frame.origin, animated: animated, duration: duration)
        }
        self.frame = frame
        updateCursorRects()
    }
    
    private func updateCursorRects() {
        resetCursorRects()
        if let cursor = NSCursor.set_windowResizeNorthEastSouthWestCursor {
            addCursorRect(NSMakeRect(0, frame.height - 10, 10, 10), cursor: cursor)
            addCursorRect(NSMakeRect(frame.width - 10, 0, 10, 10), cursor: cursor)
        }
        if let cursor = NSCursor.set_windowResizeNorthWestSouthEastCursor {
            addCursorRect(NSMakeRect(0, 0, 10, 10), cursor: cursor)
            addCursorRect(NSMakeRect(frame.width - 10, frame.height - 10, 10, 10), cursor: cursor)
        }
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
    var videoView: OngoingCallContextVideoView? {
        didSet {
            _cameraInitialized.set(.initializing)
            
            if let videoView = videoView {
                let isFullScreen = self.kitWindow?.isFullScreen ?? false
                videoView.setVideoContentMode(isFullScreen ? .resizeAspect : .resizeAspectFill)
                
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
                _cameraInitialized.set(.inited)
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
            let layout = textView.layout
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
            view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            view.layer?.animateScaleCenter(from: 0.2, to: 1.0, duration: 0.2)
        }
        _hidden = false
    }
    
    func hideView(animated: Bool) {
        if let view = self.videoView?.view, !_hidden {
            view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] completed in
                view?.removeFromSuperview()
                view?.layer?.removeAllAnimations()
            })
            view.layer?.animateScaleCenter(from: 1, to: 0.2, duration: 0.2)
        }
        _hidden = true
    }
    
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
}

