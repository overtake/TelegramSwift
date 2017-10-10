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
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ account: Account, _ object: ChatHistoryEntry) {
        
        if let message = object.message, let contact = message.media[0] as? TelegramMediaContact {
            let attr = NSMutableAttributedString()

            if let peerId = contact.peerId {
                self.contactPeer = message.peers[peerId]
                let range = attr.append(string: contact.firstName + " " + contact.lastName, color: theme.colors.link, font: .medium(.text))
                attr.add(link: inAppLink.peerInfo(peerId:peerId,action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range)
                _ = attr.append(string: "\n")
                _ = attr.append(string: formatPhoneNumber(contact.phoneNumber), color: theme.colors.text, font: .normal(.text))
            } else {
                self.contactPeer = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: 0), accessHash: nil, firstName: contact.firstName, lastName: contact.lastName, username: nil, phone: contact.phoneNumber, photo: [], botInfo: nil, flags: [])
                _ = attr.append(string: contact.firstName + " " + contact.lastName, color: theme.colors.text, font: .medium(.text))
                _ = attr.append(string: "\n")
                _ = attr.append(string: formatPhoneNumber(contact.phoneNumber), color: theme.colors.text, font: .normal(.text))
            }
            text = TextViewLayout(attr, maximumNumberOfLines: 3, truncationType: .end, alignment: .left)
            text.interactions = globalLinkExecutor

        } else {
            fatalError("contact not found for item")
        }
        
        super.init(initialSize, chatInteraction, account, object)
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        text.measure(width: width - 60)
        return NSMakeSize(text.layoutSize.width + 60, 50)
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
        photoView.setFrameSize(50,50)
        textView.isSelectable = false
        addSubview(textView)
    }
    
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = backdorColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        if let item = self.item as? ChatContactRowItem {
            textView.update(item.text)
            textView.centerY(x:60)
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
