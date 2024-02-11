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

protocol CallViewUpdater {
    func updateState(_ state: PeerCallState, arguments: Arguments, transition: ContainedViewLayoutTransition)
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition)
}

public final class PeerCallScreen : ViewController {
    private let external: PeerCallArguments
    private let screen: Window
    
    private let actionsDisposable = DisposableSet()

    
    private let statePromise = ValuePromise<PeerCallState>(ignoreRepeated: true)
    private let stateValue = Atomic<PeerCallState>(value: .init())
    private func updateState(_ f: (PeerCallState) -> PeerCallState) {
        statePromise.set(stateValue.modify (f))
    }
    
    public init(external: PeerCallArguments) {
        self.external = external
        let size = NSMakeSize(720, 560)
        if let screen = NSScreen.main {
            self.screen = Window(contentRect: NSMakeRect(floorToScreenPixels((screen.frame.width - size.width) / 2), floorToScreenPixels((screen.frame.height - size.height) / 2), size.width, size.height), styleMask: [.fullSizeContentView, .borderless, .resizable, .miniaturizable, .titled], backing: .buffered, defer: true, screen: screen)
            self.screen.minSize = size
            self.screen.isOpaque = true
            self.screen.backgroundColor = .black
            self.screen.titlebarAppearsTransparent = true
            self.screen.isMovableByWindowBackground = true
        } else {
            fatalError("screen not found")
        }

        super.init()

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
        
        
        let arguments = Arguments(external: external, toggleAnim: {
            //            updateState { current in
            //                var current = current
            //                current.externalState = current.stateIndex + 1
            //                if current.stateIndex > 2 {
            //                    current.stateIndex = 0
            //                }
            //                if let networkStatus = current.networkStatus {
            //                    switch networkStatus {
            //                    case .connecting:
            //                        current.networkStatus = .calling
            //                    case .calling:
            //                        current.networkStatus = .failed
            //                    case .failed:
            //                        current.networkStatus = nil
            //                    }
            //                } else {
            //                    current.networkStatus = .connecting
            //                }
            //                current.networkSignal = current.networkSignal + 1
            //                if current.networkSignal > 4 {
            //                    current.networkSignal = 0
            //                }
            //                return current
            //            }
        }, toggleSecretKey: {
            updateState { current in
                var current = current
                current.secretKeyViewState = current.secretKeyViewState.rev
                return current
            }
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
                    return "Weak network signal"
                }
                if index == 1 {
                    return "\(state.compactTitle)'s battery is low"
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
            .init(lowSignal: $0.reception != nil && $0.reception! < 2, lowBattery: $0.externalState.remoteBatteryLevel == .low)
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
            } else if event.keyCode == KeyboardKey.Space.rawValue {
                arguments.toggleSecretKey()
                return .invoked
            }
            
            
            return .rejected
        }
        
        screen.set(handler: invokeEsc, with: self, for: .Escape)
        screen.set(handler: invokeEsc, with: self, for: .Space)

    }
    
    private func applyState(_ state: PeerCallState, arguments: Arguments, animated: Bool) {
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .spring) : .immediate
        genericView.updateState(state, arguments: arguments, transition: transition)
        genericView.updateLayout(size: self.frame.size, transition: transition)
    }
    
    public func show() {
        
        screen.contentView = view
        
        self.screen.makeKeyAndOrderFront(self)
        self.screen.orderFrontRegardless()
        
        self.genericView.updateLayout(size: screen.frame.size, transition: .immediate)
    }
}


