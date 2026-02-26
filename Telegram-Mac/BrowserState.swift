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
        
        self.minSize = rect.size
        
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
        return lhs.tabdata.unique != rhs.tabdata.unique
    }
    var tabdata: BrowserTabData
    
    init(tabdata: BrowserTabData) {
        self.tabdata = tabdata
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
    
    
    var isEmpty: Bool {
        return recentlyUsed.isEmpty
    }
}

private let accountHolder: Atomic<[AccountRecordId : BrowserStateContext]> = .init(value: [:])



final class BrowserStateContext {
    
    private init(context: AccountContext) {
        self.context = context
    }
    
    static func get(_ context: AccountContext) -> BrowserStateContext {
        let holder = accountHolder.with { $0[context.account.id] }
        if let holder {
            return holder
        } else {
            return accountHolder.modify { value in
                var value = value
                value[context.account.id] = .init(context: context)
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
        if event.modifierFlags.contains(.command) {
            let list = accountHolder.with { $0.values }
            var invoked: Bool = false
            for value in list {
                if value.browser?.window == event.window {
                    if event.keyCode == KeyboardKey.W.rawValue {
                        value.browser?.closeTab()
                        invoked = true
                    } else {
                        let keyCodes: [KeyboardKey] = [.Escape, .Zero, .One, .Two, .Three, .Four, .Five, .Six, .Seven, .Eight, .Nine]
                        if keyCodes.contains(where: { $0.rawValue == event.keyCode }) {
                            event.window?.sendEvent(event)
                            invoked = true
                        }
                    }
                               
                }
            }
            if invoked {
                return nil
            }
        }
        return event
    }
    
    public private(set) var browser: WebappBrowserController? = nil
    private let context: AccountContext
    
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
            let tab: BrowserTabData
        }
        
        let opened: [BrowserTabData]
        
        let state: WebappsState
        let recentlyMenu: [ResolvedRecently]
        
        struct Recommended : Equatable {
            let peer: EnginePeer
        }
        
        var isEmpty: Bool {
            return recentlyMenu.isEmpty && opened.isEmpty
        }
        
        let recommended:[Recommended]
        let recentUsedApps: [Recommended]
    }
    
    func fullState() -> Signal<FullState, NoError> {
        let context = self.context
        return combineLatest(statePromise.get(), browserState.get()) |> mapToSignal { value, browserState in
            let recommendedList:(Signal<[EnginePeer.Id]?, NoError>) -> Signal<[FullState.Recommended], NoError> = { signal in
                return signal |> mapToSignal { appIds in
                    if let appIds {
                        return context.engine.data.subscribe(
                            EngineDataMap(
                                appIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                                    return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                                }
                            )) |> map  { peers in
                                var result: [FullState.Recommended] = []
                                for id in appIds {
                                    if let peer = peers[id] as? EnginePeer  {
                                        result.append(FullState.Recommended(peer: peer))
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
            
            
            let combinedRecentApps: [FullState.ResolvedRecently] = value.recentlyUsed.compactMap { recent in
                if !browserState.contains(where: { $0.unique == recent.tabdata.unique }) {
                    return .init(tab: recent.tabdata)
                }
                return nil
            }
            
                        
            return combineLatest(recommendedApps, recentUsedApps) |> map { (recommendedApps, recentUsedApps) in
                let recommended = recommendedApps.filter { value in
                    return !recentUsedApps.contains(where: { $0.peer.id == value.peer.id })
                }
                return FullState(opened: browserState, state: value, recentlyMenu: combinedRecentApps, recommended: recommended, recentUsedApps: recentUsedApps)
            }
        }
    }
    
    private func updateState(_ f:(WebappsState) -> WebappsState) {
        self.statePromise.set(stateValue.modify(f))
    }

    
    func add(_ recently: WebappRecentlyUsed) {
        if recently.tabdata.peer?.addressName != context.appConfiguration.getStringValue("verify_age_bot_username", orElse: "") {
            if recently.tabdata.data.canBeRecent {
                updateState { current in
                    var current = current
                    if let index = current.recentlyUsed.firstIndex(where: { $0.tabdata.unique == recently.tabdata.unique }) {
                        current.recentlyUsed.move(at: index, to: 0)
                        current.recentlyUsed[0] = recently
                    } else {
                        current.recentlyUsed.insert(recently, at: 0)
                    }
                    return current
                }
            }
        }
    }
    func setExternalState(_ unique: BrowserTabData.Unique, external: WebpageModalState) {
        updateState { current in
            let current = current
            if let index = current.recentlyUsed.firstIndex(where: { $0.tabdata.unique == unique }) {
                current.recentlyUsed[index].tabdata.external = external
            }
            return current
        }
    }
    
    func getExternal(_ unique: BrowserTabData.Unique) -> WebpageModalState? {
        return self.stateValue.with {
            $0.recentlyUsed.first(where: { $0.tabdata.unique == unique })?.tabdata.external
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
    
    func open(tab: BrowserTabData.Data, uniqueId: BrowserTabData.Unique? = nil) {
        
        let context = self.context
        
        let invoke:()->Void = { [weak self] in
            guard let self else {
                return
            }
            if let browser = self.browser, !browser.markAsDeinit {
                browser.add(tab, uniqueId: uniqueId)
                browser.makeKeyAndOrderFront()
            } else {
                let controller = WebappBrowserController(context: context, initialTab: tab)
                self.show(controller)
            }

        }
        let verify_age_bot = context.appConfiguration.getStringValue("verify_age_bot_username", orElse: "")

        
        if let peer = tab.peer {
            
            
            let peerId = peer.id
            
            if FastSettings.shouldConfirmWebApp(peerId), peer.addressName != verify_age_bot {
                
                let signal = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.BotPrivacyPolicyUrl(id: peerId)) |> deliverOnMainQueue
                _ = signal.startStandalone(next: { [weak self] privacyUrl in
                    var window: Window?
                    if self?.browser?.markAsDeinit == false {
                        window = self?.browser?.window
                    } else {
                        window = self?.context.window
                    }
                    if let window, let context = self?.context {
                        let privacyUrl = privacyUrl ?? strings().botInfoLaunchInfoPrivacyUrl
                                                
                        let data = ModalAlertData(title: nil, info: strings().webAppFirstOpenTerms(privacyUrl), description: nil, ok: strings().botLaunchApp, options: [], mode: .confirm(text: strings().modalCancel, isThird: false), header: .init(value: { initialSize, stableId, presentation in
                            return AlertHeaderItem(initialSize, stableId: stableId, presentation: presentation, context: context, peer: peer, info: strings().botMoreAbout, callback: { _ in
                                navigateToChat(navigation: context.bindings.rootNavigation(), context: context, chatLocation: .peer(peerId))
                                closeAllModals(window: context.window)
                            })
                        }))
                        
                        showModalAlert(for: window, data: data, completion: { result in
                            invoke()
                            FastSettings.markWebAppAsConfirmed(peerId)
                        })
                    }
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
