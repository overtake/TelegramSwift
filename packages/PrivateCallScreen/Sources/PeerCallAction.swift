//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 08.02.2024.
//

import Foundation
import AppKit
import TelegramMedia
import TGUIKit

struct PeerCallAction {
    var text: String?
    
    var normal: CGImage
    var activeImage: CGImage?
    var image: CGImage? {
        if active, interactive {
            return activeImage
        } else {
            return normal
        }
    }
    
    var active: Bool = false
    var loading: Bool = false
    var enabled: Bool = true
    var interactive: Bool = true
    
    var action:()->Void
}

private let actionSize = NSMakeSize(50, 50)


func makeNormalAction(_ image: NSImage) -> CGImage {
    let img = image._cgImage!
    return generateImage(actionSize, contextGenerator: { size, ctx in
        ctx.clear(size.bounds)
        ctx.round(size, size.height / 2)
        ctx.draw(img, in: size.bounds.focus(img.backingSize))
    })!
}



func makeActiveAction(_ image: NSImage) -> CGImage {
    let img = image._cgImage!
    return generateImage(actionSize, contextGenerator: { size, ctx in
        ctx.clear(size.bounds)
        ctx.round(size, size.height / 2)
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: size.bounds)
        
        ctx.clip(to: size.bounds.focus(img.backingSize), mask: img)
        
        ctx.setBlendMode(.clear)
        ctx.fill(size.bounds)
    })!
}

func makeAction(text: String, resource: ImageResource, active: Bool = false, enabled: Bool = true, loading: Bool = false, interactive: Bool = true, action: @escaping()->Void) -> PeerCallAction {
    let image = NSImage(resource: resource)
    return .init(text: text, normal: !interactive ? image._cgImage! : makeNormalAction(image), activeImage: !interactive ? nil : makeActiveAction(image), active: active, loading: loading, enabled: enabled, interactive: interactive, action: action)
}


final class PeerCallActionView : Control {
    private let imageLayer: SimpleLayer = SimpleLayer(frame: actionSize.bounds)
    private let backgroundLayer: SimpleLayer = SimpleLayer(frame: actionSize.bounds)
    private var normalBackground: SimpleLayer?
    private let backgroundView = NSVisualEffectView(frame: actionSize.bounds)
    private var textView: TextView?
    
    private var progressView: InfiniteProgressView?
    
    private var isLoading: Bool = false
    
    private var state: PeerCallAction?
    
    override init() {
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: actionSize.width, height: actionSize.height + 5 + 15)))

        imageLayer.contentsGravity = .center
        backgroundLayer.contentsGravity = .center
        
        backgroundView.wantsLayer = true
        backgroundView.material = .light
        backgroundView.state = .active
        backgroundView.blendingMode = .withinWindow
        
        backgroundView.layer?.addSublayer(backgroundLayer)
        
        
        if #available(macOS 10.15, *) {
            backgroundLayer.cornerCurve = .continuous
            imageLayer.cornerCurve = .continuous
        }

        
        imageLayer.cornerRadius = imageLayer.frame.height / 2
        backgroundLayer.cornerRadius = imageLayer.frame.height / 2
        backgroundView.layer?.cornerRadius = backgroundView.frame.height / 2
        
        addSubview(backgroundView)
        
        layer?.masksToBounds = false
        scaleOnClick = true
        
        set(handler: { [weak self] _ in
            if let state = self?.state {
                state.action()
            }
        }, for: .Click)
        
    }
    
    func updateLoading(_ isLoading: Bool, animated: Bool) {
        self.isLoading = isLoading
        if isLoading {
            let current: InfiniteProgressView
            if let view = progressView {
                current = view
            } else {
                current = InfiniteProgressView(color: NSColor.random, lineWidth: 2)
                self.progressView = current
                backgroundView.addSubview(current)
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.4)
                }
            }
            current.frame = backgroundView.bounds.insetBy(dx: 1, dy: 1)
        } else if let view = progressView {
            performSubviewRemoval(view, animated: animated)
            self.progressView = nil
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

    
    func updateEnabled(_ enabled: Bool, animated: Bool) {
        self.isEnabled = enabled
        
        change(opacity: enabled ? 1 : 0.7, animated: animated)
    }
    
    var size: NSSize {
        return backgroundView.frame.size
    }
    
    func update(_ data: PeerCallAction, animated: Bool) {
        
        let previousData = self.state
        self.state = data
        
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
            }
            let layout = TextViewLayout(.initialize(string: text, color: .white, font: .roundTimer(12)), maximumNumberOfLines: 1)
            layout.measure(width: 100)
            current.update(layout)
        } else if let textView = self.textView {
            performSubviewRemoval(textView, animated: animated)
            self.textView = nil
        }
        
        self.imageLayer.contents = data.image
        
        if data.active && data.activeImage != nil {
            backgroundView.layer?.mask = self.imageLayer
        } else {
            backgroundView.layer?.mask = nil
        }
        
        if previousData?.active != data.active {
            backgroundLayer.contents = data.image
        }
        
        if animated {
            backgroundLayer.animateContents()
        }
               
        updateLoading(data.loading, animated: animated)
        updateEnabled(data.enabled, animated: animated)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: backgroundView, frame: backgroundView.centerFrameX(y: 0))
        
        if let textView {
            transition.updateFrame(view: textView, frame: textView.centerFrameX(y: backgroundView.frame.maxY + 5))
        }
    }

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}
