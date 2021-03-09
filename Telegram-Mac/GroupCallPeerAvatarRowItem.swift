//
//  GroupCallPeerAvatarRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 09.03.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit

final class GroupCallPeerAvatarRowItem : GeneralRowItem {
    fileprivate let account: Account
    fileprivate let peer: Peer
    fileprivate let nameLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, account: Account, peer: Peer, customTheme: GeneralRowItem.Theme) {
        self.account = account
        self.peer = peer
        self.nameLayout = TextViewLayout(.initialize(string: peer.displayTitle, color: customTheme.textColor, font: .medium(.title)))
        super.init(initialSize, stableId: stableId, viewType: .singleItem, customTheme: customTheme)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        nameLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)
        
        return true
    }
    
    override var height: CGFloat {
        return 90 + viewType.innerInset.top + viewType.innerInset.bottom + nameLayout.layoutSize.height
    }
    
    override func viewClass() -> AnyClass {
        return GroupCallPeerAvatarRowView.self
    }
}


private final class GroupCallPeerAvatarRowView: TableRowView {
    private let avatar: AvatarControl = AvatarControl(font: .avatar(20))
    private let nameView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        avatar.setFrameSize(NSMakeSize(90, 90))
        addSubview(avatar)
        addSubview(nameView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? GeneralRowItem else {
            return
        }

        avatar.centerX(y: 0)
        nameView.centerX(y: avatar.frame.maxY + item.viewType.innerInset.top)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GroupCallPeerAvatarRowItem else {
            return
        }
        
        avatar.setPeer(account: item.account, peer: item.peer)
        nameView.update(item.nameLayout)
        
        
    }
}
