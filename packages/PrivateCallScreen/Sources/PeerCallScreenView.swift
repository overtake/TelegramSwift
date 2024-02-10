//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 08.02.2024.
//

import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import CallVideoLayer
import TGUIKit
import MetalEngine
import AppKit

private final class InfoHelpView : NSVisualEffectView {
    
    private var shimmer: ShimmerLayer?
    private let textView = TextView()
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(textView)
        
        self.textView.userInteractionEnabled = false
        self.textView.isSelectable = false
        
        self.wantsLayer = true
        self.material = .light
        self.state = .active
        self.blendingMode = .withinWindow
    }
    
    func set(string: String, hasShimm: Bool = false) {
        let layout = TextViewLayout(.initialize(string: string, color: NSColor.white, font: .medium(.text)), alignment: .center)
        layout.measure(width: .greatestFiniteMagnitude)
        self.textView.update(layout)
        
        self.setFrameSize(NSMakeSize(layout.layoutSize.width + 20, layout.layoutSize.height + 10))
        
        self.layer?.cornerRadius = frame.height / 2
        if #available(macOS 10.15, *) {
            self.layer?.cornerCurve = .continuous
        } 
        
        if hasShimm {
            let current: ShimmerLayer
            if let local = self.shimmer {
                current = local
            } else {
                current = ShimmerLayer()
                current.isStatic = true
                current.frame = self.bounds
                self.shimmer = current
                self.layer?.addSublayer(current)
            }
            current.update(backgroundColor: nil, shimmeringColor: NSColor(0xffffff, 0.3), data: nil, size: self.frame.size, imageSize: self.frame.size)
            current.updateAbsoluteRect(self.bounds, within: self.frame.size)
        } else if let shimmer = self.shimmer {
            performSublayerRemoval(shimmer, animated: true)
        }
    }
    
    override func layout() {
        super.layout()
        textView.center()
        shimmer?.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


final class PeerCallScreenView : Control {
    private let backgroundLayer: CallBackgroundLayer = .init()
    private let photoView = PeerCallPhotoView(frame: NSMakeRect(0, 0, 120, 120))
    private let statusView: PeerCallStatusView = PeerCallStatusView(frame: NSMakeRect(0, 0, 300, 58))
    
    
    private var arguments: Arguments?
    private var state: PeerCallState?
    
    private var videoAction: PeerCallActionView? = PeerCallActionView()
    private var screencastAction: PeerCallActionView? = PeerCallActionView()
    private var muteAction: PeerCallActionView? = PeerCallActionView()
    private var endAction: PeerCallActionView? = PeerCallActionView()

    
    private var weakSignal: InfoHelpView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer?.addSublayer(backgroundLayer)
        self.layer?.addSublayer(backgroundLayer.blurredLayer)
        
        addSubview(photoView)
        addSubview(statusView)
        
        addSubview(videoAction!)
        addSubview(screencastAction!)
        addSubview(muteAction!)
        addSubview(endAction!)
        
        muteAction?.update(makeAction(text: "Mute", resource: .icMute), animated: false)
        videoAction?.update(makeAction(text: "Video", resource: .icVideo), animated: false)
        screencastAction?.update(makeAction(text: "Screen", resource: .icScreen), animated: false)
        endAction?.update(makeAction(text: "End Call", resource: .icDecline, interactive: false), animated: false)

        photoView.set(handler: { [weak self] _ in
            self?.arguments?.toggleAnim()
        }, for: .Click)
        
        updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.backgroundLayer.isInHierarchy = window != nil
        self.photoView.blobView.maskLayer = backgroundLayer.blurredLayer
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        backgroundLayer.frame = size.bounds
        backgroundLayer.blurredLayer.frame = size.bounds
        
        self.backgroundLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(size.width), height: Int(size.height)), edgeInset: 0)
                
        
        transition.updateFrame(view: photoView, frame: photoView.centerFrameX(y: 128))
        photoView.updateLayout(size: photoView.frame.size, transition: transition)
        
        transition.updateFrame(view: statusView, frame: statusView.centerFrameX(y: photoView.frame.maxY + 32))
        statusView.updateLayout(size: statusView.frame.size, transition: transition)
        
        
        if let weakSignal {
            transition.updateFrame(view: weakSignal, frame: weakSignal.centerFrameX(y: statusView.frame.maxY + 12))
        }

        let actions = [self.videoAction, self.screencastAction, self.muteAction, self.endAction].compactMap { $0 }
        
        let width = actions.reduce(0, { $0 + $1.frame.width}) + 36 * CGFloat(actions.count - 1)
        
        var x = floorToScreenPixels((size.width - width) / 2)
        for action in actions {
            transition.updateFrame(view: action, frame: CGRect(origin: CGPoint(x: x, y: size.height - action.frame.height - 40), size: action.frame.size))
            x += action.frame.width + 36
        }
    }
    
    func updateState(_ state: PeerCallState, arguments: Arguments, transition: ContainedViewLayoutTransition) {
        self.state = state
        self.arguments = arguments
        
        self.photoView.updateState(state, arguments: arguments, transition: transition)
        self.statusView.updateState(state, arguments: arguments, transition: transition)
        self.backgroundLayer.update(stateIndex: state.stateIndex, isEnergySavingEnabled: false, transition: transition)
        
        
        if let reception = state.reception, reception < 2 {
            let current: InfoHelpView
            let isNew: Bool
            if let view = self.weakSignal {
                current = view
                isNew = false
            } else {
                current = InfoHelpView(frame: .zero)
                self.addSubview(current)
                self.weakSignal = current
                isNew = true
            }
            current.set(string: "Weak network signal", hasShimm: true)
            
            if isNew {
                ContainedViewLayoutTransition.immediate.updateFrame(view: current, frame: current.centerFrameX(y: statusView.frame.maxY + 12))
                if transition.isAnimated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    current.layer?.animateScaleSpring(from: 0.01, to: 1, duration: 0.2, bounce: false)
                }
            }
        } else if let weakSignal = self.weakSignal {
            performSubviewRemoval(weakSignal, animated: transition.isAnimated, scale: true)
            self.weakSignal = nil
        }
    }
}
