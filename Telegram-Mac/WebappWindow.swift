//
//  WebappWindow.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.06.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import KeyboardKey
private final class Webapp : Window {
    fileprivate let controller: ViewController
    init(controller: ViewController) {
        self.controller = controller
        let screen = NSScreen.main!
        
        
        self.controller.viewWillAppear(true)
        self.controller.measure(size: screen.frame.size)
        
        let rect = screen.frame.focus(controller.view.frame.insetBy(dx: -10, dy: -10).size)
        
        super.init(contentRect: rect, styleMask: [.fullSizeContentView, .titled, .borderless], backing: .buffered, defer: true)
        
        self.contentView?.wantsLayer = true
        self.contentView?.autoresizesSubviews = false
        
        self.modalInset = 10

        
        controller.view.layer?.cornerRadius = 10
        
       
        self.contentView?.addSubview(controller.view)
        
        self.isOpaque = false
        self.hasShadow = false
        self.backgroundColor = NSColor.clear
       // self.contentView?.layer?.cornerRadius = 10
        self.isMovableByWindowBackground = true
        
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden

    }
    
    func show() {

        let shadow = SimpleShapeLayer()
        shadow.cornerRadius = 10
        shadow.masksToBounds = false
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.4).cgColor
        shadow.shadowOffset = CGSize(width: 0.0, height: 1)
        shadow.shadowRadius = 5
        shadow.shadowOpacity = 0.7
        shadow.fillColor = controller.view.background.cgColor
        shadow.path = CGPath(roundedRect: controller.view.bounds, cornerWidth: 10, cornerHeight: 10, transform: nil)
        shadow.frame = self.controller.frame
        
        self.contentView?.layer?.addSublayer(shadow)
        
        self.makeKeyAndOrderFront(nil)
        
        self.contentView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2, removeOnCompletion: false)
        self.contentView?.layer?.animateScaleSpring(from: 0.8, to: 1.0, duration: 0.2)
        
        
        self.controller.viewDidAppear(true)
        
    }
    
    override func close() {
        super.close()
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
}


class WebappRecentlyUsed : Equatable {
    static func == (lhs: WebappRecentlyUsed, rhs: WebappRecentlyUsed) -> Bool {
        return lhs.peerId != rhs.peerId
    }
    let peerId: PeerId
    init(peerId: PeerId) {
        self.peerId = peerId
    }
}

final class WebappWindow {
    fileprivate let window: Webapp
    private init(controller: ViewController) {
        self.window = Webapp(controller: controller)
        
        controller._window = window
    }
    
    static func makeAndOrderFront(_ controller: ViewController) {
        
        
        let w = WebappWindow(controller: controller)
        
        
        let ready = controller.ready.get() |> deliverOnMainQueue |> take(1)
        _ = ready.startStandalone(next: { ready in
            w.window.show()
        })
    }
    
    
    static func enumerateWebpages(_ f:(WebpageModalController)->Bool) {
        let windows = NSApp.windows.compactMap { $0 as? Webapp }
        
        for window in windows {
            if let controller = window.controller as? WebpageModalController {
                if f(controller) {
                    break
                }
            }
        }
    }
    
    
}

struct WebappsState : Equatable {
    var recentlyUsed: [WebappRecentlyUsed] = []
    
    var peerIds: [PeerId] {
        return recentlyUsed.map { $0.peerId }
    }
    
    var isEmpty: Bool {
        return recentlyUsed.isEmpty
    }
}

private let accountHolder: Atomic<[AccountRecordId : WebappsStateContext]> = .init(value: [:])



final class WebappsStateContext {
    
    static func get(_ context: AccountContext) -> WebappsStateContext {
        let holder = accountHolder.with { $0[context.account.id] }
        if let holder {
            return holder
        } else {
            return accountHolder.modify { value in
                var value = value
                value[context.account.id] = .init()
                return value
            }[context.account.id]!
        }
    }
    
    static func cleanup(_ accountId: AccountRecordId) {
        let holder = accountHolder.with { $0[accountId] }
        holder?.hide(close: true)
        
        _ = accountHolder.modify { value in
            var value = value
            value.removeValue(forKey: accountId)
            return value
        }
    }
    
    static func hide(_ accountId: AccountRecordId) {
        accountHolder.with { $0[accountId] }?.hide(close: false)
    }
    
    static func focus(_ active: [AccountRecordId]) -> Void {
        for accountId in active {
            let holder = accountHolder.with { $0[accountId] }
            if let browser = holder?.browser {
                holder?.show(browser)
            }
        }
        
        let holders = accountHolder.with { $0 }
        for (key, holder) in holders {
            if !active.contains(key) {
                holder.hide(close: false)
            }
        }
    }
    
    static func checkActive(_ active: [AccountRecordId]) {
        let holders = accountHolder.with { $0 }
        for (key, _) in holders {
            if !active.contains(key) {
                cleanup(key)
            }
        }
    }
    
    static func checkKey(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == KeyboardKey.W.rawValue, event.modifierFlags.contains(.command) {
            let list = accountHolder.with { $0.values }
            var invoked: Bool = false
            for value in list {
                if value.browser?.window == event.window {
                    value.browser?.closeTab()
                    invoked = true
                }
            }
            if invoked {
                return nil
            }
        }
        return event
    }
    
    public private(set) var browser: WebappBrowserController? = nil
    private let browserState: Promise<[BrowserTabData]> = Promise([])
    
    func show(_ browser: WebappBrowserController) {
        self.browser = browser
        browser.show()
        
        browserState.set(browser.publicState)
    }
    
    public func hide(close: Bool = true) {
        self.browser?.hide({ [weak self] in
            if close {
                self?.browser = nil
            }
        }, close: close)
        if close {
            browserState.set(.single([]))
        }
    }
    
    
    
    private let statePromise = ValuePromise<WebappsState>(.init(), ignoreRepeated: true)
    private let stateValue = Atomic<WebappsState>(value: .init())
    
    var state: Signal<WebappsState, NoError> {
        return statePromise.get()
    }
    
    struct FullState : Equatable {
        
        struct ResolvedRecently : Equatable {
            var url: String
            let text: String
            var peerId: PeerId
        }
        
        let opened: [BrowserTabData]
        
        let state: WebappsState
        let peers: [EnginePeer.Id : EnginePeer]
        let recentlyMenu: [ResolvedRecently]
        
        struct Recommended : Equatable {
            let peer: EnginePeer
            let button: BotMenuButton?
        }
        
        var isEmpty: Bool {
            return recentlyMenu.isEmpty && opened.isEmpty
        }
        
        let recommended:[Recommended]
        let recentUsedApps: [Recommended]
    }
    
    func fullState(_ context: AccountContext) -> Signal<FullState, NoError> {
        return combineLatest(statePromise.get(), browserState.get()) |> mapToSignal { value, browserState in
            let peersSignal: [Signal<EnginePeer?, NoError>] = value.peerIds.map {
                context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: $0))
            }
            let recentApps: [Signal<(BotMenuButton?, PeerId), NoError>] = value.recentlyUsed.map { value in
                return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.BotMenu(id: value.peerId)) |> map { ($0, value.peerId)}
            }
            
            let recommendedList:(Signal<[EnginePeer.Id]?, NoError>) -> Signal<[FullState.Recommended], NoError> = { signal in
                return signal |> mapToSignal { appIds in
                    if let appIds {
                        return context.engine.data.subscribe(
                            EngineDataMap(
                                appIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                                    return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                                }
                            ), EngineDataMap(
                                appIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.BotMenu in
                                    return TelegramEngine.EngineData.Item.Peer.BotMenu(id: peerId)
                                }
                            )) |> map  { (peers, menu) in
                                var result: [FullState.Recommended] = []
                                for id in appIds {
                                    if let peer = peers[id] as? EnginePeer  {
                                        result.append(FullState.Recommended(peer: peer, button: menu[id] as? BotMenuButton))
                                    }
                                }
                                return Array(result)
                            }
                    } else {
                        return .single(Array<FullState.Recommended>())
                    }
                }
            }
            
            let recommendedApps: Signal<[FullState.Recommended], NoError> = recommendedList(context.engine.peers.recommendedAppPeerIds())
            let recentUsedApps: Signal<[FullState.Recommended], NoError> = recommendedList(context.engine.peers.recentApps() |> map(Optional.init)) |> map { Array($0.filter { $0.peer._asPeer().botInfo?.flags.contains(.hasWebApp) == true }.prefix(10)) }
            
            
            let combinedRecentApps = combineLatest(recentApps) |> map { menus in
                var recent: [FullState.ResolvedRecently] = []
                for menu in menus {
                    if let menuValue = menu.0 {
                        switch menuValue {
                        case let .webView(text, url):
                            if !browserState.contains(where: { $0.data.peer?.id == menu.1 }) {
                                recent.append(.init(url: url, text: text, peerId: menu.1))
                            }
                        default:
                            break
                        }
                    }
                }
                return recent
            }
            
            let combinedPeers = combineLatest(peersSignal)
            let peers: Signal<[EnginePeer.Id : EnginePeer], NoError> = combinedPeers |> map { peers in
                return peers.compactMap { $0 }.toDictionary(with: { $0.id })
            }
                        
            return combineLatest(peers, combinedRecentApps, recommendedApps, recentUsedApps) |> map { (peers, recentlyMenu, recommendedApps, recentUsedApps) in
                let recommended = recommendedApps.filter { value in
                    return !recentUsedApps.contains(where: { $0.peer.id == value.peer.id })
                }
                return FullState(opened: browserState.filter { $0.data.peer != nil }, state: value, peers: peers, recentlyMenu: recentlyMenu, recommended: recommended, recentUsedApps: recentUsedApps)
            }
        }
    }
    
    private func updateState(_ f:(WebappsState) -> WebappsState) {
        self.statePromise.set(stateValue.modify(f))
    }

    
    func add(_ recently: WebappRecentlyUsed) {
        updateState { current in
            var current = current
            if let index = current.recentlyUsed.firstIndex(where: { $0.peerId == recently.peerId }) {
                current.recentlyUsed.move(at: index, to: 0)
            } else {
                current.recentlyUsed.insert(recently, at: 0)
            }
            return current
        }
    }
    
    
    func closeAll() {
        hide()
    }
    
    func clearRecent() {
        updateState { current in
            var current = current
            current.recentlyUsed.removeAll()
            return current
        }
    }
    
    func open(tab: BrowserTabData.Data, context: AccountContext, uniqueId: BrowserTabData.Unique? = nil) {
        let invoke:()->Void = { [weak self] in
            guard let self else {
                return
            }
            if let browser = self.browser {
                browser.add(tab, uniqueId: uniqueId)
                browser.makeKeyAndOrderFront()
            } else {
                let controller = WebappBrowserController(context: context, initialTab: tab)
                self.show(controller)
            }
            if let savebleId = tab.savebleId {
                self.add(.init(peerId: savebleId))
            }
        }
        
        let window = self.browser?.window ?? context.window
        
        if let peer = tab.peer {
            let peerId = peer.id
            if FastSettings.shouldConfirmWebApp(peerId) {
                verifyAlert_button(for: window, header: strings().webAppFirstOpenTitle, information: strings().webAppFirstOpenInfo(peer._asPeer().displayTitle), successHandler: { _ in
                    invoke()
                    FastSettings.markWebAppAsConfirmed(peerId)
                })
            } else {
                invoke()
            }
        } else {
            invoke()
        }
        
    }
}


/*

 */
