//
//  QuoteView.swift
//  Telegram
//
//  Created by Mike Renoir on 03.10.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit

/*
 private(set) var replyMessage:Message?
 private var disposable:MetaDisposable = MetaDisposable()
 private let isPinned:Bool
 private var previousMedia: Media?
 private var isLoading: Bool = false
 private let fetchDisposable = MetaDisposable()
 private let makesizeCallback:(()->Void)?
 private let autodownload: Bool
 private let headerAsName: Bool
 private let customHeader: String?
 private let translate: ChatLiveTranslateContext.State.Result?
 init(replyMessageId:MessageId, context: AccountContext, replyMessage:Message? = nil, isPinned: Bool = false, autodownload: Bool = false, presentation: ChatAccessoryPresentation? = nil, headerAsName: Bool = false, customHeader: String? = nil, drawLine: Bool = true, makesizeCallback: (()->Void)? = nil, dismissReply: (()->Void)? = nil, translate: ChatLiveTranslateContext.State.Result? = nil) {

 */
//
//final class ChatReplyData {
//    private let parent: Message
//    private let replyMessage: Message
//    private let context: AccountContext
//    private let presentation: ChatAccessoryPresentation?
//    init(parent: Message, replyMessage: Message, context: AccountContext, presentation: ChatAccessoryPresentation? = nil, translate: ChatLiveTranslateContext.State.Result?) {
//        self.parent = parent
//        self.replyMessage = replyMessage
//        self.context = context
//        self.presentation = presentation
//    }
//}
//
//
//class Updated_ReplyView : Control {
//    
//    private let imageView = ImageView()
//    private let textView = TextView()
//    private let container = View()
//    private let line = View()
//    
//
//    required init(frame frameRect: NSRect) {
//        super.init(frame: frameRect)
//        addSubview(container)
//        container.addSubview(line)
//        container.addSubview(textView)
//        container.addSubview(imageView)
//        container.layer?.cornerRadius = .cornerRadius
//        textView.userInteractionEnabled = false
//        textView.isSelectable = false
//        
//        
//        layer?.masksToBounds = false
//    
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    
//    
//    private func updateColors() {
//        self.container.backgroundColor = theme.colors.accent.withAlphaComponent(0.2)
//        self.line.backgroundColor = theme.colors.accent
//        self.imageView.image = theme.icons.message_quote_accent
//        self.imageView.sizeToFit()
//    }
//    
//    override func updateLocalizationAndTheme(theme: PresentationTheme) {
//        super.updateLocalizationAndTheme(theme: theme)
//        updateColors()
//    }
//    
//    func set() {
//        self.updateLocalizationAndTheme(theme: theme)
//        self.update(attachment)
//    }
//    
//    func measure(_ textSize: NSSize) -> NSSize {
//        self.textView.resize(textSize.width - 41)
//        return NSMakeSize(textSize.width, self.textView.frame.height + 10 + 8)
//    }
//    
//    func update(_ attachment: ChatReplyData) {
//        self.textView.update(attachment.layout)
//        needsLayout = true
//    }
//    
//    override func setFrameSize(_ newSize: NSSize) {
//        super.setFrameSize(newSize)
//    }
//    
//    override func layout() {
//        super.layout()
//        self.container.setFrameSize(NSMakeSize(frame.width - 6, self.textView.frame.height + 10))
//        self.container.centerY(x: 6)
//        self.textView.centerY(x: 15)
//        self.imageView.setFrameOrigin(NSMakePoint(container.frame.width - imageView.frame.width - 5, 4))
//        self.line.frame = NSMakeRect(0, 0, 4, container.frame.height)
//    }
//}
