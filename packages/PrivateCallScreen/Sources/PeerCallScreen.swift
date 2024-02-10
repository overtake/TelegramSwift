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
        })
        
        
        
        actionsDisposable.add((statePromise.get() |> deliverOnMainQueue).start(next: { [weak self] state in
            self?.applyState(state, arguments: arguments, animated: true)
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
    }
    
    private func applyState(_ state: PeerCallState, arguments: Arguments, animated: Bool) {
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
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


