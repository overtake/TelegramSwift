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
    
    
    
    private let forwardMessages:[Message]
    private let hideNames: Bool
    init(forwardMessages:[Message], hideNames: Bool, context: AccountContext) {
        self.forwardMessages = forwardMessages
        self.hideNames = hideNames
        super.init(context: context)
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
            if let author = message.chatPeer(context.peerId) {
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
        
        //hideNames ? strings().chatInputForwardHidden :  names.joined(separator: ", ")
        
        let text = hideNames ? strings().chatAccessoryHiddenCountable(forwardMessages.count) : strings().chatAccessoryForwardCountable(forwardMessages.count)
        self.header = .init(.initialize(string: text, color: theme.colors.accent, font: .medium(.text)), maximumNumberOfLines: 1)
        if forwardMessages.count == 1, !forwardMessages[0].text.isEmpty, forwardMessages[0].media.isEmpty {
            let messageText = chatListText(account: context.account, for: forwardMessages[0], isPremium: context.isPremium, isReplied: true).mutableCopy() as! NSMutableAttributedString
            
            let author = forwardMessages[0].forwardInfo?.author ?? forwardMessages[0].effectiveAuthor
            
            if author?.id == context.peerId {
                messageText.insert(.initialize(string: "\(strings().chatAccessoryForwardYou): ", color: theme.colors.grayText, font: .normal(.text)), at: 0)
            } else if let author = author {
                messageText.insert(.initialize(string: "\(author.displayTitle): ", color: theme.colors.grayText, font: .normal(.text)), at: 0)
            }
            self.message = .init(messageText, maximumNumberOfLines: 1)
        } else {
            let authors = uniquePeers(from: forwardMessages.compactMap { $0.forwardInfo?.author ?? $0.effectiveAuthor })
            let messageText = authors.map { $0.compactDisplayTitle }.joined(separator: ", ")
            let text = "\(strings().chatAccessoryForwardFrom): \(messageText)"

            self.message = .init(.initialize(string: text, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        }

        nodeReady.set(.single(true))
        self.setNeedDisplay()
    }
    

}
