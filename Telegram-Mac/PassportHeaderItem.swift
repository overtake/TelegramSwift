//
//  PassportHeaderItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SyncCore

class PassportHeaderItem: TableRowItem {
    fileprivate let botPhoto: AvatarNodeState
    fileprivate let textLayout: TextViewLayout
    fileprivate let account: Account
    fileprivate let _stableId: AnyHashable
    
    override var stableId: AnyHashable {
        return _stableId
    }
    init(_ initialSize: NSSize, account: Account, stableId: AnyHashable, requestedFields: [SecureIdRequestedFormField], peer: Peer) {
        self.account = account
        self._stableId = stableId
        self.botPhoto = .PeerAvatar(peer, peer.displayLetters, peer.smallProfileImage, nil)
        
        let attributed = NSMutableAttributedString()
        
        _ = attributed.append(string: L10n.secureIdRequestHeader1(peer.displayTitle), color: theme.colors.grayText, font: .normal(.text))
        attributed.detectBoldColorInString(with: .bold(.text))
        self.textLayout = TextViewLayout(attributed, alignment: .left)
        
        super.init(initialSize)
        
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        textLayout.measure(width: width - 120)
        
        return success
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return PassportHeaderRowView.self
    }
    
    override var height: CGFloat {
        return max(50, textLayout.layoutSize.height)
    }
    
}


private final class PassportHeaderRowView : TableRowView {
    private let botPhoto: AvatarControl = AvatarControl(font: .avatar(20))
    private let textView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(botPhoto)
        addSubview(textView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        botPhoto.setFrameSize(50, 50)
    }
    
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = theme.colors.background
    }
    
    override func layout() {
        super.layout()
        
        botPhoto.centerY(x: 20)
        
        textView.centerY(x: botPhoto.frame.maxX + 20)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PassportHeaderItem else {return}
        
        textView.update(item.textLayout)
        botPhoto.setState(account: item.account, state: item.botPhoto)
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
