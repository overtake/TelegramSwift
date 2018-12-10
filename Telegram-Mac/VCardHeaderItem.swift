//
//  VCardHeaderItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19/07/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
import TGUIKit
import Contacts

class VCardHeaderItem: GeneralRowItem {
    fileprivate let contact: TelegramMediaContact
    fileprivate let nameLayout: TextViewLayout
    fileprivate let account: Account
    fileprivate let name: String
    init(_ initialSize: NSSize, stableId: AnyHashable, account: Account, vCard: CNContact, contact: TelegramMediaContact) {
        self.contact = contact
        self.account = account
        
        self.name = isNotEmptyStrings([contact.firstName + (!contact.firstName.isEmpty ? " " : "") + contact.lastName, vCard.givenName, vCard.organizationName])
        
        nameLayout = TextViewLayout(.initialize(string: self.name, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1)
        super.init(initialSize, height: 70, stableId: stableId)
        _ = makeSize(width, oldWidth: 0)
    }
    
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let result = super.makeSize(width, oldWidth: oldWidth)
        
        nameLayout.measure(width: width - 90)
        
        return result
    }
    
    override func viewClass() -> AnyClass {
        return VCardHeaderView.self
    }
}


private final class VCardHeaderView : TableRowView {
    fileprivate let photoView: AvatarControl = AvatarControl.init(font: .avatar(18))
    fileprivate let textView: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        photoView.setFrameSize(50, 50)
        addSubview(photoView)
        addSubview(textView)
    }
    
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = theme.colors.background
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? VCardHeaderItem else {return}

        photoView.centerY(x: item.inset.left)
        textView.centerY(x: photoView.frame.maxX + 10)
        

    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? VCardHeaderItem else {return}
        
        photoView.setState(account: item.account, state: .PeerAvatar(PeerId(namespace: 0, id: 0), [item.name.prefix(1)], nil, nil))
        textView.update(item.nameLayout)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
