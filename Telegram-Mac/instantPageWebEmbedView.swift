//
//  instantPageWebEmbedView.swift
//  Telegram
//
//  Created by keepcoder on 10/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import TGUIKit
import WebKit

private final class InstantPageWebView : WKWebView {
    
    var enableScrolling: Bool = true
    
    override func scrollWheel(with event: NSEvent) {
        if enableScrolling {
            super.scrollWheel(with: event)
        } else {
            if event.scrollingDeltaX != 0 {
                super.scrollWheel(with: event)
            } else {
                super.enclosingScrollView?.scrollWheel(with: event)
            }
        }
    }
}


private class WeakInstantPageWebEmbedNodeMessageHandler: NSObject, WKScriptMessageHandler {
    private let f: (WKScriptMessage) -> ()
    
    init(_ f: @escaping (WKScriptMessage) -> ()) {
        self.f = f
        
        super.init()
    }
    
    func userContentController(_ controller: WKUserContentController, didReceive scriptMessage: WKScriptMessage) {
        self.f(scriptMessage)
    }
}

final class InstantPageWebEmbedView: View, InstantPageView {
    let url: String?
    let html: String?
    
    private var webView: InstantPageWebView!
    let updateWebEmbedHeight: (CGFloat) -> Void
    init(frame: CGRect, url: String?, html: String?, enableScrolling: Bool, updateWebEmbedHeight: @escaping(CGFloat) -> Void) {
        self.url = url
        self.html = html
        self.updateWebEmbedHeight = updateWebEmbedHeight
        super.init()
        

        
        let js = "var TelegramWebviewProxyProto = function() {}; " +
            "TelegramWebviewProxyProto.prototype.postEvent = function(eventName, eventData) { " +
            "window.webkit.messageHandlers.performAction.postMessage({'eventName': eventName, 'eventData': eventData}); " +
            "}; " +
        "var TelegramWebviewProxy = new TelegramWebviewProxyProto();"
        
        let configuration = WKWebViewConfiguration()
        let userController = WKUserContentController()
        
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userController.addUserScript(userScript)
        
        userController.add(WeakInstantPageWebEmbedNodeMessageHandler { [weak self] message in
            if let strongSelf = self {
                strongSelf.handleScriptMessage(message)
            }
        }, name: "performAction")
        
        configuration.userContentController = userController
        
        let webView = InstantPageWebView(frame: CGRect(origin: CGPoint(), size: frame.size), configuration: configuration)

        
        
        if let html = html {
            webView.loadHTMLString(html, baseURL: nil)
        } else if let url = url, let parsedUrl = URL(string: url) {
            var request = URLRequest(url: parsedUrl)
            if let scheme = parsedUrl.scheme, let host = parsedUrl.host {
                let referrer = "\(scheme)://\(host)"
                request.setValue(referrer, forHTTPHeaderField: "Referer")
            }
            webView.load(request)
        }
        self.webView = webView
        webView.enableScrolling = enableScrolling
        addSubview(webView)
    }
    
    private func handleScriptMessage(_ message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else {
            return
        }
        
        guard let eventName = body["eventName"] as? String, let eventString = body["eventData"] as? String else {
            return
        }
        
        guard let eventData = eventString.data(using: .utf8) else {
            return
        }
        
        guard let dict = (try? JSONSerialization.jsonObject(with: eventData, options: [])) as? [String: Any] else {
            return
        }
        
        if eventName == "resize_frame", let height = dict["height"] as? Int {
            self.updateWebEmbedHeight(CGFloat(height))
        }
    }
    
    deinit {
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        self.webView.frame = self.bounds
    }
    
    func updateIsVisible(_ isVisible: Bool) {
    }
}
