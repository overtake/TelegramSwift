//
//  CreateChannelViewController.swift
//  TelegramMac
//
//  Created by keepcoder on 26/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TGUIKit


class CreateChannelViewController: ComposeViewController<(PeerId?, Bool), Void, TableView> {

    private var nameItem:GroupNameRowItem!
    private var descItem:InputDataRowItem!
    private let disposable = MetaDisposable()
    private var picture: String? {
        didSet {
            nameItem.photo = picture
            genericView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.nextEnabled(false)
        
        genericView.getBackgroundColor = {
            theme.colors.listBackground
        }
        
        let initialSize = atomicSize.with { $0 }
        
        nameItem = GroupNameRowItem(initialSize, stableId: 0, account: context.account, placeholder: L10n.channelChannelNameHolder, viewType: .singleItem, limit: 140, textChangeHandler:{ [weak self] text in
            self?.nextEnabled(!text.isEmpty)
        }, pickPicture: { [weak self] select in
            if select {
                filePanel(with: photoExts, allowMultiple: false, canChooseDirectories: false, for: mainWindow, completion: { paths in
                    if let path = paths?.first, let image = NSImage(contentsOfFile: path) {
                        _ = (putToTemp(image: image, compress: true) |> deliverOnMainQueue).start(next: { path in
                            let controller = EditImageModalController(URL(fileURLWithPath: path), settings: .disableSizes(dimensions: .square))
                            showModal(with: controller, for: mainWindow, animationType: .scaleCenter)
                            _ = (controller.result |> deliverOnMainQueue).start(next: { url, _ in
                                self?.picture = url.path
                            })
                            
                            controller.onClose = {
                                removeFile(at: path)
                            }
                        })
                    }
                })
            } else {
                self?.picture = nil
            }
        })
        descItem = InputDataRowItem(initialSize, stableId: arc4random(), mode: .plain, error: nil, viewType: .singleItem, currentText: "", placeholder: nil, inputPlaceholder: L10n.channelDescriptionHolder, filter: { $0 }, updated: { _ in }, limit: 255)
       
    
        _ = genericView.addItem(item: GeneralRowItem(initialSize, height: 30, stableId: arc4random(), viewType: .separator))
        _ = genericView.addItem(item: GeneralTextRowItem(initialSize, stableId: arc4random(), text: L10n.channelNameHeader, viewType: .textTopItem))
        _ = genericView.addItem(item: nameItem)
        _ = genericView.addItem(item: GeneralRowItem(initialSize, height: 30, stableId: arc4random(), viewType: .separator))
        _ = genericView.addItem(item: GeneralTextRowItem(initialSize, stableId: arc4random(), text: L10n.channelDescHeader, viewType: .textTopItem))
        _ = genericView.addItem(item: descItem)
        _ = genericView.addItem(item: GeneralTextRowItem(initialSize, stableId: arc4random(), text: L10n.channelDescriptionHolderDescrpiton, viewType: .textBottomItem))
        _ = genericView.addItem(item: GeneralRowItem(initialSize, height: 30, stableId: arc4random(), viewType: .separator))
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
        
        if nameItem.currentText.isEmpty {
            nameItem.view?.shakeView()
            return
        }
        
        let signal: Signal<(PeerId, Bool)?, CreateChannelError> = showModalProgress(signal: createChannel(account: context.account, title: nameItem.currentText, description: descItem.currentText), for: window!, disposeAfterComplete: false) |> mapToSignal { peerId in
            if let picture = picture {
                let resource = LocalFileReferenceMediaResource(localFilePath: picture, randomId: arc4random64())
                let signal:Signal<(PeerId, Bool)?, CreateChannelError> = updatePeerPhoto(postbox: context.account.postbox, network: context.account.network, stateManager: context.account.stateManager, accountPeerId: context.peerId, peerId: peerId, photo: uploadedPeerPhoto(postbox: context.account.postbox, network: context.account.network, resource: resource), mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                }) |> mapError { _ in CreateChannelError.generic } |> map { value in
                    switch value {
                    case .complete:
                        return (peerId, false)
                    default:
                        return nil
                    }
                }
                
                return .single((peerId, true)) |> then(signal)
            }
            return .single((peerId, true))
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] value in
            if let value = value {
                self?.onComplete.set(.single((value.0, value.1)))
            }
        }, error: { error in
            let text: String
            switch error {
            case .generic:
                text = L10n.unknownError
            case .tooMuchJoined:
                showInactiveChannels(context: context, source: .create)
                return
            case let .serverProvided(t):
                text = t
            default:
                text = L10n.unknownError
            }
            alert(for: context.window, info: text)
        }))
        
    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override func firstResponder() -> NSResponder? {
        if let window = window {
            if let nameView = genericView.viewNecessary(at: nameItem.index) as? GroupNameRowView, let descView = genericView.viewNecessary(at: descItem.index) as? InputDataRowView {
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
        
    }
    
}

