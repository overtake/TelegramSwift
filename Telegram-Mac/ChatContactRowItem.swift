//
//  ChatContactRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 22/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
class ChatContactRowItem: ChatRowItem {

    let contactPeer:Peer?
    let text:TextViewLayout
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ account: Account, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings) {
        
        if let message = object.message, let contact = message.media[0] as? TelegramMediaContact {
            let attr = NSMutableAttributedString()

            let isIncoming: Bool = message.isIncoming(account, object.renderType == .bubble)

            if let peerId = contact.peerId {
                self.contactPeer = message.peers[peerId]
                let range = attr.append(string: contact.firstName + " " + contact.lastName, font: .medium(.text))
                attr.add(link: inAppLink.peerInfo(peerId:peerId,action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: theme.chat.linkColor(isIncoming, object.renderType == .bubble))
                _ = attr.append(string: "\n")
                _ = attr.append(string: formatPhoneNumber(contact.phoneNumber), color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .normal(.text))
            } else {
                self.contactPeer = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: 0), accessHash: nil, firstName: contact.firstName, lastName: contact.lastName, username: nil, phone: contact.phoneNumber, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
                _ = attr.append(string: contact.firstName + " " + contact.lastName, color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .medium(.text))
                _ = attr.append(string: "\n")
                _ = attr.append(string: formatPhoneNumber(contact.phoneNumber), color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .normal(.text))
            }
            text = TextViewLayout(attr, maximumNumberOfLines: 3, truncationType: .end, alignment: .left)
            text.interactions = globalLinkExecutor

        } else {
            fatalError("contact not found for item")
        }
        
        super.init(initialSize, chatInteraction, account, object, downloadSettings)
    }
    
    override var additionalLineForDateInBubbleState: CGFloat? {
        return rightSize.height
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        text.measure(width: width - 50)
        return NSMakeSize(text.layoutSize.width + 50, 40)
    }
    
    override func viewClass() -> AnyClass {
        return ChatContactRowView.self
    }

}


class ChatContactRowView : ChatRowView {
    
    private let photoView:AvatarControl = AvatarControl(font: .avatar(.title))
    private let textView:TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(photoView)
        photoView.setFrameSize(40,40)
        textView.isSelectable = false
        addSubview(textView)
    }
    
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = contentColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        if let item = self.item as? ChatContactRowItem {
            textView.update(item.text)
            textView.centerY(x:50)
        }

    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? ChatContactRowItem {
            photoView.setPeer(account: item.account, peer: item.contactPeer)
            photoView.removeAllHandlers()
            if let peerId = item.contactPeer?.id {
                photoView.set(handler: { control in
                    item.chatInteraction.openInfo(peerId, false , nil, nil)
                }, for: .Click)
            }
            
        }
        
    }
    
}
