//
//  CallControl.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 14/08/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

struct CallControlData {
    enum Mode: Equatable {
        case normal(NSColor, CGImage)
        case visualEffect(CGImage)
        case animated(LocalAnimatedSticker, NSColor)
    }
    
    let text: String?
    let mode: Mode
    let iconSize: NSSize
    
    func isProperView(_ view: NSView?) -> Bool {
        if view == nil {
            return false
        }
        switch mode {
        case .visualEffect:
            return view is NSVisualEffectView
        case .animated:
            return view is LottiePlayerView
        case .normal:
            return !(view is LottiePlayerView) && !(view is NSVisualEffectView)
        }
    }
}

final class CallControl : Control {
    private let imageView: ImageView = ImageView()
    private var imageBackgroundView:NSView? = nil
    private var textView: TextView?
    
    private var progressView: RadialProgressView?
    
    private var isLoading: Bool = false
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.imageView.isEventLess = true
    }
    
    func updateLoading(_ isLoading: Bool, animated: Bool) {
        self.isLoading = isLoading
        if isLoading {
            if progressView == nil {
                progressView = RadialProgressView(theme: RadialProgressTheme(backgroundColor: .clear, foregroundColor: .grayIcon), twist: true)
                
                addSubview(progressView!)
                
                if animated {
                    progressView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.4)
                }
            }
            let rect = imageBackgroundView?.bounds ?? NSMakeRect(0, 0, 40, 40)
            
            progressView?.frame = NSMakeRect(rect.minX + 1, rect.minY + 1, rect.width - 2, rect.height - 2)
            progressView?.state = .ImpossibleFetching(progress: 0.2, force: !animated)
        } else {
            if let progressView = self.progressView {
                self.progressView = nil
                progressView.state = .ImpossibleFetching(progress: 1.0, force: false)
                if animated {
                    progressView.layer?.animateAlpha(from: 1, to: 0, duration: 0.4, removeOnCompletion: false, completion: { [weak progressView] _ in
                        progressView?.removeFromSuperview()
                    })
                } else {
                    progressView.removeFromSuperview()
                }
            }
        }
    }
    
    override var isEnabled: Bool {
        get {
            return super.isEnabled && !isLoading
        }
        set {
            super.isEnabled = newValue
        }
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return false
    }
    private var previousState: ControlState?
    
    override func stateDidUpdate( _ state: ControlState) {
        switch controlState {
        case .Highlight:
            imageBackgroundView?._change(opacity: 0.9)
            textView?.change(opacity: 0.9)
            imageBackgroundView?.layer?.animateScaleCenter(from: 1, to: 0.95, duration: 0.2, removeOnCompletion: false)
        default:
            imageBackgroundView?._change(opacity: 1.0)
            textView?.change(opacity: 1.0)
            if let previousState = previousState, previousState == .Highlight {
                imageBackgroundView?.layer?.animateScaleCenter(from: 0.95, to: 1.0, duration: 0.2)
            }
        }
        previousState = state
    }
    
    func updateEnabled(_ enabled: Bool, animated: Bool) {
        self.isEnabled = enabled
        
        change(opacity: enabled ? 1 : 0.7, animated: animated)
    }
    
    var size: NSSize {
        return imageBackgroundView?.frame.size ?? frame.size
    }
    
    func updateWithData(_ data: CallControlData, animated: Bool) {
        
        if let text = data.text {
            let current: TextView
            if let textView = self.textView {
                current = textView
            } else {
                current = TextView()
                self.textView = current
                current.isSelectable = false
                current.userInteractionEnabled = false
                current.isEventLess = true
                addSubview(current)
                current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
            let layout = TextViewLayout(.initialize(string: text, color: .white, font: .normal(12)), maximumNumberOfLines: 1)
            layout.measure(width: max(data.iconSize.width, 100))
            current.update(layout)
        } else {
            if let textView = self.textView {
                self.textView = nil
                textView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak textView] _ in
                    textView?.removeFromSuperview()
                })
            }
        }
        
        switch data.mode {
        case let .visualEffect(icon):
            if !data.isProperView(self.imageBackgroundView) {
                self.imageBackgroundView?.removeFromSuperview()
                self.imageBackgroundView = NSVisualEffectView(frame: NSMakeRect(0, 0, data.iconSize.width, data.iconSize.height))
                self.imageBackgroundView?.wantsLayer = true
                self.addSubview(self.imageBackgroundView!)
            }
            let view = self.imageBackgroundView as! NSVisualEffectView
            
            view.material = .light
            view.state = .active
            view.blendingMode = .withinWindow
            
            imageView.isHidden = false
            imageView.animates = animated
            imageView.image = icon
            imageView.setFrameSize(data.iconSize)
            
        case let .normal(color, icon):
            if !data.isProperView(self.imageBackgroundView) {
                self.imageBackgroundView?.removeFromSuperview()
                self.imageBackgroundView = NSView(frame: NSMakeRect(0, 0, data.iconSize.width, data.iconSize.height))
                self.imageBackgroundView?.wantsLayer = true
                self.addSubview(self.imageBackgroundView!)
            }
            imageView.isHidden = false
            imageView.animates = animated
            imageView.image = icon
            imageView.setFrameSize(data.iconSize)
            
            self.imageBackgroundView?.background = color
        case let .animated(value, color):
            if !data.isProperView(self.imageBackgroundView) {
                self.imageBackgroundView?.removeFromSuperview()
                self.imageBackgroundView = LottiePlayerView(frame: NSMakeRect(0, 0, data.iconSize.width, data.iconSize.height))
                self.imageBackgroundView?.wantsLayer = true
                self.addSubview(self.imageBackgroundView!)
            }
            imageView.isHidden = true
            let player = self.imageBackgroundView as? LottiePlayerView
            if let animationData = value.data {
                let policy: LottiePlayPolicy
                if animated {
                    policy = .toEnd(from: 1)
                } else {
                    policy = .toEnd(from: .max)
                }
                player?.set(LottieAnimation(compressed: animationData, key: .init(key: .bundle(value.rawValue), size: data.iconSize), type: .lottie, cachePurpose: .none, playPolicy: policy, runOnQueue: .mainQueue()))
            }
            self.imageBackgroundView?.background = color
        }
        

        imageView.removeFromSuperview()
        self.imageBackgroundView?.addSubview(imageView)
        
        imageBackgroundView!._change(size: data.iconSize, animated: animated)
        imageBackgroundView!.layer?.cornerRadius = data.iconSize.height / 2
        
        
        if let textView = self.textView {
            change(size: NSMakeSize(max(data.iconSize.width, textView.frame.width), data.iconSize.height + 5 + textView.frame.height), animated: animated)
            
            imageView._change(pos: imageBackgroundView!.focus(imageView.frame.size).origin, animated: animated)
            textView._change(pos: NSMakePoint(floorToScreenPixels(backingScaleFactor, (frame.width - textView.frame.width) / 2), imageBackgroundView!.frame.height + 5), animated: animated)
            imageBackgroundView!._change(pos: NSMakePoint(floorToScreenPixels(backingScaleFactor, (frame.width - imageBackgroundView!.frame.width) / 2), 0), animated: animated)
        } else {
            change(size: data.iconSize, animated: animated)
            imageView._change(pos: imageBackgroundView!.focus(imageView.frame.size).origin, animated: animated)
            imageBackgroundView!._change(pos: focus(imageBackgroundView!.frame.size).origin, animated: animated)
        }
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        imageView.center()
        if let imageBackgroundView = imageBackgroundView {
            if let textView = textView {
                imageBackgroundView.centerX(y: 0)
                textView.setFrameOrigin(NSMakePoint(floorToScreenPixels(backingScaleFactor, (frame.width - textView.frame.width) / 2), imageBackgroundView.frame.height + 5))
            } else {
                imageBackgroundView.center()
            }
        }
        
    }

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
