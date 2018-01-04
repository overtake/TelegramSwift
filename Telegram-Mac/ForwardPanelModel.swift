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
    private var forwardIds:[MessageId]
    private var forwardMessages:[Message] = []
    
    private var disposable:MetaDisposable = MetaDisposable()

    init(forwardIds:[MessageId], account:Account) {
        
        self.account = account
        self.forwardIds = forwardIds
        super.init()
        
        
        disposable.set((account.postbox.messagesAtIds(forwardIds)
            |> deliverOnMainQueue).start(next: { [weak self] result in
                if let strongSelf = self {
                    strongSelf.forwardMessages = result
                    strongSelf.make()
                }
        }))
    }
    
    deinit {
        disposable.dispose()
    }
    
    
    func make() -> Void {
        
        var names:[String] = []
        
        var used:Set<PeerId> = Set()
        
        
        
        
        for message in forwardMessages {
            
            var hasSource: Bool = false
            for attr in message.attributes {
                if let _ = attr as? SourceReferenceMessageAttribute {
                    if let info = message.forwardInfo {
                        if !used.contains(info.author.id) {
                            used.insert(info.author.id)
                            names.append(info.author.displayTitle)
                        }
                    }
                    hasSource = true
                    break
                }
            }
            if let peer = messageMainPeer(message), let author = message.author, !hasSource  {
                if !used.contains(author.id) {
                    used.insert(author.id)
                    if peer.isChannel {
                        names.append(peer.displayTitle)
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
