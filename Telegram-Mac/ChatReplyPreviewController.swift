//
//  ChatReplyPreviewController.swift
//  Telegram
//
//  Created by keepcoder on 04/09/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

class ChatReplyPreviewView : View {
    var container: ChatRowView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    func update(_ message: Message, account: Account, chatInteraction: ChatInteraction) {
        let item = ChatRowItem.item(frame.size, from: .MessageEntry(message, true, .Full(isAdmin: false), .FullHeader, nil), with: account, interaction: chatInteraction)
        _ = item.makeSize(frame.width, oldWidth: 0)
        
        container?.removeFromSuperview()
        let vz = item.viewClass() as! TableRowView.Type
        
        container = vz.init(frame:NSMakeRect(0, 0, NSWidth(self.frame), item.height)) as? ChatRowView
        
        container?.identifier = identifier
        addSubview(container!)
        
        container!.setFrameSize(NSMakeSize(frame.width, item.height))
        container!.set(item: item, animated: false)
        setFrameSize(NSMakeSize(frame.width, container!.frame.height + 12))
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        container?.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ChatReplyPreviewController: TelegramGenericViewController<ChatReplyPreviewView> {
    private let messageId: MessageId
    private let disposable = MetaDisposable()
    private let chatInteraction: ChatInteraction
    init(_ account: Account, messageId: MessageId, width: CGFloat) {
        self.messageId = messageId
        self.chatInteraction = ChatInteraction(peerId: messageId.peerId, account: account, isLogInteraction: true)
        super.init(account)
        _frameRect = NSMakeRect(0, 0, width, 0)
        bar = .init(height: 0)
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        disposable.set((account.postbox.messageView(messageId) |> deliverOnMainQueue).start(next: { [weak self] view in
            if let message = view.message, let strongSelf = self {
                self?.genericView.update(message, account: strongSelf.account, chatInteraction: strongSelf.chatInteraction)
                self?.readyOnce()
            }
        }))
    }
    
    deinit {
        disposable.dispose()
    }
    
}
