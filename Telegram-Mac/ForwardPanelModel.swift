//
//  ForwardPanelModel.swift
//  Telegram-Mac
//
//  Created by keepcoder on 01/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore

class ForwardPanelModel: ChatAccessoryModel {
    
    
    
    private let account:Account
    private let forwardMessages:[Message]
    private let hideNames: Bool
    init(forwardMessages:[Message], hideNames: Bool, account:Account) {
        self.account = account
        self.forwardMessages = forwardMessages
        self.hideNames = hideNames
        super.init()
        self.make()
    }
    deinit {
    }
    
    
    func make() -> Void {
        
        var names:[String] = []
        
        var used:Set<PeerId> = Set()
        
        var keys:[Int64:Int64] = [:]
        var forwardMessages:[Message] = []
        for message in self.forwardMessages {
            if let groupingKey = message.groupingKey {
                if keys[groupingKey] == nil {
                    keys[groupingKey] = groupingKey
                    forwardMessages.append(message)
                }
            } else {
                forwardMessages.append(message)
            }
        }
        
        
        for message in forwardMessages {
            if let author = message.chatPeer(account.peerId) {
                if !used.contains(author.id) {
                    used.insert(author.id)
                    if author.isChannel {
                        names.append(author.displayTitle)
                    } else {
                        names.append(author.displayTitle)
                    }
                }
            }
        }
        
        //hideNames ? L10n.chatInputForwardHidden :  names.joined(separator: ", ")
        
        let text = hideNames ? L10n.chatAccessoryHiddenCountable(forwardMessages.count) : L10n.chatAccessoryForwardCountable(forwardMessages.count)
        self.headerAttr = NSAttributedString.initialize(string: text, color: theme.colors.accent, font: .medium(.text))
        if forwardMessages.count == 1, !forwardMessages[0].text.isEmpty, forwardMessages[0].media.isEmpty {
            let text: String
            let messageText = chatListText(account: account, for: forwardMessages[0]).string
            if forwardMessages[0].effectiveAuthor?.id == account.peerId {
                text = "\(L10n.chatAccessoryForwardYou): \(messageText)"
            } else if let author = forwardMessages[0].effectiveAuthor {
                text = "\(author.displayTitle): \(messageText)"
            } else {
                text = messageText
            }
            self.messageAttr = NSAttributedString.initialize(string: text, color: theme.colors.grayText, font: .normal(.text))
        } else {
            let authors = uniquePeers(from: forwardMessages.compactMap { $0.effectiveAuthor })
            let messageText = authors.map { $0.compactDisplayTitle }.joined(separator: ", ")
            let text = "\(L10n.chatAccessoryForwardFrom): \(messageText)"

            self.messageAttr = NSAttributedString.initialize(string: text, color: theme.colors.grayText, font: .normal(.text))
        }

        nodeReady.set(.single(true))
        self.setNeedDisplay()
    }
    

}
