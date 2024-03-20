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



private class ShadowView: View {
    
    
    public override init() {
        super.init(frame: .zero)
        setup()
    }
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var gradient: CAGradientLayer {
        return self.layer as! CAGradientLayer
    }
    
    private func setup() {
        self.layer = CAGradientLayer()
        update()
    }
    
    
    private func update() {
        let baseGradientAlpha: CGFloat = 1.0
        let numSteps = 8
        let firstStep = 1
        let firstLocation: CGFloat = 0
        let color = NSColor.black.withAlphaComponent(0.6)
        self.gradient.colors = (0 ..< numSteps).map { i in
            if i < firstStep {
                return color.cgColor
            } else {
                let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                let value: CGFloat = 1.0 - bezierPoint(0.42, 0.0, 0.58, 1.0, step)
                return color.withAlphaComponent(baseGradientAlpha * value).cgColor
            }
        }

        self.gradient.locations = (0 ..< numSteps).map { i -> NSNumber in
            if i < firstStep {
                return 0.0 as NSNumber
            } else {
                let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                return (firstLocation + (1.0 - firstLocation) * step) as NSNumber
            }
        }
    }
}



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
            let targetSize = NSMakeSize(190, 190)
            return metrics.resolution.aspectFitted(targetSize)
        }
        return NSMakeSize(190, 100)
    }
}

private enum VideoMagnify {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

final class PeerCallScreenView : Control {
    private let backgroundLayer: CallBackgroundLayer = .init()
    private var photoView: PeerCallPhotoView?
    private let statusView = PeerCallStatusView(frame: NSMakeRect(0, 0, 300, 58))
    
    private let settingsView = ImageButton()
    
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
    
    private weak var videoLink_large: MetalCallVideoView?
    private weak var videoLink_small: MetalCallVideoView?
    
    private var videoShadowView: ShadowView?
    private var videoBackgroundView: NSVisualEffectView?
    private var videoBackgroundView_color: View?
    
    private var videoMagnify: VideoMagnify = .bottomRight

    private var canAnimateAudioLevel = true
   
    
    private var processedInitialAudioLevelBump: Bool = false
    private var audioLevelBump: Float = 0.0
    
    private var currentAvatarAudioScale: CGFloat = 1.0
    private var targetAudioLevel: Float = 0.0
    private var audioLevel: Float = 0.0
    private var audioLevelUpdateSubscription: SharedDisplayLinkDriver.Link?



    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.layer?.addSublayer(backgroundLayer)
        self.layer?.addSublayer(backgroundLayer.blurredLayer)
        
        
        addSubview(actions)

        addSubview(statusView)
        
        settingsView.set(image: NSImage(resource: .icSettings).precomposed(.white), for: .Normal)
        settingsView.autohighlight = false
        settingsView.scaleOnClick = true
        settingsView.sizeToFit()
        
        addSubview(settingsView)
        
        actions.layer?.masksToBounds = false
        
        settingsView.set(handler: { [weak self] _ in
            self?.arguments?.openSettings()
        }, for: .SingleClick)
        
        updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.backgroundLayer.isInHierarchy = window != nil
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let window = newWindow as? Window {
            var start: NSPoint? = nil
            var initial: NSPoint? = nil
            window.set(mouseHandler: { [weak self] event in
                guard let self, let window = self.window, let control = self.videoLink_small else {
                    return .rejected
                }
                let startPoint = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                
                if NSPointInRect(startPoint, control.frame) {
                    start = startPoint
                    initial = startPoint
                } else {
                    start = nil
                    initial = nil
                }
                return .rejected
            }, with: self, for: .leftMouseDown)

            window.set(mouseHandler: { [weak self] event in
                
                guard let self, let startPoint = start, let control = self.videoLink_small else {
                    return .rejected
                }
                control.isMoving = true
                                    
                let current = self.convert(event.locationInWindow, from: nil)
                let difference = current - startPoint
                
                control.setFrameOrigin(control.frame.origin + difference)
                start = current
                
                return .rejected
                
            }, with: self, for: .leftMouseDragged)
            
            window.set(mouseHandler: { [ weak self] event in
                guard let self, let control = self.videoLink_small, let _ = start else {
                    return .rejected
                }
                let current = self.convert(event.locationInWindow, from: nil)
                
                start = nil
                control.isMoving = false
                
                
                if initial == current {
                    return .rejected
                }
                
                if current.x < frame.width / 2 {
                    if current.y > frame.height / 2 {
                        self.videoMagnify = .bottomLeft
                    } else {
                        self.videoMagnify = .topLeft
                    }
                } else {
                    if current.y > frame.height / 2 {
                        self.videoMagnify = .bottomRight
                    } else {
                        self.videoMagnify = .topRight
                    }
                }
                self.updateLayout(size: self.frame.size, transition: .animated(duration: 0.35, curve: .spring))
                
                return .invoked
            }, with: self, for: .leftMouseUp)
            
            self.audioLevelUpdateSubscription = SharedDisplayLinkDriver.shared.add { [weak self] _ in
                guard let self else {
                    return
                }
                self.attenuateAudioLevelStep()
            }

            
        } else {
            _window?.removeAllHandlers(for: self)
            self.audioLevelUpdateSubscription = nil
        }
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
        
        let hideOutside = (videoLink_large != nil) ? (!state.mouseInside && state.isActive) : false
        
        transition.updateFrame(view: settingsView, frame: CGRect.init(origin: CGPoint(x: size.width - settingsView.frame.width - 5, y: 5), size: settingsView.frame.size))
        transition.updateAlpha(view: settingsView, alpha: hideOutside ? 0 : 1)
        
        backgroundLayer.frame = size.bounds
        backgroundLayer.blurredLayer.frame = size.bounds
        
        self.backgroundLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(size.width), height: Int(size.height)), edgeInset: 0)
                
        if let photoView {
            transition.updateFrame(view: photoView, frame: photoView.centerFrameX(y: floorToScreenPixels(size.height / 3) - 50))
            photoView.updateLayout(size: photoView.frame.size, transition: transition)
        }
        
        if videoLink_large != nil {
            transition.updateFrame(view: statusView, frame: statusView.centerFrameX(y: 10))
            statusView.updateLayout(size: statusView.frame.size, transition: transition)
        } else if let photoView {
            transition.updateFrame(view: statusView, frame: statusView.centerFrameX(y: photoView.frame.maxY + 32))
            statusView.updateLayout(size: statusView.frame.size, transition: transition)
        }
        transition.updateAlpha(view: statusView, alpha: hideOutside ? 0 : 1)
        
        
        if let videoViewState {
//            let transition: ContainedViewLayoutTransition = transition.isAnimated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
            if let videoLink_large = videoLink_large {
                let frame = largeVideoFrame(view: videoLink_large, size: size, state: videoViewState)
                transition.updateFrame(view: videoLink_large, frame: frame)
                videoLink_large.updateLayout(size: frame.size, transition: transition)
            }
            
            if let videoLink_small = videoLink_small, !videoLink_small.isMoving {
                let frame = smallVideoFrame(view: videoLink_small, size: size, videoMagnify: self.videoMagnify, state: videoViewState)
                transition.updateFrame(view: videoLink_small, frame: frame)
                videoLink_small.updateLayout(size: frame.size, transition: transition)
            }
        }
        
        
        if let videoShadowView {
            transition.updateFrame(view: videoShadowView, frame: CGRect(origin: videoShadowView.frame.origin, size: NSMakeSize(size.width, videoShadowView.frame.height)))
            transition.updateAlpha(view: videoShadowView, alpha: hideOutside ? 0 : 1)
        }
        if let videoBackgroundView {
            transition.updateFrame(view: videoBackgroundView, frame: size.bounds)
        }
        if let videoBackgroundView_color {
            transition.updateFrame(view: videoBackgroundView_color, frame: size.bounds)
        }
        
        if let statusTooltip {
            transition.updateFrame(view: statusTooltip, frame: statusTooltipFrame(view: statusTooltip, state: state))
            transition.updateAlpha(view: statusTooltip, alpha: hideOutside ? 0 : 1)
        }
        
        if let secretView {
            transition.updateFrame(view: secretView, frame: secretKeyFrame(view: secretView, state: state, largeVideo: videoLink_large != nil))
            transition.updateAlpha(view: secretView, alpha: hideOutside ? 0 : 1)
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
            transition.updateAlpha(view: action, alpha: hideOutside ? 0 : 1)
            x += action.frame.width + 36
        }
        
        var y: CGFloat = size.height - 70 - 40
        for tooltip in tooltipsViews {
            y -= (tooltip.frame.height + 10)
            transition.updateFrame(view: tooltip, frame: tooltip.centerFrameX(y: y))
            transition.updateAlpha(view: tooltip, alpha: hideOutside ? 0 : 1)
            tooltip.reveal(animated: transition.isAnimated)
        }
    }
    
    func updateAudioLevel(_ value: Float) {
        if self.canAnimateAudioLevel {
            self.targetAudioLevel = min(1, value)
        } else {
            self.targetAudioLevel = 0.0
        }
    }
    
        
    private func attenuateAudioLevelStep() {
        self.audioLevel = self.audioLevel * 0.8 + (self.targetAudioLevel + self.audioLevelBump) * 0.2
        if self.audioLevel <= 0.01 {
            self.audioLevel = 0.0
        }
        self.updateAudioLevel()
    }
    
    private func updateAudioLevel() {
        if self.canAnimateAudioLevel, let photoView {
            let additionalAvatarScale = CGFloat(max(0.0, min(self.audioLevel, 5.0)) * 0.05)
            self.currentAvatarAudioScale = 1.0 + additionalAvatarScale
//            photoView.layer?.anchorPoint = NSMakePoint(0.5, 0.5)
//            photoView.layer?.transform = CATransform3DMakeScale(self.currentAvatarAudioScale, self.currentAvatarAudioScale, 1.0)
//            
            let blobAmplificationFactor: CGFloat = 2.0
            photoView.blobView.blob.transform = CATransform3DMakeScale(1.0 + additionalAvatarScale * blobAmplificationFactor, 1.0 + additionalAvatarScale * blobAmplificationFactor, 1.0)

        }
    }
        

    
    
    func updateState(_ state: PeerCallState, videoViewState: PeerCallVideoViewState, arguments: Arguments, transition: ContainedViewLayoutTransition) {
        self.state = state
        self.arguments = arguments
        self.videoViewState = videoViewState
        
        self.statusView.updateState(state, arguments: arguments, transition: transition)
        self.backgroundLayer.update(stateIndex: state.stateIndex, isEnergySavingEnabled: false, transition: transition)
        
        
        var smallVideo: MetalCallVideoView?
        var largeVideo: MetalCallVideoView?
        var largeInited: Bool
        var smallInited: Bool

        switch state.smallVideo {
        case .incoming:
            smallVideo = videoViewState.incomingView
            largeVideo = videoViewState.outgoingView
            largeInited = videoViewState.outgoingInited
            smallInited = videoViewState.incomingInited
        case .outgoing:
            smallVideo = videoViewState.outgoingView
            largeVideo = videoViewState.incomingView
            largeInited = videoViewState.incomingInited
            smallInited = videoViewState.outgoingInited
        }
        
        
        if let largeVideo = largeVideo {
            if largeInited {
                
                if transition.isAnimated, largeVideo.superview == nil {
                    let frame = largeVideoFrame(view: largeVideo, size: frame.size, state: videoViewState)
                    ContainedViewLayoutTransition.immediate.updateFrame(view: largeVideo, frame: frame)
                    largeVideo.updateLayout(size: frame.size, transition: .immediate)
                    largeVideo.layer?.animateAlpha(from: 0, to: 1, duration: transition.duration, timingFunction: transition.timingFunction)
                }
                addSubview(largeVideo, positioned: .below, relativeTo: self.videoLink_small ?? actions)

                largeVideo.layer?.cornerRadius = 0
                largeVideo.userInteractionEnabled = false

                videoLink_large = largeVideo

            } else {
                videoLink_large = nil
            }
        } else if let view = self.videoLink_large {
            if view != smallVideo && view != largeVideo {
                performSubviewRemoval(view, animated: transition.isAnimated)
            }
            self.videoLink_large = nil
        }
        
        if let smallVideo = smallVideo {
            if smallInited {
                
                if transition.isAnimated, smallVideo.superview == nil {
                    let frame = smallVideoFrame(view: smallVideo, size: frame.size, videoMagnify: self.videoMagnify, state: videoViewState)
                    ContainedViewLayoutTransition.immediate.updateFrame(view: smallVideo, frame: frame)
                    smallVideo.updateLayout(size: frame.size, transition: .immediate)
                    smallVideo.layer?.animateAlpha(from: 0, to: 1, duration: transition.duration, timingFunction: transition.timingFunction)
                }
                addSubview(smallVideo, positioned: .below, relativeTo: actions)

                smallVideo.layer?.cornerRadius = 10
                smallVideo.userInteractionEnabled = true

 
                videoLink_small = smallVideo
                
            } else {
                videoLink_small = nil
            }
        } else if let view = self.videoLink_small {
            if view != smallVideo && view != largeVideo {
                performSubviewRemoval(view, animated: transition.isAnimated)
            }
            self.videoLink_small = nil
        }
        
        
        if videoLink_large != nil {
            let current: ShadowView
            if let view = self.videoShadowView {
                current = view
            } else {
                current = ShadowView(frame: NSMakeRect(0, -50, frame.width, 160))
                addSubview(current, positioned: .below, relativeTo: self.statusView)
                self.videoShadowView = current
            }
        } else if let videoShadowView {
            performSubviewRemoval(videoShadowView, animated: transition.isAnimated)
            self.videoShadowView = nil
        }
        
        if let videoLink_large {
            let current: View
            if let view = self.videoBackgroundView_color {
                current = view
            } else {
                current = View(frame: self.bounds)
                addSubview(current, positioned: .below, relativeTo: videoLink_large)
                self.videoBackgroundView_color = current
            }
            current.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        } else if let videoBackgroundView_color {
            performSubviewRemoval(videoBackgroundView_color, animated: transition.isAnimated)
            self.videoBackgroundView_color = nil
        }
        
        if let videoLink_large {
            let current: NSVisualEffectView
            if let view = self.videoBackgroundView {
                current = view
            } else {
                current = NSVisualEffectView(frame: self.bounds)
                current.material = .dark
                current.state = .active
                current.blendingMode = .withinWindow
                current.wantsLayer = true
                addSubview(current, positioned: .below, relativeTo: videoLink_large)
                self.videoBackgroundView = current
            }
        } else if let videoBackgroundView {
            performSubviewRemoval(videoBackgroundView, animated: transition.isAnimated)
            self.videoBackgroundView = nil
        }
        
         if videoLink_large == nil {
             let current: PeerCallPhotoView
             if let view = self.photoView {
                 current = view
             } else {
                 current = PeerCallPhotoView(frame: NSMakeRect(0, 0, 120, 120))
                 addSubview(current, positioned: .below, relativeTo: self.subviews.first)
                 self.photoView = current
                 
                 ContainedViewLayoutTransition.immediate.updateFrame(view: current, frame: current.centerFrameX(y: floorToScreenPixels(frame.height / 3) - 50))
                 
                 if transition.isAnimated {
                     current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                     current.layer?.animateScaleSpring(from: 0.01, to: 1, duration: 0.2, bounce: false)
                 }
             }
             current.blobView.maskLayer = backgroundLayer.blurredLayer
             current.updateState(state, arguments: arguments, transition: transition)
         } else if let photoView {
             performSubviewRemoval(photoView, animated: transition.isAnimated, scale: true)
             self.photoView = nil
         }
         

        
        if let tooltip = state.statusTooltip {
            if self.statusTooltip?.string != tooltip {
                if let statusTooltip = self.statusTooltip {
                    performSubviewRemoval(statusTooltip, animated: transition.isAnimated, scale: true)
                    self.statusTooltip = nil
                }
                
                let current: InfoHelpView
                let isNew = true
                current = InfoHelpView(frame: .zero)
                self.addSubview(current)
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
            self.subviews.append(contentsOf: self.tooltipsViews)
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
        
        
        if state.secretKeyViewState == .revealed, let secretView {
            let current: PeerCallRevealedSecretKeyView
            let isNew: Bool
            if let view = self.revealedKey {
                current = view
                isNew = false
            } else {
                if let index = self.subviews.firstIndex(of: secretView) {
                    self.subviews.remove(at: index)
                    self.subviews.append(secretView)
                }
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
                ContainedViewLayoutTransition.immediate.updateFrame(view: current, frame: secretKeyFrame(view: current, state: state, largeVideo: videoLink_large != nil))
                if transition.isAnimated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    current.layer?.animateScaleSpring(from: 0.01, to: 1, duration: 0.2, bounce: false)
                }
            }
        } else if let secretView = self.secretView {
            performSubviewRemoval(secretView, animated: transition.isAnimated, scale: true)
            self.secretView = nil
        }
        
    }
}





//RECT

private extension PeerCallScreenView {
    func statusTooltipFrame(view: NSView, state: PeerCallState) -> NSRect {
        return view.centerFrameX(y: statusView.frame.maxY + 12)
    }
    func smallVideoFrame(view: MetalCallVideoView, size: NSSize, videoMagnify: VideoMagnify, state: PeerCallVideoViewState) -> NSRect {
        let videoSize = state.smallVideoSize
        let point: NSPoint
        switch videoMagnify {
        case .topLeft:
            point = NSMakePoint(10, 10)
        case .topRight:
            point = NSMakePoint(size.width - videoSize.width - 10, 10)
        case .bottomLeft:
            point = NSMakePoint(10, size.height - videoSize.height - 10)
        case .bottomRight:
            point = NSMakePoint(size.width - videoSize.width - 10, size.height - videoSize.height - 10)
        }
        return CGRect(origin: point, size: videoSize)
    }
    func largeVideoFrame(view: MetalCallVideoView, size: NSSize, state: PeerCallVideoViewState) -> NSRect {
        return size.bounds
    }
    func secretKeyFrame(view: NSView, state: PeerCallState, largeVideo: Bool) -> NSRect {
        if state.secretKeyViewState == .revealed {
            var rect = focus(NSMakeSize(200, 50))
            rect.origin.y -= 30
            return rect
        } else {
            var rect = focus(NSMakeSize(100, 25))
            if largeVideo {
                rect.origin.y = 10
                rect.origin.x = frame.width - rect.width - 10 - settingsView.frame.width
            } else {
                rect.origin.y = 10
            }
            return rect
        }
    }
    
    func revealedKeyFrame(view: NSView, state: PeerCallState) -> NSRect {
        return view.centerFrame()
    }
}
