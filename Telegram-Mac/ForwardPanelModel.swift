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
        
        self.headerAttr = NSAttributedString.initialize(string: hideNames ? L10n.chatInputForwardHidden :  names.joined(separator: ", "), color: theme.colors.accent, font: .medium(.text))
        if forwardMessages.count == 1, !forwardMessages[0].text.isEmpty, forwardMessages[0].media.isEmpty {
            self.messageAttr = NSAttributedString.initialize(string: forwardMessages[0].text, color: theme.colors.text, font: .normal(.text))
        } else {
            self.messageAttr = NSAttributedString.initialize(string: L10n.messageAccessoryPanelForwardedCountable(forwardMessages.count), color: theme.colors.text, font: .normal(.text))
        }

        nodeReady.set(.single(true))
        self.setNeedDisplay()
    }
    

}
