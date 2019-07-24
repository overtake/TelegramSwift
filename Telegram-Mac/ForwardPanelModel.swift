//
//  ForwardPanelModel.swift
//  Telegram-Mac
//
//  Created by keepcoder on 01/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac
class ForwardPanelModel: ChatAccessoryModel {
    
    
    
    private var account:Account
    private var forwardMessages:[Message] = []
    
    init(forwardMessages:[Message], account:Account) {
        
        self.account = account
        self.forwardMessages = forwardMessages
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
        
        self.headerAttr = NSAttributedString.initialize(string: names.joined(separator: ", "), color: theme.colors.blueUI, font: .medium(.text))
        self.messageAttr = NSAttributedString.initialize(string: tr(L10n.messageAccessoryPanelForwardedCountable(forwardMessages.count)), color: theme.colors.text, font: .normal(.text))

        nodeReady.set(.single(true))
        self.setNeedDisplay()
    }
    

}
