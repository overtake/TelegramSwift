//
//  ChatContactRowItem.swift
//  TelegramMac
//
//  Created by keepcoder on 22/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import InAppSettings
import Postbox
import SwiftSignalKit
import Contacts

class ChatContactRowItem: ChatRowItem {

    let contactPeer:Peer?
    let phoneLayout:TextViewLayout
    let nameLayout: TextViewLayout
    let vCard: CNContact?
    let contact: TelegramMediaContact
    let appearance: WPLayoutPresentation
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ context: AccountContext, _ object: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        
        if let message = object.message, let contact = message.media[0] as? TelegramMediaContact {
            let attr = NSMutableAttributedString()
            
            let isIncoming: Bool = message.isIncoming(context.account, object.renderType == .bubble)

            
            self.appearance = WPLayoutPresentation(text: theme.chat.textColor(isIncoming, object.renderType == .bubble), activity: theme.chat.webPreviewActivity(isIncoming, object.renderType == .bubble), link: theme.chat.linkColor(isIncoming, object.renderType == .bubble), selectText: theme.chat.selectText(isIncoming, object.renderType == .bubble), ivIcon: theme.chat.instantPageIcon(isIncoming, object.renderType == .bubble, presentation: theme), renderType: object.renderType)

            
            if let _ = contact.vCardData?.data(using: .utf8) {
                //let contacts = try? CNContactVCardSerialization.contacts(with: vCard)
                self.vCard = nil
            } else {
                self.vCard = nil
            }
            self.contact = contact
            
            let name = isNotEmptyStrings([contact.firstName + (!contact.firstName.isEmpty ? " " : "") + contact.lastName, vCard?.givenName, vCard?.organizationName])



            if let peerId = contact.peerId {
                self.contactPeer = message.peers[peerId]
                let range = attr.append(string: name, font: .medium(.text))
                attr.add(link: inAppLink.peerInfo(link: "", peerId:peerId,action:nil, openChat: false, postId: nil, callback: chatInteraction.openInfo), for: range, color: theme.chat.linkColor(isIncoming, object.renderType == .bubble))
                phoneLayout = TextViewLayout(.initialize(string: formatPhoneNumber(contact.phoneNumber), color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .normal(.text)), maximumNumberOfLines: 1, truncationType: .end, alignment: .left)

            } else {
                self.contactPeer = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(0)), accessHash: nil, firstName: name.components(separatedBy: " ").first ?? name, lastName: name.components(separatedBy: " ").count == 2 ? name.components(separatedBy: " ").last : "", username: nil, phone: contact.phoneNumber, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [])
                _ = attr.append(string: name, color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .medium(.text))
                
                phoneLayout = TextViewLayout(.initialize(string: formatPhoneNumber(contact.phoneNumber), color: theme.chat.textColor(isIncoming, object.renderType == .bubble), font: .normal(.text)), maximumNumberOfLines: 1, truncationType: .end, alignment: .left)
            }
            nameLayout = TextViewLayout(attr, maximumNumberOfLines: 1)
            nameLayout.interactions = globalLinkExecutor
            
        } else {
            fatalError("contact not found for item")
        }
        
        super.init(initialSize, chatInteraction, context, object, downloadSettings, theme: theme)
    }
    
    override var isForceRightLine: Bool {
        if let line = phoneLayout.lines.last, (line.frame.width + 50) > realContentSize.width - (rightSize.width + insetBetweenContentAndDate) {
            return true
        }
        return super.isForceRightLine
    }   
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        nameLayout.measure(width: width - 50)
        phoneLayout.measure(width: width - 50)
        return NSMakeSize(max(nameLayout.layoutSize.width, phoneLayout.layoutSize.width) + 50, 40 + (vCard != nil ? 36 : 0))
    }
    
    override func viewClass() -> AnyClass {
        return ChatContactRowView.self
    }

}


class ChatContactRowView : ChatRowView {
    
    private let contactPhotoView:AvatarControl = AvatarControl(font: .avatar(.title))
    private let nameView: TextView = TextView()
    private let phoneView: TextView = TextView()
    private var actionButton: TitleButton?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(contactPhotoView)
        contactPhotoView.setFrameSize(40,40)
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
        nameView.setFrameOrigin(50, contactPhotoView.frame.minY + 3)
        phoneView.setFrameOrigin(50, nameView.frame.maxY + 1)
        
        actionButton?.setFrameOrigin(0, contactPhotoView.frame.maxY + 6)

        
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? ChatContactRowItem {
            contactPhotoView.setPeer(account: item.context.account, peer: item.contactPeer)
            contactPhotoView.removeAllHandlers()
            if let peerId = item.contactPeer?.id {
                contactPhotoView.set(handler: { [weak item] control in
                    item?.chatInteraction.openInfo(peerId, false , nil, nil)
                }, for: .Click)
            }
            

            
            nameView.update(item.nameLayout)
            phoneView.update(item.phoneLayout)
            
            if let _ = item.vCard {
                if actionButton == nil {
                    actionButton = TitleButton()
                    actionButton?.layer?.cornerRadius = .cornerRadius
                    actionButton?.layer?.borderWidth = 1
                    actionButton?.disableActions()
                    actionButton?.set(font: .normal(.text), for: .Normal)
                    addSubview(actionButton!)
                }
                actionButton?.removeAllHandlers()
                actionButton?.set(text: strings().chatViewContact, for: .Normal)
                actionButton?.layer?.borderColor = item.appearance.activity.cgColor
                actionButton?.set(color: item.appearance.activity, for: .Normal)
                _ = actionButton?.sizeToFit(NSZeroSize, NSMakeSize(item.contentSize.width, 30), thatFit: true)
                
            } else {
                actionButton?.removeFromSuperview()
                actionButton = nil
            }
            
        }
    }
    
}
