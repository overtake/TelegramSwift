//
//  ForwardChatListController.swift
//  TelegramMac
//
//  Created by keepcoder on 05/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
class ForwardChatListController: ChatListController {
    override func getLeftBarViewOnce() -> BarView {
        let button = TextButtonBarView(controller: self, text: tr(L10n.chatCancel))
        
        button.set(handler: { [weak self] _ in
            self?.navigationController?.removeModalAction()
            self?.navigationController?.back()
        }, for: .Click)
        
        return button
    }
    
    override func getRightBarViewOnce() -> BarView {
        return BarView(controller: self)
    }
    
    init(_ context: AccountContext) {
        super.init(context, modal:true)
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        navigationController?.removeModalAction()
        return .rejected
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

}
