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


class CreateChannelViewController: ComposeViewController<(PeerId?, Bool), Void, TableView> {

    private var nameItem:GroupNameRowItem!
    private var descItem:GeneralInputRowItem!
    private var picture: String? {
        didSet {
            nameItem.photo = picture
            genericView.reloadData(row: 0)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.nextEnabled(false)
        nameItem = GroupNameRowItem(atomicSize.modify({$0}), stableId: 0, account: account, placeholder: tr(L10n.channelChannelNameHolder), limit: 140, textChangeHandler:{ [weak self] text in
            self?.nextEnabled(!text.isEmpty)
        }, pickPicture: { [weak self] select in
            if let strongSelf = self, select {
                pickImage(for: mainWindow, completion: { image in
                    if let image = image {
                        _ = (putToTemp(image: image) |> deliverOnMainQueue).start(next: { [weak strongSelf] path in
                            strongSelf?.picture = path
                        })
                    }
                })
            } else {
                self?.picture = nil
            }
        })
        descItem = GeneralInputRowItem(atomicSize.modify({$0}), stableId: 2, placeholder: tr(L10n.channelDescriptionHolder), limit: 300, automaticallyBecomeResponder: false)
       
        _ = genericView.addItem(item: nameItem)
        _ = genericView.addItem(item: GeneralRowItem(atomicSize.modify({$0}), height: 30, stableId: 1))
        _ = genericView.addItem(item: descItem)
        _ = genericView.addItem(item: GeneralTextRowItem(atomicSize.modify({$0}), stableId: 3, text: tr(L10n.channelDescriptionHolderDescrpiton)))
        readyOnce()
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    
    override var removeAfterDisapper: Bool {
        return true
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        if let event = NSApp.currentEvent, let descView = genericView.viewNecessary(at: descItem.index) as? GeneralInputRowView {
            if !descView.textViewEnterPressed(event), window?.firstResponder == descView.textView.inputView {
                return .invokeNext
            }
        }
        
        return super.returnKeyAction()
    }
    
    override func executeNext() {
        let picture = self.picture
        let account = self.account
        
        if nameItem.text.isEmpty {
            nameItem.view?.shakeView()
            return
        }
        
        
        onComplete.set(showModalProgress(signal: createChannel(account: account, title: nameItem.text, description: descItem.text), for: window!, disposeAfterComplete: false) |> mapToSignal { peerId in
            if let peerId = peerId, let picture = picture {
                let resource = LocalFileReferenceMediaResource(localFilePath: picture, randomId: arc4random64())
                let signal:Signal<(PeerId?, Bool), Void> = updatePeerPhoto(account: account, peerId: peerId, resource: resource) |> mapError {_ in} |> map { value in
                    switch value {
                    case .complete:
                        return (Optional(peerId), false)
                    default:
                        return (nil, false)
                    }
                }
                
                return .single((peerId, true)) |> then(signal)
            }
            return .single((peerId, true))
        })
    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
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

    deinit {
        var bp:Int = 0
        bp += 1
    }
    
}
