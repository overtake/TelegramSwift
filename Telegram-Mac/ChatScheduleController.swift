//
//  ChatScheduleController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13/08/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import TGUIKit
import Postbox
import SwiftSignalKit

class ChatScheduleController: ChatController {
    private let focusTarget: ChatFocusTarget?
    override init(context: AccountContext, chatLocation:ChatLocation, mode: ChatMode = .scheduled, focusTarget: ChatFocusTarget? = nil, initialAction:ChatInitialAction? = nil, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>? = nil) {
        self.focusTarget = focusTarget
        super.init(context: context, chatLocation: chatLocation, mode: mode, focusTarget: focusTarget, initialAction: initialAction, chatLocationContextHolder: chatLocationContextHolder)
    }

    
    override var removeAfterDisapper: Bool {
        return true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

    }
    override func applyTransition(_ transition: TableUpdateTransition, initialData: ChatHistoryCombinedInitialData, isLoading: Bool, processedView: ChatHistoryView) {
        
        let removedItems = self.genericView.tableView.allItems.filter({ transition.deleted.contains($0.index) })
                
        super.applyTransition(transition, initialData: initialData, isLoading: isLoading, processedView: processedView)
        
        let currentItems = self.genericView.tableView.allItems.filter({ $0 is ChatRowItem })

        
        if !transition.inserted.isEmpty {
            let messages = transition.inserted.compactMap { ($1 as? ChatRowItem)?.messages }.reduce([], { $0 + $1 })
            let message = messages.first(where: { $0.id == self.focusTarget?.messageId })
            if let message, message.pendingProcessingAttribute != nil {
                self.genericView.showVideoProccessingTooltip(context: context, source: .proccessing(message), animated: true)
            }
        } else if !removedItems.isEmpty {
            let messages = removedItems.compactMap { ($0 as? ChatRowItem)?.messages }.reduce([], { $0 + $1 })
            
            let message = messages.first(where: { $0.id == self.focusTarget?.messageId })
            
            if let message, message.pendingProcessingAttribute != nil, currentItems.isEmpty {
                self.navigationController?.back()
                let controller = self.navigationController?.controller as? ChatController
                controller?.genericView.showVideoProccessingTooltip(context: context, source: .published(message), animated: true)
            } else if self.focusTarget == nil, let message = messages.first(where: { $0.pendingProcessingAttribute != nil }) {
                self.genericView.showVideoProccessingTooltip(context: context, source: .published(message), animated: true)
            }
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        chatInteraction.sendPlainText = { _ in
            
        }
        let context = self.context
        
        chatInteraction.requestMessageActionCallback = { _, _, _ in
            alert(for: context.window, info: strings().chatScheduledInlineButtonError)
        }
        
        chatInteraction.vote = { _, _, _ in
            alert(for: context.window, info: strings().chatScheduledInlineButtonError)
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
