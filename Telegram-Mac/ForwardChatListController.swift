//
//  ForwardChatListController.swift
//  TelegramMac
//
//  Created by keepcoder on 05/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
class ForwardChatListController: ChatListController {
    override func getLeftBarViewOnce() -> BarView {
        let button = TextButtonBarView(controller: self, text: tr(L10n.chatCancel))
        
        button.set(handler: { [weak self] _ in
            self?.navigationController?.back()
            }, for: .Click)
        
        return button
    }
    
    override func getRightBarViewOnce() -> BarView {
        return BarView(controller: self)
    }
    
    init(_ account: Account) {
        super.init(account, modal:true)
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        return .rejected
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

}
