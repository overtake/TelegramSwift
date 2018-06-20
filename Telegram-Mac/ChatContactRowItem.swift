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
    let phoneLayout:TextViewLayout
    let nameLayout: TextViewLayout
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ account: Account, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings) {
        
        if let message = object.message, let contact = message.media[0] as? TelegramMediaContact {
            let attr = NSMutableAttributedString()

            let isIncoming: Bool = message.isIncoming(account, object.renderType == .bubble)

            if let peerId = contact.peerId {
                self.contactPeer = message.peers[peerId]
                let range = attr.append(string: contact.firstName + " " + contact.lastName, font: .medium(.text))
                attr.add(link: inAppLink.peerInfo(peerId:peerId,action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: theme.chat.linkColor(isIncoming, object.renderType == .bubble))
                phoneLayout = TextViewLayout(.initialize(string: formatPhoneNumber(contact.phoneNumber), color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .normal(.text)), maximumNumberOfLines: 1, truncationType: .end, alignment: .left)

            } else {
                self.contactPeer = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: 0), accessHash: nil, firstName: contact.firstName, lastName: contact.lastName, username: nil, phone: contact.phoneNumber, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
                _ = attr.append(string: contact.firstName + " " + contact.lastName, color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .medium(.text))
                
                phoneLayout = TextViewLayout(.initialize(string: formatPhoneNumber(contact.phoneNumber), color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .normal(.text)), maximumNumberOfLines: 1, truncationType: .end, alignment: .left)
            }
            nameLayout = TextViewLayout(attr, maximumNumberOfLines: 1)
            nameLayout.interactions = globalLinkExecutor
            
        } else {
            fatalError("contact not found for item")
        }
        
        super.init(initialSize, chatInteraction, account, object, downloadSettings)
    }
    
    override var additionalLineForDateInBubbleState: CGFloat? {
        if let line = phoneLayout.lines.last, (line.frame.width + 50) > realContentSize.width - (rightSize.width + insetBetweenContentAndDate) {
            return rightSize.height
        }
        return nil
    }
    
    override var isFixedRightPosition: Bool {
        if let line = phoneLayout.lines.last, (line.frame.width + 50) < contentSize.width - (rightSize.width + insetBetweenContentAndDate) {
            return true
        }
        return super.isForceRightLine
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        nameLayout.measure(width: width - 50)
        phoneLayout.measure(width: width - 50)
        return NSMakeSize(max(nameLayout.layoutSize.width, phoneLayout.layoutSize.width) + 50, 40)
    }
    
    override func viewClass() -> AnyClass {
        return ChatContactRowView.self
    }

}


class ChatContactRowView : ChatRowView {
    
    private let photoView:AvatarControl = AvatarControl(font: .avatar(.title))
    private let nameView: TextView = TextView()
    private let phoneView: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(photoView)
        photoView.setFrameSize(40,40)
        nameView.isSelectable = false
        addSubview(nameView)
        
        phoneView.isSelectable = false
        addSubview(phoneView)
    }
    
    override func updateColors() {
        super.updateColors()
        nameView.backgroundColor = contentColor
        phoneView.backgroundColor = contentColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        let mid = contentView.frame.height / 2
        nameView.setFrameOrigin(50, mid - nameView.frame.height - 1)
        phoneView.setFrameOrigin(50, mid + 1)
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
            nameView.update(item.nameLayout)
            phoneView.update(item.phoneLayout)
        }
    }
    
}
