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

fileprivate var weakGames:[WeakReference<WebGameViewController>] = []

fileprivate func game(forKey:String) -> WebGameViewController? {
    for i in 0 ..< weakGames.count {
        if weakGames[i].value?.uniqueId == forKey {
            return weakGames[i].value
        }
    }
    return nil
}

class WebGameViewController: TelegramGenericViewController<WebView>, WebFrameLoadDelegate {
    private let gameUrl:String
    private let peerId:PeerId
    
    private var media:TelegramMediaGame!
    private var peer:Peer!
    
    private let messageId:MessageId
    fileprivate let uniqueId:String = "_\(arc4random())"
    private let loadMessageDisposable = MetaDisposable()
    init(_ account:Account, _ peerId:PeerId, _ messageId:MessageId, _ gameUrl:String) {
        self.gameUrl = gameUrl
        self.peerId = peerId
        self.messageId = messageId
        super.init(account)
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
        
        let account = self.account
        view.button.set(handler: {_ in 
            showModal(with: ShareModalController(ShareLinkObject(account, link: "https://t.me/gamebot")), for: mainWindow)
        }, for: .Click)
        view.set(image: theme.icons.webgameShare, highlightImage: nil)
        return view
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        genericView.mainFrame.load(URLRequest(url: URL(string:"file://blank")!))
        genericView.mainFrame.stopLoading()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadMessageDisposable.set((account.postbox.messageAtId(messageId) |> deliverOnMainQueue).start(next: { [weak self] message in
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
            genericView.mainFrame.load(URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15))
        }
        genericView.frameLoadDelegate = self;
        readyOnce()
    }
    
    func webView(_ sender: WebView!, didFinishLoadFor frame: WebFrame!) {
        frame.windowObject.evaluateWebScript("TelegramWebviewProxy = { postEvent:function(eventType, eventData) {gameHandler(eventType,eventData)}}")
        JSGlobalContextSetName(frame.globalContext, JSStringCreateWithCFString(uniqueId as CFString!));
        let funcName = JSStringCreateWithUTF8CString("gameHandler");
        let funcObj = JSObjectMakeFunctionWithCallback(frame.globalContext, funcName, { (ctx, function, thisObject, argumentCount, arguments, exception) in
            if let arguments = arguments, argumentCount == 2 && JSValueGetType (ctx, arguments[0]) == kJSTypeString && JSValueGetType (ctx, arguments[1]) == kJSTypeString {
                let eventType = JSStringCopyCFString(kCFAllocatorDefault,JSValueToStringCopy (ctx, arguments[0],exception))
                let data = JSStringCopyCFString(kCFAllocatorDefault,JSValueToStringCopy (ctx, arguments[1],exception))
                let uniqueId = JSStringCopyCFString(kCFAllocatorDefault,JSGlobalContextCopyName(JSContextGetGlobalContext(ctx)))

                if let eventType = eventType as String?, let data = data as String?, let uniqueId = uniqueId as String?, let controller = game(forKey: uniqueId) {
                    let selector = NSSelectorFromString(eventType + ":")
                    if controller.responds(to: selector) {
                        controller.perform(selector, with: data)
                    }
                }
            }
            return  JSValueMakeNull(ctx);
        });
        JSObjectSetProperty(sender.mainFrame.globalContext, JSContextGetGlobalObject(frame.globalContext), funcName, funcObj, JSPropertyAttributes(kJSPropertyAttributeNone), nil);
        JSStringRelease(funcName);

    }

    
    @objc func game_loaded(_ data:String) {
        
    }
    @objc func game_over(_ data:String) {
        
    }
    @objc func share_game(_ data:String) {
        showModal(with: ShareModalController(ShareLinkObject(account, link: "https://t.me/gamebot")), for: mainWindow)
    }
    @objc func share_score(_ data:String) {
        showModal(with: ShareModalController(ShareLinkObject(account, link: "https://t.me/gamebot")), for: mainWindow)
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
