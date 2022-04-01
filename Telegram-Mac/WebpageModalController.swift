//
//  WebpageModalController.swift
//  TelegramMac
//
//  Created by keepcoder on 14/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import SwiftSignalKit
import Postbox
import WebKit

private class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private let f: (WKScriptMessage) -> ()
    
    init(_ f: @escaping (WKScriptMessage) -> ()) {
        self.f = f
        
        super.init()
    }
    
    func userContentController(_ controller: WKUserContentController, didReceive scriptMessage: WKScriptMessage) {
        self.f(scriptMessage)
    }
}



class WebpageModalController: ModalViewController, WKNavigationDelegate {
    
    struct Data {
        let queryId: Int64
        let bot: Peer
        let peerId: PeerId
        let buttonText: String
        let keepAliveSignal: Signal<Never, KeepWebViewError>
    }
    
    enum RequestData {
        case simple(url: String, bot: Peer)
        case normal(url: String?, peerId: PeerId, bot: Peer, replyTo: MessageId?, buttonText: String, payload: String?, complete:(()->Void)?)
    }

    
    private var indicator:ProgressIndicator!
    private var url:String
    private let context:AccountContext
    private var effectiveSize: NSSize?
    private var data: Data?
    private var requestData: RequestData?
    private var webview: WKWebView!
    private var locked: Bool = false
    private var counter: Int = 0
    private let title: String
    
    private var keepAliveDisposable: Disposable?
    private let installedBotsDisposable = MetaDisposable()
    private let requestWebDisposable = MetaDisposable()
    
    private var installedBots:[PeerId] = []
    
    init(url: String, title: String, effectiveSize: NSSize? = nil, requestData: RequestData? = nil, context: AccountContext) {
        self.url = url
        self.requestData = requestData
        self.data = nil
        self.context = context
        self.title = title
        self.effectiveSize = effectiveSize
        super.init(frame:NSMakeRect(0,0,380,450))
    }
    
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webview.isHidden = false
        webview.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        indicator.isHidden = true
        indicator.animates = false
    }
    
    override var dynamicSize:Bool {
        return true
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let js = "var TelegramWebviewProxyProto = function() {}; " +
        "TelegramWebviewProxyProto.prototype.postEvent = function(eventName, eventData) { " +
        "window.webkit.messageHandlers.performAction.postMessage({'eventName': eventName, 'eventData': eventData}); " +
        "}; " +
        "var TelegramWebviewProxy = new TelegramWebviewProxyProto();"
    
        let configuration = WKWebViewConfiguration()
        let userController = WKUserContentController()
        
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userController.addUserScript(userScript)
        
        userController.add(WeakScriptMessageHandler { [weak self] message in
            if let strongSelf = self {
                strongSelf.handleScriptMessage(message)
            }
        }, name: "performAction")

        
        configuration.userContentController = userController
    
        
        
        webview = WKWebView(frame: NSZeroRect, configuration: configuration)
        
        webview.wantsLayer = true
        webview.removeFromSuperview()
        addSubview(webview)
        
        indicator = ProgressIndicator(frame: NSMakeRect(0,0,30,30))
        addSubview(indicator)
        indicator.center()
        
        webview.isHidden = true
        indicator.animates = true
        
        webview.navigationDelegate = self
        
        readyOnce()
        let context = self.context

        
        if let requestData = requestData {
            
            switch requestData {
            case .simple(let url, let bot):
                let signal = context.engine.messages.requestSimpleWebView(botId: bot.id, url: url, themeParams: generateWebAppThemeParams(theme)) |> deliverOnMainQueue
                
                requestWebDisposable.set(signal.start(next: { [weak self] url in
                    if let url = URL(string: url) {
                        self?.webview.load(URLRequest(url: url))
                    }
                    self?.url = url
                }, error: { [weak self] error in
                    switch error {
                    case .generic:
                        alert(for: context.window, info: strings().unknownError)
                        self?.close()
                    }
                }))
            case .normal(let url, let peerId, let bot, let replyTo, let buttonText, let payload, let complete):
                let signal = context.engine.messages.requestWebView(peerId: peerId, botId: bot.id, url: url, payload: payload, themeParams: generateWebAppThemeParams(theme), replyToMessageId: replyTo) |> deliverOnMainQueue
                requestWebDisposable.set(signal.start(next: { [weak self] result in
                    
                    self?.data = .init(queryId: result.queryId, bot: bot, peerId: peerId, buttonText: buttonText, keepAliveSignal: result.keepAliveSignal)
                    if let url = URL(string: result.url) {
                        self?.webview.load(URLRequest(url: url))
                    }
                    self?.keepAliveDisposable = (result.keepAliveSignal
                                                |> deliverOnMainQueue).start(error: { [weak self] _ in
                                                    self?.close()
                                                }, completed: { [weak self] in
                                                    self?.close()
                                                    complete?()
                                                })
                    self?.url = result.url
                }, error: { [weak self] error in
                    switch error {
                    case .generic:
                        alert(for: context.window, info: strings().unknownError)
                        self?.close()
                    }
                }))
            }
            
            
            
        } else {
            if let url = URL(string: self.url) {
                webview.load(URLRequest(url: url))
            }
        }
        
        let bots = self.context.engine.messages.attachMenuBots() |> deliverOnMainQueue
        installedBotsDisposable.set(bots.start(next: { [weak self] items in
            self?.installedBots = items.map { $0.peer.id }
        }))

    }
    
    
    override func measure(size: NSSize) {
        if let embedSize = effectiveSize {
            let size = embedSize.aspectFitted(NSMakeSize(min(size.width - 100, 800), min(size.height - 100, 800)))
            webview.setFrameSize(size)
            
            self.modal?.resize(with:size, animated: false)
            indicator.center()

        } else {
            let size = NSMakeSize(380, 450)
            webview.setFrameSize(size)
            
            self.modal?.resize(with:size, animated: false)
            indicator.center()

        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        webview.removeFromSuperview()
        webview.stopLoading()
        webview.loadHTMLString("", baseURL: nil)
    }
    
    deinit {
        keepAliveDisposable?.dispose()
        installedBotsDisposable.dispose()
        requestWebDisposable.dispose()
    }
    
    private func handleScriptMessage(_ message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else {
            return
        }
        
        guard let eventName = body["eventName"] as? String else {
            return
        }
        
        switch eventName {
        case "web_app_data_send":
            if let eventData = body["eventData"] as? String {
                self.handleSendData(data: eventData)
            }
        case "web_app_close":
            self.close()
        default:
            break
        }
    }
    
    func sendEvent(name: String, data: String) {
        let script = "window.TelegramGameProxy.receiveEvent(\"\(name)\", \(data))"
        self.webview.evaluateJavaScript(script, completionHandler: { _, _ in
            
        })
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        
        let themeParams = generateWebAppThemeParams(theme)
        var themeParamsString = "{theme_params: {"
        for (key, value) in themeParams {
            if let value = value as? Int32 {
                let color = NSColor(rgb: UInt32(bitPattern: value))
                
                if themeParamsString.count > 16 {
                    themeParamsString.append(", ")
                }
                themeParamsString.append("\"\(key)\": \"#\(color.hexString)\"")
            }
        }
        themeParamsString.append("}}")
        self.sendEvent(name: "theme_changed", data: themeParamsString)

    }
    

    
    private func handleSendData(data string: String) {
        guard let controllerData = self.data else {
            return
        }
        
        counter += 1
        
        
        if let data = string.data(using: .utf8), let jsonArray = try? JSONSerialization.jsonObject(with: data, options : .allowFragments) as? [String: Any], let data = jsonArray["data"] {
            var resultString: String?
            if let string = data as? String {
                resultString = string
            } else if let data1 = try? JSONSerialization.data(withJSONObject: data, options: JSONSerialization.WritingOptions.prettyPrinted), let convertedString = String(data: data1, encoding: String.Encoding.utf8) {
                resultString = convertedString
            }
            if let resultString = resultString {
                let _ = (self.context.engine.messages.sendWebViewData(botId: controllerData.bot.id, buttonText: controllerData.buttonText, data: resultString)).start()
            }
        }
        self.close()
    }

    private func reloadPage() {
        self.webview.reload()
    }
    
    override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        return (left: ModalHeaderData(image: theme.icons.modalClose, handler: { [weak self] in
            self?.close()
        }), center: ModalHeaderData(title: self.defaultBarTitle, subtitle: strings().presenceBot), right: ModalHeaderData(image: theme.icons.chatActions, contextMenu: { [weak self] in
            
            var items:[ContextMenuItem] = []
            
            items.append(.init(strings().webAppReload, handler: { [weak self] in
                self?.reloadPage()
            }, itemImage: MenuAnimation.menu_reload.value))
            
            if let installedBots = self?.installedBots {
                if let data = self?.data, let bot = data.bot as? TelegramUser, let botInfo = bot.botInfo {
                    if botInfo.flags.contains(.canBeAddedToAttachMenu) {
                        if installedBots.contains(where: { $0 == bot.id }) {
                            items.append(ContextSeparatorItem())
                            items.append(.init(strings().webAppRemoveBot, handler: { [weak self] in
                                self?.removeBotFromAttachMenu(bot: bot)
                            }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                        } else {
                            items.append(.init(strings().webAppInstallBot, handler: { [weak self] in
                                self?.addBotToAttachMenu(bot: bot)
                            }, itemImage: MenuAnimation.menu_plus.value))
                        }
                    }
                }
            }
            return items
        }))
    }
    
    private func removeBotFromAttachMenu(bot: Peer) {
        let context = self.context
        _ = showModalProgress(signal: context.engine.messages.removeBotFromAttachMenu(botId: bot.id), for: context.window).start(next: { value in
            if value {
                showModalText(for: context.window, text: strings().webAppAttachRemoveSuccess(bot.displayTitle))
            }
        })
        self.installedBots.removeAll(where: { $0 == bot.id})
    }
    private func addBotToAttachMenu(bot: Peer) {
        let context = self.context
        installAttachMenuBot(context: context, peer: bot, completion: { [weak self] value in
            if value {
                self?.installedBots.append(bot.id)
            }
        })
    }
    
    
    override var defaultBarTitle: String {
        return self.title
    }
    

}

