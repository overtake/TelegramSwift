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
    init(account:Account, peerId:PeerId, fallbackId:PeerId, initialAction:ChatInitialAction? = nil) {
        self.fallbackId = fallbackId
        super.init(account: account, chatLocation: .peer(peerId), initialAction: initialAction)
    }
    
    override var removeAfterDisapper: Bool {
        return true
    }
    
    override open func backSettings() -> (String,CGImage?) {
        return (tr(L10n.navigationCancel),nil)
    }
    
    override func applyTransition(_ transition: TableUpdateTransition, initialData: ChatHistoryCombinedInitialData, wallpaper: TelegramWallpaper) {
        super.applyTransition(transition, initialData: initialData, wallpaper: wallpaper)
        
        if case let .none(interface) = transition.state, let _ = interface {
            for (_, item) in transition.inserted {
                if let item = item as? ChatRowItem, let message = item.message {
                    for attribute in message.attributes {
                        if let attribute = attribute as? ReplyMarkupMessageAttribute {
                            for row in attribute.rows {
                                for button in row.buttons {
                                    if case let .switchInline(samePeer: _, query: query) = button.action {
                                        let text = "@\(message.inlinePeer?.username ?? "") \(query)"
                                        self.navigationController?.push(ChatController(account: account, chatLocation: .peer(fallbackId), initialAction: .inputText(text: text, behavior: .automatic)))
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
