//
//  ChatUrlPreviewModal.swift
//  Telegram
//
//  Created by keepcoder on 03/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore


class ChatUrlPreviewModel: ChatAccessoryModel {
    private let webpageDisposable = MetaDisposable()
    
    private (set) var webpage: TelegramMediaWebpage
    private let url:String
    init(context: AccountContext, webpage: TelegramMediaWebpage, url:String) {
        self.webpage = webpage
        self.url = url
        super.init(context: context)
        self.updateWebpage()
    }
    
    override var modelType: ChatAccessoryModel.ModelType {
        return .classic
    }
    
    deinit {
        self.webpageDisposable.dispose()
    }
    
    private func updateWebpage() {
        var authorName = ""
        var text = ""
        var isEmptyText: Bool = false
        switch self.webpage.content {
        case .Pending:
            authorName = strings().chatInlineRequestLoading
            text = self.url
        case let .Loaded(content):
            if let title = content.websiteName {
                authorName = title
            } else if let websiteName = content.websiteName {
                authorName = websiteName
            } else {
                authorName = content.displayUrl
            }
            if content.text == nil && content.title == nil {
                isEmptyText = true
            }
            text = content.text ?? content.title ?? strings().chatEmptyLinkPreview
        }
        
        self.header = .init(.initialize(string: authorName, color: theme.colors.accent, font: .medium(.text)), maximumNumberOfLines: 1)
        self.message = .init(.initialize(string: text, color: isEmptyText ? theme.colors.grayText : theme.colors.text, font: .normal(.text)), maximumNumberOfLines: 1)
        
        nodeReady.set(.single(true))
        self.setNeedDisplay()
    }
}
