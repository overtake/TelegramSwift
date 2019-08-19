//
//  ChatSwitchInlineController.swift
//  TelegramMac
//
//  Created by keepcoder on 13/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac



class ChatSwitchInlineController: ChatController {
    private let fallbackId:PeerId
    private let fallbackMode: ChatMode
    init(context:AccountContext, peerId:PeerId, fallbackId:PeerId, fallbackMode: ChatMode, initialAction:ChatInitialAction? = nil) {
        self.fallbackId = fallbackId
        self.fallbackMode = fallbackMode
        super.init(context: context, chatLocation: .peer(peerId), initialAction: initialAction)
    }
    
    override var removeAfterDisapper: Bool {
        return true
    }
    
    override open func backSettings() -> (String,CGImage?) {
        return (L10n.navigationCancel,nil)
    }
    
    override func applyTransition(_ transition:TableUpdateTransition, view: MessageHistoryView?, initialData:ChatHistoryCombinedInitialData, isLoading: Bool) {
        super.applyTransition(transition, view: view, initialData: initialData, isLoading: isLoading)
        
        if case let .none(interface) = transition.state, let _ = interface {
            for (_, item) in transition.inserted {
                if let item = item as? ChatRowItem, let message = item.message {
                    for attribute in message.attributes {
                        if let attribute = attribute as? ReplyMarkupMessageAttribute {
                            for row in attribute.rows {
                                for button in row.buttons {
                                    if case let .switchInline(samePeer: _, query: query) = button.action {
                                        let text = "@\(message.inlinePeer?.username ?? "") \(query)"
                                        let controller: ChatController
                                        switch self.fallbackMode {
                                        case .history:
                                            controller = ChatController(context: context, chatLocation: .peer(fallbackId), initialAction: .inputText(text: text, behavior: .automatic))
                                        case .scheduled:
                                            controller = ChatScheduleController(context: context, chatLocation: .peer(fallbackId), initialAction: .inputText(text: text, behavior: .automatic))
                                        }
                                        self.navigationController?.push(controller)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
}
