//
//  ChatSuggestMessagesController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25.04.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//


import Cocoa
import TelegramCore
import TGUIKit
import Postbox
import SwiftSignalKit

class ChatSuggestMessagesController: ChatController {
  
    
    
    override var removeAfterDisapper: Bool {
        return true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

    }
    override func applyTransition(_ transition: TableUpdateTransition, initialData: ChatHistoryCombinedInitialData, isLoading: Bool, processedView: ChatHistoryView) {
        
                
        super.applyTransition(transition, initialData: initialData, isLoading: isLoading, processedView: processedView)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
}
