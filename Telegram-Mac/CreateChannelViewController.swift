//
//  CreateChannelViewController.swift
//  TelegramMac
//
//  Created by keepcoder on 26/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit


class CreateChannelViewController: ComposeViewController<PeerId?, Void, TableView> {

    private var nameItem:GroupNameRowItem!
    private var descItem:GeneralInputRowItem!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.nextEnabled(false)
        nameItem = GroupNameRowItem(atomicSize.modify({$0}), stableId: 0, placeholder: tr(.channelChannelNameHolder), limit: 140, textChangeHandler:{ [weak self] text in
            self?.nextEnabled(!text.isEmpty)
        })
        descItem = GeneralInputRowItem(atomicSize.modify({$0}), stableId: 2, placeholder: tr(.channelDescriptionHolder), limit: 300)
       
        _ = genericView.addItem(item: nameItem)
        _ = genericView.addItem(item: GeneralRowItem(atomicSize.modify({$0}), height: 30, stableId: 1))
        _ = genericView.addItem(item: descItem)
        _ = genericView.addItem(item: GeneralTextRowItem(atomicSize.modify({$0}), stableId: 3, text: tr(.channelDescriptionHolderDescrpiton)))
        readyOnce()
    }
    
    override var removeAfterDisapper: Bool {
        return true
    }
    
    override func executeNext() {
        onComplete.set(showModalProgress(signal: createChannel(account: account, title: nameItem.text, description: descItem.text), for: window!))
    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool? {
        return false
    }
    
    override func firstResponder() -> NSResponder? {
        if let window = window {
            if let nameView = genericView.viewNecessary(at: nameItem.index) as? GroupNameRowView, let descView = genericView.viewNecessary(at: descItem.index) as? GeneralInputRowView {
                nameView.textView.inputView.nextKeyView = descView.textView.inputView
                nameView.textView.inputView.nextResponder = descView.textView.inputView
                if window.firstResponder != nameView.textView.inputView && window.firstResponder != descView.textView.inputView {
                    return nameView.textView
                }
            }
        }
        
        return nil
    }

    
}
