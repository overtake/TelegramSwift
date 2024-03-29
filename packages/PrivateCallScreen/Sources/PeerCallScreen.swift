//
//  PeerCallScreen.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08.02.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import CallVideoLayer
import TGUIKit
import MetalEngine
import AppKit
import KeyboardKey
import TelegramMedia
import Localization

protocol CallViewUpdater {
    func updateState(_ state: PeerCallState, arguments: Arguments, transition: ContainedViewLayoutTransition)
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition)
}

public final class PeerCallScreen : ViewController {
    private var external: PeerCallArguments
    private let screen: Window
    
    private let actionsDisposable = DisposableSet()
    private let audioLevelDisposable = MetaDisposable()
    
    public var onCompletion: (()->Void)? = nil
    
    public var contextObject: Any?
    
    private var videoViewState: PeerCallVideoViewState = .init()

    
    private let statePromise = ValuePromise<PeerCallState>(ignoreRepeated: true)
    private let stateValue = Atomic<PeerCallState>(value: .init())
    private func updateState(_ f: (PeerCallState) -> PeerCallState) {
        statePromise.set(stateValue.modify (f))
    }
    
    
    public func update(arguments: PeerCallArguments) {
        self.external = arguments
        self.updateAudioLevel()
    }
    
    
    public init(external: PeerCallArguments) {
        self.external = external
        let size = NSMakeSize(720, 560)
        if let screen = NSScreen.main {
            self.screen = Window(contentRect: NSMakeRect(floorToScreenPixels((screen.frame.width - size.width) / 2), floorToScreenPixels((screen.frame.height - size.height) / 2), size.width, size.height), styleMask: [.fullSizeContentView, .borderless, .resizable, .miniaturizable, .titled, .closable], backing: .buffered, defer: true, screen: screen)
            self.screen.minSize = size
            self.screen.isOpaque = true
            self.screen.backgroundColor = .black
            self.screen.titlebarAppearsTransparent = true
            self.screen.isMovableByWindowBackground = true
            self.screen.isReleasedWhenClosed = false
        } else {
            fatalError("screen not found")
        }
        super.init()
        actionsDisposable.add(audioLevelDisposable)
        self.updateAudioLevel()
    }
    
    private func updateAudioLevel() {
        audioLevelDisposable.set((external.audioLevel() |> deliverOnMainQueue).start(next: { [weak self] level in
            self?.genericView.updateAudioLevel(level)
        }))
    }
    
    public func setState(_ signal: Signal<ExternalPeerCallState, NoError>) {
        actionsDisposable.add((signal |> deliverOnMainQueue).start(next: { [weak self] external in
            
            var actions: [PeerCallAction] = []
            
            let disableEverything: Bool
            switch external.state {
            case .terminating, .terminated:
                disableEverything = true
            default:
                disableEverything = false
            }
            
            let videoEnabled: Bool
            switch external.state {
            case .reconnecting, .active:
                videoEnabled = !external.canBeRemoved
            default:
                videoEnabled = false
            }
            
            var redial: Bool = false
            switch external.state {
            case let .terminated(reason):
                redial = reason?.recall ?? false
            default:
                break
            }
            
            let muteEnabled = !external.canBeRemoved && !disableEverything && !redial
            let endEnabled = !external.canBeRemoved

            
            
            var isActive: Bool = false
            switch external.state {
            case .active, .reconnecting, .connecting, .requesting:
                isActive = !external.canBeRemoved
            default:
                break
            }
            
            switch external.videoState {
            case .notAvailable:
                break
            default:
                
                switch external.state {
                case .ringing:
                    break
                default:
                    if !redial {
                        actions.append(makeAction(type: .video, text: L10n.callVideo, resource: .icVideo, active: external.videoState == .active(true) && !external.isScreenCapture, enabled: videoEnabled, action: { [weak self] in
                            self?.external.toggleCamera(external)
                        }))
                        actions.append(makeAction(type: .video, text: L10n.callScreen, resource: .icScreen, active: external.videoState == .active(true) && external.isScreenCapture, enabled: videoEnabled, action: {
                            self?.external.toggleScreencast(external)
                        }))
                    }
                }
            }
  
            actions.append(makeAction(type: .mute, text: L10n.callMute, resource: .icMute, active: external.isMuted && isActive, enabled: muteEnabled, action: {
                self?.external.toggleMute()
            }))
            switch external.state {
            case .ringing:
                actions.append(makeAction(type: .accept, text: L10n.callAccept, resource: .icAccept, interactive: true, attract: true, action: {
                    self?.external.acceptcall()
                }))
            default:
                break
            }
            
            if redial {
                actions.append(makeAction(type: .redial, text: L10n.callRecall, resource: .icRedial, interactive: true, attract: false, action: {
                    self?.external.recall()
                }))
            }
            
            actions.append(makeAction(type: .mute, text: L10n.callEnd, resource: .icDecline, enabled: endEnabled, interactive: true, action: {
                self?.external.endcall(external)
            }))
            
            
            self?.updateState { current in
                var current = current
                current.externalState = external
                current.actions = actions
                return current
            }
        }))
    }
    
    public override func viewClass() -> AnyClass {
        return PeerCallScreenView.self
    }
    
    private var genericView: PeerCallScreenView {
        return self.view as! PeerCallScreenView
    }
    
    public override var window: Window? {
        return screen
    }
        
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let updateState: ((PeerCallState) -> PeerCallState) -> Void = { [weak self] f in
            guard let self else {
                return
            }
            statePromise.set(stateValue.modify (f))
        }
        
        
        let arguments = Arguments(toggleSecretKey: {
            updateState { current in
                var current = current
                if current.secretKey != nil {
                    current.secretKeyViewState = current.secretKeyViewState.rev
                } else {
                    current.secretKeyViewState = .concealed
                }
                return current
            }
        }, makeAvatar: { [weak self] view, peerId in
            return self?.external.makeAvatar(view, peerId)
        }, openSettings: { [weak self] in
            guard let self else {
                return
            }
            self.external.openSettings(self.screen)
        })
        
        
        var first: Bool = true
        
        actionsDisposable.add((statePromise.get() |> deliverOnMainQueue).start(next: { [weak self] state in
            self?.applyState(state, arguments: arguments, animated: !first)
            first = false
        }))
        
        struct TooltipTuple : Equatable {
            let lowSignal: Bool
            let lowBattery: Bool
            
            var isEmpty: Bool {
                return !lowSignal && !lowBattery
            }
            
            func take(_ index: Int, state: PeerCallState) -> String {
                
                if index == 0 {
                    return L10n.callToastWeakNetwork
                }
                if index == 1 {
                    return L10n.callToastLowBattery(state.compactTitle) 
                }
                return ""
            }
            var indexes: [Int] {
                var indexes: [Int] = []
                if lowSignal {
                    indexes.append(0)
                }
                if lowBattery {
                    indexes.append(1)
                }
                return indexes
            }
        }
        
        let statusTooltip: Signal<TooltipTuple, NoError> =  statePromise.get() |> map {
            .init(lowSignal: $0.reception != nil && $0.reception! < 2 && $0.seconds > 4, lowBattery: $0.externalState.remoteBatteryLevel == .low)
        } |> distinctUntilChanged
        
        
        let recursiveDisposable = MetaDisposable()
        
        actionsDisposable.add(recursiveDisposable)
        
        actionsDisposable.add(statusTooltip.start(next: { tooltip in
            DispatchQueue.main.async {
                if tooltip.isEmpty {
                    updateState { current in
                        var current = current
                        current.statusTooltip = nil
                        return current
                    }
                    recursiveDisposable.set(nil)
                } else {
                    let recursive = Signal<Void, NoError>.single(Void()) |> then(.single(Void()) |> suspendAwareDelay(4, queue: .mainQueue()) |> restart)
                    
                    
                    let indexes: [Int] = tooltip.indexes
                    var index: Int = 0

                    
                    recursiveDisposable.set(recursive.start(next: {
                        updateState { current in
                            var current = current
                            current.statusTooltip = tooltip.take(indexes[index], state: current)
                            return current
                        }
                        
                        index += 1
                        if index == indexes.count {
                            index = 0
                        }
                    }))
                }
                
            }
        }))
        
        let peer = external.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: external.peerId)) |> deliverOnMainQueue
        let accountPeer = external.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: external.engine.account.peerId)) |> deliverOnMainQueue
        
        actionsDisposable.add(combineLatest(peer, accountPeer).start(next: { [weak self] peer, accountPeer in
            self?.updateState { current in
                var current = current
                current.peer = peer
                current.accountPeer = accountPeer
                return current
            }
        }))
        
        let invokeEsc:(NSEvent)->KeyHandlerResult = { [weak self] event in
            guard let self else {
                return .rejected
            }
            let keyIsShown = self.stateValue.with { $0.secretKeyViewState == .revealed }
            if keyIsShown {
                arguments.toggleSecretKey()
                return .invoked
            } else if event.keyCode == KeyboardKey.Space.rawValue || event.keyCode == KeyboardKey.Return.rawValue {
                arguments.toggleSecretKey()
                return .invoked
            }
            
            
            return .rejected
        }
        
        screen.set(handler: invokeEsc, with: self, for: .Escape)
        screen.set(handler: invokeEsc, with: self, for: .Space)
        screen.set(handler: invokeEsc, with: self, for: .Return)
        
        
        let updateMouse:(NSEvent)->KeyHandlerResult = { [weak self] event in
            guard let self else {
                return .rejected
            }
            let mouseInside = self.stateValue.with { $0.mouseInside }
            let screenLocation = self.screen.convertToScreen(CGRect(origin: event.locationInWindow, size: self.screen.frame.size))
            let updatedMouseInside = NSWindow.windowNumber(at: screenLocation.origin, belowWindowWithWindowNumber: 0) == self.screen.windowNumber
            
            if mouseInside != updatedMouseInside {
                self.updateState({ current in
                    var current = current
                    current.mouseInside = updatedMouseInside
                    return current
                })
            }
            
            return .rejected
        }
        
        screen.set(mouseHandler: updateMouse, with: self, for: .mouseMoved)
        screen.set(mouseHandler: updateMouse, with: self, for: .mouseExited)
        screen.set(mouseHandler: updateMouse, with: self, for: .mouseEntered)

    }
    
    private var previousState: PeerCallState?
    
    private func applyState(_ state: PeerCallState, arguments: Arguments, animated: Bool) {
        
        
        var videoViewState: PeerCallVideoViewState = self.videoViewState
        switch state.externalState.remoteVideoState {
        case .active:
            if videoViewState.incomingView == nil {
                if let video = external.video(true) {
                    let view = MetalVideoMakeView(videoStreamSignal: video)
                    view.videoMetricsDidUpdate = { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.applyState(self.stateValue.with { $0 }, arguments: arguments, animated: animated)
                    }
                    view.set(handler: { [weak self] control in
                        self?.updateState { current in
                            var current = current
                            current.smallVideo = .outgoing
                            return current
                        }
                    }, for: .Up)
                    videoViewState.incomingView = view
                } else {
                    videoViewState.incomingView = nil
                }
            }
        default:
            videoViewState.incomingView = nil
        }
        
        switch state.externalState.videoState {
        case .active:
            if videoViewState.outgoingView == nil {
                if let video = external.video(false) {
                    let view = MetalVideoMakeView(videoStreamSignal: video)
                    view.videoMetricsDidUpdate = { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.applyState(self.stateValue.with { $0 }, arguments: arguments, animated: animated)
                    }
                    view.set(handler: { [weak self] _ in
                        self?.updateState { current in
                            var current = current
                            current.smallVideo = .incoming
                            return current
                        }
                    }, for: .Up)
                    videoViewState.outgoingView = view
                } else {
                    videoViewState.outgoingView = nil
                }
            }
        default:
            videoViewState.outgoingView = nil
        }
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .spring) : .immediate
        genericView.updateState(state, videoViewState: videoViewState, arguments: arguments, transition: transition)
        genericView.updateLayout(size: self.frame.size, transition: transition)
        
        if state.externalState.canBeRemoved, self.onCompletion != nil {
            closeAllModals(window: screen)
            if screen.isFullScreen {
                screen.toggleFullScreen(nil)
            }
            delay(1.3, closure: {
                NSAnimationContext.runAnimationGroup({ ctx in
                    self.screen.animator().alphaValue = 0
                }, completionHandler: {
                    self.screen.orderOut(nil)
                })
            })
            self.onCompletion?()
            self.onCompletion = nil
        }
       
        self.videoViewState = videoViewState
        self.previousState = state
    }
    
    public func show() {
        
        
        if !screen.isOnActiveSpace {
            self.screen.alphaValue = 0
            self.screen.makeKeyAndOrderFront(self)
            self.screen.orderFrontRegardless()
            
            NSAnimationContext.runAnimationGroup({ ctx in
                self.screen.animator().alphaValue = 1
            }, completionHandler: { })
        } else {
            self.screen.makeKeyAndOrderFront(self)
            self.screen.orderFrontRegardless()
        }
        
        screen.contentView = view

        
        self.genericView.updateLayout(size: screen.frame.size, transition: .immediate)
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
}


