//
//  ChatScheduleController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13/08/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox

class ChatScheduleController: ChatController {
    public override init(context: AccountContext, chatLocation:ChatLocation, mode: ChatMode = .scheduled, messageId:MessageId? = nil, initialAction:ChatInitialAction? = nil) {
        super.init(context: context, chatLocation: chatLocation, mode: mode, messageId: messageId, initialAction: initialAction)
    }

    
    override var removeAfterDisapper: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        chatInteraction.sendPlainText = { _ in
            
        }
        let context = self.context
        
        chatInteraction.requestMessageActionCallback = { _, _, _ in
            alert(for: context.window, info: L10n.chatScheduledInlineButtonError)
        }
        
        chatInteraction.vote = { _, _, _ in
            alert(for: context.window, info: L10n.chatScheduledInlineButtonError)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        let controller = self.navigationController?.controller as? ChatController
        let current = self.chatInteraction.presentation.interfaceState
        
        let count = self.genericView.tableView.count
        
        controller?.chatInteraction.update(animated: false, { $0.withUpdatedHasScheduled(count > 1).updatedInterfaceState { _ in return current } })
        
    }
    
}
