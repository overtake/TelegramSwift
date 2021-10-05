//
//  RequestJoinChatRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01.10.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import TelegramCore


final class RequestJoinChatRowItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let peer: Peer
    fileprivate let titleLayout: TextViewLayout
    fileprivate let statusLayout: TextViewLayout
    fileprivate let aboutLayout: TextViewLayout
    
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, peer: Peer, viewType: GeneralViewType) {
        self.context = context
        self.peer = peer
        
        self.titleLayout = TextViewLayout(.initialize(string: peer.displayTitle, color: theme.colors.text, font: .medium(.header)), maximumNumberOfLines: 1, truncationType: .middle)
        
        self.statusLayout = TextViewLayout(.initialize(string: "48,000 subscribers", color: theme.colors.grayText, font: .normal(.text)), alignment: .center)

        self.aboutLayout = TextViewLayout(.initialize(string: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.", color: theme.colors.text, font: .normal(.text)), alignment: .center)

        
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override var height: CGFloat {
        let top = self.viewType.innerInset.top
        return top + 80 + top + self.titleLayout.layoutSize.height + self.statusLayout.layoutSize.height + top + self.aboutLayout.layoutSize.height + top
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.titleLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)
        self.statusLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)
        self.aboutLayout.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)

        return true
    }
    
    override func viewClass() -> AnyClass {
        return RequestJoinChatRowView.self
    }
}


private final class RequestJoinChatRowView : GeneralContainableRowView {
    private let avatar: AvatarControl = AvatarControl(font: .avatar(20))
    private let titleView = TextView()
    private let statusView = TextView()
    private let aboutView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.avatar.setFrameSize(NSMakeSize(80, 80))
        addSubview(self.avatar)
        addSubview(titleView)
        addSubview(statusView)
        addSubview(aboutView)
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        statusView.userInteractionEnabled = false
        statusView.isSelectable = false
        aboutView.userInteractionEnabled = false
        aboutView.isSelectable = false
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? GeneralRowItem else {
            return
        }
        let top = item.viewType.innerInset.top
        avatar.centerX(y: top)
        titleView.centerX(y: avatar.frame.maxY + top)
        statusView.centerX(y: titleView.frame.maxY)
        aboutView.centerX(y: statusView.frame.maxY + top)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? RequestJoinChatRowItem else {
            return
        }
        self.avatar.setPeer(account: item.context.account, peer: item.peer)
        self.titleView.update(item.titleLayout)
        self.statusView.update(item.statusLayout)
        self.aboutView.update(item.aboutLayout)
        needsLayout = true
    }
}
