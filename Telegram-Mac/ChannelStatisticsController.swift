//
//  ChannelStatisticsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22/02/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import WebKit



class ChannelStatisticsController: TelegramGenericViewController<WebView> {
    private let peerId:PeerId
    
    private let uniqueId:String = "_\(arc4random())"
    private let disposable = MetaDisposable()
    private let statsUrl: String
    init(_ context: AccountContext, _ peerId:PeerId, statsUrl: String) {
        self.peerId = peerId
        self.statsUrl = statsUrl
        super.init(context)
        load(with: statsUrl)
    }
    
    override var enableBack: Bool {
        return true
    }


    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        genericView.mainFrame.load(URLRequest(url: URL(string:"file://blank")!))
        genericView.mainFrame.stopLoading()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.wantsLayer = true
        readyOnce()
    }
    
    private func load(with url: String) {
        
        if let url = URL(string:url) {
            genericView.mainFrame.load(URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15))
        }
        
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
        disposable.dispose()
    }
    
}
