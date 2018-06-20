//
//  WebpageModalController.swift
//  TelegramMac
//
//  Created by keepcoder on 14/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac
import WebKit


class WebpageModalController: ModalViewController,WebFrameLoadDelegate {
    private var indicator:ProgressIndicator!
    private let content:TelegramMediaWebpageLoadedContent
    private let account:Account
    private let webview: WebView = WebView(frame: NSZeroRect)
    override func loadView() {
        super.loadView()
        webview.frameLoadDelegate = self
        webview.wantsLayer = true
        webview.removeFromSuperview()
        addSubview(webview)
        
        indicator = ProgressIndicator(frame: NSMakeRect(0,0,30,30))
        addSubview(indicator)
        indicator.center()
        
        webview.isHidden = true
        indicator.animates = true
        
        
       // leakWebview()
        
        if let embed = content.embedUrl, let url = URL(string: embed) {
            webview.mainFrame.load(URLRequest(url: url))
            readyOnce()
        }
        
    }
    
    
    override var dynamicSize:Bool {
        return true
    }
    
    
    
    override func measure(size: NSSize) {
        if let embedSize = content.embedSize {
            let size = embedSize.aspectFitted(NSMakeSize(min(size.width - 100, 800), min(size.height - 100, 800)))
            webview.setFrameSize(size)
            
            self.modal?.resize(with:size, animated: false)
            indicator.center()

        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        webview.removeFromSuperview()
        webview.frameLoadDelegate = nil
        webview.mainFrame.load(URLRequest(url: URL(string:"https://google.com")!))
       // webview.mainFrame.stopLoading()
      //  webView.stopLoading(nil)
      //  webView.removeFromSuperview()
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    func webView(_ sender: WebView!, didFinishLoadFor frame: WebFrame!) {
        webview.isHidden = false
        webview.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
        indicator.isHidden = true
        indicator.animates = false
    }
    
    init(content:TelegramMediaWebpageLoadedContent, account:Account) {
        self.content = content
        self.account = account
        super.init(frame:NSMakeRect(0,0,350,270))
    }
    
}

