//
//  WebGameViewController.swift
//  TelegramMac
//
//  Created by keepcoder on 30/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import WebKit
import TGUIKit
import SwiftSignalKit
import TelegramCore
import TelegramIconsTheme
import Postbox

private class WeakGameScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private let f: (WKScriptMessage) -> ()
    
    init(_ f: @escaping (WKScriptMessage) -> ()) {
        self.f = f
        
        super.init()
    }
    
    func userContentController(_ controller: WKUserContentController, didReceive scriptMessage: WKScriptMessage) {
        self.f(scriptMessage)
    }
}




public final class GameView : View {
    
    let headerView: WebpageHeaderView
    
    let webView: WKWebView
    
    required init(frame frameRect: NSRect, configuration: WKWebViewConfiguration!) {
        headerView = .init(frame: NSMakeRect(0, 0, frameRect.width, 50))
        webView = WKWebView(frame: CGRect(origin: NSMakePoint(0, headerView.frame.height), size: NSMakeSize(frameRect.width, frameRect.height - headerView.frame.height)), configuration: configuration)
        super.init(frame: frameRect)
        
        addSubview(webView)
        addSubview(headerView)

        updateLocalizationAndTheme(theme: theme)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    public override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: headerView, frame: NSMakeRect(0, 0, size.width, 50))
        transition.updateFrame(view: webView, frame: NSMakeRect(0, headerView.frame.maxY, size.width, size.height - headerView.frame.maxY))
    }
    
    public override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        self.headerView.backgroundColor = theme.colors.background
    }
}

class WebGameViewController: ModalViewController, WKUIDelegate {
    private let gameUrl:String
    let peerId:PeerId
    private let context: AccountContext
    
    private var media:TelegramMediaGame!
    private var peer:Peer!
    private var threadId: Int64?
    
    private let messageId:MessageId
    fileprivate let uniqueId:String = "_\(arc4random())"
    private let loadMessageDisposable = MetaDisposable()
    init(_ context: AccountContext, _ peerId:PeerId, _ messageId:MessageId, _ gameUrl:String) {
        self.gameUrl = gameUrl
        self.peerId = peerId
        self.context = context
        self.messageId = messageId
        super.init()
    }
    
    override var enableBack: Bool {
        return true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        webView.load(URLRequest(url: URL(string:"file://blank")!))
        webView.stopLoading()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadMessageDisposable.set((context.account.postbox.messageAtId(messageId) |> deliverOnMainQueue).start(next: { [weak self] message in
            if let message = message, let game = message.anyMedia as? TelegramMediaGame {
                self?.start(with: game, peer: message.inlinePeer, threadId: message.threadId)
            }
        }))
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.genericView.updateLocalizationAndTheme(theme: theme)
    }
    
    func start(with game: TelegramMediaGame, peer: Peer?, threadId: Int64?) {
        self.media = game
        self.peer = peer
        self.threadId = threadId
        
        genericView.headerView.update(title: peer?.displayTitle ?? media.title, subtitle: media.name, left: .dismiss, animated: false, leftCallback: { [weak self] in
            self?.close()
        }, contextMenu: { [weak self] in
            let menu = ContextMenu()
            menu.addItem(ContextMenuItem(strings().modalShare, handler: {
                self?.share_game("")
            }, itemImage: MenuAnimation.menu_share.value))
            return menu
        }, context: context, bot: peer)
                
        if let url = URL(string:gameUrl) {
            webView.load(URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15))
        }
        
        
        readyOnce()
    }
    
    
    override func close(animationType: ModalAnimationCloseBehaviour = .common) {        
        self.window?.contentView?.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
            self?._window?.orderOut(nil)
            self?._window = nil
        })
    }
    
    
    override func initializer() -> GameView {
        
        let js = "var TelegramWebviewProxyProto = function() {}; " +
            "TelegramWebviewProxyProto.prototype.postEvent = function(eventName, eventData) { " +
            "window.webkit.messageHandlers.performAction.postMessage({'eventName': eventName, 'eventData': eventData}); " +
            "}; " +
        "var TelegramWebviewProxy = new TelegramWebviewProxyProto();"
        
        let configuration = WKWebViewConfiguration()
        
        if FastSettings.debugWebApp {
            configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        }
        
        let userController = WKUserContentController()
        
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userController.addUserScript(userScript)
        
        userController.add(WeakGameScriptMessageHandler { [weak self] message in
            if let strongSelf = self {
                strongSelf.handleScriptMessage(message)
            }
        }, name: "performAction")
        
        
        configuration.userContentController = userController
        
        let rect = NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height)
        
        return GameView(frame: rect, configuration: configuration)
    }
    
    private func handleScriptMessage(_ message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else {
            return
        }
        
        guard let eventName = body["eventName"] as? String else {
            return
        }
        
        switch eventName {
        case "share_game":
            self.share_game("")
        case "share_score":
            self.share_score("")
        case "game_over":
            self.game_over("")
        case "game_loaded":
            self.game_loaded("")
        default:
            break
        }
    }


    
    @objc func game_loaded(_ data:String) {
        
    }
    @objc func game_over(_ data:String) {
        
    }
    @objc func share_game(_ data:String) {
        showModal(with: ShareModalController(ShareLinkObject(context, link: "https://t.me/\(self.peer.addressName ?? "gamebot")" + "?game=\(self.media.name)")), for: mainWindow)
    }
    @objc func share_score(_ data:String) {
        
        let context = self.context
        let messageId = self.messageId
        let threadId = self.threadId
        if let window {
            showModal(with: ShareModalController(ShareCallbackObject(context, callback: { peerIds in
                let signals = peerIds.map { context.engine.messages.forwardGameWithScore(messageId: messageId, to: $0, threadId: threadId, as: nil) }
                return combineLatest(signals) |> map { _ in return } |> ignoreValues
            })), for: window)
        }
    }
    
    private var webView: WKWebView {
        return (self.view as! GameView).webView
    }
    
    private var genericView: GameView {
        return (self.view as! GameView)
    }
    
    
    
    override func viewClass() -> AnyClass {
        return GameView.self
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override func firstResponder() -> NSResponder? {
        return webView
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    
    deinit {
        
    }
    
    override func measure(size: NSSize) {
        let s = NSMakeSize(size.width + 20, size.height + 20)
        let size = NSMakeSize(420, min(420 + 420 * 0.6, s.height - 80))
        let rect = size.bounds.insetBy(dx: 10, dy: 10)
        self.genericView.frame = rect
        self.genericView.updateLayout(size: rect.size, transition: .immediate)
    }

    
}
