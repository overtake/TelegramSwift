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

final class instantPageWebEmbedView: View, InstantPageView {
    let url: String?
    let html: String?
    
    private let webView: WebView
    
    init(frame: CGRect, url: String?, html: String?, enableScrolling: Bool) {
        self.url = url
        self.html = html
        
        self.webView = WebView(frame: CGRect(origin: CGPoint(), size: frame.size))
        
        webView.background = theme.colors.background
        super.init()
        
        if let html = html {
            self.webView.mainFrame.loadHTMLString(html, baseURL: nil)
        } else if let url = url, let parsedUrl = URL(string: url) {
            var request = URLRequest(url: parsedUrl)
            let referrer = "\(parsedUrl.scheme ?? "")://\(parsedUrl.host ?? "")"
            request.setValue(referrer, forHTTPHeaderField: "Referer")
            self.webView.mainFrame.load(request)
        }
        addSubview(webView)
    }
    
    
    deinit {
        webView.mainFrame.load(URLRequest(url: URL(string:"file://blank")!))
        webView.mainFrame.stopLoading()
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
