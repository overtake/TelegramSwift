//
//  ChatSwitchInlineController.swift
//  TelegramMac
//
//  Created by keepcoder on 13/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore

import SwiftSignalKit



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
        return (strings().navigationCancel,nil)
    }
    
    override func applyTransition(_ transition:TableUpdateTransition, initialData:ChatHistoryCombinedInitialData, isLoading: Bool, processedView: ChatHistoryView) {
        super.applyTransition(transition, initialData: initialData, isLoading: isLoading, processedView: processedView)
        
        if case let .none(interface) = transition.state, let _ = interface {
            for (_, item) in transition.inserted {
                if let item = item as? ChatRowItem, let message = item.message {
                    for attribute in message.attributes {
                        if let attribute = attribute as? ReplyMarkupMessageAttribute {
                            for row in attribute.rows {
                                for button in row.buttons {
                                    if case let .switchInline(samePeer: _, query: query, _) = button.action {
                                        let text = "@\(message.inlinePeer?.username ?? "") \(query)"
                                        let controller: ChatController
                                        switch self.fallbackMode {
                                        case .history, .pinned:
                                            controller = ChatController(context: context, chatLocation: .peer(fallbackId), initialAction: .inputText(text: .init(inputText: text), behavior: .automatic))
                                        case let .thread(mode):
                                            controller = ChatController(context: context, chatLocation: .peer(fallbackId), mode: .thread(mode: mode), initialAction: .inputText(text: .init(inputText: text), behavior: .automatic), chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil))
                                        case .scheduled:
                                            controller = ChatScheduleController(context: context, chatLocation: .peer(fallbackId), initialAction: .inputText(text: .init(inputText: text), behavior: .automatic))
                                        case .customChatContents, .customLink, .preview:
                                            fatalError()
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
