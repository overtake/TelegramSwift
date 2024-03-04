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
    
    var string: String? {
        return textView.textLayout?.attributedString.string
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

struct PeerCallVideoViewState {
    var incomingView: MetalCallVideoView?
    var outgoingView: MetalCallVideoView?
    
    var incomingInited: Bool {
        return self.incomingView?.videoMetrics != nil
    }
    var outgoingInited: Bool {
        return self.outgoingView?.videoMetrics != nil
    }
    
    var smallVideoSize: NSSize {
        if let outgoingView, let metrics = outgoingView.videoMetrics {
            let targetSize = NSMakeSize(180, 180)
            return metrics.resolution.aspectFitted(targetSize)
        }
        return NSMakeSize(180, 100)
    }
}

final class PeerCallScreenView : Control {
    private let backgroundLayer: CallBackgroundLayer = .init()
    private let photoView = PeerCallPhotoView(frame: NSMakeRect(0, 0, 120, 120))
    private let statusView = PeerCallStatusView(frame: NSMakeRect(0, 0, 300, 58))
    
    
    private var arguments: Arguments?
    private var state: PeerCallState?
    
    private let actions = View()

    
    private var statusTooltip: InfoHelpView?
    
    private var secretView: SecretKeyView?
    private var revealedKey: PeerCallRevealedSecretKeyView?
    private var keyoverlay: Control?
    
    private var tooltipsViews: [PeerCallTooltipStatusView] = []
    private var tooltips: [PeerCallTooltipStatusView.TooltipType] = []
    
    private var videoViewState: PeerCallVideoViewState?
    
    
    private var actionsViews: [PeerCallActionView] = []
    private var actionsList: [PeerCallAction] = []
    
    private weak var videoLink_incoming:NSView?
    private weak var videoLink_outgoing:NSView?


    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer?.addSublayer(backgroundLayer)
        self.layer?.addSublayer(backgroundLayer.blurredLayer)
        
        addSubview(photoView)
        addSubview(statusView)
        
        addSubview(actions)
        
        actions.layer?.masksToBounds = false
        
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
        
        guard let state = self.state else {
            return
        }
        
        backgroundLayer.frame = size.bounds
        backgroundLayer.blurredLayer.frame = size.bounds
        
        self.backgroundLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(size.width), height: Int(size.height)), edgeInset: 0)
                
        
        transition.updateFrame(view: photoView, frame: photoView.centerFrameX(y: floorToScreenPixels(size.height / 3) - 50))
        photoView.updateLayout(size: photoView.frame.size, transition: transition)
        
        transition.updateFrame(view: statusView, frame: statusView.centerFrameX(y: photoView.frame.maxY + 32))
        statusView.updateLayout(size: statusView.frame.size, transition: transition)
        
        if let videoViewState {
            if let incomingVideoView = videoLink_incoming {
                transition.updateFrame(view: incomingVideoView, frame: size.bounds)
            }
            
            if let outgointVideoView = videoLink_outgoing {
                let videoSize = videoViewState.smallVideoSize
                transition.updateFrame(view: outgointVideoView, frame: CGRect(origin: NSMakePoint(size.width - videoSize.width - 10, size.height - videoSize.height - 10), size: videoSize))
            }
        }
        
        
        
        if let statusTooltip {
            transition.updateFrame(view: statusTooltip, frame: statusTooltipFrame(view: statusTooltip, state: state))
        }
        
        if let secretView {
            transition.updateFrame(view: secretView, frame: secretKeyFrame(view: secretView, state: state))
            secretView.updateLayout(size: secretView.frame.size, transition: transition)
        }
        
        if let revealedKey {
            transition.updateFrame(view: revealedKey, frame: revealedKeyFrame(view: revealedKey, state: state))
            revealedKey.updateLayout(size: revealedKey.frame.size, transition: transition)
        }
        if let keyoverlay {
            transition.updateFrame(view: keyoverlay, frame: size.bounds)
        }
        
        transition.updateFrame(view: actions, frame: NSMakeRect(0, size.height - 70 - 40, size.width, 70))
        

        
        let actions = self.actionsViews
        
        let width = actions.reduce(0, { $0 + $1.frame.width}) + 36 * CGFloat(actions.count - 1)
        
        var x = floorToScreenPixels((size.width - width) / 2)
        for action in actions {
            transition.updateFrame(view: action, frame: CGRect(origin: CGPoint(x: x, y: 0), size: action.frame.size))
            x += action.frame.width + 36
        }
        
        var y: CGFloat = size.height - 70 - 40
        for tooltip in tooltipsViews {
            y -= (tooltip.frame.height + 10)
            transition.updateFrame(view: tooltip, frame: tooltip.centerFrameX(y: y))
            tooltip.reveal(animated: transition.isAnimated)
        }
    }
    
    func updateState(_ state: PeerCallState, videoViewState: PeerCallVideoViewState, arguments: Arguments, transition: ContainedViewLayoutTransition) {
        self.state = state
        self.arguments = arguments
        self.videoViewState = videoViewState
        
        self.photoView.updateState(state, arguments: arguments, transition: transition)
        self.statusView.updateState(state, arguments: arguments, transition: transition)
        self.backgroundLayer.update(stateIndex: state.stateIndex, isEnergySavingEnabled: false, transition: transition)
        
        var videos: [NSView] = []
        
        if let incomingView = videoViewState.incomingView {
            if videoViewState.incomingInited {
                videos.append(incomingView)
            }
            videoLink_incoming = incomingView
        } else if let view = self.videoLink_incoming {
            performSubviewRemoval(view, animated: transition.isAnimated)
            self.videoLink_incoming = nil
        }
        
        if let outgoingView = videoViewState.outgoingView {
            if videoViewState.outgoingInited {
                videos.append(outgoingView)
                outgoingView.layer?.cornerRadius = 10
            }
            videoLink_outgoing = outgoingView
        } else if let view = self.videoLink_outgoing {
            performSubviewRemoval(view, animated: transition.isAnimated)
            self.videoLink_outgoing = nil
        }
        
        
            CATransaction.begin()
            for video in videos {
                video.removeFromSuperview()
            }
            if let index = self.subviews.firstIndex(of: self.actions) {
                self.subviews.insert(contentsOf: videos, at: index)
            }
            CATransaction.commit()

        
        if let tooltip = state.statusTooltip {
            if self.statusTooltip?.string != tooltip {
                if let statusTooltip = self.statusTooltip {
                    performSubviewRemoval(statusTooltip, animated: transition.isAnimated, scale: true)
                    self.statusTooltip = nil
                }
                
                let current: InfoHelpView
                let isNew = true
                current = InfoHelpView(frame: .zero)
                self.addSubview(current, positioned: .below, relativeTo: subviews.first)
                self.statusTooltip = current
                current.set(string: tooltip, hasShimm: true)
                
                if isNew {
                    ContainedViewLayoutTransition.immediate.updateFrame(view: current, frame: statusTooltipFrame(view: current, state: state))
                    if transition.isAnimated {
                        current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        current.layer?.animateScaleSpring(from: 0.01, to: 1, duration: 0.2, bounce: false)
                    }
                }
            }
        } else if let statusTooltip = self.statusTooltip {
            performSubviewRemoval(statusTooltip, animated: transition.isAnimated, scale: true)
            self.statusTooltip = nil
        }
        
        
        
        if state.secretKeyViewState == .revealed, let secretView {
            let current: PeerCallRevealedSecretKeyView
            let isNew: Bool
            if let view = self.revealedKey {
                current = view
                isNew = false
            } else {
                current = PeerCallRevealedSecretKeyView(frame: NSMakeRect(0, 0, 300, 300))
                self.addSubview(current, positioned: .below, relativeTo: secretView)
                self.revealedKey = current
                isNew = true
            }
            current.updateState(state, arguments: arguments, transition: isNew ? .immediate : transition)
            
            if isNew {
                ContainedViewLayoutTransition.immediate.updateFrame(view: current, frame: revealedKeyFrame(view: current, state: state))
                if transition.isAnimated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    current.layer?.animateScaleSpring(from: 0.8, to: 1, duration: 0.2, bounce: false)
                }
            }
            
            if "".isEmpty {
                let current: Control
                if let view = self.keyoverlay {
                    current = view
                } else {
                    current = Control(frame: bounds)
                    self.addSubview(current, positioned: .below, relativeTo: revealedKey)
                    self.keyoverlay = current
                    
                    current.set(handler: { [weak arguments] _ in
                        arguments?.toggleSecretKey()
                    }, for: .Click)
                }
                ContainedViewLayoutTransition.immediate.updateFrame(view: current, frame: bounds)
            }
            
            
        } else {
            if let revealedKey = self.revealedKey {
                performSubviewRemoval(revealedKey, animated: transition.isAnimated, scale: false)
                self.revealedKey = nil
            }
            if let keyoverlay = self.keyoverlay {
                performSubviewRemoval(keyoverlay, animated: transition.isAnimated, scale: false)
                self.keyoverlay = nil
            }
        }
        
        
        if let _ = state.secretKey {
            let current: SecretKeyView
            let isNew: Bool
            if let view = self.secretView {
                current = view
                isNew = false
            } else {
                current = SecretKeyView(frame: NSMakeRect(0, 0, 100, 25))
                self.addSubview(current, positioned: .above, relativeTo: revealedKey)
                self.secretView = current
                isNew = true
            }
            current.updateState(state, arguments: arguments, transition: isNew ? .immediate : transition)
            
            if isNew {
                ContainedViewLayoutTransition.immediate.updateFrame(view: current, frame: secretKeyFrame(view: current, state: state))
                if transition.isAnimated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    current.layer?.animateScaleSpring(from: 0.01, to: 1, duration: 0.2, bounce: false)
                }
            }
        } else if let secretView = self.secretView {
            performSubviewRemoval(secretView, animated: transition.isAnimated, scale: true)
            self.secretView = nil
        }
        
        do {
            var tooltips:[PeerCallTooltipStatusView.TooltipType] = []
            
            if state.externalState.isMuted, state.isActive {
                tooltips.append(.yourMicroOff)
            }
            if state.externalState.remoteAudioState == .muted, state.isActive {
                tooltips.append(.microOff(state.compactTitle))
            }
            
            let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.tooltips, rightList: tooltips)
            
            for deleteIndex in deleteIndices.reversed() {
                let view = self.tooltipsViews.remove(at: deleteIndex)
                performSubviewRemoval(view, animated: transition.isAnimated, scale: true)
            }
            for indicesAndItem in indicesAndItems {
                let view = PeerCallTooltipStatusView(frame: .zero)
                view.set(type: indicesAndItem.1)
                tooltipsViews.insert(view, at: indicesAndItem.0)
            }
            for updateIndex in updateIndices {
                let view = self.tooltipsViews[updateIndex.0]
                view.set(type: updateIndex.1)
            }
            CATransaction.begin()
            for view in self.tooltipsViews {
                view.removeFromSuperview()
            }
            self.subviews.insert(contentsOf: self.tooltipsViews, at: 0)
            CATransaction.commit()
            
            self.tooltips = tooltips
        }
        
        do {

            let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.actionsList, rightList: state.actions)
            
            var deletedViews: [Int: PeerCallActionView] = [:]
            
            for deleteIndex in deleteIndices.reversed() {
                let view = self.actionsViews.remove(at: deleteIndex)
                deletedViews[deleteIndex] = view
            }
            for indicesAndItem in indicesAndItems {
                let previous: PeerCallActionView?
                if let previousIndex = indicesAndItem.2 {
                    previous = deletedViews[previousIndex]
                    deletedViews.removeValue(forKey: previousIndex)
                } else {
                    previous = nil
                }
                let view = previous ?? PeerCallActionView()
                view.setFrameOrigin(actions.focus(view.frame.size).origin)
                view.update(indicesAndItem.1, animated: false)
                actionsViews.insert(view, at: indicesAndItem.0)
                if transition.isAnimated, indicesAndItem.2 == nil {
                    view.layer?.animateAlpha(from: 0, to: indicesAndItem.1.enabled ? 1.0 : 0.7, duration: 0.2)
                    view.layer?.animateScaleSpring(from: 0.01, to: 1, duration: 0.2, bounce: false)
                }
            }
            for updateIndex in updateIndices {
                let view = self.actionsViews[updateIndex.0]
                view.update(updateIndex.1, animated: transition.isAnimated)
            }
            
            for (_, view) in deletedViews {
                performSubviewRemoval(view, animated: transition.isAnimated, scale: true)
            }
            
            CATransaction.begin()
            for view in self.actionsViews {
                view.removeFromSuperview()
            }
            self.actions.subviews.insert(contentsOf: self.actionsViews, at: 0)
            CATransaction.commit()
            
            self.actionsList = state.actions
        }
    }
}





//RECT

extension PeerCallScreenView {
    func statusTooltipFrame(view: NSView, state: PeerCallState) -> NSRect {
        return view.centerFrameX(y: statusView.frame.maxY + 12)
    }
    func secretKeyFrame(view: NSView, state: PeerCallState) -> NSRect {
        if state.secretKeyViewState == .revealed {
            var rect = focus(NSMakeSize(200, 50))
            rect.origin.y -= 30
            return rect
        } else {
            var rect = focus(NSMakeSize(100, 25))
            rect.origin.y = 16
            return rect
        }
    }
    
    func revealedKeyFrame(view: NSView, state: PeerCallState) -> NSRect {
        return view.centerFrame()
    }
}
