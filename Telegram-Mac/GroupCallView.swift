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
    private var resizeMode: CALayerContentsGravity = .resizeAspect {
        didSet {
            mainVideoView?.currentResizeMode = resizeMode
        }
    }
    private let titleHeaderCap = View()
    let peersTable: TableView = TableView(frame: NSMakeRect(0, 0, 340, 329))
    
    let titleView: GroupCallTitleView = GroupCallTitleView(frame: NSMakeRect(0, 0, 380, 54))
    private let peersTableContainer: View = View(frame: NSMakeRect(0, 0, 340, 329))
    private let controlsContainer = GroupCallControlsView(frame: .init(x: 0, y: 0, width: 360, height: 320))
    
    private var mainVideoView: MainVideoContainerView? = nil
    
    private var scheduleView: GroupCallScheduleView?
    
    
    var arguments: GroupCallUIArguments? {
        didSet {
            controlsContainer.arguments = arguments
        }
    }
    
    override func viewDidMoveToWindow() {
        if window == nil {
            var bp:Int = 0
            bp += 1
        }
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(peersTableContainer)
        addSubview(peersTable)
        addSubview(titleView)
        addSubview(titleHeaderCap)
        addSubview(controlsContainer)
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
    }
    
    private func substrateRect() -> NSRect {
        var h = self.peersTable.listHeight
        if peersTable.documentOffset.y < 0 {
            h -= peersTable.documentOffset.y
        }
        h = min(h, self.peersTable.frame.height)
        return .init(origin:  tableRect.origin, size: NSMakeSize(self.peersTable.frame.width, h))

    }
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        peersTableContainer.backgroundColor = GroupCallTheme.membersColor
        backgroundColor = GroupCallTheme.windowBackground
        titleView.backgroundColor = .clear
        titleHeaderCap.backgroundColor = GroupCallTheme.windowBackground
    }
    
    func updateMouse(event: NSEvent, animated: Bool) {
        let isVertical = state?.currentDominantSpeakerWithVideo != nil
        
        let location = self.convert(event.locationInWindow, from: nil)
        
        let mode: ControlsMode
        if isVertical, let mainVideoView = self.mainVideoView {
            if NSPointInRect(location, mainVideoView.frame) {
                mode = .normal
            } else {
                mode = .invisible
            }
        } else {
            mode = .normal
        }
        
        
        let previousMode = self.controlsMode
        self.controlsMode = mode
        
        if previousMode != mode {
            controlsContainer.change(opacity: mode == .invisible && isFullScreen ? 0 : 1, animated: animated)
            titleView.change(opacity: mode == .invisible && isFullScreen ? 0 : 1, animated: animated)
            mainVideoView?.updateMode(controlsMode: mode, controlsState: controlsContainer.mode, animated: animated)
        }
    }
    
    func idleHide() {
        let isVertical = state?.currentDominantSpeakerWithVideo != nil
        let mode: ControlsMode = isVertical ? .invisible :.normal
        let previousMode = self.controlsMode
        self.controlsMode = mode
        
        if previousMode != mode {
            controlsContainer.change(opacity: mode == .invisible && isFullScreen ? 0 : 1, animated: true)
            titleView.change(opacity: mode == .invisible && isFullScreen ? 0 : 1, animated: true)
            mainVideoView?.updateMode(controlsMode: mode, controlsState: controlsContainer.mode, animated: true)
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        
        let isVertical = isFullScreen && state?.currentDominantSpeakerWithVideo != nil
        
        transition.updateFrame(view: peersTable, frame: tableRect)
        transition.updateFrame(view: peersTableContainer, frame: substrateRect())
        if isVertical {
            transition.updateFrame(view: controlsContainer, frame: controlsContainer.centerFrameX(y: frame.height - controlsContainer.frame.height + 100, addition: peersTable.frame.width / 2))
        } else {
            transition.updateFrame(view: controlsContainer, frame: controlsContainer.centerFrameX(y: frame.height - controlsContainer.frame.height + 50))
        }
        let titleRect = NSMakeRect(isVertical ? 100 : 0, 0, frame.width - (isVertical ? 100 : 0), isVertical ? 54 : 54)
        transition.updateFrame(view: titleView, frame: titleRect)
        titleView.updateLayout(size: titleRect.size, transition: transition)
        
        controlsContainer.updateLayout(size: controlsContainer.frame.size, transition: transition)
        if let mainVideoView = mainVideoView {
            transition.updateFrame(view: mainVideoView, frame: mainVideoRect)
            mainVideoView.updateLayout(size: mainVideoRect.size, transition: transition)
        }
        
        transition.updateFrame(view: titleHeaderCap, frame: NSMakeRect(0, 0, 100, 54))
        
        if let scheduleView = self.scheduleView {
            let rect = tableRect
            transition.updateFrame(view: scheduleView, frame: rect)
            scheduleView.updateLayout(size: rect.size, transition: transition)
        }
    }
    
    
    
    private var tableRect: NSRect {
        var size = peersTable.frame.size
        let width = min(frame.width - 40, 600)
        if let state = state, state.currentDominantSpeakerWithVideo != nil {
            if isFullScreen {
                size = NSMakeSize(80, frame.height - 54)
            } else {
                size = NSMakeSize(width, frame.height - round(width * 0.4) - 271 )
            }
        } else {
            size = NSMakeSize(width, frame.height - 271)
        }
        var rect = focus(size)
        rect.origin.y = 54
        
        if let state = state, state.currentDominantSpeakerWithVideo != nil {
            if !isFullScreen {
                rect.origin.y = mainVideoRect.maxY + 10
            } else {
                rect.origin.x = 10
                rect.origin.y = 54
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
        updateLayout(size: newSize, transition: .immediate)
    }
    
    var isFullScreen: Bool {
        if let tempVertical = tempFullScreen {
            return tempVertical
        }
        if frame.width >= fullScreenThreshold {
            return true
        }
        return false
    }
    
    private var mainVideoRect: NSRect {
        var rect: CGRect
        if isFullScreen {
            let width = frame.width - 100
            let height = frame.height
            rect = CGRect(origin: .init(x: 100, y: 0), size: .init(width: width, height: height))
        } else {
            let width = min(frame.width - 40, 600)
            rect = focus(NSMakeSize(width, width * 0.4))
            rect.origin.y = 54
        }
        return rect
    }
    
    var state: GroupCallUIState?
    
    var markWasScheduled: Bool? = false
    
    var tempFullScreen: Bool? = nil
    
    func applyUpdates(_ state: GroupCallUIState, _ transition: TableUpdateTransition, _ call: PresentationGroupCall, animated: Bool) {
                
        let duration: Double = 0.3
        
       
        let previousState = self.state
        if !transition.isEmpty {
            peersTable.merge(with: transition)
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

        
        titleView.update(state.peer, state, call.account, settingsClick: { [weak self] in
            self?.arguments?.settings()
        }, recordClick: { [weak self, weak state] in
            if let state = state {
                self?.arguments?.recordClick(state.state)
            }
        }, animated: animated)
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
        
        if let currentDominantSpeakerWithVideo = state.currentDominantSpeakerWithVideo {
            let mainVideo: MainVideoContainerView
            var isPresented: Bool = false
            if let video = self.mainVideoView {
                mainVideo = video
            } else {
                mainVideo = MainVideoContainerView(call: call, resizeMode: self.resizeMode)
                
                mainVideo.set(handler: { [weak self] control in
                    guard let `self` = self else {
                        return
                    }
                    switch self.resizeMode {
                    case .resizeAspect:
                        self.resizeMode = .resizeAspectFill
                    case .resizeAspectFill:
                        self.resizeMode = .resizeAspect
                    default:
                        break
                    }
                }, for: .DoubleClick)
                
                mainVideo.gravityButton.set(handler: { [weak self] control in
                    guard let `self` = self else {
                        return
                    }
                    self.arguments?.toggleScreenMode()
                }, for: .Click)
                
                self.mainVideoView = mainVideo
                addSubview(mainVideo, positioned: .below, relativeTo: titleView)
                isPresented = true
            }
            mainVideo.updatePeer(peer: currentDominantSpeakerWithVideo, transition: .immediate, controlsMode: self.controlsMode)
            
            if isPresented && animated {
                mainVideo.layer?.animateAlpha(from: 0, to: 1, duration: duration)
                 
                mainVideo.updateLayout(size: mainVideoRect.size, transition: .immediate)
                mainVideo.frame = mainVideoRect
                
                mainVideo.layer?.animateAlpha(from: 0, to: 1, duration: duration)
                

                peersTable.change(size: tableRect.size, animated: animated)
                peersTableContainer.change(size: substrateRect().size, animated: animated)

            }
        } else {
            if let mainVideo = self.mainVideoView{
                self.mainVideoView = nil
                if animated {
                    mainVideo.layer?.animateAlpha(from: 1, to: 0, duration: duration, removeOnCompletion: false, completion: { [weak mainVideo] _ in
                        mainVideo?.removeFromSuperview()
                    })
                    peersTable.change(size: tableRect.size, animated: animated)
                    peersTableContainer.change(size: substrateRect().size, animated: animated)

                } else {
                    mainVideo.removeFromSuperview()
                }
            }
        }

        self.mainVideoView?.updateMode(controlsMode: controlsMode, controlsState: controlsContainer.mode, animated: animated)
        
        updateLayout(size: frame.size, transition: transition)
        updateUIAfterFullScreenUpdated(state, reloadTable: false)

    }
    
    private func updateUIAfterFullScreenUpdated(_ state: GroupCallUIState, reloadTable: Bool) {
        let isVertical = isFullScreen && state.currentDominantSpeakerWithVideo != nil
        
        peersTableContainer.isHidden = isVertical
        peersTable.layer?.cornerRadius = isVertical ? 0 : 10
        
        mainVideoView?.layer?.cornerRadius = isVertical ? 0 : 10
        
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
