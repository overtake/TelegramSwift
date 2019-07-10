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
        nameItem = GroupNameRowItem(atomicSize.modify({$0}), stableId: 0, account: context.account, placeholder: L10n.channelChannelNameHolder, limit: 140, textChangeHandler:{ [weak self] text in
            self?.nextEnabled(!text.isEmpty)
        }, pickPicture: { [weak self] select in
            if select {
                filePanel(with: photoExts, allowMultiple: false, canChooseDirectories: false, for: mainWindow, completion: { paths in
                    if let path = paths?.first, let image = NSImage(contentsOfFile: path) {
                        _ = (putToTemp(image: image, compress: true) |> deliverOnMainQueue).start(next: { path in
                            let controller = EditImageModalController(URL(fileURLWithPath: path), settings: .disableSizes(dimensions: .square))
                            showModal(with: controller, for: mainWindow)
                            _ = (controller.result |> deliverOnMainQueue).start(next: { url, _ in
                                self?.picture = url.path
                            })
                            
                            controller.onClose = {
                                removeFile(at: path)
                            }
                        })
                    }
                })
                
//                pickImage(for: mainWindow, completion: { image in
//                    if let image = image {
//                        _ = (putToTemp(image: image) |> deliverOnMainQueue).start(next: { [weak strongSelf] path in
//                            strongSelf?.picture = path
//                        })
//                    }
//                })
            } else {
                self?.picture = nil
            }
        })
        descItem = GeneralInputRowItem(atomicSize.modify({$0}), stableId: 2, placeholder: L10n.channelDescriptionHolder, limit: 300, automaticallyBecomeResponder: false)
       
        _ = genericView.addItem(item: nameItem)
        _ = genericView.addItem(item: GeneralRowItem(atomicSize.modify({$0}), height: 30, stableId: 1))
        _ = genericView.addItem(item: descItem)
        _ = genericView.addItem(item: GeneralTextRowItem(atomicSize.modify({$0}), stableId: 3, text: L10n.channelDescriptionHolderDescrpiton))
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
        let context = self.context
        
        if nameItem.text.isEmpty {
            nameItem.view?.shakeView()
            return
        }
        
        
        onComplete.set(showModalProgress(signal: createChannel(account: context.account, title: nameItem.text, description: descItem.text), for: window!, disposeAfterComplete: false) |> map(Optional.init) |> `catch` { _ in return .single(nil) } |> mapToSignal { peerId in
            if let peerId = peerId, let picture = picture {
                let resource = LocalFileReferenceMediaResource(localFilePath: picture, randomId: arc4random64())
                let signal:Signal<(PeerId?, Bool), NoError> = updatePeerPhoto(postbox: context.account.postbox, network: context.account.network, stateManager: context.account.stateManager, accountPeerId: context.peerId, peerId: peerId, photo: uploadedPeerPhoto(postbox: context.account.postbox, network: context.account.network, resource: resource), mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                }) |> `catch` {_ in return .complete()} |> map { value in
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
