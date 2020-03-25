//
//  ChatInfoTouchbar.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 18/09/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import SwiftSignalKit
import TGUIKit

@available(OSX 10.12.2, *)
fileprivate extension NSTouchBarItem.Identifier {
    static let edit = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chat-info.edit")
    static let share = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chat-info.share")

    static let sharedMediaAndInfo = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chat-info.sharedMediaAndInfo")
    static let userActions = NSTouchBarItem.Identifier("\(Bundle.main.bundleIdentifier!).touchBar.chat-info.userActions")

}

@available(OSX 10.12.2, *)
class ChatInfoTouchbar: NSTouchBar, NSTouchBarDelegate {
    private let chatInteraction: ChatInteraction
    private let dismiss:()->Void
    init(chatInteraction: ChatInteraction, dismiss: @escaping()->Void) {
        self.chatInteraction = chatInteraction
        self.dismiss = dismiss
        super.init()
        self.delegate = self
        guard let peer = chatInteraction.peer else {return}
        var items: [NSTouchBarItem.Identifier] = []
        items.append(.edit)
        if peer.isBot || (peer.isUser && (peer as! TelegramUser).phone != nil) || peer.addressName != nil {
            items.append(.share)
        }
        items.append(.flexibleSpace)
        items.append(.sharedMediaAndInfo)
        if peer.isUser && peer.id != chatInteraction.context.peerId, !peer.isBot {
            items.append(.userActions)
        }
        items.append(.flexibleSpace)
        self.defaultItemIdentifiers = items
        self.customizationAllowedItemIdentifiers = self.defaultItemIdentifiers
        self.customizationIdentifier = .popoverBar
    }
    
    @objc private func userInfoActions(_ sender: Any?) {
        guard let segment = sender as? NSSegmentedControl else {return}
        switch segment.selectedSegment {
        case 0:
            _ = showModalProgress(signal: createSecretChat(account: chatInteraction.context.account, peerId: chatInteraction.peerId) |> deliverOnMainQueue, for: mainWindow).start(next: { [weak self] peerId in
                if let strongSelf = self {
                    strongSelf.chatInteraction.context.sharedContext.bindings.rootNavigation().push(ChatController(context: strongSelf.chatInteraction.context, chatLocation: .peer(peerId)))
                }
            })
        case 1:
            let context = chatInteraction.context
            _ = (phoneCall(account: context.account, sharedContext: context.sharedContext, peerId: chatInteraction.peerId) |> deliverOnMainQueue).start(next: { result in
                applyUIPCallResult(context.sharedContext, result)
            })
        default:
            break
        }
        dismiss()
    }
    @objc private func editChat() {
        chatInteraction.update({$0.selectionState == nil ? $0.withSelectionState() : $0.withoutSelectionState()})
        dismiss()
    }
    @objc private func shareAction() {
        guard let peer = chatInteraction.peer else {return}

        if peer.isUser, let peer = peer as? TelegramUser {
            showModal(with: ShareModalController(ShareContactObject(chatInteraction.context, user: peer)), for: mainWindow)
        } else if let address = peer.addressName {
            showModal(with: ShareModalController(ShareLinkObject(chatInteraction.context, link: "https://t.me/\(address)")), for: mainWindow)
        }
        
        dismiss()
    }
    @objc private func sharedMediaAction() {
        chatInteraction.context.sharedContext.bindings.rootNavigation().push(PeerMediaController(context: chatInteraction.context, peerId: chatInteraction.peerId))
        dismiss()
    }
    @objc private func peerInfoActions(_ sender: Any?) {
        guard let segment = sender as? NSSegmentedControl else {return}
        switch segment.selectedSegment {
        case 0:
            chatInteraction.context.sharedContext.bindings.rootNavigation().push(PeerMediaController(context: chatInteraction.context, peerId: chatInteraction.peerId))
        case 1:
            chatInteraction.context.sharedContext.bindings.rootNavigation().push(PeerInfoController(context: chatInteraction.context, peerId: chatInteraction.peerId))
        default:
            break
        }
        dismiss()
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .edit:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: chatInteraction.presentation.selectionState != nil ? L10n.navigationCancel : L10n.navigationEdit, target: self, action: #selector(editChat))
            item.view = button
            item.customizationLabel = button.title
            return item
        case .share:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(image: NSImage(named: NSImage.Name("Icon_TouchBar_Share"))!, target: self, action: #selector(shareAction))
            item.view = button
            item.customizationLabel = button.title
            return item
        case .sharedMediaAndInfo:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let segment = NSSegmentedControl()
            segment.segmentStyle = .separated
            segment.segmentCount = 1
            segment.setImage(NSImage(named: NSImage.Name("Icon_TouchBar_AttachPhotoOrVideo"))!, forSegment: 0)
            segment.setLabel(L10n.telegramPeerMediaController, forSegment: 0)
            segment.trackingMode = .momentary
            segment.target = self
            segment.action = #selector(peerInfoActions(_:))
            item.view = segment
            return item
        case .userActions:
            let item = NSCustomTouchBarItem(identifier: identifier)
            guard let peer = chatInteraction.peer as? TelegramUser else {return nil}
            let segment = NSSegmentedControl()
            segment.segmentStyle = .separated
            segment.segmentCount = peer.canCall ? 2 : 1
            segment.setImage(NSImage(named: NSImage.Name("Icon_TouchBar_ComposeSecretChat"))!, forSegment: 0)
            segment.setImage(NSImage(named: NSImage.Name("Icon_TouchBar_Call"))!, forSegment: 1)
            segment.setLabel(L10n.touchBarStartSecretChat, forSegment: 0)
            segment.setLabel(L10n.touchBarCall, forSegment: 1)
            segment.trackingMode = .momentary
            segment.target = self
            segment.action = #selector(userInfoActions(_:))
            item.view = segment
            return item
        default:
            break
        }
        return nil
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
}
