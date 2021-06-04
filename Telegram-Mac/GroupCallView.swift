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



final class GroupCallView : View {
    
    enum ControlsMode {
        case normal
        case invisible
    }
    
    private var controlsMode: ControlsMode = .normal

    let peersTable: TableView = TableView(frame: NSMakeRect(0, 0, 340, 329))
    
    let titleView: GroupCallTitleView = GroupCallTitleView(frame: NSMakeRect(0, 0, 380, 54))
    private let peersTableContainer: View = View(frame: NSMakeRect(0, 0, 340, 329))
    private let controlsContainer = GroupCallControlsView(frame: .init(x: 0, y: 0, width: 360, height: 320))
    
    private var scheduleView: GroupCallScheduleView?
    private(set) var tileView: GroupCallTileView?

    private var scrollView = ScrollView()
    
    private var speakingTooltipView: GroupCallSpeakingTooltipView?
    
    var arguments: GroupCallUIArguments? {
        didSet {
            controlsContainer.arguments = arguments
        }
    }
    
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(scrollView)
        addSubview(titleView)
        addSubview(peersTableContainer)
        addSubview(peersTable)
        addSubview(controlsContainer)
                
        scrollView.wantsLayer = true
        
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
        
        updateLayout(size: frame.size, transition: .immediate)
        
        
        NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.contentView, queue: OperationQueue.main, using: { [weak self] notification in
            let bounds = self?.scrollView.contentView.bounds
            if bounds?.minY == 0 {
                var bp = 0
                bp += 1
            }
            NSLog("bounds: \(bounds)")
        })
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
        backgroundColor = GroupCallTheme.windowBackground
        titleView.backgroundColor = .clear
    }
    
    func updateMouse(event: NSEvent, animated: Bool, isReal: Bool) {
        guard let window = self.window else {
            return
        }
        let location = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        
        var mode: ControlsMode
        let videoView = self.tileView
        if let videoView = videoView {
            if NSPointInRect(location, videoView.frame) && mouseInside() {
                if isReal {
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
        
        if previousMode != mode {
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
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        
        
        let hasVideo = isFullScreen && (self.tileView != nil)
        
        let isVideo = state?.mode == .video
        
        
        peersTableContainer.setFrameSize(NSMakeSize(substrateRect().width, peersTableContainer.frame.height))
        peersTable.setFrameSize(NSMakeSize(tableRect.width, peersTable.frame.height))
        
        transition.updateFrame(view: peersTable, frame: tableRect)

        transition.updateFrame(view: peersTableContainer, frame: substrateRect())
        if hasVideo {
            if isFullScreen, state?.hideParticipants == true {
                transition.updateFrame(view: controlsContainer, frame: controlsContainer.centerFrameX(y: frame.height - controlsContainer.frame.height + 75))
            } else {
                transition.updateFrame(view: controlsContainer, frame: controlsContainer.centerFrameX(y: frame.height - controlsContainer.frame.height + 75, addition: -peersTable.frame.width / 2))
            }
        } else {
            if isVideo {
                transition.updateFrame(view: controlsContainer, frame: controlsContainer.centerFrameX(y: frame.height - controlsContainer.frame.height + 100))
            } else {
                transition.updateFrame(view: controlsContainer, frame: controlsContainer.centerFrameX(y: frame.height - controlsContainer.frame.height + 50))
            }
        }
        
        let titleRect = NSMakeRect(0, 0, frame.width, 54)
        transition.updateFrame(view: titleView, frame: titleRect)
        titleView.updateLayout(size: titleRect.size, transition: transition)
        
        controlsContainer.updateLayout(size: controlsContainer.frame.size, transition: transition)
       
        if let tileView = self.tileView {
            let size = tileView.getSize(videoRect.size)
            let clipView = tileView.enclosingScrollView?.contentView as? TGClipView
            var offset = tileView.enclosingScrollView?.contentOffset ?? .zero
            transition.updateFrame(view: tileView, frame: size.bounds)
            tileView.updateLayout(size: size, transition: transition)
            
            
            let videoRect = isFullScreen ? self.videoRect : tableRect
            
            if case let .animated(duration, curve) = transition {
                if let current = self.currentTileTransition, let clipView = clipView {
                    if current.prevPinnedIndex == nil && current.pinnedIndex != nil {
                        clipView.layer?.animateBounds(from: CGRect(origin: offset, size: size), to: size.bounds, duration: duration, timingFunction: curve.timingFunction)
                    } else if let index = current.prevPinnedIndex, current.pinnedIndex == nil {
                        let tile = current.prevTiles[index]
                        offset = CGPoint(x: 0, y: max(0, min(tile.rect.midY - videoRect.height / 2, size.height - videoRect.height)))
                        if tile.rect.maxY > videoRect.height {
                            if offset != .zero {
                                clipView.scroll(to: offset)
                                clipView.layer?.animateBounds(from: size.bounds, to: CGRect(origin: offset, size: size), duration: duration, timingFunction: curve.timingFunction)
                            }
                        }
                    }
                }
            }
            
            self.currentTileTransition = nil
            
//            tileView.enclosingScrollView?.contentView.scroll(to: offset)

        }
        let clipRect = videoRect.size.bounds
        transition.updateFrame(view: scrollView.contentView, frame: clipRect)
        transition.updateFrame(view: scrollView, frame: videoRect)

        
        if let scheduleView = self.scheduleView {
            let rect = tableRect
            transition.updateFrame(view: scheduleView, frame: rect)
            scheduleView.updateLayout(size: rect.size, transition: transition)
        }
        
        if let current = speakingTooltipView {
            let hasTable = isFullScreen && state?.hideParticipants == false
            transition.updateFrame(view: current, frame: current.centerFrameX(y: 60, addition: hasTable ? (-peersTable.frame.width / 2) : 0))
        }
    }
    
    
    
    private var tableRect: NSRect {
        var size = peersTable.frame.size
        let width = min(frame.width - 40, 600)
        
        if let state = state, !state.videoActive(.main).isEmpty || state.mode == .video {
            if isFullScreen && !state.videoActive(.main).isEmpty {
                size = NSMakeSize(GroupCallTheme.tileTableWidth, frame.height - 54 - 5)
            } else {
                size = NSMakeSize(width, frame.height - 180)
            }
        } else {
            size = NSMakeSize(width, frame.height - 271)
        }
        var rect = focus(size)
        rect.origin.y = 54
        
        if let state = state, !state.videoActive(.main).isEmpty {
            if !isFullScreen {
                rect.origin.y = 54
            } else {
                rect.origin.x = frame.width - size.width - 5
                rect.origin.y = 54
                
                if state.hideParticipants {
                    rect.origin.x = (frame.width + 5)
                }
            }
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
    }
    
    var isFullScreen: Bool {
        if let state = state {
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
                let height = frame.height - 54 - 5
                rect = CGRect(origin: .init(x: 5, y: 54), size: .init(width: width, height: height))
            } else {
                let width = frame.width - tableWidth + 5
                let height = frame.height - 54 - 5
                rect = CGRect(origin: .init(x: 5, y: 54), size: .init(width: width, height: height))
            }
            
        } else {
            let width = min(frame.width - 40, 600)
            rect = focus(NSMakeSize(width, max(200, frame.height - 180 - 200)))
            rect.origin.y = 54
        }
        return rect
    }
    
    var state: GroupCallUIState?
    
    var markWasScheduled: Bool? = false
    
    var tempFullScreen: Bool? = nil
    
    private var currentTileTransition: GroupCallTileView.Transition?
    
    func applyUpdates(_ state: GroupCallUIState, _ tableTransition: TableUpdateTransition, _ call: PresentationGroupCall, animated: Bool) {
                
        let duration: Double = 0.3
        
       
        let previousState = self.state
        
        
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
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: duration, curve: .easeInOut) : .immediate
        
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
                    self.addSubview(peersTableContainer)
                    self.addSubview(peersTable)
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
                addSubview(peersTableContainer)
                addSubview(peersTable)
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
            
            let transition = current.update(state: state, transition: transition, size: videoRect.size, animated: animated, controlsMode: self.controlsMode)
            
            self.currentTileTransition = transition
            
            
            if state.isFullScreen {
                if scrollView.documentView != self.tileView {
                    scrollView.documentView = self.tileView
                }
            } else {
                scrollView.documentView = nil
            }

        } else {
            if let tileView = self.tileView {
                self.tileView = nil
                if animated {
                    tileView.layer?.animateAlpha(from: 1, to: 0, duration: duration, removeOnCompletion: false, completion: { [weak tileView, weak scrollView] _ in
                        tileView?.removeFromSuperview()
                        if scrollView?.documentView == tileView {
                            scrollView?.documentView = nil
                        }
                    })
                } else {
                    tileView.removeFromSuperview()
                    scrollView.documentView = nil
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
        
        if !tableTransition.isEmpty {
            peersTable.merge(with: tableTransition)
        }
        
        updateLayout(size: frame.size, transition: transition)
        updateUIAfterFullScreenUpdated(state, reloadTable: false)

    }
    
    var isVertical: Bool {
        return isFullScreen && state?.dominantSpeaker != nil
    }
    
    private func updateUIAfterFullScreenUpdated(_ state: GroupCallUIState, reloadTable: Bool) {
        
        peersTable.layer?.cornerRadius = isVertical ? 0 : 10
                
        if let event = NSApp.currentEvent {
            updateMouse(event: event, animated: false, isReal: false)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
