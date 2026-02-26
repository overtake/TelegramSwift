//
//  GroupCallView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.04.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox


private final class NoStreamView : View {
    private let progressView = InfiniteProgressView(color: GroupCallTheme.customTheme.textColor, lineWidth: 2)
    private var textView: TextView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        progressView.setFrameSize(NSMakeSize(30, 30))
        addSubview(progressView)
        progressView.color = GroupCallTheme.customTheme.textColor
        self.progressView.progress = nil
    }
    
    func update(initialTimestamp: TimeInterval, title: String?, transition: ContainedViewLayoutTransition) {
        self.progressView.viewDidMoveToWindow()
        
        if Date().timeIntervalSince1970 - initialTimestamp > 10 {
            let current: TextView
            var isNew = false
            if let view = self.textView {
                current = view
            } else {
                current = TextView()
                current.isSelectable = false
                current.userInteractionEnabled = false
                self.textView = current
                addSubview(current)
                if transition.isAnimated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                isNew = true
            }
            let layout = TextViewLayout(.initialize(string: title == nil ? strings().voiceChatRTMPError : strings().voiceChatRTMPViewerError(title!), color: GroupCallTheme.customTheme.textColor, font: .normal(.text)), alignment: .center)
            layout.measure(width: frame.width)
            current.update(layout)
            
            if isNew {
                current.center()
            }
            updateLayout(size: frame.size, transition: transition)
        } else if let view = textView {
            performSubviewRemoval(view, animated: transition.isAnimated)
            self.textView = nil
        } else {
            delay(1, closure: { [weak self] in
                self?.update(initialTimestamp: initialTimestamp, title: title, transition: .animated(duration: 0.2, curve: .easeOut))
            })
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        if let textView = textView {
            transition.updateFrame(view: textView, frame: textView.centerFrameX(y: frame.height / 2 + 4))
            transition.updateFrame(view: progressView, frame: progressView.centerFrameX(y: frame.height / 2 - progressView.frame.height - 4))
        } else {
            transition.updateFrame(view: progressView, frame: focus(progressView.frame.size))
        }
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class GroupCallView : View {
    
    enum ControlsMode {
        case normal
        case invisible
    }
    
    private var controlsMode: ControlsMode = .normal

    let peersTable: TableView = TableView(frame: NSMakeRect(0, 0, 340, 329))
    
    let titleView: GroupCallTitleView = GroupCallTitleView(frame: NSMakeRect(0, 0, 380, 54))
    private let peersTableContainer: View = View(frame: NSMakeRect(0, 0, 340, 329))
    let controlsContainer: GroupCallControlsView
    
    private var scheduleView: GroupCallScheduleView?
    private(set) var tileView: GroupCallTileView?

    private var scrollView = ScrollView()
    
    private var speakingTooltipView: GroupCallSpeakingTooltipView?
    
    private var noStreamView: NoStreamView?
    
    private let visualBackgroundView = NSVisualEffectView()
    private let backgroundContainerView = View()
    
    private var secureEmojiView: GroupCallSecureEmojiView?
    private var secureVisualBackgroundView: Control?
    
    var arguments: GroupCallUIArguments? {
        didSet {
            controlsContainer.arguments = arguments
        }
    }
    
    private final class Content : View {
        
        var state: GroupCallUIState? {
            didSet {
                needsDisplay = true
            }
        }
        
        override func layout() {
            super.layout()
            needsDisplay = true
        }
        
        override func draw(_ layer: CALayer, in ctx: CGContext) {
            ctx.setFillColor(.clear)
            ctx.fill(bounds)
            var rect: CGRect = .zero
            if let state = self.state {
                switch state.mode {
                case .video:
                    if state.videoActive(.main).isEmpty || !state.isFullScreen {
                        rect = NSMakeRect(0, 54, min(frame.width - 40, 600), frame.height - 180)
                        rect.origin.x = focus(rect.size).minX
                    } else {
                        rect = NSMakeRect(5, 54, frame.width - 10, frame.height - 5 - 54)
                    }
                case .voice:
                    rect = NSMakeRect(0, 54, min(frame.width - 40, 600), frame.height - 271)
                    rect.origin.x = focus(rect.size).minX
                }
                if rect != .zero {
                    let path = CGMutablePath()
                    path.addRoundedRect(in: rect, cornerWidth: 10, cornerHeight: 10)
                    ctx.addPath(path)
                    ctx.clip()
                    ctx.clear(rect)
                }
            }
        }
    }
    
    private let content = Content()
    
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            var bp = 0
            bp += 1
        }
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        
        if superview == nil {
            var bp = 0
            bp += 1
        }
    }
    
    required init(frame frameRect: NSRect, callMode: GroupCallUIState.Mode) {
        controlsContainer = GroupCallControlsView(frame: .init(x: 0, y: 0, width: 360, height: 320), callMode: callMode)
        super.init(frame: frameRect)
        
        self.addSubview(visualBackgroundView)
        self.addSubview(backgroundContainerView)
        
        backgroundContainerView.backgroundColor = GroupCallTheme.windowBackground.withAlphaComponent(1.0)


        visualBackgroundView.wantsLayer = true
        visualBackgroundView.material = .ultraDark
        visualBackgroundView.blendingMode = .behindWindow
        visualBackgroundView.state = .active
        
        addSubview(scrollView)
        
        addSubview(peersTableContainer)
        addSubview(peersTable)
        
        peersTable.layer?.cornerRadius = 10
        peersTable.clipView.layer?.cornerRadius = 10
        peersTableContainer.layer?.cornerRadius = 10
        
        addSubview(content)

        addSubview(controlsContainer)
        addSubview(titleView)

        content.isEventLess = true
                
        scrollView.clipView._mouseDownCanMoveWindow = true
        scrollView._mouseDownCanMoveWindow = true
        
        scrollView.background = .clear
        scrollView.layer?.cornerRadius = 10
        peersTableContainer.layer?.cornerRadius = 10
        updateLocalizationAndTheme(theme: theme)
        
        peersTable._mouseDownCanMoveWindow = true
        
        peersTable.getBackgroundColor = {
            .clear
        }
        peersTable.addScroll(listener: TableScrollListener(dispatchWhenVisibleRangeUpdated: false, { [weak self] pos in
            guard let `self` = self else {
                return
            }
            self.peersTableContainer.frame = self.substrateRect()
        }))
        
        
        peersTable.applyExternalScroll = { [weak self] event in
            guard let strongSelf = self, !strongSelf.isFullScreen, let state = strongSelf.state else {
                return false
            }
            
            if state.videoActive(.main).isEmpty {
                return false
            }
            if state.pinnedData.focused != nil || state.pinnedData.permanent != nil {
                return false
            }
            
            let tileHeight = strongSelf.tileView?.frame.height ?? 0
            
            if tileHeight <= 280 {
                return false
            }
            if state.videoActive(.main).count == 1 {
                return false
            }
            if strongSelf.peersTable.documentOffset.y > 0 {
                return false
            }
            if strongSelf.peersTable.listHeight + strongSelf.videoRect.height < strongSelf.frame.height - 180 {
                return false
            }

            
            let local = strongSelf.scrollTempOffset
            
            var scrollTempOffset = local
            

            
            scrollTempOffset += -event.scrollingDeltaY
            
            
            strongSelf.scrollTempOffset = min(max(0, scrollTempOffset), strongSelf.videoRect.height + 5)

            strongSelf.updateLayout(size: strongSelf.frame.size, transition: .immediate)
            
            if strongSelf.tableRect.minY == strongSelf.titleView.frame.maxY {
                return false
            }
            
            return true
        }
        
        scrollView.applyExternalScroll = { [weak self] event in
            
            guard let strongSelf = self, let state = strongSelf.state, let tileView = strongSelf.tileView else {
                return false
            }
            
            if !state.isFullScreen {
                return strongSelf.peersTable.applyExternalScroll?(event) ?? false
            }
            
            let local = strongSelf.scrollTempOffset
            
            var scrollTempOffset = local
            
            scrollTempOffset += -event.scrollingDeltaY
            
            strongSelf.scrollTempOffset = min(max(0, scrollTempOffset), -(strongSelf.frame.height - tileView.frame.height - strongSelf.titleView.frame.height - 5))
            
            strongSelf.updateLayout(size: strongSelf.frame.size, transition: .immediate)

            
            return true
        }

        
        updateLayout(size: frame.size, transition: .immediate)
        
        
//        NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.contentView, queue: OperationQueue.main, using: { [weak self] notification in
//            let bounds = self?.scrollView.contentView.bounds
//            if bounds?.minY == 0 {
//                var bp = 0
//                bp += 1
//            }
//            NSLog("bounds: \(bounds)")
//        })
    }
    
    private func substrateRect() -> NSRect {
        var h = self.peersTable.listHeight
        if peersTable.documentOffset.y < 0 {
            h -= peersTable.documentOffset.y
        }
        var isVertical: Bool? = nil
        var offset: CGFloat = 0
        peersTable.enumerateItems(with: { item in
        
            if let item = item as? GroupCallParticipantRowItem {
                isVertical = item.isVertical
            }
            if isVertical == true {
                offset += item.height
            }
            if let item = item as? GroupCallTileRowItem {
                offset += item.height
            }
            return isVertical == nil || isVertical == true
        })
        h = min(h, self.peersTable.frame.height)
        h -= offset
        if h < 0 {
            offset = -h
            h = 0
        }
        
        let point = tableRect.origin + NSMakePoint(0, offset)
        return .init(origin: point, size: NSMakeSize(self.peersTable.frame.width, h))

    }
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        peersTableContainer.backgroundColor = GroupCallTheme.membersColor
//        backgroundColor = GroupCallTheme.windowBackground
        titleView.backgroundColor = .clear
    }
    
    func updateMouse(animated: Bool, isReal: Bool) {
        guard let window = self.window else {
            return
        }
        let location = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        
        var mode: ControlsMode
        let videoView = self.tileView
        if let videoView = videoView {
            if NSPointInRect(location, videoView.frame) && mouseInside() {
                if isReal && window.isKeyWindow {
                    mode = .normal
                } else {
                    mode = self.controlsMode
                }
            } else {
                mode = .invisible
            }
        } else {
            mode = .normal
        }
        
        if state?.state.networkState == .connecting {
            mode = .normal
        }
        
        let previousMode = self.controlsMode
        self.controlsMode = mode
        

       // if previousMode != mode {
            controlsContainer.change(opacity: mode == .invisible && isFullScreen && state?.controlsTooltip == nil ? 0 : 1, animated: animated)
            tileView?.updateMode(controlsMode: mode, controlsState: controlsContainer.mode, animated: animated)

    ///    }
    }
    
    func idleHide() {
        
        guard let window = self.window else {
            return
        }
        let location = window.mouseLocationOutsideOfEventStream
        
        let frame = controlsContainer.convert(controlsContainer.fullscreenBackgroundView.frame, to: nil)

        
        
        let hasVideo = tileView != nil
        let mode: ControlsMode = hasVideo && isFullScreen && !NSPointInRect(location, frame) ? .invisible :.normal
        let previousMode = self.controlsMode
        self.controlsMode = mode
        
        controlsContainer.change(opacity: mode == .invisible && isFullScreen && state?.controlsTooltip == nil ? 0 : 1, animated: true)
        
        
        
        var videosMode: ControlsMode
        if !isFullScreen {
            if NSPointInRect(location, frame) && mouseInside() {
                videosMode = .normal
            } else {
                videosMode = .invisible
            }
        } else {
            videosMode = mode
        }
        
            self.controlsMode = videosMode
        
        tileView?.updateMode(controlsMode: videosMode, controlsState: controlsContainer.mode, animated: true)

    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        
        
        let hasVideo = isFullScreen && (self.tileView != nil)
        
        let isVideo = controlsContainer.callMode == .video
        
        transition.updateFrame(view: backgroundContainerView, frame: size.bounds)
        transition.updateFrame(view: visualBackgroundView, frame: size.bounds)

        
        peersTableContainer.setFrameSize(NSMakeSize(substrateRect().width, peersTableContainer.frame.height))
        peersTable.setFrameSize(NSMakeSize(tableRect.width, peersTable.frame.height))
        
        transition.updateFrame(view: peersTable, frame: tableRect)

        transition.updateFrame(view: peersTableContainer, frame: substrateRect())
        if hasVideo {
            if isFullScreen, state?.hideParticipants == true {
                transition.updateFrame(view: controlsContainer, frame: controlsContainer.centerFrameX(y: size.height - controlsContainer.frame.height + 75))
            } else {
                transition.updateFrame(view: controlsContainer, frame: controlsContainer.centerFrameX(y: size.height - controlsContainer.frame.height + 75, addition: -peersTable.frame.width / 2))
            }
        } else {
            if isVideo {
                transition.updateFrame(view: controlsContainer, frame: controlsContainer.centerFrameX(y: size.height - controlsContainer.frame.height + 100))
            } else {
                transition.updateFrame(view: controlsContainer, frame: controlsContainer.centerFrameX(y: size.height - controlsContainer.frame.height + 50))
            }
        }
        
        let titleRect = NSMakeRect(0, 0, frame.width, 54)
        transition.updateFrame(view: titleView, frame: titleRect)
        titleView.updateLayout(size: titleRect.size, transition: transition)
        
        controlsContainer.updateLayout(size: controlsContainer.frame.size, transition: transition)
       
        if let tileView = self.tileView {
            let size = tileView.getSize(videoRect.size)
            var rect = videoRect
            if tileView.superview != self {
                rect = size.bounds
            }
            transition.updateFrame(view: tileView, frame: rect)
            tileView.updateLayout(size: rect.size, transition: transition)
    
        }
        let clipRect = videoRect.size.bounds
        var scrollRect = videoRect
        scrollRect.size.height += 5
        transition.updateFrame(view: scrollView.contentView, frame: clipRect)
        transition.updateFrame(view: scrollView, frame: scrollRect)
        
        transition.updateFrame(view: content, frame: bounds)
        
        
        if let scheduleView = self.scheduleView {
            let rect = tableRect
            transition.updateFrame(view: scheduleView, frame: rect)
            scheduleView.updateLayout(size: rect.size, transition: transition)
        }
        
        if let current = speakingTooltipView {
            let hasTable = isFullScreen && state?.hideParticipants == false
            transition.updateFrame(view: current, frame: current.centerFrameX(y: 60, addition: hasTable ? (-peersTable.frame.width / 2) : 0))
        }
        
        if let view = noStreamView {
            transition.updateFrame(view: view, frame: focus(view.frame.size))
            view.updateLayout(size: view.frame.size, transition: transition)
        }
        
        if let view = secureEmojiView {
            if self.state?.showConferenceKey == true {
                transition.updateFrame(view: view, frame: size.bounds.focus(view.frame.size))
            } else {
                transition.updateFrame(view: view, frame: size.bounds.focusX(view.frame.size, y: 52))
            }
            view.updateLayout(size: view.frame.size, transition: transition)
        }
        
        if let view = secureVisualBackgroundView {
            transition.updateFrame(view: view, frame: size.bounds)
        }
    }
    
    
    
    private var tableRect: NSRect {
        var size = peersTable.frame.size
        let width = min(frame.width - 40, 600)
        
        if let state = state {
            if !state.videoActive(.main).isEmpty {
                if isFullScreen {
                    size = NSMakeSize(GroupCallTheme.tileTableWidth, frame.height - 54 - 5)
                } else {
                    var videoHeight = max(160, frame.height - 180 - 200)
                    videoHeight -= (self.scrollTempOffset)
                    size = NSMakeSize(width, frame.height - 180 - max(0, videoHeight) - 5)
                }
            } else {
                switch controlsContainer.callMode {
                case .voice:
                    size = NSMakeSize(width, frame.height - 271)
                case .video:
                    size = NSMakeSize(width, frame.height - 180)
                }
            }
        }
        var rect = focus(size)
        rect.origin.y = 54
        
        if let state = state, !state.videoActive(.main).isEmpty {
            if !isFullScreen {
                rect.origin.y = videoRect.maxY + 5
            } else {
                rect.origin.x = frame.width - size.width - 5
                rect.origin.y = 54
                
                if state.hideParticipants {
                    rect.origin.x = (frame.width + 5)
                }
            }
        }
        
        if let state = state, state.isConference, isFullScreen || state.videoActive(.main).isEmpty {
            rect.origin.y += 40
            rect.size.height -= 40
        }
        
        return rect
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        let prevFullScreen = self.isFullScreen
        super.setFrameSize(newSize)
        
        if prevFullScreen != self.isFullScreen, let state = self.state {
            updateUIAfterFullScreenUpdated(state, reloadTable: false)
        }
    }
    
    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
        
        self.peersTable.beginTableUpdates()
        self.peersTable.layoutSubtreeIfNeeded()
        self.peersTable.endTableUpdates()
    }
    
    var isFullScreen: Bool {
        if let state = state {
            if state.isStream {
                return true
            }
            return state.isFullScreen
        }
        if frame.width >= GroupCallTheme.fullScreenThreshold {
            return true
        }
        return false
    }
    
    var videoRect: NSRect {
        var rect: CGRect
        if isFullScreen, let state = state {
            let tableWidth: CGFloat
            tableWidth = (GroupCallTheme.tileTableWidth + 20)
            
            if state.hideParticipants, isFullScreen {
                let width = frame.width - 10
                var height = frame.height - 5 - 54
                if let tileView = tileView {
                    height = tileView.getSize(NSMakeSize(width, height)).height
                }
                rect = CGRect(origin: .init(x: 5, y: 54 - scrollTempOffset), size: .init(width: width, height: height))
            } else {
                let width = frame.width - tableWidth + 5
                var height = frame.height - 5 - 54
                if let tileView = tileView {
                    height = tileView.getSize(NSMakeSize(width, height)).height
                }
                rect = CGRect(origin: .init(x: 5, y: 54 - scrollTempOffset), size: .init(width: width, height: height))
            }
            
        } else {
            let width = min(frame.width - 40, 600)
            
            var height = max(200, frame.height - 180 - 200)
            if let tileView = tileView {
                height = tileView.getSize(NSMakeSize(width, height)).height
            }
            rect = focus(NSMakeSize(width, height))
            rect.origin.y = 54 - scrollTempOffset
        }
        if let state, state.isConference {
            rect.origin.y = 94
            rect.size.height -= 40
        }
        return rect
    }
    
    var state: GroupCallUIState?
    
    var markWasScheduled: Bool? = false
    
    private var _scrollTempOffset: CGFloat = 0
    private var scrollTempOffset: CGFloat {
        get {
            if let state = state {
                if state.pinnedData.isEmpty {
                    return 0
                } else {
                    return _scrollTempOffset
                }
            }
            return 0
        }
        set {
            _scrollTempOffset = newValue
        }
    }
    
    private var saveScrollInset: (GroupCallTileView.Transition, CGPoint)?
    
    func applyUpdates(_ state: GroupCallUIState, _ tableTransition: TableUpdateTransition, _ call: PresentationGroupCall, animated: Bool) {
                
        let duration: Double = 0.3
        
        let previousState = self.state
        
        if previousState?.isFullScreen != state.isFullScreen {
            self.scrollTempOffset = 0
        }
        
        if let previousState = previousState {
            if let markWasScheduled = self.markWasScheduled, !state.state.canManageCall {
                if !markWasScheduled {
                    self.markWasScheduled = previousState.state.scheduleState != nil && state.state.scheduleState == nil
                }
                if self.markWasScheduled == true {
                    switch state.state.networkState {
                    case .connecting:
                        return
                    default:
                        self.markWasScheduled = nil
                    }
                }
               
            }
        }
        self.state = state
        titleView.update(state.peer, state, call.account, recordClick: { [weak self, weak state] in
            if let state = state {
                self?.arguments?.recordClick(state.state)
            }
        }, resizeClick: { [weak self] in
            self?.arguments?.toggleScreenMode()
        }, hidePeersClick: { [weak self] in
            self?.arguments?.togglePeersHidden()
        } , animated: animated)
        controlsContainer.update(state, voiceSettings: state.voiceSettings, audioLevel: state.myAudioLevel, animated: animated)
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: duration, curve: state.showConferenceKey != previousState?.showConferenceKey ? .spring : .easeOut) : .immediate
        
        if let _ = state.state.scheduleTimestamp {
            let current: GroupCallScheduleView
            if let view = self.scheduleView {
                current = view
            } else {
                current = GroupCallScheduleView(frame: tableRect)
                self.scheduleView = current
                addSubview(current)
            }
        } else {
            if let view = self.scheduleView {
                self.scheduleView = nil
                if animated {
                    view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                        view?.removeFromSuperview()
                    })
                    view.layer?.animateScaleSpring(from: 1, to: 0.1, duration: 0.3)
                } else {
                    view.removeFromSuperview()
                }
            }
        }
        scheduleView?.update(state, arguments: arguments, animated: animated)

        if animated {
            let from: CGFloat = state.state.scheduleTimestamp != nil ? 1 : 0
            let to: CGFloat = state.state.scheduleTimestamp != nil ? 0 : 1
            if previousState?.state.scheduleTimestamp != state.state.scheduleTimestamp {
                let remove: Bool = state.state.scheduleTimestamp != nil
                if !remove {
                    self.addSubview(peersTableContainer, positioned: .below, relativeTo: content)
                    self.addSubview(peersTable, positioned: .below, relativeTo: content)
                }
                self.peersTable.layer?.animateAlpha(from: from, to: to, duration: duration, removeOnCompletion: false, completion: { [weak self] _ in
                    if remove {
                        self?.peersTable.removeFromSuperview()
                        self?.peersTableContainer.removeFromSuperview()
                    }
                })
            }
        } else {
            if state.state.scheduleState != nil {
                peersTable.removeFromSuperview()
                peersTableContainer.removeFromSuperview()
            } else if peersTable.superview == nil {
                addSubview(peersTableContainer, positioned: .below, relativeTo: content)
                addSubview(peersTable, positioned: .below, relativeTo: content)
            }
        }
        
        if !state.videoActive(.main).isEmpty {
            let current: GroupCallTileView
            if let tileView = self.tileView {
                current = tileView
            } else {
                current = GroupCallTileView(call: call, arguments: arguments, frame: videoRect.size.bounds)
                self.tileView = current
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: duration)
                }
            }
            
            let _ = current.update(state: state, context: call.accountContext, transition: transition, size: videoRect.size, animated: animated, controlsMode: self.controlsMode)
                        
            self.addSubview(current, positioned: .below, relativeTo: content)
        } else {
            if let tileView = self.tileView {
                self.tileView = nil
                if animated {
                    tileView.layer?.animateAlpha(from: 1, to: 0, duration: duration, removeOnCompletion: false, completion: { [weak tileView] _ in
                        tileView?.removeFromSuperview()
                    })
                } else {
                    tileView.removeFromSuperview()
                }
            }
        }
        scrollView.isHidden = self.tileView == nil

        
        
        if previousState?.tooltipSpeaker != state.tooltipSpeaker {
            
            if let current = self.speakingTooltipView {
                self.speakingTooltipView = nil
                if animated {
                    current.layer?.animateAlpha(from: 1, to: 0, duration: duration, removeOnCompletion: false, completion: { [weak current] _ in
                        current?.removeFromSuperview()
                    })
                    current.layer?.animatePosition(from: current.frame.origin, to: current.frame.origin - NSMakePoint(0, 10), removeOnCompletion: false)
                } else {
                    current.removeFromSuperview()
                }
            }
            if let tooltipSpeaker = state.tooltipSpeaker {
                let current: GroupCallSpeakingTooltipView
                var presented = false
                if let speakingTooltipView = self.speakingTooltipView {
                    current = speakingTooltipView
                } else {
                    current = GroupCallSpeakingTooltipView(frame: .zero)
                    self.speakingTooltipView = current
                    addSubview(current)
                    if animated {
                        current.layer?.animateAlpha(from: 0, to: 1, duration: duration)
                    }
                    presented = true
                    
                    current.set(handler: { [weak self] _ in
                        if tooltipSpeaker.hasVideo {
                            self?.arguments?.focusVideo(tooltipSpeaker.videoEndpoint ?? tooltipSpeaker.presentationEndpoint)
                        }
                    }, for: .Click)
                }
                current.setPeer(data: tooltipSpeaker, account: call.account, audioLevel: arguments?.audioLevel ?? { _ in return nil })
                
                if presented {
                    let hasTable = isFullScreen && state.hideParticipants == false
                    current.setFrameOrigin(current.centerFrameX(y: 60, addition: hasTable ? (-peersTable.frame.width / 2) : 0).origin)
                    if animated {
                        current.layer?.animatePosition(from: current.frame.origin - NSMakePoint(0, 10), to: current.frame.origin)
                    }
                }
            }
        }
        
        if state.state.scheduleState == nil, state.isStream, state.videoActive(.main).isEmpty, let peer = state.peer {
            let current: NoStreamView
            if let view = self.noStreamView {
                current = view
            } else {
                current = NoStreamView(frame: focus(NSMakeSize(300, 300)))
                self.noStreamView = current
                addSubview(current)
            }
            current.update(initialTimestamp: state.initialTimestamp, title: !peer.groupAccess.isCreator ? peer.displayTitle : nil, transition: transition)
        } else if let view = noStreamView {
            performSubviewRemoval(view, animated: animated)
            self.noStreamView = nil
        }
        
        if state.isConference, state.showConferenceKey {
            let current: Control
            let isNew: Bool
            if let view = self.secureVisualBackgroundView {
                current = view
                isNew = false
            } else {
                current = Control(frame: .zero)
                self.secureVisualBackgroundView = current
                addSubview(current, positioned: .below, relativeTo: self.secureEmojiView)
                isNew = true
            }
            
            current.backgroundColor = NSColor.black.withAlphaComponent(0.8)
            
            current.setSingle(handler: { [weak self] _ in
                self?.arguments?.toggleShowConferenceKey(false)
            }, for: .Click)
            
            if isNew {
                current.frame = bounds
            }
            transition.updateFrame(view: current, frame: self.bounds)
            if isNew {
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
        } else if let view = self.secureVisualBackgroundView {
            performSubviewRemoval(view, animated: animated)
            self.secureVisualBackgroundView = nil
        }
        
        if state.isConference {
            let current: GroupCallSecureEmojiView
            let isNew: Bool
            if let view = self.secureEmojiView {
                current = view
                isNew = false
            } else {
                current = GroupCallSecureEmojiView(frame: .zero)
                self.secureEmojiView = current
                addSubview(current)
                isNew = true
            }
            let size = current.update(state, encryptionKeyEmoji: state.encryptionKeyEmoji, call.account, toggle: { [weak self] in
                self?.arguments?.toggleShowConferenceKey(!state.showConferenceKey)
            }, transition: isNew ? .immediate : transition)
            
            if isNew {
                current.setFrameSize(size)
                if state.showConferenceKey {
                    current.center()
                } else {
                    current.centerX(y: 52)
                }
            }
            let transition = isNew ? ContainedViewLayoutTransition.immediate : transition
            transition.updateFrame(view: current, frame: state.showConferenceKey ? self.bounds.focus(size) : self.bounds.focusX(size, y: 52))
            
            if isNew {
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
                }
            }
        } else if let view = self.secureEmojiView {
            performSubviewRemoval(view, animated: animated, scale: true)
            self.secureEmojiView = nil
        }
        
       
        
        content.state = state

        CATransaction.begin()
        if !tableTransition.isEmpty {
            peersTable.merge(with: tableTransition)
        }
        CATransaction.commit()
        
        updateLayout(size: frame.size, transition: transition)
        updateUIAfterFullScreenUpdated(state, reloadTable: false)

    }
    
    var isVertical: Bool {
        return isFullScreen && state?.dominantSpeaker != nil
    }
    
    private func updateUIAfterFullScreenUpdated(_ state: GroupCallUIState, reloadTable: Bool) {
        
        peersTable.layer?.cornerRadius = isVertical ? 0 : 10
                
        updateMouse(animated: false, isReal: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
}
