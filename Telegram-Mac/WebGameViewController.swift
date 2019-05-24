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
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac

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



fileprivate var weakGames:[WeakReference<WebGameViewController>] = []

fileprivate func game(forKey:String) -> WebGameViewController? {
    for i in 0 ..< weakGames.count {
        if weakGames[i].value?.uniqueId == forKey {
            return weakGames[i].value
        }
    }
    return nil
}

class WebGameViewController: TelegramGenericViewController<WKWebView>, WKUIDelegate {
    private let gameUrl:String
    private let peerId:PeerId
    
    private var media:TelegramMediaGame!
    private var peer:Peer!
    
    private let messageId:MessageId
    fileprivate let uniqueId:String = "_\(arc4random())"
    private let loadMessageDisposable = MetaDisposable()
    init(_ context: AccountContext, _ peerId:PeerId, _ messageId:MessageId, _ gameUrl:String) {
        self.gameUrl = gameUrl
        self.peerId = peerId
        self.messageId = messageId
        super.init(context)
        weakGames.append(WeakReference(value: self))
    }
    
    override var enableBack: Bool {
        return true
    }
    override func requestUpdateRightBar() {
        (rightBarView as? ImageBarView)?.set(image: theme.icons.webgameShare, highlightImage: nil)
    }
    
    
    override func getRightBarViewOnce() -> BarView {
        let view = ImageBarView(controller: self, theme.icons.webgameShare)
        
        view.button.set(handler: { [weak self] _ in
            self?.share_game("")
        }, for: .Click)
        view.set(image: theme.icons.webgameShare, highlightImage: nil)
        return view
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        genericView.load(URLRequest(url: URL(string:"file://blank")!))
        genericView.stopLoading()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.wantsLayer = true
        loadMessageDisposable.set((context.account.postbox.messageAtId(messageId) |> deliverOnMainQueue).start(next: { [weak self] message in
            if let message = message, let game = message.media.first as? TelegramMediaGame, let peer = message.inlinePeer {
               self?.start(with: game, peer: peer)
            }
        }))
    }
    
    func start(with game: TelegramMediaGame, peer: Peer) {
        self.media = game
        self.peer = peer
        self.centerBarView.text = .initialize(string: media.name, color: theme.colors.text, font: .medium(.title))
        self.centerBarView.status = .initialize(string: "@\(peer.addressName ?? "gamebot")", color: theme.colors.grayText, font: .normal(.text))
        
        if let url = URL(string:gameUrl) {
            genericView.load(URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15))
        }
        
        
        

        
        readyOnce()
    }
    
    
    override func initializer() -> WKWebView {
        
        let js = "var TelegramWebviewProxyProto = function() {}; " +
            "TelegramWebviewProxyProto.prototype.postEvent = function(eventName, eventData) { " +
            "window.webkit.messageHandlers.performAction.postMessage({'eventName': eventName, 'eventData': eventData}); " +
            "}; " +
        "var TelegramWebviewProxy = new TelegramWebviewProxyProto();"
        
        let configuration = WKWebViewConfiguration()
        let userController = WKUserContentController()
        
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userController.addUserScript(userScript)
        
        userController.add(WeakGameScriptMessageHandler { [weak self] message in
            if let strongSelf = self {
                strongSelf.handleScriptMessage(message)
            }
        }, name: "performAction")
        
        
        configuration.userContentController = userController
        
        return WKWebView(frame: NSMakeRect(_frameRect.minX, _frameRect.minY, _frameRect.width, _frameRect.height - bar.height), configuration: configuration)
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
        
        showModal(with: ShareModalController(ShareCallbackObject(context, callback: { peerIds in
            let signals = peerIds.map { forwardGameWithScore(account: context.account, messageId: messageId, to: $0) }
            return combineLatest(signals) |> map { _ in return } |> ignoreValues
        })), for: mainWindow)
    }
    
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    
    deinit {
        while true {
            var index:Int = -1
            loop: for i in 0 ..< weakGames.count {
                if weakGames[i].value?.uniqueId == self.uniqueId || weakGames[i].value == nil {
                    index = i
                    break loop
                }
            }
            if index != -1 {
                weakGames.remove(at: index)
            } else {
                break
            }
        }
        
    }
    
}
