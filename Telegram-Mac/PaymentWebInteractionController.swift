//
//  PaymentWebInteractionController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 26.02.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import WebKit

private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}
enum PaymentWebInteractionIntent {
    case addPaymentMethod((BotCheckoutPaymentWebToken) -> Void)
    case externalVerification((Bool) -> Void)
}

private class WeakPaymentScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private let f: (WKScriptMessage) -> ()
    
    init(_ f: @escaping (WKScriptMessage) -> ()) {
        self.f = f
        
        super.init()
    }
    
    func userContentController(_ controller: WKUserContentController, didReceive scriptMessage: WKScriptMessage) {
        self.f(scriptMessage)
    }
}



final class PaymentWebInteractionController: ModalViewController, WKNavigationDelegate {
    private let url: String
    private let intent: PaymentWebInteractionIntent
    init(context: AccountContext, url: String, intent: PaymentWebInteractionIntent) {
        self.url = url
        self.intent = intent
        super.init(frame: NSMakeRect(0, 0, 380, 440))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
    }
    
    override var defaultBarTitle: String {
        switch intent {
        case .addPaymentMethod:
            return L10n.checkoutNewCardTitle
        case .externalVerification:
            return L10n.checkoutWebConfirmationTitle
        }
    }
    
    override var modalInteractions: ModalInteractions? {
        return ModalInteractions(acceptTitle: L10n.modalCancel, accept: { [weak self] in
            self?.close()
        }, height: 50, singleButton: true)
    }
    
    override func initializer() -> NSView {
        let webView: WKWebView
        switch intent {
            case .addPaymentMethod:
            let js = "var TelegramWebviewProxyProto = function() {}; " +
                "TelegramWebviewProxyProto.prototype.postEvent = function(eventName, eventData) { " +
                "window.webkit.messageHandlers.performAction.postMessage({'eventName': eventName, 'eventData': eventData}); " +
                "}; " +
            "var TelegramWebviewProxy = new TelegramWebviewProxyProto();"
               
            let configuration = WKWebViewConfiguration()
            let userController = WKUserContentController()
               
            let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            userController.addUserScript(userScript)
               
            userController.add(WeakPaymentScriptMessageHandler { [weak self] message in
                if let strongSelf = self {
                    strongSelf.handleScriptMessage(message)
                }
            }, name: "performAction")
               
            configuration.userContentController = userController
            webView = WKWebView(frame: CGRect(), configuration: configuration)
            webView.allowsLinkPreview = false

        case .externalVerification:
            webView = WKWebView()
            webView.allowsLinkPreview = false
            webView.navigationDelegate = self
        }
        if let parsedUrl = URL(string: url) {
           webView.load(URLRequest(url: parsedUrl))
        }
        webView.frame = NSMakeRect(0, 0, _frameRect.width, _frameRect.height - 50)
        return webView
    }
    
    private func handleScriptMessage(_ message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else {
            return
        }
       
        guard let eventName = body["eventName"] as? String else {
            return
        }
       
        if eventName == "payment_form_submit" {
            guard let eventString = body["eventData"] as? String else {
                return
            }
           
            guard let eventData = eventString.data(using: .utf8) else {
                return
            }
           
            guard let dict = (try? JSONSerialization.jsonObject(with: eventData, options: [])) as? [String: Any] else {
                return
            }
           
            guard let title = dict["title"] as? String else {
                return
            }
           
            guard let credentials = dict["credentials"] else {
                return
            }
           
            guard let credentialsData = try? JSONSerialization.data(withJSONObject: credentials, options: []) else {
                return
            }
           
            guard let credentialsString = String(data: credentialsData, encoding: .utf8) else {
                return
            }
           
            if case let .addPaymentMethod(completion) = self.intent {
                completion(BotCheckoutPaymentWebToken(title: title, data: credentialsString, saveOnServer: false))
                close()
            }
        }
    }
       
   func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if case let .externalVerification(completion) = self.intent, let host =  navigationAction.request.url?.host {
            if host == "t.me" || host == "telegram.me" {
                decisionHandler(.cancel)
                completion(true)
                close()
            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
    }

}
