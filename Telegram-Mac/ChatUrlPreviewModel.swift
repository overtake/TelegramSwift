//
//  ChatUrlPreviewModal.swift
//  Telegram
//
//  Created by keepcoder on 03/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac

class ChatUrlPreviewModel: ChatAccessoryModel {
    private let webpageDisposable = MetaDisposable()
    
    private (set) var webpage: TelegramMediaWebpage
    private let url:String
    init(account: Account, webpage: TelegramMediaWebpage, url:String) {
        self.webpage = webpage
        self.url = url
        super.init()
        self.updateWebpage()
    }
    
    deinit {
        self.webpageDisposable.dispose()
    }
    
    private func updateWebpage() {
        var authorName = ""
        var text = ""
        switch self.webpage.content {
        case .Pending:
            authorName = "Loading..."
            text = self.url
        case let .Loaded(content):
            if let title = content.websiteName {
                authorName = title
            } else if let websiteName = content.websiteName {
                authorName = websiteName
            } else {
                authorName = content.displayUrl
            }
            text = content.text ?? content.title ?? ""
        }
        
        self.headerAttr = .initialize(string: authorName, color: theme.colors.link, font: .medium(.text))
        self.messageAttr = .initialize(string: text, color: theme.colors.text, font: .normal(.text))
        
        nodeReady.set(.single(true))
        self.setNeedDisplay()
    }
}
